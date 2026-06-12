// shading_pipeline.sv
// Lambert diffuse + Phong specular + shadow + fog shading FSM. Shades one
// hit or miss per invocation and completes before traversal advances to the
// next pixel.
//
// Stages: decode normal -> diffuse dot(n,light) -> specular reflect+pow^4 ->
// shadow ray -> combine base*(diff*shadow+ambient)+spec -> fog lerp by t_hit
// -> 24-bit pixel out.
`timescale 1ns/1ps
module shading_pipeline (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,           // single-cycle pulse: shade this hit/miss

    // Hit information from traversal FSM
    input  logic        is_miss,
    input  logic [1:0]  hit_face,        // 0=X  1=Y  2=Z
    input  logic        hit_face_sign,   // 0=positive normal  1=negative normal
    input  logic [7:0]  block_id,
    input  logic signed [31:0] t_hit,   // Q16.16 distance to hit

    // Ray direction (for specular reflect)
    input  logic signed [31:0] ray_dx, ray_dy, ray_dz,

    // Hit position (for shadow ray origin)
    input  logic signed [31:0] hit_px, hit_py, hit_pz,

    // Light and scene registers (Q16.16, from AXI slave)
    input  logic signed [31:0] light_dir_x, light_dir_y, light_dir_z,
    input  logic [23:0] sky_color,
    input  logic [23:0] fog_color,
    input  logic signed [31:0] fog_start,
    input  logic signed [31:0] shadow_bias,
    input  logic [31:0] lut [0:15],     // packed: [31:24]=material flag, [23:0]=RGB
    input  logic [31:0] time_phase,     // per-frame animation counter (raw bits)
    input  logic        shadow_on,      // 1=cast shadow ray, 0=skip (lit, faster)

    // Shadow traversal interface
    // When shadow_start pulses, the shadow traversal FSM begins.
    // shadow_done pulses one cycle after it finishes; shadow_hit=1 if blocked.
    output logic        shadow_start,
    output logic signed [31:0] shadow_ro_x, shadow_ro_y, shadow_ro_z,
    output logic signed [31:0] shadow_rd_x, shadow_rd_y, shadow_rd_z,
    input  logic        shadow_done,
    input  logic        shadow_hit,

    // Output
    output logic [23:0] pixel_color,
    output logic        done
);

    // -------------------------------------------------------------------------
    // Q16.16 helpers (multiplies go through the shared_qmul3 bank below)
    // -------------------------------------------------------------------------
    function automatic logic signed [31:0] qclamp01(
        input logic signed [31:0] v
    );
        if (v < 0)              return 0;
        if (v > 32'h0001_0000) return 32'h0001_0000;
        return v;
    endfunction

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    typedef enum logic [4:0] {
        S_IDLE      = 5'd0,
        S_NORMAL    = 5'd1,
        S_DS_A      = 5'd2,   // dot(n,light) products + shadow ray origin
        S_DS_B      = 5'd3,   // dnl = sum(products); diffuse = clamp(dnl)
        S_DS_C      = 5'd4,   // reflect numerator m = dnl * n
        S_DS_D      = 5'd5,   // reflect vector rf = light - 2m
        S_DS_E      = 5'd6,   // reflect.ray products
        S_DS_F      = 5'd7,   // dot_rv = sum(products)
        S_DS_G      = 5'd8,   // s_cl = clamp(-dot_rv)
        S_DS_H      = 5'd9,   // s2 = s_cl^2
        S_DS_I      = 5'd10,  // spec = s2^2
        S_SHADOW    = 5'd11,
        S_WAIT_SH   = 5'd12,
        S_COMBINE   = 5'd13,  // direct = (shadowed?0:diffuse)+ambient
        S_COMB2     = 5'd14,  // base_color * direct
        S_COMB3     = 5'd15,  // + specular, clamp, pack -> combined
        S_FOG       = 5'd16,  // blend_raw = (t_hit-fog_start)*INV_RANGE
        S_FOG_CLAMP = 5'd17,  // blend = clamp(blend_raw)
        S_FOG_LERP  = 5'd18,  // fog deltas = blend*(fog-combined)
        S_FOG_LERP2 = 5'd19,  // pixel = combined + delta
        S_DONE      = 5'd20
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // Intermediate registers
    // -------------------------------------------------------------------------
    logic signed [31:0] nx, ny, nz;          // surface normal (Q16.16 ±1.0)
    logic signed [31:0] diffuse;             // [0,1] Q16.16
    logic signed [31:0] spec;               // [0,1] Q16.16
    logic [23:0] base_color;
    logic [23:0] combined;
    logic        shadowed;

    // ---- XOR checkerboard texture (procedural surface variation) ----
    // Darken alternate 1-unit cells. Parity = XOR of the integer-LSB (Q16.16 bit 16)
    // of the two in-face (tangent) coords only; the face-normal coord lies on an
    // integer plane where t_hit rounding flips its bit, so it is dropped to keep the
    // per-face checker boundary-stable.
    wire        tex_dark = (hit_face == 2'd0) ? ~(hit_py[16] ^ hit_pz[16]) :  // normal X
                           (hit_face == 2'd1) ? ~(hit_px[16] ^ hit_pz[16]) :  // normal Y
                                                ~(hit_px[16] ^ hit_py[16]);   // normal Z
    wire [23:0] base_lut = lut[(block_id > 5'd15) ? 5'd15 : block_id][23:0];
    wire [23:0] base_tex = {base_lut[23:16] - (base_lut[23:16] >> 3),
                            base_lut[15:8]  - (base_lut[15:8]  >> 3),
                            base_lut[7:0]   - (base_lut[7:0]   >> 3)};

    // ---- Animated materials (flag in lut[idx][31:24]) ----
    wire [7:0]  mat_flag = lut[(block_id > 5'd15) ? 5'd15 : block_id][31:24];
    // Water: diagonal bright bands that scroll with time -> "flowing" + a sparkle.
    wire [4:0]  w_band  = hit_px[20:16] + hit_pz[20:16] + time_phase[8:4];
    wire        w_brt   = (w_band[2:1] == 2'b10);                 // ~scrolling stripe
    wire [7:0]  w_spk   = hit_px[18:16] * 8'd37 + hit_pz[18:16] * 8'd101 + time_phase[7:0];
    wire        w_spark = (w_spk[7:5] == 3'b111);                 // sparse glints
    // Lava: bright bands flowing downward, keyed off the vertical coord so
    // (y + t) bands march toward -y as time advances.
    wire [4:0]  l_band  = hit_py[20:16] + time_phase[7:3];
    wire        l_brt   = (l_band[3:2] == 2'b11);

    // brighten toward white by ~50% (add half of 255-c)
    function automatic logic [7:0] lighten(input logic [7:0] c);
        lighten = c + ((8'd255 - c) >> 1);
    endfunction
    wire [23:0] base_water = (w_brt || w_spark)
        ? {lighten(base_lut[23:16]), lighten(base_lut[15:8]), lighten(base_lut[7:0])}
        : base_lut;
    wire [23:0] base_lava  = l_brt
        ? {lighten(base_lut[23:16]), lighten(base_lut[15:8]), lighten(base_lut[7:0])}
        : {base_lut[23:16] - (base_lut[23:16] >> 2),   // darker crust between cracks
           base_lut[15:8]  - (base_lut[15:8]  >> 2),
           base_lut[7:0]   - (base_lut[7:0]   >> 2)};

    // diffuse/specular/fog intermediates (registered between stages)
    logic signed [31:0] dnl;                 // dot(normal, light) — reused for diffuse + reflect
    logic signed [31:0] m_nx, m_ny, m_nz;    // reflect numerator  = dnl * normal
    logic signed [31:0] dot_rv;              // dot(reflect, ray_dir)
    logic signed [31:0] s2;                  // specular base squared
    logic signed [31:0] blend;               // fog blend factor [0,1]
    logic signed [31:0] pn_x, pn_y, pn_z;    // dot(normal,light) partial products
    logic signed [31:0] rf_x, rf_y, rf_z;    // reflect vector = light - 2m
    logic signed [31:0] pr_x, pr_y, pr_z;    // reflect·ray partial products
    logic signed [31:0] s_cl;                // clamp(-dot_rv)
    logic signed [31:0] direct;              // (shadowed?0:diffuse)+ambient
    logic signed [31:0] cmb_r, cmb_g, cmb_b; // base_color * direct
    logic signed [31:0] blend_raw;           // unclamped fog blend
    logic signed [31:0] fog_dr, fog_dg, fog_db; // fog lerp deltas
    logic signed [31:0] fog_dist;            // t_hit - fog_start (pre-subtracted)
    logic signed [31:0] fdiff_r, fdiff_g, fdiff_b; // fog_color - combined (pre-subtracted)

    // 1/185 in Q16.16 (reciprocal of MAX_T - FOG_START = 200-15)
    localparam logic signed [31:0] FOG_INV_RANGE = 32'h0000_0394;
    // ambient = 0.1 in Q16.16
    localparam logic signed [31:0] AMBIENT = 32'h0000_199A;

    // -------------------------------------------------------------------------
    // Shared 3-lane multiplier bank (DSP reduction). A multiply stage issues
    // operands at q_phase==0, waits QCOL cycles, collects the product at
    // q_phase==1, then advances. Non-multiply stages leave q_phase at 0.
    // -------------------------------------------------------------------------
    localparam int QCOL = 4;
    logic signed [31:0] q_a0, q_b0, q_a1, q_b1, q_a2, q_b2;
    logic signed [31:0] q_p0, q_p1, q_p2;
    logic [2:0]         q_phase;

    shared_qmul3 #(.LAT(3)) u_qmul (
        .clk(clk),
        .a0(q_a0), .b0(q_b0), .a1(q_a1), .b1(q_b1), .a2(q_a2), .b2(q_b2),
        .p0(q_p0), .p1(q_p1), .p2(q_p2)
    );

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state        <= S_IDLE;
            done         <= '0;
            shadow_start <= '0;
            q_phase      <= '0;
        end else begin
            done         <= '0;
            shadow_start <= '0;

            unique case (state)

            S_IDLE: if (start) state <= is_miss ? S_FOG : S_NORMAL;

            // -----------------------------------------------------------------
            S_NORMAL: begin
                // Decode face normal: two components zero, one ±1.0
                nx <= '0; ny <= '0; nz <= '0;
                unique case (hit_face)
                    2'd0: nx <= hit_face_sign ? -32'sh0001_0000 : 32'sh0001_0000;
                    2'd1: ny <= hit_face_sign ? -32'sh0001_0000 : 32'sh0001_0000;
                    2'd2: nz <= hit_face_sign ? -32'sh0001_0000 : 32'sh0001_0000;
                    default: nx <= 32'sh0001_0000;
                endcase
                // base colour: animated materials override the XOR texture
                unique case (mat_flag)
                    8'd1:    base_color <= base_water;
                    8'd2:    base_color <= base_lava;
                    default: base_color <= tex_dark ? base_tex : base_lut;  // 0 static, 3 glow (host-driven LUT)
                endcase
                state <= S_DS_A;
            end

            // -----------------------------------------------------------------
            // Diffuse + specular, one arithmetic op per stage. Two 3-lane
            // multiply groups issued over 2 cycles (6 muls > 3 lanes):
            //   A: pn = dot(normal,light) partials (reused for diffuse + reflect)
            //   B: n*bias for shadow ray origin = hit_pos + normal*bias
            S_DS_A: begin
                if (q_phase == 0) begin           // issue A: pn = n * light
                    q_a0 <= nx; q_b0 <= light_dir_x;
                    q_a1 <= ny; q_b1 <= light_dir_y;
                    q_a2 <= nz; q_b2 <= light_dir_z;
                    shadow_rd_x <= light_dir_x;    // independent passthrough
                    shadow_rd_y <= light_dir_y;
                    shadow_rd_z <= light_dir_z;
                    q_phase <= 3'd5;
                end else if (q_phase == 5) begin  // issue B: n * shadow_bias
                    q_a0 <= nx; q_b0 <= shadow_bias;
                    q_a1 <= ny; q_b1 <= shadow_bias;
                    q_a2 <= nz; q_b2 <= shadow_bias;
                    q_phase <= 3'd4;
                end else if (q_phase == 2) begin  // collect A (pn), 4 after issue A
                    pn_x <= q_p0; pn_y <= q_p1; pn_z <= q_p2;
                    q_phase <= 3'd1;
                end else if (q_phase == 1) begin  // collect B -> shadow_ro = hit + n*bias
                    shadow_ro_x <= hit_px + q_p0;
                    shadow_ro_y <= hit_py + q_p1;
                    shadow_ro_z <= hit_pz + q_p2;
                    q_phase <= '0; state <= S_DS_B;
                end else q_phase <= q_phase - 1'b1;  // 4->3, 3->2
            end

            S_DS_B: begin
                begin
                    logic signed [31:0] dnl_c;
                    dnl_c   = pn_x + pn_y + pn_z;
                    dnl     <= dnl_c;
                    diffuse <= qclamp01(dnl_c);
                end
                state <= S_DS_C;
            end

            S_DS_C: begin
                // reflect numerator m = dot(light,normal) * normal  (shared bank)
                if (q_phase == 0) begin
                    q_a0 <= dnl; q_b0 <= nx;
                    q_a1 <= dnl; q_b1 <= ny;
                    q_a2 <= dnl; q_b2 <= nz;
                    q_phase <= QCOL[2:0];
                end else if (q_phase == 1) begin
                    m_nx <= q_p0; m_ny <= q_p1; m_nz <= q_p2;
                    q_phase <= '0; state <= S_DS_D;
                end else q_phase <= q_phase - 1'b1;
            end

            S_DS_D: begin
                // reflect vector rf = light - 2*m  (×2 = arithmetic shift, no mul)
                rf_x <= light_dir_x - (m_nx <<< 1);
                rf_y <= light_dir_y - (m_ny <<< 1);
                rf_z <= light_dir_z - (m_nz <<< 1);
                state <= S_DS_E;
            end

            S_DS_E: begin
                // reflect·ray partial products  (shared bank)
                if (q_phase == 0) begin
                    q_a0 <= rf_x; q_b0 <= ray_dx;
                    q_a1 <= rf_y; q_b1 <= ray_dy;
                    q_a2 <= rf_z; q_b2 <= ray_dz;
                    q_phase <= QCOL[2:0];
                end else if (q_phase == 1) begin
                    pr_x <= q_p0; pr_y <= q_p1; pr_z <= q_p2;
                    q_phase <= '0; state <= S_DS_F;
                end else q_phase <= q_phase - 1'b1;
            end

            S_DS_F: begin
                dot_rv <= pr_x + pr_y + pr_z;
                state  <= S_DS_G;
            end

            S_DS_G: begin
                s_cl  <= qclamp01(-dot_rv);   // negate: ray goes toward eye
                state <= S_DS_H;
            end

            S_DS_H: begin                     // s2 = s_cl^2  (shared bank, lane 0)
                if (q_phase == 0) begin
                    q_a0 <= s_cl; q_b0 <= s_cl;
                    q_phase <= QCOL[2:0];
                end else if (q_phase == 1) begin
                    s2 <= q_p0;
                    q_phase <= '0; state <= S_DS_I;
                end else q_phase <= q_phase - 1'b1;
            end

            S_DS_I: begin                     // spec = s2^2 (= s_cl^4)  (shared bank)
                if (q_phase == 0) begin
                    q_a0 <= s2; q_b0 <= s2;
                    q_phase <= QCOL[2:0];
                end else if (q_phase == 1) begin
                    spec <= q_p0;
                    q_phase <= '0;
                    if (shadow_on) begin
                        state <= S_SHADOW;
                    end else begin
                        shadowed <= 1'b0;          // no shadow ray -> fully lit
                        state    <= S_COMBINE;
                    end
                end else q_phase <= q_phase - 1'b1;
            end

            // -----------------------------------------------------------------
            S_SHADOW: begin
                shadow_start <= 1'b1;
                state <= S_WAIT_SH;
            end

            S_WAIT_SH: if (shadow_done) begin
                shadowed <= shadow_hit;
                state    <= S_COMBINE;
            end

            // -----------------------------------------------------------------
            // Combine, one op per stage (qmul isolated from pre-clamp and post
            // add+saturate).
            S_COMBINE: begin
                // direct = (shadowed ? 0 : diffuse) + ambient
                direct   <= shadowed ? AMBIENT : qclamp01(diffuse + AMBIENT);
                // pre-subtract fog distance so S_FOG's qmul has no subtract in front
                fog_dist <= t_hit - fog_start;
                state    <= S_COMB2;
            end

            S_COMB2: begin
                // base_color * direct  (one lane per channel, shared bank)
                if (q_phase == 0) begin
                    q_a0 <= {16'd0, base_color[23:16]}; q_b0 <= direct;
                    q_a1 <= {16'd0, base_color[15:8]};  q_b1 <= direct;
                    q_a2 <= {16'd0, base_color[7:0]};   q_b2 <= direct;
                    q_phase <= QCOL[2:0];
                end else if (q_phase == 1) begin
                    cmb_r <= q_p0; cmb_g <= q_p1; cmb_b <= q_p2;
                    q_phase <= '0; state <= S_COMB3;
                end else q_phase <= q_phase - 1'b1;
            end

            S_COMB3: begin
                // add white specular highlight, saturate to 8-bit, pack
                begin
                    logic signed [31:0] spec_add, r_ch, g_ch, b_ch;
                    spec_add = spec >> 8;
                    r_ch = cmb_r + spec_add; if (r_ch > 8'hFF) r_ch = 8'hFF;
                    g_ch = cmb_g + spec_add; if (g_ch > 8'hFF) g_ch = 8'hFF;
                    b_ch = cmb_b + spec_add; if (b_ch > 8'hFF) b_ch = 8'hFF;
                    combined <= {r_ch[7:0], g_ch[7:0], b_ch[7:0]};
                end
                state <= S_FOG;
            end

            // -----------------------------------------------------------------
            S_FOG: begin
                // only the fog branch uses the bank; miss / no-fog exit single-cycle
                if (q_phase == 0) begin
                    if (is_miss) begin
                        pixel_color <= sky_color;
                        state       <= S_DONE;
                    end else if (t_hit > fog_start) begin
                        // blend_raw = fog_dist * (1/range)
                        q_a0    <= fog_dist; q_b0 <= FOG_INV_RANGE;
                        q_phase <= QCOL[2:0];
                    end else begin
                        pixel_color <= combined;
                        state       <= S_DONE;
                    end
                end else if (q_phase == 1) begin
                    blend_raw <= q_p0;
                    q_phase   <= '0; state <= S_FOG_CLAMP;
                end else q_phase <= q_phase - 1'b1;
            end

            S_FOG_CLAMP: begin
                // clamp blend and pre-subtract (fog_color - combined) in parallel
                blend   <= qclamp01(blend_raw);
                fdiff_r <= {16'd0, fog_color[23:16]} - {16'd0, combined[23:16]};
                fdiff_g <= {16'd0, fog_color[15:8]}  - {16'd0, combined[15:8]};
                fdiff_b <= {16'd0, fog_color[7:0]}   - {16'd0, combined[7:0]};
                state   <= S_FOG_LERP;
            end

            S_FOG_LERP: begin
                // fog deltas = blend * (fog_color - combined)  (one lane/channel, shared bank)
                if (q_phase == 0) begin
                    q_a0 <= blend; q_b0 <= fdiff_r;
                    q_a1 <= blend; q_b1 <= fdiff_g;
                    q_a2 <= blend; q_b2 <= fdiff_b;
                    q_phase <= QCOL[2:0];
                end else if (q_phase == 1) begin
                    fog_dr <= q_p0; fog_dg <= q_p1; fog_db <= q_p2;
                    q_phase <= '0; state <= S_FOG_LERP2;
                end else q_phase <= q_phase - 1'b1;
            end

            S_FOG_LERP2: begin
                // pixel = combined + delta  (add + pack)
                begin
                    logic signed [31:0] pr, pg, pb;
                    pr = {16'd0, combined[23:16]} + fog_dr;
                    pg = {16'd0, combined[15:8]}  + fog_dg;
                    pb = {16'd0, combined[7:0]}   + fog_db;
                    pixel_color <= {pr[7:0], pg[7:0], pb[7:0]};
                end
                state <= S_DONE;
            end

            // -----------------------------------------------------------------
            S_DONE: begin
                done  <= 1'b1;
                state <= S_IDLE;
            end

            endcase
        end
    end

endmodule

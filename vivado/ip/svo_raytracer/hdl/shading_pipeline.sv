// shading_pipeline.sv
// Full shading pipeline for one hit or miss per invocation.
// Sequential (not pipelined across pixels) — completes before the traversal
// FSM moves to the next pixel.
//
// Stages:
//   1. Decode surface normal from hit_face + hit_face_sign
//   2. Diffuse:  dot(normal, light_dir), clamped to [0,1]
//   3. Specular: reflect + pow^4 approximation
//   4. Trigger shadow traversal; wait for result
//   5. Combine: base_colour * (diff * shadow + ambient) + white * spec
//   6. Fog:     lerp to fog_colour based on t_hit
//   7. Output final 24-bit pixel colour
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
    input  logic [31:0] lut [0:5],      // packed RGB colour table

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
    // Q16.16 helpers
    // -------------------------------------------------------------------------
    // (The qmul() function has been removed: every shading multiply is now issued
    // onto the shared_qmul3 bank from the FSM. Only qclamp01 remains.)
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
    // 0.75x the base colour on alternating unit cells. pattern = LSB of each integer
    // hit coordinate (Q16.16 bit 16) XORed — one gate + shift, free in hardware.
    // Mirrored in gen_reference_shaded.py so the reference PNG matches.
    wire        tex_dark = ~(hit_px[16] ^ hit_py[16] ^ hit_pz[16]);
    wire [23:0] base_lut = lut[(block_id > 5) ? 5 : block_id][23:0];
    wire [23:0] base_tex = {base_lut[23:16] - (base_lut[23:16] >> 3),
                            base_lut[15:8]  - (base_lut[15:8]  >> 3),
                            base_lut[7:0]   - (base_lut[7:0]   >> 3)};

    // Pipelined S_DIFFSPEC / S_FOG intermediates (registered between stages)
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
    // Shading's own shared 3-lane multiplier bank (DSP reduction). Every shading
    // qmul is issued onto these lanes from the FSM and collected QCOL cycles later
    // instead of inferring one dedicated DSP per multiply. A multiply stage issues
    // operands at q_phase==0, waits QCOL cycles, collects the product at q_phase==1,
    // then advances. Non-multiply stages leave q_phase at 0 (single cycle).
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
                // Look up base colour (clamped to LUT range [0,5]) + XOR checkerboard texture.
                base_color <= tex_dark ? base_tex : base_lut;
                state <= S_DS_A;
            end

            // -----------------------------------------------------------------
            // Pipelined diffuse + specular: ONE arithmetic op per stage so every
            // combinational path is <= one qmul (~6 ns) and fits the 10 ns clock.
            // Algebra is identical to the original single-cycle S_DIFFSPEC.
            // Two 3-lane multiply groups over 2 issue cycles (6 muls > 3 lanes):
            //   A: pn = dot(normal,light) partial products (summed in S_DS_B,
            //      reused for diffuse + specular reflect)
            //   B: n*bias for the shadow ray origin = hit_pos + normal*bias
            //      (pruned when the shadow traversal is not built).
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
                    q_phase <= '0; state <= S_SHADOW;
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
            // Combine: pipelined one-op-per-stage (qmul isolated from the
            // pre-clamp and the post add+saturate). Algebra identical to the
            // old single-cycle S_COMBINE.
            S_COMBINE: begin
                // direct = (shadowed ? 0 : diffuse) + ambient
                direct   <= shadowed ? AMBIENT : qclamp01(diffuse + AMBIENT);
                // Pre-subtract the fog distance here (parallel, independent) so
                // S_FOG's qmul has no subtract in front of it.
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
                // Conditional: only the fog branch uses the bank; the miss / no-fog
                // branches exit at q_phase==0 (q_phase untouched, single cycle).
                if (q_phase == 0) begin
                    if (is_miss) begin
                        pixel_color <= sky_color;
                        state       <= S_DONE;
                    end else if (t_hit > fog_start) begin
                        // issue blend_raw = fog_dist * (1/range)  (subtract done in S_COMBINE)
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
                // clamp blend AND pre-subtract (fog_color - combined) in parallel,
                // so S_FOG_LERP's qmul has no subtract in front of it.
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

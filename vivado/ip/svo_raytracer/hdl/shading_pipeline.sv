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
    function automatic logic signed [31:0] qmul(
        input logic signed [31:0] a, b
    );
        logic signed [63:0] p;
        p = a * b;
        return p[47:16];
    endfunction

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
    typedef enum logic [2:0] {
        S_IDLE     = 3'd0,
        S_NORMAL   = 3'd1,
        S_DIFFSPEC = 3'd2,
        S_SHADOW   = 3'd3,
        S_WAIT_SH  = 3'd4,
        S_COMBINE  = 3'd5,
        S_FOG      = 3'd6,
        S_DONE     = 3'd7
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

    // 1/185 in Q16.16 (reciprocal of MAX_T - FOG_START = 200-15)
    localparam logic signed [31:0] FOG_INV_RANGE = 32'h0000_0394;
    // ambient = 0.1 in Q16.16
    localparam logic signed [31:0] AMBIENT = 32'h0000_199A;

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state        <= S_IDLE;
            done         <= '0;
            shadow_start <= '0;
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
                // Look up base colour; clamp block_id to LUT range [0,5]
                base_color <= lut[(block_id > 5) ? 5 : block_id][23:0];
                state <= S_DIFFSPEC;
            end

            // -----------------------------------------------------------------
            S_DIFFSPEC: begin
                // Diffuse = clamp(dot(normal, light_dir), 0, 1)
                begin
                    logic signed [31:0] d;
                    d = qmul(nx, light_dir_x) + qmul(ny, light_dir_y) + qmul(nz, light_dir_z);
                    diffuse <= qclamp01(d);
                end
                // Specular: r = ld - 2*dot(ld,n)*n;  spec = clamp(-dot(r,rd),0,1)^4
                begin
                    logic signed [31:0] dot_ln, rx, ry, rz, dot_rv, s;
                    dot_ln = qmul(light_dir_x, nx) + qmul(light_dir_y, ny) + qmul(light_dir_z, nz);
                    rx = light_dir_x - qmul(32'sh0002_0000, qmul(dot_ln, nx));
                    ry = light_dir_y - qmul(32'sh0002_0000, qmul(dot_ln, ny));
                    rz = light_dir_z - qmul(32'sh0002_0000, qmul(dot_ln, nz));
                    dot_rv = qmul(rx, ray_dx) + qmul(ry, ray_dy) + qmul(rz, ray_dz);
                    s = qclamp01(-dot_rv);    // negate: ray goes toward eye
                    s = qmul(s, s);           // ^2
                    spec <= qmul(s, s);       // ^4
                end
                // Shadow ray: origin = hit_pos + normal * shadow_bias
                shadow_ro_x <= hit_px + qmul(nx, shadow_bias);
                shadow_ro_y <= hit_py + qmul(ny, shadow_bias);
                shadow_ro_z <= hit_pz + qmul(nz, shadow_bias);
                shadow_rd_x <= light_dir_x;
                shadow_rd_y <= light_dir_y;
                shadow_rd_z <= light_dir_z;
                state <= S_SHADOW;
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
            S_COMBINE: begin
                begin
                    logic signed [31:0] direct, r_ch, g_ch, b_ch, spec_add;
                    // direct = (shadowed ? 0 : diffuse) + ambient
                    direct = shadowed ? AMBIENT : qclamp01(diffuse + AMBIENT);
                    r_ch = qmul({16'd0, base_color[23:16]}, direct);
                    g_ch = qmul({16'd0, base_color[15:8]},  direct);
                    b_ch = qmul({16'd0, base_color[7:0]},   direct);
                    // White specular highlight
                    spec_add = spec >> 8;
                    r_ch += spec_add; if (r_ch > 8'hFF) r_ch = 8'hFF;
                    g_ch += spec_add; if (g_ch > 8'hFF) g_ch = 8'hFF;
                    b_ch += spec_add; if (b_ch > 8'hFF) b_ch = 8'hFF;
                    combined <= {r_ch[7:0], g_ch[7:0], b_ch[7:0]};
                end
                state <= S_FOG;
            end

            // -----------------------------------------------------------------
            S_FOG: begin
                if (is_miss) begin
                    pixel_color <= sky_color;
                end else if (t_hit > fog_start) begin
                    logic signed [31:0] blend;
                    logic signed [31:0] cr, cg, cb, fr, fg, fb;
                    logic signed [31:0] pr, pg, pb;
                    blend = qclamp01(qmul(t_hit - fog_start, FOG_INV_RANGE));
                    cr = {16'd0, combined[23:16]};
                    cg = {16'd0, combined[15:8]};
                    cb = {16'd0, combined[7:0]};
                    fr = {16'd0, fog_color[23:16]};
                    fg = {16'd0, fog_color[15:8]};
                    fb = {16'd0, fog_color[7:0]};
                    pr = cr + qmul(blend, fr - cr);
                    pg = cg + qmul(blend, fg - cg);
                    pb = cb + qmul(blend, fb - cb);
                    pixel_color <= {pr[7:0], pg[7:0], pb[7:0]};
                end else begin
                    pixel_color <= combined;
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

`timescale 1ns/1ps
// axis_upscale_2x.sv
// Nearest-neighbour 2x AXI4-Stream line upscaler (HDMI path).
// In : IN_W x IN_H, 32-bit/pixel, tuser=SOF, tlast=EOL.
// Out: 2*IN_W x 2*IN_H, same format, framing regenerated. One clock domain.
// Each source pixel becomes a 2x2 block; the input must deliver exactly
// IN_W*IN_H pixels/frame (true for VDMA MM2S).
module axis_upscale_2x #(
    parameter int IN_W = 320,
    parameter int IN_H = 240
)(
    input  logic        aclk,
    input  logic        aresetn,
    // slave (input)
    input  logic [31:0] s_axis_tdata,
    input  logic [3:0]  s_axis_tkeep,
    input  logic        s_axis_tuser,
    input  logic        s_axis_tlast,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    // master (output)
    output logic [31:0] m_axis_tdata,
    output logic [3:0]  m_axis_tkeep,
    output logic        m_axis_tuser,
    output logic        m_axis_tlast,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready
);
    localparam int OUT_W = 2*IN_W;
    localparam int OUT_H = 2*IN_H;

    logic [31:0] linebuf [0:IN_W-1];
    logic [31:0] hold;                 // last accepted source pixel (phase A)
    logic [10:0] out_col;              // 0..OUT_W-1
    logic [10:0] out_row;              // 0..OUT_H-1
    logic        phase_b;              // 0 = LINE_A (read input), 1 = LINE_B (replay)
    logic        synced;               // has the upscaler locked to an input frame start (tuser)?

    wire        src_even = ~out_col[0];      // even out col needs a new source pixel (phase A)
    wire [10:0] src_col  = out_col >> 1;     // 0..IN_W-1

    // ---- output data ----
    always_comb begin
        if (phase_b)        m_axis_tdata = linebuf[src_col];
        else                m_axis_tdata = src_even ? s_axis_tdata : hold;
    end
    assign m_axis_tkeep = 4'hF;
    assign m_axis_tlast = (out_col == OUT_W-1);
    assign m_axis_tuser = (out_row == 0) && (out_col == 0);

    // ---- handshake ----
    // phase A even col: emit a NEW source pixel -> needs s_axis_tvalid
    // phase A odd  col: re-emit hold            -> always valid
    // phase B        : replay buffer            -> always valid
    always_comb begin
        if (!synced)        m_axis_tvalid = 1'b0;        // hold output until locked to input SOF
        else if (phase_b)   m_axis_tvalid = 1'b1;
        else if (src_even)  m_axis_tvalid = s_axis_tvalid;
        else                m_axis_tvalid = 1'b1;
    end
    assign s_axis_tready = synced && (!phase_b) && src_even && m_axis_tready;

    wire adv = m_axis_tvalid && m_axis_tready;   // one output pixel committed

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            out_col <= '0; out_row <= '0; phase_b <= 1'b0; synced <= 1'b0;
        end else begin
            if (s_axis_tready && s_axis_tvalid) begin
                hold             <= s_axis_tdata;
                linebuf[src_col] <= s_axis_tdata;
            end
            if (!synced) begin
                // Lock to the input frame start: ignore everything until the first SOF
                // (tuser), then begin aligned at (0,0). Otherwise the column counter
                // starts mid-frame and every output line is horizontally offset.
                if (s_axis_tvalid && s_axis_tuser) begin
                    synced <= 1'b1; out_col <= '0; out_row <= '0; phase_b <= 1'b0;
                end
            end else if (adv) begin
                if (out_col == OUT_W-1) begin
                    out_col <= '0;
                    phase_b <= ~phase_b;                          // A -> B (replay), B -> A (next line)
                    out_row <= (out_row == OUT_H-1) ? '0 : out_row + 1'b1;
                end else begin
                    out_col <= out_col + 1'b1;
                end
            end
        end
    end
endmodule

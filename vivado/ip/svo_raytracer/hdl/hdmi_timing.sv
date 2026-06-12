// hdmi_timing.sv — legacy, not part of the active render pipeline.
// 640×480 @ 60 Hz VESA timing generator on a 25.175 MHz pixel clock.
`timescale 1ns/1ps
module hdmi_timing (
    input  logic       clk_pixel,
    input  logic       rst,
    output logic [9:0] hx,        // 0..799
    output logic [9:0] hy,        // 0..524
    output logic       hsync,
    output logic       vsync,
    output logic       data_en
);
    // Horizontal: 640 active | 16 FP | 96 sync | 48 BP = 800 total
    // Vertical:   480 active | 10 FP |  2 sync | 33 BP = 525 total
    localparam int H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48;
    localparam int V_ACTIVE = 480, V_FP = 10, V_SYNC =  2, V_BP = 33;
    localparam int H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP; // 800
    localparam int V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP; // 525

    always_ff @(posedge clk_pixel) begin
        if (rst) begin
            hx <= '0;
            hy <= '0;
        end else if (hx == H_TOTAL - 1) begin
            hx <= '0;
            hy <= (hy == V_TOTAL - 1) ? '0 : hy + 1'b1;
        end else
            hx <= hx + 1'b1;
    end

    // Active-low sync pulses per VESA 640×480 spec
    assign hsync   = ~(hx >= H_ACTIVE + H_FP && hx < H_ACTIVE + H_FP + H_SYNC);
    assign vsync   = ~(hy >= V_ACTIVE + V_FP && hy < V_ACTIVE + V_FP + V_SYNC);
    assign data_en =  (hx < H_ACTIVE) && (hy < V_ACTIVE);

endmodule

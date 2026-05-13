// sim/tb_hdmi_timing.sv
// Verifies that hdmi_timing produces exactly 640×480 = 307200 active pixels
// per frame for the 640×480 @ 60 Hz VESA timing spec.
`timescale 1ns/1ps
module tb_hdmi_timing;
    logic       clk = '0;
    logic       rst = '1;
    logic [9:0] hx, hy;
    logic       hsync, vsync, data_en;

    hdmi_timing dut (
        .clk_pixel (clk),
        .rst       (rst),
        .hx        (hx),
        .hy        (hy),
        .hsync     (hsync),
        .vsync     (vsync),
        .data_en   (data_en)
    );

    always #19.86 clk = ~clk;   // ≈ 25.175 MHz

    int active_pixels = 0;

    initial begin
        $dumpfile("hdmi_timing.vcd");
        $dumpvars(0, tb_hdmi_timing);
        #100 rst = '0;
        repeat (800 * 525) @(posedge clk);
        $display("Active pixels: %0d (expect 307200)", active_pixels);
        if (active_pixels == 307200)
            $display("PASS");
        else
            $display("FAIL");
        $finish;
    end

    always_ff @(posedge clk)
        if (data_en) active_pixels++;

endmodule

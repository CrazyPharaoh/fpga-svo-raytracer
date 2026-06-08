// axi_lite_slave.sv
// AXI4-Lite slave — exposes all control/camera/LUT/SVO registers to PS.
`timescale 1ns/1ps
module axi_lite_slave #(
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 8
)(
    // AXI4-Lite signals
    input  logic                              S_AXI_ACLK,
    input  logic                              S_AXI_ARESETN,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_AWADDR,
    input  logic                              S_AXI_AWVALID,
    output logic                              S_AXI_AWREADY,
    input  logic [C_S_AXI_DATA_WIDTH-1:0]    S_AXI_WDATA,
    input  logic [C_S_AXI_DATA_WIDTH/8-1:0]  S_AXI_WSTRB,
    input  logic                              S_AXI_WVALID,
    output logic                              S_AXI_WREADY,
    output logic [1:0]                        S_AXI_BRESP,
    output logic                              S_AXI_BVALID,
    input  logic                              S_AXI_BREADY,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    input  logic                              S_AXI_ARVALID,
    output logic                              S_AXI_ARREADY,
    output logic [C_S_AXI_DATA_WIDTH-1:0]    S_AXI_RDATA,
    output logic [1:0]                        S_AXI_RRESP,
    output logic                              S_AXI_RVALID,
    input  logic                              S_AXI_RREADY,

    // Control / status
    output logic        ctrl_trigger,         // single-cycle pulse: start render
    input  logic        status_busy,
    input  logic        status_frame_done,

    // Camera registers (Q16.16)
    output logic signed [31:0] cam_pos_x,   cam_pos_y,   cam_pos_z,
    output logic signed [31:0] cam_right_x, cam_right_y, cam_right_z,
    output logic signed [31:0] cam_up_x,    cam_up_y,    cam_up_z,
    output logic signed [31:0] cam_fwd_x,   cam_fwd_y,   cam_fwd_z,
    output logic signed [31:0] cam_scale,

    // Light direction (Q16.16, normalised)
    output logic signed [31:0] light_dir_x, light_dir_y, light_dir_z,

    // SVO BRAM write port (streaming loader)
    output logic [14:0] svo_wr_addr,
    output logic [31:0] svo_wr_data,
    output logic        svo_wr_en,

    // Colour registers (packed: [31:24]=material flag, [23:0]=RGB R<<16|G<<8|B)
    output logic [31:0] lut [0:15],
    output logic [31:0] sky_color,
    output logic [31:0] fog_color,
    output logic signed [31:0] fog_start,
    output logic signed [31:0] shadow_bias,
    output logic [31:0] time_phase,
    output logic        shadow_on,
    output logic [3:0]  max_depth,

    // Debug inputs from traversal FSM (read-only)
    input  logic [3:0]  dbg_state,
    input  logic [3:0]  dbg_rs_wait,  // rs_wait counter value (0-15)
    input  logic [8:0]  dbg_px,
    input  logic [7:0]  dbg_py,
    input  logic        dbg_tvalid,   // 1 = IP outputting pixel to VDMA
    input  logic        dbg_tready,   // 1 = VDMA accepting the pixel
    input  logic [31:0] dbg_mr        // multi-ray core internals (read at 0x80)
);

    logic [C_S_AXI_ADDR_WIDTH-1:0] aw_addr_lat;

    // ctrl_trigger stays high for 32 cycles after the AXI write so it is
    // visible to the traversal FSM even across the 16-cycle multicycle path.
    logic [5:0] trig_cnt;

    // Auto-incrementing LUT write pointer (0..15)
    logic [3:0] lut_index;

    // -------------------------------------------------------------------------
    // Write channel
    // -------------------------------------------------------------------------
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= '0;
            S_AXI_WREADY  <= '0;
            S_AXI_BVALID  <= '0;
            S_AXI_BRESP   <= '0;
            ctrl_trigger  <= '0;
            trig_cnt      <= '0;
            svo_wr_en     <= '0;
            svo_wr_addr   <= '0;
            lut_index     <= '0;
            time_phase    <= '0;
            shadow_on     <= 1'b1;
            max_depth     <= 4'd6;
        end else begin
            // ctrl_trigger: pulse for 32 cycles after AXI write to 0x00
            if (trig_cnt != '0) begin
                trig_cnt     <= trig_cnt - 1'b1;
                ctrl_trigger <= (trig_cnt != 6'd1); // go low on last countdown
            end else
                ctrl_trigger <= '0;

            // Latch write address
            if (S_AXI_AWVALID && !S_AXI_AWREADY) begin
                S_AXI_AWREADY <= 1'b1;
                aw_addr_lat   <= S_AXI_AWADDR;
            end else
                S_AXI_AWREADY <= 1'b0;

            // Accept write data
            if (S_AXI_WVALID && !S_AXI_WREADY)
                S_AXI_WREADY <= 1'b1;
            else
                S_AXI_WREADY <= 1'b0;

            // Register write — fires when both address and data are accepted
            svo_wr_en <= '0;
            if (S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WREADY && S_AXI_WVALID) begin
                unique case (aw_addr_lat[7:2])
                    6'h00: if (S_AXI_WDATA[0]) trig_cnt <= 6'd32; // arm 32-cycle pulse
                    // 6'h01 → STATUS read-only, writes ignored
                    6'h02: cam_pos_x    <= S_AXI_WDATA;
                    6'h03: cam_pos_y    <= S_AXI_WDATA;
                    6'h04: cam_pos_z    <= S_AXI_WDATA;
                    6'h05: cam_right_x  <= S_AXI_WDATA;
                    6'h06: cam_right_y  <= S_AXI_WDATA;
                    6'h07: cam_right_z  <= S_AXI_WDATA;
                    6'h08: cam_up_x     <= S_AXI_WDATA;
                    6'h09: cam_up_y     <= S_AXI_WDATA;
                    6'h0A: cam_up_z     <= S_AXI_WDATA;
                    6'h0B: cam_fwd_x    <= S_AXI_WDATA;
                    6'h0C: cam_fwd_y    <= S_AXI_WDATA;
                    6'h0D: cam_fwd_z    <= S_AXI_WDATA;
                    6'h0E: cam_scale    <= S_AXI_WDATA;
                    6'h0F: light_dir_x  <= S_AXI_WDATA;
                    6'h10: light_dir_y  <= S_AXI_WDATA;
                    6'h11: light_dir_z  <= S_AXI_WDATA;
                    6'h12: svo_wr_addr  <= S_AXI_WDATA[14:0];
                    6'h13: begin
                               svo_wr_data <= S_AXI_WDATA;
                               svo_wr_en   <= 1'b1;
                               svo_wr_addr <= svo_wr_addr + 1'b1;
                           end
                    6'h14: lut_index <= S_AXI_WDATA[3:0];   // set LUT write pointer
                    6'h15: begin                            // write + auto-increment
                               lut[lut_index] <= S_AXI_WDATA;
                               lut_index      <= lut_index + 1'b1;
                           end
                    6'h1A: sky_color    <= S_AXI_WDATA;
                    6'h1B: fog_color    <= S_AXI_WDATA;
                    6'h1C: fog_start    <= S_AXI_WDATA;
                    6'h1D: shadow_bias  <= S_AXI_WDATA;
                    6'h21: time_phase   <= S_AXI_WDATA;     // 0x84: per-frame animation counter
                    6'h22: shadow_on    <= S_AXI_WDATA[0];  // 0x88: runtime shadow toggle
                    6'h23: max_depth    <= S_AXI_WDATA[3:0]; // 0x8C: traversal depth cap
                    default: ;
                endcase
            end

            // Write response
            if (S_AXI_WREADY && S_AXI_WVALID) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00; // OKAY
            end else if (S_AXI_BREADY)
                S_AXI_BVALID <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Read channel
    // -------------------------------------------------------------------------
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= '0;
            S_AXI_RVALID  <= '0;
            S_AXI_RDATA   <= '0;
            S_AXI_RRESP   <= '0;
        end else begin
            if (S_AXI_ARVALID && !S_AXI_ARREADY) begin
                S_AXI_ARREADY <= 1'b1;
                S_AXI_RVALID  <= 1'b1;
                S_AXI_RRESP   <= 2'b00;
                unique case (S_AXI_ARADDR[7:2])
                    6'h01:   S_AXI_RDATA <= {30'd0, status_frame_done, status_busy};
                    // 0x78: bits[3:0]=FSM state, bit[4]=tvalid, bit[5]=tready, bits[9:6]=rs_wait
                    // state=12 + tvalid=1 + tready=0 means VDMA is applying backpressure
                    // state=1 + rs_wait stuck means S_RAY_SETUP hang
                    6'h1E:   S_AXI_RDATA <= {22'd0, dbg_rs_wait, dbg_tready, dbg_tvalid, dbg_state};
                    // 0x7C: pixel position — bits[16:8]=px, bits[7:0]=py
                    6'h1F:   S_AXI_RDATA <= {15'd0, dbg_px, dbg_py};
                    // 0x80: multi-ray core internals (per-slot state + arbiter flags)
                    6'h20:   S_AXI_RDATA <= dbg_mr;
                    default: S_AXI_RDATA <= 32'hDEAD_BEEF;
                endcase
            end else begin
                S_AXI_ARREADY <= 1'b0;
                if (S_AXI_RREADY) S_AXI_RVALID <= 1'b0;
            end
        end
    end

endmodule

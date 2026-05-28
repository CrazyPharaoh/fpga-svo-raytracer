// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vtop__pch.h"

Vtop__Syms::Vtop__Syms(VerilatedContext* contextp, const char* namep, Vtop* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    // Setup top module instance
    , TOP{this, namep}
{
    // Check resources
    Verilated::stackCheck(2396);
    // Setup sub module instances
    // Configure time unit / time precision
    _vm_contextp__->timeunit(-9);
    _vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
    // Setup each module's pointer back to symbol table (for public functions)
    TOP.__Vconfigure(true);
    // Setup scopes
    __Vscopep_TOP = new VerilatedScope{this, "TOP", "TOP", "<null>", 0, VerilatedScope::SCOPE_OTHER};
    __Vscopep_svo_traversal = new VerilatedScope{this, "svo_traversal", "svo_traversal", "svo_traversal", -9, VerilatedScope::SCOPE_MODULE};
    // Set up scope hierarchy
    __Vhier.add(0, __Vscopep_svo_traversal);
    // Setup export functions - final: 0
    // Setup export functions - final: 1
    // Setup public variables
    __Vscopep_TOP->varInsert("any_hit", &(TOP.any_hit), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("axis_tdata", &(TOP.axis_tdata), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("axis_tlast", &(TOP.axis_tlast), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("axis_tready", &(TOP.axis_tready), false, VLVT_UINT8, VLVD_IN|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("axis_tuser", &(TOP.axis_tuser), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 1 ,0,0);
    __Vscopep_TOP->varInsert("axis_tvalid", &(TOP.axis_tvalid), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("busy", &(TOP.busy), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("cam_fwd_x", &(TOP.cam_fwd_x), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_fwd_y", &(TOP.cam_fwd_y), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_fwd_z", &(TOP.cam_fwd_z), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_pos_x", &(TOP.cam_pos_x), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_pos_y", &(TOP.cam_pos_y), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_pos_z", &(TOP.cam_pos_z), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_right_x", &(TOP.cam_right_x), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_right_y", &(TOP.cam_right_y), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_right_z", &(TOP.cam_right_z), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_scale", &(TOP.cam_scale), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_up_x", &(TOP.cam_up_x), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_up_y", &(TOP.cam_up_y), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("cam_up_z", &(TOP.cam_up_z), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("clk", &(TOP.clk), false, VLVT_UINT8, VLVD_IN|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("dbg_px", &(TOP.dbg_px), false, VLVT_UINT16, VLVD_OUT|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 1 ,8,0);
    __Vscopep_TOP->varInsert("dbg_py", &(TOP.dbg_py), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 1 ,7,0);
    __Vscopep_TOP->varInsert("dbg_rs_wait", &(TOP.dbg_rs_wait), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 1 ,4,0);
    __Vscopep_TOP->varInsert("dbg_state", &(TOP.dbg_state), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 1 ,3,0);
    __Vscopep_TOP->varInsert("dbg_tready", &(TOP.dbg_tready), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
    __Vscopep_TOP->varInsert("dbg_tvalid", &(TOP.dbg_tvalid), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
    __Vscopep_TOP->varInsert("fb_wr_addr", &(TOP.fb_wr_addr), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW, 0, 1 ,16,0);
    __Vscopep_TOP->varInsert("fb_wr_data", &(TOP.fb_wr_data), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW, 0, 1 ,23,0);
    __Vscopep_TOP->varInsert("fb_wr_en", &(TOP.fb_wr_en), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("frame_done", &(TOP.frame_done), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("rst", &(TOP.rst), false, VLVT_UINT8, VLVD_IN|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("shade_block_id", &(TOP.shade_block_id), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 1 ,7,0);
    __Vscopep_TOP->varInsert("shade_done", &(TOP.shade_done), false, VLVT_UINT8, VLVD_IN|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("shade_hit_face", &(TOP.shade_hit_face), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 1 ,1,0);
    __Vscopep_TOP->varInsert("shade_hit_face_sign", &(TOP.shade_hit_face_sign), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("shade_hit_px", &(TOP.shade_hit_px), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("shade_hit_py", &(TOP.shade_hit_py), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("shade_hit_pz", &(TOP.shade_hit_pz), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("shade_is_miss", &(TOP.shade_is_miss), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("shade_pixel_color", &(TOP.shade_pixel_color), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW, 0, 1 ,23,0);
    __Vscopep_TOP->varInsert("shade_ray_dx", &(TOP.shade_ray_dx), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("shade_ray_dy", &(TOP.shade_ray_dy), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("shade_ray_dz", &(TOP.shade_ray_dz), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("shade_start", &(TOP.shade_start), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("shade_t_hit", &(TOP.shade_t_hit), false, VLVT_UINT32, VLVD_OUT|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("sky_color", &(TOP.sky_color), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW, 0, 1 ,23,0);
    __Vscopep_TOP->varInsert("start", &(TOP.start), false, VLVT_UINT8, VLVD_IN|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("svo_rd_addr", &(TOP.svo_rd_addr), false, VLVT_UINT16, VLVD_OUT|VLVF_PUB_RW, 0, 1 ,14,0);
    __Vscopep_TOP->varInsert("svo_rd_data", &(TOP.svo_rd_data), false, VLVT_UINT32, VLVD_IN|VLVF_PUB_RW, 0, 1 ,31,0);
    __Vscopep_TOP->varInsert("svo_rd_en", &(TOP.svo_rd_en), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("IMG_H", const_cast<void*>(static_cast<const void*>(&(TOP.svo_traversal__DOT__IMG_H))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("IMG_W", const_cast<void*>(static_cast<const void*>(&(TOP.svo_traversal__DOT__IMG_W))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("SHADE_MODE", const_cast<void*>(static_cast<const void*>(&(TOP.svo_traversal__DOT__SHADE_MODE))), true, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_BITVAR, 0, 0);
    __Vscopep_svo_traversal->varInsert("SHADOW_MODE", const_cast<void*>(static_cast<const void*>(&(TOP.svo_traversal__DOT__SHADOW_MODE))), true, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_BITVAR, 0, 0);
    __Vscopep_svo_traversal->varInsert("STACK_DEPTH", const_cast<void*>(static_cast<const void*>(&(TOP.svo_traversal__DOT__STACK_DEPTH))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("WORLD_SIZE", const_cast<void*>(static_cast<const void*>(&(TOP.svo_traversal__DOT__WORLD_SIZE))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("any_hit", &(TOP.svo_traversal__DOT__any_hit), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("axis_tdata", &(TOP.svo_traversal__DOT__axis_tdata), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("axis_tlast", &(TOP.svo_traversal__DOT__axis_tlast), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("axis_tready", &(TOP.svo_traversal__DOT__axis_tready), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("axis_tuser", &(TOP.svo_traversal__DOT__axis_tuser), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,0,0);
    __Vscopep_svo_traversal->varInsert("axis_tvalid", &(TOP.svo_traversal__DOT__axis_tvalid), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("bitmask", &(TOP.svo_traversal__DOT__bitmask), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,15,0);
    __Vscopep_svo_traversal->varInsert("block_id_hit", &(TOP.svo_traversal__DOT__block_id_hit), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,7,0);
    __Vscopep_svo_traversal->varInsert("bram_field", &(TOP.svo_traversal__DOT__bram_field), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,2,0);
    __Vscopep_svo_traversal->varInsert("busy", &(TOP.svo_traversal__DOT__busy), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("bw_abs_ix_c", &(TOP.svo_traversal__DOT__bw_abs_ix_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_abs_iy_c", &(TOP.svo_traversal__DOT__bw_abs_iy_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_abs_iz_c", &(TOP.svo_traversal__DOT__bw_abs_iz_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_dist_x_c", &(TOP.svo_traversal__DOT__bw_dist_x_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_dist_y_c", &(TOP.svo_traversal__DOT__bw_dist_y_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_dist_z_c", &(TOP.svo_traversal__DOT__bw_dist_z_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_ex_c", &(TOP.svo_traversal__DOT__bw_ex_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_ex_rel_c", &(TOP.svo_traversal__DOT__bw_ex_rel_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_ey_c", &(TOP.svo_traversal__DOT__bw_ey_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_ey_rel_c", &(TOP.svo_traversal__DOT__bw_ey_rel_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_ez_c", &(TOP.svo_traversal__DOT__bw_ez_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_ez_rel_c", &(TOP.svo_traversal__DOT__bw_ez_rel_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("bw_icx_c", &(TOP.svo_traversal__DOT__bw_icx_c), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,6,0);
    __Vscopep_svo_traversal->varInsert("bw_icy_c", &(TOP.svo_traversal__DOT__bw_icy_c), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,6,0);
    __Vscopep_svo_traversal->varInsert("bw_icz_c", &(TOP.svo_traversal__DOT__bw_icz_c), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,6,0);
    __Vscopep_svo_traversal->varInsert("bw_nh_c", &(TOP.svo_traversal__DOT__bw_nh_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_fwd_x", &(TOP.svo_traversal__DOT__cam_fwd_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_fwd_y", &(TOP.svo_traversal__DOT__cam_fwd_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_fwd_z", &(TOP.svo_traversal__DOT__cam_fwd_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_pos_x", &(TOP.svo_traversal__DOT__cam_pos_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_pos_y", &(TOP.svo_traversal__DOT__cam_pos_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_pos_z", &(TOP.svo_traversal__DOT__cam_pos_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_right_x", &(TOP.svo_traversal__DOT__cam_right_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_right_y", &(TOP.svo_traversal__DOT__cam_right_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_right_z", &(TOP.svo_traversal__DOT__cam_right_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_scale", &(TOP.svo_traversal__DOT__cam_scale), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_up_x", &(TOP.svo_traversal__DOT__cam_up_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_up_y", &(TOP.svo_traversal__DOT__cam_up_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cam_up_z", &(TOP.svo_traversal__DOT__cam_up_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("cidx", &(TOP.svo_traversal__DOT__cidx), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,2,0);
    __Vscopep_svo_traversal->varInsert("clk", &(TOP.svo_traversal__DOT__clk), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("cx", &(TOP.svo_traversal__DOT__cx), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,5,0);
    __Vscopep_svo_traversal->varInsert("cy", &(TOP.svo_traversal__DOT__cy), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,5,0);
    __Vscopep_svo_traversal->varInsert("cz", &(TOP.svo_traversal__DOT__cz), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,5,0);
    __Vscopep_svo_traversal->varInsert("dbg_px", &(TOP.svo_traversal__DOT__dbg_px), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 1 ,8,0);
    __Vscopep_svo_traversal->varInsert("dbg_py", &(TOP.svo_traversal__DOT__dbg_py), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 1 ,7,0);
    __Vscopep_svo_traversal->varInsert("dbg_rs_wait", &(TOP.svo_traversal__DOT__dbg_rs_wait), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 1 ,4,0);
    __Vscopep_svo_traversal->varInsert("dbg_state", &(TOP.svo_traversal__DOT__dbg_state), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 1 ,3,0);
    __Vscopep_svo_traversal->varInsert("dbg_tready", &(TOP.svo_traversal__DOT__dbg_tready), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
    __Vscopep_svo_traversal->varInsert("dbg_tvalid", &(TOP.svo_traversal__DOT__dbg_tvalid), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
    __Vscopep_svo_traversal->varInsert("dt_x", &(TOP.svo_traversal__DOT__dt_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("dt_x_bw_c", &(TOP.svo_traversal__DOT__dt_x_bw_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("dt_x_pop_c", &(TOP.svo_traversal__DOT__dt_x_pop_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("dt_y", &(TOP.svo_traversal__DOT__dt_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("dt_y_bw_c", &(TOP.svo_traversal__DOT__dt_y_bw_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("dt_y_pop_c", &(TOP.svo_traversal__DOT__dt_y_pop_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("dt_z", &(TOP.svo_traversal__DOT__dt_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("dt_z_bw_c", &(TOP.svo_traversal__DOT__dt_z_bw_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("dt_z_pop_c", &(TOP.svo_traversal__DOT__dt_z_pop_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("em_face", &(TOP.svo_traversal__DOT__em_face), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,1,0);
    __Vscopep_svo_traversal->varInsert("em_fsign", &(TOP.svo_traversal__DOT__em_fsign), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("fb_wr_addr", &(TOP.svo_traversal__DOT__fb_wr_addr), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,16,0);
    __Vscopep_svo_traversal->varInsert("fb_wr_data", &(TOP.svo_traversal__DOT__fb_wr_data), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,23,0);
    __Vscopep_svo_traversal->varInsert("fb_wr_en", &(TOP.svo_traversal__DOT__fb_wr_en), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("frame_done", &(TOP.svo_traversal__DOT__frame_done), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("hit_face", &(TOP.svo_traversal__DOT__hit_face), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,1,0);
    __Vscopep_svo_traversal->varInsert("hit_face_sign_r", &(TOP.svo_traversal__DOT__hit_face_sign_r), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("hit_px_r", &(TOP.svo_traversal__DOT__hit_px_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("hit_py_r", &(TOP.svo_traversal__DOT__hit_py_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("hit_pz_r", &(TOP.svo_traversal__DOT__hit_pz_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("inv_x", &(TOP.svo_traversal__DOT__inv_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("inv_y", &(TOP.svo_traversal__DOT__inv_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("inv_z", &(TOP.svo_traversal__DOT__inv_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("node_half", &(TOP.svo_traversal__DOT__node_half), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,5,0);
    __Vscopep_svo_traversal->varInsert("node_idx", &(TOP.svo_traversal__DOT__node_idx), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,15,0);
    __Vscopep_svo_traversal->varInsert("node_origin_x", &(TOP.svo_traversal__DOT__node_origin_x), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,5,0);
    __Vscopep_svo_traversal->varInsert("node_origin_y", &(TOP.svo_traversal__DOT__node_origin_y), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,5,0);
    __Vscopep_svo_traversal->varInsert("node_origin_z", &(TOP.svo_traversal__DOT__node_origin_z), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,5,0);
    __Vscopep_svo_traversal->varInsert("pixel_color", &(TOP.svo_traversal__DOT__pixel_color), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,23,0);
    __Vscopep_svo_traversal->varInsert("post_pop", &(TOP.svo_traversal__DOT__post_pop), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("px", &(TOP.svo_traversal__DOT__px), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,8,0);
    __Vscopep_svo_traversal->varInsert("py", &(TOP.svo_traversal__DOT__py), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,7,0);
    __Vscopep_svo_traversal->varInsert("r_bitmask", &(TOP.svo_traversal__DOT__r_bitmask), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,15,0);
    __Vscopep_svo_traversal->varInsert("r_block", &(TOP.svo_traversal__DOT__r_block), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,7 ,7,0);
    __Vscopep_svo_traversal->varInsert("r_child", &(TOP.svo_traversal__DOT__r_child), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,7 ,15,0);
    __Vscopep_svo_traversal->varInsert("rd_x", &(TOP.svo_traversal__DOT__rd_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rd_y", &(TOP.svo_traversal__DOT__rd_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rd_z", &(TOP.svo_traversal__DOT__rd_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("ro_x", &(TOP.svo_traversal__DOT__ro_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("ro_y", &(TOP.svo_traversal__DOT__ro_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("ro_z", &(TOP.svo_traversal__DOT__ro_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_ax_r", &(TOP.svo_traversal__DOT__rs_ax_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_ay_r", &(TOP.svo_traversal__DOT__rs_ay_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_az_r", &(TOP.svo_traversal__DOT__rs_az_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_ndx_r", &(TOP.svo_traversal__DOT__rs_ndx_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_ndy_r", &(TOP.svo_traversal__DOT__rs_ndy_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_ndz_r", &(TOP.svo_traversal__DOT__rs_ndz_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_r0x_r", &(TOP.svo_traversal__DOT__rs_r0x_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_r0y_r", &(TOP.svo_traversal__DOT__rs_r0y_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_r0z_r", &(TOP.svo_traversal__DOT__rs_r0z_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_r1x_r", &(TOP.svo_traversal__DOT__rs_r1x_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_r1y_r", &(TOP.svo_traversal__DOT__rs_r1y_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_r1z_r", &(TOP.svo_traversal__DOT__rs_r1z_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rilinv2_r", &(TOP.svo_traversal__DOT__rs_rilinv2_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rilinv_r", &(TOP.svo_traversal__DOT__rs_rilinv_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rilsq_r", &(TOP.svo_traversal__DOT__rs_rilsq_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rilsub_r", &(TOP.svo_traversal__DOT__rs_rilsub_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_riltmp_r", &(TOP.svo_traversal__DOT__rs_riltmp_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rma_x_r", &(TOP.svo_traversal__DOT__rs_rma_x_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rma_y_r", &(TOP.svo_traversal__DOT__rs_rma_y_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rma_z_r", &(TOP.svo_traversal__DOT__rs_rma_z_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rmb_x_r", &(TOP.svo_traversal__DOT__rs_rmb_x_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rmb_y_r", &(TOP.svo_traversal__DOT__rs_rmb_y_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rmb_z_r", &(TOP.svo_traversal__DOT__rs_rmb_z_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rsdx_r", &(TOP.svo_traversal__DOT__rs_rsdx_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rsdy_r", &(TOP.svo_traversal__DOT__rs_rsdy_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rsdz_r", &(TOP.svo_traversal__DOT__rs_rsdz_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rslen2_r", &(TOP.svo_traversal__DOT__rs_rslen2_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rsu_r", &(TOP.svo_traversal__DOT__rs_rsu_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_rsv_r", &(TOP.svo_traversal__DOT__rs_rsv_r), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_tmp", &(TOP.svo_traversal__DOT__rs_tmp), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_tx0", &(TOP.svo_traversal__DOT__rs_tx0), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_tx1", &(TOP.svo_traversal__DOT__rs_tx1), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_ty0", &(TOP.svo_traversal__DOT__rs_ty0), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_ty1", &(TOP.svo_traversal__DOT__rs_ty1), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_tz0", &(TOP.svo_traversal__DOT__rs_tz0), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_tz1", &(TOP.svo_traversal__DOT__rs_tz1), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rs_wait", &(TOP.svo_traversal__DOT__rs_wait), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,4,0);
    __Vscopep_svo_traversal->varInsert("rs_world_q", &(TOP.svo_traversal__DOT__rs_world_q), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("rst", &(TOP.svo_traversal__DOT__rst), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("shade_block_id", &(TOP.svo_traversal__DOT__shade_block_id), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,7,0);
    __Vscopep_svo_traversal->varInsert("shade_done", &(TOP.svo_traversal__DOT__shade_done), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("shade_hit_face", &(TOP.svo_traversal__DOT__shade_hit_face), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,1,0);
    __Vscopep_svo_traversal->varInsert("shade_hit_face_sign", &(TOP.svo_traversal__DOT__shade_hit_face_sign), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("shade_hit_px", &(TOP.svo_traversal__DOT__shade_hit_px), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("shade_hit_py", &(TOP.svo_traversal__DOT__shade_hit_py), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("shade_hit_pz", &(TOP.svo_traversal__DOT__shade_hit_pz), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("shade_is_miss", &(TOP.svo_traversal__DOT__shade_is_miss), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("shade_pixel_color", &(TOP.svo_traversal__DOT__shade_pixel_color), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,23,0);
    __Vscopep_svo_traversal->varInsert("shade_ray_dx", &(TOP.svo_traversal__DOT__shade_ray_dx), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("shade_ray_dy", &(TOP.svo_traversal__DOT__shade_ray_dy), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("shade_ray_dz", &(TOP.svo_traversal__DOT__shade_ray_dz), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("shade_start", &(TOP.svo_traversal__DOT__shade_start), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("shade_t_hit", &(TOP.svo_traversal__DOT__shade_t_hit), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("sky_color", &(TOP.svo_traversal__DOT__sky_color), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,23,0);
    __Vscopep_svo_traversal->varInsert("sp", &(TOP.svo_traversal__DOT__sp), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,3,0);
    __Vscopep_svo_traversal->varInsert("start", &(TOP.svo_traversal__DOT__start), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("state", &(TOP.svo_traversal__DOT__state), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,3,0);
    __Vscopep_svo_traversal->varInsert("state_raw", &(TOP.svo_traversal__DOT__state_raw), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 1 ,3,0);
    __Vscopep_svo_traversal->varInsert("step_x", &(TOP.svo_traversal__DOT__step_x), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,2,0);
    __Vscopep_svo_traversal->varInsert("step_y", &(TOP.svo_traversal__DOT__step_y), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,2,0);
    __Vscopep_svo_traversal->varInsert("step_z", &(TOP.svo_traversal__DOT__step_z), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,2,0);
    __Vscopep_svo_traversal->varInsert("stk_bitmask", &(TOP.svo_traversal__DOT__stk_bitmask), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,11 ,15,0);
    __Vscopep_svo_traversal->varInsert("stk_cx", &(TOP.svo_traversal__DOT__stk_cx), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,11 ,5,0);
    __Vscopep_svo_traversal->varInsert("stk_cy", &(TOP.svo_traversal__DOT__stk_cy), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,11 ,5,0);
    __Vscopep_svo_traversal->varInsert("stk_cz", &(TOP.svo_traversal__DOT__stk_cz), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,11 ,5,0);
    __Vscopep_svo_traversal->varInsert("stk_node_half", &(TOP.svo_traversal__DOT__stk_node_half), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,11 ,5,0);
    __Vscopep_svo_traversal->varInsert("stk_node_idx", &(TOP.svo_traversal__DOT__stk_node_idx), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,11 ,15,0);
    __Vscopep_svo_traversal->varInsert("stk_orig_x", &(TOP.svo_traversal__DOT__stk_orig_x), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,11 ,5,0);
    __Vscopep_svo_traversal->varInsert("stk_orig_y", &(TOP.svo_traversal__DOT__stk_orig_y), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,11 ,5,0);
    __Vscopep_svo_traversal->varInsert("stk_orig_z", &(TOP.svo_traversal__DOT__stk_orig_z), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 1, 1 ,0,11 ,5,0);
    __Vscopep_svo_traversal->varInsert("stk_t_max", &(TOP.svo_traversal__DOT__stk_t_max), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 1, 1 ,0,11 ,31,0);
    __Vscopep_svo_traversal->varInsert("stk_t_min", &(TOP.svo_traversal__DOT__stk_t_min), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 1, 1 ,0,11 ,31,0);
    __Vscopep_svo_traversal->varInsert("stk_t_next_x", &(TOP.svo_traversal__DOT__stk_t_next_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 1, 1 ,0,11 ,31,0);
    __Vscopep_svo_traversal->varInsert("stk_t_next_y", &(TOP.svo_traversal__DOT__stk_t_next_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 1, 1 ,0,11 ,31,0);
    __Vscopep_svo_traversal->varInsert("stk_t_next_z", &(TOP.svo_traversal__DOT__stk_t_next_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 1, 1 ,0,11 ,31,0);
    __Vscopep_svo_traversal->varInsert("svo_rd_addr", &(TOP.svo_traversal__DOT__svo_rd_addr), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,14,0);
    __Vscopep_svo_traversal->varInsert("svo_rd_data", &(TOP.svo_traversal__DOT__svo_rd_data), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("svo_rd_en", &(TOP.svo_traversal__DOT__svo_rd_en), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_svo_traversal->varInsert("t_hit", &(TOP.svo_traversal__DOT__t_hit), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("t_max", &(TOP.svo_traversal__DOT__t_max), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("t_min", &(TOP.svo_traversal__DOT__t_min), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("t_next_x", &(TOP.svo_traversal__DOT__t_next_x), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("t_next_x_bw_c", &(TOP.svo_traversal__DOT__t_next_x_bw_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("t_next_y", &(TOP.svo_traversal__DOT__t_next_y), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("t_next_y_bw_c", &(TOP.svo_traversal__DOT__t_next_y_bw_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("t_next_z", &(TOP.svo_traversal__DOT__t_next_z), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_svo_traversal->varInsert("t_next_z_bw_c", &(TOP.svo_traversal__DOT__t_next_z_bw_c), false, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY|VLVF_SIGNED, 0, 1 ,31,0);
}

Vtop__Syms::~Vtop__Syms() {
    // Tear down scope hierarchy
    __Vhier.remove(0, __Vscopep_svo_traversal);
    // Clear keys from hierarchy map after values have been removed
    __Vhier.clear();
    // Tear down scopes
    VL_DO_CLEAR(delete __Vscopep_TOP, __Vscopep_TOP = nullptr);
    VL_DO_CLEAR(delete __Vscopep_svo_traversal, __Vscopep_svo_traversal = nullptr);
    // Tear down sub module instances
}

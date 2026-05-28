// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtop.h for the primary calling header

#include "Vtop__pch.h"

VL_ATTR_COLD void Vtop___024root___eval_static(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_static\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__Vtrigprevexpr___TOP__svo_traversal__DOT__clk__0 
        = vlSelfRef.svo_traversal__DOT__clk;
}

VL_ATTR_COLD void Vtop___024root___eval_initial(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_initial\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vtop___024root___eval_final(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_final\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtop___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vtop___024root___eval_phase__stl(Vtop___024root* vlSelf);

VL_ATTR_COLD void Vtop___024root___eval_settle(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_settle\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VstlIterCount;
    // Body
    __VstlIterCount = 0U;
    vlSelfRef.__VstlFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VstlIterCount)))) {
#ifdef VL_DEBUG
            Vtop___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
            VL_FATAL_MT("/home/ali/git/fyp/vivado/ip/svo_raytracer/hdl/svo_traversal.sv", 14, "", "DIDNOTCONVERGE: Settle region did not converge after '--converge-limit' of 10000 tries");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
        vlSelfRef.__VstlPhaseResult = Vtop___024root___eval_phase__stl(vlSelf);
        vlSelfRef.__VstlFirstIteration = 0U;
    } while (vlSelfRef.__VstlPhaseResult);
}

VL_ATTR_COLD void Vtop___024root___eval_triggers_vec__stl(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_triggers_vec__stl\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered[0U]) 
                                     | (IData)((IData)(vlSelfRef.__VstlFirstIteration)));
}

VL_ATTR_COLD bool Vtop___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtop___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(Vtop___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vtop___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___trigger_anySet__stl\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vtop___024root___ico_sequent__TOP__0(Vtop___024root* vlSelf);

VL_ATTR_COLD void Vtop___024root___eval_stl(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_stl\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VstlTriggered[0U])) {
        Vtop___024root___ico_sequent__TOP__0(vlSelf);
    }
}

VL_ATTR_COLD bool Vtop___024root___eval_phase__stl(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_phase__stl\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VstlExecute;
    // Body
    Vtop___024root___eval_triggers_vec__stl(vlSelf);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtop___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
    __VstlExecute = Vtop___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        Vtop___024root___eval_stl(vlSelf);
    }
    return (__VstlExecute);
}

bool Vtop___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtop___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(Vtop___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

bool Vtop___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtop___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(Vtop___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge svo_traversal.clk)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtop___024root___ctor_var_reset(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___ctor_var_reset\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelf->clk = 0;
    vlSelf->rst = 0;
    vlSelf->start = 0;
    vlSelf->cam_pos_x = 0;
    vlSelf->cam_pos_y = 0;
    vlSelf->cam_pos_z = 0;
    vlSelf->cam_right_x = 0;
    vlSelf->cam_right_y = 0;
    vlSelf->cam_right_z = 0;
    vlSelf->cam_up_x = 0;
    vlSelf->cam_up_y = 0;
    vlSelf->cam_up_z = 0;
    vlSelf->cam_fwd_x = 0;
    vlSelf->cam_fwd_y = 0;
    vlSelf->cam_fwd_z = 0;
    vlSelf->cam_scale = 0;
    vlSelf->sky_color = 0;
    vlSelf->svo_rd_addr = 0;
    vlSelf->svo_rd_data = 0;
    vlSelf->svo_rd_en = 0;
    vlSelf->fb_wr_addr = 0;
    vlSelf->fb_wr_data = 0;
    vlSelf->fb_wr_en = 0;
    vlSelf->axis_tvalid = 0;
    vlSelf->axis_tdata = 0;
    vlSelf->axis_tlast = 0;
    vlSelf->axis_tuser = 0;
    vlSelf->axis_tready = 0;
    vlSelf->shade_start = 0;
    vlSelf->shade_is_miss = 0;
    vlSelf->shade_hit_face = 0;
    vlSelf->shade_hit_face_sign = 0;
    vlSelf->shade_block_id = 0;
    vlSelf->shade_t_hit = 0;
    vlSelf->shade_ray_dx = 0;
    vlSelf->shade_ray_dy = 0;
    vlSelf->shade_ray_dz = 0;
    vlSelf->shade_hit_px = 0;
    vlSelf->shade_hit_py = 0;
    vlSelf->shade_hit_pz = 0;
    vlSelf->shade_done = 0;
    vlSelf->shade_pixel_color = 0;
    vlSelf->busy = 0;
    vlSelf->frame_done = 0;
    vlSelf->any_hit = 0;
    vlSelf->dbg_state = 0;
    vlSelf->dbg_rs_wait = 0;
    vlSelf->dbg_px = 0;
    vlSelf->dbg_py = 0;
    vlSelf->dbg_tvalid = 0;
    vlSelf->dbg_tready = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_habf6d040__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h9d41b6af__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h6831e3f2__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h881263f8__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_hb13d1bf5__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h00e6080f__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_hd4ed9f67__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h4b07ddb1__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h1738f021__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h10022533__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h46c1a37b__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h20b934f4__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h5d517a59__0 = 0;
    vlSelf->svo_traversal__DOT____Vlvbound_h3fbd9737__0 = 0;
    vlSelf->svo_traversal__DOT__clk = 0;
    vlSelf->svo_traversal__DOT__rst = 0;
    vlSelf->svo_traversal__DOT__start = 0;
    vlSelf->svo_traversal__DOT__cam_pos_x = 0;
    vlSelf->svo_traversal__DOT__cam_pos_y = 0;
    vlSelf->svo_traversal__DOT__cam_pos_z = 0;
    vlSelf->svo_traversal__DOT__cam_right_x = 0;
    vlSelf->svo_traversal__DOT__cam_right_y = 0;
    vlSelf->svo_traversal__DOT__cam_right_z = 0;
    vlSelf->svo_traversal__DOT__cam_up_x = 0;
    vlSelf->svo_traversal__DOT__cam_up_y = 0;
    vlSelf->svo_traversal__DOT__cam_up_z = 0;
    vlSelf->svo_traversal__DOT__cam_fwd_x = 0;
    vlSelf->svo_traversal__DOT__cam_fwd_y = 0;
    vlSelf->svo_traversal__DOT__cam_fwd_z = 0;
    vlSelf->svo_traversal__DOT__cam_scale = 0;
    vlSelf->svo_traversal__DOT__sky_color = 0;
    vlSelf->svo_traversal__DOT__svo_rd_addr = 0;
    vlSelf->svo_traversal__DOT__svo_rd_data = 0;
    vlSelf->svo_traversal__DOT__svo_rd_en = 0;
    vlSelf->svo_traversal__DOT__fb_wr_addr = 0;
    vlSelf->svo_traversal__DOT__fb_wr_data = 0;
    vlSelf->svo_traversal__DOT__fb_wr_en = 0;
    vlSelf->svo_traversal__DOT__axis_tvalid = 0;
    vlSelf->svo_traversal__DOT__axis_tdata = 0;
    vlSelf->svo_traversal__DOT__axis_tlast = 0;
    vlSelf->svo_traversal__DOT__axis_tuser = 0;
    vlSelf->svo_traversal__DOT__axis_tready = 0;
    vlSelf->svo_traversal__DOT__shade_start = 0;
    vlSelf->svo_traversal__DOT__shade_is_miss = 0;
    vlSelf->svo_traversal__DOT__shade_hit_face = 0;
    vlSelf->svo_traversal__DOT__shade_hit_face_sign = 0;
    vlSelf->svo_traversal__DOT__shade_block_id = 0;
    vlSelf->svo_traversal__DOT__shade_t_hit = 0;
    vlSelf->svo_traversal__DOT__shade_ray_dx = 0;
    vlSelf->svo_traversal__DOT__shade_ray_dy = 0;
    vlSelf->svo_traversal__DOT__shade_ray_dz = 0;
    vlSelf->svo_traversal__DOT__shade_hit_px = 0;
    vlSelf->svo_traversal__DOT__shade_hit_py = 0;
    vlSelf->svo_traversal__DOT__shade_hit_pz = 0;
    vlSelf->svo_traversal__DOT__shade_done = 0;
    vlSelf->svo_traversal__DOT__shade_pixel_color = 0;
    vlSelf->svo_traversal__DOT__busy = 0;
    vlSelf->svo_traversal__DOT__frame_done = 0;
    vlSelf->svo_traversal__DOT__any_hit = 0;
    vlSelf->svo_traversal__DOT__dbg_state = 0;
    vlSelf->svo_traversal__DOT__dbg_rs_wait = 0;
    vlSelf->svo_traversal__DOT__dbg_px = 0;
    vlSelf->svo_traversal__DOT__dbg_py = 0;
    vlSelf->svo_traversal__DOT__dbg_tvalid = 0;
    vlSelf->svo_traversal__DOT__dbg_tready = 0;
    vlSelf->svo_traversal__DOT__state = 0;
    vlSelf->svo_traversal__DOT__state_raw = 0;
    vlSelf->svo_traversal__DOT__px = 0;
    vlSelf->svo_traversal__DOT__py = 0;
    vlSelf->svo_traversal__DOT__ro_x = 0;
    vlSelf->svo_traversal__DOT__ro_y = 0;
    vlSelf->svo_traversal__DOT__ro_z = 0;
    vlSelf->svo_traversal__DOT__rd_x = 0;
    vlSelf->svo_traversal__DOT__rd_y = 0;
    vlSelf->svo_traversal__DOT__rd_z = 0;
    vlSelf->svo_traversal__DOT__inv_x = 0;
    vlSelf->svo_traversal__DOT__inv_y = 0;
    vlSelf->svo_traversal__DOT__inv_z = 0;
    vlSelf->svo_traversal__DOT__t_min = 0;
    vlSelf->svo_traversal__DOT__t_max = 0;
    vlSelf->svo_traversal__DOT__t_next_x = 0;
    vlSelf->svo_traversal__DOT__t_next_y = 0;
    vlSelf->svo_traversal__DOT__t_next_z = 0;
    vlSelf->svo_traversal__DOT__dt_x = 0;
    vlSelf->svo_traversal__DOT__dt_y = 0;
    vlSelf->svo_traversal__DOT__dt_z = 0;
    vlSelf->svo_traversal__DOT__step_x = 0;
    vlSelf->svo_traversal__DOT__step_y = 0;
    vlSelf->svo_traversal__DOT__step_z = 0;
    vlSelf->svo_traversal__DOT__cx = 0;
    vlSelf->svo_traversal__DOT__cy = 0;
    vlSelf->svo_traversal__DOT__cz = 0;
    vlSelf->svo_traversal__DOT__node_half = 0;
    vlSelf->svo_traversal__DOT__node_origin_x = 0;
    vlSelf->svo_traversal__DOT__node_origin_y = 0;
    vlSelf->svo_traversal__DOT__node_origin_z = 0;
    vlSelf->svo_traversal__DOT__rs_tx0 = 0;
    vlSelf->svo_traversal__DOT__rs_tx1 = 0;
    vlSelf->svo_traversal__DOT__rs_ty0 = 0;
    vlSelf->svo_traversal__DOT__rs_ty1 = 0;
    vlSelf->svo_traversal__DOT__rs_tz0 = 0;
    vlSelf->svo_traversal__DOT__rs_tz1 = 0;
    vlSelf->svo_traversal__DOT__rs_world_q = 0;
    vlSelf->svo_traversal__DOT__rs_tmp = 0;
    vlSelf->svo_traversal__DOT__bw_icx_c = 0;
    vlSelf->svo_traversal__DOT__bw_icy_c = 0;
    vlSelf->svo_traversal__DOT__bw_icz_c = 0;
    vlSelf->svo_traversal__DOT__em_face = 0;
    vlSelf->svo_traversal__DOT__em_fsign = 0;
    vlSelf->svo_traversal__DOT__rs_rsu_r = 0;
    vlSelf->svo_traversal__DOT__rs_rsv_r = 0;
    vlSelf->svo_traversal__DOT__rs_rsdx_r = 0;
    vlSelf->svo_traversal__DOT__rs_rsdy_r = 0;
    vlSelf->svo_traversal__DOT__rs_rsdz_r = 0;
    vlSelf->svo_traversal__DOT__rs_rslen2_r = 0;
    vlSelf->svo_traversal__DOT__rs_rilinv_r = 0;
    vlSelf->svo_traversal__DOT__rs_rilsq_r = 0;
    vlSelf->svo_traversal__DOT__rs_riltmp_r = 0;
    vlSelf->svo_traversal__DOT__rs_rilsub_r = 0;
    vlSelf->svo_traversal__DOT__rs_rilinv2_r = 0;
    vlSelf->svo_traversal__DOT__rs_ndx_r = 0;
    vlSelf->svo_traversal__DOT__rs_ndy_r = 0;
    vlSelf->svo_traversal__DOT__rs_ndz_r = 0;
    vlSelf->svo_traversal__DOT__rs_ax_r = 0;
    vlSelf->svo_traversal__DOT__rs_ay_r = 0;
    vlSelf->svo_traversal__DOT__rs_az_r = 0;
    vlSelf->svo_traversal__DOT__rs_r0x_r = 0;
    vlSelf->svo_traversal__DOT__rs_r0y_r = 0;
    vlSelf->svo_traversal__DOT__rs_r0z_r = 0;
    vlSelf->svo_traversal__DOT__rs_rma_x_r = 0;
    vlSelf->svo_traversal__DOT__rs_rma_y_r = 0;
    vlSelf->svo_traversal__DOT__rs_rma_z_r = 0;
    vlSelf->svo_traversal__DOT__rs_r1x_r = 0;
    vlSelf->svo_traversal__DOT__rs_r1y_r = 0;
    vlSelf->svo_traversal__DOT__rs_r1z_r = 0;
    vlSelf->svo_traversal__DOT__rs_rmb_x_r = 0;
    vlSelf->svo_traversal__DOT__rs_rmb_y_r = 0;
    vlSelf->svo_traversal__DOT__rs_rmb_z_r = 0;
    vlSelf->svo_traversal__DOT__node_idx = 0;
    vlSelf->svo_traversal__DOT__bitmask = 0;
    vlSelf->svo_traversal__DOT__cidx = 0;
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->svo_traversal__DOT__r_child[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->svo_traversal__DOT__r_block[__Vi0] = 0;
    }
    vlSelf->svo_traversal__DOT__r_bitmask = 0;
    vlSelf->svo_traversal__DOT__bram_field = 0;
    vlSelf->svo_traversal__DOT__block_id_hit = 0;
    vlSelf->svo_traversal__DOT__t_hit = 0;
    vlSelf->svo_traversal__DOT__hit_face = 0;
    vlSelf->svo_traversal__DOT__hit_face_sign_r = 0;
    vlSelf->svo_traversal__DOT__hit_px_r = 0;
    vlSelf->svo_traversal__DOT__hit_py_r = 0;
    vlSelf->svo_traversal__DOT__hit_pz_r = 0;
    vlSelf->svo_traversal__DOT__sp = 0;
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_node_idx[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_bitmask[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_t_min[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_t_max[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_t_next_x[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_t_next_y[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_t_next_z[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_cx[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_cy[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_cz[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_node_half[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_orig_x[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_orig_y[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 12; ++__Vi0) {
        vlSelf->svo_traversal__DOT__stk_orig_z[__Vi0] = 0;
    }
    vlSelf->svo_traversal__DOT__pixel_color = 0;
    vlSelf->svo_traversal__DOT__rs_wait = 0;
    vlSelf->svo_traversal__DOT__post_pop = 0;
    vlSelf->svo_traversal__DOT__bw_ex_c = 0;
    vlSelf->svo_traversal__DOT__bw_ey_c = 0;
    vlSelf->svo_traversal__DOT__bw_ez_c = 0;
    vlSelf->svo_traversal__DOT__bw_abs_ix_c = 0;
    vlSelf->svo_traversal__DOT__bw_abs_iy_c = 0;
    vlSelf->svo_traversal__DOT__bw_abs_iz_c = 0;
    vlSelf->svo_traversal__DOT__bw_nh_c = 0;
    vlSelf->svo_traversal__DOT__dt_x_bw_c = 0;
    vlSelf->svo_traversal__DOT__dt_y_bw_c = 0;
    vlSelf->svo_traversal__DOT__dt_z_bw_c = 0;
    vlSelf->svo_traversal__DOT__bw_ex_rel_c = 0;
    vlSelf->svo_traversal__DOT__bw_ey_rel_c = 0;
    vlSelf->svo_traversal__DOT__bw_ez_rel_c = 0;
    vlSelf->svo_traversal__DOT__bw_dist_x_c = 0;
    vlSelf->svo_traversal__DOT__bw_dist_y_c = 0;
    vlSelf->svo_traversal__DOT__bw_dist_z_c = 0;
    vlSelf->svo_traversal__DOT__t_next_x_bw_c = 0;
    vlSelf->svo_traversal__DOT__t_next_y_bw_c = 0;
    vlSelf->svo_traversal__DOT__t_next_z_bw_c = 0;
    vlSelf->svo_traversal__DOT__dt_x_pop_c = 0;
    vlSelf->svo_traversal__DOT__dt_y_pop_c = 0;
    vlSelf->svo_traversal__DOT__dt_z_pop_c = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VstlTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VicoTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VactTriggered[__Vi0] = 0;
    }
    vlSelf->__Vtrigprevexpr___TOP__svo_traversal__DOT__clk__0 = 0;
    vlSelf->__VactDidInit = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VnbaTriggered[__Vi0] = 0;
    }
}

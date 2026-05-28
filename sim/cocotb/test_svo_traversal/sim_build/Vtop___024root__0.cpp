// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtop.h for the primary calling header

#include "Vtop__pch.h"

void Vtop___024root___eval_triggers_vec__ico(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_triggers_vec__ico\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[0U]) 
                                     | (IData)((IData)(vlSelfRef.__VicoFirstIteration)));
}

bool Vtop___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___trigger_anySet__ico\n"); );
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

void Vtop___024root___ico_sequent__TOP__0(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___ico_sequent__TOP__0\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__9__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__9__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__9__a;
    __Vfunc_svo_traversal__DOT__qmul__9__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__9__b;
    __Vfunc_svo_traversal__DOT__qmul__9__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__9__p;
    __Vfunc_svo_traversal__DOT__qmul__9__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__10__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__10__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__10__a;
    __Vfunc_svo_traversal__DOT__qmul__10__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__10__b;
    __Vfunc_svo_traversal__DOT__qmul__10__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__10__p;
    __Vfunc_svo_traversal__DOT__qmul__10__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__11__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__11__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__11__a;
    __Vfunc_svo_traversal__DOT__qmul__11__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__11__b;
    __Vfunc_svo_traversal__DOT__qmul__11__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__11__p;
    __Vfunc_svo_traversal__DOT__qmul__11__p = 0;
    // Body
    vlSelfRef.svo_traversal__DOT__clk = vlSelfRef.clk;
    vlSelfRef.svo_traversal__DOT__rst = vlSelfRef.rst;
    vlSelfRef.svo_traversal__DOT__start = vlSelfRef.start;
    vlSelfRef.svo_traversal__DOT__cam_pos_x = vlSelfRef.cam_pos_x;
    vlSelfRef.svo_traversal__DOT__cam_pos_y = vlSelfRef.cam_pos_y;
    vlSelfRef.svo_traversal__DOT__cam_pos_z = vlSelfRef.cam_pos_z;
    vlSelfRef.svo_traversal__DOT__cam_right_x = vlSelfRef.cam_right_x;
    vlSelfRef.svo_traversal__DOT__cam_right_y = vlSelfRef.cam_right_y;
    vlSelfRef.svo_traversal__DOT__cam_right_z = vlSelfRef.cam_right_z;
    vlSelfRef.svo_traversal__DOT__cam_up_x = vlSelfRef.cam_up_x;
    vlSelfRef.svo_traversal__DOT__cam_up_y = vlSelfRef.cam_up_y;
    vlSelfRef.svo_traversal__DOT__cam_up_z = vlSelfRef.cam_up_z;
    vlSelfRef.svo_traversal__DOT__cam_fwd_x = vlSelfRef.cam_fwd_x;
    vlSelfRef.svo_traversal__DOT__cam_fwd_y = vlSelfRef.cam_fwd_y;
    vlSelfRef.svo_traversal__DOT__cam_fwd_z = vlSelfRef.cam_fwd_z;
    vlSelfRef.svo_traversal__DOT__cam_scale = vlSelfRef.cam_scale;
    vlSelfRef.svo_traversal__DOT__sky_color = vlSelfRef.sky_color;
    vlSelfRef.svo_rd_addr = vlSelfRef.svo_traversal__DOT__svo_rd_addr;
    vlSelfRef.svo_traversal__DOT__svo_rd_data = vlSelfRef.svo_rd_data;
    vlSelfRef.svo_rd_en = vlSelfRef.svo_traversal__DOT__svo_rd_en;
    vlSelfRef.fb_wr_addr = vlSelfRef.svo_traversal__DOT__fb_wr_addr;
    vlSelfRef.fb_wr_data = vlSelfRef.svo_traversal__DOT__fb_wr_data;
    vlSelfRef.fb_wr_en = vlSelfRef.svo_traversal__DOT__fb_wr_en;
    vlSelfRef.axis_tvalid = vlSelfRef.svo_traversal__DOT__axis_tvalid;
    vlSelfRef.axis_tdata = vlSelfRef.svo_traversal__DOT__axis_tdata;
    vlSelfRef.axis_tlast = vlSelfRef.svo_traversal__DOT__axis_tlast;
    vlSelfRef.axis_tuser = vlSelfRef.svo_traversal__DOT__axis_tuser;
    vlSelfRef.shade_start = vlSelfRef.svo_traversal__DOT__shade_start;
    vlSelfRef.shade_is_miss = vlSelfRef.svo_traversal__DOT__shade_is_miss;
    vlSelfRef.shade_hit_face = vlSelfRef.svo_traversal__DOT__shade_hit_face;
    vlSelfRef.shade_hit_face_sign = vlSelfRef.svo_traversal__DOT__shade_hit_face_sign;
    vlSelfRef.shade_block_id = vlSelfRef.svo_traversal__DOT__shade_block_id;
    vlSelfRef.shade_t_hit = vlSelfRef.svo_traversal__DOT__shade_t_hit;
    vlSelfRef.shade_ray_dx = vlSelfRef.svo_traversal__DOT__shade_ray_dx;
    vlSelfRef.shade_ray_dy = vlSelfRef.svo_traversal__DOT__shade_ray_dy;
    vlSelfRef.shade_ray_dz = vlSelfRef.svo_traversal__DOT__shade_ray_dz;
    vlSelfRef.shade_hit_px = vlSelfRef.svo_traversal__DOT__shade_hit_px;
    vlSelfRef.shade_hit_py = vlSelfRef.svo_traversal__DOT__shade_hit_py;
    vlSelfRef.shade_hit_pz = vlSelfRef.svo_traversal__DOT__shade_hit_pz;
    vlSelfRef.svo_traversal__DOT__shade_done = vlSelfRef.shade_done;
    vlSelfRef.svo_traversal__DOT__shade_pixel_color 
        = vlSelfRef.shade_pixel_color;
    vlSelfRef.busy = vlSelfRef.svo_traversal__DOT__busy;
    vlSelfRef.frame_done = vlSelfRef.svo_traversal__DOT__frame_done;
    vlSelfRef.any_hit = vlSelfRef.svo_traversal__DOT__any_hit;
    vlSelfRef.svo_traversal__DOT__dbg_tvalid = vlSelfRef.svo_traversal__DOT__axis_tvalid;
    vlSelfRef.svo_traversal__DOT__dbg_rs_wait = vlSelfRef.svo_traversal__DOT__rs_wait;
    vlSelfRef.svo_traversal__DOT__dbg_px = vlSelfRef.svo_traversal__DOT__px;
    vlSelfRef.svo_traversal__DOT__dbg_py = vlSelfRef.svo_traversal__DOT__py;
    vlSelfRef.svo_traversal__DOT__axis_tready = vlSelfRef.axis_tready;
    vlSelfRef.svo_traversal__DOT__state_raw = vlSelfRef.svo_traversal__DOT__state;
    vlSelfRef.svo_traversal__DOT__bw_ex_c = (vlSelfRef.svo_traversal__DOT__ro_x 
                                             + (IData)(
                                                       (VL_MULS_QQQ(64, 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__t_min), 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__rd_x)) 
                                                        >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_ey_c = (vlSelfRef.svo_traversal__DOT__ro_y 
                                             + (IData)(
                                                       (VL_MULS_QQQ(64, 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__t_min), 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__rd_y)) 
                                                        >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_ez_c = (vlSelfRef.svo_traversal__DOT__ro_z 
                                             + (IData)(
                                                       (VL_MULS_QQQ(64, 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__t_min), 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__rd_z)) 
                                                        >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_abs_ix_c = ((vlSelfRef.svo_traversal__DOT__inv_x 
                                                  >> 0x0000001fU)
                                                  ? 
                                                 (- vlSelfRef.svo_traversal__DOT__inv_x)
                                                  : vlSelfRef.svo_traversal__DOT__inv_x);
    vlSelfRef.svo_traversal__DOT__bw_abs_iy_c = ((vlSelfRef.svo_traversal__DOT__inv_y 
                                                  >> 0x0000001fU)
                                                  ? 
                                                 (- vlSelfRef.svo_traversal__DOT__inv_y)
                                                  : vlSelfRef.svo_traversal__DOT__inv_y);
    vlSelfRef.svo_traversal__DOT__bw_abs_iz_c = ((vlSelfRef.svo_traversal__DOT__inv_z 
                                                  >> 0x0000001fU)
                                                  ? 
                                                 (- vlSelfRef.svo_traversal__DOT__inv_z)
                                                  : vlSelfRef.svo_traversal__DOT__inv_z);
    vlSelfRef.svo_traversal__DOT__bw_nh_c = VL_SHIFTL_III(32,32,32, (IData)(vlSelfRef.svo_traversal__DOT__node_half), 0x00000010U);
    vlSelfRef.dbg_tvalid = vlSelfRef.svo_traversal__DOT__dbg_tvalid;
    vlSelfRef.dbg_rs_wait = vlSelfRef.svo_traversal__DOT__dbg_rs_wait;
    vlSelfRef.dbg_px = vlSelfRef.svo_traversal__DOT__dbg_px;
    vlSelfRef.dbg_py = vlSelfRef.svo_traversal__DOT__dbg_py;
    vlSelfRef.svo_traversal__DOT__dbg_tready = vlSelfRef.svo_traversal__DOT__axis_tready;
    vlSelfRef.svo_traversal__DOT__dbg_state = vlSelfRef.svo_traversal__DOT__state_raw;
    __Vfunc_svo_traversal__DOT__qmul__9__b = vlSelfRef.svo_traversal__DOT__bw_abs_ix_c;
    __Vfunc_svo_traversal__DOT__qmul__9__a = (((0x0bU 
                                                >= 
                                                (0x0000000fU 
                                                 & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                    - (IData)(1U))))
                                                ? vlSelfRef.svo_traversal__DOT__stk_node_half
                                               [(0x0000000fU 
                                                 & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                    - (IData)(1U)))]
                                                : 0U) 
                                              << 0x00000010U);
    __Vfunc_svo_traversal__DOT__qmul__9__p = VL_MULS_QQQ(64, 
                                                         VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__9__a), 
                                                         VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__9__b));
    __Vfunc_svo_traversal__DOT__qmul__9__Vfuncout = (IData)(
                                                            (__Vfunc_svo_traversal__DOT__qmul__9__p 
                                                             >> 0x10U));
    vlSelfRef.svo_traversal__DOT__dt_x_pop_c = __Vfunc_svo_traversal__DOT__qmul__9__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__10__b = vlSelfRef.svo_traversal__DOT__bw_abs_iy_c;
    __Vfunc_svo_traversal__DOT__qmul__10__a = (((0x0bU 
                                                 >= 
                                                 (0x0000000fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                     - (IData)(1U))))
                                                 ? vlSelfRef.svo_traversal__DOT__stk_node_half
                                                [(0x0000000fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                     - (IData)(1U)))]
                                                 : 0U) 
                                               << 0x00000010U);
    __Vfunc_svo_traversal__DOT__qmul__10__p = VL_MULS_QQQ(64, 
                                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__10__a), 
                                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__10__b));
    __Vfunc_svo_traversal__DOT__qmul__10__Vfuncout 
        = (IData)((__Vfunc_svo_traversal__DOT__qmul__10__p 
                   >> 0x10U));
    vlSelfRef.svo_traversal__DOT__dt_y_pop_c = __Vfunc_svo_traversal__DOT__qmul__10__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__11__b = vlSelfRef.svo_traversal__DOT__bw_abs_iz_c;
    __Vfunc_svo_traversal__DOT__qmul__11__a = (((0x0bU 
                                                 >= 
                                                 (0x0000000fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                     - (IData)(1U))))
                                                 ? vlSelfRef.svo_traversal__DOT__stk_node_half
                                                [(0x0000000fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                     - (IData)(1U)))]
                                                 : 0U) 
                                               << 0x00000010U);
    __Vfunc_svo_traversal__DOT__qmul__11__p = VL_MULS_QQQ(64, 
                                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__11__a), 
                                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__11__b));
    __Vfunc_svo_traversal__DOT__qmul__11__Vfuncout 
        = (IData)((__Vfunc_svo_traversal__DOT__qmul__11__p 
                   >> 0x10U));
    vlSelfRef.svo_traversal__DOT__dt_z_pop_c = __Vfunc_svo_traversal__DOT__qmul__11__Vfuncout;
    vlSelfRef.svo_traversal__DOT__dt_x_bw_c = (IData)(
                                                      (VL_MULS_QQQ(64, 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_nh_c), 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_ix_c)) 
                                                       >> 0x00000010U));
    vlSelfRef.svo_traversal__DOT__dt_y_bw_c = (IData)(
                                                      (VL_MULS_QQQ(64, 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_nh_c), 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_iy_c)) 
                                                       >> 0x00000010U));
    vlSelfRef.svo_traversal__DOT__dt_z_bw_c = (IData)(
                                                      (VL_MULS_QQQ(64, 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_nh_c), 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_iz_c)) 
                                                       >> 0x00000010U));
    vlSelfRef.svo_traversal__DOT__bw_icx_c = (VL_GTS_III(32, 0U, vlSelfRef.svo_traversal__DOT__bw_ex_c)
                                               ? 0U
                                               : (0x0000007fU 
                                                  & (vlSelfRef.svo_traversal__DOT__bw_ex_c 
                                                     >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_icx_c = (((IData)(vlSelfRef.svo_traversal__DOT__bw_icx_c) 
                                               >= (IData)(vlSelfRef.svo_traversal__DOT__node_origin_x))
                                               ? (0x0000007fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__bw_icx_c) 
                                                     - (IData)(vlSelfRef.svo_traversal__DOT__node_origin_x)))
                                               : 0U);
    vlSelfRef.svo_traversal__DOT__bw_ex_rel_c = (vlSelfRef.svo_traversal__DOT__bw_ex_c 
                                                 - 
                                                 VL_SHIFTL_III(32,32,32, (IData)(vlSelfRef.svo_traversal__DOT__node_origin_x), 0x00000010U));
    vlSelfRef.svo_traversal__DOT__bw_dist_x_c = ((4U 
                                                  & (IData)(vlSelfRef.svo_traversal__DOT__step_x))
                                                  ? 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icx_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (vlSelfRef.svo_traversal__DOT__bw_ex_rel_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_nh_c)
                                                   : vlSelfRef.svo_traversal__DOT__bw_ex_rel_c)
                                                  : 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icx_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (VL_SHIFTL_III(32,32,32, vlSelfRef.svo_traversal__DOT__bw_nh_c, 1U) 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ex_rel_c)
                                                   : 
                                                  (vlSelfRef.svo_traversal__DOT__bw_nh_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ex_rel_c)));
    vlSelfRef.svo_traversal__DOT__bw_icy_c = (VL_GTS_III(32, 0U, vlSelfRef.svo_traversal__DOT__bw_ey_c)
                                               ? 0U
                                               : (0x0000007fU 
                                                  & (vlSelfRef.svo_traversal__DOT__bw_ey_c 
                                                     >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_icy_c = (((IData)(vlSelfRef.svo_traversal__DOT__bw_icy_c) 
                                               >= (IData)(vlSelfRef.svo_traversal__DOT__node_origin_y))
                                               ? (0x0000007fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__bw_icy_c) 
                                                     - (IData)(vlSelfRef.svo_traversal__DOT__node_origin_y)))
                                               : 0U);
    vlSelfRef.svo_traversal__DOT__bw_ey_rel_c = (vlSelfRef.svo_traversal__DOT__bw_ey_c 
                                                 - 
                                                 VL_SHIFTL_III(32,32,32, (IData)(vlSelfRef.svo_traversal__DOT__node_origin_y), 0x00000010U));
    vlSelfRef.svo_traversal__DOT__bw_dist_y_c = ((4U 
                                                  & (IData)(vlSelfRef.svo_traversal__DOT__step_y))
                                                  ? 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icy_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (vlSelfRef.svo_traversal__DOT__bw_ey_rel_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_nh_c)
                                                   : vlSelfRef.svo_traversal__DOT__bw_ey_rel_c)
                                                  : 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icy_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (VL_SHIFTL_III(32,32,32, vlSelfRef.svo_traversal__DOT__bw_nh_c, 1U) 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ey_rel_c)
                                                   : 
                                                  (vlSelfRef.svo_traversal__DOT__bw_nh_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ey_rel_c)));
    vlSelfRef.svo_traversal__DOT__bw_icz_c = (VL_GTS_III(32, 0U, vlSelfRef.svo_traversal__DOT__bw_ez_c)
                                               ? 0U
                                               : (0x0000007fU 
                                                  & (vlSelfRef.svo_traversal__DOT__bw_ez_c 
                                                     >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_icz_c = (((IData)(vlSelfRef.svo_traversal__DOT__bw_icz_c) 
                                               >= (IData)(vlSelfRef.svo_traversal__DOT__node_origin_z))
                                               ? (0x0000007fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__bw_icz_c) 
                                                     - (IData)(vlSelfRef.svo_traversal__DOT__node_origin_z)))
                                               : 0U);
    vlSelfRef.svo_traversal__DOT__bw_ez_rel_c = (vlSelfRef.svo_traversal__DOT__bw_ez_c 
                                                 - 
                                                 VL_SHIFTL_III(32,32,32, (IData)(vlSelfRef.svo_traversal__DOT__node_origin_z), 0x00000010U));
    vlSelfRef.svo_traversal__DOT__bw_dist_z_c = ((4U 
                                                  & (IData)(vlSelfRef.svo_traversal__DOT__step_z))
                                                  ? 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icz_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (vlSelfRef.svo_traversal__DOT__bw_ez_rel_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_nh_c)
                                                   : vlSelfRef.svo_traversal__DOT__bw_ez_rel_c)
                                                  : 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icz_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (VL_SHIFTL_III(32,32,32, vlSelfRef.svo_traversal__DOT__bw_nh_c, 1U) 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ez_rel_c)
                                                   : 
                                                  (vlSelfRef.svo_traversal__DOT__bw_nh_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ez_rel_c)));
    vlSelfRef.dbg_tready = vlSelfRef.svo_traversal__DOT__dbg_tready;
    vlSelfRef.dbg_state = vlSelfRef.svo_traversal__DOT__dbg_state;
    vlSelfRef.svo_traversal__DOT__t_next_x_bw_c = (vlSelfRef.svo_traversal__DOT__t_min 
                                                   + (IData)(
                                                             (VL_MULS_QQQ(64, 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_ix_c), 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_dist_x_c)) 
                                                              >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__t_next_y_bw_c = (vlSelfRef.svo_traversal__DOT__t_min 
                                                   + (IData)(
                                                             (VL_MULS_QQQ(64, 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_iy_c), 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_dist_y_c)) 
                                                              >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__t_next_z_bw_c = (vlSelfRef.svo_traversal__DOT__t_min 
                                                   + (IData)(
                                                             (VL_MULS_QQQ(64, 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_iz_c), 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_dist_z_c)) 
                                                              >> 0x00000010U)));
}

void Vtop___024root___eval_ico(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_ico\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VicoTriggered[0U])) {
        Vtop___024root___ico_sequent__TOP__0(vlSelf);
    }
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtop___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vtop___024root___eval_phase__ico(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_phase__ico\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VicoExecute;
    // Body
    Vtop___024root___eval_triggers_vec__ico(vlSelf);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtop___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    __VicoExecute = Vtop___024root___trigger_anySet__ico(vlSelfRef.__VicoTriggered);
    if (__VicoExecute) {
        Vtop___024root___eval_ico(vlSelf);
    }
    return (__VicoExecute);
}

void Vtop___024root___eval_triggers_vec__act(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_triggers_vec__act\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                    ((IData)(vlSelfRef.svo_traversal__DOT__clk) 
                                                     & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__svo_traversal__DOT__clk__0)))));
    vlSelfRef.__Vtrigprevexpr___TOP__svo_traversal__DOT__clk__0 
        = vlSelfRef.svo_traversal__DOT__clk;
    if (VL_UNLIKELY(((1U & (~ (IData)(vlSelfRef.__VactDidInit)))))) {
        vlSelfRef.__VactDidInit = 1U;
        vlSelfRef.__VactTriggered[0U] = (1ULL | vlSelfRef.__VactTriggered[0U]);
    }
}

bool Vtop___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___trigger_anySet__act\n"); );
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

void Vtop___024root___nba_sequent__TOP__0(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___nba_sequent__TOP__0\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__9__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__9__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__9__a;
    __Vfunc_svo_traversal__DOT__qmul__9__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__9__b;
    __Vfunc_svo_traversal__DOT__qmul__9__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__9__p;
    __Vfunc_svo_traversal__DOT__qmul__9__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__10__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__10__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__10__a;
    __Vfunc_svo_traversal__DOT__qmul__10__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__10__b;
    __Vfunc_svo_traversal__DOT__qmul__10__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__10__p;
    __Vfunc_svo_traversal__DOT__qmul__10__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__11__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__11__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__11__a;
    __Vfunc_svo_traversal__DOT__qmul__11__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__11__b;
    __Vfunc_svo_traversal__DOT__qmul__11__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__11__p;
    __Vfunc_svo_traversal__DOT__qmul__11__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__12__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__12__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__12__a;
    __Vfunc_svo_traversal__DOT__qmul__12__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__12__b;
    __Vfunc_svo_traversal__DOT__qmul__12__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__12__p;
    __Vfunc_svo_traversal__DOT__qmul__12__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__13__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__13__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__13__a;
    __Vfunc_svo_traversal__DOT__qmul__13__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__13__b;
    __Vfunc_svo_traversal__DOT__qmul__13__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__13__p;
    __Vfunc_svo_traversal__DOT__qmul__13__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__14__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__14__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__14__a;
    __Vfunc_svo_traversal__DOT__qmul__14__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__14__b;
    __Vfunc_svo_traversal__DOT__qmul__14__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__14__p;
    __Vfunc_svo_traversal__DOT__qmul__14__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__15__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__15__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__15__a;
    __Vfunc_svo_traversal__DOT__qmul__15__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__15__b;
    __Vfunc_svo_traversal__DOT__qmul__15__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__15__p;
    __Vfunc_svo_traversal__DOT__qmul__15__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__16__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__16__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__16__a;
    __Vfunc_svo_traversal__DOT__qmul__16__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__16__b;
    __Vfunc_svo_traversal__DOT__qmul__16__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__16__p;
    __Vfunc_svo_traversal__DOT__qmul__16__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__17__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__17__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__17__a;
    __Vfunc_svo_traversal__DOT__qmul__17__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__17__b;
    __Vfunc_svo_traversal__DOT__qmul__17__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__17__p;
    __Vfunc_svo_traversal__DOT__qmul__17__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__18__a;
    __Vfunc_svo_traversal__DOT__qmul__18__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__18__b;
    __Vfunc_svo_traversal__DOT__qmul__18__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__18__p;
    __Vfunc_svo_traversal__DOT__qmul__18__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__19__a;
    __Vfunc_svo_traversal__DOT__qmul__19__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__19__b;
    __Vfunc_svo_traversal__DOT__qmul__19__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__19__p;
    __Vfunc_svo_traversal__DOT__qmul__19__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__20__a;
    __Vfunc_svo_traversal__DOT__qmul__20__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__20__b;
    __Vfunc_svo_traversal__DOT__qmul__20__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__20__p;
    __Vfunc_svo_traversal__DOT__qmul__20__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__21__a;
    __Vfunc_svo_traversal__DOT__qmul__21__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__21__b;
    __Vfunc_svo_traversal__DOT__qmul__21__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__21__p;
    __Vfunc_svo_traversal__DOT__qmul__21__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__22__a;
    __Vfunc_svo_traversal__DOT__qmul__22__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__22__b;
    __Vfunc_svo_traversal__DOT__qmul__22__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__22__p;
    __Vfunc_svo_traversal__DOT__qmul__22__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__23__a;
    __Vfunc_svo_traversal__DOT__qmul__23__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__23__b;
    __Vfunc_svo_traversal__DOT__qmul__23__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__23__p;
    __Vfunc_svo_traversal__DOT__qmul__23__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__24__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__24__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__24__a;
    __Vfunc_svo_traversal__DOT__qmul__24__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__24__b;
    __Vfunc_svo_traversal__DOT__qmul__24__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__24__p;
    __Vfunc_svo_traversal__DOT__qmul__24__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__25__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__25__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__25__a;
    __Vfunc_svo_traversal__DOT__qmul__25__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__25__b;
    __Vfunc_svo_traversal__DOT__qmul__25__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__25__p;
    __Vfunc_svo_traversal__DOT__qmul__25__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__26__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__26__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__26__a;
    __Vfunc_svo_traversal__DOT__qmul__26__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__26__b;
    __Vfunc_svo_traversal__DOT__qmul__26__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__26__p;
    __Vfunc_svo_traversal__DOT__qmul__26__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__27__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__27__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__27__a;
    __Vfunc_svo_traversal__DOT__qmul__27__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__27__b;
    __Vfunc_svo_traversal__DOT__qmul__27__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__27__p;
    __Vfunc_svo_traversal__DOT__qmul__27__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__28__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__28__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__28__a;
    __Vfunc_svo_traversal__DOT__qmul__28__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__28__b;
    __Vfunc_svo_traversal__DOT__qmul__28__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__28__p;
    __Vfunc_svo_traversal__DOT__qmul__28__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__29__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__29__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__29__a;
    __Vfunc_svo_traversal__DOT__qmul__29__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__29__b;
    __Vfunc_svo_traversal__DOT__qmul__29__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__29__p;
    __Vfunc_svo_traversal__DOT__qmul__29__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__30__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__30__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__30__a;
    __Vfunc_svo_traversal__DOT__qmul__30__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__30__b;
    __Vfunc_svo_traversal__DOT__qmul__30__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__30__p;
    __Vfunc_svo_traversal__DOT__qmul__30__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__31__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__31__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__31__a;
    __Vfunc_svo_traversal__DOT__qmul__31__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__31__b;
    __Vfunc_svo_traversal__DOT__qmul__31__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__31__p;
    __Vfunc_svo_traversal__DOT__qmul__31__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__32__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__32__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__32__a;
    __Vfunc_svo_traversal__DOT__qmul__32__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__32__b;
    __Vfunc_svo_traversal__DOT__qmul__32__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__32__p;
    __Vfunc_svo_traversal__DOT__qmul__32__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qrecip_r0__33__Vfuncout;
    __Vfunc_svo_traversal__DOT__qrecip_r0__33__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qrecip_r0__33__xabs;
    __Vfunc_svo_traversal__DOT__qrecip_r0__33__xabs = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qrecip_r0__34__Vfuncout;
    __Vfunc_svo_traversal__DOT__qrecip_r0__34__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qrecip_r0__34__xabs;
    __Vfunc_svo_traversal__DOT__qrecip_r0__34__xabs = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qrecip_r0__35__Vfuncout;
    __Vfunc_svo_traversal__DOT__qrecip_r0__35__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qrecip_r0__35__xabs;
    __Vfunc_svo_traversal__DOT__qrecip_r0__35__xabs = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__36__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__36__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__36__a;
    __Vfunc_svo_traversal__DOT__qmul__36__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__36__b;
    __Vfunc_svo_traversal__DOT__qmul__36__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__36__p;
    __Vfunc_svo_traversal__DOT__qmul__36__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__37__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__37__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__37__a;
    __Vfunc_svo_traversal__DOT__qmul__37__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__37__b;
    __Vfunc_svo_traversal__DOT__qmul__37__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__37__p;
    __Vfunc_svo_traversal__DOT__qmul__37__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__38__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__38__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__38__a;
    __Vfunc_svo_traversal__DOT__qmul__38__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__38__b;
    __Vfunc_svo_traversal__DOT__qmul__38__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__38__p;
    __Vfunc_svo_traversal__DOT__qmul__38__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__39__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__39__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__39__a;
    __Vfunc_svo_traversal__DOT__qmul__39__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__39__b;
    __Vfunc_svo_traversal__DOT__qmul__39__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__39__p;
    __Vfunc_svo_traversal__DOT__qmul__39__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__40__b;
    __Vfunc_svo_traversal__DOT__qmul__40__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__40__p;
    __Vfunc_svo_traversal__DOT__qmul__40__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__41__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__41__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__41__a;
    __Vfunc_svo_traversal__DOT__qmul__41__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__41__b;
    __Vfunc_svo_traversal__DOT__qmul__41__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__41__p;
    __Vfunc_svo_traversal__DOT__qmul__41__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__42__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__42__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__42__a;
    __Vfunc_svo_traversal__DOT__qmul__42__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__42__b;
    __Vfunc_svo_traversal__DOT__qmul__42__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__42__p;
    __Vfunc_svo_traversal__DOT__qmul__42__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__43__b;
    __Vfunc_svo_traversal__DOT__qmul__43__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__43__p;
    __Vfunc_svo_traversal__DOT__qmul__43__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__44__a;
    __Vfunc_svo_traversal__DOT__qmul__44__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__44__b;
    __Vfunc_svo_traversal__DOT__qmul__44__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__44__p;
    __Vfunc_svo_traversal__DOT__qmul__44__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__45__a;
    __Vfunc_svo_traversal__DOT__qmul__45__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__45__b;
    __Vfunc_svo_traversal__DOT__qmul__45__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__45__p;
    __Vfunc_svo_traversal__DOT__qmul__45__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__46__a;
    __Vfunc_svo_traversal__DOT__qmul__46__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__46__b;
    __Vfunc_svo_traversal__DOT__qmul__46__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__46__p;
    __Vfunc_svo_traversal__DOT__qmul__46__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__47__a;
    __Vfunc_svo_traversal__DOT__qmul__47__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__47__b;
    __Vfunc_svo_traversal__DOT__qmul__47__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__47__p;
    __Vfunc_svo_traversal__DOT__qmul__47__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__48__a;
    __Vfunc_svo_traversal__DOT__qmul__48__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__48__b;
    __Vfunc_svo_traversal__DOT__qmul__48__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__48__p;
    __Vfunc_svo_traversal__DOT__qmul__48__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__49__a;
    __Vfunc_svo_traversal__DOT__qmul__49__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__49__b;
    __Vfunc_svo_traversal__DOT__qmul__49__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__49__p;
    __Vfunc_svo_traversal__DOT__qmul__49__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__50__a;
    __Vfunc_svo_traversal__DOT__qmul__50__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__50__b;
    __Vfunc_svo_traversal__DOT__qmul__50__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__50__p;
    __Vfunc_svo_traversal__DOT__qmul__50__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__51__a;
    __Vfunc_svo_traversal__DOT__qmul__51__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__51__b;
    __Vfunc_svo_traversal__DOT__qmul__51__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__51__p;
    __Vfunc_svo_traversal__DOT__qmul__51__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__52__a;
    __Vfunc_svo_traversal__DOT__qmul__52__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__52__b;
    __Vfunc_svo_traversal__DOT__qmul__52__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__52__p;
    __Vfunc_svo_traversal__DOT__qmul__52__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__53__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__53__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__53__a;
    __Vfunc_svo_traversal__DOT__qmul__53__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__53__b;
    __Vfunc_svo_traversal__DOT__qmul__53__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__53__p;
    __Vfunc_svo_traversal__DOT__qmul__53__p = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__54__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__54__Vfuncout = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__54__a;
    __Vfunc_svo_traversal__DOT__qmul__54__a = 0;
    IData/*31:0*/ __Vfunc_svo_traversal__DOT__qmul__54__b;
    __Vfunc_svo_traversal__DOT__qmul__54__b = 0;
    QData/*63:0*/ __Vfunc_svo_traversal__DOT__qmul__54__p;
    __Vfunc_svo_traversal__DOT__qmul__54__p = 0;
    CData/*3:0*/ __Vdly__svo_traversal__DOT__state;
    __Vdly__svo_traversal__DOT__state = 0;
    SData/*8:0*/ __Vdly__svo_traversal__DOT__px;
    __Vdly__svo_traversal__DOT__px = 0;
    CData/*7:0*/ __Vdly__svo_traversal__DOT__py;
    __Vdly__svo_traversal__DOT__py = 0;
    CData/*3:0*/ __Vdly__svo_traversal__DOT__sp;
    __Vdly__svo_traversal__DOT__sp = 0;
    CData/*4:0*/ __Vdly__svo_traversal__DOT__rs_wait;
    __Vdly__svo_traversal__DOT__rs_wait = 0;
    CData/*0:0*/ __Vdly__svo_traversal__DOT__post_pop;
    __Vdly__svo_traversal__DOT__post_pop = 0;
    CData/*5:0*/ __Vdly__svo_traversal__DOT__node_half;
    __Vdly__svo_traversal__DOT__node_half = 0;
    SData/*15:0*/ __Vdly__svo_traversal__DOT__node_idx;
    __Vdly__svo_traversal__DOT__node_idx = 0;
    IData/*31:0*/ __Vdly__svo_traversal__DOT__dt_x;
    __Vdly__svo_traversal__DOT__dt_x = 0;
    IData/*31:0*/ __Vdly__svo_traversal__DOT__dt_y;
    __Vdly__svo_traversal__DOT__dt_y = 0;
    IData/*31:0*/ __Vdly__svo_traversal__DOT__dt_z;
    __Vdly__svo_traversal__DOT__dt_z = 0;
    SData/*15:0*/ __Vdly__svo_traversal__DOT__r_bitmask;
    __Vdly__svo_traversal__DOT__r_bitmask = 0;
    IData/*31:0*/ __Vdly__svo_traversal__DOT__t_min;
    __Vdly__svo_traversal__DOT__t_min = 0;
    IData/*31:0*/ __Vdly__svo_traversal__DOT__t_max;
    __Vdly__svo_traversal__DOT__t_max = 0;
    IData/*31:0*/ __Vdly__svo_traversal__DOT__t_next_x;
    __Vdly__svo_traversal__DOT__t_next_x = 0;
    IData/*31:0*/ __Vdly__svo_traversal__DOT__t_next_y;
    __Vdly__svo_traversal__DOT__t_next_y = 0;
    IData/*31:0*/ __Vdly__svo_traversal__DOT__t_next_z;
    __Vdly__svo_traversal__DOT__t_next_z = 0;
    CData/*5:0*/ __Vdly__svo_traversal__DOT__cx;
    __Vdly__svo_traversal__DOT__cx = 0;
    CData/*5:0*/ __Vdly__svo_traversal__DOT__cy;
    __Vdly__svo_traversal__DOT__cy = 0;
    CData/*5:0*/ __Vdly__svo_traversal__DOT__cz;
    __Vdly__svo_traversal__DOT__cz = 0;
    CData/*5:0*/ __Vdly__svo_traversal__DOT__node_origin_x;
    __Vdly__svo_traversal__DOT__node_origin_x = 0;
    CData/*5:0*/ __Vdly__svo_traversal__DOT__node_origin_y;
    __Vdly__svo_traversal__DOT__node_origin_y = 0;
    CData/*5:0*/ __Vdly__svo_traversal__DOT__node_origin_z;
    __Vdly__svo_traversal__DOT__node_origin_z = 0;
    CData/*2:0*/ __Vdly__svo_traversal__DOT__bram_field;
    __Vdly__svo_traversal__DOT__bram_field = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__stk_node_idx__v0;
    __VdlyVal__svo_traversal__DOT__stk_node_idx__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_node_idx__v0;
    __VdlyDim0__svo_traversal__DOT__stk_node_idx__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_node_idx__v0;
    __VdlySet__svo_traversal__DOT__stk_node_idx__v0 = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__stk_bitmask__v0;
    __VdlyVal__svo_traversal__DOT__stk_bitmask__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_bitmask__v0;
    __VdlyDim0__svo_traversal__DOT__stk_bitmask__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_bitmask__v0;
    __VdlySet__svo_traversal__DOT__stk_bitmask__v0 = 0;
    IData/*31:0*/ __VdlyVal__svo_traversal__DOT__stk_t_min__v0;
    __VdlyVal__svo_traversal__DOT__stk_t_min__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_t_min__v0;
    __VdlyDim0__svo_traversal__DOT__stk_t_min__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_t_min__v0;
    __VdlySet__svo_traversal__DOT__stk_t_min__v0 = 0;
    IData/*31:0*/ __VdlyVal__svo_traversal__DOT__stk_t_max__v0;
    __VdlyVal__svo_traversal__DOT__stk_t_max__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_t_max__v0;
    __VdlyDim0__svo_traversal__DOT__stk_t_max__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_t_max__v0;
    __VdlySet__svo_traversal__DOT__stk_t_max__v0 = 0;
    IData/*31:0*/ __VdlyVal__svo_traversal__DOT__stk_t_next_x__v0;
    __VdlyVal__svo_traversal__DOT__stk_t_next_x__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_t_next_x__v0;
    __VdlyDim0__svo_traversal__DOT__stk_t_next_x__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_t_next_x__v0;
    __VdlySet__svo_traversal__DOT__stk_t_next_x__v0 = 0;
    IData/*31:0*/ __VdlyVal__svo_traversal__DOT__stk_t_next_y__v0;
    __VdlyVal__svo_traversal__DOT__stk_t_next_y__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_t_next_y__v0;
    __VdlyDim0__svo_traversal__DOT__stk_t_next_y__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_t_next_y__v0;
    __VdlySet__svo_traversal__DOT__stk_t_next_y__v0 = 0;
    IData/*31:0*/ __VdlyVal__svo_traversal__DOT__stk_t_next_z__v0;
    __VdlyVal__svo_traversal__DOT__stk_t_next_z__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_t_next_z__v0;
    __VdlyDim0__svo_traversal__DOT__stk_t_next_z__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_t_next_z__v0;
    __VdlySet__svo_traversal__DOT__stk_t_next_z__v0 = 0;
    CData/*5:0*/ __VdlyVal__svo_traversal__DOT__stk_cx__v0;
    __VdlyVal__svo_traversal__DOT__stk_cx__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_cx__v0;
    __VdlyDim0__svo_traversal__DOT__stk_cx__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_cx__v0;
    __VdlySet__svo_traversal__DOT__stk_cx__v0 = 0;
    CData/*5:0*/ __VdlyVal__svo_traversal__DOT__stk_cy__v0;
    __VdlyVal__svo_traversal__DOT__stk_cy__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_cy__v0;
    __VdlyDim0__svo_traversal__DOT__stk_cy__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_cy__v0;
    __VdlySet__svo_traversal__DOT__stk_cy__v0 = 0;
    CData/*5:0*/ __VdlyVal__svo_traversal__DOT__stk_cz__v0;
    __VdlyVal__svo_traversal__DOT__stk_cz__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_cz__v0;
    __VdlyDim0__svo_traversal__DOT__stk_cz__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_cz__v0;
    __VdlySet__svo_traversal__DOT__stk_cz__v0 = 0;
    CData/*5:0*/ __VdlyVal__svo_traversal__DOT__stk_node_half__v0;
    __VdlyVal__svo_traversal__DOT__stk_node_half__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_node_half__v0;
    __VdlyDim0__svo_traversal__DOT__stk_node_half__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_node_half__v0;
    __VdlySet__svo_traversal__DOT__stk_node_half__v0 = 0;
    CData/*5:0*/ __VdlyVal__svo_traversal__DOT__stk_orig_x__v0;
    __VdlyVal__svo_traversal__DOT__stk_orig_x__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_orig_x__v0;
    __VdlyDim0__svo_traversal__DOT__stk_orig_x__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_orig_x__v0;
    __VdlySet__svo_traversal__DOT__stk_orig_x__v0 = 0;
    CData/*5:0*/ __VdlyVal__svo_traversal__DOT__stk_orig_y__v0;
    __VdlyVal__svo_traversal__DOT__stk_orig_y__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_orig_y__v0;
    __VdlyDim0__svo_traversal__DOT__stk_orig_y__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_orig_y__v0;
    __VdlySet__svo_traversal__DOT__stk_orig_y__v0 = 0;
    CData/*5:0*/ __VdlyVal__svo_traversal__DOT__stk_orig_z__v0;
    __VdlyVal__svo_traversal__DOT__stk_orig_z__v0 = 0;
    CData/*3:0*/ __VdlyDim0__svo_traversal__DOT__stk_orig_z__v0;
    __VdlyDim0__svo_traversal__DOT__stk_orig_z__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__stk_orig_z__v0;
    __VdlySet__svo_traversal__DOT__stk_orig_z__v0 = 0;
    CData/*7:0*/ __VdlyVal__svo_traversal__DOT__r_block__v0;
    __VdlyVal__svo_traversal__DOT__r_block__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_block__v0;
    __VdlySet__svo_traversal__DOT__r_block__v0 = 0;
    CData/*7:0*/ __VdlyVal__svo_traversal__DOT__r_block__v1;
    __VdlyVal__svo_traversal__DOT__r_block__v1 = 0;
    CData/*7:0*/ __VdlyVal__svo_traversal__DOT__r_block__v2;
    __VdlyVal__svo_traversal__DOT__r_block__v2 = 0;
    CData/*7:0*/ __VdlyVal__svo_traversal__DOT__r_block__v3;
    __VdlyVal__svo_traversal__DOT__r_block__v3 = 0;
    CData/*7:0*/ __VdlyVal__svo_traversal__DOT__r_block__v4;
    __VdlyVal__svo_traversal__DOT__r_block__v4 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_block__v4;
    __VdlySet__svo_traversal__DOT__r_block__v4 = 0;
    CData/*7:0*/ __VdlyVal__svo_traversal__DOT__r_block__v5;
    __VdlyVal__svo_traversal__DOT__r_block__v5 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_block__v5;
    __VdlySet__svo_traversal__DOT__r_block__v5 = 0;
    CData/*7:0*/ __VdlyVal__svo_traversal__DOT__r_block__v6;
    __VdlyVal__svo_traversal__DOT__r_block__v6 = 0;
    CData/*7:0*/ __VdlyVal__svo_traversal__DOT__r_block__v7;
    __VdlyVal__svo_traversal__DOT__r_block__v7 = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__r_child__v0;
    __VdlyVal__svo_traversal__DOT__r_child__v0 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_child__v0;
    __VdlySet__svo_traversal__DOT__r_child__v0 = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__r_child__v1;
    __VdlyVal__svo_traversal__DOT__r_child__v1 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_child__v1;
    __VdlySet__svo_traversal__DOT__r_child__v1 = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__r_child__v2;
    __VdlyVal__svo_traversal__DOT__r_child__v2 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_child__v2;
    __VdlySet__svo_traversal__DOT__r_child__v2 = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__r_child__v3;
    __VdlyVal__svo_traversal__DOT__r_child__v3 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_child__v3;
    __VdlySet__svo_traversal__DOT__r_child__v3 = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__r_child__v4;
    __VdlyVal__svo_traversal__DOT__r_child__v4 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_child__v4;
    __VdlySet__svo_traversal__DOT__r_child__v4 = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__r_child__v5;
    __VdlyVal__svo_traversal__DOT__r_child__v5 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_child__v5;
    __VdlySet__svo_traversal__DOT__r_child__v5 = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__r_child__v6;
    __VdlyVal__svo_traversal__DOT__r_child__v6 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_child__v6;
    __VdlySet__svo_traversal__DOT__r_child__v6 = 0;
    SData/*15:0*/ __VdlyVal__svo_traversal__DOT__r_child__v7;
    __VdlyVal__svo_traversal__DOT__r_child__v7 = 0;
    CData/*0:0*/ __VdlySet__svo_traversal__DOT__r_child__v7;
    __VdlySet__svo_traversal__DOT__r_child__v7 = 0;
    // Body
    __Vdly__svo_traversal__DOT__post_pop = vlSelfRef.svo_traversal__DOT__post_pop;
    __Vdly__svo_traversal__DOT__node_idx = vlSelfRef.svo_traversal__DOT__node_idx;
    __Vdly__svo_traversal__DOT__dt_x = vlSelfRef.svo_traversal__DOT__dt_x;
    __Vdly__svo_traversal__DOT__dt_y = vlSelfRef.svo_traversal__DOT__dt_y;
    __Vdly__svo_traversal__DOT__dt_z = vlSelfRef.svo_traversal__DOT__dt_z;
    __Vdly__svo_traversal__DOT__r_bitmask = vlSelfRef.svo_traversal__DOT__r_bitmask;
    __Vdly__svo_traversal__DOT__t_max = vlSelfRef.svo_traversal__DOT__t_max;
    __Vdly__svo_traversal__DOT__t_next_x = vlSelfRef.svo_traversal__DOT__t_next_x;
    __Vdly__svo_traversal__DOT__t_next_y = vlSelfRef.svo_traversal__DOT__t_next_y;
    __Vdly__svo_traversal__DOT__t_next_z = vlSelfRef.svo_traversal__DOT__t_next_z;
    __Vdly__svo_traversal__DOT__cx = vlSelfRef.svo_traversal__DOT__cx;
    __Vdly__svo_traversal__DOT__cy = vlSelfRef.svo_traversal__DOT__cy;
    __Vdly__svo_traversal__DOT__cz = vlSelfRef.svo_traversal__DOT__cz;
    __Vdly__svo_traversal__DOT__bram_field = vlSelfRef.svo_traversal__DOT__bram_field;
    __VdlySet__svo_traversal__DOT__stk_node_idx__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_bitmask__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_t_min__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_t_max__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_t_next_x__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_t_next_y__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_t_next_z__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_cx__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_cy__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_cz__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_orig_x__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_orig_y__v0 = 0U;
    __VdlySet__svo_traversal__DOT__stk_orig_z__v0 = 0U;
    __Vdly__svo_traversal__DOT__px = vlSelfRef.svo_traversal__DOT__px;
    __Vdly__svo_traversal__DOT__py = vlSelfRef.svo_traversal__DOT__py;
    __Vdly__svo_traversal__DOT__rs_wait = vlSelfRef.svo_traversal__DOT__rs_wait;
    __Vdly__svo_traversal__DOT__state = vlSelfRef.svo_traversal__DOT__state;
    __VdlySet__svo_traversal__DOT__r_block__v0 = 0U;
    __VdlySet__svo_traversal__DOT__r_block__v4 = 0U;
    __VdlySet__svo_traversal__DOT__r_block__v5 = 0U;
    __VdlySet__svo_traversal__DOT__r_child__v0 = 0U;
    __VdlySet__svo_traversal__DOT__r_child__v1 = 0U;
    __VdlySet__svo_traversal__DOT__r_child__v2 = 0U;
    __VdlySet__svo_traversal__DOT__r_child__v3 = 0U;
    __VdlySet__svo_traversal__DOT__r_child__v4 = 0U;
    __VdlySet__svo_traversal__DOT__r_child__v5 = 0U;
    __VdlySet__svo_traversal__DOT__r_child__v6 = 0U;
    __VdlySet__svo_traversal__DOT__r_child__v7 = 0U;
    __Vdly__svo_traversal__DOT__node_origin_x = vlSelfRef.svo_traversal__DOT__node_origin_x;
    __Vdly__svo_traversal__DOT__node_origin_y = vlSelfRef.svo_traversal__DOT__node_origin_y;
    __Vdly__svo_traversal__DOT__node_origin_z = vlSelfRef.svo_traversal__DOT__node_origin_z;
    __Vdly__svo_traversal__DOT__sp = vlSelfRef.svo_traversal__DOT__sp;
    __VdlySet__svo_traversal__DOT__stk_node_half__v0 = 0U;
    __Vdly__svo_traversal__DOT__t_min = vlSelfRef.svo_traversal__DOT__t_min;
    __Vdly__svo_traversal__DOT__node_half = vlSelfRef.svo_traversal__DOT__node_half;
    if (vlSelfRef.svo_traversal__DOT__rst) {
        __Vdly__svo_traversal__DOT__state = 0U;
        vlSelfRef.svo_traversal__DOT__busy = 0U;
        vlSelfRef.svo_traversal__DOT__frame_done = 0U;
        vlSelfRef.svo_traversal__DOT__any_hit = 0U;
        vlSelfRef.svo_traversal__DOT__fb_wr_en = 0U;
        vlSelfRef.svo_traversal__DOT__svo_rd_en = 0U;
        vlSelfRef.svo_traversal__DOT__shade_start = 0U;
        vlSelfRef.svo_traversal__DOT__axis_tvalid = 0U;
        vlSelfRef.svo_traversal__DOT__axis_tdata = 0U;
        vlSelfRef.svo_traversal__DOT__axis_tlast = 0U;
        vlSelfRef.svo_traversal__DOT__axis_tuser = 0U;
        __Vdly__svo_traversal__DOT__px = 0U;
        __Vdly__svo_traversal__DOT__py = 0U;
        __Vdly__svo_traversal__DOT__sp = 0U;
        __Vdly__svo_traversal__DOT__rs_wait = 0U;
        __Vdly__svo_traversal__DOT__post_pop = 0U;
    } else {
        vlSelfRef.svo_traversal__DOT__fb_wr_en = 0U;
        vlSelfRef.svo_traversal__DOT__frame_done = 0U;
        vlSelfRef.svo_traversal__DOT__any_hit = 0U;
        vlSelfRef.svo_traversal__DOT__shade_start = 0U;
        vlSelfRef.svo_traversal__DOT__axis_tvalid = 0U;
        if ((8U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
            if ((4U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
                if ((1U & (~ ((IData)(vlSelfRef.svo_traversal__DOT__state) 
                              >> 1U)))) {
                    if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
                        vlSelfRef.svo_traversal__DOT__axis_tvalid = 0U;
                        __Vdly__svo_traversal__DOT__sp = 0U;
                        __Vdly__svo_traversal__DOT__post_pop = 0U;
                        __Vdly__svo_traversal__DOT__node_half = 0x20U;
                        if ((0x013fU == (IData)(vlSelfRef.svo_traversal__DOT__px))) {
                            __Vdly__svo_traversal__DOT__px = 0U;
                            if ((0xefU == (IData)(vlSelfRef.svo_traversal__DOT__py))) {
                                __Vdly__svo_traversal__DOT__py = 0U;
                                vlSelfRef.svo_traversal__DOT__frame_done = 1U;
                                __Vdly__svo_traversal__DOT__state = 0U;
                            } else {
                                __Vdly__svo_traversal__DOT__py 
                                    = (0x000000ffU 
                                       & ((IData)(1U) 
                                          + (IData)(vlSelfRef.svo_traversal__DOT__py)));
                                __Vdly__svo_traversal__DOT__rs_wait = 0U;
                                __Vdly__svo_traversal__DOT__state = 1U;
                            }
                        } else {
                            __Vdly__svo_traversal__DOT__px 
                                = (0x000001ffU & ((IData)(1U) 
                                                  + (IData)(vlSelfRef.svo_traversal__DOT__px)));
                            __Vdly__svo_traversal__DOT__rs_wait = 0U;
                            __Vdly__svo_traversal__DOT__state = 1U;
                        }
                    } else {
                        vlSelfRef.svo_traversal__DOT__axis_tvalid = 1U;
                        vlSelfRef.svo_traversal__DOT__axis_tdata 
                            = vlSelfRef.svo_traversal__DOT__pixel_color;
                        vlSelfRef.svo_traversal__DOT__axis_tlast 
                            = (0x013fU == (IData)(vlSelfRef.svo_traversal__DOT__px));
                        if (vlSelfRef.svo_traversal__DOT__axis_tready) {
                            __Vdly__svo_traversal__DOT__state = 0x0dU;
                        }
                        vlSelfRef.svo_traversal__DOT__axis_tuser 
                            = ((0U == (IData)(vlSelfRef.svo_traversal__DOT__px)) 
                               & (0U == (IData)(vlSelfRef.svo_traversal__DOT__py)));
                    }
                }
            } else if ((2U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
                if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
                    vlSelfRef.svo_traversal__DOT__shade_start = 0U;
                    if (vlSelfRef.svo_traversal__DOT__shade_done) {
                        vlSelfRef.svo_traversal__DOT__pixel_color 
                            = vlSelfRef.svo_traversal__DOT__shade_pixel_color;
                        __Vdly__svo_traversal__DOT__state = 0x0cU;
                    }
                } else {
                    vlSelfRef.svo_traversal__DOT__pixel_color 
                        = vlSelfRef.svo_traversal__DOT__sky_color;
                    __Vdly__svo_traversal__DOT__state = 0x0cU;
                }
            } else if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
                if ((0U == (IData)(vlSelfRef.svo_traversal__DOT__sp))) {
                    __Vdly__svo_traversal__DOT__state = 0x0aU;
                } else {
                    __Vdly__svo_traversal__DOT__sp 
                        = (0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                          - (IData)(1U)));
                    if ((0x0bU >= (0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                  - (IData)(1U))))) {
                        __Vdly__svo_traversal__DOT__node_idx 
                            = vlSelfRef.svo_traversal__DOT__stk_node_idx
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__r_bitmask 
                            = vlSelfRef.svo_traversal__DOT__stk_bitmask
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__t_min 
                            = vlSelfRef.svo_traversal__DOT__stk_t_min
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__t_max 
                            = vlSelfRef.svo_traversal__DOT__stk_t_max
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__t_next_x 
                            = vlSelfRef.svo_traversal__DOT__stk_t_next_x
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__t_next_y 
                            = vlSelfRef.svo_traversal__DOT__stk_t_next_y
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__t_next_z 
                            = vlSelfRef.svo_traversal__DOT__stk_t_next_z
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__cx 
                            = vlSelfRef.svo_traversal__DOT__stk_cx
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__cy 
                            = vlSelfRef.svo_traversal__DOT__stk_cy
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__cz 
                            = vlSelfRef.svo_traversal__DOT__stk_cz
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__node_half 
                            = vlSelfRef.svo_traversal__DOT__stk_node_half
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__node_origin_x 
                            = vlSelfRef.svo_traversal__DOT__stk_orig_x
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__node_origin_y 
                            = vlSelfRef.svo_traversal__DOT__stk_orig_y
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                        __Vdly__svo_traversal__DOT__node_origin_z 
                            = vlSelfRef.svo_traversal__DOT__stk_orig_z
                            [(0x0000000fU & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                             - (IData)(1U)))];
                    } else {
                        __Vdly__svo_traversal__DOT__node_idx = 0U;
                        __Vdly__svo_traversal__DOT__r_bitmask = 0U;
                        __Vdly__svo_traversal__DOT__t_min = 0U;
                        __Vdly__svo_traversal__DOT__t_max = 0U;
                        __Vdly__svo_traversal__DOT__t_next_x = 0U;
                        __Vdly__svo_traversal__DOT__t_next_y = 0U;
                        __Vdly__svo_traversal__DOT__t_next_z = 0U;
                        __Vdly__svo_traversal__DOT__cx = 0U;
                        __Vdly__svo_traversal__DOT__cy = 0U;
                        __Vdly__svo_traversal__DOT__cz = 0U;
                        __Vdly__svo_traversal__DOT__node_half = 0U;
                        __Vdly__svo_traversal__DOT__node_origin_x = 0U;
                        __Vdly__svo_traversal__DOT__node_origin_y = 0U;
                        __Vdly__svo_traversal__DOT__node_origin_z = 0U;
                    }
                    __Vdly__svo_traversal__DOT__dt_x 
                        = vlSelfRef.svo_traversal__DOT__dt_x_pop_c;
                    __Vdly__svo_traversal__DOT__dt_y 
                        = vlSelfRef.svo_traversal__DOT__dt_y_pop_c;
                    __Vdly__svo_traversal__DOT__dt_z 
                        = vlSelfRef.svo_traversal__DOT__dt_z_pop_c;
                    __Vdly__svo_traversal__DOT__post_pop = 1U;
                    __Vdly__svo_traversal__DOT__state = 3U;
                }
            } else {
                vlSelfRef.svo_traversal__DOT____Vlvbound_h3fbd9737__0 
                    = vlSelfRef.svo_traversal__DOT__node_idx;
                __Vdly__svo_traversal__DOT__state = 3U;
                vlSelfRef.svo_traversal__DOT____Vlvbound_h5d517a59__0 
                    = vlSelfRef.svo_traversal__DOT__r_bitmask;
                __Vdly__svo_traversal__DOT__node_idx 
                    = vlSelfRef.svo_traversal__DOT__r_child
                    [vlSelfRef.svo_traversal__DOT__cidx];
                vlSelfRef.svo_traversal__DOT____Vlvbound_h20b934f4__0 
                    = vlSelfRef.svo_traversal__DOT__t_min;
                vlSelfRef.svo_traversal__DOT____Vlvbound_h46c1a37b__0 
                    = vlSelfRef.svo_traversal__DOT__t_max;
                vlSelfRef.svo_traversal__DOT____Vlvbound_h10022533__0 
                    = vlSelfRef.svo_traversal__DOT__t_next_x;
                vlSelfRef.svo_traversal__DOT____Vlvbound_h1738f021__0 
                    = vlSelfRef.svo_traversal__DOT__t_next_y;
                vlSelfRef.svo_traversal__DOT____Vlvbound_h4b07ddb1__0 
                    = vlSelfRef.svo_traversal__DOT__t_next_z;
                vlSelfRef.svo_traversal__DOT____Vlvbound_hd4ed9f67__0 
                    = vlSelfRef.svo_traversal__DOT__cx;
                vlSelfRef.svo_traversal__DOT____Vlvbound_h00e6080f__0 
                    = vlSelfRef.svo_traversal__DOT__cy;
                vlSelfRef.svo_traversal__DOT____Vlvbound_hb13d1bf5__0 
                    = vlSelfRef.svo_traversal__DOT__cz;
                vlSelfRef.svo_traversal__DOT____Vlvbound_h881263f8__0 
                    = vlSelfRef.svo_traversal__DOT__node_half;
                vlSelfRef.svo_traversal__DOT____Vlvbound_h6831e3f2__0 
                    = vlSelfRef.svo_traversal__DOT__node_origin_x;
                vlSelfRef.svo_traversal__DOT____Vlvbound_h9d41b6af__0 
                    = vlSelfRef.svo_traversal__DOT__node_origin_y;
                vlSelfRef.svo_traversal__DOT____Vlvbound_habf6d040__0 
                    = vlSelfRef.svo_traversal__DOT__node_origin_z;
                if ((0x0bU >= (IData)(vlSelfRef.svo_traversal__DOT__sp))) {
                    __VdlyVal__svo_traversal__DOT__stk_node_idx__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h3fbd9737__0;
                    __VdlyDim0__svo_traversal__DOT__stk_node_idx__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_node_idx__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_bitmask__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h5d517a59__0;
                    __VdlyDim0__svo_traversal__DOT__stk_bitmask__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_bitmask__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_t_min__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h20b934f4__0;
                    __VdlyDim0__svo_traversal__DOT__stk_t_min__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_t_min__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_t_max__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h46c1a37b__0;
                    __VdlyDim0__svo_traversal__DOT__stk_t_max__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_t_max__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_t_next_x__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h10022533__0;
                    __VdlyDim0__svo_traversal__DOT__stk_t_next_x__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_t_next_x__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_t_next_y__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h1738f021__0;
                    __VdlyDim0__svo_traversal__DOT__stk_t_next_y__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_t_next_y__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_t_next_z__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h4b07ddb1__0;
                    __VdlyDim0__svo_traversal__DOT__stk_t_next_z__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_t_next_z__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_cx__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_hd4ed9f67__0;
                    __VdlyDim0__svo_traversal__DOT__stk_cx__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_cx__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_cy__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h00e6080f__0;
                    __VdlyDim0__svo_traversal__DOT__stk_cy__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_cy__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_cz__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_hb13d1bf5__0;
                    __VdlyDim0__svo_traversal__DOT__stk_cz__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_cz__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_node_half__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h881263f8__0;
                    __VdlyDim0__svo_traversal__DOT__stk_node_half__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_node_half__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_orig_x__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h6831e3f2__0;
                    __VdlyDim0__svo_traversal__DOT__stk_orig_x__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_orig_x__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_orig_y__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_h9d41b6af__0;
                    __VdlyDim0__svo_traversal__DOT__stk_orig_y__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_orig_y__v0 = 1U;
                    __VdlyVal__svo_traversal__DOT__stk_orig_z__v0 
                        = vlSelfRef.svo_traversal__DOT____Vlvbound_habf6d040__0;
                    __VdlyDim0__svo_traversal__DOT__stk_orig_z__v0 
                        = vlSelfRef.svo_traversal__DOT__sp;
                    __VdlySet__svo_traversal__DOT__stk_orig_z__v0 = 1U;
                }
                __Vdly__svo_traversal__DOT__sp = (0x0000000fU 
                                                  & ((IData)(1U) 
                                                     + (IData)(vlSelfRef.svo_traversal__DOT__sp)));
                __Vdly__svo_traversal__DOT__node_origin_x 
                    = (0x0000003fU & ((IData)(vlSelfRef.svo_traversal__DOT__node_origin_x) 
                                      + ((1U & (IData)(vlSelfRef.svo_traversal__DOT__cx))
                                          ? (IData)(vlSelfRef.svo_traversal__DOT__node_half)
                                          : 0U)));
                __Vdly__svo_traversal__DOT__node_origin_y 
                    = (0x0000003fU & ((IData)(vlSelfRef.svo_traversal__DOT__node_origin_y) 
                                      + ((1U & (IData)(vlSelfRef.svo_traversal__DOT__cy))
                                          ? (IData)(vlSelfRef.svo_traversal__DOT__node_half)
                                          : 0U)));
                __Vdly__svo_traversal__DOT__node_origin_z 
                    = (0x0000003fU & ((IData)(vlSelfRef.svo_traversal__DOT__node_origin_z) 
                                      + ((1U & (IData)(vlSelfRef.svo_traversal__DOT__cz))
                                          ? (IData)(vlSelfRef.svo_traversal__DOT__node_half)
                                          : 0U)));
                __Vdly__svo_traversal__DOT__node_half 
                    = VL_SHIFTR_III(6,6,32, (IData)(vlSelfRef.svo_traversal__DOT__node_half), 1U);
            }
        } else if ((4U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
            if ((2U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
                if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
                    vlSelfRef.svo_traversal__DOT__t_hit 
                        = vlSelfRef.svo_traversal__DOT__t_min;
                    vlSelfRef.svo_traversal__DOT__block_id_hit 
                        = vlSelfRef.svo_traversal__DOT__r_block
                        [vlSelfRef.svo_traversal__DOT__cidx];
                    vlSelfRef.svo_traversal__DOT__hit_px_r 
                        = vlSelfRef.svo_traversal__DOT__bw_ex_c;
                    vlSelfRef.svo_traversal__DOT__hit_py_r 
                        = vlSelfRef.svo_traversal__DOT__bw_ey_c;
                    vlSelfRef.svo_traversal__DOT__hit_pz_r 
                        = vlSelfRef.svo_traversal__DOT__bw_ez_c;
                    vlSelfRef.svo_traversal__DOT__pixel_color = 0x00ffffffU;
                    __Vdly__svo_traversal__DOT__state = 0x0cU;
                } else {
                    if ((VL_LTES_III(32, vlSelfRef.svo_traversal__DOT__t_next_x, vlSelfRef.svo_traversal__DOT__t_next_y) 
                         & VL_LTES_III(32, vlSelfRef.svo_traversal__DOT__t_next_x, vlSelfRef.svo_traversal__DOT__t_next_z))) {
                        __Vdly__svo_traversal__DOT__cx 
                            = (0x0000003fU & ((IData)(vlSelfRef.svo_traversal__DOT__cx) 
                                              + ((0x00000038U 
                                                  & ((- (IData)(
                                                                (1U 
                                                                 & ((IData)(vlSelfRef.svo_traversal__DOT__step_x) 
                                                                    >> 2U)))) 
                                                     << 3U)) 
                                                 | (IData)(vlSelfRef.svo_traversal__DOT__step_x))));
                        vlSelfRef.svo_traversal__DOT__em_face = 0U;
                        vlSelfRef.svo_traversal__DOT__em_fsign 
                            = (1U & ((IData)(vlSelfRef.svo_traversal__DOT__step_x) 
                                     >> 2U));
                        __Vdly__svo_traversal__DOT__t_min 
                            = vlSelfRef.svo_traversal__DOT__t_next_x;
                        __Vdly__svo_traversal__DOT__state 
                            = ((1U & (((IData)(vlSelfRef.svo_traversal__DOT__step_x) 
                                       >> 2U) ^ (IData)(vlSelfRef.svo_traversal__DOT__cx)))
                                ? 9U : 5U);
                        __Vdly__svo_traversal__DOT__t_next_x 
                            = (vlSelfRef.svo_traversal__DOT__t_next_x 
                               + vlSelfRef.svo_traversal__DOT__dt_x);
                    } else if (VL_LTES_III(32, vlSelfRef.svo_traversal__DOT__t_next_y, vlSelfRef.svo_traversal__DOT__t_next_z)) {
                        __Vdly__svo_traversal__DOT__cy 
                            = (0x0000003fU & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                              + ((0x00000038U 
                                                  & ((- (IData)(
                                                                (1U 
                                                                 & ((IData)(vlSelfRef.svo_traversal__DOT__step_y) 
                                                                    >> 2U)))) 
                                                     << 3U)) 
                                                 | (IData)(vlSelfRef.svo_traversal__DOT__step_y))));
                        vlSelfRef.svo_traversal__DOT__em_face = 1U;
                        vlSelfRef.svo_traversal__DOT__em_fsign 
                            = (1U & ((IData)(vlSelfRef.svo_traversal__DOT__step_y) 
                                     >> 2U));
                        __Vdly__svo_traversal__DOT__t_min 
                            = vlSelfRef.svo_traversal__DOT__t_next_y;
                        __Vdly__svo_traversal__DOT__state 
                            = ((1U & (((IData)(vlSelfRef.svo_traversal__DOT__step_y) 
                                       >> 2U) ^ (IData)(vlSelfRef.svo_traversal__DOT__cy)))
                                ? 9U : 5U);
                        __Vdly__svo_traversal__DOT__t_next_y 
                            = (vlSelfRef.svo_traversal__DOT__t_next_y 
                               + vlSelfRef.svo_traversal__DOT__dt_y);
                    } else {
                        __Vdly__svo_traversal__DOT__cz 
                            = (0x0000003fU & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                              + ((0x00000038U 
                                                  & ((- (IData)(
                                                                (1U 
                                                                 & ((IData)(vlSelfRef.svo_traversal__DOT__step_z) 
                                                                    >> 2U)))) 
                                                     << 3U)) 
                                                 | (IData)(vlSelfRef.svo_traversal__DOT__step_z))));
                        vlSelfRef.svo_traversal__DOT__em_face = 2U;
                        vlSelfRef.svo_traversal__DOT__em_fsign 
                            = (1U & ((IData)(vlSelfRef.svo_traversal__DOT__step_z) 
                                     >> 2U));
                        __Vdly__svo_traversal__DOT__t_min 
                            = vlSelfRef.svo_traversal__DOT__t_next_z;
                        __Vdly__svo_traversal__DOT__state 
                            = ((1U & (((IData)(vlSelfRef.svo_traversal__DOT__step_z) 
                                       >> 2U) ^ (IData)(vlSelfRef.svo_traversal__DOT__cz)))
                                ? 9U : 5U);
                        __Vdly__svo_traversal__DOT__t_next_z 
                            = (vlSelfRef.svo_traversal__DOT__t_next_z 
                               + vlSelfRef.svo_traversal__DOT__dt_z);
                    }
                    vlSelfRef.svo_traversal__DOT__hit_face 
                        = vlSelfRef.svo_traversal__DOT__em_face;
                    vlSelfRef.svo_traversal__DOT__hit_face_sign_r 
                        = vlSelfRef.svo_traversal__DOT__em_fsign;
                }
            } else if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
                vlSelfRef.svo_traversal__DOT__cidx 
                    = ((4U & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                              << 2U)) | ((2U & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                << 1U)) 
                                         | (1U & (IData)(vlSelfRef.svo_traversal__DOT__cx))));
                __Vdly__svo_traversal__DOT__state = 
                    ((0U == (3U & VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                VL_SHIFTL_III(32,32,32, 
                                                              ((4U 
                                                                & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                   << 2U)) 
                                                               | ((2U 
                                                                   & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                      << 1U)) 
                                                                  | (1U 
                                                                     & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U))))
                      ? 6U : ((3U == (3U & VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                         VL_SHIFTL_III(32,32,32, 
                                                                       ((4U 
                                                                         & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                            << 2U)) 
                                                                        | ((2U 
                                                                            & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                               << 1U)) 
                                                                           | (1U 
                                                                              & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U))))
                               ? 7U : ((1U == (3U & 
                                               VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                             VL_SHIFTL_III(32,32,32, 
                                                                           ((4U 
                                                                             & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                                << 2U)) 
                                                                            | ((2U 
                                                                                & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                                << 1U)) 
                                                                               | (1U 
                                                                                & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U))))
                                        ? 8U : 6U)));
                if ((1U & (~ VL_ONEHOT_I((((1U == (3U 
                                                   & VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                                   VL_SHIFTL_III(32,32,32, 
                                                                                ((4U 
                                                                                & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                                << 2U)) 
                                                                                | ((2U 
                                                                                & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                                << 1U)) 
                                                                                | (1U 
                                                                                & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U)))) 
                                           << 2U) | 
                                          (((3U == 
                                             (3U & 
                                              VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                            VL_SHIFTL_III(32,32,32, 
                                                                          ((4U 
                                                                            & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                               << 2U)) 
                                                                           | ((2U 
                                                                               & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                                << 1U)) 
                                                                              | (1U 
                                                                                & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U)))) 
                                            << 1U) 
                                           | (0U == 
                                              (3U & 
                                               VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                             VL_SHIFTL_III(32,32,32, 
                                                                           ((4U 
                                                                             & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                                << 2U)) 
                                                                            | ((2U 
                                                                                & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                                << 1U)) 
                                                                               | (1U 
                                                                                & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U)))))))))) {
                    if ((0U != (((1U == (3U & VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                            VL_SHIFTL_III(32,32,32, 
                                                                          ((4U 
                                                                            & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                               << 2U)) 
                                                                           | ((2U 
                                                                               & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                                << 1U)) 
                                                                              | (1U 
                                                                                & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U)))) 
                                 << 2U) | (((3U == 
                                             (3U & 
                                              VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                            VL_SHIFTL_III(32,32,32, 
                                                                          ((4U 
                                                                            & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                               << 2U)) 
                                                                           | ((2U 
                                                                               & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                                << 1U)) 
                                                                              | (1U 
                                                                                & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U)))) 
                                            << 1U) 
                                           | (0U == 
                                              (3U & 
                                               VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                             VL_SHIFTL_III(32,32,32, 
                                                                           ((4U 
                                                                             & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                                << 2U)) 
                                                                            | ((2U 
                                                                                & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                                << 1U)) 
                                                                               | (1U 
                                                                                & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U)))))))) {
                        if (VL_UNLIKELY((vlSymsp->_vm_contextp__->assertOn()))) {
                            VL_WRITEF_NX("[%0t] %%Error: svo_traversal.sv:599: Assertion failed in %m: unique case, but multiple matches found for '2'h%X'\n",4, 'M',vlSymsp->name(),"svo_traversal", 'T',-9
                                         , '#',64,VL_TIME_UNITED_Q(1000)
                                         , '#',2,(3U 
                                                  & VL_SHIFTR_III(2,16,32, (IData)(vlSelfRef.svo_traversal__DOT__r_bitmask), 
                                                                  VL_SHIFTL_III(32,32,32, 
                                                                                ((4U 
                                                                                & ((IData)(vlSelfRef.svo_traversal__DOT__cz) 
                                                                                << 2U)) 
                                                                                | ((2U 
                                                                                & ((IData)(vlSelfRef.svo_traversal__DOT__cy) 
                                                                                << 1U)) 
                                                                                | (1U 
                                                                                & (IData)(vlSelfRef.svo_traversal__DOT__cx)))), 1U))));
                            VL_STOP_MT("/home/ali/git/fyp/vivado/ip/svo_raytracer/hdl/svo_traversal.sv", 599, "");
                        }
                    }
                }
            } else {
                if ((4U & (IData)(vlSelfRef.svo_traversal__DOT__bram_field))) {
                    if ((2U & (IData)(vlSelfRef.svo_traversal__DOT__bram_field))) {
                        if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__bram_field))) {
                            vlSelfRef.svo_traversal__DOT__svo_rd_addr 
                                = (1U | (0x00007ff8U 
                                         & ((IData)(vlSelfRef.svo_traversal__DOT__node_idx) 
                                            << 3U)));
                            __Vdly__svo_traversal__DOT__bram_field = 0U;
                        } else {
                            __VdlyVal__svo_traversal__DOT__r_block__v0 
                                = (0x000000ffU & vlSelfRef.svo_traversal__DOT__svo_rd_data);
                            __VdlySet__svo_traversal__DOT__r_block__v0 = 1U;
                            __VdlyVal__svo_traversal__DOT__r_block__v1 
                                = (0x000000ffU & (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                                                  >> 8U));
                            __VdlyVal__svo_traversal__DOT__r_block__v2 
                                = (0x000000ffU & (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                                                  >> 0x10U));
                            __VdlyVal__svo_traversal__DOT__r_block__v3 
                                = (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                                   >> 0x18U);
                        }
                    } else if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__bram_field))) {
                        __VdlyVal__svo_traversal__DOT__r_block__v4 
                            = (0x000000ffU & vlSelfRef.svo_traversal__DOT__svo_rd_data);
                        __VdlySet__svo_traversal__DOT__r_block__v4 = 1U;
                        vlSelfRef.svo_traversal__DOT__svo_rd_en = 0U;
                        __Vdly__svo_traversal__DOT__bram_field = 6U;
                        __VdlyVal__svo_traversal__DOT__r_block__v5 
                            = (0x000000ffU & (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                                              >> 8U));
                        __VdlySet__svo_traversal__DOT__r_block__v5 = 1U;
                        __VdlyVal__svo_traversal__DOT__r_block__v6 
                            = (0x000000ffU & (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                                              >> 0x10U));
                        __VdlyVal__svo_traversal__DOT__r_block__v7 
                            = (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                               >> 0x18U);
                    } else {
                        __VdlyVal__svo_traversal__DOT__r_child__v0 
                            = (0x0000ffffU & vlSelfRef.svo_traversal__DOT__svo_rd_data);
                        __VdlySet__svo_traversal__DOT__r_child__v0 = 1U;
                        vlSelfRef.svo_traversal__DOT__svo_rd_addr 
                            = (6U | (0x00007ff8U & 
                                     ((IData)(vlSelfRef.svo_traversal__DOT__node_idx) 
                                      << 3U)));
                        __Vdly__svo_traversal__DOT__bram_field = 5U;
                        __VdlyVal__svo_traversal__DOT__r_child__v1 
                            = (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                               >> 0x10U);
                        __VdlySet__svo_traversal__DOT__r_child__v1 = 1U;
                    }
                } else if ((2U & (IData)(vlSelfRef.svo_traversal__DOT__bram_field))) {
                    if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__bram_field))) {
                        __VdlyVal__svo_traversal__DOT__r_child__v2 
                            = (0x0000ffffU & vlSelfRef.svo_traversal__DOT__svo_rd_data);
                        __VdlySet__svo_traversal__DOT__r_child__v2 = 1U;
                        vlSelfRef.svo_traversal__DOT__svo_rd_addr 
                            = (5U | (0x00007ff8U & 
                                     ((IData)(vlSelfRef.svo_traversal__DOT__node_idx) 
                                      << 3U)));
                        __Vdly__svo_traversal__DOT__bram_field = 4U;
                        __VdlyVal__svo_traversal__DOT__r_child__v3 
                            = (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                               >> 0x10U);
                        __VdlySet__svo_traversal__DOT__r_child__v3 = 1U;
                    } else {
                        __VdlyVal__svo_traversal__DOT__r_child__v4 
                            = (0x0000ffffU & vlSelfRef.svo_traversal__DOT__svo_rd_data);
                        __VdlySet__svo_traversal__DOT__r_child__v4 = 1U;
                        vlSelfRef.svo_traversal__DOT__svo_rd_addr 
                            = (4U | (0x00007ff8U & 
                                     ((IData)(vlSelfRef.svo_traversal__DOT__node_idx) 
                                      << 3U)));
                        __Vdly__svo_traversal__DOT__bram_field = 3U;
                        __VdlyVal__svo_traversal__DOT__r_child__v5 
                            = (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                               >> 0x10U);
                        __VdlySet__svo_traversal__DOT__r_child__v5 = 1U;
                    }
                } else if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__bram_field))) {
                    __VdlyVal__svo_traversal__DOT__r_child__v6 
                        = (0x0000ffffU & vlSelfRef.svo_traversal__DOT__svo_rd_data);
                    __VdlySet__svo_traversal__DOT__r_child__v6 = 1U;
                    vlSelfRef.svo_traversal__DOT__svo_rd_addr 
                        = (3U | (0x00007ff8U & ((IData)(vlSelfRef.svo_traversal__DOT__node_idx) 
                                                << 3U)));
                    __Vdly__svo_traversal__DOT__bram_field = 2U;
                    __VdlyVal__svo_traversal__DOT__r_child__v7 
                        = (vlSelfRef.svo_traversal__DOT__svo_rd_data 
                           >> 0x10U);
                    __VdlySet__svo_traversal__DOT__r_child__v7 = 1U;
                } else {
                    __Vdly__svo_traversal__DOT__r_bitmask 
                        = (0x0000ffffU & vlSelfRef.svo_traversal__DOT__svo_rd_data);
                    vlSelfRef.svo_traversal__DOT__svo_rd_addr 
                        = (2U | (0x00007ff8U & ((IData)(vlSelfRef.svo_traversal__DOT__node_idx) 
                                                << 3U)));
                    __Vdly__svo_traversal__DOT__bram_field = 1U;
                }
                if ((6U == (IData)(vlSelfRef.svo_traversal__DOT__bram_field))) {
                    vlSelfRef.svo_traversal__DOT__svo_rd_en = 0U;
                    vlSelfRef.svo_traversal__DOT__bitmask 
                        = vlSelfRef.svo_traversal__DOT__r_bitmask;
                    if (vlSelfRef.svo_traversal__DOT__post_pop) {
                        __Vdly__svo_traversal__DOT__post_pop = 0U;
                        __Vdly__svo_traversal__DOT__state = 6U;
                    } else {
                        __Vdly__svo_traversal__DOT__cx 
                            = (((IData)(vlSelfRef.svo_traversal__DOT__bw_icx_c) 
                                >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                ? 1U : 0U);
                        __Vdly__svo_traversal__DOT__dt_x 
                            = vlSelfRef.svo_traversal__DOT__dt_x_bw_c;
                        __Vdly__svo_traversal__DOT__dt_y 
                            = vlSelfRef.svo_traversal__DOT__dt_y_bw_c;
                        __Vdly__svo_traversal__DOT__dt_z 
                            = vlSelfRef.svo_traversal__DOT__dt_z_bw_c;
                        __Vdly__svo_traversal__DOT__t_next_x 
                            = vlSelfRef.svo_traversal__DOT__t_next_x_bw_c;
                        __Vdly__svo_traversal__DOT__t_next_y 
                            = vlSelfRef.svo_traversal__DOT__t_next_y_bw_c;
                        __Vdly__svo_traversal__DOT__t_next_z 
                            = vlSelfRef.svo_traversal__DOT__t_next_z_bw_c;
                        __Vdly__svo_traversal__DOT__state = 5U;
                        __Vdly__svo_traversal__DOT__cy 
                            = (((IData)(vlSelfRef.svo_traversal__DOT__bw_icy_c) 
                                >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                ? 1U : 0U);
                        __Vdly__svo_traversal__DOT__cz 
                            = (((IData)(vlSelfRef.svo_traversal__DOT__bw_icz_c) 
                                >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                ? 1U : 0U);
                    }
                }
            }
        } else if ((2U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
            if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
                __Vdly__svo_traversal__DOT__bram_field = 7U;
                vlSelfRef.svo_traversal__DOT__svo_rd_en = 1U;
                vlSelfRef.svo_traversal__DOT__svo_rd_addr 
                    = (0x00007ff8U & ((IData)(vlSelfRef.svo_traversal__DOT__node_idx) 
                                      << 3U));
                __Vdly__svo_traversal__DOT__state = 4U;
            } else {
                vlSelfRef.svo_traversal__DOT__rs_world_q = 0x00400000U;
                __Vfunc_svo_traversal__DOT__qmul__12__b 
                    = vlSelfRef.svo_traversal__DOT__inv_x;
                __Vfunc_svo_traversal__DOT__qmul__12__a 
                    = (- vlSelfRef.svo_traversal__DOT__ro_x);
                __Vfunc_svo_traversal__DOT__qmul__12__p 
                    = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__12__a), 
                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__12__b));
                __Vfunc_svo_traversal__DOT__qmul__12__Vfuncout 
                    = (IData)((__Vfunc_svo_traversal__DOT__qmul__12__p 
                               >> 0x10U));
                vlSelfRef.svo_traversal__DOT__rs_tx0 
                    = __Vfunc_svo_traversal__DOT__qmul__12__Vfuncout;
                __Vfunc_svo_traversal__DOT__qmul__13__b 
                    = vlSelfRef.svo_traversal__DOT__inv_x;
                __Vfunc_svo_traversal__DOT__qmul__13__a 
                    = (vlSelfRef.svo_traversal__DOT__rs_world_q 
                       - vlSelfRef.svo_traversal__DOT__ro_x);
                __Vfunc_svo_traversal__DOT__qmul__13__p 
                    = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__13__a), 
                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__13__b));
                __Vfunc_svo_traversal__DOT__qmul__13__Vfuncout 
                    = (IData)((__Vfunc_svo_traversal__DOT__qmul__13__p 
                               >> 0x10U));
                vlSelfRef.svo_traversal__DOT__rs_tx1 
                    = __Vfunc_svo_traversal__DOT__qmul__13__Vfuncout;
                __Vfunc_svo_traversal__DOT__qmul__14__b 
                    = vlSelfRef.svo_traversal__DOT__inv_y;
                __Vfunc_svo_traversal__DOT__qmul__14__a 
                    = (- vlSelfRef.svo_traversal__DOT__ro_y);
                __Vfunc_svo_traversal__DOT__qmul__14__p 
                    = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__14__a), 
                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__14__b));
                __Vfunc_svo_traversal__DOT__qmul__14__Vfuncout 
                    = (IData)((__Vfunc_svo_traversal__DOT__qmul__14__p 
                               >> 0x10U));
                vlSelfRef.svo_traversal__DOT__rs_ty0 
                    = __Vfunc_svo_traversal__DOT__qmul__14__Vfuncout;
                __Vfunc_svo_traversal__DOT__qmul__15__b 
                    = vlSelfRef.svo_traversal__DOT__inv_y;
                __Vfunc_svo_traversal__DOT__qmul__15__a 
                    = (vlSelfRef.svo_traversal__DOT__rs_world_q 
                       - vlSelfRef.svo_traversal__DOT__ro_y);
                __Vfunc_svo_traversal__DOT__qmul__15__p 
                    = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__15__a), 
                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__15__b));
                __Vfunc_svo_traversal__DOT__qmul__15__Vfuncout 
                    = (IData)((__Vfunc_svo_traversal__DOT__qmul__15__p 
                               >> 0x10U));
                vlSelfRef.svo_traversal__DOT__rs_ty1 
                    = __Vfunc_svo_traversal__DOT__qmul__15__Vfuncout;
                __Vfunc_svo_traversal__DOT__qmul__16__b 
                    = vlSelfRef.svo_traversal__DOT__inv_z;
                __Vfunc_svo_traversal__DOT__qmul__16__a 
                    = (- vlSelfRef.svo_traversal__DOT__ro_z);
                __Vfunc_svo_traversal__DOT__qmul__16__p 
                    = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__16__a), 
                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__16__b));
                __Vfunc_svo_traversal__DOT__qmul__16__Vfuncout 
                    = (IData)((__Vfunc_svo_traversal__DOT__qmul__16__p 
                               >> 0x10U));
                vlSelfRef.svo_traversal__DOT__rs_tz0 
                    = __Vfunc_svo_traversal__DOT__qmul__16__Vfuncout;
                __Vfunc_svo_traversal__DOT__qmul__17__b 
                    = vlSelfRef.svo_traversal__DOT__inv_z;
                __Vfunc_svo_traversal__DOT__qmul__17__a 
                    = (vlSelfRef.svo_traversal__DOT__rs_world_q 
                       - vlSelfRef.svo_traversal__DOT__ro_z);
                __Vfunc_svo_traversal__DOT__qmul__17__p 
                    = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__17__a), 
                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__17__b));
                __Vfunc_svo_traversal__DOT__qmul__17__Vfuncout 
                    = (IData)((__Vfunc_svo_traversal__DOT__qmul__17__p 
                               >> 0x10U));
                vlSelfRef.svo_traversal__DOT__rs_tz1 
                    = __Vfunc_svo_traversal__DOT__qmul__17__Vfuncout;
                if (VL_GTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tx0, vlSelfRef.svo_traversal__DOT__rs_tx1)) {
                    vlSelfRef.svo_traversal__DOT__rs_tmp 
                        = vlSelfRef.svo_traversal__DOT__rs_tx0;
                    vlSelfRef.svo_traversal__DOT__rs_tx0 
                        = vlSelfRef.svo_traversal__DOT__rs_tx1;
                    vlSelfRef.svo_traversal__DOT__rs_tx1 
                        = vlSelfRef.svo_traversal__DOT__rs_tmp;
                }
                if (VL_GTS_III(32, vlSelfRef.svo_traversal__DOT__rs_ty0, vlSelfRef.svo_traversal__DOT__rs_ty1)) {
                    vlSelfRef.svo_traversal__DOT__rs_tmp 
                        = vlSelfRef.svo_traversal__DOT__rs_ty0;
                    vlSelfRef.svo_traversal__DOT__rs_ty0 
                        = vlSelfRef.svo_traversal__DOT__rs_ty1;
                    vlSelfRef.svo_traversal__DOT__rs_ty1 
                        = vlSelfRef.svo_traversal__DOT__rs_tmp;
                }
                if (VL_GTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tz0, vlSelfRef.svo_traversal__DOT__rs_tz1)) {
                    vlSelfRef.svo_traversal__DOT__rs_tmp 
                        = vlSelfRef.svo_traversal__DOT__rs_tz0;
                    vlSelfRef.svo_traversal__DOT__rs_tz0 
                        = vlSelfRef.svo_traversal__DOT__rs_tz1;
                    vlSelfRef.svo_traversal__DOT__rs_tz1 
                        = vlSelfRef.svo_traversal__DOT__rs_tmp;
                }
                __Vdly__svo_traversal__DOT__t_min = 
                    (VL_GTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tx0, vlSelfRef.svo_traversal__DOT__rs_ty0)
                      ? (VL_GTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tx0, vlSelfRef.svo_traversal__DOT__rs_tz0)
                          ? vlSelfRef.svo_traversal__DOT__rs_tx0
                          : vlSelfRef.svo_traversal__DOT__rs_tz0)
                      : (VL_GTS_III(32, vlSelfRef.svo_traversal__DOT__rs_ty0, vlSelfRef.svo_traversal__DOT__rs_tz0)
                          ? vlSelfRef.svo_traversal__DOT__rs_ty0
                          : vlSelfRef.svo_traversal__DOT__rs_tz0));
                __Vdly__svo_traversal__DOT__t_max = 
                    (VL_LTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tx1, vlSelfRef.svo_traversal__DOT__rs_ty1)
                      ? (VL_LTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tx1, vlSelfRef.svo_traversal__DOT__rs_tz1)
                          ? vlSelfRef.svo_traversal__DOT__rs_tx1
                          : vlSelfRef.svo_traversal__DOT__rs_tz1)
                      : (VL_LTS_III(32, vlSelfRef.svo_traversal__DOT__rs_ty1, vlSelfRef.svo_traversal__DOT__rs_tz1)
                          ? vlSelfRef.svo_traversal__DOT__rs_ty1
                          : vlSelfRef.svo_traversal__DOT__rs_tz1));
                if (VL_GTS_III(32, (VL_GTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tx0, vlSelfRef.svo_traversal__DOT__rs_ty0)
                                     ? (VL_GTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tx0, vlSelfRef.svo_traversal__DOT__rs_tz0)
                                         ? vlSelfRef.svo_traversal__DOT__rs_tx0
                                         : vlSelfRef.svo_traversal__DOT__rs_tz0)
                                     : (VL_GTS_III(32, vlSelfRef.svo_traversal__DOT__rs_ty0, vlSelfRef.svo_traversal__DOT__rs_tz0)
                                         ? vlSelfRef.svo_traversal__DOT__rs_ty0
                                         : vlSelfRef.svo_traversal__DOT__rs_tz0)), 
                               (VL_LTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tx1, vlSelfRef.svo_traversal__DOT__rs_ty1)
                                 ? (VL_LTS_III(32, vlSelfRef.svo_traversal__DOT__rs_tx1, vlSelfRef.svo_traversal__DOT__rs_tz1)
                                     ? vlSelfRef.svo_traversal__DOT__rs_tx1
                                     : vlSelfRef.svo_traversal__DOT__rs_tz1)
                                 : (VL_LTS_III(32, vlSelfRef.svo_traversal__DOT__rs_ty1, vlSelfRef.svo_traversal__DOT__rs_tz1)
                                     ? vlSelfRef.svo_traversal__DOT__rs_ty1
                                     : vlSelfRef.svo_traversal__DOT__rs_tz1)))) {
                    __Vdly__svo_traversal__DOT__state = 0x0aU;
                } else {
                    __Vdly__svo_traversal__DOT__node_idx = 0U;
                    __Vdly__svo_traversal__DOT__node_origin_x = 0U;
                    __Vdly__svo_traversal__DOT__node_origin_y = 0U;
                    __Vdly__svo_traversal__DOT__node_origin_z = 0U;
                    __Vdly__svo_traversal__DOT__state = 3U;
                }
            }
        } else if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__state))) {
            __Vdly__svo_traversal__DOT__rs_wait = (0x0000001fU 
                                                   & ((IData)(1U) 
                                                      + (IData)(vlSelfRef.svo_traversal__DOT__rs_wait)));
            if ((1U & (~ ((IData)(vlSelfRef.svo_traversal__DOT__rs_wait) 
                          >> 4U)))) {
                if ((8U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                    if ((4U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                        if ((1U & (~ ((IData)(vlSelfRef.svo_traversal__DOT__rs_wait) 
                                      >> 1U)))) {
                            if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                                if ((vlSelfRef.svo_traversal__DOT__rs_ndx_r 
                                     >> 0x1fU)) {
                                    __Vfunc_svo_traversal__DOT__qmul__18__b 
                                        = ((IData)(0x00020000U) 
                                           - vlSelfRef.svo_traversal__DOT__rs_rmb_x_r);
                                    __Vfunc_svo_traversal__DOT__qmul__18__a 
                                        = vlSelfRef.svo_traversal__DOT__rs_r1x_r;
                                    __Vfunc_svo_traversal__DOT__qmul__18__p 
                                        = VL_MULS_QQQ(64, 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__18__a), 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__18__b));
                                    vlSelfRef.svo_traversal__DOT____VlemCall_17__qmul 
                                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__18__p 
                                                   >> 0x10U));
                                    vlSelfRef.svo_traversal__DOT____VlemCall_18__qmul 
                                        = (- vlSelfRef.svo_traversal__DOT____VlemCall_17__qmul);
                                } else {
                                    __Vfunc_svo_traversal__DOT__qmul__19__b 
                                        = ((IData)(0x00020000U) 
                                           - vlSelfRef.svo_traversal__DOT__rs_rmb_x_r);
                                    __Vfunc_svo_traversal__DOT__qmul__19__a 
                                        = vlSelfRef.svo_traversal__DOT__rs_r1x_r;
                                    __Vfunc_svo_traversal__DOT__qmul__19__p 
                                        = VL_MULS_QQQ(64, 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__19__a), 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__19__b));
                                    vlSelfRef.svo_traversal__DOT____VlemCall_18__qmul 
                                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__19__p 
                                                   >> 0x10U));
                                }
                                if ((vlSelfRef.svo_traversal__DOT__rs_ndy_r 
                                     >> 0x1fU)) {
                                    __Vfunc_svo_traversal__DOT__qmul__20__b 
                                        = ((IData)(0x00020000U) 
                                           - vlSelfRef.svo_traversal__DOT__rs_rmb_y_r);
                                    __Vfunc_svo_traversal__DOT__qmul__20__a 
                                        = vlSelfRef.svo_traversal__DOT__rs_r1y_r;
                                    __Vfunc_svo_traversal__DOT__qmul__20__p 
                                        = VL_MULS_QQQ(64, 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__20__a), 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__20__b));
                                    vlSelfRef.svo_traversal__DOT____VlemCall_19__qmul 
                                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__20__p 
                                                   >> 0x10U));
                                    vlSelfRef.svo_traversal__DOT____VlemCall_20__qmul 
                                        = (- vlSelfRef.svo_traversal__DOT____VlemCall_19__qmul);
                                } else {
                                    __Vfunc_svo_traversal__DOT__qmul__21__b 
                                        = ((IData)(0x00020000U) 
                                           - vlSelfRef.svo_traversal__DOT__rs_rmb_y_r);
                                    __Vfunc_svo_traversal__DOT__qmul__21__a 
                                        = vlSelfRef.svo_traversal__DOT__rs_r1y_r;
                                    __Vfunc_svo_traversal__DOT__qmul__21__p 
                                        = VL_MULS_QQQ(64, 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__21__a), 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__21__b));
                                    vlSelfRef.svo_traversal__DOT____VlemCall_20__qmul 
                                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__21__p 
                                                   >> 0x10U));
                                }
                                if ((vlSelfRef.svo_traversal__DOT__rs_ndz_r 
                                     >> 0x1fU)) {
                                    __Vfunc_svo_traversal__DOT__qmul__22__b 
                                        = ((IData)(0x00020000U) 
                                           - vlSelfRef.svo_traversal__DOT__rs_rmb_z_r);
                                    __Vfunc_svo_traversal__DOT__qmul__22__a 
                                        = vlSelfRef.svo_traversal__DOT__rs_r1z_r;
                                    __Vfunc_svo_traversal__DOT__qmul__22__p 
                                        = VL_MULS_QQQ(64, 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__22__a), 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__22__b));
                                    vlSelfRef.svo_traversal__DOT____VlemCall_21__qmul 
                                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__22__p 
                                                   >> 0x10U));
                                    vlSelfRef.svo_traversal__DOT____VlemCall_22__qmul 
                                        = (- vlSelfRef.svo_traversal__DOT____VlemCall_21__qmul);
                                } else {
                                    __Vfunc_svo_traversal__DOT__qmul__23__b 
                                        = ((IData)(0x00020000U) 
                                           - vlSelfRef.svo_traversal__DOT__rs_rmb_z_r);
                                    __Vfunc_svo_traversal__DOT__qmul__23__a 
                                        = vlSelfRef.svo_traversal__DOT__rs_r1z_r;
                                    __Vfunc_svo_traversal__DOT__qmul__23__p 
                                        = VL_MULS_QQQ(64, 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__23__a), 
                                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__23__b));
                                    vlSelfRef.svo_traversal__DOT____VlemCall_22__qmul 
                                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__23__p 
                                                   >> 0x10U));
                                }
                                vlSelfRef.svo_traversal__DOT__rd_x 
                                    = vlSelfRef.svo_traversal__DOT__rs_ndx_r;
                                vlSelfRef.svo_traversal__DOT__rd_y 
                                    = vlSelfRef.svo_traversal__DOT__rs_ndy_r;
                                vlSelfRef.svo_traversal__DOT__rd_z 
                                    = vlSelfRef.svo_traversal__DOT__rs_ndz_r;
                                vlSelfRef.svo_traversal__DOT__ro_x 
                                    = vlSelfRef.svo_traversal__DOT__cam_pos_x;
                                vlSelfRef.svo_traversal__DOT__ro_y 
                                    = vlSelfRef.svo_traversal__DOT__cam_pos_y;
                                vlSelfRef.svo_traversal__DOT__ro_z 
                                    = vlSelfRef.svo_traversal__DOT__cam_pos_z;
                                vlSelfRef.svo_traversal__DOT__inv_x 
                                    = vlSelfRef.svo_traversal__DOT____VlemCall_18__qmul;
                                vlSelfRef.svo_traversal__DOT__inv_y 
                                    = vlSelfRef.svo_traversal__DOT____VlemCall_20__qmul;
                                vlSelfRef.svo_traversal__DOT__inv_z 
                                    = vlSelfRef.svo_traversal__DOT____VlemCall_22__qmul;
                                vlSelfRef.svo_traversal__DOT__step_x 
                                    = (VL_LTES_III(32, 0U, vlSelfRef.svo_traversal__DOT__rs_ndx_r)
                                        ? 1U : 7U);
                                vlSelfRef.svo_traversal__DOT__step_y 
                                    = (VL_LTES_III(32, 0U, vlSelfRef.svo_traversal__DOT__rs_ndy_r)
                                        ? 1U : 7U);
                                vlSelfRef.svo_traversal__DOT__step_z 
                                    = (VL_LTES_III(32, 0U, vlSelfRef.svo_traversal__DOT__rs_ndz_r)
                                        ? 1U : 7U);
                                __Vdly__svo_traversal__DOT__sp = 0U;
                                __Vdly__svo_traversal__DOT__rs_wait = 0U;
                                __Vdly__svo_traversal__DOT__state = 2U;
                            } else {
                                __Vfunc_svo_traversal__DOT__qmul__24__b 
                                    = vlSelfRef.svo_traversal__DOT__rs_r1x_r;
                                __Vfunc_svo_traversal__DOT__qmul__25__b 
                                    = vlSelfRef.svo_traversal__DOT__rs_r1y_r;
                                __Vfunc_svo_traversal__DOT__qmul__26__b 
                                    = vlSelfRef.svo_traversal__DOT__rs_r1z_r;
                                __Vfunc_svo_traversal__DOT__qmul__24__a 
                                    = vlSelfRef.svo_traversal__DOT__rs_ax_r;
                                __Vfunc_svo_traversal__DOT__qmul__25__a 
                                    = vlSelfRef.svo_traversal__DOT__rs_ay_r;
                                __Vfunc_svo_traversal__DOT__qmul__26__a 
                                    = vlSelfRef.svo_traversal__DOT__rs_az_r;
                                __Vfunc_svo_traversal__DOT__qmul__24__p 
                                    = VL_MULS_QQQ(64, 
                                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__24__a), 
                                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__24__b));
                                __Vfunc_svo_traversal__DOT__qmul__25__p 
                                    = VL_MULS_QQQ(64, 
                                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__25__a), 
                                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__25__b));
                                __Vfunc_svo_traversal__DOT__qmul__26__p 
                                    = VL_MULS_QQQ(64, 
                                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__26__a), 
                                                  VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__26__b));
                                __Vfunc_svo_traversal__DOT__qmul__24__Vfuncout 
                                    = (IData)((__Vfunc_svo_traversal__DOT__qmul__24__p 
                                               >> 0x10U));
                                __Vfunc_svo_traversal__DOT__qmul__25__Vfuncout 
                                    = (IData)((__Vfunc_svo_traversal__DOT__qmul__25__p 
                                               >> 0x10U));
                                __Vfunc_svo_traversal__DOT__qmul__26__Vfuncout 
                                    = (IData)((__Vfunc_svo_traversal__DOT__qmul__26__p 
                                               >> 0x10U));
                                vlSelfRef.svo_traversal__DOT__rs_rmb_x_r 
                                    = __Vfunc_svo_traversal__DOT__qmul__24__Vfuncout;
                                vlSelfRef.svo_traversal__DOT__rs_rmb_y_r 
                                    = __Vfunc_svo_traversal__DOT__qmul__25__Vfuncout;
                                vlSelfRef.svo_traversal__DOT__rs_rmb_z_r 
                                    = __Vfunc_svo_traversal__DOT__qmul__26__Vfuncout;
                            }
                        }
                    } else if ((2U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                        if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                            __Vfunc_svo_traversal__DOT__qmul__27__b 
                                = ((IData)(0x00020000U) 
                                   - vlSelfRef.svo_traversal__DOT__rs_rma_x_r);
                            __Vfunc_svo_traversal__DOT__qmul__28__b 
                                = ((IData)(0x00020000U) 
                                   - vlSelfRef.svo_traversal__DOT__rs_rma_y_r);
                            __Vfunc_svo_traversal__DOT__qmul__29__b 
                                = ((IData)(0x00020000U) 
                                   - vlSelfRef.svo_traversal__DOT__rs_rma_z_r);
                            __Vfunc_svo_traversal__DOT__qmul__27__a 
                                = vlSelfRef.svo_traversal__DOT__rs_r0x_r;
                            __Vfunc_svo_traversal__DOT__qmul__28__a 
                                = vlSelfRef.svo_traversal__DOT__rs_r0y_r;
                            __Vfunc_svo_traversal__DOT__qmul__29__a 
                                = vlSelfRef.svo_traversal__DOT__rs_r0z_r;
                            __Vfunc_svo_traversal__DOT__qmul__27__p 
                                = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__27__a), 
                                              VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__27__b));
                            __Vfunc_svo_traversal__DOT__qmul__28__p 
                                = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__28__a), 
                                              VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__28__b));
                            __Vfunc_svo_traversal__DOT__qmul__29__p 
                                = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__29__a), 
                                              VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__29__b));
                            __Vfunc_svo_traversal__DOT__qmul__27__Vfuncout 
                                = (IData)((__Vfunc_svo_traversal__DOT__qmul__27__p 
                                           >> 0x10U));
                            __Vfunc_svo_traversal__DOT__qmul__28__Vfuncout 
                                = (IData)((__Vfunc_svo_traversal__DOT__qmul__28__p 
                                           >> 0x10U));
                            __Vfunc_svo_traversal__DOT__qmul__29__Vfuncout 
                                = (IData)((__Vfunc_svo_traversal__DOT__qmul__29__p 
                                           >> 0x10U));
                            vlSelfRef.svo_traversal__DOT__rs_r1x_r 
                                = __Vfunc_svo_traversal__DOT__qmul__27__Vfuncout;
                            vlSelfRef.svo_traversal__DOT__rs_r1y_r 
                                = __Vfunc_svo_traversal__DOT__qmul__28__Vfuncout;
                            vlSelfRef.svo_traversal__DOT__rs_r1z_r 
                                = __Vfunc_svo_traversal__DOT__qmul__29__Vfuncout;
                        } else {
                            __Vfunc_svo_traversal__DOT__qmul__30__b 
                                = vlSelfRef.svo_traversal__DOT__rs_r0x_r;
                            __Vfunc_svo_traversal__DOT__qmul__31__b 
                                = vlSelfRef.svo_traversal__DOT__rs_r0y_r;
                            __Vfunc_svo_traversal__DOT__qmul__32__b 
                                = vlSelfRef.svo_traversal__DOT__rs_r0z_r;
                            __Vfunc_svo_traversal__DOT__qmul__30__a 
                                = vlSelfRef.svo_traversal__DOT__rs_ax_r;
                            __Vfunc_svo_traversal__DOT__qmul__31__a 
                                = vlSelfRef.svo_traversal__DOT__rs_ay_r;
                            __Vfunc_svo_traversal__DOT__qmul__32__a 
                                = vlSelfRef.svo_traversal__DOT__rs_az_r;
                            __Vfunc_svo_traversal__DOT__qmul__30__p 
                                = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__30__a), 
                                              VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__30__b));
                            __Vfunc_svo_traversal__DOT__qmul__31__p 
                                = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__31__a), 
                                              VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__31__b));
                            __Vfunc_svo_traversal__DOT__qmul__32__p 
                                = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__32__a), 
                                              VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__32__b));
                            __Vfunc_svo_traversal__DOT__qmul__30__Vfuncout 
                                = (IData)((__Vfunc_svo_traversal__DOT__qmul__30__p 
                                           >> 0x10U));
                            __Vfunc_svo_traversal__DOT__qmul__31__Vfuncout 
                                = (IData)((__Vfunc_svo_traversal__DOT__qmul__31__p 
                                           >> 0x10U));
                            __Vfunc_svo_traversal__DOT__qmul__32__Vfuncout 
                                = (IData)((__Vfunc_svo_traversal__DOT__qmul__32__p 
                                           >> 0x10U));
                            vlSelfRef.svo_traversal__DOT__rs_rma_x_r 
                                = __Vfunc_svo_traversal__DOT__qmul__30__Vfuncout;
                            vlSelfRef.svo_traversal__DOT__rs_rma_y_r 
                                = __Vfunc_svo_traversal__DOT__qmul__31__Vfuncout;
                            vlSelfRef.svo_traversal__DOT__rs_rma_z_r 
                                = __Vfunc_svo_traversal__DOT__qmul__32__Vfuncout;
                        }
                    } else if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                        if ((vlSelfRef.svo_traversal__DOT__rs_ndx_r 
                             >> 0x1fU)) {
                            __Vfunc_svo_traversal__DOT__qrecip_r0__33__xabs 
                                = (- vlSelfRef.svo_traversal__DOT__rs_ndx_r);
                            vlSelfRef.svo_traversal__DOT__rs_ax_r 
                                = (- vlSelfRef.svo_traversal__DOT__rs_ndx_r);
                        } else {
                            __Vfunc_svo_traversal__DOT__qrecip_r0__33__xabs 
                                = vlSelfRef.svo_traversal__DOT__rs_ndx_r;
                            vlSelfRef.svo_traversal__DOT__rs_ax_r 
                                = vlSelfRef.svo_traversal__DOT__rs_ndx_r;
                        }
                        if ((vlSelfRef.svo_traversal__DOT__rs_ndy_r 
                             >> 0x1fU)) {
                            __Vfunc_svo_traversal__DOT__qrecip_r0__34__xabs 
                                = (- vlSelfRef.svo_traversal__DOT__rs_ndy_r);
                            vlSelfRef.svo_traversal__DOT__rs_ay_r 
                                = (- vlSelfRef.svo_traversal__DOT__rs_ndy_r);
                        } else {
                            __Vfunc_svo_traversal__DOT__qrecip_r0__34__xabs 
                                = vlSelfRef.svo_traversal__DOT__rs_ndy_r;
                            vlSelfRef.svo_traversal__DOT__rs_ay_r 
                                = vlSelfRef.svo_traversal__DOT__rs_ndy_r;
                        }
                        if ((vlSelfRef.svo_traversal__DOT__rs_ndz_r 
                             >> 0x1fU)) {
                            __Vfunc_svo_traversal__DOT__qrecip_r0__35__xabs 
                                = (- vlSelfRef.svo_traversal__DOT__rs_ndz_r);
                            vlSelfRef.svo_traversal__DOT__rs_az_r 
                                = (- vlSelfRef.svo_traversal__DOT__rs_ndz_r);
                        } else {
                            __Vfunc_svo_traversal__DOT__qrecip_r0__35__xabs 
                                = vlSelfRef.svo_traversal__DOT__rs_ndz_r;
                            vlSelfRef.svo_traversal__DOT__rs_az_r 
                                = vlSelfRef.svo_traversal__DOT__rs_ndz_r;
                        }
                        __Vfunc_svo_traversal__DOT__qrecip_r0__33__Vfuncout 
                            = ((0U != (__Vfunc_svo_traversal__DOT__qrecip_r0__33__xabs 
                                       >> 0x10U)) ? 0x00010000U
                                : ((0x00008000U & __Vfunc_svo_traversal__DOT__qrecip_r0__33__xabs)
                                    ? 0x00018000U : 
                                   ((0x00004000U & __Vfunc_svo_traversal__DOT__qrecip_r0__33__xabs)
                                     ? 0x00030000U : 
                                    ((0x00002000U & __Vfunc_svo_traversal__DOT__qrecip_r0__33__xabs)
                                      ? 0x00060000U
                                      : ((0x00001000U 
                                          & __Vfunc_svo_traversal__DOT__qrecip_r0__33__xabs)
                                          ? 0x000c0000U
                                          : 0x00180000U)))));
                        __Vfunc_svo_traversal__DOT__qrecip_r0__34__Vfuncout 
                            = ((0U != (__Vfunc_svo_traversal__DOT__qrecip_r0__34__xabs 
                                       >> 0x10U)) ? 0x00010000U
                                : ((0x00008000U & __Vfunc_svo_traversal__DOT__qrecip_r0__34__xabs)
                                    ? 0x00018000U : 
                                   ((0x00004000U & __Vfunc_svo_traversal__DOT__qrecip_r0__34__xabs)
                                     ? 0x00030000U : 
                                    ((0x00002000U & __Vfunc_svo_traversal__DOT__qrecip_r0__34__xabs)
                                      ? 0x00060000U
                                      : ((0x00001000U 
                                          & __Vfunc_svo_traversal__DOT__qrecip_r0__34__xabs)
                                          ? 0x000c0000U
                                          : 0x00180000U)))));
                        __Vfunc_svo_traversal__DOT__qrecip_r0__35__Vfuncout 
                            = ((0U != (__Vfunc_svo_traversal__DOT__qrecip_r0__35__xabs 
                                       >> 0x10U)) ? 0x00010000U
                                : ((0x00008000U & __Vfunc_svo_traversal__DOT__qrecip_r0__35__xabs)
                                    ? 0x00018000U : 
                                   ((0x00004000U & __Vfunc_svo_traversal__DOT__qrecip_r0__35__xabs)
                                     ? 0x00030000U : 
                                    ((0x00002000U & __Vfunc_svo_traversal__DOT__qrecip_r0__35__xabs)
                                      ? 0x00060000U
                                      : ((0x00001000U 
                                          & __Vfunc_svo_traversal__DOT__qrecip_r0__35__xabs)
                                          ? 0x000c0000U
                                          : 0x00180000U)))));
                        vlSelfRef.svo_traversal__DOT__rs_r0x_r 
                            = __Vfunc_svo_traversal__DOT__qrecip_r0__33__Vfuncout;
                        vlSelfRef.svo_traversal__DOT__rs_r0y_r 
                            = __Vfunc_svo_traversal__DOT__qrecip_r0__34__Vfuncout;
                        vlSelfRef.svo_traversal__DOT__rs_r0z_r 
                            = __Vfunc_svo_traversal__DOT__qrecip_r0__35__Vfuncout;
                    } else {
                        __Vfunc_svo_traversal__DOT__qmul__36__b 
                            = vlSelfRef.svo_traversal__DOT__rs_rilinv2_r;
                        __Vfunc_svo_traversal__DOT__qmul__37__b 
                            = vlSelfRef.svo_traversal__DOT__rs_rilinv2_r;
                        __Vfunc_svo_traversal__DOT__qmul__38__b 
                            = vlSelfRef.svo_traversal__DOT__rs_rilinv2_r;
                        __Vfunc_svo_traversal__DOT__qmul__36__a 
                            = vlSelfRef.svo_traversal__DOT__rs_rsdx_r;
                        __Vfunc_svo_traversal__DOT__qmul__37__a 
                            = vlSelfRef.svo_traversal__DOT__rs_rsdy_r;
                        __Vfunc_svo_traversal__DOT__qmul__38__a 
                            = vlSelfRef.svo_traversal__DOT__rs_rsdz_r;
                        __Vfunc_svo_traversal__DOT__qmul__36__p 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__36__a), 
                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__36__b));
                        __Vfunc_svo_traversal__DOT__qmul__37__p 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__37__a), 
                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__37__b));
                        __Vfunc_svo_traversal__DOT__qmul__38__p 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__38__a), 
                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__38__b));
                        __Vfunc_svo_traversal__DOT__qmul__36__Vfuncout 
                            = (IData)((__Vfunc_svo_traversal__DOT__qmul__36__p 
                                       >> 0x10U));
                        __Vfunc_svo_traversal__DOT__qmul__37__Vfuncout 
                            = (IData)((__Vfunc_svo_traversal__DOT__qmul__37__p 
                                       >> 0x10U));
                        __Vfunc_svo_traversal__DOT__qmul__38__Vfuncout 
                            = (IData)((__Vfunc_svo_traversal__DOT__qmul__38__p 
                                       >> 0x10U));
                        vlSelfRef.svo_traversal__DOT__rs_ndx_r 
                            = __Vfunc_svo_traversal__DOT__qmul__36__Vfuncout;
                        vlSelfRef.svo_traversal__DOT__rs_ndy_r 
                            = __Vfunc_svo_traversal__DOT__qmul__37__Vfuncout;
                        vlSelfRef.svo_traversal__DOT__rs_ndz_r 
                            = __Vfunc_svo_traversal__DOT__qmul__38__Vfuncout;
                    }
                } else if ((4U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                    if ((2U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                        if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                            __Vfunc_svo_traversal__DOT__qmul__39__b 
                                = vlSelfRef.svo_traversal__DOT__rs_rilsub_r;
                            __Vfunc_svo_traversal__DOT__qmul__39__a 
                                = vlSelfRef.svo_traversal__DOT__rs_rilinv_r;
                            __Vfunc_svo_traversal__DOT__qmul__39__p 
                                = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__39__a), 
                                              VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__39__b));
                            __Vfunc_svo_traversal__DOT__qmul__39__Vfuncout 
                                = (IData)((__Vfunc_svo_traversal__DOT__qmul__39__p 
                                           >> 0x10U));
                            vlSelfRef.svo_traversal__DOT__rs_rilinv2_r 
                                = __Vfunc_svo_traversal__DOT__qmul__39__Vfuncout;
                        } else {
                            __Vfunc_svo_traversal__DOT__qmul__40__b 
                                = vlSelfRef.svo_traversal__DOT__rs_riltmp_r;
                            __Vfunc_svo_traversal__DOT__qmul__40__p 
                                = VL_MULS_QQQ(64, 0x0000000000008000ULL, 
                                              VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__40__b));
                            vlSelfRef.svo_traversal__DOT____VlemCall_16__qmul 
                                = (IData)((__Vfunc_svo_traversal__DOT__qmul__40__p 
                                           >> 0x10U));
                            vlSelfRef.svo_traversal__DOT__rs_rilsub_r 
                                = ((IData)(0x00018000U) 
                                   - vlSelfRef.svo_traversal__DOT____VlemCall_16__qmul);
                        }
                    } else if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                        __Vfunc_svo_traversal__DOT__qmul__41__b 
                            = vlSelfRef.svo_traversal__DOT__rs_rilsq_r;
                        __Vfunc_svo_traversal__DOT__qmul__41__a 
                            = vlSelfRef.svo_traversal__DOT__rs_rslen2_r;
                        __Vfunc_svo_traversal__DOT__qmul__41__p 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__41__a), 
                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__41__b));
                        __Vfunc_svo_traversal__DOT__qmul__41__Vfuncout 
                            = (IData)((__Vfunc_svo_traversal__DOT__qmul__41__p 
                                       >> 0x10U));
                        vlSelfRef.svo_traversal__DOT__rs_riltmp_r 
                            = __Vfunc_svo_traversal__DOT__qmul__41__Vfuncout;
                    } else {
                        __Vfunc_svo_traversal__DOT__qmul__42__b 
                            = vlSelfRef.svo_traversal__DOT__rs_rilinv_r;
                        __Vfunc_svo_traversal__DOT__qmul__42__a 
                            = vlSelfRef.svo_traversal__DOT__rs_rilinv_r;
                        __Vfunc_svo_traversal__DOT__qmul__42__p 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__42__a), 
                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__42__b));
                        __Vfunc_svo_traversal__DOT__qmul__42__Vfuncout 
                            = (IData)((__Vfunc_svo_traversal__DOT__qmul__42__p 
                                       >> 0x10U));
                        vlSelfRef.svo_traversal__DOT__rs_rilsq_r 
                            = __Vfunc_svo_traversal__DOT__qmul__42__Vfuncout;
                    }
                } else if ((2U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                    if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                        __Vfunc_svo_traversal__DOT__qmul__43__b 
                            = vlSelfRef.svo_traversal__DOT__rs_rslen2_r;
                        __Vfunc_svo_traversal__DOT__qmul__43__p 
                            = VL_MULS_QQQ(64, 0x0000000000008000ULL, 
                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__43__b));
                        vlSelfRef.svo_traversal__DOT____VlemCall_15__qmul 
                            = (IData)((__Vfunc_svo_traversal__DOT__qmul__43__p 
                                       >> 0x10U));
                        vlSelfRef.svo_traversal__DOT__rs_rilinv_r 
                            = ((IData)(0x00018000U) 
                               - vlSelfRef.svo_traversal__DOT____VlemCall_15__qmul);
                    } else {
                        __Vfunc_svo_traversal__DOT__qmul__44__b 
                            = vlSelfRef.svo_traversal__DOT__rs_rsdx_r;
                        __Vfunc_svo_traversal__DOT__qmul__44__a 
                            = vlSelfRef.svo_traversal__DOT__rs_rsdx_r;
                        __Vfunc_svo_traversal__DOT__qmul__44__p 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__44__a), 
                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__44__b));
                        vlSelfRef.svo_traversal__DOT____VlemCall_12__qmul 
                            = (IData)((__Vfunc_svo_traversal__DOT__qmul__44__p 
                                       >> 0x10U));
                        __Vfunc_svo_traversal__DOT__qmul__45__b 
                            = vlSelfRef.svo_traversal__DOT__rs_rsdy_r;
                        __Vfunc_svo_traversal__DOT__qmul__45__a 
                            = vlSelfRef.svo_traversal__DOT__rs_rsdy_r;
                        __Vfunc_svo_traversal__DOT__qmul__45__p 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__45__a), 
                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__45__b));
                        vlSelfRef.svo_traversal__DOT____VlemCall_13__qmul 
                            = (IData)((__Vfunc_svo_traversal__DOT__qmul__45__p 
                                       >> 0x10U));
                        __Vfunc_svo_traversal__DOT__qmul__46__b 
                            = vlSelfRef.svo_traversal__DOT__rs_rsdz_r;
                        __Vfunc_svo_traversal__DOT__qmul__46__a 
                            = vlSelfRef.svo_traversal__DOT__rs_rsdz_r;
                        __Vfunc_svo_traversal__DOT__qmul__46__p 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__46__a), 
                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__46__b));
                        vlSelfRef.svo_traversal__DOT____VlemCall_14__qmul 
                            = (IData)((__Vfunc_svo_traversal__DOT__qmul__46__p 
                                       >> 0x10U));
                        vlSelfRef.svo_traversal__DOT__rs_rslen2_r 
                            = ((vlSelfRef.svo_traversal__DOT____VlemCall_12__qmul 
                                + vlSelfRef.svo_traversal__DOT____VlemCall_13__qmul) 
                               + vlSelfRef.svo_traversal__DOT____VlemCall_14__qmul);
                    }
                } else if ((1U & (IData)(vlSelfRef.svo_traversal__DOT__rs_wait))) {
                    __Vfunc_svo_traversal__DOT__qmul__47__b 
                        = vlSelfRef.svo_traversal__DOT__cam_right_x;
                    __Vfunc_svo_traversal__DOT__qmul__49__b 
                        = vlSelfRef.svo_traversal__DOT__cam_right_y;
                    __Vfunc_svo_traversal__DOT__qmul__51__b 
                        = vlSelfRef.svo_traversal__DOT__cam_right_z;
                    __Vfunc_svo_traversal__DOT__qmul__47__a 
                        = vlSelfRef.svo_traversal__DOT__rs_rsu_r;
                    __Vfunc_svo_traversal__DOT__qmul__49__a 
                        = vlSelfRef.svo_traversal__DOT__rs_rsu_r;
                    __Vfunc_svo_traversal__DOT__qmul__51__a 
                        = vlSelfRef.svo_traversal__DOT__rs_rsu_r;
                    __Vfunc_svo_traversal__DOT__qmul__47__p 
                        = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__47__a), 
                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__47__b));
                    __Vfunc_svo_traversal__DOT__qmul__49__p 
                        = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__49__a), 
                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__49__b));
                    __Vfunc_svo_traversal__DOT__qmul__51__p 
                        = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__51__a), 
                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__51__b));
                    vlSelfRef.svo_traversal__DOT____VlemCall_6__qmul 
                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__47__p 
                                   >> 0x10U));
                    vlSelfRef.svo_traversal__DOT____VlemCall_8__qmul 
                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__49__p 
                                   >> 0x10U));
                    vlSelfRef.svo_traversal__DOT____VlemCall_10__qmul 
                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__51__p 
                                   >> 0x10U));
                    __Vfunc_svo_traversal__DOT__qmul__48__b 
                        = vlSelfRef.svo_traversal__DOT__cam_up_x;
                    __Vfunc_svo_traversal__DOT__qmul__50__b 
                        = vlSelfRef.svo_traversal__DOT__cam_up_y;
                    __Vfunc_svo_traversal__DOT__qmul__52__b 
                        = vlSelfRef.svo_traversal__DOT__cam_up_z;
                    __Vfunc_svo_traversal__DOT__qmul__48__a 
                        = vlSelfRef.svo_traversal__DOT__rs_rsv_r;
                    __Vfunc_svo_traversal__DOT__qmul__50__a 
                        = vlSelfRef.svo_traversal__DOT__rs_rsv_r;
                    __Vfunc_svo_traversal__DOT__qmul__52__a 
                        = vlSelfRef.svo_traversal__DOT__rs_rsv_r;
                    __Vfunc_svo_traversal__DOT__qmul__48__p 
                        = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__48__a), 
                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__48__b));
                    __Vfunc_svo_traversal__DOT__qmul__50__p 
                        = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__50__a), 
                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__50__b));
                    __Vfunc_svo_traversal__DOT__qmul__52__p 
                        = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__52__a), 
                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__52__b));
                    vlSelfRef.svo_traversal__DOT____VlemCall_7__qmul 
                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__48__p 
                                   >> 0x10U));
                    vlSelfRef.svo_traversal__DOT____VlemCall_9__qmul 
                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__50__p 
                                   >> 0x10U));
                    vlSelfRef.svo_traversal__DOT____VlemCall_11__qmul 
                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__52__p 
                                   >> 0x10U));
                    vlSelfRef.svo_traversal__DOT__rs_rsdx_r 
                        = ((vlSelfRef.svo_traversal__DOT__cam_fwd_x 
                            + vlSelfRef.svo_traversal__DOT____VlemCall_6__qmul) 
                           - vlSelfRef.svo_traversal__DOT____VlemCall_7__qmul);
                    vlSelfRef.svo_traversal__DOT__rs_rsdy_r 
                        = ((vlSelfRef.svo_traversal__DOT__cam_fwd_y 
                            + vlSelfRef.svo_traversal__DOT____VlemCall_8__qmul) 
                           - vlSelfRef.svo_traversal__DOT____VlemCall_9__qmul);
                    vlSelfRef.svo_traversal__DOT__rs_rsdz_r 
                        = ((vlSelfRef.svo_traversal__DOT__cam_fwd_z 
                            + vlSelfRef.svo_traversal__DOT____VlemCall_10__qmul) 
                           - vlSelfRef.svo_traversal__DOT____VlemCall_11__qmul);
                } else {
                    __Vfunc_svo_traversal__DOT__qmul__53__b 
                        = vlSelfRef.svo_traversal__DOT__cam_scale;
                    __Vfunc_svo_traversal__DOT__qmul__54__b 
                        = vlSelfRef.svo_traversal__DOT__cam_scale;
                    __Vfunc_svo_traversal__DOT__qmul__53__a 
                        = (VL_EXTENDS_II(32,26, ((IData)(vlSelfRef.svo_traversal__DOT__px) 
                                                 << 0x00000010U)) 
                           - (IData)(0x00a00000U));
                    __Vfunc_svo_traversal__DOT__qmul__54__a 
                        = (VL_EXTENDS_II(32,25, ((IData)(vlSelfRef.svo_traversal__DOT__py) 
                                                 << 0x00000010U)) 
                           - (IData)(0x00780000U));
                    __Vfunc_svo_traversal__DOT__qmul__53__p 
                        = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__53__a), 
                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__53__b));
                    __Vfunc_svo_traversal__DOT__qmul__54__p 
                        = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__54__a), 
                                      VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__54__b));
                    __Vfunc_svo_traversal__DOT__qmul__53__Vfuncout 
                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__53__p 
                                   >> 0x10U));
                    __Vfunc_svo_traversal__DOT__qmul__54__Vfuncout 
                        = (IData)((__Vfunc_svo_traversal__DOT__qmul__54__p 
                                   >> 0x10U));
                    vlSelfRef.svo_traversal__DOT__rs_rsu_r 
                        = __Vfunc_svo_traversal__DOT__qmul__53__Vfuncout;
                    vlSelfRef.svo_traversal__DOT__rs_rsv_r 
                        = __Vfunc_svo_traversal__DOT__qmul__54__Vfuncout;
                }
            }
        } else {
            vlSelfRef.svo_traversal__DOT__busy = 0U;
            if (vlSelfRef.svo_traversal__DOT__start) {
                vlSelfRef.svo_traversal__DOT__busy = 1U;
                __Vdly__svo_traversal__DOT__px = 0U;
                __Vdly__svo_traversal__DOT__py = 0U;
                __Vdly__svo_traversal__DOT__sp = 0U;
                __Vdly__svo_traversal__DOT__rs_wait = 0U;
                __Vdly__svo_traversal__DOT__node_half = 0x20U;
                __Vdly__svo_traversal__DOT__state = 1U;
            }
        }
    }
    vlSelfRef.svo_traversal__DOT__post_pop = __Vdly__svo_traversal__DOT__post_pop;
    vlSelfRef.svo_traversal__DOT__node_idx = __Vdly__svo_traversal__DOT__node_idx;
    vlSelfRef.svo_traversal__DOT__dt_x = __Vdly__svo_traversal__DOT__dt_x;
    vlSelfRef.svo_traversal__DOT__dt_y = __Vdly__svo_traversal__DOT__dt_y;
    vlSelfRef.svo_traversal__DOT__dt_z = __Vdly__svo_traversal__DOT__dt_z;
    vlSelfRef.svo_traversal__DOT__r_bitmask = __Vdly__svo_traversal__DOT__r_bitmask;
    vlSelfRef.svo_traversal__DOT__t_max = __Vdly__svo_traversal__DOT__t_max;
    vlSelfRef.svo_traversal__DOT__t_next_x = __Vdly__svo_traversal__DOT__t_next_x;
    vlSelfRef.svo_traversal__DOT__t_next_y = __Vdly__svo_traversal__DOT__t_next_y;
    vlSelfRef.svo_traversal__DOT__t_next_z = __Vdly__svo_traversal__DOT__t_next_z;
    vlSelfRef.svo_traversal__DOT__cx = __Vdly__svo_traversal__DOT__cx;
    vlSelfRef.svo_traversal__DOT__cy = __Vdly__svo_traversal__DOT__cy;
    vlSelfRef.svo_traversal__DOT__cz = __Vdly__svo_traversal__DOT__cz;
    vlSelfRef.svo_traversal__DOT__bram_field = __Vdly__svo_traversal__DOT__bram_field;
    if (__VdlySet__svo_traversal__DOT__stk_node_idx__v0) {
        vlSelfRef.svo_traversal__DOT__stk_node_idx[__VdlyDim0__svo_traversal__DOT__stk_node_idx__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_node_idx__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_bitmask__v0) {
        vlSelfRef.svo_traversal__DOT__stk_bitmask[__VdlyDim0__svo_traversal__DOT__stk_bitmask__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_bitmask__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_t_min__v0) {
        vlSelfRef.svo_traversal__DOT__stk_t_min[__VdlyDim0__svo_traversal__DOT__stk_t_min__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_t_min__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_t_max__v0) {
        vlSelfRef.svo_traversal__DOT__stk_t_max[__VdlyDim0__svo_traversal__DOT__stk_t_max__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_t_max__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_t_next_x__v0) {
        vlSelfRef.svo_traversal__DOT__stk_t_next_x[__VdlyDim0__svo_traversal__DOT__stk_t_next_x__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_t_next_x__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_t_next_y__v0) {
        vlSelfRef.svo_traversal__DOT__stk_t_next_y[__VdlyDim0__svo_traversal__DOT__stk_t_next_y__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_t_next_y__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_t_next_z__v0) {
        vlSelfRef.svo_traversal__DOT__stk_t_next_z[__VdlyDim0__svo_traversal__DOT__stk_t_next_z__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_t_next_z__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_cx__v0) {
        vlSelfRef.svo_traversal__DOT__stk_cx[__VdlyDim0__svo_traversal__DOT__stk_cx__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_cx__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_cy__v0) {
        vlSelfRef.svo_traversal__DOT__stk_cy[__VdlyDim0__svo_traversal__DOT__stk_cy__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_cy__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_cz__v0) {
        vlSelfRef.svo_traversal__DOT__stk_cz[__VdlyDim0__svo_traversal__DOT__stk_cz__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_cz__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_orig_x__v0) {
        vlSelfRef.svo_traversal__DOT__stk_orig_x[__VdlyDim0__svo_traversal__DOT__stk_orig_x__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_orig_x__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_orig_y__v0) {
        vlSelfRef.svo_traversal__DOT__stk_orig_y[__VdlyDim0__svo_traversal__DOT__stk_orig_y__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_orig_y__v0;
    }
    if (__VdlySet__svo_traversal__DOT__stk_orig_z__v0) {
        vlSelfRef.svo_traversal__DOT__stk_orig_z[__VdlyDim0__svo_traversal__DOT__stk_orig_z__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_orig_z__v0;
    }
    vlSelfRef.svo_traversal__DOT__px = __Vdly__svo_traversal__DOT__px;
    vlSelfRef.svo_traversal__DOT__py = __Vdly__svo_traversal__DOT__py;
    vlSelfRef.svo_traversal__DOT__rs_wait = __Vdly__svo_traversal__DOT__rs_wait;
    vlSelfRef.svo_traversal__DOT__state = __Vdly__svo_traversal__DOT__state;
    if (__VdlySet__svo_traversal__DOT__r_block__v0) {
        vlSelfRef.svo_traversal__DOT__r_block[4U] = __VdlyVal__svo_traversal__DOT__r_block__v0;
        vlSelfRef.svo_traversal__DOT__r_block[5U] = __VdlyVal__svo_traversal__DOT__r_block__v1;
        vlSelfRef.svo_traversal__DOT__r_block[6U] = __VdlyVal__svo_traversal__DOT__r_block__v2;
        vlSelfRef.svo_traversal__DOT__r_block[7U] = __VdlyVal__svo_traversal__DOT__r_block__v3;
    }
    if (__VdlySet__svo_traversal__DOT__r_block__v4) {
        vlSelfRef.svo_traversal__DOT__r_block[0U] = __VdlyVal__svo_traversal__DOT__r_block__v4;
    }
    if (__VdlySet__svo_traversal__DOT__r_block__v5) {
        vlSelfRef.svo_traversal__DOT__r_block[1U] = __VdlyVal__svo_traversal__DOT__r_block__v5;
        vlSelfRef.svo_traversal__DOT__r_block[2U] = __VdlyVal__svo_traversal__DOT__r_block__v6;
        vlSelfRef.svo_traversal__DOT__r_block[3U] = __VdlyVal__svo_traversal__DOT__r_block__v7;
    }
    if (__VdlySet__svo_traversal__DOT__r_child__v0) {
        vlSelfRef.svo_traversal__DOT__r_child[6U] = __VdlyVal__svo_traversal__DOT__r_child__v0;
    }
    if (__VdlySet__svo_traversal__DOT__r_child__v1) {
        vlSelfRef.svo_traversal__DOT__r_child[7U] = __VdlyVal__svo_traversal__DOT__r_child__v1;
    }
    if (__VdlySet__svo_traversal__DOT__r_child__v2) {
        vlSelfRef.svo_traversal__DOT__r_child[4U] = __VdlyVal__svo_traversal__DOT__r_child__v2;
    }
    if (__VdlySet__svo_traversal__DOT__r_child__v3) {
        vlSelfRef.svo_traversal__DOT__r_child[5U] = __VdlyVal__svo_traversal__DOT__r_child__v3;
    }
    if (__VdlySet__svo_traversal__DOT__r_child__v4) {
        vlSelfRef.svo_traversal__DOT__r_child[2U] = __VdlyVal__svo_traversal__DOT__r_child__v4;
    }
    if (__VdlySet__svo_traversal__DOT__r_child__v5) {
        vlSelfRef.svo_traversal__DOT__r_child[3U] = __VdlyVal__svo_traversal__DOT__r_child__v5;
    }
    if (__VdlySet__svo_traversal__DOT__r_child__v6) {
        vlSelfRef.svo_traversal__DOT__r_child[0U] = __VdlyVal__svo_traversal__DOT__r_child__v6;
    }
    if (__VdlySet__svo_traversal__DOT__r_child__v7) {
        vlSelfRef.svo_traversal__DOT__r_child[1U] = __VdlyVal__svo_traversal__DOT__r_child__v7;
    }
    vlSelfRef.svo_traversal__DOT__node_origin_x = __Vdly__svo_traversal__DOT__node_origin_x;
    vlSelfRef.svo_traversal__DOT__node_origin_y = __Vdly__svo_traversal__DOT__node_origin_y;
    vlSelfRef.svo_traversal__DOT__node_origin_z = __Vdly__svo_traversal__DOT__node_origin_z;
    vlSelfRef.svo_traversal__DOT__sp = __Vdly__svo_traversal__DOT__sp;
    if (__VdlySet__svo_traversal__DOT__stk_node_half__v0) {
        vlSelfRef.svo_traversal__DOT__stk_node_half[__VdlyDim0__svo_traversal__DOT__stk_node_half__v0] 
            = __VdlyVal__svo_traversal__DOT__stk_node_half__v0;
    }
    vlSelfRef.svo_traversal__DOT__t_min = __Vdly__svo_traversal__DOT__t_min;
    vlSelfRef.svo_traversal__DOT__node_half = __Vdly__svo_traversal__DOT__node_half;
    vlSelfRef.busy = vlSelfRef.svo_traversal__DOT__busy;
    vlSelfRef.frame_done = vlSelfRef.svo_traversal__DOT__frame_done;
    vlSelfRef.any_hit = vlSelfRef.svo_traversal__DOT__any_hit;
    vlSelfRef.fb_wr_en = vlSelfRef.svo_traversal__DOT__fb_wr_en;
    vlSelfRef.svo_rd_en = vlSelfRef.svo_traversal__DOT__svo_rd_en;
    vlSelfRef.shade_start = vlSelfRef.svo_traversal__DOT__shade_start;
    vlSelfRef.axis_tdata = vlSelfRef.svo_traversal__DOT__axis_tdata;
    vlSelfRef.axis_tlast = vlSelfRef.svo_traversal__DOT__axis_tlast;
    vlSelfRef.axis_tuser = vlSelfRef.svo_traversal__DOT__axis_tuser;
    vlSelfRef.svo_rd_addr = vlSelfRef.svo_traversal__DOT__svo_rd_addr;
    vlSelfRef.svo_traversal__DOT__dbg_px = vlSelfRef.svo_traversal__DOT__px;
    vlSelfRef.svo_traversal__DOT__dbg_py = vlSelfRef.svo_traversal__DOT__py;
    vlSelfRef.svo_traversal__DOT__dbg_rs_wait = vlSelfRef.svo_traversal__DOT__rs_wait;
    vlSelfRef.svo_traversal__DOT__state_raw = vlSelfRef.svo_traversal__DOT__state;
    vlSelfRef.axis_tvalid = vlSelfRef.svo_traversal__DOT__axis_tvalid;
    vlSelfRef.svo_traversal__DOT__dbg_tvalid = vlSelfRef.svo_traversal__DOT__axis_tvalid;
    vlSelfRef.svo_traversal__DOT__bw_abs_ix_c = ((vlSelfRef.svo_traversal__DOT__inv_x 
                                                  >> 0x0000001fU)
                                                  ? 
                                                 (- vlSelfRef.svo_traversal__DOT__inv_x)
                                                  : vlSelfRef.svo_traversal__DOT__inv_x);
    vlSelfRef.svo_traversal__DOT__bw_abs_iy_c = ((vlSelfRef.svo_traversal__DOT__inv_y 
                                                  >> 0x0000001fU)
                                                  ? 
                                                 (- vlSelfRef.svo_traversal__DOT__inv_y)
                                                  : vlSelfRef.svo_traversal__DOT__inv_y);
    vlSelfRef.svo_traversal__DOT__bw_abs_iz_c = ((vlSelfRef.svo_traversal__DOT__inv_z 
                                                  >> 0x0000001fU)
                                                  ? 
                                                 (- vlSelfRef.svo_traversal__DOT__inv_z)
                                                  : vlSelfRef.svo_traversal__DOT__inv_z);
    vlSelfRef.svo_traversal__DOT__bw_ex_c = (vlSelfRef.svo_traversal__DOT__ro_x 
                                             + (IData)(
                                                       (VL_MULS_QQQ(64, 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__t_min), 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__rd_x)) 
                                                        >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_ey_c = (vlSelfRef.svo_traversal__DOT__ro_y 
                                             + (IData)(
                                                       (VL_MULS_QQQ(64, 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__t_min), 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__rd_y)) 
                                                        >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_ez_c = (vlSelfRef.svo_traversal__DOT__ro_z 
                                             + (IData)(
                                                       (VL_MULS_QQQ(64, 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__t_min), 
                                                                    VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__rd_z)) 
                                                        >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_nh_c = VL_SHIFTL_III(32,32,32, (IData)(vlSelfRef.svo_traversal__DOT__node_half), 0x00000010U);
    vlSelfRef.dbg_px = vlSelfRef.svo_traversal__DOT__dbg_px;
    vlSelfRef.dbg_py = vlSelfRef.svo_traversal__DOT__dbg_py;
    vlSelfRef.dbg_rs_wait = vlSelfRef.svo_traversal__DOT__dbg_rs_wait;
    vlSelfRef.svo_traversal__DOT__dbg_state = vlSelfRef.svo_traversal__DOT__state_raw;
    vlSelfRef.dbg_tvalid = vlSelfRef.svo_traversal__DOT__dbg_tvalid;
    __Vfunc_svo_traversal__DOT__qmul__9__b = vlSelfRef.svo_traversal__DOT__bw_abs_ix_c;
    __Vfunc_svo_traversal__DOT__qmul__9__a = (((0x0bU 
                                                >= 
                                                (0x0000000fU 
                                                 & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                    - (IData)(1U))))
                                                ? vlSelfRef.svo_traversal__DOT__stk_node_half
                                               [(0x0000000fU 
                                                 & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                    - (IData)(1U)))]
                                                : 0U) 
                                              << 0x00000010U);
    __Vfunc_svo_traversal__DOT__qmul__9__p = VL_MULS_QQQ(64, 
                                                         VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__9__a), 
                                                         VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__9__b));
    __Vfunc_svo_traversal__DOT__qmul__9__Vfuncout = (IData)(
                                                            (__Vfunc_svo_traversal__DOT__qmul__9__p 
                                                             >> 0x10U));
    vlSelfRef.svo_traversal__DOT__dt_x_pop_c = __Vfunc_svo_traversal__DOT__qmul__9__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__10__b = vlSelfRef.svo_traversal__DOT__bw_abs_iy_c;
    __Vfunc_svo_traversal__DOT__qmul__10__a = (((0x0bU 
                                                 >= 
                                                 (0x0000000fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                     - (IData)(1U))))
                                                 ? vlSelfRef.svo_traversal__DOT__stk_node_half
                                                [(0x0000000fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                     - (IData)(1U)))]
                                                 : 0U) 
                                               << 0x00000010U);
    __Vfunc_svo_traversal__DOT__qmul__10__p = VL_MULS_QQQ(64, 
                                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__10__a), 
                                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__10__b));
    __Vfunc_svo_traversal__DOT__qmul__10__Vfuncout 
        = (IData)((__Vfunc_svo_traversal__DOT__qmul__10__p 
                   >> 0x10U));
    vlSelfRef.svo_traversal__DOT__dt_y_pop_c = __Vfunc_svo_traversal__DOT__qmul__10__Vfuncout;
    __Vfunc_svo_traversal__DOT__qmul__11__b = vlSelfRef.svo_traversal__DOT__bw_abs_iz_c;
    __Vfunc_svo_traversal__DOT__qmul__11__a = (((0x0bU 
                                                 >= 
                                                 (0x0000000fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                     - (IData)(1U))))
                                                 ? vlSelfRef.svo_traversal__DOT__stk_node_half
                                                [(0x0000000fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__sp) 
                                                     - (IData)(1U)))]
                                                 : 0U) 
                                               << 0x00000010U);
    __Vfunc_svo_traversal__DOT__qmul__11__p = VL_MULS_QQQ(64, 
                                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__11__a), 
                                                          VL_EXTENDS_QI(64,32, __Vfunc_svo_traversal__DOT__qmul__11__b));
    __Vfunc_svo_traversal__DOT__qmul__11__Vfuncout 
        = (IData)((__Vfunc_svo_traversal__DOT__qmul__11__p 
                   >> 0x10U));
    vlSelfRef.svo_traversal__DOT__dt_z_pop_c = __Vfunc_svo_traversal__DOT__qmul__11__Vfuncout;
    vlSelfRef.svo_traversal__DOT__dt_x_bw_c = (IData)(
                                                      (VL_MULS_QQQ(64, 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_nh_c), 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_ix_c)) 
                                                       >> 0x00000010U));
    vlSelfRef.svo_traversal__DOT__dt_y_bw_c = (IData)(
                                                      (VL_MULS_QQQ(64, 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_nh_c), 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_iy_c)) 
                                                       >> 0x00000010U));
    vlSelfRef.svo_traversal__DOT__dt_z_bw_c = (IData)(
                                                      (VL_MULS_QQQ(64, 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_nh_c), 
                                                                   VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_iz_c)) 
                                                       >> 0x00000010U));
    vlSelfRef.svo_traversal__DOT__bw_icx_c = (VL_GTS_III(32, 0U, vlSelfRef.svo_traversal__DOT__bw_ex_c)
                                               ? 0U
                                               : (0x0000007fU 
                                                  & (vlSelfRef.svo_traversal__DOT__bw_ex_c 
                                                     >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_icx_c = (((IData)(vlSelfRef.svo_traversal__DOT__bw_icx_c) 
                                               >= (IData)(vlSelfRef.svo_traversal__DOT__node_origin_x))
                                               ? (0x0000007fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__bw_icx_c) 
                                                     - (IData)(vlSelfRef.svo_traversal__DOT__node_origin_x)))
                                               : 0U);
    vlSelfRef.svo_traversal__DOT__bw_ex_rel_c = (vlSelfRef.svo_traversal__DOT__bw_ex_c 
                                                 - 
                                                 VL_SHIFTL_III(32,32,32, (IData)(vlSelfRef.svo_traversal__DOT__node_origin_x), 0x00000010U));
    vlSelfRef.svo_traversal__DOT__bw_dist_x_c = ((4U 
                                                  & (IData)(vlSelfRef.svo_traversal__DOT__step_x))
                                                  ? 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icx_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (vlSelfRef.svo_traversal__DOT__bw_ex_rel_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_nh_c)
                                                   : vlSelfRef.svo_traversal__DOT__bw_ex_rel_c)
                                                  : 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icx_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (VL_SHIFTL_III(32,32,32, vlSelfRef.svo_traversal__DOT__bw_nh_c, 1U) 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ex_rel_c)
                                                   : 
                                                  (vlSelfRef.svo_traversal__DOT__bw_nh_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ex_rel_c)));
    vlSelfRef.svo_traversal__DOT__bw_icy_c = (VL_GTS_III(32, 0U, vlSelfRef.svo_traversal__DOT__bw_ey_c)
                                               ? 0U
                                               : (0x0000007fU 
                                                  & (vlSelfRef.svo_traversal__DOT__bw_ey_c 
                                                     >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_icy_c = (((IData)(vlSelfRef.svo_traversal__DOT__bw_icy_c) 
                                               >= (IData)(vlSelfRef.svo_traversal__DOT__node_origin_y))
                                               ? (0x0000007fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__bw_icy_c) 
                                                     - (IData)(vlSelfRef.svo_traversal__DOT__node_origin_y)))
                                               : 0U);
    vlSelfRef.svo_traversal__DOT__bw_ey_rel_c = (vlSelfRef.svo_traversal__DOT__bw_ey_c 
                                                 - 
                                                 VL_SHIFTL_III(32,32,32, (IData)(vlSelfRef.svo_traversal__DOT__node_origin_y), 0x00000010U));
    vlSelfRef.svo_traversal__DOT__bw_dist_y_c = ((4U 
                                                  & (IData)(vlSelfRef.svo_traversal__DOT__step_y))
                                                  ? 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icy_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (vlSelfRef.svo_traversal__DOT__bw_ey_rel_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_nh_c)
                                                   : vlSelfRef.svo_traversal__DOT__bw_ey_rel_c)
                                                  : 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icy_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (VL_SHIFTL_III(32,32,32, vlSelfRef.svo_traversal__DOT__bw_nh_c, 1U) 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ey_rel_c)
                                                   : 
                                                  (vlSelfRef.svo_traversal__DOT__bw_nh_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ey_rel_c)));
    vlSelfRef.svo_traversal__DOT__bw_icz_c = (VL_GTS_III(32, 0U, vlSelfRef.svo_traversal__DOT__bw_ez_c)
                                               ? 0U
                                               : (0x0000007fU 
                                                  & (vlSelfRef.svo_traversal__DOT__bw_ez_c 
                                                     >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__bw_icz_c = (((IData)(vlSelfRef.svo_traversal__DOT__bw_icz_c) 
                                               >= (IData)(vlSelfRef.svo_traversal__DOT__node_origin_z))
                                               ? (0x0000007fU 
                                                  & ((IData)(vlSelfRef.svo_traversal__DOT__bw_icz_c) 
                                                     - (IData)(vlSelfRef.svo_traversal__DOT__node_origin_z)))
                                               : 0U);
    vlSelfRef.svo_traversal__DOT__bw_ez_rel_c = (vlSelfRef.svo_traversal__DOT__bw_ez_c 
                                                 - 
                                                 VL_SHIFTL_III(32,32,32, (IData)(vlSelfRef.svo_traversal__DOT__node_origin_z), 0x00000010U));
    vlSelfRef.svo_traversal__DOT__bw_dist_z_c = ((4U 
                                                  & (IData)(vlSelfRef.svo_traversal__DOT__step_z))
                                                  ? 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icz_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (vlSelfRef.svo_traversal__DOT__bw_ez_rel_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_nh_c)
                                                   : vlSelfRef.svo_traversal__DOT__bw_ez_rel_c)
                                                  : 
                                                 (((IData)(vlSelfRef.svo_traversal__DOT__bw_icz_c) 
                                                   >= (IData)(vlSelfRef.svo_traversal__DOT__node_half))
                                                   ? 
                                                  (VL_SHIFTL_III(32,32,32, vlSelfRef.svo_traversal__DOT__bw_nh_c, 1U) 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ez_rel_c)
                                                   : 
                                                  (vlSelfRef.svo_traversal__DOT__bw_nh_c 
                                                   - vlSelfRef.svo_traversal__DOT__bw_ez_rel_c)));
    vlSelfRef.dbg_state = vlSelfRef.svo_traversal__DOT__dbg_state;
    vlSelfRef.svo_traversal__DOT__t_next_x_bw_c = (vlSelfRef.svo_traversal__DOT__t_min 
                                                   + (IData)(
                                                             (VL_MULS_QQQ(64, 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_ix_c), 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_dist_x_c)) 
                                                              >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__t_next_y_bw_c = (vlSelfRef.svo_traversal__DOT__t_min 
                                                   + (IData)(
                                                             (VL_MULS_QQQ(64, 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_iy_c), 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_dist_y_c)) 
                                                              >> 0x00000010U)));
    vlSelfRef.svo_traversal__DOT__t_next_z_bw_c = (vlSelfRef.svo_traversal__DOT__t_min 
                                                   + (IData)(
                                                             (VL_MULS_QQQ(64, 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_abs_iz_c), 
                                                                          VL_EXTENDS_QI(64,32, vlSelfRef.svo_traversal__DOT__bw_dist_z_c)) 
                                                              >> 0x00000010U)));
}

void Vtop___024root___eval_nba(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_nba\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
        Vtop___024root___nba_sequent__TOP__0(vlSelf);
    }
}

void Vtop___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((0U >= n));
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtop___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vtop___024root___eval_phase__act(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_phase__act\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtop___024root___eval_triggers_vec__act(vlSelf);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtop___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vtop___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    return (0U);
}

void Vtop___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

bool Vtop___024root___eval_phase__nba(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_phase__nba\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vtop___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        Vtop___024root___eval_nba(vlSelf);
        Vtop___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

void Vtop___024root___eval(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VicoIterCount;
    IData/*31:0*/ __VnbaIterCount;
    // Body
    __VicoIterCount = 0U;
    vlSelfRef.__VicoFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VicoIterCount)))) {
#ifdef VL_DEBUG
            Vtop___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
            VL_FATAL_MT("/home/ali/git/fyp/vivado/ip/svo_raytracer/hdl/svo_traversal.sv", 14, "", "DIDNOTCONVERGE: Input combinational region did not converge after '--converge-limit' of 10000 tries");
        }
        __VicoIterCount = ((IData)(1U) + __VicoIterCount);
        vlSelfRef.__VicoPhaseResult = Vtop___024root___eval_phase__ico(vlSelf);
        vlSelfRef.__VicoFirstIteration = 0U;
    } while (vlSelfRef.__VicoPhaseResult);
    __VnbaIterCount = 0U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VnbaIterCount)))) {
#ifdef VL_DEBUG
            Vtop___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
            VL_FATAL_MT("/home/ali/git/fyp/vivado/ip/svo_raytracer/hdl/svo_traversal.sv", 14, "", "DIDNOTCONVERGE: NBA region did not converge after '--converge-limit' of 10000 tries");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        vlSelfRef.__VactIterCount = 0U;
        do {
            if (VL_UNLIKELY(((0x00002710U < vlSelfRef.__VactIterCount)))) {
#ifdef VL_DEBUG
                Vtop___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
                VL_FATAL_MT("/home/ali/git/fyp/vivado/ip/svo_raytracer/hdl/svo_traversal.sv", 14, "", "DIDNOTCONVERGE: Active region did not converge after '--converge-limit' of 10000 tries");
            }
            vlSelfRef.__VactIterCount = ((IData)(1U) 
                                         + vlSelfRef.__VactIterCount);
            vlSelfRef.__VactPhaseResult = Vtop___024root___eval_phase__act(vlSelf);
        } while (vlSelfRef.__VactPhaseResult);
        vlSelfRef.__VnbaPhaseResult = Vtop___024root___eval_phase__nba(vlSelf);
    } while (vlSelfRef.__VnbaPhaseResult);
}

#ifdef VL_DEBUG
void Vtop___024root___eval_debug_assertions(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_debug_assertions\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (VL_UNLIKELY(((vlSelfRef.clk & 0xfeU)))) {
        Verilated::overWidthError("clk");
    }
    if (VL_UNLIKELY(((vlSelfRef.rst & 0xfeU)))) {
        Verilated::overWidthError("rst");
    }
    if (VL_UNLIKELY(((vlSelfRef.start & 0xfeU)))) {
        Verilated::overWidthError("start");
    }
    if (VL_UNLIKELY(((vlSelfRef.sky_color & 0xff000000U)))) {
        Verilated::overWidthError("sky_color");
    }
    if (VL_UNLIKELY(((vlSelfRef.axis_tready & 0xfeU)))) {
        Verilated::overWidthError("axis_tready");
    }
    if (VL_UNLIKELY(((vlSelfRef.shade_done & 0xfeU)))) {
        Verilated::overWidthError("shade_done");
    }
    if (VL_UNLIKELY(((vlSelfRef.shade_pixel_color & 0xff000000U)))) {
        Verilated::overWidthError("shade_pixel_color");
    }
}
#endif  // VL_DEBUG

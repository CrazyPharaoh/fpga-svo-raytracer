// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtop.h for the primary calling header

#ifndef VERILATED_VTOP___024ROOT_H_
#define VERILATED_VTOP___024ROOT_H_  // guard

#include "verilated.h"


class Vtop__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtop___024root final {
  public:

    // DESIGN SPECIFIC STATE
    // Anonymous structures to workaround compiler member-count bugs
    struct {
        VL_IN8(clk,0,0);
        VL_IN8(rst,0,0);
        VL_IN8(start,0,0);
        VL_OUT8(svo_rd_en,0,0);
        VL_OUT8(fb_wr_en,0,0);
        VL_OUT8(axis_tvalid,0,0);
        VL_OUT8(axis_tlast,0,0);
        VL_OUT8(axis_tuser,0,0);
        VL_IN8(axis_tready,0,0);
        VL_OUT8(shade_start,0,0);
        VL_OUT8(shade_is_miss,0,0);
        VL_OUT8(shade_hit_face,1,0);
        VL_OUT8(shade_hit_face_sign,0,0);
        VL_OUT8(shade_block_id,7,0);
        VL_IN8(shade_done,0,0);
        VL_OUT8(busy,0,0);
        VL_OUT8(frame_done,0,0);
        VL_OUT8(any_hit,0,0);
        VL_OUT8(dbg_state,3,0);
        VL_OUT8(dbg_rs_wait,4,0);
        VL_OUT8(dbg_py,7,0);
        VL_OUT8(dbg_tvalid,0,0);
        VL_OUT8(dbg_tready,0,0);
        CData/*5:0*/ svo_traversal__DOT____Vlvbound_habf6d040__0;
        CData/*5:0*/ svo_traversal__DOT____Vlvbound_h9d41b6af__0;
        CData/*5:0*/ svo_traversal__DOT____Vlvbound_h6831e3f2__0;
        CData/*5:0*/ svo_traversal__DOT____Vlvbound_h881263f8__0;
        CData/*5:0*/ svo_traversal__DOT____Vlvbound_hb13d1bf5__0;
        CData/*5:0*/ svo_traversal__DOT____Vlvbound_h00e6080f__0;
        CData/*5:0*/ svo_traversal__DOT____Vlvbound_hd4ed9f67__0;
        CData/*0:0*/ svo_traversal__DOT__clk;
        CData/*0:0*/ svo_traversal__DOT__rst;
        CData/*0:0*/ svo_traversal__DOT__start;
        CData/*0:0*/ svo_traversal__DOT__svo_rd_en;
        CData/*0:0*/ svo_traversal__DOT__fb_wr_en;
        CData/*0:0*/ svo_traversal__DOT__axis_tvalid;
        CData/*0:0*/ svo_traversal__DOT__axis_tlast;
        CData/*0:0*/ svo_traversal__DOT__axis_tuser;
        CData/*0:0*/ svo_traversal__DOT__axis_tready;
        CData/*0:0*/ svo_traversal__DOT__shade_start;
        CData/*0:0*/ svo_traversal__DOT__shade_is_miss;
        CData/*1:0*/ svo_traversal__DOT__shade_hit_face;
        CData/*0:0*/ svo_traversal__DOT__shade_hit_face_sign;
        CData/*7:0*/ svo_traversal__DOT__shade_block_id;
        CData/*0:0*/ svo_traversal__DOT__shade_done;
        CData/*0:0*/ svo_traversal__DOT__busy;
        CData/*0:0*/ svo_traversal__DOT__frame_done;
        CData/*0:0*/ svo_traversal__DOT__any_hit;
        CData/*3:0*/ svo_traversal__DOT__dbg_state;
        CData/*4:0*/ svo_traversal__DOT__dbg_rs_wait;
        CData/*7:0*/ svo_traversal__DOT__dbg_py;
        CData/*0:0*/ svo_traversal__DOT__dbg_tvalid;
        CData/*0:0*/ svo_traversal__DOT__dbg_tready;
        CData/*3:0*/ svo_traversal__DOT__state;
        CData/*3:0*/ svo_traversal__DOT__state_raw;
        CData/*7:0*/ svo_traversal__DOT__py;
        CData/*2:0*/ svo_traversal__DOT__step_x;
        CData/*2:0*/ svo_traversal__DOT__step_y;
        CData/*2:0*/ svo_traversal__DOT__step_z;
        CData/*5:0*/ svo_traversal__DOT__cx;
        CData/*5:0*/ svo_traversal__DOT__cy;
        CData/*5:0*/ svo_traversal__DOT__cz;
        CData/*5:0*/ svo_traversal__DOT__node_half;
        CData/*5:0*/ svo_traversal__DOT__node_origin_x;
    };
    struct {
        CData/*5:0*/ svo_traversal__DOT__node_origin_y;
        CData/*5:0*/ svo_traversal__DOT__node_origin_z;
        CData/*6:0*/ svo_traversal__DOT__bw_icx_c;
        CData/*6:0*/ svo_traversal__DOT__bw_icy_c;
        CData/*6:0*/ svo_traversal__DOT__bw_icz_c;
        CData/*1:0*/ svo_traversal__DOT__em_face;
        CData/*0:0*/ svo_traversal__DOT__em_fsign;
        CData/*2:0*/ svo_traversal__DOT__cidx;
        CData/*2:0*/ svo_traversal__DOT__bram_field;
        CData/*7:0*/ svo_traversal__DOT__block_id_hit;
        CData/*1:0*/ svo_traversal__DOT__hit_face;
        CData/*0:0*/ svo_traversal__DOT__hit_face_sign_r;
        CData/*3:0*/ svo_traversal__DOT__sp;
        CData/*4:0*/ svo_traversal__DOT__rs_wait;
        CData/*0:0*/ svo_traversal__DOT__post_pop;
        CData/*0:0*/ __VstlFirstIteration;
        CData/*0:0*/ __VstlPhaseResult;
        CData/*0:0*/ __VicoFirstIteration;
        CData/*0:0*/ __VicoPhaseResult;
        CData/*0:0*/ __Vtrigprevexpr___TOP__svo_traversal__DOT__clk__0;
        CData/*0:0*/ __VactDidInit;
        CData/*0:0*/ __VactPhaseResult;
        CData/*0:0*/ __VnbaPhaseResult;
        VL_OUT16(svo_rd_addr,14,0);
        VL_OUT16(dbg_px,8,0);
        SData/*15:0*/ svo_traversal__DOT____Vlvbound_h5d517a59__0;
        SData/*15:0*/ svo_traversal__DOT____Vlvbound_h3fbd9737__0;
        SData/*14:0*/ svo_traversal__DOT__svo_rd_addr;
        SData/*8:0*/ svo_traversal__DOT__dbg_px;
        SData/*8:0*/ svo_traversal__DOT__px;
        SData/*15:0*/ svo_traversal__DOT__node_idx;
        SData/*15:0*/ svo_traversal__DOT__bitmask;
        SData/*15:0*/ svo_traversal__DOT__r_bitmask;
        VL_IN(cam_pos_x,31,0);
        VL_IN(cam_pos_y,31,0);
        VL_IN(cam_pos_z,31,0);
        VL_IN(cam_right_x,31,0);
        VL_IN(cam_right_y,31,0);
        VL_IN(cam_right_z,31,0);
        VL_IN(cam_up_x,31,0);
        VL_IN(cam_up_y,31,0);
        VL_IN(cam_up_z,31,0);
        VL_IN(cam_fwd_x,31,0);
        VL_IN(cam_fwd_y,31,0);
        VL_IN(cam_fwd_z,31,0);
        VL_IN(cam_scale,31,0);
        VL_IN(sky_color,23,0);
        VL_IN(svo_rd_data,31,0);
        VL_OUT(fb_wr_addr,16,0);
        VL_OUT(fb_wr_data,23,0);
        VL_OUT(axis_tdata,31,0);
        VL_OUT(shade_t_hit,31,0);
        VL_OUT(shade_ray_dx,31,0);
        VL_OUT(shade_ray_dy,31,0);
        VL_OUT(shade_ray_dz,31,0);
        VL_OUT(shade_hit_px,31,0);
        VL_OUT(shade_hit_py,31,0);
        VL_OUT(shade_hit_pz,31,0);
        VL_IN(shade_pixel_color,23,0);
        IData/*31:0*/ svo_traversal__DOT____Vlvbound_h4b07ddb1__0;
        IData/*31:0*/ svo_traversal__DOT____Vlvbound_h1738f021__0;
        IData/*31:0*/ svo_traversal__DOT____Vlvbound_h10022533__0;
        IData/*31:0*/ svo_traversal__DOT____Vlvbound_h46c1a37b__0;
        IData/*31:0*/ svo_traversal__DOT____Vlvbound_h20b934f4__0;
    };
    struct {
        IData/*31:0*/ svo_traversal__DOT____VlemCall_22__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_21__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_20__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_19__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_18__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_17__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_16__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_15__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_14__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_13__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_12__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_11__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_10__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_9__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_8__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_7__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_6__qmul;
        IData/*31:0*/ svo_traversal__DOT__cam_pos_x;
        IData/*31:0*/ svo_traversal__DOT__cam_pos_y;
        IData/*31:0*/ svo_traversal__DOT__cam_pos_z;
        IData/*31:0*/ svo_traversal__DOT__cam_right_x;
        IData/*31:0*/ svo_traversal__DOT__cam_right_y;
        IData/*31:0*/ svo_traversal__DOT__cam_right_z;
        IData/*31:0*/ svo_traversal__DOT__cam_up_x;
        IData/*31:0*/ svo_traversal__DOT__cam_up_y;
        IData/*31:0*/ svo_traversal__DOT__cam_up_z;
        IData/*31:0*/ svo_traversal__DOT__cam_fwd_x;
        IData/*31:0*/ svo_traversal__DOT__cam_fwd_y;
        IData/*31:0*/ svo_traversal__DOT__cam_fwd_z;
        IData/*31:0*/ svo_traversal__DOT__cam_scale;
        IData/*23:0*/ svo_traversal__DOT__sky_color;
        IData/*31:0*/ svo_traversal__DOT__svo_rd_data;
        IData/*16:0*/ svo_traversal__DOT__fb_wr_addr;
        IData/*23:0*/ svo_traversal__DOT__fb_wr_data;
        IData/*31:0*/ svo_traversal__DOT__axis_tdata;
        IData/*31:0*/ svo_traversal__DOT__shade_t_hit;
        IData/*31:0*/ svo_traversal__DOT__shade_ray_dx;
        IData/*31:0*/ svo_traversal__DOT__shade_ray_dy;
        IData/*31:0*/ svo_traversal__DOT__shade_ray_dz;
        IData/*31:0*/ svo_traversal__DOT__shade_hit_px;
        IData/*31:0*/ svo_traversal__DOT__shade_hit_py;
        IData/*31:0*/ svo_traversal__DOT__shade_hit_pz;
        IData/*23:0*/ svo_traversal__DOT__shade_pixel_color;
        IData/*31:0*/ svo_traversal__DOT__ro_x;
        IData/*31:0*/ svo_traversal__DOT__ro_y;
        IData/*31:0*/ svo_traversal__DOT__ro_z;
        IData/*31:0*/ svo_traversal__DOT__rd_x;
        IData/*31:0*/ svo_traversal__DOT__rd_y;
        IData/*31:0*/ svo_traversal__DOT__rd_z;
        IData/*31:0*/ svo_traversal__DOT__inv_x;
        IData/*31:0*/ svo_traversal__DOT__inv_y;
        IData/*31:0*/ svo_traversal__DOT__inv_z;
        IData/*31:0*/ svo_traversal__DOT__t_min;
        IData/*31:0*/ svo_traversal__DOT__t_max;
        IData/*31:0*/ svo_traversal__DOT__t_next_x;
        IData/*31:0*/ svo_traversal__DOT__t_next_y;
        IData/*31:0*/ svo_traversal__DOT__t_next_z;
        IData/*31:0*/ svo_traversal__DOT__dt_x;
        IData/*31:0*/ svo_traversal__DOT__dt_y;
        IData/*31:0*/ svo_traversal__DOT__dt_z;
        IData/*31:0*/ svo_traversal__DOT__rs_tx0;
        IData/*31:0*/ svo_traversal__DOT__rs_tx1;
        IData/*31:0*/ svo_traversal__DOT__rs_ty0;
        IData/*31:0*/ svo_traversal__DOT__rs_ty1;
    };
    struct {
        IData/*31:0*/ svo_traversal__DOT__rs_tz0;
        IData/*31:0*/ svo_traversal__DOT__rs_tz1;
        IData/*31:0*/ svo_traversal__DOT__rs_world_q;
        IData/*31:0*/ svo_traversal__DOT__rs_tmp;
        IData/*31:0*/ svo_traversal__DOT__rs_rsu_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rsv_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rsdx_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rsdy_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rsdz_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rslen2_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rilinv_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rilsq_r;
        IData/*31:0*/ svo_traversal__DOT__rs_riltmp_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rilsub_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rilinv2_r;
        IData/*31:0*/ svo_traversal__DOT__rs_ndx_r;
        IData/*31:0*/ svo_traversal__DOT__rs_ndy_r;
        IData/*31:0*/ svo_traversal__DOT__rs_ndz_r;
        IData/*31:0*/ svo_traversal__DOT__rs_ax_r;
        IData/*31:0*/ svo_traversal__DOT__rs_ay_r;
        IData/*31:0*/ svo_traversal__DOT__rs_az_r;
        IData/*31:0*/ svo_traversal__DOT__rs_r0x_r;
        IData/*31:0*/ svo_traversal__DOT__rs_r0y_r;
        IData/*31:0*/ svo_traversal__DOT__rs_r0z_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rma_x_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rma_y_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rma_z_r;
        IData/*31:0*/ svo_traversal__DOT__rs_r1x_r;
        IData/*31:0*/ svo_traversal__DOT__rs_r1y_r;
        IData/*31:0*/ svo_traversal__DOT__rs_r1z_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rmb_x_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rmb_y_r;
        IData/*31:0*/ svo_traversal__DOT__rs_rmb_z_r;
        IData/*31:0*/ svo_traversal__DOT__t_hit;
        IData/*31:0*/ svo_traversal__DOT__hit_px_r;
        IData/*31:0*/ svo_traversal__DOT__hit_py_r;
        IData/*31:0*/ svo_traversal__DOT__hit_pz_r;
        IData/*23:0*/ svo_traversal__DOT__pixel_color;
        IData/*31:0*/ svo_traversal__DOT__bw_ex_c;
        IData/*31:0*/ svo_traversal__DOT__bw_ey_c;
        IData/*31:0*/ svo_traversal__DOT__bw_ez_c;
        IData/*31:0*/ svo_traversal__DOT__bw_abs_ix_c;
        IData/*31:0*/ svo_traversal__DOT__bw_abs_iy_c;
        IData/*31:0*/ svo_traversal__DOT__bw_abs_iz_c;
        IData/*31:0*/ svo_traversal__DOT__bw_nh_c;
        IData/*31:0*/ svo_traversal__DOT__dt_x_bw_c;
        IData/*31:0*/ svo_traversal__DOT__dt_y_bw_c;
        IData/*31:0*/ svo_traversal__DOT__dt_z_bw_c;
        IData/*31:0*/ svo_traversal__DOT__bw_ex_rel_c;
        IData/*31:0*/ svo_traversal__DOT__bw_ey_rel_c;
        IData/*31:0*/ svo_traversal__DOT__bw_ez_rel_c;
        IData/*31:0*/ svo_traversal__DOT__bw_dist_x_c;
        IData/*31:0*/ svo_traversal__DOT__bw_dist_y_c;
        IData/*31:0*/ svo_traversal__DOT__bw_dist_z_c;
        IData/*31:0*/ svo_traversal__DOT__t_next_x_bw_c;
        IData/*31:0*/ svo_traversal__DOT__t_next_y_bw_c;
        IData/*31:0*/ svo_traversal__DOT__t_next_z_bw_c;
        IData/*31:0*/ svo_traversal__DOT__dt_x_pop_c;
        IData/*31:0*/ svo_traversal__DOT__dt_y_pop_c;
        IData/*31:0*/ svo_traversal__DOT__dt_z_pop_c;
        IData/*31:0*/ __VactIterCount;
        VlUnpacked<SData/*15:0*/, 8> svo_traversal__DOT__r_child;
        VlUnpacked<CData/*7:0*/, 8> svo_traversal__DOT__r_block;
        VlUnpacked<SData/*15:0*/, 12> svo_traversal__DOT__stk_node_idx;
    };
    struct {
        VlUnpacked<SData/*15:0*/, 12> svo_traversal__DOT__stk_bitmask;
        VlUnpacked<IData/*31:0*/, 12> svo_traversal__DOT__stk_t_min;
        VlUnpacked<IData/*31:0*/, 12> svo_traversal__DOT__stk_t_max;
        VlUnpacked<IData/*31:0*/, 12> svo_traversal__DOT__stk_t_next_x;
        VlUnpacked<IData/*31:0*/, 12> svo_traversal__DOT__stk_t_next_y;
        VlUnpacked<IData/*31:0*/, 12> svo_traversal__DOT__stk_t_next_z;
        VlUnpacked<CData/*5:0*/, 12> svo_traversal__DOT__stk_cx;
        VlUnpacked<CData/*5:0*/, 12> svo_traversal__DOT__stk_cy;
        VlUnpacked<CData/*5:0*/, 12> svo_traversal__DOT__stk_cz;
        VlUnpacked<CData/*5:0*/, 12> svo_traversal__DOT__stk_node_half;
        VlUnpacked<CData/*5:0*/, 12> svo_traversal__DOT__stk_orig_x;
        VlUnpacked<CData/*5:0*/, 12> svo_traversal__DOT__stk_orig_y;
        VlUnpacked<CData/*5:0*/, 12> svo_traversal__DOT__stk_orig_z;
        VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
        VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
        VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
        VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;
    };

    // INTERNAL VARIABLES
    Vtop__Syms* vlSymsp;
    const char* vlNamep;

    // PARAMETERS
    static constexpr CData/*0:0*/ svo_traversal__DOT__SHADOW_MODE = 0U;
    static constexpr CData/*0:0*/ svo_traversal__DOT__SHADE_MODE = 0U;
    static constexpr IData/*31:0*/ svo_traversal__DOT__IMG_W = 0x00000140U;
    static constexpr IData/*31:0*/ svo_traversal__DOT__IMG_H = 0x000000f0U;
    static constexpr IData/*31:0*/ svo_traversal__DOT__STACK_DEPTH = 0x0000000cU;
    static constexpr IData/*31:0*/ svo_traversal__DOT__WORLD_SIZE = 0x00000040U;

    // CONSTRUCTORS
    Vtop___024root(Vtop__Syms* symsp, const char* namep);
    ~Vtop___024root();
    VL_UNCOPYABLE(Vtop___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard

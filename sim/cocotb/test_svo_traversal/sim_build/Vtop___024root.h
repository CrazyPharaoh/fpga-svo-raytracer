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
        VL_OUT8(shade_start,0,0);
        VL_OUT8(shade_is_miss,0,0);
        VL_OUT8(shade_hit_face,1,0);
        VL_OUT8(shade_hit_face_sign,0,0);
        VL_OUT8(shade_block_id,7,0);
        VL_IN8(shade_done,0,0);
        VL_OUT8(busy,0,0);
        VL_OUT8(frame_done,0,0);
        VL_OUT8(any_hit,0,0);
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
        CData/*0:0*/ svo_traversal__DOT__shade_start;
        CData/*0:0*/ svo_traversal__DOT__shade_is_miss;
        CData/*1:0*/ svo_traversal__DOT__shade_hit_face;
        CData/*0:0*/ svo_traversal__DOT__shade_hit_face_sign;
        CData/*7:0*/ svo_traversal__DOT__shade_block_id;
        CData/*0:0*/ svo_traversal__DOT__shade_done;
        CData/*0:0*/ svo_traversal__DOT__busy;
        CData/*0:0*/ svo_traversal__DOT__frame_done;
        CData/*0:0*/ svo_traversal__DOT__any_hit;
        CData/*3:0*/ svo_traversal__DOT__state;
        CData/*7:0*/ svo_traversal__DOT__py;
        CData/*2:0*/ svo_traversal__DOT__step_x;
        CData/*2:0*/ svo_traversal__DOT__step_y;
        CData/*2:0*/ svo_traversal__DOT__step_z;
        CData/*5:0*/ svo_traversal__DOT__cx;
        CData/*5:0*/ svo_traversal__DOT__cy;
        CData/*5:0*/ svo_traversal__DOT__cz;
        CData/*5:0*/ svo_traversal__DOT__node_half;
        CData/*5:0*/ svo_traversal__DOT__node_origin_x;
        CData/*5:0*/ svo_traversal__DOT__node_origin_y;
        CData/*5:0*/ svo_traversal__DOT__node_origin_z;
        CData/*2:0*/ svo_traversal__DOT__cidx;
        CData/*2:0*/ svo_traversal__DOT__bram_field;
        CData/*7:0*/ svo_traversal__DOT__block_id_hit;
        CData/*1:0*/ svo_traversal__DOT__hit_face;
        CData/*0:0*/ svo_traversal__DOT__hit_face_sign_r;
        CData/*3:0*/ svo_traversal__DOT__sp;
        CData/*5:0*/ svo_traversal__DOT__unnamedblk3__DOT__icx;
        CData/*5:0*/ svo_traversal__DOT__unnamedblk3__DOT__icy;
        CData/*5:0*/ svo_traversal__DOT__unnamedblk3__DOT__icz;
        CData/*1:0*/ svo_traversal__DOT__unnamedblk4__DOT__face;
        CData/*0:0*/ svo_traversal__DOT__unnamedblk4__DOT__fsign;
        CData/*0:0*/ __VstlFirstIteration;
        CData/*0:0*/ __VstlPhaseResult;
        CData/*0:0*/ __VicoFirstIteration;
        CData/*0:0*/ __VicoPhaseResult;
        CData/*0:0*/ __Vtrigprevexpr___TOP__svo_traversal__DOT__clk__0;
        CData/*0:0*/ __VactDidInit;
    };
    struct {
        CData/*0:0*/ __VactPhaseResult;
        CData/*0:0*/ __VnbaPhaseResult;
        VL_OUT16(svo_rd_addr,14,0);
        SData/*15:0*/ svo_traversal__DOT____Vlvbound_h3fbd9737__0;
        SData/*14:0*/ svo_traversal__DOT__svo_rd_addr;
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
        IData/*31:0*/ svo_traversal__DOT____VlemCall_19__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_18__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_17__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_16__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_15__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_14__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_13__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_12__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_11__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_10__qrecip;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_9__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_8__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_7__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_6__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_5__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_4__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_3__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_2__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_1__qmul;
        IData/*31:0*/ svo_traversal__DOT____VlemCall_0__qmul;
        IData/*31:0*/ svo_traversal__DOT__cam_pos_x;
        IData/*31:0*/ svo_traversal__DOT__cam_pos_y;
        IData/*31:0*/ svo_traversal__DOT__cam_pos_z;
        IData/*31:0*/ svo_traversal__DOT__cam_right_x;
        IData/*31:0*/ svo_traversal__DOT__cam_right_y;
    };
    struct {
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
        IData/*31:0*/ svo_traversal__DOT__t_hit;
        IData/*31:0*/ svo_traversal__DOT__hit_px_r;
        IData/*31:0*/ svo_traversal__DOT__hit_py_r;
        IData/*31:0*/ svo_traversal__DOT__hit_pz_r;
        IData/*23:0*/ svo_traversal__DOT__pixel_color;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk1__DOT__u;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk1__DOT__v;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk1__DOT__dx;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk1__DOT__dy;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk1__DOT__dz;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk1__DOT__len2;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk1__DOT__inv_len;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk2__DOT__tx0;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk2__DOT__tx1;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk2__DOT__ty0;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk2__DOT__ty1;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk2__DOT__tz0;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk2__DOT__tz1;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk2__DOT__world_q;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk2__DOT__tmp;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk3__DOT__ex;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk3__DOT__ey;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk3__DOT__ez;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk3__DOT__abs_ix;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk3__DOT__abs_iy;
        IData/*31:0*/ svo_traversal__DOT__unnamedblk3__DOT__abs_iz;
        IData/*31:0*/ __VactIterCount;
    };
    struct {
        VlUnpacked<SData/*15:0*/, 8> svo_traversal__DOT__r_child;
        VlUnpacked<CData/*7:0*/, 8> svo_traversal__DOT__r_block;
        VlUnpacked<SData/*15:0*/, 12> svo_traversal__DOT__stk_node_idx;
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

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
    VL_IN8(clk_pixel,0,0);
    VL_IN8(rst,0,0);
    VL_OUT8(hsync,0,0);
    VL_OUT8(vsync,0,0);
    VL_OUT8(data_en,0,0);
    CData/*0:0*/ hdmi_timing__DOT__clk_pixel;
    CData/*0:0*/ hdmi_timing__DOT__rst;
    CData/*0:0*/ hdmi_timing__DOT__hsync;
    CData/*0:0*/ hdmi_timing__DOT__vsync;
    CData/*0:0*/ hdmi_timing__DOT__data_en;
    CData/*0:0*/ __VstlFirstIteration;
    CData/*0:0*/ __VstlPhaseResult;
    CData/*0:0*/ __VicoFirstIteration;
    CData/*0:0*/ __VicoPhaseResult;
    CData/*0:0*/ __Vtrigprevexpr___TOP__hdmi_timing__DOT__clk_pixel__0;
    CData/*0:0*/ __VactPhaseResult;
    CData/*0:0*/ __VnbaPhaseResult;
    VL_OUT16(hx,9,0);
    VL_OUT16(hy,9,0);
    SData/*9:0*/ hdmi_timing__DOT__hx;
    SData/*9:0*/ hdmi_timing__DOT__hy;
    IData/*31:0*/ __VactIterCount;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vtop__Syms* vlSymsp;
    const char* vlNamep;

    // PARAMETERS
    static constexpr IData/*31:0*/ hdmi_timing__DOT__H_ACTIVE = 0x00000280U;
    static constexpr IData/*31:0*/ hdmi_timing__DOT__H_FP = 0x00000010U;
    static constexpr IData/*31:0*/ hdmi_timing__DOT__H_SYNC = 0x00000060U;
    static constexpr IData/*31:0*/ hdmi_timing__DOT__H_BP = 0x00000030U;
    static constexpr IData/*31:0*/ hdmi_timing__DOT__V_ACTIVE = 0x000001e0U;
    static constexpr IData/*31:0*/ hdmi_timing__DOT__V_FP = 0x0000000aU;
    static constexpr IData/*31:0*/ hdmi_timing__DOT__V_SYNC = 2U;
    static constexpr IData/*31:0*/ hdmi_timing__DOT__V_BP = 0x00000021U;
    static constexpr IData/*31:0*/ hdmi_timing__DOT__H_TOTAL = 0x00000320U;
    static constexpr IData/*31:0*/ hdmi_timing__DOT__V_TOTAL = 0x0000020dU;

    // CONSTRUCTORS
    Vtop___024root(Vtop__Syms* symsp, const char* namep);
    ~Vtop___024root();
    VL_UNCOPYABLE(Vtop___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard

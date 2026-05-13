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
    // Body
    vlSelfRef.hdmi_timing__DOT__clk_pixel = vlSelfRef.clk_pixel;
    vlSelfRef.hdmi_timing__DOT__rst = vlSelfRef.rst;
    vlSelfRef.hx = vlSelfRef.hdmi_timing__DOT__hx;
    vlSelfRef.hy = vlSelfRef.hdmi_timing__DOT__hy;
    vlSelfRef.hdmi_timing__DOT__hsync = (1U & (~ ((0x0290U 
                                                   <= (IData)(vlSelfRef.hdmi_timing__DOT__hx)) 
                                                  & (0x02f0U 
                                                     > (IData)(vlSelfRef.hdmi_timing__DOT__hx)))));
    vlSelfRef.hdmi_timing__DOT__vsync = (1U & (~ ((0x01eaU 
                                                   <= (IData)(vlSelfRef.hdmi_timing__DOT__hy)) 
                                                  & (0x01ecU 
                                                     > (IData)(vlSelfRef.hdmi_timing__DOT__hy)))));
    vlSelfRef.hdmi_timing__DOT__data_en = ((0x0280U 
                                            > (IData)(vlSelfRef.hdmi_timing__DOT__hx)) 
                                           & (0x01e0U 
                                              > (IData)(vlSelfRef.hdmi_timing__DOT__hy)));
    vlSelfRef.hsync = vlSelfRef.hdmi_timing__DOT__hsync;
    vlSelfRef.vsync = vlSelfRef.hdmi_timing__DOT__vsync;
    vlSelfRef.data_en = vlSelfRef.hdmi_timing__DOT__data_en;
}

void Vtop___024root___eval_ico(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_ico\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VicoTriggered[0U])) {
        vlSelfRef.hdmi_timing__DOT__clk_pixel = vlSelfRef.clk_pixel;
        vlSelfRef.hdmi_timing__DOT__rst = vlSelfRef.rst;
        vlSelfRef.hx = vlSelfRef.hdmi_timing__DOT__hx;
        vlSelfRef.hy = vlSelfRef.hdmi_timing__DOT__hy;
        vlSelfRef.hdmi_timing__DOT__hsync = (1U & (~ 
                                                   ((0x0290U 
                                                     <= (IData)(vlSelfRef.hdmi_timing__DOT__hx)) 
                                                    & (0x02f0U 
                                                       > (IData)(vlSelfRef.hdmi_timing__DOT__hx)))));
        vlSelfRef.hdmi_timing__DOT__vsync = (1U & (~ 
                                                   ((0x01eaU 
                                                     <= (IData)(vlSelfRef.hdmi_timing__DOT__hy)) 
                                                    & (0x01ecU 
                                                       > (IData)(vlSelfRef.hdmi_timing__DOT__hy)))));
        vlSelfRef.hdmi_timing__DOT__data_en = ((0x0280U 
                                                > (IData)(vlSelfRef.hdmi_timing__DOT__hx)) 
                                               & (0x01e0U 
                                                  > (IData)(vlSelfRef.hdmi_timing__DOT__hy)));
        vlSelfRef.hsync = vlSelfRef.hdmi_timing__DOT__hsync;
        vlSelfRef.vsync = vlSelfRef.hdmi_timing__DOT__vsync;
        vlSelfRef.data_en = vlSelfRef.hdmi_timing__DOT__data_en;
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
                                                    ((IData)(vlSelfRef.hdmi_timing__DOT__clk_pixel) 
                                                     & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__hdmi_timing__DOT__clk_pixel__0)))));
    vlSelfRef.__Vtrigprevexpr___TOP__hdmi_timing__DOT__clk_pixel__0 
        = vlSelfRef.hdmi_timing__DOT__clk_pixel;
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
    SData/*9:0*/ __Vdly__hdmi_timing__DOT__hx;
    __Vdly__hdmi_timing__DOT__hx = 0;
    SData/*9:0*/ __Vdly__hdmi_timing__DOT__hy;
    __Vdly__hdmi_timing__DOT__hy = 0;
    // Body
    __Vdly__hdmi_timing__DOT__hx = vlSelfRef.hdmi_timing__DOT__hx;
    __Vdly__hdmi_timing__DOT__hy = vlSelfRef.hdmi_timing__DOT__hy;
    if (vlSelfRef.hdmi_timing__DOT__rst) {
        __Vdly__hdmi_timing__DOT__hx = 0U;
        __Vdly__hdmi_timing__DOT__hy = 0U;
    } else if ((0x031fU == (IData)(vlSelfRef.hdmi_timing__DOT__hx))) {
        __Vdly__hdmi_timing__DOT__hy = ((0x020cU == (IData)(vlSelfRef.hdmi_timing__DOT__hy))
                                         ? 0U : (0x000003ffU 
                                                 & ((IData)(1U) 
                                                    + (IData)(vlSelfRef.hdmi_timing__DOT__hy))));
        __Vdly__hdmi_timing__DOT__hx = 0U;
    } else {
        __Vdly__hdmi_timing__DOT__hx = (0x000003ffU 
                                        & ((IData)(1U) 
                                           + (IData)(vlSelfRef.hdmi_timing__DOT__hx)));
    }
    vlSelfRef.hdmi_timing__DOT__hx = __Vdly__hdmi_timing__DOT__hx;
    vlSelfRef.hdmi_timing__DOT__hy = __Vdly__hdmi_timing__DOT__hy;
    vlSelfRef.hx = vlSelfRef.hdmi_timing__DOT__hx;
    vlSelfRef.hdmi_timing__DOT__hsync = (1U & (~ ((0x0290U 
                                                   <= (IData)(vlSelfRef.hdmi_timing__DOT__hx)) 
                                                  & (0x02f0U 
                                                     > (IData)(vlSelfRef.hdmi_timing__DOT__hx)))));
    vlSelfRef.hy = vlSelfRef.hdmi_timing__DOT__hy;
    vlSelfRef.hdmi_timing__DOT__vsync = (1U & (~ ((0x01eaU 
                                                   <= (IData)(vlSelfRef.hdmi_timing__DOT__hy)) 
                                                  & (0x01ecU 
                                                     > (IData)(vlSelfRef.hdmi_timing__DOT__hy)))));
    vlSelfRef.hdmi_timing__DOT__data_en = ((0x0280U 
                                            > (IData)(vlSelfRef.hdmi_timing__DOT__hx)) 
                                           & (0x01e0U 
                                              > (IData)(vlSelfRef.hdmi_timing__DOT__hy)));
    vlSelfRef.hsync = vlSelfRef.hdmi_timing__DOT__hsync;
    vlSelfRef.vsync = vlSelfRef.hdmi_timing__DOT__vsync;
    vlSelfRef.data_en = vlSelfRef.hdmi_timing__DOT__data_en;
}

void Vtop___024root___eval_nba(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_nba\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    SData/*9:0*/ __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hx;
    __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hx = 0;
    SData/*9:0*/ __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hy;
    __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hy = 0;
    // Body
    if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
        __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hx 
            = vlSelfRef.hdmi_timing__DOT__hx;
        __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hy 
            = vlSelfRef.hdmi_timing__DOT__hy;
        if (vlSelfRef.hdmi_timing__DOT__rst) {
            __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hx = 0U;
            __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hy = 0U;
        } else if ((0x031fU == (IData)(vlSelfRef.hdmi_timing__DOT__hx))) {
            __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hy 
                = ((0x020cU == (IData)(vlSelfRef.hdmi_timing__DOT__hy))
                    ? 0U : (0x000003ffU & ((IData)(1U) 
                                           + (IData)(vlSelfRef.hdmi_timing__DOT__hy))));
            __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hx = 0U;
        } else {
            __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hx 
                = (0x000003ffU & ((IData)(1U) + (IData)(vlSelfRef.hdmi_timing__DOT__hx)));
        }
        vlSelfRef.hdmi_timing__DOT__hx = __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hx;
        vlSelfRef.hdmi_timing__DOT__hy = __Vinline__nba_sequent__TOP__0___Vdly__hdmi_timing__DOT__hy;
        vlSelfRef.hx = vlSelfRef.hdmi_timing__DOT__hx;
        vlSelfRef.hdmi_timing__DOT__hsync = (1U & (~ 
                                                   ((0x0290U 
                                                     <= (IData)(vlSelfRef.hdmi_timing__DOT__hx)) 
                                                    & (0x02f0U 
                                                       > (IData)(vlSelfRef.hdmi_timing__DOT__hx)))));
        vlSelfRef.hy = vlSelfRef.hdmi_timing__DOT__hy;
        vlSelfRef.hdmi_timing__DOT__vsync = (1U & (~ 
                                                   ((0x01eaU 
                                                     <= (IData)(vlSelfRef.hdmi_timing__DOT__hy)) 
                                                    & (0x01ecU 
                                                       > (IData)(vlSelfRef.hdmi_timing__DOT__hy)))));
        vlSelfRef.hdmi_timing__DOT__data_en = ((0x0280U 
                                                > (IData)(vlSelfRef.hdmi_timing__DOT__hx)) 
                                               & (0x01e0U 
                                                  > (IData)(vlSelfRef.hdmi_timing__DOT__hy)));
        vlSelfRef.hsync = vlSelfRef.hdmi_timing__DOT__hsync;
        vlSelfRef.vsync = vlSelfRef.hdmi_timing__DOT__vsync;
        vlSelfRef.data_en = vlSelfRef.hdmi_timing__DOT__data_en;
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
            VL_FATAL_MT("/home/ali/git/fyp/vivado/ip/svo_raytracer/hdl/hdmi_timing.sv", 4, "", "DIDNOTCONVERGE: Input combinational region did not converge after '--converge-limit' of 10000 tries");
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
            VL_FATAL_MT("/home/ali/git/fyp/vivado/ip/svo_raytracer/hdl/hdmi_timing.sv", 4, "", "DIDNOTCONVERGE: NBA region did not converge after '--converge-limit' of 10000 tries");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        vlSelfRef.__VactIterCount = 0U;
        do {
            if (VL_UNLIKELY(((0x00002710U < vlSelfRef.__VactIterCount)))) {
#ifdef VL_DEBUG
                Vtop___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
                VL_FATAL_MT("/home/ali/git/fyp/vivado/ip/svo_raytracer/hdl/hdmi_timing.sv", 4, "", "DIDNOTCONVERGE: Active region did not converge after '--converge-limit' of 10000 tries");
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
    if (VL_UNLIKELY(((vlSelfRef.clk_pixel & 0xfeU)))) {
        Verilated::overWidthError("clk_pixel");
    }
    if (VL_UNLIKELY(((vlSelfRef.rst & 0xfeU)))) {
        Verilated::overWidthError("rst");
    }
}
#endif  // VL_DEBUG

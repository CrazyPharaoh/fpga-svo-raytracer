// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtop.h for the primary calling header

#include "Vtop__pch.h"

// Parameter definitions for Vtop___024root
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__H_ACTIVE;
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__H_FP;
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__H_SYNC;
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__H_BP;
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__V_ACTIVE;
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__V_FP;
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__V_SYNC;
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__V_BP;
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__H_TOTAL;
constexpr IData/*31:0*/ Vtop___024root::hdmi_timing__DOT__V_TOTAL;


void Vtop___024root___ctor_var_reset(Vtop___024root* vlSelf);

Vtop___024root::Vtop___024root(Vtop__Syms* symsp, const char* namep)
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vtop___024root___ctor_var_reset(this);
}

void Vtop___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vtop___024root::~Vtop___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}

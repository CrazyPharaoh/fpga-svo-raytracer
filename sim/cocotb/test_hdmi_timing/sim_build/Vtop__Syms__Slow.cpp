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
    Verilated::stackCheck(258);
    // Setup sub module instances
    // Configure time unit / time precision
    _vm_contextp__->timeunit(-9);
    _vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
    // Setup each module's pointer back to symbol table (for public functions)
    TOP.__Vconfigure(true);
    // Setup scopes
    __Vscopep_TOP = new VerilatedScope{this, "TOP", "TOP", "<null>", 0, VerilatedScope::SCOPE_OTHER};
    __Vscopep_hdmi_timing = new VerilatedScope{this, "hdmi_timing", "hdmi_timing", "hdmi_timing", -9, VerilatedScope::SCOPE_MODULE};
    // Set up scope hierarchy
    __Vhier.add(0, __Vscopep_hdmi_timing);
    // Setup export functions - final: 0
    // Setup export functions - final: 1
    // Setup public variables
    __Vscopep_TOP->varInsert("clk_pixel", &(TOP.clk_pixel), false, VLVT_UINT8, VLVD_IN|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("data_en", &(TOP.data_en), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
    __Vscopep_TOP->varInsert("hsync", &(TOP.hsync), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
    __Vscopep_TOP->varInsert("hx", &(TOP.hx), false, VLVT_UINT16, VLVD_OUT|VLVF_PUB_RW, 0, 1 ,9,0);
    __Vscopep_TOP->varInsert("hy", &(TOP.hy), false, VLVT_UINT16, VLVD_OUT|VLVF_PUB_RW, 0, 1 ,9,0);
    __Vscopep_TOP->varInsert("rst", &(TOP.rst), false, VLVT_UINT8, VLVD_IN|VLVF_PUB_RW, 0, 0);
    __Vscopep_TOP->varInsert("vsync", &(TOP.vsync), false, VLVT_UINT8, VLVD_OUT|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
    __Vscopep_hdmi_timing->varInsert("H_ACTIVE", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__H_ACTIVE))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("H_BP", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__H_BP))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("H_FP", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__H_FP))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("H_SYNC", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__H_SYNC))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("H_TOTAL", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__H_TOTAL))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("V_ACTIVE", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__V_ACTIVE))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("V_BP", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__V_BP))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("V_FP", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__V_FP))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("V_SYNC", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__V_SYNC))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("V_TOTAL", const_cast<void*>(static_cast<const void*>(&(TOP.hdmi_timing__DOT__V_TOTAL))), true, VLVT_UINT32, VLVD_NODIR|VLVF_PUB_RW|VLVF_DPI_CLAY|VLVF_SIGNED, 0, 1 ,31,0);
    __Vscopep_hdmi_timing->varInsert("clk_pixel", &(TOP.hdmi_timing__DOT__clk_pixel), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_hdmi_timing->varInsert("data_en", &(TOP.hdmi_timing__DOT__data_en), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
    __Vscopep_hdmi_timing->varInsert("hsync", &(TOP.hdmi_timing__DOT__hsync), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
    __Vscopep_hdmi_timing->varInsert("hx", &(TOP.hdmi_timing__DOT__hx), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,9,0);
    __Vscopep_hdmi_timing->varInsert("hy", &(TOP.hdmi_timing__DOT__hy), false, VLVT_UINT16, VLVD_NODIR|VLVF_PUB_RW, 0, 1 ,9,0);
    __Vscopep_hdmi_timing->varInsert("rst", &(TOP.hdmi_timing__DOT__rst), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW, 0, 0);
    __Vscopep_hdmi_timing->varInsert("vsync", &(TOP.hdmi_timing__DOT__vsync), false, VLVT_UINT8, VLVD_NODIR|VLVF_PUB_RW|VLVF_CONTINUOUSLY, 0, 0);
}

Vtop__Syms::~Vtop__Syms() {
    // Tear down scope hierarchy
    __Vhier.remove(0, __Vscopep_hdmi_timing);
    // Clear keys from hierarchy map after values have been removed
    __Vhier.clear();
    // Tear down scopes
    VL_DO_CLEAR(delete __Vscopep_TOP, __Vscopep_TOP = nullptr);
    VL_DO_CLEAR(delete __Vscopep_hdmi_timing, __Vscopep_hdmi_timing = nullptr);
    // Tear down sub module instances
}

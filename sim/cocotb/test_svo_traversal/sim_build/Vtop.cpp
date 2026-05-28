// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtop__pch.h"

//============================================================
// Constructors

Vtop::Vtop(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtop__Syms(contextp(), _vcname__, this)}
    , clk{vlSymsp->TOP.clk}
    , rst{vlSymsp->TOP.rst}
    , start{vlSymsp->TOP.start}
    , svo_rd_en{vlSymsp->TOP.svo_rd_en}
    , fb_wr_en{vlSymsp->TOP.fb_wr_en}
    , axis_tvalid{vlSymsp->TOP.axis_tvalid}
    , axis_tlast{vlSymsp->TOP.axis_tlast}
    , axis_tuser{vlSymsp->TOP.axis_tuser}
    , axis_tready{vlSymsp->TOP.axis_tready}
    , shade_start{vlSymsp->TOP.shade_start}
    , shade_is_miss{vlSymsp->TOP.shade_is_miss}
    , shade_hit_face{vlSymsp->TOP.shade_hit_face}
    , shade_hit_face_sign{vlSymsp->TOP.shade_hit_face_sign}
    , shade_block_id{vlSymsp->TOP.shade_block_id}
    , shade_done{vlSymsp->TOP.shade_done}
    , busy{vlSymsp->TOP.busy}
    , frame_done{vlSymsp->TOP.frame_done}
    , any_hit{vlSymsp->TOP.any_hit}
    , dbg_state{vlSymsp->TOP.dbg_state}
    , dbg_rs_wait{vlSymsp->TOP.dbg_rs_wait}
    , dbg_py{vlSymsp->TOP.dbg_py}
    , dbg_tvalid{vlSymsp->TOP.dbg_tvalid}
    , dbg_tready{vlSymsp->TOP.dbg_tready}
    , svo_rd_addr{vlSymsp->TOP.svo_rd_addr}
    , dbg_px{vlSymsp->TOP.dbg_px}
    , cam_pos_x{vlSymsp->TOP.cam_pos_x}
    , cam_pos_y{vlSymsp->TOP.cam_pos_y}
    , cam_pos_z{vlSymsp->TOP.cam_pos_z}
    , cam_right_x{vlSymsp->TOP.cam_right_x}
    , cam_right_y{vlSymsp->TOP.cam_right_y}
    , cam_right_z{vlSymsp->TOP.cam_right_z}
    , cam_up_x{vlSymsp->TOP.cam_up_x}
    , cam_up_y{vlSymsp->TOP.cam_up_y}
    , cam_up_z{vlSymsp->TOP.cam_up_z}
    , cam_fwd_x{vlSymsp->TOP.cam_fwd_x}
    , cam_fwd_y{vlSymsp->TOP.cam_fwd_y}
    , cam_fwd_z{vlSymsp->TOP.cam_fwd_z}
    , cam_scale{vlSymsp->TOP.cam_scale}
    , sky_color{vlSymsp->TOP.sky_color}
    , svo_rd_data{vlSymsp->TOP.svo_rd_data}
    , fb_wr_addr{vlSymsp->TOP.fb_wr_addr}
    , fb_wr_data{vlSymsp->TOP.fb_wr_data}
    , axis_tdata{vlSymsp->TOP.axis_tdata}
    , shade_t_hit{vlSymsp->TOP.shade_t_hit}
    , shade_ray_dx{vlSymsp->TOP.shade_ray_dx}
    , shade_ray_dy{vlSymsp->TOP.shade_ray_dy}
    , shade_ray_dz{vlSymsp->TOP.shade_ray_dz}
    , shade_hit_px{vlSymsp->TOP.shade_hit_px}
    , shade_hit_py{vlSymsp->TOP.shade_hit_py}
    , shade_hit_pz{vlSymsp->TOP.shade_hit_pz}
    , shade_pixel_color{vlSymsp->TOP.shade_pixel_color}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtop::Vtop(const char* _vcname__)
    : Vtop(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtop::~Vtop() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtop___024root___eval_debug_assertions(Vtop___024root* vlSelf);
#endif  // VL_DEBUG
void Vtop___024root___eval_static(Vtop___024root* vlSelf);
void Vtop___024root___eval_initial(Vtop___024root* vlSelf);
void Vtop___024root___eval_settle(Vtop___024root* vlSelf);
void Vtop___024root___eval(Vtop___024root* vlSelf);

void Vtop::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtop::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vtop___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vtop___024root___eval_static(&(vlSymsp->TOP));
        Vtop___024root___eval_initial(&(vlSymsp->TOP));
        Vtop___024root___eval_settle(&(vlSymsp->TOP));
        vlSymsp->__Vm_didInit = true;
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vtop___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vtop::eventsPending() { return false; }

uint64_t Vtop::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vtop::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vtop___024root___eval_final(Vtop___024root* vlSelf);

VL_ATTR_COLD void Vtop::final() {
    contextp()->executingFinal(true);
    Vtop___024root___eval_final(&(vlSymsp->TOP));
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtop::hierName() const { return vlSymsp->name(); }
const char* Vtop::modelName() const { return "Vtop"; }
unsigned Vtop::threads() const { return 1; }
void Vtop::prepareClone() const { contextp()->prepareClone(); }
void Vtop::atClone() const {
    contextp()->threadPoolpOnClone();
}

# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "IN_H" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IN_W" -parent ${Page_0}


}

proc update_PARAM_VALUE.IN_H { PARAM_VALUE.IN_H } {
	# Procedure called to update IN_H when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IN_H { PARAM_VALUE.IN_H } {
	# Procedure called to validate IN_H
	return true
}

proc update_PARAM_VALUE.IN_W { PARAM_VALUE.IN_W } {
	# Procedure called to update IN_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IN_W { PARAM_VALUE.IN_W } {
	# Procedure called to validate IN_W
	return true
}


proc update_MODELPARAM_VALUE.IN_W { MODELPARAM_VALUE.IN_W PARAM_VALUE.IN_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IN_W}] ${MODELPARAM_VALUE.IN_W}
}

proc update_MODELPARAM_VALUE.IN_H { MODELPARAM_VALUE.IN_H PARAM_VALUE.IN_H } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IN_H}] ${MODELPARAM_VALUE.IN_H}
}


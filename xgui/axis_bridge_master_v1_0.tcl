# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  #Adding Page
  set User_Parameters [ipgui::add_page $IPINST -name "User Parameters"]
  ipgui::add_param $IPINST -name "Component_Name" -parent ${User_Parameters}
  #Adding Group
  set RX_Address_Mask [ipgui::add_group $IPINST -name "RX Address Mask" -parent ${User_Parameters}]
  ipgui::add_param $IPINST -name "RX_ADDR_MASK" -parent ${RX_Address_Mask}

  #Adding Group
  set K-Characters [ipgui::add_group $IPINST -name "K-Characters" -parent ${User_Parameters}]
  set_property tooltip {K-Characters} ${K-Characters}
  ipgui::add_param $IPINST -name "K_SOF" -parent ${K-Characters} -widget comboBox
  ipgui::add_param $IPINST -name "K_EOF" -parent ${K-Characters} -widget comboBox
  ipgui::add_param $IPINST -name "K_ERR" -parent ${K-Characters} -widget comboBox
  ipgui::add_param $IPINST -name "K_INT" -parent ${K-Characters} -widget comboBox


  #Adding Page
  set AXI_(Locked) [ipgui::add_page $IPINST -name "AXI (Locked)"]
  ipgui::add_param $IPINST -name "C_S00_AXI_BASEADDR" -parent ${AXI_(Locked)}
  ipgui::add_param $IPINST -name "C_S00_AXI_HIGHADDR" -parent ${AXI_(Locked)}

  ipgui::add_param $IPINST -name "POSTED_WRITES" -widget comboBox

}

proc update_PARAM_VALUE.POSTED_WRITES { PARAM_VALUE.POSTED_WRITES } {
	# Procedure called to update POSTED_WRITES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.POSTED_WRITES { PARAM_VALUE.POSTED_WRITES } {
	# Procedure called to validate POSTED_WRITES
	return true
}

proc update_PARAM_VALUE.TIMEOUT_CYCLES { PARAM_VALUE.TIMEOUT_CYCLES } {
	# Procedure called to update TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TIMEOUT_CYCLES { PARAM_VALUE.TIMEOUT_CYCLES } {
	# Procedure called to validate TIMEOUT_CYCLES
	return true
}

proc update_PARAM_VALUE.RX_ADDR_MASK { PARAM_VALUE.RX_ADDR_MASK } {
	# Procedure called to update RX_ADDR_MASK when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RX_ADDR_MASK { PARAM_VALUE.RX_ADDR_MASK } {
	# Procedure called to validate RX_ADDR_MASK
	return true
}

proc update_PARAM_VALUE.K_SOF { PARAM_VALUE.K_SOF } {
	# Procedure called to update K_SOF when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.K_SOF { PARAM_VALUE.K_SOF } {
	# Procedure called to validate K_SOF
	return true
}

proc update_PARAM_VALUE.K_EOF { PARAM_VALUE.K_EOF } {
	# Procedure called to update K_EOF when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.K_EOF { PARAM_VALUE.K_EOF } {
	# Procedure called to validate K_EOF
	return true
}

proc update_PARAM_VALUE.K_ERR { PARAM_VALUE.K_ERR } {
	# Procedure called to update K_ERR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.K_ERR { PARAM_VALUE.K_ERR } {
	# Procedure called to validate K_ERR
	return true
}

proc update_PARAM_VALUE.K_INT { PARAM_VALUE.K_INT } {
	# Procedure called to update K_INT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.K_INT { PARAM_VALUE.K_INT } {
	# Procedure called to validate K_INT
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_BASEADDR { PARAM_VALUE.C_S00_AXI_BASEADDR } {
	# Procedure called to update C_S00_AXI_BASEADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_BASEADDR { PARAM_VALUE.C_S00_AXI_BASEADDR } {
	# Procedure called to validate C_S00_AXI_BASEADDR
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_HIGHADDR { PARAM_VALUE.C_S00_AXI_HIGHADDR } {
	# Procedure called to update C_S00_AXI_HIGHADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_HIGHADDR { PARAM_VALUE.C_S00_AXI_HIGHADDR } {
	# Procedure called to validate C_S00_AXI_HIGHADDR
	return true
}


proc update_MODELPARAM_VALUE.RX_ADDR_MASK { MODELPARAM_VALUE.RX_ADDR_MASK PARAM_VALUE.RX_ADDR_MASK } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RX_ADDR_MASK}] ${MODELPARAM_VALUE.RX_ADDR_MASK}
}

proc update_MODELPARAM_VALUE.K_SOF { MODELPARAM_VALUE.K_SOF PARAM_VALUE.K_SOF } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.K_SOF}] ${MODELPARAM_VALUE.K_SOF}
}

proc update_MODELPARAM_VALUE.K_EOF { MODELPARAM_VALUE.K_EOF PARAM_VALUE.K_EOF } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.K_EOF}] ${MODELPARAM_VALUE.K_EOF}
}

proc update_MODELPARAM_VALUE.K_ERR { MODELPARAM_VALUE.K_ERR PARAM_VALUE.K_ERR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.K_ERR}] ${MODELPARAM_VALUE.K_ERR}
}

proc update_MODELPARAM_VALUE.K_INT { MODELPARAM_VALUE.K_INT PARAM_VALUE.K_INT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.K_INT}] ${MODELPARAM_VALUE.K_INT}
}

proc update_MODELPARAM_VALUE.POSTED_WRITES { MODELPARAM_VALUE.POSTED_WRITES PARAM_VALUE.POSTED_WRITES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.POSTED_WRITES}] ${MODELPARAM_VALUE.POSTED_WRITES}
}

proc update_MODELPARAM_VALUE.TIMEOUT_CYCLES { MODELPARAM_VALUE.TIMEOUT_CYCLES PARAM_VALUE.TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.TIMEOUT_CYCLES}
}


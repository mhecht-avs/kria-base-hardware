# (C) Copyright 2020 - 2021 Xilinx, Inc.
# SPDX-License-Identifier: Apache-2.0

##################################################################
# DESIGN PROCs
##################################################################

# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports

  # Create ports
  set fan_en_b [ create_bd_port -dir O -from 0 -to 0 fan_en_b ]

  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice xlslice_0 ]
  set_property -dict [ list \
   CONFIG.DIN_FROM {2} \
   CONFIG.DIN_TO {2} \
   CONFIG.DIN_WIDTH {3} \
   CONFIG.DOUT_WIDTH {1} \
 ] $xlslice_0
 
set ::PS_INST zynq_ultra_ps_e_0
set zynq_ultra_ps_e_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0 ] 

 apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0] 

set_property -dict [ list \
CONFIG.PSU__CRF_APB__DPLL_FRAC_CFG__ENABLED  {1} \
CONFIG.PSU__CRF_APB__VPLL_FRAC_CFG__ENABLED  {1} \
CONFIG.PSU__CRL_APB__USB3__ENABLE {1} \
CONFIG.PSU__FPGA_PL0_ENABLE {1} \
CONFIG.PSU__NUM_FABRIC_RESETS {4} \
CONFIG.PSU__TTC0__WAVEOUT__ENABLE {1} \
CONFIG.PSU__TTC0__WAVEOUT__IO {EMIO} \
CONFIG.PSU__USE__M_AXI_GP0  {0} \
CONFIG.PSU__USE__M_AXI_GP1  {0} \
CONFIG.PSU__USE__M_AXI_GP2  {1} \
CONFIG.PSU__USE__S_AXI_ACE  {0} \
CONFIG.PSU__USE__S_AXI_ACP  {0} \
CONFIG.PSU__USE__S_AXI_GP0  {0} \
CONFIG.PSU__USE__S_AXI_GP1  {0} \
CONFIG.PSU__USE__S_AXI_GP2  {0} \
CONFIG.PSU__USE__S_AXI_GP3  {0} \
CONFIG.PSU__USE__S_AXI_GP4  {0} \
CONFIG.PSU__USE__S_AXI_GP5  {0} \
CONFIG.PSU__USE__S_AXI_GP6  {0} \
] [get_bd_cells zynq_ultra_ps_e_0] 

# Create port connections
  connect_bd_net -net xlslice_0_Dout [get_bd_ports fan_en_b] [get_bd_pins xlslice_0/Dout]
  connect_bd_net -net zynq_ultra_ps_e_0_emio_ttc0_wave_o [get_bd_pins xlslice_0/Din] [get_bd_pins zynq_ultra_ps_e_0/emio_ttc0_wave_o]


#############################################################
# add pl iic on PMOD
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.1 axi_iic_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property CONFIG.NUM_PORTS {8} [get_bd_cells xlconcat_0]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {Custom} Manual_Source {Auto}}  [get_bd_intf_pins axi_iic_0/IIC]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_slave {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_xbar {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/axi_iic_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_iic_0/S_AXI]
set_property name iic_pmod [get_bd_intf_ports iic_rtl]

connect_bd_net [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]



# Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


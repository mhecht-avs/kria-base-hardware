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

  variable ::mipi_channel_cnt
  set ::mipi_channel_cnt 1


  set ::mipi_axis_numpixperclk(0) 1
  set ::mipi_axis_numpixperclk(1) 1
  set ::mipi_axis_numpixperclk(2) 1

  set ::mipi_csi_buf_depth(0) 8192
  set ::mipi_csi_buf_depth(1) 8192
  set ::mipi_csi_buf_depth(2) 8192

  set ::mipi_csi_linerate_ch(0) 750
  set ::mipi_csi_linerate_ch(1) 750
  set ::mipi_csi_linerate_ch(2) 750

  set ::mipi_csi_num_lanes(0) 4
  set ::mipi_csi_num_lanes(1) 2
  set ::mipi_csi_num_lanes(2) 4

  # YUV422_8bit, YUV422_10bit, RAW8, RAW10, RAW12, RGB888
  set ::mipi_csi_format(0) YUV422_8bit
  set ::mipi_csi_format(1) YUV422_8bit
  set ::mipi_csi_format(2) YUV422_8bit

  set ::PS_INST zynq_ultra_ps_e_0
  set zynq_ultra_ps_e_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0 ]

  apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]

  set_property -dict [ list \
    CONFIG.PSU__CRF_APB__DPLL_FRAC_CFG__ENABLED  {1} \
    CONFIG.PSU__CRF_APB__VPLL_FRAC_CFG__ENABLED  {1} \
    CONFIG.PSU__CRL_APB__USB3__ENABLE {1} \
    CONFIG.PSU__TTC0__WAVEOUT__ENABLE {1} \
    CONFIG.PSU__TTC0__WAVEOUT__IO {EMIO} \
    CONFIG.PSU__USE__M_AXI_GP0  {1} \
    CONFIG.PSU__USE__M_AXI_GP1  {0} \
    CONFIG.PSU__USE__M_AXI_GP2  {1} \
    CONFIG.PSU__USE__S_AXI_ACE  {0} \
    CONFIG.PSU__USE__S_AXI_ACP  {0} \
    CONFIG.PSU__USE__S_AXI_GP0  {0} \
    CONFIG.PSU__USE__S_AXI_GP1  {0} \
    CONFIG.PSU__USE__S_AXI_GP2  {1} \
    CONFIG.PSU__USE__S_AXI_GP3  {0} \
    CONFIG.PSU__USE__S_AXI_GP4  {0} \
    CONFIG.PSU__USE__S_AXI_GP5  {0} \
    CONFIG.PSU__USE__S_AXI_GP6  {0} \
    CONFIG.PSU__NUM_FABRIC_RESETS {4} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__FPGA_PL1_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {300} \
    CONFIG.PSU__GPIO_EMIO_WIDTH {92} \
    CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO {92} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {64} \
    ] [get_bd_cells zynq_ultra_ps_e_0]


  # Create interface ports

  # Create ports
  set fan_en_b [ create_bd_port -dir O -from 0 -to 0 fan_en_b ]

  # Create instance: xlslice_pwm, and set properties
  set xlslice_pwm [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice xlslice_pwm ]
  set_property -dict [ list \
    CONFIG.DIN_FROM {2} \
    CONFIG.DIN_TO {2} \
    CONFIG.DIN_WIDTH {3} \
    CONFIG.DOUT_WIDTH {1} \
    ] $xlslice_pwm

  # Create port connections
  connect_bd_net -net xlslice_pwm_Dout [get_bd_ports fan_en_b] [get_bd_pins xlslice_pwm/Dout]
  connect_bd_net -net zynq_ultra_ps_e_0_emio_ttc0_wave_o [get_bd_pins xlslice_pwm/Din] [get_bd_pins zynq_ultra_ps_e_0/emio_ttc0_wave_o]

  #############################################################

  create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_irq_0
  set_property CONFIG.NUM_PORTS {8} [get_bd_cells xlconcat_irq_0]

  connect_bd_net [get_bd_pins xlconcat_irq_0/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

  create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0

  set_property -dict [list \
    CONFIG.CLKOUT1_JITTER {102.086} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {6.000} \
    CONFIG.USE_RESET {false} \
    ] [get_bd_cells clk_wiz_0]

  set_property -dict [list CONFIG.PRIM_IN_FREQ.VALUE_SRC PROPAGATED] [get_bd_cells clk_wiz_0]

  # Create instance: axi_ic_video, and set properties

  # Create instance: ps_axi_fpd, and set properties
  set ps_axi_lpd [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect ps_axi_lpd ]
  # 1 port for iic
  # 1 port for control interfacec of mipoi csi rx
  set_property -dict [ list \
    CONFIG.NUM_MI [expr 2 * $::mipi_channel_cnt ] \
    CONFIG.NUM_SI {1} \
    ] $ps_axi_lpd

  set ps_axi_fpd [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect ps_axi_fpd ]
  set_property -dict [ list \
    CONFIG.NUM_MI [expr 1 * $::mipi_channel_cnt ] \
    CONFIG.NUM_SI {1} \
    ] $ps_axi_fpd

  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins ps_axi_fpd/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_LPD [get_bd_intf_pins ps_axi_lpd/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD]

  set axi_ic_video [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect axi_ic_video ]
  set_property -dict [ list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.M00_HAS_DATA_FIFO {2} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI [expr $::mipi_channel_cnt] \
    ] $axi_ic_video


  set rst_ps8_0_300M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_0_300M ]
  set rst_ps8_0_99M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_0_99M ]

  set xlslice_csi_rst_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice xlslice_csi_rst_0 ]
  set xlslice_frmb_csi_rst_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice xlslice_frmb_csi_rst_0 ]
  set_property CONFIG.DIN_WIDTH {92} [get_bd_cells xlslice_csi_rst_0]
  set_property CONFIG.DIN_WIDTH {92} [get_bd_cells xlslice_frmb_csi_rst_0]

  set x 0
  set iic$x [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 iic$x ]
  set mipi_phy_if_$x [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:mipi_phy_rtl:1.0 mipi_phy_if_$x ]

  set axi_iic_$x [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.1 axi_iic_$x ]
  set axis_ssconv_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 axis_ssconv_0 ]

  if {$::mipi_channel_cnt > 0} {
    # Create instance: mipi_csi2rxss_0, and set properties
    set mipi_csi2rxss_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mipi_csi2_rx_subsystem mipi_csi2rxss_0 ]
    set_property -dict [ list \
      CONFIG.CMN_NUM_LANES [expr $::mipi_csi_num_lanes(0)] \
      CONFIG.C_DPHY_LANES [expr $::mipi_csi_num_lanes(0)] \
      CONFIG.CMN_NUM_PIXELS [expr $::mipi_axis_numpixperclk(0)] \
      CONFIG.CMN_PXL_FORMAT $::mipi_csi_format(0) \
      CONFIG.CSI_BUF_DEPTH [expr $::mipi_csi_buf_depth(0) ] \
      CONFIG.CSI_EMB_NON_IMG {false} \
      CONFIG.CLK_LANE_IO_LOC {C1} \
      CONFIG.CLK_LANE_IO_LOC_NAME {IO_L7P_T1L_N0_QBC_AD13P_66} \
      CONFIG.C_CLK_LANE_IO_POSITION {13} \
      CONFIG.C_CSI_EN_ACTIVELANES {true} \
      CONFIG.C_CSI_FILTER_USERDATATYPE {true} \
      CONFIG.C_DATA_LANE0_IO_POSITION {15} \
      CONFIG.C_DATA_LANE1_IO_POSITION {17} \
      CONFIG.C_DATA_LANE2_IO_POSITION {19} \
      CONFIG.C_DATA_LANE3_IO_POSITION {21} \
      CONFIG.C_EN_BG0_PIN0 {false} \
      CONFIG.C_EN_BG1_PIN0 {false} \
      CONFIG.C_EN_TIMEOUT_REGS {true} \
      CONFIG.C_HS_LINE_RATE [expr $::mipi_csi_linerate_ch(0)] \
      CONFIG.DPY_LINE_RATE [expr $::mipi_csi_linerate_ch(0)] \
      CONFIG.DATA_LANE0_IO_LOC {A2} \
      CONFIG.DATA_LANE0_IO_LOC_NAME {IO_L8P_T1L_N2_AD5P_66} \
      CONFIG.DATA_LANE1_IO_LOC {B3} \
      CONFIG.DATA_LANE1_IO_LOC_NAME {IO_L9P_T1L_N4_AD12P_66} \
      CONFIG.DATA_LANE2_IO_LOC {B4} \
      CONFIG.DATA_LANE2_IO_LOC_NAME {IO_L10P_T1U_N6_QBC_AD4P_66} \
      CONFIG.DATA_LANE3_IO_LOC {D4} \
      CONFIG.DATA_LANE3_IO_LOC_NAME {IO_L11P_T1U_N8_GC_66} \
      CONFIG.DPY_EN_REG_IF {true} \
      CONFIG.HP_IO_BANK_SELECTION {66} \
      CONFIG.SupportLevel {1} \
      ] $mipi_csi2rxss_0

    # set line rate afterwards to let calculate the C_HS_SETTLE_NS by the IPI wizard
    set_property -dict [list \
      CONFIG.C_HS_LINE_RATE [expr $::mipi_csi_linerate_ch(0)] \
      CONFIG.DPY_LINE_RATE [expr $::mipi_csi_linerate_ch(0)] \
      ] $mipi_csi2rxss_0

    set v_frmbuf_wr_csi_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_frmbuf_wr v_frmbuf_wr_csi_0 ]
    set_property -dict [ list \
      CONFIG.AXIMM_DATA_WIDTH {64} \
      CONFIG.C_M_AXI_MM_VIDEO_DATA_WIDTH {64} \
      CONFIG.HAS_BGR8 {0} \
      CONFIG.HAS_BGRX8 {0} \
      CONFIG.HAS_RGB8 {0} \
      CONFIG.HAS_RGBX8 {0} \
      CONFIG.HAS_UYVY8 {1} \
      CONFIG.HAS_YUYV8 {1} \
      CONFIG.HAS_Y_UV8 {0} \
      CONFIG.MAX_COLS [expr $::mipi_csi_buf_depth(0)] \
      CONFIG.MAX_NR_PLANES {1} \
      CONFIG.MAX_ROWS {4096} \
      CONFIG.SAMPLES_PER_CLOCK [expr $::mipi_axis_numpixperclk(0)] \
      ] $v_frmbuf_wr_csi_0

    if {$::mipi_csi_format(0) == {RAW8}} {
      set_property -dict [ list \
        CONFIG.HAS_Y8 {1} \
        CONFIG.HAS_RGBX8 {1} \
        CONFIG.HAS_YUVX8 {0} \
        CONFIG.HAS_YUYV8 {0} \
        CONFIG.HAS_Y_UV8 {0} \
        CONFIG.HAS_Y_UV8_420 {0} \
        CONFIG.HAS_RGB8 {0} \
        CONFIG.HAS_YUV8 {0} \
        CONFIG.HAS_BGRX8 {1} \
        CONFIG.HAS_UYVY8 {0} \
        CONFIG.HAS_BGR8 {0} \
        CONFIG.HAS_Y_U_V8 {0} \
        CONFIG.MAX_NR_PLANES {1} \
        ] $v_frmbuf_wr_csi_0

      set_property -dict [list \
        CONFIG.S_TDATA_NUM_BYTES {2}  \
        CONFIG.TDATA_REMAP {16'b00000000,tdata[7:0],tdata[7:0]} \
        ] $axis_ssconv_0
    }

    if {$::mipi_csi_format(0) == {YUV422_8bit}} {
      set_property -dict [ list \
        CONFIG.HAS_Y8 {1} \
        CONFIG.HAS_RGBX8 {0} \
        CONFIG.HAS_YUVX8 {0} \
        CONFIG.HAS_YUYV8 {1} \
        CONFIG.HAS_Y_UV8 {0} \
        CONFIG.HAS_Y_UV8_420 {0} \
        CONFIG.HAS_RGB8 {0} \
        CONFIG.HAS_YUV8 {0} \
        CONFIG.HAS_BGRX8 {0} \
        CONFIG.HAS_UYVY8 {1} \
        CONFIG.HAS_BGR8 {0} \
        CONFIG.HAS_Y_U_V8 {0} \
        CONFIG.MAX_NR_PLANES {1} \
        ] $v_frmbuf_wr_csi_0

      set_property -dict [list \
        CONFIG.S_TDATA_NUM_BYTES {2} \
        CONFIG.M_TDATA_NUM_BYTES {3} \
        CONFIG.TDATA_REMAP {8'b00000000,tdata[15:0]} \
      ] $axis_ssconv_0


      set_property -dict [list \
        CONFIG.DPHYRX_BOARD_INTERFACE {som240_1_connector_mipi_csi_ias} \
        ] [get_bd_cells mipi_csi2rxss_0]

      set_property -dict [list \
        CONFIG.VFB_TU_WIDTH {1} \
        CONFIG.C_CSI_EN_CRC {true} \
        CONFIG.C_CSI_EN_ACTIVELANES {true} \
        CONFIG.CMN_PXL_FORMAT {YUV422_8bit} \
        CONFIG.CMN_NUM_LANES {4} \
        CONFIG.C_DPHY_LANES {4} \
        CONFIG.C_EN_CSI_V2_0 {false} \
        CONFIG.CMN_VC {All} \
        CONFIG.CMN_NUM_PIXELS {1} \
        CONFIG.C_HS_LINE_RATE {750} \
        CONFIG.DPY_LINE_RATE {750} \
        CONFIG.C_HS_SETTLE_NS {148} \
        CONFIG.C_EN_TIMEOUT_REGS {true} \
        CONFIG.SupportLevel {1} \
        ] [get_bd_cells mipi_csi2rxss_0]
    }

  }

  connect_bd_net -net clk_200M \
    [get_bd_pins clk_wiz_0/clk_out1] \
    [get_bd_pins mipi_csi2rxss_0/dphy_clk_200M] \
    [get_bd_pins mipi_csi2rxss_1/dphy_clk_200M] \
    [get_bd_pins mipi_csi2rxss_2/dphy_clk_200M] \
    [get_bd_pins mipi_csi2rxss_3/dphy_clk_200M]

  #    [get_bd_pins clk_wiz_0/clk_300M]
  connect_bd_net -net clk_300M \
    [get_bd_pins zynq_ultra_ps_e_0/pl_clk1] \
    [get_bd_pins clk_wiz_0/clk_in1] \
    [get_bd_pins rst_clk_wiz_0_300M/slowest_sync_clk] \
    [get_bd_pins rst_ps8_0_300M/slowest_sync_clk] \
    [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] \
    [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk] \
    [get_bd_pins axi_ic_video/ACLK] \
    [get_bd_pins axi_ic_video/M00_ACLK] \
    [get_bd_pins axi_ic_video/S00_ACLK] \
    [get_bd_pins axi_ic_video/S01_ACLK] \
    [get_bd_pins axi_ic_video/S02_ACLK] \
    [get_bd_pins axi_ic_video/S03_ACLK] \
    [get_bd_pins axi_ic_video/S04_ACLK] \
    [get_bd_pins axi_ic_video/S05_ACLK] \
    [get_bd_pins axis_ssconv_0/aclk] \
    [get_bd_pins axis_ssconv_1/aclk] \
    [get_bd_pins axis_ssconv_2/aclk] \
    [get_bd_pins axis_ssconv_3/aclk] \
    [get_bd_pins v_frmbuf_wr_csi_0/ap_clk] \
    [get_bd_pins v_frmbuf_wr_csi_1/ap_clk] \
    [get_bd_pins v_frmbuf_wr_csi_2/ap_clk] \
    [get_bd_pins v_frmbuf_wr_csi_3/ap_clk] \
    [get_bd_pins v_frmbuf_wr_tpg/ap_clk] \
    [get_bd_pins mipi_csi2rxss_0/video_aclk] \
    [get_bd_pins mipi_csi2rxss_1/video_aclk] \
    [get_bd_pins mipi_csi2rxss_2/video_aclk] \
    [get_bd_pins mipi_csi2rxss_3/video_aclk] \
    [get_bd_pins v_tpg_0/ap_clk] \
    [get_bd_pins ps_axi_fpd/ACLK] \
    [get_bd_pins ps_axi_fpd/M00_ACLK] \
    [get_bd_pins ps_axi_fpd/M01_ACLK] \
    [get_bd_pins ps_axi_fpd/M02_ACLK] \
    [get_bd_pins ps_axi_fpd/M04_ACLK] \
    [get_bd_pins ps_axi_fpd/M06_ACLK] \
    [get_bd_pins ps_axi_fpd/M08_ACLK] \
    [get_bd_pins ps_axi_fpd/M09_ACLK] \
    [get_bd_pins ps_axi_fpd/S00_ACLK]

  connect_bd_net -net clk_99M  \
    [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
    [get_bd_pins mipi_csi2rxss_0/lite_aclk] \
    [get_bd_pins rst_ps8_0_99M/slowest_sync_clk] \
    [get_bd_pins ps_axi_lpd/M00_ACLK] \
    [get_bd_pins ps_axi_lpd/S00_ACLK] \
    [get_bd_pins ps_axi_lpd/ACLK] \
    [get_bd_pins ps_axi_lpd/M01_ACLK] \
    [get_bd_pins axi_iic_0/s_axi_aclk] \
    [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk]

  connect_bd_net [get_bd_pins xlslice_csi_rst_0/Dout] [get_bd_pins mipi_csi2rxss_0/video_aresetn]
  connect_bd_net [get_bd_pins xlslice_csi_rst_0/Din] [get_bd_pins xlslice_frmb_csi_rst_0/Din]
  connect_bd_net [get_bd_pins xlslice_frmb_csi_rst_0/Dout] [get_bd_pins v_frmbuf_wr_csi_0/ap_rst_n]
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/emio_gpio_o] [get_bd_pins xlslice_csi_rst_0/Din]

  connect_bd_net [get_bd_pins mipi_csi2rxss_0/system_rst_out] [get_bd_pins axis_ssconv_0/aresetn]

  set_property -dict [list CONFIG.M_TDATA_NUM_BYTES.VALUE_SRC USER] [get_bd_cells axis_ssconv_0]
  #set_property -dict [list CONFIG.M_TDATA_NUM_BYTES {3} CONFIG.TDATA_REMAP {8'b00000000,tdata[15:0]}] [get_bd_cells axis_ssconv_0]

  connect_bd_net [get_bd_pins mipi_csi2rxss_0/csirxss_csi_irq] [get_bd_pins xlconcat_irq_0/In1]
  connect_bd_net [get_bd_pins v_frmbuf_wr_csi_0/interrupt] [get_bd_pins xlconcat_irq_0/In2]

  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins ps_axi_fpd/M00_AXI] [get_bd_intf_pins v_frmbuf_wr_csi_0/s_axi_CTRL]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins ps_axi_fpd/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]

  connect_bd_intf_net [get_bd_intf_pins axis_ssconv_0/S_AXIS] [get_bd_intf_pins mipi_csi2rxss_0/video_out]
  connect_bd_intf_net [get_bd_intf_pins axis_ssconv_0/M_AXIS] [get_bd_intf_pins v_frmbuf_wr_csi_0/s_axis_video]

  connect_bd_intf_net [get_bd_intf_pins v_frmbuf_wr_csi_0/m_axi_mm_video] -boundary_type upper [get_bd_intf_pins axi_ic_video/S00_AXI]
  connect_bd_intf_net [get_bd_intf_ports mipi_phy_if_0] [get_bd_intf_pins mipi_csi2rxss_0/mipi_phy_if]

  #connect_bd_intf_net -boundary_type upper [get_bd_intf_pins ps_axi_fpd/M00_AXI] [get_bd_intf_pins mipi_csi2rxss_0/csirxss_s_axi]
  #connect_bd_intf_net -boundary_type upper [get_bd_intf_pins ps_axi_fpd/M01_AXI] [get_bd_intf_pins v_frmbuf_wr_csi_0/s_axi_CTRL]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins ps_axi_fpd/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_ic_video/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]

  #apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_slave {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_xbar {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/axi_iic_0/S_AXI} ddr_seg {Auto} intc_ip {/ps_axi_lpd} master_apm {0}}  [get_bd_intf_pins axi_iic_0/S_AXI]

  connect_bd_intf_net [get_bd_intf_ports iic0] [get_bd_intf_pins axi_iic_0/IIC]
  connect_bd_net [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins xlconcat_irq_0/In0]
  connect_bd_net [get_bd_pins axi_ic_video/S00_ARESETN] [get_bd_pins rst_ps8_0_300M/peripheral_aresetn]
  connect_bd_net [get_bd_pins axi_ic_video/M00_ARESETN] [get_bd_pins rst_ps8_0_300M/peripheral_aresetn]
  connect_bd_net [get_bd_pins axi_ic_video/ARESETN] [get_bd_pins rst_ps8_0_300M/interconnect_aresetn]
#  connect_bd_net [get_bd_pins ps_axi_fpd/M01_ARESETN] [get_bd_pins ps_axi_fpd/M00_ARESETN] -boundary_type upper
#  connect_bd_net [get_bd_pins ps_axi_fpd/S00_ARESETN] [get_bd_pins ps_axi_fpd/M01_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins ps_axi_fpd/S00_ARESETN] [get_bd_pins rst_ps8_0_300M/interconnect_aresetn]
  connect_bd_net [get_bd_pins ps_axi_fpd/ARESETN] [get_bd_pins rst_ps8_0_300M/interconnect_aresetn]

  set_property -dict [list CONFIG.NUM_MI {2}] [get_bd_cells ps_axi_lpd]
  set_property -dict [list CONFIG.S00_HAS_DATA_FIFO {1}] [get_bd_cells axi_ic_video]


  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins rst_ps8_0_99M/ext_reset_in]
  connect_bd_net [get_bd_pins rst_ps8_0_99M/peripheral_aresetn] [get_bd_pins axi_iic_0/s_axi_aresetn]
  connect_bd_net [get_bd_pins rst_ps8_0_99M/interconnect_aresetn] [get_bd_pins ps_axi_lpd/ARESETN]
  connect_bd_net [get_bd_pins ps_axi_lpd/S00_ARESETN] [get_bd_pins ps_axi_lpd/M00_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins ps_axi_lpd/M00_ARESETN] [get_bd_pins rst_ps8_0_99M/peripheral_aresetn]


  connect_bd_net [get_bd_pins ps_axi_lpd/M01_ARESETN] [get_bd_pins rst_ps8_0_99M/peripheral_aresetn]
  connect_bd_net [get_bd_pins rst_ps8_0_300M/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]

  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins ps_axi_lpd/M00_AXI] [get_bd_intf_pins axi_iic_0/S_AXI]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins ps_axi_lpd/M01_AXI] [get_bd_intf_pins mipi_csi2rxss_0/csirxss_s_axi]
  connect_bd_net [get_bd_pins mipi_csi2rxss_0/lite_aresetn] [get_bd_pins rst_ps8_0_99M/peripheral_aresetn]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins ps_axi_fpd/M00_AXI] [get_bd_intf_pins v_frmbuf_wr_csi_0/s_axi_CTRL]

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


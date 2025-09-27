# CORDIC FPGA Constraints File for Zynq Z2 Board
# This file defines the pin assignments and timing constraints

##############################################################################
# Clock Constraints
##############################################################################

# 100 MHz system clock (10ns period)
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clock]

# Input delay constraints (assuming external signals arrive relative to clock)
set_input_delay -clock [get_clocks sys_clk_pin] -min -add_delay 2.000 [get_ports {reset start x_start[*] y_start[*] angle[*]}]
set_input_delay -clock [get_clocks sys_clk_pin] -max -add_delay 8.000 [get_ports {reset start x_start[*] y_start[*] angle[*]}]

# Output delay constraints (assuming external circuits expect data relative to clock)
set_output_delay -clock [get_clocks sys_clk_pin] -min -add_delay 1.000 [get_ports {cosine[*] sine[*] done}]
set_output_delay -clock [get_clocks sys_clk_pin] -max -add_delay 7.000 [get_ports {cosine[*] sine[*] done}]

##############################################################################
# Pin Assignments for Zynq Z2 Board (Pynq-Z2 / Zybo Z7)
##############################################################################

# System Clock (100 MHz) - Usually comes from dedicated clock input
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { clock }]; 

# Reset signal - Connect to a button or switch
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { reset }]; 

# Start signal - Connect to a button
set_property -dict { PACKAGE_PIN D20   IOSTANDARD LVCMOS33 } [get_ports { start }]; 

# Done output - Connect to an LED
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { done }]; 

# Example pin assignments for data inputs/outputs
# Note: In a real implementation, these would typically connect to memory or other modules
# For demonstration, we're assigning them to available I/O pins

# X_start input pins (16-bit) - Could connect to switches or external interface
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { x_start[0] }]; 
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { x_start[1] }]; 
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { x_start[2] }]; 
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { x_start[3] }]; 
set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports { x_start[4] }]; 
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { x_start[5] }]; 
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { x_start[6] }]; 
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { x_start[7] }]; 
set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { x_start[8] }]; 
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { x_start[9] }]; 
set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports { x_start[10] }]; 
set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { x_start[11] }]; 
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { x_start[12] }]; 
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { x_start[13] }]; 
set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { x_start[14] }]; 
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { x_start[15] }]; 

# Y_start input pins (16-bit) - Connect to available GPIO
set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports { y_start[0] }]; 
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { y_start[1] }]; 
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { y_start[2] }]; 
set_property -dict { PACKAGE_PIN K14   IOSTANDARD LVCMOS33 } [get_ports { y_start[3] }]; 
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { y_start[4] }]; 
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { y_start[5] }]; 
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { y_start[6] }]; 
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { y_start[7] }]; 
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { y_start[8] }]; 
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { y_start[9] }]; 
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { y_start[10] }]; 
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { y_start[11] }]; 
set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { y_start[12] }]; 
set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports { y_start[13] }]; 
set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { y_start[14] }]; 
set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports { y_start[15] }]; 

# Cosine output pins (16-bit) - Connect to LEDs or external interface  
set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports { cosine[0] }]; 
set_property -dict { PACKAGE_PIN T20   IOSTANDARD LVCMOS33 } [get_ports { cosine[1] }]; 
set_property -dict { PACKAGE_PIN T19   IOSTANDARD LVCMOS33 } [get_ports { cosine[2] }]; 
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { cosine[3] }]; 
set_property -dict { PACKAGE_PIN V20   IOSTANDARD LVCMOS33 } [get_ports { cosine[4] }]; 
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports { cosine[5] }]; 
set_property -dict { PACKAGE_PIN V18   IOSTANDARD LVCMOS33 } [get_ports { cosine[6] }]; 
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { cosine[7] }]; 
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { cosine[8] }]; 
set_property -dict { PACKAGE_PIN W18   IOSTANDARD LVCMOS33 } [get_ports { cosine[9] }]; 
set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports { cosine[10] }]; 
set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 } [get_ports { cosine[11] }]; 
set_property -dict { PACKAGE_PIN Y17   IOSTANDARD LVCMOS33 } [get_ports { cosine[12] }]; 
set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS33 } [get_ports { cosine[13] }]; 
set_property -dict { PACKAGE_PIN Y14   IOSTANDARD LVCMOS33 } [get_ports { cosine[14] }]; 
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports { cosine[15] }]; 

# Sine output pins (16-bit) - Connect to available GPIO
set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports { sine[0] }]; 
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { sine[1] }]; 
set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports { sine[2] }]; 
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { sine[3] }]; 
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports { sine[4] }]; 
set_property -dict { PACKAGE_PIN T12   IOSTANDARD LVCMOS33 } [get_ports { sine[5] }]; 
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { sine[6] }]; 
set_property -dict { PACKAGE_PIN U15   IOSTANDARD LVCMOS33 } [get_ports { sine[7] }]; 
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports { sine[8] }]; 
set_property -dict { PACKAGE_PIN T13   IOSTANDARD LVCMOS33 } [get_ports { sine[9] }]; 
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { sine[10] }]; 
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { sine[11] }]; 
set_property -dict { PACKAGE_PIN U10   IOSTANDARD LVCMOS33 } [get_ports { sine[12] }]; 
set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports { sine[13] }]; 
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { sine[14] }]; 
set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { sine[15] }]; 

# Note: Angle input (32-bit) pins are not assigned here as they would typically 
# come from internal logic or memory rather than external pins

##############################################################################
# Timing Constraints and Optimization
##############################################################################

# Set maximum delay for combinational paths
set_max_delay -from [get_ports {x_start[*] y_start[*] angle[*]}] -to [get_ports {cosine[*] sine[*]}] 9.000

# False path constraints for asynchronous reset
set_false_path -from [get_ports reset] -to [all_registers]

# Multi-cycle path constraints for CORDIC computation (if needed)
# The CORDIC algorithm takes multiple clock cycles, so we can relax timing
set_multicycle_path -setup -end -from [get_cells -hierarchical -filter {NAME =~ *x[*]*}] -to [get_cells -hierarchical -filter {NAME =~ *x[*]*}] 2
set_multicycle_path -hold -end -from [get_cells -hierarchical -filter {NAME =~ *x[*]*}] -to [get_cells -hierarchical -filter {NAME =~ *x[*]*}] 1

##############################################################################
# Physical Constraints and Optimization Directives
##############################################################################

# Power optimization
set_property POWER_OPT.PAR_NUM_FANOUT_LUT 12 [current_design]

# Area optimization for lookup tables
set_property OPTIMIZE_PRIMITIVE true [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ LUT*}]

# Keep hierarchy for debugging (optional)
set_property KEEP_HIERARCHY true [get_cells {dut}]

##############################################################################
# Configuration Constraints
##############################################################################

# Configuration settings for Zynq
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Bitstream settings
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
# Vivado 2017.4: dual-core Zynq PS with a 64 KiB AXI BRAM.

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $project_dir build]
set vivado_dir [file join $build_dir vivado]
set hw_dir [file join $build_dir hw]
set project_name pi_monte_carlo
set bd_name system

file mkdir $build_dir
file mkdir $hw_dir

set board_parts [lsort [get_board_parts -quiet "digilentinc.com:zybo:*"]]
if {[llength $board_parts] == 0} {
    error "Board part da Zybo nao encontrado. Instale os board files da Digilent."
}
set board_part [lindex $board_parts end]
puts "INFO: Usando board part $board_part"

create_project -force $project_name $vivado_dir -part xc7z010clg400-1
set_property board_part $board_part [current_project]

create_bd_design $bd_name

set ps7 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:* processing_system7_0]
apply_bd_automation \
    -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    $ps7

set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
] $ps7

set interconnect [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:* axi_interconnect_0]
set_property -dict [list CONFIG.NUM_MI {1}] $interconnect

set bram_ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:* axi_bram_ctrl_0]
set_property -dict [list \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.SINGLE_PORT_BRAM {1} \
] $bram_ctrl

set bram [create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:* blk_mem_gen_0]
set_property -dict [list \
    CONFIG.Memory_Type {Single_Port_RAM} \
    CONFIG.Use_Byte_Write_Enable {true} \
    CONFIG.Byte_Size {8} \
] $bram

set reset [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* rst_ps7_0_100M]

set const_one [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:* constant_one]
set_property -dict [list CONFIG.CONST_VAL {1}] $const_one
set const_zero [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:* constant_zero]
set_property -dict [list CONFIG.CONST_VAL {0}] $const_zero

connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] \
    [get_bd_intf_pins axi_interconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] \
    [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] \
    [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]

connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
    [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] \
    [get_bd_pins axi_interconnect_0/ACLK] \
    [get_bd_pins axi_interconnect_0/S00_ACLK] \
    [get_bd_pins axi_interconnect_0/M00_ACLK] \
    [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] \
    [get_bd_pins rst_ps7_0_100M/slowest_sync_clk]

connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
    [get_bd_pins rst_ps7_0_100M/ext_reset_in]
connect_bd_net [get_bd_pins constant_one/dout] \
    [get_bd_pins rst_ps7_0_100M/dcm_locked]
connect_bd_net [get_bd_pins constant_zero/dout] \
    [get_bd_pins rst_ps7_0_100M/aux_reset_in] \
    [get_bd_pins rst_ps7_0_100M/mb_debug_sys_rst]

connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] \
    [get_bd_pins axi_interconnect_0/ARESETN] \
    [get_bd_pins axi_interconnect_0/S00_ARESETN] \
    [get_bd_pins axi_interconnect_0/M00_ARESETN] \
    [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn]

assign_bd_address \
    -offset 0x40000000 \
    -range 64K \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0]

validate_bd_design
save_bd_design

set bd_file [get_files "${bd_name}.bd"]
generate_target all $bd_file
set wrapper_files [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_files
update_compile_order -fileset sources_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "A implementacao nao terminou corretamente."
}

set bit_file [file join [get_property DIRECTORY [get_runs impl_1]] "${bd_name}_wrapper.bit"]
if {![file exists $bit_file]} {
    error "Bitstream nao encontrado: $bit_file"
}

set hwdef_file [file join $hw_dir "${project_name}_hw.hdf"]
set hdf_file [file join $hw_dir "${project_name}.hdf"]
write_hwdef -force -file $hwdef_file
write_sysdef -force -hwdef $hwdef_file -bitfile $bit_file -file $hdf_file

puts "INFO: Hardware e bitstream exportados para $hdf_file"
close_project

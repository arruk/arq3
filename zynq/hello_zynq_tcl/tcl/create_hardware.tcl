# Vivado 2025.2 batch script for the original Digilent Zybo (XC7Z010).

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $project_dir build]
set vivado_dir [file join $build_dir vivado]
set project_name hello_zynq
set bd_name system

file mkdir $build_dir

# Use the installed Digilent board preset so DDR and UART parameters match
# the exact Zybo board revision known by this Vivado installation.
set board_parts [lsort [get_board_parts -quiet "digilentinc.com:zybo:*"]]
if {[llength $board_parts] == 0} {
    set board_parts [lsort [get_board_parts -quiet "*zybo*"]]
}
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

# The chip physically has two Cortex-A9 cores. No PL master, slave or interrupt
# interface is needed for this Processing System-only Vivado project.
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {0} \
    CONFIG.PCW_USE_S_AXI_HP0 {0} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {0} \
] $ps7

validate_bd_design
save_bd_design

set bd_file [get_files "${bd_name}.bd"]
generate_target all $bd_file
set wrapper_files [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_files
update_compile_order -fileset sources_1

puts "INFO: Projeto Vivado criado em $vivado_dir"
close_project

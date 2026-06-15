# XSCT 2017.4: program the PL and start both Cortex-A9 applications.

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set workspace [file join $project_dir build sdk_workspace]
set hw_project [file join $workspace hw_platform_0]
set init_script [file join $hw_project ps7_init.tcl]
set elf0 [file join $workspace pi_core0 Debug pi_core0.elf]
set elf1 [file join $workspace pi_core1 Debug pi_core1.elf]
set bit_files [glob -nocomplain [file join $hw_project *.bit]]

if {![file exists $init_script]} {
    error "ps7_init.tcl nao encontrado. Execute create_software.tcl."
}
if {![file exists $elf0] || ![file exists $elf1]} {
    error "Aplicacoes nao encontradas. Execute create_software.tcl."
}
if {[llength $bit_files] == 0} {
    error "Bitstream nao encontrado dentro de $hw_project"
}

connect -url tcp:127.0.0.1:3121

targets -set -nocase -filter {name =~ "ARM*#0"}
rst -system
after 1000

fpga -file [lindex $bit_files 0]

targets -set -nocase -filter {name =~ "ARM*#0"}
source $init_script
ps7_init
ps7_post_config

targets -set -nocase -filter {name =~ "ARM*#1"}
rst -processor
dow $elf1

targets -set -nocase -filter {name =~ "ARM*#0"}
rst -processor
dow $elf0

# Core 1 waits for the signature written by core 0.
targets -set -nocase -filter {name =~ "ARM*#1"}
con
targets -set -nocase -filter {name =~ "ARM*#0"}
con

puts "INFO: Os dois cores foram iniciados."


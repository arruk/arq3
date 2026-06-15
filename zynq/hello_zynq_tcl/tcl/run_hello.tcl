# XSCT 2017.4 script: initialize the Zynq and run the ELF on core 0.

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set workspace [file join $project_dir build sdk_workspace]
set hw_project [file join $workspace hw_platform_0]
set init_script [file join $hw_project ps7_init.tcl]
set elf_file [file join $workspace hello_world Debug hello_world.elf]

if {![file exists $init_script]} {
    error "Inicializacao do PS nao encontrada: execute create_software.tcl"
}
if {![file exists $elf_file]} {
    error "ELF nao encontrado: execute create_software.tcl"
}

connect -url tcp:127.0.0.1:3121

targets -set -nocase -filter {name =~ "ARM*#0"}
rst -system
after 1000

# A system reset can invalidate the selected target, so select core 0 again.
targets -set -nocase -filter {name =~ "ARM*#0"}
source $init_script
ps7_init
ps7_post_config

dow $elf_file
puts "INFO: Iniciando $elf_file no Cortex-A9 core 0"
con


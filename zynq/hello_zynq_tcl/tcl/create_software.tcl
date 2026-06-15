# SDK/XSCT 2017.4 script: standalone application on Cortex-A9 core 0.

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $project_dir build]
set hw_file [file join $build_dir hw hello_zynq.hdf]
set workspace [file join $build_dir sdk_workspace]
set source_file [file join $project_dir src helloworld.c]

if {![file exists $hw_file]} {
    error "Hardware nao encontrado: execute primeiro create_hardware.tcl"
}
if {![file exists $source_file]} {
    error "Codigo-fonte nao encontrado: $source_file"
}

# This directory contains only generated SDK projects, so rebuilding it is safe.
file delete -force $workspace
file mkdir $workspace
setws $workspace

createhw -name hw_platform_0 -hwspec $hw_file
createbsp \
    -name bsp_core0 \
    -hwproject hw_platform_0 \
    -proc ps7_cortexa9_0 \
    -os standalone

createapp \
    -name hello_world \
    -hwproject hw_platform_0 \
    -proc ps7_cortexa9_0 \
    -os standalone \
    -lang C \
    -app {Hello World} \
    -bsp bsp_core0

# Replace the SDK template with the source kept under version control.
file copy -force $source_file [file join $workspace hello_world src helloworld.c]

projects -build

set elf_file [file join $workspace hello_world Debug hello_world.elf]
if {![file exists $elf_file]} {
    error "A compilacao terminou sem produzir $elf_file"
}
puts "INFO: Aplicacao compilada: $elf_file"

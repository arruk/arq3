# SDK/XSCT 2017.4: one standalone application for each Cortex-A9 core.

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $project_dir build]
set hw_file [file join $build_dir hw pi_monte_carlo.hdf]
set workspace [file join $build_dir sdk_workspace]

proc patch_linker_script {path origin length} {
    if {![file exists $path]} {
        error "Linker script nao encontrado: $path"
    }

    set channel [open $path r]
    set contents [read $channel]
    close $channel

    set replacement "ps7_ddr_0_S_AXI_BASEADDR : ORIGIN = $origin, LENGTH = $length"
    set count [regsub -all \
        {ps7_ddr_0_S_AXI_BASEADDR[ \t]*:[^\r\n]*} \
        $contents \
        $replacement \
        contents]
    if {$count != 1} {
        error "Nao foi possivel ajustar a regiao DDR em $path"
    }

    set channel [open $path w]
    puts -nonewline $channel $contents
    close $channel
}

proc copy_application_sources {project_dir workspace app core_dir} {
    set destination [file join $workspace $app src]
    file copy -force \
        [file join $project_dir src $core_dir main.c] \
        [file join $destination main.c]
    file copy -force \
        [file join $project_dir src common monte_carlo.c] \
        [file join $destination monte_carlo.c]
    file copy -force \
        [file join $project_dir src common monte_carlo.h] \
        [file join $destination monte_carlo.h]
    file copy -force \
        [file join $project_dir src common shared_data.h] \
        [file join $destination shared_data.h]
}

if {![file exists $hw_file]} {
    error "Hardware nao encontrado: execute primeiro create_hardware.tcl"
}

file delete -force $workspace
file mkdir $workspace
setws $workspace

createhw -name hw_platform_0 -hwspec $hw_file

createbsp \
    -name bsp_core0 \
    -hwproject hw_platform_0 \
    -proc ps7_cortexa9_0 \
    -os standalone
createbsp \
    -name bsp_core1 \
    -hwproject hw_platform_0 \
    -proc ps7_cortexa9_1 \
    -os standalone

createapp \
    -name pi_core0 \
    -hwproject hw_platform_0 \
    -proc ps7_cortexa9_0 \
    -os standalone \
    -lang C \
    -app {Empty Application} \
    -bsp bsp_core0
createapp \
    -name pi_core1 \
    -hwproject hw_platform_0 \
    -proc ps7_cortexa9_1 \
    -os standalone \
    -lang C \
    -app {Empty Application} \
    -bsp bsp_core1

copy_application_sources $project_dir $workspace pi_core0 core0
copy_application_sources $project_dir $workspace pi_core1 core1

# Keep code, data, heap, stacks and MMU tables of both cores disjoint.
patch_linker_script \
    [file join $workspace pi_core0 src lscript.ld] \
    0x00100000 \
    0x07F00000
patch_linker_script \
    [file join $workspace pi_core1 src lscript.ld] \
    0x08100000 \
    0x07F00000

projects -build

set elf0 [file join $workspace pi_core0 Debug pi_core0.elf]
set elf1 [file join $workspace pi_core1 Debug pi_core1.elf]
if {![file exists $elf0]} {
    error "ELF do core 0 nao produzido: $elf0"
}
if {![file exists $elf1]} {
    error "ELF do core 1 nao produzido: $elf1"
}

puts "INFO: Core 0: $elf0"
puts "INFO: Core 1: $elf1"


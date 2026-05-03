#!/usr/bin/env bash
set -euo pipefail

verilator --cc --exe --build --top-module top \
	-Wno-fatal -Wall \
	-Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-DECLFILENAME \
	-Wno-MULTITOP -Wno-PINCONNECTEMPTY \
	sim/sim_vga.cpp \
	sim/vga_sync_model.v \
	src/top.v \
	src/mesh_grid.v \
	src/mesh.v \
	src/mesh_filter_cores.v \
	src/win_stream.v \
	src/filters.v \
	src/mesh_source.v \
	src/mesh_vga_stream.v \
	src/vga.v \
	src/mem.v

./obj_dir/Vtop "$@"

#include "Vtop.h"
#include "Vtop___024root.h"
#include "verilated.h"

#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {
constexpr int H_VISIBLE = 640;
constexpr int H_TOTAL = 800;
constexpr int V_VISIBLE = 480;
constexpr int V_TOTAL = 525;
constexpr int FRAME_CYCLES = H_TOTAL * V_TOTAL;
constexpr int IMG_W = 256;
constexpr int IMG_H = 128;
constexpr int VGA_SCALE = 2;
constexpr int VGA_OFFSET_X = 64;
constexpr int VGA_OFFSET_Y = 112;
constexpr int DEFAULT_WARMUP_CYCLES = 100000;
constexpr uint32_t SINK_VALID_BIT = 26;
constexpr uint32_t SINK_PIXEL_BIT = 17;

struct Pixel {
    uint8_t r;
    uint8_t g;
    uint8_t b;
};

void write_ppm(const std::string& path, const std::vector<Pixel>& frame) {
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        std::cerr << "failed to open output file: " << path << "\n";
        std::exit(1);
    }

    out << "P6\n" << H_VISIBLE << " " << V_VISIBLE << "\n255\n";
    for (const Pixel& pixel : frame) {
        out.put(static_cast<char>(pixel.r));
        out.put(static_cast<char>(pixel.g));
        out.put(static_cast<char>(pixel.b));
    }
}

void advance_position(int& h, int& v) {
    if (h == H_TOTAL - 1) {
        h = 0;
        if (v == V_TOTAL - 1) {
            v = 0;
        } else {
            ++v;
        }
    } else {
        ++h;
    }
}
}  // namespace

int main(int argc, char** argv) {
	Verilated::commandArgs(argc, argv);

	std::string output_path = "sim/vga_frame.ppm";
	int64_t warmup_cycles = DEFAULT_WARMUP_CYCLES;
	bool scan_vga_outputs = false;

	for (int i = 1; i < argc; ++i) {
		const std::string arg = argv[i];
		if (arg == "--out" && (i + 1) < argc) {
			output_path = argv[++i];
		} else if (arg == "--warmup" && (i + 1) < argc) {
			warmup_cycles = static_cast<int64_t>(std::atoi(argv[++i])) * FRAME_CYCLES;
		} else if (arg == "--warmup-cycles" && (i + 1) < argc) {
			warmup_cycles = std::atoll(argv[++i]);
		} else if (arg == "--scan") {
			scan_vga_outputs = true;
		} else {
			std::cerr << "usage: " << argv[0]
			          << " [--warmup frames] [--warmup-cycles cycles]"
			          << " [--scan] [--out file.ppm]\n";
			return 1;
		}
	}

	Vtop top;
	int h = H_TOTAL - 1;
	int v = V_TOTAL - 1;
	uint64_t source_fires = 0;
	uint64_t sink_packets = 0;
	uint64_t sink_one_packets = 0;
	uint64_t framebuffer_writes = 0;

    auto half_cycle_low = [&]() {
        top.CLOCK_50 = 0;
        top.eval();
    };

	auto posedge = [&](bool mirror_reset) {
		top.CLOCK_50 = 1;
		top.eval();
		if (mirror_reset) {
			h = H_TOTAL - 1;
			v = V_TOTAL - 1;
		} else {
			advance_position(h, v);

			if (top.rootp->top__DOT__image_source_inst__DOT__fire) {
				++source_fires;
			}

			const uint32_t sink_pkt =
			    top.rootp->top__DOT__mesh_grid_inst__DOT____Vcellout__row_gen__BRA__15__KET____DOT__col_gen__BRA__15__KET____DOT__node_inst__east_out_pkt;
			if ((sink_pkt >> SINK_VALID_BIT) & 1U) {
				++sink_packets;
				if ((sink_pkt >> SINK_PIXEL_BIT) & 1U) {
					++sink_one_packets;
				}
			}

			if (top.rootp->top__DOT__vga_stream_display_inst__DOT__display_inst__DOT__framebuffer_inst__DOT__write_bank0) {
				++framebuffer_writes;
			}
		}
	};

    top.SW = 1;
    for (int i = 0; i < 8; ++i) {
        half_cycle_low();
        posedge(true);
    }

	top.SW = 0;

	for (int64_t i = 0; i < warmup_cycles; ++i) {
		half_cycle_low();
		posedge(false);
	}

	std::vector<Pixel> frame(H_VISIBLE * V_VISIBLE, Pixel{0, 0, 0});
	int lit_pixels = 0;
	int active_samples = 0;

	if (scan_vga_outputs) {
		for (int i = 0; i < FRAME_CYCLES; ++i) {
			half_cycle_low();
			posedge(false);

			if (h < H_VISIBLE && v < V_VISIBLE) {
				const uint8_t r = top.VGA_R;
				const uint8_t g = top.VGA_G;
				const uint8_t b = top.VGA_B;
				frame[(v * H_VISIBLE) + h] = Pixel{r, g, b};
				++active_samples;
				if (r || g || b) {
					++lit_pixels;
				}
			}
		}
	} else {
		for (int y_pos = 0; y_pos < V_VISIBLE; ++y_pos) {
			for (int x_pos = 0; x_pos < H_VISIBLE; ++x_pos) {
				bool pixel_on = false;
				const bool in_display =
				    (x_pos >= VGA_OFFSET_X) &&
				    (x_pos < (VGA_OFFSET_X + (IMG_W * VGA_SCALE))) &&
				    (y_pos >= VGA_OFFSET_Y) &&
				    (y_pos < (VGA_OFFSET_Y + (IMG_H * VGA_SCALE)));

				if (in_display) {
					const int image_x = (x_pos - VGA_OFFSET_X) / VGA_SCALE;
					const int image_y = (y_pos - VGA_OFFSET_Y) / VGA_SCALE;
					const int addr = (image_y * IMG_W) + image_x;
					pixel_on =
					    top.rootp->top__DOT__vga_stream_display_inst__DOT__display_inst__DOT__framebuffer_inst__DOT__memory0__DOT__memory[addr] != 0;
				}

				const uint8_t value = pixel_on ? 255 : 0;
				frame[(y_pos * H_VISIBLE) + x_pos] = Pixel{value, value, value};
				if (pixel_on) {
					++lit_pixels;
				}
				++active_samples;
			}
		}
	}

	write_ppm(output_path, frame);

	int rom_ones = 0;
	int framebuffer_ones = 0;
	for (int addr = 0; addr < (IMG_W * IMG_H); ++addr) {
		if (top.rootp->top__DOT__image_source_inst__DOT__image_rom__DOT__memory[addr]) {
			++rom_ones;
		}
		if (top.rootp->top__DOT__vga_stream_display_inst__DOT__display_inst__DOT__framebuffer_inst__DOT__memory0__DOT__memory[addr]) {
			++framebuffer_ones;
		}
	}

	std::cout << "wrote " << output_path << "\n"
	          << "mode=" << (scan_vga_outputs ? "scan" : "framebuffer") << "\n"
	          << "warmup_cycles=" << warmup_cycles << "\n"
	          << "active_samples=" << active_samples << "\n"
	          << "lit_pixels=" << lit_pixels << "\n"
	          << "rom_ones=" << rom_ones << "\n"
	          << "source_fires=" << source_fires << "\n"
	          << "sink_packets=" << sink_packets << "\n"
	          << "sink_one_packets=" << sink_one_packets << "\n"
	          << "framebuffer_writes=" << framebuffer_writes << "\n"
	          << "framebuffer_ones=" << framebuffer_ones << "\n";

	return 0;
}

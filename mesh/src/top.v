`timescale 1 ps / 1 ps

module top #(
	parameter IMAGE_FILE = "src/image.mem"
) (
	input         CLOCK_50,
	input  [9:0]  SW,

	output [7:0]  VGA_R,
	output [7:0]  VGA_G,
	output [7:0]  VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_CLK,
	output        VGA_BLANK_N,
	output        VGA_SYNC_N
);
	localparam integer IMG_W = 256;
	localparam integer IMG_H = 128;
	localparam integer VGA_SCALE = 2;
	localparam integer VGA_OFFSET_X = 64;
	localparam integer VGA_OFFSET_Y = 112;

	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);

	wire pclk;
	wire reset = SW[0];

	wire source_valid;
	wire source_ready;
	wire [(COL_W + ROW_W + 1)-1:0] source_data;
	wire sink_valid;
	wire sink_ready;
	wire [(COL_W + ROW_W + 1)-1:0] sink_data;

	mesh_image_source #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H),
		.COL_W(COL_W),
		.ROW_W(ROW_W),
		.INIT_FILE(IMAGE_FILE)
	) image_source_inst (
		.clk(pclk),
		.reset(reset),
		.out_valid(source_valid),
		.out_ready(source_ready),
		.out_data(source_data)
	);

	mesh_grid_16x16 #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H),
		.COL_W(COL_W),
		.ROW_W(ROW_W)
	) mesh_grid_inst (
		.clk(pclk),
		.reset(reset),
		.source_valid(source_valid),
		.source_ready(source_ready),
		.source_data(source_data),
		.sink_valid(sink_valid),
		.sink_ready(sink_ready),
		.sink_data(sink_data)
	);

	mesh_vga_stream_display #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H),
		.SCALE(VGA_SCALE),
		.OFFSET_X(VGA_OFFSET_X),
		.OFFSET_Y(VGA_OFFSET_Y)
	) vga_stream_display_inst (
		.clock_50(CLOCK_50),
		.reset(reset),
		.in_valid(sink_valid),
		.in_ready(sink_ready),
		.in_data(sink_data),
		.pixel_clock(pclk),

		.VGA_R(VGA_R),
		.VGA_G(VGA_G),
		.VGA_B(VGA_B),
		.VGA_HS(VGA_HS),
		.VGA_VS(VGA_VS),
		.VGA_CLK(VGA_CLK),
		.VGA_BLANK_N(VGA_BLANK_N),
		.VGA_SYNC_N(VGA_SYNC_N)
	);

endmodule

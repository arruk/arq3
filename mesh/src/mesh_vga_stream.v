`timescale 1 ps / 1 ps

module mesh_vga_stream_display #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer COL_W = $clog2(IMG_W + 1),
	parameter integer ROW_W = $clog2(IMG_H + 1),
	parameter integer DATA_W = COL_W + ROW_W + 1,
	parameter integer SCALE = 2,
	parameter integer OFFSET_X = 64,
	parameter integer OFFSET_Y = 112
) (
	input clock_50,
	input reset,

	input in_valid,
	output in_ready,
	input [DATA_W-1:0] in_data,

	output pixel_clock,

	output [7:0] VGA_R,
	output [7:0] VGA_G,
	output [7:0] VGA_B,
	output VGA_HS,
	output VGA_VS,
	output VGA_CLK,
	output VGA_BLANK_N,
	output VGA_SYNC_N
);

	wire in_pixel;
	wire [ROW_W-1:0] in_row;
	wire [COL_W-1:0] in_column;
	assign {in_pixel, in_row, in_column} = in_data;

	localparam [COL_W-1:0] IMG_W_LIM = IMG_W[COL_W-1:0];
	localparam [ROW_W-1:0] IMG_H_LIM = IMG_H[ROW_W-1:0];

	wire in_bounds = (in_column < IMG_W_LIM) && (in_row < IMG_H_LIM);
	wire write_fire = in_valid && in_ready;
	wire write_enable = write_fire && in_bounds;

	assign in_ready = 1'b1;

	vga_display #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H),
		.SCALE(SCALE),
		.OFFSET_X(OFFSET_X),
		.OFFSET_Y(OFFSET_Y)
	) display_inst (
		.clock_50(clock_50),
		.reset(reset),
		.write_enable(write_enable),
		.write_column(in_column),
		.write_row(in_row),
		.write_pixel(in_pixel),
		.pixel_clock(pixel_clock),

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

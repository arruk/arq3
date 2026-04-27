`timescale 1 ps / 1 ps

module top (
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
	localparam integer IMG_W = 20;
	localparam integer IMG_H = 20;
	localparam integer VGA_SCALE = 16;
	localparam integer VGA_OFFSET_X = 80;
	localparam integer VGA_OFFSET_Y = 0;
	localparam integer GOL_DELAY_W = 9;
	localparam [GOL_DELAY_W-1:0] GOL_UPDATE_DELAY_FRAMES = 9'd60;

	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);

	wire pclk;
	wire reset = SW[0];

	wire vga_frame_tick;
	wire vga_update_valid;
	wire [COL_W-1:0] vga_update_column;
	wire [ROW_W-1:0] vga_update_row;
	wire vga_update_pixel;
	wire vga_update_ready;

	vga_display #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H),
		.SCALE(VGA_SCALE),
		.OFFSET_X(VGA_OFFSET_X),
		.OFFSET_Y(VGA_OFFSET_Y)
	) vga_display_inst (
		.clock_50(CLOCK_50),
		.reset(reset),
		.update_ready(vga_update_ready),
		.update_valid(vga_update_valid),
		.update_column(vga_update_column),
		.update_row(vga_update_row),
		.update_pixel(vga_update_pixel),
		.frame_tick(vga_frame_tick),
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


	gol_engine #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H),
		.DELAY_W(GOL_DELAY_W)
	) gol_engine_inst (
		.clk(pclk),
		.reset(reset),
		.update_delay_frames(GOL_UPDATE_DELAY_FRAMES),
		.vga_frame_tick(vga_frame_tick),
		.vga_update_ready(vga_update_ready),
		.vga_update_valid(vga_update_valid),
		.vga_update_column(vga_update_column),
		.vga_update_row(vga_update_row),
		.vga_update_pixel(vga_update_pixel),
		.vga_update_done()
	);

endmodule

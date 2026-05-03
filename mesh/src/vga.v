`timescale 1 ps / 1 ps


module vga_display #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer SCALE = 1,
	parameter integer OFFSET_X = 0,
	parameter integer OFFSET_Y = 0
) (
	input clock_50,
	input reset,
	input write_enable,
	input [($clog2(IMG_W + 1))-1:0] write_column,
	input [($clog2(IMG_H + 1))-1:0] write_row,
	input write_pixel,
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
	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);
	localparam integer DISPLAY_W = IMG_W * SCALE;
	localparam integer DISPLAY_H = IMG_H * SCALE;

	localparam integer DISPLAY_RIGHT_INT = (DISPLAY_W + OFFSET_X);
	localparam [9:0]   DISPLAY_RIGHT = DISPLAY_RIGHT_INT[9:0];
	localparam [9:0]   DISPLAY_LEFT  = OFFSET_X[9:0];

	localparam integer DISPLAY_BOTTOM_INT = (DISPLAY_H + OFFSET_Y);
	localparam [9:0] DISPLAY_BOTTOM = DISPLAY_BOTTOM_INT[9:0];
	localparam [9:0] DISPLAY_TOP    = OFFSET_Y[9:0];

	localparam integer CLOG_SCALE = $clog2(SCALE);

	wire [9:0] pixel_row;
	wire [9:0] pixel_column;
	wire on;
	wire pclk;
	wire red_out;
	wire green_out;
	wire blue_out;

	VGA_SYNC vga_sync_inst (
		.clock_50Mhz    (clock_50),
		.reset          (reset),
		.red            (display_in_bounds ? display_pixel : 1'b0),
		.green          (display_in_bounds ? display_pixel : 1'b0),
		.blue           (display_in_bounds ? display_pixel : 1'b0),
		.red_out        (red_out),
		.green_out      (green_out),
		.blue_out       (blue_out),
		.horiz_sync_out (VGA_HS),
		.vert_sync_out  (VGA_VS),
		.video_on       (on),
		.pixel_clock    (pclk),
		.pixel_row      (pixel_row),
		.pixel_column   (pixel_column)
	);

	wire display_fb_pixel;
	wire display_in_bounds = on && (pixel_column >= DISPLAY_LEFT) && (pixel_column < DISPLAY_RIGHT) && (pixel_row >= DISPLAY_TOP) && (pixel_row < DISPLAY_BOTTOM);

	wire [9:0] scaled_column = (pixel_column - DISPLAY_LEFT) >> CLOG_SCALE;
	wire [9:0] scaled_row    = (pixel_row - DISPLAY_TOP) >> CLOG_SCALE;
	wire [COL_W-1:0] framebuffer_read_column = scaled_column[COL_W-1:0];
	wire [ROW_W-1:0] framebuffer_read_row = scaled_row[ROW_W-1:0];
	wire display_pixel = display_fb_pixel;

	double_framebuffer #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) framebuffer_inst (
		.clk   (pclk),
		.reset (reset),
		.read_bank(1'b0),
		.write_bank(1'b0),

		.display_read_enable (display_in_bounds),
		.display_read_column (framebuffer_read_column),
		.display_read_row    (framebuffer_read_row),
		.display_read_pixel  (display_fb_pixel),

		.compute_read_enable (1'b0),
		.compute_read_column ({COL_W{1'b0}}),
		.compute_read_row    ({ROW_W{1'b0}}),
		.compute_read_pixel  (),

		.write_enable (write_enable),
		.write_column (write_column),
		.write_row    (write_row),
		.write_pixel  (write_pixel)
	);

	assign VGA_R = {8{red_out}};
	assign VGA_G = {8{green_out}};
	assign VGA_B = {8{blue_out}};
	assign VGA_CLK = pclk;
	assign VGA_BLANK_N = on;
	assign VGA_SYNC_N = 1'b0;
	
	assign pixel_clock = pclk;

endmodule

module vga_framebuffer #(
	parameter integer IMG_W = 640,
	parameter integer IMG_H = 480
) (
	input clk,
	input reset,

	input read_enable,
	input [($clog2(IMG_W + 1))-1:0] read_column,
	input [($clog2(IMG_H + 1))-1:0] read_row,
	output read_pixel,

	input write_enable,
	input [($clog2(IMG_W + 1))-1:0] write_column,
	input [($clog2(IMG_H + 1))-1:0] write_row,
	input write_pixel
);
	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);
	localparam integer COL_INDEX_W = $clog2(IMG_W);
	localparam integer ROW_INDEX_W = $clog2(IMG_H);
	localparam integer FRAME_SIZE = IMG_W * IMG_H;
	localparam integer ADDR_W = $clog2(FRAME_SIZE);

	localparam [COL_W-1:0] IMG_W_LIM = IMG_W[COL_W-1:0];
	localparam [ROW_W-1:0] IMG_H_LIM = IMG_H[ROW_W-1:0];

	wire read_in_bounds = read_enable && (read_column < IMG_W_LIM) && (read_row < IMG_H_LIM);
	wire write_in_bounds = write_enable && (write_column < IMG_W_LIM) && (write_row < IMG_H_LIM);
	wire [ADDR_W-1:0] read_addr = address(read_column[COL_INDEX_W-1:0], read_row[ROW_INDEX_W-1:0]);
	wire [ADDR_W-1:0] write_addr = address(write_column[COL_INDEX_W-1:0], write_row[ROW_INDEX_W-1:0]);
	wire memory_read_pixel;

	simple_dual_port_ram #(
		.ADDR_W(ADDR_W),
		.DATA_W(1),
		.DEPTH(FRAME_SIZE)
	) fb_memory (
		.clk(clk),

		.write_enable (write_in_bounds),
		.write_addr   (write_addr),
		.write_data   (write_pixel),

		.read_enable (read_in_bounds),
		.read_addr   (read_addr),
		.read_data   (memory_read_pixel)
	);

	reg read_in_bounds_q = 1'b0;

	always @(posedge clk) begin
		if (reset) begin
			read_in_bounds_q <= 1'b0;
		end else begin
			read_in_bounds_q <= read_in_bounds;
		end
	end

	assign read_pixel = read_in_bounds_q ? memory_read_pixel : 1'b0;

	function [ADDR_W-1:0] address;
		input [COL_INDEX_W-1:0] column;
		input [ROW_INDEX_W-1:0] row;
		reg [31:0] column_ext;
		reg [31:0] row_ext;
		reg [31:0] linear_address;
		begin
			column_ext = {{(32-COL_INDEX_W){1'b0}}, column};
			row_ext = {{(32-ROW_INDEX_W){1'b0}}, row};
			linear_address = (row_ext * IMG_W) + column_ext;
			address = linear_address[ADDR_W-1:0];
		end
	endfunction

endmodule

`timescale 1 ps / 1 ps

module VGA_SYNC (
	input clock_50Mhz,
	input reset,
	input red,
	input green,
	input blue,
	output red_out,
	output green_out,
	output blue_out,
	output horiz_sync_out,
	output vert_sync_out,
	output video_on,
	output pixel_clock,
	output [9:0] pixel_row,
	output [9:0] pixel_column
);

	assign red_out = red;
	assign green_out = green;
	assign blue_out = blue;
	assign horiz_sync_out = 1'b1;
	assign vert_sync_out = 1'b1;
	assign video_on = !reset;
	assign pixel_clock = clock_50Mhz;
	assign pixel_row = 10'd0;
	assign pixel_column = 10'd0;

endmodule

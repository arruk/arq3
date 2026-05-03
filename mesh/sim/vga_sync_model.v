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
	localparam integer H_VISIBLE = 640;
	localparam integer H_SYNC_LOW = 664;
	localparam integer H_SYNC_HIGH = 760;
	localparam integer H_TOTAL = 800;
	localparam [9:0] H_VISIBLE_C = 10'd640;
	localparam [9:0] H_SYNC_LOW_C = 10'd664;
	localparam [9:0] H_SYNC_HIGH_C = 10'd760;
	localparam [9:0] H_LAST = 10'd799;

	localparam integer V_VISIBLE = 480;
	localparam integer V_SYNC_LOW = 491;
	localparam integer V_SYNC_HIGH = 493;
	localparam integer V_TOTAL = 525;
	localparam [9:0] V_VISIBLE_C = 10'd480;
	localparam [9:0] V_SYNC_LOW_C = 10'd491;
	localparam [9:0] V_SYNC_HIGH_C = 10'd493;
	localparam [9:0] V_LAST = 10'd524;

	reg [9:0] h_count = H_LAST;
	reg [9:0] v_count = V_LAST;

	assign pixel_clock = clock_50Mhz;
	assign pixel_column = h_count;
	assign pixel_row = v_count;

	assign video_on = (h_count < H_VISIBLE_C) && (v_count < V_VISIBLE_C);
	assign horiz_sync_out = !((h_count >= H_SYNC_LOW_C) && (h_count < H_SYNC_HIGH_C));
	assign vert_sync_out = !((v_count >= V_SYNC_LOW_C) && (v_count < V_SYNC_HIGH_C));

	assign red_out = red && video_on;
	assign green_out = green && video_on;
	assign blue_out = blue && video_on;

	always @(posedge clock_50Mhz) begin
		if (reset) begin
			h_count <= H_LAST;
			v_count <= V_LAST;
		end else if (h_count == H_LAST) begin
			h_count <= 10'd0;
			if (v_count == V_LAST) begin
				v_count <= 10'd0;
			end else begin
				v_count <= v_count + 10'd1;
			end
		end else begin
			h_count <= h_count + 10'd1;
		end
	end
endmodule

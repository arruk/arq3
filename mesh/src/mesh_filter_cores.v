`timescale 1 ps / 1 ps

module mesh_majority_core #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer COL_W = $clog2(IMG_W + 1),
	parameter integer ROW_W = $clog2(IMG_H + 1),
	parameter integer DEST_X_W = 4,
	parameter integer DEST_Y_W = 4,
	parameter integer PKT_W = COL_W + ROW_W + DEST_X_W + DEST_Y_W + 2,
	parameter integer OUT_DEST_X = 0,
	parameter integer OUT_DEST_Y = 0,
	parameter integer OUTPUT_FIFO_DEPTH = 16,
	parameter integer PIPELINE_GUARD = 8,
	parameter integer OUTPUT_FIFO_COUNT_W = (OUTPUT_FIFO_DEPTH <= 1) ? 1 : $clog2(OUTPUT_FIFO_DEPTH + 1)
) (
	input clk,
	input reset,

	input in_valid,
	output in_ready,
	input [PKT_W-1:0] in_pkt,

	output out_valid,
	input out_ready,
	output [PKT_W-1:0] out_pkt
);

	localparam [31:0] OUT_DEST_X_32 = OUT_DEST_X;
	localparam [31:0] OUT_DEST_Y_32 = OUT_DEST_Y;
	localparam integer OUTPUT_FIFO_SAFE_LIMIT = (OUTPUT_FIFO_DEPTH > PIPELINE_GUARD) ? (OUTPUT_FIFO_DEPTH - PIPELINE_GUARD) : 0;

	wire [DEST_X_W-1:0] out_dest_x = OUT_DEST_X_32[DEST_X_W-1:0];
	wire [DEST_Y_W-1:0] out_dest_y = OUT_DEST_Y_32[DEST_Y_W-1:0];

	function [PKT_W-1:0] pack_packet;
		input [COL_W-1:0] column;
		input [ROW_W-1:0] row;
		input pixel;
		input [DEST_X_W-1:0] dest_x;
		input [DEST_Y_W-1:0] dest_y;
		input packet_valid;
		begin
			pack_packet = {packet_valid, dest_y, dest_x, pixel, row, column};
		end
	endfunction

	wire [COL_W-1:0] in_column;
	wire [ROW_W-1:0] in_row;
	wire in_pixel;
	wire [DEST_X_W-1:0] in_dest_x;
	wire [DEST_Y_W-1:0] in_dest_y;
	wire in_packet_valid;
	assign {in_packet_valid, in_dest_y, in_dest_x, in_pixel, in_row, in_column} = in_pkt;

	wire [OUTPUT_FIFO_COUNT_W-1:0] output_fifo_fill_count;
	wire [31:0] output_fifo_fill_ext = {{(32-OUTPUT_FIFO_COUNT_W){1'b0}}, output_fifo_fill_count};
	wire output_has_space = output_fifo_fill_ext < OUTPUT_FIFO_SAFE_LIMIT;
	assign in_ready = !in_packet_valid || output_has_space;

	wire input_fire = in_valid && in_ready && in_packet_valid;

	wire [2:0] win_w_col0;
	wire [2:0] win_w_col1;
	wire [2:0] win_w_col2;
	wire [COL_W-1:0] win_center_column;
	wire [ROW_W-1:0] win_center_row;
	wire win_center_valid;
	wire win_window_valid;
	wire win_border;

	window_stream #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) window_inst (
		.clk(clk),
		.reset(reset),
		.pixel_in(in_pixel),
		.column_in(in_column),
		.row_in(in_row),
		.valid_in(input_fire),
		.w_col0(win_w_col0),
		.w_col1(win_w_col1),
		.w_col2(win_w_col2),
		.center_column(win_center_column),
		.center_row(win_center_row),
		.center_valid(win_center_valid),
		.window_valid(win_window_valid),
		.border(win_border)
	);

	wire filtered_pixel;

	majority majority_inst (
		.w_col0(win_w_col0),
		.w_col1(win_w_col1),
		.w_col2(win_w_col2),
		.center_valid(win_center_valid),
		.window_valid(win_window_valid),
		.border(win_border),
		.pixel_out(filtered_pixel)
	);

	wire output_fifo_in_ready;
	wire [PKT_W-1:0] output_fifo_in_pkt;
	assign output_fifo_in_pkt = pack_packet(win_center_column, win_center_row, filtered_pixel, out_dest_x, out_dest_y, 1'b1);

	stream_fifo #(
		.DATA_W(PKT_W),
		.DEPTH(OUTPUT_FIFO_DEPTH),
		.FIFO_COUNT_W(OUTPUT_FIFO_COUNT_W)
	) output_fifo (
		.clk(clk),
		.reset(reset),
		.in_valid(win_center_valid),
		.in_ready(output_fifo_in_ready),
		.in_data(output_fifo_in_pkt),
		.out_valid(out_valid),
		.out_ready(out_ready),
		.out_data(out_pkt),
		.fill_count(output_fifo_fill_count)
	);

endmodule

module mesh_vga_sink_core #(
	parameter integer COL_W = 10,
	parameter integer ROW_W = 10,
	parameter integer DEST_X_W = 4,
	parameter integer DEST_Y_W = 4,
	parameter integer PKT_W = COL_W + ROW_W + DEST_X_W + DEST_Y_W + 2,
	parameter integer SINK_DATA_W = COL_W + ROW_W + 1
) (
	input in_valid,
	output in_ready,
	input [PKT_W-1:0] in_pkt,

	output out_valid,
	input out_ready,
	output [PKT_W-1:0] out_pkt,

	output sink_valid,
	input sink_ready,
	output [SINK_DATA_W-1:0] sink_data
);

	wire [COL_W-1:0] in_column;
	wire [ROW_W-1:0] in_row;
	wire in_pixel;
	wire [DEST_X_W-1:0] in_dest_x;
	wire [DEST_Y_W-1:0] in_dest_y;
	wire in_packet_valid;
	assign {in_packet_valid, in_dest_y, in_dest_x, in_pixel, in_row, in_column} = in_pkt;

	assign sink_valid = in_valid && in_packet_valid;
	assign sink_data = {in_pixel, in_row, in_column};
	assign in_ready = !in_packet_valid || sink_ready;

	assign out_valid = 1'b0;
	assign out_pkt = {PKT_W{1'b0}};

endmodule

module mesh_sobel_core #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer COL_W = $clog2(IMG_W + 1),
	parameter integer ROW_W = $clog2(IMG_H + 1),
	parameter integer DEST_X_W = 4,
	parameter integer DEST_Y_W = 4,
	parameter integer PKT_W = COL_W + ROW_W + DEST_X_W + DEST_Y_W + 2,
	parameter integer OUT_DEST_X = 0,
	parameter integer OUT_DEST_Y = 0,
	parameter [4:0] THRESHOLD = 5'd2,
	parameter integer OUTPUT_FIFO_DEPTH = 16,
	parameter integer PIPELINE_GUARD = 8,
	parameter integer OUTPUT_FIFO_COUNT_W = (OUTPUT_FIFO_DEPTH <= 1) ? 1 : $clog2(OUTPUT_FIFO_DEPTH + 1)
) (
	input clk,
	input reset,

	input in_valid,
	output in_ready,
	input [PKT_W-1:0] in_pkt,

	output out_valid,
	input out_ready,
	output [PKT_W-1:0] out_pkt
);

	localparam [31:0] OUT_DEST_X_32 = OUT_DEST_X;
	localparam [31:0] OUT_DEST_Y_32 = OUT_DEST_Y;
	localparam integer OUTPUT_FIFO_SAFE_LIMIT = (OUTPUT_FIFO_DEPTH > PIPELINE_GUARD) ? (OUTPUT_FIFO_DEPTH - PIPELINE_GUARD) : 0;

	wire [DEST_X_W-1:0] out_dest_x = OUT_DEST_X_32[DEST_X_W-1:0];
	wire [DEST_Y_W-1:0] out_dest_y = OUT_DEST_Y_32[DEST_Y_W-1:0];

	function [PKT_W-1:0] pack_packet;
		input [COL_W-1:0] column;
		input [ROW_W-1:0] row;
		input pixel;
		input [DEST_X_W-1:0] dest_x;
		input [DEST_Y_W-1:0] dest_y;
		input packet_valid;
		begin
			pack_packet = {packet_valid, dest_y, dest_x, pixel, row, column};
		end
	endfunction

	wire [COL_W-1:0] in_column;
	wire [ROW_W-1:0] in_row;
	wire in_pixel;
	wire [DEST_X_W-1:0] in_dest_x;
	wire [DEST_Y_W-1:0] in_dest_y;
	wire in_packet_valid;
	assign {in_packet_valid, in_dest_y, in_dest_x, in_pixel, in_row, in_column} = in_pkt;

	wire [OUTPUT_FIFO_COUNT_W-1:0] output_fifo_fill_count;
	wire [31:0] output_fifo_fill_ext = {{(32-OUTPUT_FIFO_COUNT_W){1'b0}}, output_fifo_fill_count};
	wire output_has_space = output_fifo_fill_ext < OUTPUT_FIFO_SAFE_LIMIT;
	assign in_ready = !in_packet_valid || output_has_space;

	wire input_fire = in_valid && in_ready && in_packet_valid;

	wire [2:0] win_w_col0;
	wire [2:0] win_w_col1;
	wire [2:0] win_w_col2;
	wire [COL_W-1:0] win_center_column;
	wire [ROW_W-1:0] win_center_row;
	wire win_center_valid;
	wire win_window_valid;
	wire win_border;

	window_stream #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) window_inst (
		.clk(clk),
		.reset(reset),
		.pixel_in(in_pixel),
		.column_in(in_column),
		.row_in(in_row),
		.valid_in(input_fire),
		.w_col0(win_w_col0),
		.w_col1(win_w_col1),
		.w_col2(win_w_col2),
		.center_column(win_center_column),
		.center_row(win_center_row),
		.center_valid(win_center_valid),
		.window_valid(win_window_valid),
		.border(win_border)
	);

	wire filtered_pixel;

	sobel #(
		.THRESHOLD(THRESHOLD)
	) sobel_inst (
		.w_col0(win_w_col0),
		.w_col1(win_w_col1),
		.w_col2(win_w_col2),
		.center_valid(win_center_valid),
		.window_valid(win_window_valid),
		.border(win_border),
		.pixel_out(filtered_pixel)
	);

	wire output_fifo_in_ready;
	wire [PKT_W-1:0] output_fifo_in_pkt;
	assign output_fifo_in_pkt = pack_packet(win_center_column, win_center_row, filtered_pixel, out_dest_x, out_dest_y, 1'b1);

	stream_fifo #(
		.DATA_W(PKT_W),
		.DEPTH(OUTPUT_FIFO_DEPTH),
		.FIFO_COUNT_W(OUTPUT_FIFO_COUNT_W)
	) output_fifo (
		.clk(clk),
		.reset(reset),
		.in_valid(win_center_valid),
		.in_ready(output_fifo_in_ready),
		.in_data(output_fifo_in_pkt),
		.out_valid(out_valid),
		.out_ready(out_ready),
		.out_data(out_pkt),
		.fill_count(output_fifo_fill_count)
	);

endmodule

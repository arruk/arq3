`timescale 1 ps / 1 ps

module mesh_core #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer COL_W = 10,
	parameter integer ROW_W = 10,
	parameter integer DEST_X_W = 4,
	parameter integer DEST_Y_W = 4,
	parameter integer PKT_W = COL_W + ROW_W + DEST_X_W + DEST_Y_W + 2,
	parameter integer FIFO_DEPTH = 2,
	parameter integer CORE_OUTPUT_FIFO_DEPTH = 16,
	parameter [4:0] CORE_SOBEL_THRESHOLD = 5'd2,
	parameter integer MAJORITY_X = 1,
	parameter integer MAJORITY_Y = 1,
	parameter integer SOBEL_X = 2,
	parameter integer SOBEL_Y = 2,
	parameter integer SINK_X = 15,
	parameter integer SINK_Y = 15,
	parameter integer X_ID = 0,
	parameter integer Y_ID = 0
) (
	input clk,
	input reset,

	input north_in_valid,
	output north_in_ready,
	input [PKT_W-1:0] north_in_pkt,
	
	output north_out_valid,
	input north_out_ready,
	output [PKT_W-1:0] north_out_pkt,

	input south_in_valid,
	output south_in_ready,
	input [PKT_W-1:0] south_in_pkt,
	
	output south_out_valid,
	input south_out_ready,
	output [PKT_W-1:0] south_out_pkt,

	input west_in_valid,
	output west_in_ready,
	input [PKT_W-1:0] west_in_pkt,
	
	output west_out_valid,
	input west_out_ready,
	output [PKT_W-1:0] west_out_pkt,

	input east_in_valid,
	output east_in_ready,
	input [PKT_W-1:0] east_in_pkt,
	
	output east_out_valid,
	input east_out_ready,
	output [PKT_W-1:0] east_out_pkt

);

	localparam [2:0] DIR_NORTH = 3'd0;
	localparam [2:0] DIR_SOUTH = 3'd1;
	localparam [2:0] DIR_WEST = 3'd2;
	localparam [2:0] DIR_EAST = 3'd3;
	localparam [2:0] DIR_LOCAL = 3'd4;
	localparam integer MESH_FIFO_COUNT_W = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH + 1);

	wire north_arb_valid;
	wire north_arb_ready;
	wire [PKT_W-1:0] north_arb_pkt;
	wire [MESH_FIFO_COUNT_W-1:0] north_fifo_fill_count;

	stream_fifo #(
		.DATA_W(PKT_W),
		.DEPTH(FIFO_DEPTH),
		.FIFO_COUNT_W(MESH_FIFO_COUNT_W)
	) north_in_fifo (
		.clk(clk),
		.reset(reset),
		.in_valid(north_in_valid),
		.in_ready(north_in_ready),
		.in_data(north_in_pkt),
		.out_valid(north_arb_valid),
		.out_ready(north_arb_ready),
		.out_data(north_arb_pkt),
		.fill_count(north_fifo_fill_count)
	);

	wire south_arb_valid;
	wire south_arb_ready;
	wire [PKT_W-1:0] south_arb_pkt;
	wire [MESH_FIFO_COUNT_W-1:0] south_fifo_fill_count;

	stream_fifo #(
		.DATA_W(PKT_W),
		.DEPTH(FIFO_DEPTH),
		.FIFO_COUNT_W(MESH_FIFO_COUNT_W)
	) south_in_fifo (
		.clk(clk),
		.reset(reset),
		.in_valid(south_in_valid),
		.in_ready(south_in_ready),
		.in_data(south_in_pkt),
		.out_valid(south_arb_valid),
		.out_ready(south_arb_ready),
		.out_data(south_arb_pkt),
		.fill_count(south_fifo_fill_count)
	);

	wire west_arb_valid;
	wire west_arb_ready;
	wire [PKT_W-1:0] west_arb_pkt;
	wire [MESH_FIFO_COUNT_W-1:0] west_fifo_fill_count;

	stream_fifo #(
		.DATA_W(PKT_W),
		.DEPTH(FIFO_DEPTH),
		.FIFO_COUNT_W(MESH_FIFO_COUNT_W)
	) west_in_fifo (
		.clk(clk),
		.reset(reset),
		.in_valid(west_in_valid),
		.in_ready(west_in_ready),
		.in_data(west_in_pkt),
		.out_valid(west_arb_valid),
		.out_ready(west_arb_ready),
		.out_data(west_arb_pkt),
		.fill_count(west_fifo_fill_count)
	);

	wire east_arb_valid;
	wire east_arb_ready;
	wire [PKT_W-1:0] east_arb_pkt;
	wire [MESH_FIFO_COUNT_W-1:0] east_fifo_fill_count;

	stream_fifo #(
		.DATA_W(PKT_W),
		.DEPTH(FIFO_DEPTH),
		.FIFO_COUNT_W(MESH_FIFO_COUNT_W)
	) east_in_fifo (
		.clk(clk),
		.reset(reset),
		.in_valid(east_in_valid),
		.in_ready(east_in_ready),
		.in_data(east_in_pkt),
		.out_valid(east_arb_valid),
		.out_ready(east_arb_ready),
		.out_data(east_arb_pkt),
		.fill_count(east_fifo_fill_count)
	);

	wire [COL_W-1:0] north_in_column;
	wire [ROW_W-1:0] north_in_row;
	wire north_in_pixel;
	wire [DEST_X_W-1:0] north_in_dest_x;
	wire [DEST_Y_W-1:0] north_in_dest_y;
	wire north_in_packet_valid;
	wire [2:0] north_in_route;
	assign {north_in_packet_valid, north_in_dest_y, north_in_dest_x, north_in_pixel, north_in_row, north_in_column} = north_arb_pkt;
	assign north_in_route = route_xy(north_in_dest_x, north_in_dest_y);

	wire [COL_W-1:0] south_in_column;
	wire [ROW_W-1:0] south_in_row;
	wire south_in_pixel;
	wire [DEST_X_W-1:0] south_in_dest_x;
	wire [DEST_Y_W-1:0] south_in_dest_y;
	wire south_in_packet_valid;
	wire [2:0] south_in_route;
	assign {south_in_packet_valid, south_in_dest_y, south_in_dest_x, south_in_pixel, south_in_row, south_in_column} = south_arb_pkt;
	assign south_in_route = route_xy(south_in_dest_x, south_in_dest_y);

	wire [COL_W-1:0] west_in_column;
	wire [ROW_W-1:0] west_in_row;
	wire west_in_pixel;
	wire [DEST_X_W-1:0] west_in_dest_x;
	wire [DEST_Y_W-1:0] west_in_dest_y;
	wire west_in_packet_valid;
	wire [2:0] west_in_route;
	assign {west_in_packet_valid, west_in_dest_y, west_in_dest_x, west_in_pixel, west_in_row, west_in_column} = west_arb_pkt;
	assign west_in_route = route_xy(west_in_dest_x, west_in_dest_y);

	wire [COL_W-1:0] east_in_column;
	wire [ROW_W-1:0] east_in_row;
	wire east_in_pixel;
	wire [DEST_X_W-1:0] east_in_dest_x;
	wire [DEST_Y_W-1:0] east_in_dest_y;
	wire east_in_packet_valid;
	wire [2:0] east_in_route;
	assign {east_in_packet_valid, east_in_dest_y, east_in_dest_x, east_in_pixel, east_in_row, east_in_column} = east_arb_pkt;
	assign east_in_route = route_xy(east_in_dest_x, east_in_dest_y);

	wire local_fifo_in_valid;
	wire local_fifo_in_ready;
	wire [PKT_W-1:0] local_fifo_in_pkt;
	wire [MESH_FIFO_COUNT_W-1:0] local_fifo_fill_count;

	wire local_in_valid;
	wire local_in_ready;
	wire [PKT_W-1:0] local_in_pkt;

	stream_fifo #(
		.DATA_W(PKT_W),
		.DEPTH(FIFO_DEPTH),
		.FIFO_COUNT_W(MESH_FIFO_COUNT_W)
	) local_in_fifo (
		.clk(clk),
		.reset(reset),
		.in_valid(local_fifo_in_valid),
		.in_ready(local_fifo_in_ready),
		.in_data(local_fifo_in_pkt),
		.out_valid(local_in_valid),
		.out_ready(local_in_ready),
		.out_data(local_in_pkt),
		.fill_count(local_fifo_fill_count)
	);

	generate
		if ((X_ID == MAJORITY_X) && (Y_ID == MAJORITY_Y)) begin : majority_core_gen
			mesh_majority_core #(
				.IMG_W(IMG_W),
				.IMG_H(IMG_H),
				.COL_W(COL_W),
				.ROW_W(ROW_W),
				.DEST_X_W(DEST_X_W),
				.DEST_Y_W(DEST_Y_W),
				.PKT_W(PKT_W),
				.OUT_DEST_X(SOBEL_X),
				.OUT_DEST_Y(SOBEL_Y),
				.OUTPUT_FIFO_DEPTH(CORE_OUTPUT_FIFO_DEPTH)
			) core_inst (
				.clk(clk),
				.reset(reset),
				.in_valid(local_in_valid),
				.in_ready(local_in_ready),
				.in_pkt(local_in_pkt),
				.out_valid(local_out_valid),
				.out_ready(local_out_ready),
				.out_pkt(local_out_pkt)
			);
		end else if ((X_ID == SOBEL_X) && (Y_ID == SOBEL_Y)) begin : sobel_core_gen
			mesh_sobel_core #(
				.IMG_W(IMG_W),
				.IMG_H(IMG_H),
				.COL_W(COL_W),
				.ROW_W(ROW_W),
				.DEST_X_W(DEST_X_W),
				.DEST_Y_W(DEST_Y_W),
				.PKT_W(PKT_W),
				.OUT_DEST_X(SINK_X),
				.OUT_DEST_Y(SINK_Y),
				.THRESHOLD(CORE_SOBEL_THRESHOLD),
				.OUTPUT_FIFO_DEPTH(CORE_OUTPUT_FIFO_DEPTH)
			) core_inst (
				.clk(clk),
				.reset(reset),
				.in_valid(local_in_valid),
				.in_ready(local_in_ready),
				.in_pkt(local_in_pkt),
				.out_valid(local_out_valid),
				.out_ready(local_out_ready),
				.out_pkt(local_out_pkt)
			);
		end else begin : off_core_gen
			mesh_node_core #(
				.PKT_W(PKT_W)
			) core_inst (
				.in_valid(local_in_valid),
				.in_ready(local_in_ready),
				.in_pkt(local_in_pkt),
				.out_valid(local_out_valid),
				.out_ready(local_out_ready),
				.out_pkt(local_out_pkt)
			);
		end
	endgenerate

	wire local_out_valid;
	wire local_out_ready;
	wire [PKT_W-1:0] local_out_pkt;

	wire local_out_arb_valid;
	wire local_out_arb_ready;
	wire [PKT_W-1:0] local_out_arb_pkt;
	wire [MESH_FIFO_COUNT_W-1:0] local_out_fifo_fill_count;

	stream_fifo #(
		.DATA_W(PKT_W),
		.DEPTH(FIFO_DEPTH),
		.FIFO_COUNT_W(MESH_FIFO_COUNT_W)
	) local_out_fifo (
		.clk(clk),
		.reset(reset),
		.in_valid(local_out_valid),
		.in_ready(local_out_ready),
		.in_data(local_out_pkt),
		.out_valid(local_out_arb_valid),
		.out_ready(local_out_arb_ready),
		.out_data(local_out_arb_pkt),
		.fill_count(local_out_fifo_fill_count)
	);

	wire [COL_W-1:0] local_out_column;
	wire [ROW_W-1:0] local_out_row;
	wire local_out_pixel;
	wire [DEST_X_W-1:0] local_out_dest_x;
	wire [DEST_Y_W-1:0] local_out_dest_y;
	wire local_out_packet_valid;
	wire [2:0] local_out_route;
	assign {local_out_packet_valid, local_out_dest_y, local_out_dest_x, local_out_pixel, local_out_row, local_out_column} = local_out_arb_pkt;
	assign local_out_route = route_xy(local_out_dest_x, local_out_dest_y);

	mesh_arbiter #(
		.PKT_W(PKT_W)
	) arbiter_inst (
		.north_in_valid(north_arb_valid && north_in_packet_valid),
		.north_in_route(north_in_route),
		.north_in_pkt(north_arb_pkt),
		.north_in_ready(north_arb_ready),

		.south_in_valid(south_arb_valid && south_in_packet_valid),
		.south_in_route(south_in_route),
		.south_in_pkt(south_arb_pkt),
		.south_in_ready(south_arb_ready),

		.west_in_valid(west_arb_valid && west_in_packet_valid),
		.west_in_route(west_in_route),
		.west_in_pkt(west_arb_pkt),
		.west_in_ready(west_arb_ready),

		.east_in_valid(east_arb_valid && east_in_packet_valid),
		.east_in_route(east_in_route),
		.east_in_pkt(east_arb_pkt),
		.east_in_ready(east_arb_ready),

		.local_in_valid(local_out_arb_valid && local_out_packet_valid),
		.local_in_route(local_out_route),
		.local_in_pkt(local_out_arb_pkt),
		.local_in_ready(local_out_arb_ready),

		.north_out_valid(north_out_valid),
		.north_out_ready(north_out_ready),
		.north_out_pkt(north_out_pkt),

		.south_out_valid(south_out_valid),
		.south_out_ready(south_out_ready),
		.south_out_pkt(south_out_pkt),

		.west_out_valid(west_out_valid),
		.west_out_ready(west_out_ready),
		.west_out_pkt(west_out_pkt),

		.east_out_valid(east_out_valid),
		.east_out_ready(east_out_ready),
		.east_out_pkt(east_out_pkt),

		.local_out_valid(local_fifo_in_valid),
		.local_out_ready(local_fifo_in_ready),
		.local_out_pkt(local_fifo_in_pkt)
	);

	wire [COL_W-1:0] north_out_column;
	wire [ROW_W-1:0] north_out_row;
	wire north_out_pixel;
	wire [DEST_X_W-1:0] north_out_dest_x;
	wire [DEST_Y_W-1:0] north_out_dest_y;
	wire north_out_packet_valid;
	assign {north_out_packet_valid, north_out_dest_y, north_out_dest_x, north_out_pixel, north_out_row, north_out_column} = north_out_pkt;

	wire [COL_W-1:0] south_out_column;
	wire [ROW_W-1:0] south_out_row;
	wire south_out_pixel;
	wire [DEST_X_W-1:0] south_out_dest_x;
	wire [DEST_Y_W-1:0] south_out_dest_y;
	wire south_out_packet_valid;
	assign {south_out_packet_valid, south_out_dest_y, south_out_dest_x, south_out_pixel, south_out_row, south_out_column} = south_out_pkt;

	wire [COL_W-1:0] west_out_column;
	wire [ROW_W-1:0] west_out_row;
	wire west_out_pixel;
	wire [DEST_X_W-1:0] west_out_dest_x;
	wire [DEST_Y_W-1:0] west_out_dest_y;
	wire west_out_packet_valid;
	assign {west_out_packet_valid, west_out_dest_y, west_out_dest_x, west_out_pixel, west_out_row, west_out_column} = west_out_pkt;

	wire [COL_W-1:0] east_out_column;
	wire [ROW_W-1:0] east_out_row;
	wire east_out_pixel;
	wire [DEST_X_W-1:0] east_out_dest_x;
	wire [DEST_Y_W-1:0] east_out_dest_y;
	wire east_out_packet_valid;
	assign {east_out_packet_valid, east_out_dest_y, east_out_dest_x, east_out_pixel, east_out_row, east_out_column} = east_out_pkt;

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

	function [2:0] route_xy;
		input [DEST_X_W-1:0] dest_x;
		input [DEST_Y_W-1:0] dest_y;
		integer dest_x_int;
		integer dest_y_int;
		begin
			dest_x_int = {{(32-DEST_X_W){1'b0}}, dest_x};
			dest_y_int = {{(32-DEST_Y_W){1'b0}}, dest_y};

			if (dest_x_int > X_ID) begin
				route_xy = DIR_EAST;
			end else if (dest_x_int < X_ID) begin
				route_xy = DIR_WEST;
			end else if (dest_y_int > Y_ID) begin
				route_xy = DIR_SOUTH;
			end else if (dest_y_int < Y_ID) begin
				route_xy = DIR_NORTH;
			end else if ((X_ID == SINK_X) && (Y_ID == SINK_Y)) begin
				route_xy = DIR_EAST;
			end else begin
				route_xy = DIR_LOCAL;
			end
		end
	endfunction

endmodule

module stream_fifo #(
	parameter integer DATA_W = 1,
	parameter integer DEPTH = 2,
	parameter integer FIFO_COUNT_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1)
) (
	input clk,
	input reset,

	input in_valid,
	output in_ready,
	input [DATA_W-1:0] in_data,

	output out_valid,
	input out_ready,
	output [DATA_W-1:0] out_data,
	output [FIFO_COUNT_W-1:0] fill_count
);

	wire [DEPTH:0] valid_bus;
	wire [DEPTH:0] ready_bus;
	wire [((DEPTH + 1) * DATA_W)-1:0] data_bus;
	reg [FIFO_COUNT_W-1:0] count;

	assign valid_bus[0] = in_valid;
	assign in_ready = ready_bus[0];
	assign data_bus[DATA_W-1:0] = in_data;

	assign out_valid = valid_bus[DEPTH];
	assign ready_bus[DEPTH] = out_ready;
	assign out_data = data_bus[(DEPTH*DATA_W) +: DATA_W];
	assign fill_count = count;

	wire push = in_valid && in_ready;
	wire pop = out_valid && out_ready;

	always @(posedge clk) begin
		if (reset) begin
			count <= {FIFO_COUNT_W{1'b0}};
		end else begin
			case ({push, pop})
				2'b10: count <= count + 1'b1;
				2'b01: count <= count - 1'b1;
				default: count <= count;
			endcase
		end
	end

	genvar i;
	generate
		for (i = 0; i < DEPTH; i = i + 1) begin : fifo_stage
			stream_fifo_stage #(
				.DATA_W(DATA_W)
			) stage_inst (
				.clk(clk),
				.reset(reset),
				.in_valid(valid_bus[i]),
				.in_ready(ready_bus[i]),
				.in_data(data_bus[(i*DATA_W) +: DATA_W]),
				.out_valid(valid_bus[i+1]),
				.out_ready(ready_bus[i+1]),
				.out_data(data_bus[((i+1)*DATA_W) +: DATA_W])
			);
		end
	endgenerate

endmodule

module stream_fifo_stage #(
	parameter integer DATA_W = 1
) (
	input clk,
	input reset,

	input in_valid,
	output in_ready,
	input [DATA_W-1:0] in_data,

	output out_valid,
	input out_ready,
	output [DATA_W-1:0] out_data
);

	reg full;
	reg [DATA_W-1:0] data_q;

	assign in_ready = !full;
	assign out_valid = full;
	assign out_data = data_q;

	always @(posedge clk) begin
		if (reset) begin
			full <= 1'b0;
			data_q <= {DATA_W{1'b0}};
		end else if (in_valid && in_ready) begin
			full <= 1'b1;
			data_q <= in_data;
		end else if (out_ready) begin
			full <= 1'b0;
		end
	end

endmodule

module mesh_arbiter #(
	parameter integer PKT_W = 1
) (
	input north_in_valid,
	input [2:0] north_in_route,
	input [PKT_W-1:0] north_in_pkt,
	output north_in_ready,

	input south_in_valid,
	input [2:0] south_in_route,
	input [PKT_W-1:0] south_in_pkt,
	output south_in_ready,

	input west_in_valid,
	input [2:0] west_in_route,
	input [PKT_W-1:0] west_in_pkt,
	output west_in_ready,

	input east_in_valid,
	input [2:0] east_in_route,
	input [PKT_W-1:0] east_in_pkt,
	output east_in_ready,

	input local_in_valid,
	input [2:0] local_in_route,
	input [PKT_W-1:0] local_in_pkt,
	output local_in_ready,

	output north_out_valid,
	input north_out_ready,
	output [PKT_W-1:0] north_out_pkt,

	output south_out_valid,
	input south_out_ready,
	output [PKT_W-1:0] south_out_pkt,

	output west_out_valid,
	input west_out_ready,
	output [PKT_W-1:0] west_out_pkt,

	output east_out_valid,
	input east_out_ready,
	output [PKT_W-1:0] east_out_pkt,

	output local_out_valid,
	input local_out_ready,
	output [PKT_W-1:0] local_out_pkt
);

	localparam [2:0] DIR_NORTH = 3'd0;
	localparam [2:0] DIR_SOUTH = 3'd1;
	localparam [2:0] DIR_WEST = 3'd2;
	localparam [2:0] DIR_EAST = 3'd3;
	localparam [2:0] DIR_LOCAL = 3'd4;

	wire south_to_north = south_in_valid && (south_in_route == DIR_NORTH);
	wire east_to_north = east_in_valid && (east_in_route == DIR_NORTH);
	wire north_to_north = north_in_valid && (north_in_route == DIR_NORTH);
	wire west_to_north = west_in_valid && (west_in_route == DIR_NORTH);
	wire local_to_north = local_in_valid && (local_in_route == DIR_NORTH);

	wire south_to_south = south_in_valid && (south_in_route == DIR_SOUTH);
	wire east_to_south = east_in_valid && (east_in_route == DIR_SOUTH);
	wire north_to_south = north_in_valid && (north_in_route == DIR_SOUTH);
	wire west_to_south = west_in_valid && (west_in_route == DIR_SOUTH);
	wire local_to_south = local_in_valid && (local_in_route == DIR_SOUTH);

	wire south_to_east = south_in_valid && (south_in_route == DIR_EAST);
	wire east_to_east = east_in_valid && (east_in_route == DIR_EAST);
	wire north_to_east = north_in_valid && (north_in_route == DIR_EAST);
	wire west_to_east = west_in_valid && (west_in_route == DIR_EAST);
	wire local_to_east = local_in_valid && (local_in_route == DIR_EAST);

	wire south_to_west = south_in_valid && (south_in_route == DIR_WEST);
	wire east_to_west = east_in_valid && (east_in_route == DIR_WEST);
	wire north_to_west = north_in_valid && (north_in_route == DIR_WEST);
	wire west_to_west = west_in_valid && (west_in_route == DIR_WEST);
	wire local_to_west = local_in_valid && (local_in_route == DIR_WEST);

	wire south_to_local = south_in_valid && (south_in_route == DIR_LOCAL);
	wire east_to_local = east_in_valid && (east_in_route == DIR_LOCAL);
	wire north_to_local = north_in_valid && (north_in_route == DIR_LOCAL);
	wire west_to_local = west_in_valid && (west_in_route == DIR_LOCAL);

	assign north_out_valid = south_to_north || east_to_north || north_to_north || west_to_north || local_to_north;
	assign south_out_valid = south_to_south || east_to_south || north_to_south || west_to_south || local_to_south;
	assign east_out_valid = south_to_east || east_to_east || north_to_east || west_to_east || local_to_east;
	assign west_out_valid = south_to_west || east_to_west || north_to_west || west_to_west || local_to_west;
	assign local_out_valid = south_to_local || east_to_local || north_to_local || west_to_local;

	assign north_out_pkt = south_to_north ? south_in_pkt :
	                       east_to_north ? east_in_pkt :
	                       north_to_north ? north_in_pkt :
	                       west_to_north ? west_in_pkt :
	                       local_to_north ? local_in_pkt :
	                       {PKT_W{1'b0}};

	assign south_out_pkt = south_to_south ? south_in_pkt :
	                       east_to_south ? east_in_pkt :
	                       north_to_south ? north_in_pkt :
	                       west_to_south ? west_in_pkt :
	                       local_to_south ? local_in_pkt :
	                       {PKT_W{1'b0}};

	assign east_out_pkt = south_to_east ? south_in_pkt :
	                      east_to_east ? east_in_pkt :
	                      north_to_east ? north_in_pkt :
	                      west_to_east ? west_in_pkt :
	                      local_to_east ? local_in_pkt :
	                      {PKT_W{1'b0}};

	assign west_out_pkt = south_to_west ? south_in_pkt :
	                      east_to_west ? east_in_pkt :
	                      north_to_west ? north_in_pkt :
	                      west_to_west ? west_in_pkt :
	                      local_to_west ? local_in_pkt :
	                      {PKT_W{1'b0}};

	assign local_out_pkt = south_to_local ? south_in_pkt :
	                       east_to_local ? east_in_pkt :
	                       north_to_local ? north_in_pkt :
	                       west_to_local ? west_in_pkt :
	                       {PKT_W{1'b0}};

	assign south_in_ready = (south_to_north && north_out_ready) ||
	                        (south_to_south && south_out_ready) ||
	                        (south_to_east && east_out_ready) ||
	                        (south_to_west && west_out_ready) ||
	                        (south_to_local && local_out_ready);

	assign east_in_ready = (east_to_north && !south_to_north && north_out_ready) ||
	                       (east_to_south && !south_to_south && south_out_ready) ||
	                       (east_to_east && !south_to_east && east_out_ready) ||
	                       (east_to_west && !south_to_west && west_out_ready) ||
	                       (east_to_local && !south_to_local && local_out_ready);

	assign north_in_ready = (north_to_north && !south_to_north && !east_to_north && north_out_ready) ||
	                        (north_to_south && !south_to_south && !east_to_south && south_out_ready) ||
	                        (north_to_east && !south_to_east && !east_to_east && east_out_ready) ||
	                        (north_to_west && !south_to_west && !east_to_west && west_out_ready) ||
	                        (north_to_local && !south_to_local && !east_to_local && local_out_ready);

	assign west_in_ready = (west_to_north && !south_to_north && !east_to_north && !north_to_north && north_out_ready) ||
	                       (west_to_south && !south_to_south && !east_to_south && !north_to_south && south_out_ready) ||
	                       (west_to_east && !south_to_east && !east_to_east && !north_to_east && east_out_ready) ||
	                       (west_to_west && !south_to_west && !east_to_west && !north_to_west && west_out_ready) ||
	                       (west_to_local && !south_to_local && !east_to_local && !north_to_local && local_out_ready);

	assign local_in_ready = (local_to_north && !south_to_north && !east_to_north && !north_to_north && !west_to_north && north_out_ready) ||
	                        (local_to_south && !south_to_south && !east_to_south && !north_to_south && !west_to_south && south_out_ready) ||
	                        (local_to_east && !south_to_east && !east_to_east && !north_to_east && !west_to_east && east_out_ready) ||
	                        (local_to_west && !south_to_west && !east_to_west && !north_to_west && !west_to_west && west_out_ready);

endmodule

module mesh_node_core #(
	parameter integer PKT_W = 1
) (
	input in_valid,
	output in_ready,
	input [PKT_W-1:0] in_pkt,

	output out_valid,
	input out_ready,
	output [PKT_W-1:0] out_pkt
);

	assign in_ready = 1'b1;
	assign out_valid = 1'b0;
	assign out_pkt = {PKT_W{1'b0}};

endmodule

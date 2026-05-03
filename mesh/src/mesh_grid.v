`timescale 1 ps / 1 ps

module mesh_grid_16x16 #(
	parameter integer GRID_W = 16,
	parameter integer GRID_H = 16,
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer COL_W = $clog2(IMG_W + 1),
	parameter integer ROW_W = $clog2(IMG_H + 1),
	parameter integer DEST_X_W = 4,
	parameter integer DEST_Y_W = 4,
	parameter integer PKT_W = COL_W + ROW_W + DEST_X_W + DEST_Y_W + 2,
	parameter integer SINK_DATA_W = COL_W + ROW_W + 1,
	parameter integer FIFO_DEPTH = 2,
	parameter [4:0] SOBEL_THRESHOLD = 5'd2,
	parameter integer MAJORITY_X = 1,
	parameter integer MAJORITY_Y = 1,
	parameter integer SOBEL_X = 2,
	parameter integer SOBEL_Y = 2,
	parameter integer SOURCE_Y = 0,
	parameter integer SINK_X = 15,
	parameter integer SINK_Y = 15
) (
	input clk,
	input reset,

	input source_valid,
	output source_ready,
	input [SINK_DATA_W-1:0] source_data,

	output sink_valid,
	input sink_ready,
	output [SINK_DATA_W-1:0] sink_data
);

	localparam integer NUM_NODES = GRID_W * GRID_H;
	localparam integer SINK_IDX = (SINK_Y * GRID_W) + SINK_X;
	localparam integer SOURCE_IDX = SOURCE_Y * GRID_W;

	wire [NUM_NODES-1:0] north_in_valid;
	wire [NUM_NODES-1:0] north_in_ready;
	wire [(NUM_NODES*PKT_W)-1:0] north_in_pkt;
	wire [NUM_NODES-1:0] north_out_valid;
	wire [NUM_NODES-1:0] north_out_ready;
	wire [(NUM_NODES*PKT_W)-1:0] north_out_pkt;

	wire [NUM_NODES-1:0] south_in_valid;
	wire [NUM_NODES-1:0] south_in_ready;
	wire [(NUM_NODES*PKT_W)-1:0] south_in_pkt;
	wire [NUM_NODES-1:0] south_out_valid;
	wire [NUM_NODES-1:0] south_out_ready;
	wire [(NUM_NODES*PKT_W)-1:0] south_out_pkt;

	wire [NUM_NODES-1:0] west_in_valid;
	wire [NUM_NODES-1:0] west_in_ready;
	wire [(NUM_NODES*PKT_W)-1:0] west_in_pkt;
	wire [NUM_NODES-1:0] west_out_valid;
	wire [NUM_NODES-1:0] west_out_ready;
	wire [(NUM_NODES*PKT_W)-1:0] west_out_pkt;

	wire [NUM_NODES-1:0] east_in_valid;
	wire [NUM_NODES-1:0] east_in_ready;
	wire [(NUM_NODES*PKT_W)-1:0] east_in_pkt;
	wire [NUM_NODES-1:0] east_out_valid;
	wire [NUM_NODES-1:0] east_out_ready;
	wire [(NUM_NODES*PKT_W)-1:0] east_out_pkt;

	wire source_pixel;
	wire [ROW_W-1:0] source_row;
	wire [COL_W-1:0] source_column;
	wire [PKT_W-1:0] source_pkt;
	wire [DEST_X_W-1:0] source_dest_x;
	wire [DEST_Y_W-1:0] source_dest_y;
	assign {source_pixel, source_row, source_column} = source_data;
	assign source_dest_x = MAJORITY_X[DEST_X_W-1:0];
	assign source_dest_y = MAJORITY_Y[DEST_Y_W-1:0];
	assign source_pkt = {1'b1, source_dest_y, source_dest_x, source_pixel, source_row, source_column};
	assign source_ready = west_in_ready[SOURCE_IDX];

    wire [COL_W-1:0] sink_out_column;
    wire [ROW_W-1:0] sink_out_row;
    wire sink_out_pixel;
    wire [DEST_X_W-1:0] sink_out_dest_x;
    wire [DEST_Y_W-1:0] sink_out_dest_y;
    wire sink_out_packet_valid;
    assign {sink_out_packet_valid, sink_out_dest_y, sink_out_dest_x, sink_out_pixel, sink_out_row, sink_out_column} = east_out_pkt[(SINK_IDX*PKT_W) +: PKT_W];
	assign sink_data = {sink_out_pixel, sink_out_row, sink_out_column};
	assign sink_valid = sink_out_packet_valid;

	genvar x;
	genvar y;
	generate
		for (y = 0; y < GRID_H; y = y + 1) begin : row_gen
			for (x = 0; x < GRID_W; x = x + 1) begin : col_gen
				localparam integer IDX = (y * GRID_W) + x;

				if (y == 0) begin : north_edge_gen
					assign north_in_valid[IDX] = 1'b0;
					assign north_in_pkt[(IDX*PKT_W) +: PKT_W] = {PKT_W{1'b0}};
					assign north_out_ready[IDX] = 1'b1;
				end else begin : north_link_gen
					localparam integer NORTH_IDX = ((y - 1) * GRID_W) + x;
					assign north_in_valid[IDX] = south_out_valid[NORTH_IDX];
					assign north_in_pkt[(IDX*PKT_W) +: PKT_W] = south_out_pkt[(NORTH_IDX*PKT_W) +: PKT_W];
					assign north_out_ready[IDX] = south_in_ready[NORTH_IDX];
				end

				if (y == (GRID_H - 1)) begin : south_edge_gen
					assign south_in_valid[IDX] = 1'b0;
					assign south_in_pkt[(IDX*PKT_W) +: PKT_W] = {PKT_W{1'b0}};
					assign south_out_ready[IDX] = 1'b1;
				end else begin : south_link_gen
					localparam integer SOUTH_IDX = ((y + 1) * GRID_W) + x;
					assign south_in_valid[IDX] = north_out_valid[SOUTH_IDX];
					assign south_in_pkt[(IDX*PKT_W) +: PKT_W] = north_out_pkt[(SOUTH_IDX*PKT_W) +: PKT_W];
					assign south_out_ready[IDX] = north_in_ready[SOUTH_IDX];
				end

				if (x == 0) begin : west_edge_gen
					assign west_in_valid[IDX] = (y == SOURCE_Y) ? source_valid : 1'b0;
					assign west_in_pkt[(IDX*PKT_W) +: PKT_W] = (y == SOURCE_Y) ? source_pkt : {PKT_W{1'b0}};
					assign west_out_ready[IDX] = 1'b1;
				end else begin : west_link_gen
					localparam integer WEST_IDX = (y * GRID_W) + (x - 1);
					assign west_in_valid[IDX] = east_out_valid[WEST_IDX];
					assign west_in_pkt[(IDX*PKT_W) +: PKT_W] = east_out_pkt[(WEST_IDX*PKT_W) +: PKT_W];
					assign west_out_ready[IDX] = east_in_ready[WEST_IDX];
				end

				if (x == (GRID_W - 1)) begin : east_edge_gen
					assign east_in_valid[IDX] = 1'b0;
					assign east_in_pkt[(IDX*PKT_W) +: PKT_W] = {PKT_W{1'b0}};
					if (SINK_IDX == IDX) begin : sink_east_edge_gen
						assign east_out_ready[IDX] = sink_ready;
					end else begin : default_east_edge_gen
						assign east_out_ready[IDX] = 1'b1;
					end
				end else begin : east_link_gen
					localparam integer EAST_IDX = (y * GRID_W) + (x + 1);
					assign east_in_valid[IDX] = west_out_valid[EAST_IDX];
					assign east_in_pkt[(IDX*PKT_W) +: PKT_W] = west_out_pkt[(EAST_IDX*PKT_W) +: PKT_W];
					assign east_out_ready[IDX] = west_in_ready[EAST_IDX];
				end

				mesh_core #(
					.IMG_W(IMG_W),
					.IMG_H(IMG_H),
					.COL_W(COL_W),
					.ROW_W(ROW_W),
					.DEST_X_W(DEST_X_W),
					.DEST_Y_W(DEST_Y_W),
					.PKT_W(PKT_W),
					.FIFO_DEPTH(FIFO_DEPTH),
					.MAJORITY_X(MAJORITY_X),
					.MAJORITY_Y(MAJORITY_Y),
					.SOBEL_X(SOBEL_X),
					.SOBEL_Y(SOBEL_Y),
					.SINK_X(SINK_X),
					.SINK_Y(SINK_Y),					
					.CORE_SOBEL_THRESHOLD(SOBEL_THRESHOLD),
					.X_ID(x),
					.Y_ID(y)
				) node_inst (
					.clk(clk),
					.reset(reset),

					.north_in_valid(north_in_valid[IDX]),
					.north_in_ready(north_in_ready[IDX]),
					.north_in_pkt(north_in_pkt[(IDX*PKT_W) +: PKT_W]),
					.north_out_valid(north_out_valid[IDX]),
					.north_out_ready(north_out_ready[IDX]),
					.north_out_pkt(north_out_pkt[(IDX*PKT_W) +: PKT_W]),

					.south_in_valid(south_in_valid[IDX]),
					.south_in_ready(south_in_ready[IDX]),
					.south_in_pkt(south_in_pkt[(IDX*PKT_W) +: PKT_W]),
					.south_out_valid(south_out_valid[IDX]),
					.south_out_ready(south_out_ready[IDX]),
					.south_out_pkt(south_out_pkt[(IDX*PKT_W) +: PKT_W]),

					.west_in_valid(west_in_valid[IDX]),
					.west_in_ready(west_in_ready[IDX]),
					.west_in_pkt(west_in_pkt[(IDX*PKT_W) +: PKT_W]),
					.west_out_valid(west_out_valid[IDX]),
					.west_out_ready(west_out_ready[IDX]),
					.west_out_pkt(west_out_pkt[(IDX*PKT_W) +: PKT_W]),

					.east_in_valid(east_in_valid[IDX]),
					.east_in_ready(east_in_ready[IDX]),
					.east_in_pkt(east_in_pkt[(IDX*PKT_W) +: PKT_W]),
					.east_out_valid(east_out_valid[IDX]),
					.east_out_ready(east_out_ready[IDX]),
					.east_out_pkt(east_out_pkt[(IDX*PKT_W) +: PKT_W])
				);
			end
		end
	endgenerate

	function integer node_index;
		input integer x_c;
		input integer y_c;
		begin
			node_index = (y_c * GRID_W) + x_c;
		end
	endfunction

endmodule

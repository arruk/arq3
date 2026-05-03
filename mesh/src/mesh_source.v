`timescale 1 ps / 1 ps

module mesh_image_source #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer COL_W = $clog2(IMG_W + 1),
	parameter integer ROW_W = $clog2(IMG_H + 1),
	parameter integer DATA_W = COL_W + ROW_W + 1,
	parameter INIT_FILE = "src/image.mem",
	parameter integer REPEAT = 1
) (
	input clk,
	input reset,

	output out_valid,
	input out_ready,
	output [DATA_W-1:0] out_data
);

	localparam integer FRAME_SIZE = IMG_W * IMG_H;
	localparam integer ADDR_W = $clog2(FRAME_SIZE);

	localparam [COL_W-1:0] IMG_W_LIM = IMG_W[COL_W-1:0];
	localparam [ROW_W-1:0] IMG_H_LIM = IMG_H[ROW_W-1:0];

	reg [COL_W-1:0] column = {COL_W{1'b0}};
	reg [ROW_W-1:0] row = {ROW_W{1'b0}};
	reg done = 1'b0;

	wire in_image = (column < IMG_W_LIM) && (row < IMG_H_LIM);
	wire [ADDR_W-1:0] rom_addr = image_address(column, row);
	wire rom_pixel;
	wire source_pixel = in_image ? rom_pixel : 1'b0;
	wire fire = out_valid && out_ready;

	assign out_valid = !done;
	assign out_data = {source_pixel, row, column};

	mesh_image_rom #(
		.DATA_W(1),
		.ADDR_W(ADDR_W),
		.DEPTH(FRAME_SIZE),
		.INIT_FILE(INIT_FILE)
	) image_rom (
		.addr(rom_addr),
		.data(rom_pixel)
	);

	always @(posedge clk) begin
		if (reset) begin
			column <= {COL_W{1'b0}};
			row <= {ROW_W{1'b0}};
			done <= 1'b0;
		end else if (fire) begin
			if ((column == IMG_W_LIM) && (row == IMG_H_LIM)) begin
				column <= {COL_W{1'b0}};
				row <= {ROW_W{1'b0}};
				done <= (REPEAT == 0);
			end else if (column == IMG_W_LIM) begin
				column <= {COL_W{1'b0}};
				row <= row + 1'b1;
			end else begin
				column <= column + 1'b1;
			end
		end
	end

	function [ADDR_W-1:0] image_address;
		input [COL_W-1:0] addr_column;
		input [ROW_W-1:0] addr_row;
		reg [31:0] column_ext;
		reg [31:0] row_ext;
		reg [31:0] linear_address;
		begin
			column_ext = {{(32-COL_W){1'b0}}, addr_column};
			row_ext = {{(32-ROW_W){1'b0}}, addr_row};
			linear_address = (row_ext * IMG_W) + column_ext;
			image_address = linear_address[ADDR_W-1:0];
		end
	endfunction

endmodule

module mesh_image_rom #(
	parameter integer DATA_W = 1,
	parameter integer ADDR_W = 15,
	parameter integer DEPTH = 32768,
	parameter INIT_FILE = "src/image.mem"
) (
	input [ADDR_W-1:0] addr,
	output [DATA_W-1:0] data
);

	reg [DATA_W-1:0] memory [0:DEPTH-1];

	initial begin
		$readmemb(INIT_FILE, memory);
	end

	assign data = memory[addr];

endmodule

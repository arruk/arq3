`timescale 1 ps / 1 ps

module simple_dual_port_ram #(
	parameter integer ADDR_W = 15,
	parameter integer DATA_W = 1,
	parameter integer DEPTH = 32768
) (
	input clk,
	input write_enable,
	input [ADDR_W-1:0] write_addr,
	input [DATA_W-1:0] write_data,
	input read_enable,
	input [ADDR_W-1:0] read_addr,
	output reg [DATA_W-1:0] read_data
);
	reg [DATA_W-1:0] memory [0:DEPTH-1];

	always @(posedge clk) begin
		if (write_enable) begin
			memory[write_addr] <= write_data;
		end

		if (read_enable) begin
			read_data <= memory[read_addr];
		end
	end
endmodule

module true_dual_port_ram #(
	parameter integer ADDR_W = 15,
	parameter integer DATA_W = 1,
	parameter integer DEPTH = 32768
) (
	input clk,
	input port_a_write_enable,
	input port_a_read_enable,
	input [ADDR_W-1:0] port_a_read_addr,
	input [ADDR_W-1:0] port_a_write_addr,
	input [DATA_W-1:0] port_a_write_data,
	output reg [DATA_W-1:0] port_a_read_data,

	input port_b_write_enable,
	input port_b_read_enable,
	input [ADDR_W-1:0] port_b_read_addr,
	input [ADDR_W-1:0] port_b_write_addr,
	input [DATA_W-1:0] port_b_write_data,
	output reg [DATA_W-1:0] port_b_read_data
);
	reg [DATA_W-1:0] memory [0:DEPTH-1];

	wire [ADDR_W-1:0] port_a_addr = port_a_write_enable ? port_a_write_addr : port_a_read_addr;
	wire [ADDR_W-1:0] port_b_addr = port_b_write_enable ? port_b_write_addr : port_b_read_addr;

	always @(posedge clk) begin
		if (port_a_write_enable) begin
			memory[port_a_addr] <= port_a_write_data;
		end

		if (port_a_read_enable) begin
			port_a_read_data <= memory[port_a_addr];
		end

		if (port_b_write_enable) begin
			memory[port_b_addr] <= port_b_write_data;
		end

		if (port_b_read_enable) begin
			port_b_read_data <= memory[port_b_addr];
		end
	end
endmodule

module double_framebuffer #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128
) (
	input clk,
	input reset,
	input read_bank,
	input write_bank,

	input display_read_enable,
	input [($clog2(IMG_W + 1))-1:0] display_read_column,
	input [($clog2(IMG_H + 1))-1:0] display_read_row,
	output display_read_pixel,

	input compute_read_enable,
	input [($clog2(IMG_W + 1))-1:0] compute_read_column,
	input [($clog2(IMG_H + 1))-1:0] compute_read_row,
	output compute_read_pixel,

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

	wire display_read_in_bounds = display_read_enable && (display_read_column < IMG_W_LIM) && (display_read_row < IMG_H_LIM);
	wire compute_read_in_bounds = compute_read_enable && (compute_read_column < IMG_W_LIM) && (compute_read_row < IMG_H_LIM);
	wire write_in_bounds = write_enable && (write_column < IMG_W_LIM) && (write_row < IMG_H_LIM);

	wire [ADDR_W-1:0] display_read_addr = address(display_read_column[COL_INDEX_W-1:0], display_read_row[ROW_INDEX_W-1:0]);
	wire [ADDR_W-1:0] compute_read_addr = address(compute_read_column[COL_INDEX_W-1:0], compute_read_row[ROW_INDEX_W-1:0]);
	wire [ADDR_W-1:0] write_addr        = address(write_column[COL_INDEX_W-1:0], write_row[ROW_INDEX_W-1:0]);

	wire display_read_pixel0;
	wire compute_read_pixel0;

	true_dual_port_ram #(
		.ADDR_W(ADDR_W),
		.DATA_W(1),
		.DEPTH(FRAME_SIZE)
	) memory0 (
		.clk(clk),

		.port_a_write_enable (write_in_bounds && !write_bank),
		.port_a_read_enable  (display_read_in_bounds && !read_bank),
		.port_a_write_addr   (write_addr),
		.port_a_read_addr    (display_read_addr),
		.port_a_write_data   (write_pixel),
		.port_a_read_data    (display_read_pixel0),

		.port_b_write_enable (1'b0),
		.port_b_read_enable  (compute_read_in_bounds && !read_bank),
		.port_b_write_addr   ({(ADDR_W){1'b0}}),
		.port_b_read_addr    (compute_read_addr),
		.port_b_write_data   (1'b0),
		.port_b_read_data    (compute_read_pixel0)
	);

	wire display_read_pixel1;
	wire compute_read_pixel1;

	true_dual_port_ram #(
		.ADDR_W(ADDR_W),
		.DATA_W(1),
		.DEPTH(FRAME_SIZE)
	) memory1 (
		.clk(clk),

		.port_a_write_enable (write_in_bounds && write_bank),
		.port_a_read_enable  (display_read_in_bounds && read_bank),
		.port_a_write_addr   (write_addr),
		.port_a_read_addr    (display_read_addr),
		.port_a_write_data   (write_pixel),
		.port_a_read_data    (display_read_pixel1),

		.port_b_write_enable (1'b0),
		.port_b_read_enable  (compute_read_in_bounds && read_bank),
		.port_b_write_addr   ({(ADDR_W){1'b0}}),
		.port_b_read_addr    (compute_read_addr),
		.port_b_write_data   (1'b0),
		.port_b_read_data    (compute_read_pixel1)
	);

	assign display_read_pixel = read_bank ? display_read_pixel1 : display_read_pixel0;
	assign compute_read_pixel = read_bank ? compute_read_pixel1 : compute_read_pixel0;

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

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
	localparam integer IMG_W = 256;
	localparam integer IMG_H = 128;

	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);

	localparam [COL_W-1:0] COL_ZERO = {COL_W{1'b0}};
	localparam [ROW_W-1:0] ROW_ZERO = {ROW_W{1'b0}};
	localparam [COL_W-1:0] LAST_IMG_COLUMN = IMG_W[COL_W-1:0] - {{(COL_W-1){1'b0}}, 1'b1};
	localparam [ROW_W-1:0] LAST_IMG_ROW = IMG_H[ROW_W-1:0] - {{(ROW_W-1){1'b0}}, 1'b1};

	wire [9:0] pixel_row;
	wire [9:0] pixel_column;

	wire on;
	wire pclk;
	wire red_out;
	wire green_out;
	wire blue_out;

	wire pixel = smux;

	VGA_SYNC vga_sync_inst (
		.clock_50Mhz    (CLOCK_50),
		.red            (pixel),
		.green          (pixel),
		.blue           (pixel),
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


	wire [14:0] address;

	conc conc_inst (
		.pixel_column(pixel_column),
		.pixel_row(pixel_row),
		.address(address)
	);

	wire img1;

	rom rom_inst_initial (
		.address(address),
		.clock(pclk),
		.q(img1)
	);

	wire smux = img_end_pixel;
	
	wire mask;
	janela janela_inst (
		.pixel_column(pixel_column),
		.pixel_row(pixel_row),
		.mask(mask)
	);

	wire reset = 1'b0;

	wire img_end_pixel;
	wire [ROW_W-1:0] img_end_row;
	wire [COL_W-1:0] img_end_column;
	wire img_end_valid;

        wire [2:0] win1_w_c0;
        wire [2:0] win1_w_c1;
        wire [2:0] win1_w_c2;
        wire [ROW_W-1:0] win1_center_row;
        wire [COL_W-1:0] win1_center_column;
        wire win1_center_valid;
        wire win1_window_valid;
        wire win1_border;

	localparam [9:0] IMG_W_TOP = IMG_W[9:0];
	localparam [9:0] IMG_H_TOP = IMG_H[9:0];

	reg rom_valid = 1'b0;
	reg read_bank = 1'b0;
	reg write_bank = 1'b0;
	wire fb_pixel;

	double_framebuffer #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) framebuffer_inst (
		.clk(pclk),
		.reset(reset),
		.read_bank(read_bank),
		.write_bank(write_bank),

		.read_enable(on && (pixel_column < IMG_W_TOP) && (pixel_row < IMG_H_TOP)),
		.read_column(pixel_column[COL_W-1:0]),
		.read_row(pixel_row[ROW_W-1:0]),
		.read_pixel(fb_pixel),

		.write_enable(img_end_valid),
		.write_column(img_end_column),
		.write_row(img_end_row),
		.write_pixel(img_end_pixel)
	);

	wire use_initial_frame = !rom_valid;
	wire [9:0] stream_column = pixel_column;
	wire [9:0] stream_row = pixel_row;
	wire stream_pixel = use_initial_frame ? img1 : fb_pixel;

	wire src_valid = on && (stream_column <  IMG_W_TOP) && (stream_row <  IMG_H_TOP);
	wire flush_valid = on && (stream_column <= IMG_W_TOP) && (stream_row <= IMG_H_TOP);
	wire img1_pipe = src_valid ? stream_pixel : 1'b0;

	reg [COL_W-1:0] pipe_column = COL_ZERO;
	reg [ROW_W-1:0] pipe_row = ROW_ZERO;
	reg pipe_valid = 1'b0;

	always @(posedge pclk) begin
		pipe_column <= stream_column[COL_W-1:0];
		pipe_row    <= stream_row[ROW_W-1:0];
		pipe_valid  <= flush_valid;
	end

	always @(posedge pclk) begin
		if (reset) begin
			rom_valid <= 1'b0;
			read_bank <= 1'b0;
			write_bank <= 1'b0;
		end else if (generation_done) begin
			rom_valid <= 1'b1;
			read_bank <= write_bank;
			write_bank <= !write_bank;
		end
	end

	window_stream #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) filter_window_inst (
		.clk(pclk),
		.reset(reset),

		.pixel_in(img1_pipe),
		.column_in(pipe_column),
		.row_in(pipe_row),
		.valid_in(pipe_valid),

		.w_col0(win1_w_c0),
		.w_col1(win1_w_c1),
		.w_col2(win1_w_c2),
		.center_row(win1_center_row),
		.center_column(win1_center_column),
		.center_valid(win1_center_valid),
		.window_valid(win1_window_valid),
		.border(win1_border)
	);

	gameoflife gol_inst (
		.w_col0(win1_w_c0),
		.w_col1(win1_w_c1),
		.w_col2(win1_w_c2),
		.center_valid(win1_center_valid),
		.window_valid(win1_window_valid),
		.border(win1_border),
		.pixel_out(img_end_pixel)
	);	

	assign img_end_row = win1_center_row;
	assign img_end_column = win1_center_column;
	assign img_end_valid = win1_center_valid;

	wire generation_done = img_end_valid &&
	                       (img_end_column == LAST_IMG_COLUMN) &&
	                       (img_end_row == LAST_IMG_ROW);

	assign VGA_R = {8{red_out}};
	assign VGA_G = {8{green_out}};
	assign VGA_B = {8{blue_out}};

	assign VGA_CLK     = pclk;
	assign VGA_BLANK_N = on;
	assign VGA_SYNC_N  = 1'b0;

endmodule

module gameoflife (
        input [2:0] w_col0,
        input [2:0] w_col1,
        input [2:0] w_col2,
        input center_valid,
        input window_valid,
        input border,
        output pixel_out
);
        wire [3:0] sum_n = {3'b000, w_col0[0]} + {3'b000, w_col0[1]} + {3'b000, w_col0[2]} +
                                   {3'b000, w_col1[0]} +                       {3'b000, w_col1[2]} +
                                   {3'b000, w_col2[0]} + {3'b000, w_col2[1]} + {3'b000, w_col2[2]};

	wire center = w_col1[1];

	wire newgen = center ? ((sum_n == 2) || (sum_n == 3)) :
	                     (sum_n == 3);

	wire use_gol = center_valid && window_valid && !border;

        assign pixel_out = use_gol ? newgen : 1'b0;

endmodule

module window_stream #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128
) (
	input clk,
	input reset,
	input pixel_in,
	input [($clog2(IMG_W + 1))-1:0] column_in,
	input [($clog2(IMG_H + 1))-1:0] row_in,
	input valid_in,
	output [2:0] w_col0,
	output [2:0] w_col1,
	output [2:0] w_col2,
	output [($clog2(IMG_W + 1))-1:0] center_column,
	output [($clog2(IMG_H + 1))-1:0] center_row,
	output center_valid,
	output window_valid,
	output border
);
	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);

	localparam [COL_W-1:0] IMG_W_LIM = IMG_W[COL_W-1:0];
	localparam [ROW_W-1:0] IMG_H_LIM = IMG_H[ROW_W-1:0];

	localparam integer COL_INDEX_W = $clog2(IMG_W);

	localparam [ROW_W-1:0] ROW_ZERO = {(ROW_W){1'b0}};
	localparam [ROW_W-1:0] ROW_ONE  = {{(ROW_W-1){1'b0}}, 1'b1};
	localparam [ROW_W-1:0] ROW_TWO  = {{(ROW_W-2){1'b0}}, 2'b10};
	localparam [ROW_W-1:0] LAST_ROW = IMG_H_LIM - ROW_ONE;

	localparam [COL_W-1:0] COL_ZERO = {(COL_W){1'b0}};
	localparam [COL_W-1:0] COL_ONE  = {{(COL_W-1){1'b0}}, 1'b1};
	localparam [COL_W-1:0] LAST_COL = IMG_W_LIM - COL_ONE;

	reg s1_p0;
	reg [COL_W-1:0] s1_c;
	reg [ROW_W-1:0] s1_r;
	reg s1_valid = 1'b0;

	reg [IMG_W-1:0] buf1;
	reg [COL_W-1:0] s2_c;
	reg [ROW_W-1:0] s2_r;
	reg s2_p0, s2_p1;
	reg s2_valid = 1'b0;
	reg s2_has_prev_row = 1'b0;

	reg [IMG_W-1:0] buf2;
	reg s3_p0, s3_p1, s3_p2;
	reg [COL_W-1:0] s3_c;
	reg [ROW_W-1:0] s3_r;
	reg s3_has_prev_row = 1'b0;
	reg s3_has_3_rows = 1'b0;

	reg [COL_W-1:0] s4_center_c, s4_c;
	reg [ROW_W-1:0] s4_center_r;
	reg s4_valid = 1'b0;
	reg s4_has_3_rows = 1'b0;
	reg [2:0] s4_w_c0;

	reg [2:0] s5_w_c0;
	reg [2:0] s5_w_c1;
	reg [2:0] s5_w_c2;
    reg [COL_W-1:0] s5_center_c;
    reg [ROW_W-1:0] s5_center_r;
	reg s5_col_v0 = 1'b0;
	reg s5_col_v1 = 1'b0;
	reg s5_col_v2 = 1'b0;
	reg s5_col_rows0 = 1'b0;
	reg s5_col_rows1 = 1'b0;
	reg s5_col_rows2 = 1'b0;

	always @(posedge clk) begin
		if (reset) begin
			s1_valid <= 1'b0;
		end else begin
			s1_p0 <= pixel_in;
			s1_c <= column_in;
			s1_r <= row_in;
			s1_valid <= valid_in;
		end
	end

	always @(posedge clk) begin
		if (reset) begin
			s2_valid <= 1'b0;
			s2_has_prev_row <= 1'b0;
		end else begin
			if (s1_valid) begin
				s2_p0 <= s1_p0;
				if (s1_c < IMG_W_LIM) begin
					s2_p1 <= buf1[s1_c[COL_INDEX_W-1:0]];
					buf1[s1_c[COL_INDEX_W-1:0]] <= s1_p0;
				end else begin
					s2_p1 <= 1'b0;
				end
				s2_c <= s1_c;
				s2_r <= s1_r;
			end

			s2_valid <= s1_valid;
			s2_has_prev_row <= s1_valid && (s1_r >= ROW_ONE);
		end
	end

	always @(posedge clk) begin
		if (reset) begin
			s3_has_prev_row <= 1'b0;
			s3_has_3_rows <= 1'b0;
		end else begin
			if (s2_valid) begin
				s3_p0 <= s2_p0;
				s3_p1 <= s2_p1;
				if (s2_c < IMG_W_LIM) begin
					s3_p2 <= buf2[s2_c[COL_INDEX_W-1:0]];
					buf2[s2_c[COL_INDEX_W-1:0]] <= s2_p1;
				end else begin
					s3_p2 <= 1'b0;
				end
				s3_c <= s2_c;
				s3_r <= s2_r;
			end

			s3_has_prev_row <= s2_has_prev_row;
			s3_has_3_rows <= s2_valid && (s2_r >= ROW_TWO);
		end
	end

	always @(posedge clk) begin
		if (reset) begin
			s4_valid <= 1'b0;
			s4_has_3_rows <= 1'b0;
		end else begin
			s4_valid <= s3_has_prev_row;
			s4_has_3_rows <= s3_has_3_rows;
			s4_w_c0 <= {s3_p2, s3_p1, s3_p0};
			s4_center_c <= (s3_c == COL_ZERO) ? COL_ZERO : (s3_c - COL_ONE);
			s4_center_r <= (s3_r == ROW_ZERO) ? ROW_ZERO : (s3_r - ROW_ONE);
			s4_c <= s3_c;
		end
	end

	always @(posedge clk) begin
		if (reset) begin
			s5_col_v0 <= 1'b0;
			s5_col_v1 <= 1'b0;
			s5_col_v2 <= 1'b0;
			s5_col_rows0 <= 1'b0;
			s5_col_rows1 <= 1'b0;
			s5_col_rows2 <= 1'b0;
		end else if (s4_valid) begin
			s5_center_c <= s4_center_c;
			s5_center_r <= s4_center_r;

			if (s4_c == COL_ZERO) begin
				s5_w_c0 <= s4_w_c0;
				s5_w_c1 <= 3'd0;
				s5_w_c2 <= 3'd0;
				s5_col_v0 <= 1'b1;
				s5_col_v1 <= 1'b0;
				s5_col_v2 <= 1'b0;
				s5_col_rows0 <= s4_has_3_rows;
				s5_col_rows1 <= 1'b0;
				s5_col_rows2 <= 1'b0;
			end else begin
				s5_w_c0 <= s4_w_c0;
				s5_w_c1 <= s5_w_c0;
				s5_w_c2 <= s5_w_c1;
				s5_col_v0 <= 1'b1;
				s5_col_v1 <= s5_col_v0;
				s5_col_v2 <= s5_col_v1;
				s5_col_rows0 <= s4_has_3_rows;
				s5_col_rows1 <= s5_col_rows0;
				s5_col_rows2 <= s5_col_rows1;
			end
		end else begin
			s5_col_v0 <= 1'b0;
			s5_col_v1 <= 1'b0;
			s5_col_v2 <= 1'b0;
			s5_col_rows0 <= 1'b0;
			s5_col_rows1 <= 1'b0;
			s5_col_rows2 <= 1'b0;
		end
	end

	wire s5_has_3_cols = s5_col_v0 && s5_col_v1 && s5_col_v2;
	wire s5_has_3_rows = s5_col_rows0 && s5_col_rows1 && s5_col_rows2;

	assign w_col0 = s5_w_c0;
	assign w_col1 = s5_w_c1;
	assign w_col2 = s5_w_c2;
	assign center_row = s5_center_r;
	assign center_column = s5_center_c;
	assign center_valid = s5_col_v1;
	assign window_valid = s5_has_3_cols && s5_has_3_rows;
	assign border = (s5_center_c == COL_ZERO) || (s5_center_c == LAST_COL) || (s5_center_r == ROW_ZERO) || (s5_center_r == LAST_ROW);

endmodule

module double_framebuffer #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128
) (
	input clk,
	input reset,
	input read_bank,
	input write_bank,

	input read_enable,
	input [($clog2(IMG_W + 1))-1:0] read_column,
	input [($clog2(IMG_H + 1))-1:0] read_row,
	output reg read_pixel,

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
	wire [ADDR_W-1:0] read_addr = address_for(read_column[COL_INDEX_W-1:0], read_row[ROW_INDEX_W-1:0]);
	wire [ADDR_W-1:0] write_addr = address_for(write_column[COL_INDEX_W-1:0], write_row[ROW_INDEX_W-1:0]);
	wire [0:0] read_pixel0;
	wire [0:0] read_pixel1;

	function [ADDR_W-1:0] address_for;
		input [COL_INDEX_W-1:0] column;
		input [ROW_INDEX_W-1:0] row;
		begin
			address_for = {row, column};
		end
	endfunction

	simple_dual_port_ram #(
		.ADDR_W(ADDR_W),
		.DATA_W(1),
		.DEPTH(FRAME_SIZE)
	) memory0 (
		.clk(clk),
		.write_enable(write_in_bounds && !write_bank),
		.write_addr(write_addr),
		.write_data(write_pixel),
		.read_enable(read_in_bounds && !read_bank),
		.read_addr(read_addr),
		.read_data(read_pixel0)
	);

	simple_dual_port_ram #(
		.ADDR_W(ADDR_W),
		.DATA_W(1),
		.DEPTH(FRAME_SIZE)
	) memory1 (
		.clk(clk),
		.write_enable(write_in_bounds && write_bank),
		.write_addr(write_addr),
		.write_data(write_pixel),
		.read_enable(read_in_bounds && read_bank),
		.read_addr(read_addr),
		.read_data(read_pixel1)
	);

	always @(posedge clk) begin
		if (reset) begin
			read_pixel <= 1'b0;
		end else if (read_in_bounds) begin
			read_pixel <= read_bank ? read_pixel1[0] : read_pixel0[0];
		end else begin
			read_pixel <= 1'b0;
		end
	end
endmodule

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


module conc (
	input [9:0] pixel_column,
	input [9:0] pixel_row,
	output [14:0] address
);
	assign address = {pixel_row[6:0], pixel_column[7:0]};
endmodule

module janela (
        input [9:0] pixel_column,
        input [9:0] pixel_row,
	output mask
);

        assign mask = !(pixel_column[9] | pixel_column[8]) &
                      !(pixel_row[9] | pixel_row[8] | pixel_row[7]);

endmodule

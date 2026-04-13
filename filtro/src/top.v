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

	wire img1;
	wire [14:0] address;
	wire [9:0] pixel_row;
	wire [9:0] pixel_column;

	wire on;
	wire pclk;
	wire red_out;
	wire green_out;
	wire blue_out;
	wire mask;

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

	conc conc_inst (
		.pixel_column(pixel_column),
		.pixel_row(pixel_row),
		.address(address)
	);

	rom rom_inst (
		.address(address),
		.clock(pclk),
		.q(img1)
	);

	wire smux = (sel_img == 2'd0) ? (mask & on & img1) :
				(sel_img == 2'd1) ? img2_pixel :
		 		                    img3_pixel ;
	
	janela janela_inst (
		.pixel_column(pixel_column),
		.pixel_row(pixel_row),
		.mask(mask)
	);

	wire reset = 1'b0;

	wire img2_pixel;
	wire [ROW_W-1:0] img2_row;
	wire [COL_W-1:0] img2_column;
	wire img2_valid;

	wire img3_pixel;
	wire [ROW_W-1:0] img3_row;
	wire [COL_W-1:0] img3_column;
	wire img3_valid;

	wire [2:0] win1_w_c0;
	wire [2:0] win1_w_c1;
	wire [2:0] win1_w_c2;
	wire [ROW_W-1:0] win1_center_row;
	wire [COL_W-1:0] win1_center_column;
	wire win1_center_valid;
	wire win1_window_valid;
	wire win1_border;

	wire [2:0] win2_w_c0;
	wire [2:0] win2_w_c1;
	wire [2:0] win2_w_c2;
	wire [ROW_W-1:0] win2_center_row;
	wire [COL_W-1:0] win2_center_column;
	wire win2_center_valid;
	wire win2_window_valid;
	wire win2_border;

	localparam [9:0] IMG_W_TOP = IMG_W[9:0];
	localparam [9:0] IMG_H_TOP = IMG_H[9:0];

	wire src_valid = on && (pixel_column <  IMG_W_TOP) && (pixel_row <  IMG_H_TOP);
	wire flush_valid = on && (pixel_column <= IMG_W_TOP) && (pixel_row <= IMG_H_TOP);
	wire img1_pipe = src_valid ? img1 : 1'b0;

	reg [COL_W-1:0] pipe_column = COL_ZERO;
	reg [ROW_W-1:0] pipe_row = ROW_ZERO;
	reg pipe_valid = 1'b0;

	always @(posedge pclk) begin
		pipe_column <= pixel_column[COL_W-1:0];
		pipe_row    <= pixel_row[ROW_W-1:0];
		pipe_valid  <= flush_valid;
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

	majority majority_inst (
		.w_col0(win1_w_c0),
		.w_col1(win1_w_c1),
		.w_col2(win1_w_c2),
		.center_valid(win1_center_valid),
		.window_valid(win1_window_valid),
		.border(win1_border),
		.pixel_out(img2_pixel)
	);

	assign img2_row = win1_center_row;
	assign img2_column = win1_center_column;
	assign img2_valid = win1_center_valid;

	window_stream #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) sobel_window_inst (
		.clk(pclk),
		.reset(reset),

		.pixel_in(img2_pixel),
		.column_in(img2_column),
		.row_in(img2_row),
		.valid_in(img2_valid),

		.w_col0(win2_w_c0),
		.w_col1(win2_w_c1),
		.w_col2(win2_w_c2),
		.center_row(win2_center_row),
		.center_column(win2_center_column),
		.center_valid(win2_center_valid),
		.window_valid(win2_window_valid),
		.border(win2_border)
	);

	sobel #(
		.THRESHOLD(2)
	) sobel_inst (
		.w_col0(win2_w_c0),
		.w_col1(win2_w_c1),
		.w_col2(win2_w_c2),
		.center_valid(win2_center_valid),
		.window_valid(win2_window_valid),
		.border(win2_border),
		.pixel_out(img3_pixel)
	);

	assign img3_row = win2_center_row;
	assign img3_column = win2_center_column;
	assign img3_valid = win2_center_valid;


	assign VGA_R = {8{red_out}};
	assign VGA_G = {8{green_out}};
	assign VGA_B = {8{blue_out}};

	assign VGA_CLK     = pclk;
	assign VGA_BLANK_N = on;
	assign VGA_SYNC_N  = 1'b0;

	reg [27:0] cnt_5s = 28'd0;
	reg [1:0] sel_img = 2'd0;
	
	always @(posedge CLOCK_50) begin
	    if (cnt_5s == 28'd249_999_999) begin
			cnt_5s <= 28'd0;
			if (sel_img == 2'd2) begin
				sel_img <= 2'd0;
			end else begin
				sel_img <= sel_img + 2'd1;
			end
	    end else begin
			cnt_5s <= cnt_5s + 28'd1;
	    end
	end

endmodule

module window_stream #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer COL_W = 9,
	parameter integer ROW_W = 8
) (
	input clk,
	input reset,
	input pixel_in,
	input [COL_W-1:0] column_in,
	input [ROW_W-1:0] row_in,
	input valid_in,
	output [2:0] w_col0,
	output [2:0] w_col1,
	output [2:0] w_col2,
	output [COL_W-1:0] center_column,
	output [ROW_W-1:0] center_row,
	output center_valid,
	output window_valid,
	output border
);

	localparam integer COL_INDEX_W = $clog2(IMG_W);

	localparam [ROW_W-1:0] ROW_ZERO = {(ROW_W){1'b0}};
	localparam [ROW_W-1:0] ROW_ONE  = {{(ROW_W-1){1'b0}}, 1'b1};
	localparam [ROW_W-1:0] ROW_TWO  = {{(ROW_W-2){1'b0}}, 2'b10};
	localparam [ROW_W-1:0] LAST_ROW = IMG_H_LIM - ROW_ONE;

	localparam [COL_W-1:0] COL_ZERO = {(COL_W){1'b0}};
	localparam [COL_W-1:0] COL_ONE  = {{(COL_W-1){1'b0}}, 1'b1};
	localparam [COL_W-1:0] LAST_COL = IMG_W_LIM - COL_ONE;

	localparam [COL_W-1:0] IMG_W_LIM = IMG_W[COL_W-1:0];
	localparam [ROW_W-1:0] IMG_H_LIM = IMG_H[ROW_W-1:0];

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

module majority (
	input [2:0] w_col0,
	input [2:0] w_col1,
	input [2:0] w_col2,
	input center_valid,
	input window_valid,
	input border,
	output pixel_out
);
	wire [3:0] sum_neighbors = {3'b000, w_col0[0]} + {3'b000, w_col0[1]} + {3'b000, w_col0[2]} + 
							   {3'b000, w_col1[0]} +                       {3'b000, w_col1[2]} + 
							   {3'b000, w_col2[0]} + {3'b000, w_col2[1]} + {3'b000, w_col2[2]};

	wire use_filter = center_valid && window_valid && !border;

	wire filtered_pixel = (sum_neighbors > 4) ? 1'b1 : (sum_neighbors < 4) ? 1'b0 : w_col1[1];

	assign pixel_out = center_valid ? (use_filter ? filtered_pixel : w_col1[1]) : 1'b0;

endmodule

module sobel #(
	parameter [4:0] THRESHOLD = 5'd2
) (
	input [2:0] w_col0,
	input [2:0] w_col1,
	input [2:0] w_col2,
	input center_valid,
	input window_valid,
	input border,
	output pixel_out
);
	wire a = w_col2[2];
	wire b = w_col1[2];
	wire c = w_col0[2];
	wire d = w_col2[1];
	wire f = w_col0[1];
	wire g = w_col2[0];
	wire h = w_col1[0];
	wire i = w_col0[0];

	wire [2:0] gx_pos = {2'b00, c} + {1'b0, f, 1'b0} + {2'b00, i};
	wire [2:0] gx_neg = {2'b00, a} + {1'b0, d, 1'b0} + {2'b00, g};
	wire [2:0] gy_pos = {2'b00, a} + {1'b0, b, 1'b0} + {2'b00, c};
	wire [2:0] gy_neg = {2'b00, g} + {1'b0, h, 1'b0} + {2'b00, i};

	wire signed [3:0] gx = $signed({1'b0, gx_pos}) - $signed({1'b0, gx_neg});
	wire signed [3:0] gy = $signed({1'b0, gy_pos}) - $signed({1'b0, gy_neg});
	wire [3:0] abs_gx = gx[3] ? (~gx + 4'd1) : gx;
	wire [3:0] abs_gy = gy[3] ? (~gy + 4'd1) : gy;
	wire [4:0] magnitude = abs_gx + abs_gy;
	wire use_sobel = center_valid && window_valid && !border;

	assign pixel_out = center_valid ? (use_sobel ? (magnitude >= THRESHOLD) : 1'b0) : 1'b0;

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

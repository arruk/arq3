`timescale 1 ps / 1 ps

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


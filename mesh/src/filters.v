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


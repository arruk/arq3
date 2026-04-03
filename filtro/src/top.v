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

	wire clk2 = (mask & pclk & on);
	wire img1;

	rom rom_inst (
		.address(address),
		.clock(pclk),
		.q(img1)
	);

	reg [27:0] cnt_5s = 28'd0;
	reg sel_img = 1'b0;
	
	always @(posedge CLOCK_50) begin
	    if (cnt_5s == 28'd249_999_999) begin
		cnt_5s <= 28'd0;
		sel_img <= ~sel_img;
	    end else begin
		cnt_5s <= cnt_5s + 28'd1;
	    end
	end

	//wire smux = SW[0] ? (mask & on & img1) : img2;
	wire smux = sel_img ? (mask & on & img1) : img2;

	janela janela_inst (
		.pixel_column(pixel_column),
                .pixel_row(pixel_row),
                .mask(mask)
	);

	wire reset = 1'b0;

	wire img2_pixel;
	wire [9:0] img2_row;
	wire [9:0] img2_column;
	wire img2_ready;

	reg [9:0] pipe_column = 10'd0;
	reg [9:0] pipe_row = 10'd0;
	reg pipe_valid = 1'b0;

	always @(posedge pclk) begin
		pipe_column <= pixel_column;
		pipe_row <= pixel_row;
		pipe_valid <= mask & on;
	end


	pipeline pipeline_inst (
		.clk(pclk),
		.reset(reset),
		
		.img1(img1),
		.column(pipe_column),
		.row(pipe_row),
		.valid(pipe_valid),

		.img2_pixel(img2)
	);

	assign VGA_R = {8{red_out}};
	assign VGA_G = {8{green_out}};
	assign VGA_B = {8{blue_out}};

	assign VGA_CLK     = pclk;
	assign VGA_BLANK_N = on;
	assign VGA_SYNC_N  = 1'b0;

endmodule

module pipeline (
	input clk,
	input reset,

	input img1,
	input [9:0] column,
	input [9:0] row,
	input valid,

	output img2_pixel,
	output [9:0] img2_row,
	output [9:0] img2_column,
	output img2_valid
);

	// STAGE 1
	reg s1_p0;
	reg [9:0] s1_c, s1_r;
	reg s1_valid = 1'b0;

	always @(posedge clk) begin
		if (reset) begin
			s1_p0 <= 1'b0;
			s1_c <= 10'd0;
			s1_r <= 10'd0;
			s1_valid <= 1'b0;
		end else begin
			s1_p0 <= img1;
			s1_c <= column;
			s1_r <= row;
			s1_valid <= valid;
		end
	end


	// STAGE 2
	reg [255:0] buf1;

	reg [9:0] s2_c, s2_r;
	reg s2_p0, s2_p1;
	reg s2_valid = 1'b0;
	reg s2_has_prev_row = 1'b0;

	always @(posedge clk) begin
		if (reset) begin
			buf1 <= 256'd0;
			s2_p0 <= 1'b0;
			s2_p1 <= 1'b0;
			s2_c <= 10'd0;
			s2_r <= 10'd0;
			s2_valid <= 1'b0;
			s2_has_prev_row <= 1'b0;
		end else begin
			if (s1_valid) begin
				s2_p0 <= s1_p0;
				s2_p1 <= buf1[s1_c[7:0]];
				buf1[s1_c[7:0]] <= s1_p0;

				s2_c <= s1_c;
				s2_r <= s1_r;
			end else begin
				s2_p0 <= 1'b0;
				s2_p1 <= 1'b0;
			end

			s2_valid <= s1_valid;
			s2_has_prev_row <= s1_valid && (s1_r >= 10'd1);
		end
	end


	// STAGE 3
	reg [255:0] buf2;

	reg s3_p0, s3_p1, s3_p2;
	reg [9:0]  s3_c, s3_r;
	reg s3_has_prev_row = 1'b0;
	reg s3_has_3_rows = 1'b0;

	always @(posedge clk) begin
		if (reset) begin
			buf2 <= 256'd0;
			
			s3_p0 <= 1'b0;
			s3_p1 <= 1'b0;
			s3_p2 <= 1'b0;
			s3_c <= 10'd0;
			s3_r <= 10'd0;
			
			s3_has_prev_row <= 1'b0;
			s3_has_3_rows <= 1'b0;
		end else begin
			if (s2_valid) begin
				s3_p0 <= s2_p0;
				s3_p1 <= s2_p1;
				s3_p2 <= buf2[s2_c[7:0]];
				buf2[s2_c[7:0]] <= s2_p1;

				s3_c <= s2_c;
				s3_r <= s2_r;
			end else begin
				s3_p0 <= 1'b0;
				s3_p1 <= 1'b0;
				s3_p2 <= 1'b0;
			end

			s3_has_prev_row <= s2_has_prev_row;
			s3_has_3_rows <= s2_valid && (s2_r >= 10'd2);
		end
	end

	
	// ESTAGIO 4 
	reg s4_valid = 1'b0;
	reg s4_has_3_rows = 1'b0;
	reg [2:0] s4_w_c0;

	always @(posedge clk) begin
		if (reset) begin
			s4_valid <= 1'b0;
			s4_has_3_rows <= 1'b0;
			s4_w_c0 <= 3'd0;
		end else begin
			s4_valid <= s3_has_prev_row;
			s4_has_3_rows <= s3_has_3_rows;
			s4_w_c0 <= {s3_p2, s3_p1, s3_p0};
		end
	end


	// ESTAGIO 5
	reg [2:0] s5_w_c0;
	reg [2:0] s5_w_c1;
	reg [2:0] s5_w_c2;

	reg s5_col_v0 = 1'b0;
	reg s5_col_v1 = 1'b0;
	reg s5_col_v2 = 1'b0;
	reg s5_col_rows0 = 1'b0;
	reg s5_col_rows1 = 1'b0;
	reg s5_col_rows2 = 1'b0;

	always @(posedge clk) begin
		if (reset) begin
			s5_w_c0 <= 3'd0;
			s5_w_c1 <= 3'd0;
			s5_w_c2 <= 3'd0;
			s5_col_v0 <= 1'b0;
			s5_col_v1 <= 1'b0;
			s5_col_v2 <= 1'b0;
			s5_col_rows0 <= 1'b0;
			s5_col_rows1 <= 1'b0;
			s5_col_rows2 <= 1'b0;
		end else begin
			if (s4_valid) begin
				s5_w_c0 <= s4_w_c0;
				s5_w_c1 <= s5_w_c0;
				s5_w_c2 <= s5_w_c1;

				s5_col_v0 <= 1'b1;
				s5_col_v1 <= s5_col_v0;
				s5_col_v2 <= s5_col_v1;

				s5_col_rows0 <= s4_has_3_rows;
				s5_col_rows1 <= s5_col_rows0;
				s5_col_rows2 <= s5_col_rows1;
			end else begin
				s5_col_v0 <= 1'b0;
				s5_col_v1 <= 1'b0;
				s5_col_v2 <= 1'b0;
				s5_col_rows0 <= 1'b0;
				s5_col_rows1 <= 1'b0;
				s5_col_rows2 <= 1'b0;
			end
		end
	end

	wire s5_valid = s5_col_v1;
	wire s5_wv = s5_col_rows0 && s5_col_rows1 && s5_col_rows2;
	wire [3:0] soma_viz = s5_w_c0[0] + s5_w_c0[1] + s5_w_c0[2] + s5_w_c1[0] + s5_w_c1[2] + s5_w_c2[0] + s5_w_c2[1] + s5_w_c2[2];

	wire filter = s5_wv ? ((soma_viz > 4) ? 1'b1 : (soma_viz < 4) ? 1'b0 : s5_w_c1[1]) : s5_w_c1[1];

	wire pixel = s5_valid ? filter : 1'b0;

	assign img2_pixel = pixel;

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

`timescale 1ns/1ps

module tb_pipeline;
	localparam integer IMG_W = 256;
	localparam integer IMG_H = 128;
	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);
	localparam integer NUM_PIXELS = IMG_W * IMG_H;
	localparam integer DRAIN_CYCLES = 32;
	localparam [COL_W-1:0] IMG_W_COL = IMG_W;
	localparam [ROW_W-1:0] IMG_H_ROW = IMG_H;
	localparam [COL_W-1:0] COL_ONE = {{(COL_W-1){1'b0}}, 1'b1};
	localparam [ROW_W-1:0] ROW_ONE = {{(ROW_W-1){1'b0}}, 1'b1};

	reg clk = 1'b0;
	reg reset = 1'b1;
	reg source_active = 1'b0;
	reg draining = 1'b0;
	reg [COL_W-1:0] src_col = {COL_W{1'b0}};
	reg [ROW_W-1:0] src_row = {ROW_W{1'b0}};
	integer drain_count = 0;

	reg original_frame [0:NUM_PIXELS-1];
	reg filtered_frame [0:NUM_PIXELS-1];
	reg edge_frame [0:NUM_PIXELS-1];

	integer i;

	wire [14:0] rom_address = {src_row[6:0], src_col[7:0]};
	wire img1;

	wire src_valid = source_active && (src_col < IMG_W_COL) && (src_row < IMG_H_ROW);
	wire flush_valid = source_active && (src_col <= IMG_W_COL) && (src_row <= IMG_H_ROW);
	wire img1_pipe = src_valid ? img1 : 1'b0;

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

	wire img2_pixel;
	wire [ROW_W-1:0] img2_row;
	wire [COL_W-1:0] img2_column;
	wire img2_valid;

	wire img3_pixel;
	wire [ROW_W-1:0] img3_row;
	wire [COL_W-1:0] img3_column;
	wire img3_valid;

	always #10 clk = ~clk;

	sim_rom #(
		.ADDR_W(15),
		.DEPTH(32768),
		.INIT_FILE("sim/imagem.mem")
	) rom_inst (
		.address(rom_address),
		.q(img1)
	);

	window_stream #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H),
		.COL_W(COL_W),
		.ROW_W(ROW_W)
	) filter_window_inst (
		.clk(clk),
		.reset(reset),
		.pixel_in(img1_pipe),
		.column_in(src_col),
		.row_in(src_row),
		.valid_in(flush_valid),
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
		.IMG_H(IMG_H),
		.COL_W(COL_W),
		.ROW_W(ROW_W)
	) sobel_window_inst (
		.clk(clk),
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
		.THRESHOLD(5'd2)
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

	function [7:0] pixel_to_gray;
		input pixel_bit;
		begin
			pixel_to_gray = pixel_bit ? 8'd255 : 8'd0;
		end
	endfunction

	task write_frame;
		input [8*64-1:0] file_name;
		input integer frame_id;
		integer fd;
		integer row;
		integer col;
		integer idx;
		begin
			fd = $fopen(file_name, "w");
			if (fd == 0) begin
				$display("erro: nao foi possivel abrir %0s", file_name);
				$finish;
			end

			$fwrite(fd, "P2\n");
			$fwrite(fd, "%0d %0d\n", IMG_W, IMG_H);
			$fwrite(fd, "255\n");

			for (row = 0; row < IMG_H; row = row + 1) begin
				for (col = 0; col < IMG_W; col = col + 1) begin
					idx = (row * IMG_W) + col;
					case (frame_id)
						0: $fwrite(fd, "%0d ", pixel_to_gray(original_frame[idx]));
						1: $fwrite(fd, "%0d ", pixel_to_gray(filtered_frame[idx]));
						default: $fwrite(fd, "%0d ", pixel_to_gray(edge_frame[idx]));
					endcase
				end
				$fwrite(fd, "\n");
			end

			$fclose(fd);
		end
	endtask

	always @(posedge clk) begin
		integer src_idx;
		integer img2_idx;
		integer img3_idx;
		if (reset) begin
			src_col <= {COL_W{1'b0}};
			src_row <= {ROW_W{1'b0}};
			source_active <= 1'b0;
			draining <= 1'b0;
			drain_count <= 0;
		end else begin
			if (source_active) begin
				if (src_valid) begin
					src_idx = (src_row * IMG_W) + src_col;
					original_frame[src_idx] <= img1;
				end

				if (src_col == IMG_W_COL) begin
					src_col <= {COL_W{1'b0}};
					if (src_row == IMG_H_ROW) begin
						src_row <= src_row;
						source_active <= 1'b0;
						draining <= 1'b1;
						drain_count <= 0;
					end else begin
						src_row <= src_row + ROW_ONE;
					end
				end else begin
					src_col <= src_col + COL_ONE;
				end
			end else if (draining) begin
				if (drain_count == DRAIN_CYCLES) begin
					draining <= 1'b0;
				end else begin
					drain_count <= drain_count + 1;
				end
			end

			if (img2_valid && (img2_row < IMG_H_ROW) && (img2_column < IMG_W_COL)) begin
				img2_idx = (img2_row * IMG_W) + img2_column;
				filtered_frame[img2_idx] <= img2_pixel;
			end

			if (img3_valid && (img3_row < IMG_H_ROW) && (img3_column < IMG_W_COL)) begin
				img3_idx = (img3_row * IMG_W) + img3_column;
				edge_frame[img3_idx] <= img3_pixel;
			end
		end
	end

	initial begin
		for (i = 0; i < NUM_PIXELS; i = i + 1) begin
			original_frame[i] = 1'b0;
			filtered_frame[i] = 1'b0;
			edge_frame[i] = 1'b0;
		end

		repeat (4) @(posedge clk);
		reset = 1'b0;
		source_active = 1'b1;

		wait (!source_active && !draining);
		repeat (4) @(posedge clk);

		write_frame("sim/out/original.pgm", 0);
		write_frame("sim/out/filtered.pgm", 1);
		write_frame("sim/out/edges.pgm", 2);

		$display("imagens geradas em sim/out/");
		$finish;
	end

endmodule

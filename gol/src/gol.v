`timescale 1 ps / 1 ps

module delay_raster #(
	parameter integer DELAY_W = 9
) (
	input clk,
	input reset,
	input generation_done,
	input copy_last_q,
	input vga_frame_tick,
	input [DELAY_W-1:0] update_delay_frames,
	output comp_runing
);

	reg compute_running = 1'b1;
	reg delay_active = 1'b0;
	reg [DELAY_W-1:0] delay_frame_count = {DELAY_W{1'b0}};

	wire delay_disabled = (update_delay_frames == {DELAY_W{1'b0}});
	wire [DELAY_W-1:0] delay_last_frame = update_delay_frames - {{(DELAY_W-1){1'b0}}, 1'b1};
	wire delay_done = delay_disabled || (delay_frame_count >= delay_last_frame);

	always @(posedge clk) begin
		if (reset) begin
			compute_running <= 1'b1;
			delay_active <= 1'b0;
			delay_frame_count <= {DELAY_W{1'b0}};

		end else begin

			if (generation_done) begin
				compute_running <= 1'b0;
				delay_active <= 1'b0;
				delay_frame_count <= {DELAY_W{1'b0}};
			end

			if (copy_last_q) begin
				delay_frame_count <= {DELAY_W{1'b0}};
				if (delay_disabled) begin
					compute_running <= 1'b1;
					delay_active <= 1'b0;
				end else begin
					compute_running <= 1'b0;
					delay_active <= 1'b1;
				end
			end else if (delay_active && vga_frame_tick) begin
				if (delay_done) begin
					compute_running <= 1'b1;
					delay_active <= 1'b0;
					delay_frame_count <= {DELAY_W{1'b0}};
				end else begin
					delay_frame_count <= delay_frame_count + {{(DELAY_W-1){1'b0}}, 1'b1};
				end
			end
		end
	end

	assign comp_runing = compute_running;

endmodule

module copy_vga #(
    parameter integer IMG_W = 640,
    parameter integer IMG_H = 480
) (
    input clk,
    input reset,
    input generation_done,
	input vga_update_ready,
	input sim_copy_pixel,

	output [($clog2(IMG_W + 1))-1:0] copy_column,
	output [($clog2(IMG_H + 1))-1:0] copy_row,
	output copy_valid,
	output copy_read_enable,

	output copy_valid_out,
	output [($clog2(IMG_W + 1))-1:0] copy_column_out,
	output [($clog2(IMG_H + 1))-1:0] copy_row_out,
	output copy_pixel_out,
	output copy_last_out
);
    localparam integer COL_W = $clog2(IMG_W + 1);
    localparam integer ROW_W = $clog2(IMG_H + 1);

    localparam [COL_W-1:0] COL_ZERO = {COL_W{1'b0}};
    localparam [ROW_W-1:0] ROW_ZERO = {ROW_W{1'b0}};
    localparam [COL_W-1:0] IMG_W_LIM = IMG_W[COL_W-1:0];
    localparam [ROW_W-1:0] IMG_H_LIM = IMG_H[ROW_W-1:0];
    localparam [COL_W-1:0] LAST_IMG_COLUMN = IMG_W_LIM - {{(COL_W-1){1'b0}}, 1'b1};
    localparam [ROW_W-1:0] LAST_IMG_ROW = IMG_H_LIM - {{(ROW_W-1){1'b0}}, 1'b1};

	reg copy_valid_d = 1'b0;
	reg copy_last_d = 1'b0;
	reg [COL_W-1:0] copy_column_d = COL_ZERO;
	reg [ROW_W-1:0] copy_row_d = ROW_ZERO;

	reg copy_valid_q = 1'b0;
	reg copy_last_q = 1'b0;
	reg [COL_W-1:0] copy_column_q = COL_ZERO;
	reg [ROW_W-1:0] copy_row_q = ROW_ZERO;
	reg copy_pixel_q = 1'b0;

	assign copy_valid_out = copy_valid_q;
	assign copy_column_out = copy_column_q;
	assign copy_row_out = copy_row_q;
	assign copy_pixel_out = copy_pixel_q;
	assign copy_last_out = copy_valid_q && vga_update_ready && copy_last_q;

	reg copy_active = 1'b0;

	wire copy_source_valid = copy_valid && (copy_column < IMG_W_LIM) && (copy_row < IMG_H_LIM);
	wire copy_output_fire = copy_valid_q && vga_update_ready;
	wire copy_step_enable = copy_active && !copy_valid_d && !copy_valid_q;
	wire copy_last_read = copy_read_enable && (copy_column == LAST_IMG_COLUMN) && (copy_row == LAST_IMG_ROW);
	
	assign copy_read_enable = copy_step_enable && copy_source_valid;

    always @(posedge clk) begin
        if (reset) begin
            copy_valid_d <= 1'b0;
            copy_valid_q <= 1'b0;
            copy_last_d <= 1'b0;
            copy_last_q <= 1'b0;
            copy_column_d <= COL_ZERO;
            copy_row_d <= ROW_ZERO;
            copy_column_q <= COL_ZERO;
            copy_row_q <= ROW_ZERO;
            copy_pixel_q <= 1'b0;
            copy_active <= 1'b0;
		end else begin
			if (copy_output_fire) begin
				copy_valid_q <= 1'b0;
				copy_last_q <= 1'b0;

				if (copy_last_q) begin
					copy_active <= 1'b0;
				end
			end

			if (copy_valid_d) begin
				copy_valid_d <= 1'b0;
				copy_last_d <= 1'b0;
				copy_valid_q <= 1'b1;
				copy_last_q <= copy_last_d;
				copy_column_q <= copy_column_d;
				copy_row_q <= copy_row_d;
				copy_pixel_q <= sim_copy_pixel;
			end

			if (copy_read_enable) begin
				copy_valid_d <= 1'b1;
				copy_last_d <= copy_last_read;
				copy_column_d <= copy_column;
				copy_row_d <= copy_row;
			end

			if (generation_done) begin
				copy_active <= 1'b1;
				copy_valid_d <= 1'b0;
				copy_valid_q <= 1'b0;
				copy_last_d <= 1'b0;
				copy_last_q <= 1'b0;
			end
		end
	end

	raster_scanner #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) copy_scanner_inst (
		.clk(clk),
		.reset(reset),
		.restart(generation_done),
		.enable(copy_step_enable),
		.column(copy_column),
		.row(copy_row),
		.valid(copy_valid)
	);


endmodule

module gol_engine #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer DELAY_W = 9
) (
	input clk,
	input reset,
	input [DELAY_W-1:0] update_delay_frames,
	input vga_frame_tick,
	input vga_update_ready,

	output vga_update_valid,
	output [($clog2(IMG_W + 1))-1:0] vga_update_column,
	output [($clog2(IMG_H + 1))-1:0] vga_update_row,
	output vga_update_pixel,
	output vga_update_done
);
	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);

	localparam [COL_W-1:0] COL_ZERO = {COL_W{1'b0}};
	localparam [ROW_W-1:0] ROW_ZERO = {ROW_W{1'b0}};
	localparam [COL_W-1:0] IMG_W_LIM = IMG_W[COL_W-1:0];
	localparam [ROW_W-1:0] IMG_H_LIM = IMG_H[ROW_W-1:0];
	localparam [COL_W-1:0] LAST_IMG_COLUMN = IMG_W_LIM - {{(COL_W-1){1'b0}}, 1'b1};
	localparam [ROW_W-1:0] LAST_IMG_ROW = IMG_H_LIM - {{(ROW_W-1){1'b0}}, 1'b1};

	reg [COL_W-1:0] scan_column_d = COL_ZERO;
	reg [ROW_W-1:0] scan_row_d = ROW_ZERO;
	reg scan_valid_d = 1'b0;
	reg source_valid_d = 1'b0;
	reg use_initial_frame_d = 1'b0;

	always @(posedge clk) begin
		if (reset) begin
			scan_column_d <= COL_ZERO;
			scan_row_d <= ROW_ZERO;
			scan_valid_d <= 1'b0;
			source_valid_d <= 1'b0;
			use_initial_frame_d <= 1'b0;
		end else begin
			scan_column_d <= scan_column;
			scan_row_d <= scan_row;
			scan_valid_d <= compute_running && scan_valid;
			source_valid_d <= source_valid;
			use_initial_frame_d <= !sim_initialized;
		end
	end


	wire generation_done = next_write_enable && (next_column == LAST_IMG_COLUMN) && (next_row == LAST_IMG_ROW);

	reg sim_initialized = 1'b0;
	reg sim_read_bank = 1'b0;
	reg sim_write_bank = 1'b0;

	always @(posedge clk) begin
		if(reset) begin
            sim_initialized <= 1'b0;
            sim_read_bank <= 1'b0;
            sim_write_bank <= 1'b0;
		end else begin
			if(generation_done) begin
                sim_initialized <= 1'b1;
                sim_read_bank <= sim_write_bank;
                sim_write_bank <= !sim_write_bank;
			end
		end
	end


	wire compute_running;

	delay_raster #(
		.DELAY_W(DELAY_W)
	) delay (
        .clk(clk),
        .reset(reset),
		.generation_done(generation_done),
		.copy_last_q(vga_update_done),
		.vga_frame_tick(vga_frame_tick),
		.update_delay_frames(update_delay_frames),
		.comp_runing(compute_running)
	);

    wire [COL_W-1:0] copy_column;
    wire [ROW_W-1:0] copy_row;
    wire copy_valid;
	wire copy_read_enable;

	copy_vga #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) copy (
		.clk(clk),
		.reset(reset),
		.generation_done(generation_done),
		.vga_update_ready(vga_update_ready),
		.sim_copy_pixel(sim_copy_pixel),

		.copy_column(copy_column),
		.copy_row(copy_row),
		.copy_valid(copy_valid),
		.copy_read_enable(copy_read_enable),

		.copy_column_out(vga_update_column),
		.copy_row_out(vga_update_row),
		.copy_valid_out(vga_update_valid),
		.copy_pixel_out(vga_update_pixel),
		.copy_last_out(vga_update_done)
	);

	wire sim_compute_pixel;
	wire sim_copy_pixel;

	wire source_valid = compute_running && scan_valid && (scan_column < IMG_W_LIM) && (scan_row < IMG_H_LIM);

	wire [COL_W-1:0] next_column = win_center_column;
	wire [ROW_W-1:0] next_row = win_center_row;
	wire next_write_enable = win_center_valid;

	double_framebuffer #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) simulation_framebuffer_inst (
		.clk        (clk),
		.reset      (reset),
		.read_bank  (sim_read_bank),
		.write_bank (sim_write_bank),

		.display_read_enable (copy_read_enable),
		.display_read_column (copy_column),
		.display_read_row    (copy_row),
		.display_read_pixel  (sim_copy_pixel),

		.compute_read_enable (sim_initialized && source_valid),
		.compute_read_column (scan_column),
		.compute_read_row    (scan_row),
		.compute_read_pixel  (sim_compute_pixel),

		.write_enable (next_write_enable),
		.write_column (next_column),
		.write_row    (next_row),
		.write_pixel  (next_pixel)
	);


	wire [COL_W-1:0] scan_column;
	wire [ROW_W-1:0] scan_row;
	wire scan_valid;
	wire compute_restart = vga_update_done;

	raster_scanner #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) scanner_inst (
		.clk(clk),
		.reset(reset),
		.restart(compute_restart),
		.enable(compute_running),
		.column(scan_column),
		.row(scan_row),
		.valid(scan_valid)
	);

	wire [2:0] win_w_c0;
	wire [2:0] win_w_c1;
	wire [2:0] win_w_c2;
	wire [ROW_W-1:0] win_center_row;
	wire [COL_W-1:0] win_center_column;
	wire win_center_valid;
	wire win_window_valid;
	wire win_border;

	wire source_pixel = source_valid_d ? (use_initial_frame_d ? initial_pixel : sim_compute_pixel) : 1'b0;

	window_stream #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) window_inst (
		.clk           (clk),
		.reset         (reset),
		.pixel_in      (source_pixel),
		.column_in     (scan_column_d),
		.row_in        (scan_row_d),
		.valid_in      (scan_valid_d),
		.w_col0        (win_w_c0),
		.w_col1        (win_w_c1),
		.w_col2        (win_w_c2),
		.center_row    (win_center_row),
		.center_column (win_center_column),
		.center_valid  (win_center_valid),
		.window_valid  (win_window_valid),
		.border        (win_border)
	);


	wire next_pixel;

	gameoflife rules_inst (
		.w_col0(win_w_c0),
		.w_col1(win_w_c1),
		.w_col2(win_w_c2),

		.center_valid(win_center_valid),
		.window_valid(win_window_valid),
		.border(win_border),
		.pixel_out(next_pixel)
	);

	wire [14:0] compute_rom_address = image_address(scan_column, scan_row);
	wire initial_pixel;

	rom rom_inst_initial_compute (
		.address(compute_rom_address),
		.clock(clk),
		.q(initial_pixel)
	);

    function [14:0] image_address;
        input [COL_W-1:0] column;
        input [ROW_W-1:0] row;
        reg [31:0] column_ext;
        reg [31:0] row_ext;
        reg [31:0] linear_address;
        begin
            column_ext = {{(32-COL_W){1'b0}}, column};
            row_ext = {{(32-ROW_W){1'b0}}, row};
            linear_address = (row_ext * IMG_W) + column_ext;
            image_address = linear_address[14:0];
        end
    endfunction

endmodule

module raster_scanner #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128
) (
	input clk,
	input reset,
	input restart,
	input enable,
	output reg [($clog2(IMG_W + 1))-1:0] column,
	output reg [($clog2(IMG_H + 1))-1:0] row,
	output reg valid
);
	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);

	localparam [COL_W-1:0] COL_ZERO = {COL_W{1'b0}};
	localparam [ROW_W-1:0] ROW_ZERO = {ROW_W{1'b0}};
	localparam [COL_W-1:0] IMG_W_LIM = IMG_W[COL_W-1:0];
	localparam [ROW_W-1:0] IMG_H_LIM = IMG_H[ROW_W-1:0];

	initial begin
		column = COL_ZERO;
		row = ROW_ZERO;
		valid = 1'b1;
	end

	always @(posedge clk) begin
		if (reset || restart) begin
			column <= COL_ZERO;
			row <= ROW_ZERO;
			valid <= 1'b1;
		end else if (enable && valid) begin
			if (column == IMG_W_LIM) begin
				column <= COL_ZERO;
				if (row == IMG_H_LIM) begin
					row <= ROW_ZERO;
					valid <= 1'b0;
				end else begin
					row <= row + {{(ROW_W-1){1'b0}}, 1'b1};
				end
			end else begin
				column <= column + {{(COL_W-1){1'b0}}, 1'b1};
			end
		end
	end
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
					   {3'b000, w_col1[0]} + {3'b000, w_col1[2]} +
					   {3'b000, w_col2[0]} + {3'b000, w_col2[1]} + {3'b000, w_col2[2]};

	wire center = w_col1[1];

	wire newgen = center ? ((sum_n == 2) || (sum_n == 3)) : (sum_n == 3);

	wire use_gol = center_valid && window_valid && !border;

	assign pixel_out = use_gol ? newgen : 1'b0;

endmodule

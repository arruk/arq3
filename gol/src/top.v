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
	localparam integer IMG_W = 20;
	localparam integer IMG_H = 20;
	localparam integer VGA_SCALE = 16;
	localparam integer VGA_OFFSET_X = 80;
	localparam integer VGA_OFFSET_Y = 0;
	localparam integer GOL_DELAY_W = 9;
	localparam [GOL_DELAY_W-1:0] GOL_UPDATE_DELAY_FRAMES = 9'd60;

	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);

	wire pclk;
	wire reset = SW[0];

	wire vga_frame_tick;
	wire vga_update_valid;
	wire [COL_W-1:0] vga_update_column;
	wire [ROW_W-1:0] vga_update_row;
	wire vga_update_pixel;
	wire vga_update_ready;

	vga_display #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H),
		.SCALE(VGA_SCALE),
		.OFFSET_X(VGA_OFFSET_X),
		.OFFSET_Y(VGA_OFFSET_Y)
	) vga_display_inst (
		.clock_50(CLOCK_50),
		.reset(reset),
		.update_ready(vga_update_ready),
		.update_valid(vga_update_valid),
		.update_column(vga_update_column),
		.update_row(vga_update_row),
		.update_pixel(vga_update_pixel),
		.frame_tick(vga_frame_tick),
		.pixel_clock(pclk),

		.VGA_R(VGA_R),
		.VGA_G(VGA_G),
		.VGA_B(VGA_B),
		.VGA_HS(VGA_HS),
		.VGA_VS(VGA_VS),
		.VGA_CLK(VGA_CLK),
		.VGA_BLANK_N(VGA_BLANK_N),
		.VGA_SYNC_N(VGA_SYNC_N)
	);


	gol_engine #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H),
		.DELAY_W(GOL_DELAY_W)
	) gol_engine_inst (
		.clk(pclk),
		.reset(reset),
		.update_delay_frames(GOL_UPDATE_DELAY_FRAMES),
		.vga_frame_tick(vga_frame_tick),
		.vga_update_ready(vga_update_ready),
		.vga_update_valid(vga_update_valid),
		.vga_update_column(vga_update_column),
		.vga_update_row(vga_update_row),
		.vga_update_pixel(vga_update_pixel),
		.vga_update_done()
	);

endmodule

module vga_display #(
	parameter integer IMG_W = 256,
	parameter integer IMG_H = 128,
	parameter integer SCALE = 1,
	parameter integer OFFSET_X = 0,
	parameter integer OFFSET_Y = 0
) (
	input clock_50,
	input reset,
	output update_ready,
	input update_valid,
	input [($clog2(IMG_W + 1))-1:0] update_column,
	input [($clog2(IMG_H + 1))-1:0] update_row,
	input update_pixel,
	output reg frame_tick,
	output pixel_clock,
	output [7:0] VGA_R,
	output [7:0] VGA_G,
	output [7:0] VGA_B,
	output VGA_HS,
	output VGA_VS,
	output VGA_CLK,
	output VGA_BLANK_N,
	output VGA_SYNC_N
);
	localparam integer COL_W = $clog2(IMG_W + 1);
	localparam integer ROW_W = $clog2(IMG_H + 1);
	localparam integer DISPLAY_W = IMG_W * SCALE;
	localparam integer DISPLAY_H = IMG_H * SCALE;

	localparam integer DISPLAY_RIGHT_INT = (DISPLAY_W + OFFSET_X);
	localparam [9:0]   DISPLAY_RIGHT = DISPLAY_RIGHT_INT[9:0];
	localparam [9:0]   DISPLAY_LEFT  = OFFSET_X[9:0];

	localparam integer DISPLAY_BOTTOM_INT = (DISPLAY_H + OFFSET_Y);
	localparam [9:0] DISPLAY_BOTTOM = DISPLAY_BOTTOM_INT[9:0];
	localparam [9:0] DISPLAY_TOP    = OFFSET_Y[9:0];

	localparam integer CLOG_SCALE = $clog2(SCALE);

	wire [9:0] pixel_row;
	wire [9:0] pixel_column;
	wire on;
	wire pclk;
	wire red_out;
	wire green_out;
	wire blue_out;

	VGA_SYNC vga_sync_inst (
		.clock_50Mhz    (clock_50),
		.reset          (reset),
		.red            (display_in_bounds ? display_pixel : 1'b0),
		.green          (display_in_bounds ? display_pixel : 1'b0),
		.blue           (display_in_bounds ? display_pixel : 1'b0),
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

	wire display_fb_pixel;
	wire display_in_bounds = on && (pixel_column >= DISPLAY_LEFT) && (pixel_column < DISPLAY_RIGHT) && (pixel_row >= DISPLAY_TOP) && (pixel_row < DISPLAY_BOTTOM);

	wire [9:0] scaled_column = (pixel_column - DISPLAY_LEFT) >> CLOG_SCALE;
	wire [9:0] scaled_row    = (pixel_row - DISPLAY_TOP) >> CLOG_SCALE;
	wire [COL_W-1:0] framebuffer_read_column = scaled_column[COL_W-1:0];
	wire [ROW_W-1:0] framebuffer_read_row = scaled_row[ROW_W-1:0];
	wire [14:0] rom_address = display_in_bounds ? image_address(framebuffer_read_column, framebuffer_read_row) : 15'd0;
	wire rom_pixel;
	wire display_pixel = vga_buffer_valid ? display_fb_pixel : rom_pixel;

	vga_framebuffer #(
		.IMG_W(IMG_W),
		.IMG_H(IMG_H)
	) framebuffer_inst (
		.clk   (pclk),
		.reset (reset),

		.read_enable (vga_buffer_valid && display_in_bounds),
		.read_column (framebuffer_read_column),
		.read_row    (framebuffer_read_row),
		.read_pixel  (display_fb_pixel),

			.write_enable (update_valid && update_ready),
		.write_column (update_column),
		.write_row    (update_row),
		.write_pixel  (update_pixel)
	);

	reg vga_buffer_valid = 1'b0;
	always @(posedge pclk) begin
		if (reset) begin
			vga_buffer_valid <= 1'b0;
		end else if (update_valid && update_ready &&
		             (update_column == (IMG_W[COL_W-1:0] - {{(COL_W-1){1'b0}}, 1'b1})) &&
		             (update_row == (IMG_H[ROW_W-1:0] - {{(ROW_W-1){1'b0}}, 1'b1}))) begin
			vga_buffer_valid <= 1'b1;
		end
	end

	rom rom_inst_initial_display (
		.address(rom_address),
		.clock(pclk),
		.q(rom_pixel)
	);


	wire frame_start = on && (pixel_column == 10'd0) && (pixel_row == 10'd0);
	reg frame_start_d = 1'b0;
	always @(posedge pclk) begin
		if (reset) begin
			frame_start_d <= 1'b0;
			frame_tick <= 1'b0;
		end else begin
			frame_start_d <= frame_start;
			frame_tick <= frame_start && !frame_start_d;
		end
	end

	assign VGA_R = {8{red_out}};
	assign VGA_G = {8{green_out}};
	assign VGA_B = {8{blue_out}};
	assign VGA_CLK = pclk;
	assign VGA_BLANK_N = on;
	assign VGA_SYNC_N = 1'b0;
	
	assign pixel_clock = pclk;

	assign update_ready = on && !display_in_bounds;

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

module vga_framebuffer #(
	parameter integer IMG_W = 640,
	parameter integer IMG_H = 480
) (
	input clk,
	input reset,

	input read_enable,
	input [($clog2(IMG_W + 1))-1:0] read_column,
	input [($clog2(IMG_H + 1))-1:0] read_row,
	output read_pixel,

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
	wire [ADDR_W-1:0] read_addr = address(read_column[COL_INDEX_W-1:0], read_row[ROW_INDEX_W-1:0]);
	wire [ADDR_W-1:0] write_addr = address(write_column[COL_INDEX_W-1:0], write_row[ROW_INDEX_W-1:0]);
	wire memory_read_pixel;

	simple_dual_port_ram #(
		.ADDR_W(ADDR_W),
		.DATA_W(1),
		.DEPTH(FRAME_SIZE)
	) fb_memory (
		.clk(clk),

		.write_enable (write_in_bounds),
		.write_addr   (write_addr),
		.write_data   (write_pixel),

		.read_enable (read_in_bounds),
		.read_addr   (read_addr),
		.read_data   (memory_read_pixel)
	);

	reg read_in_bounds_q = 1'b0;

	always @(posedge clk) begin
		if (reset) begin
			read_in_bounds_q <= 1'b0;
		end else begin
			read_in_bounds_q <= read_in_bounds;
		end
	end

	assign read_pixel = read_in_bounds_q ? memory_read_pixel : 1'b0;

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

module sim_rom #(
	parameter integer ADDR_W = 15,
	parameter integer DEPTH = 32768,
	parameter INIT_FILE = "sim/imagem.mem"
) (
	input [ADDR_W-1:0] address,
	output q
);
	reg mem [0:DEPTH-1];
	integer i;

	initial begin
		for (i = 0; i < DEPTH; i = i + 1) begin
			mem[i] = 1'b0;
		end
		$readmemh(INIT_FILE, mem);
	end

	assign q = mem[address];

endmodule

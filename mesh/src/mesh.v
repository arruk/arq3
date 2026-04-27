module mesh_core #(
	parameter integer PKT_W = 1;
) (
	input north_in_valid;
	output north_in_ready;
	input north_in_pkt[PKT_W-1:0];
	
	output north_out_valid;
	input north_out_ready;
	output north_out_pkt[PKT_W-1:0];

	input south_in_valid;
	output south_in_ready;
	input south_in_pkt[PKT_W-1:0];
	
	output south_out_valid;
	input south_out_ready;
	output south_out_pkt[PKT_W-1:0];

	input west_in_valid;
	output west_in_ready;
	input west_in_pkt[PKT_W-1:0];
	
	output west_out_valid;
	input west_out_ready;
	output west_out_pkt[PKT_W-1:0];

	input east_in_valid;
	output east_in_ready;
	input east_in_pkt[PKT_W-1:0];
	
	output east_out_valid;
	input east_out_ready;
	output east_out_pkt[PKT_W-1:0];	
);

	


endmodule

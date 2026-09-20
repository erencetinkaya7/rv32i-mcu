module register_file (
	input logic clk,
	input logic write_enable,

	input logic [4:0] rs1_addr,
	input logic [4:0] rs2_addr,
	input logic [4:0] rd_addr,

	input logic [31:0] rd_data,
	
	output logic [31:0] rs1_data,
	output logic [31:0] rs2_data,

	output logic [31:0] debug_a0
);

logic [31:0] registers [0:31];

assign debug_a0 = registers[10]; //a0 = x10 disaridan okumaya acik.

// WB writes are visible to ID in the same cycle, avoiding stale register reads.
assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 :
                  (write_enable && rd_addr != 5'b0 && rd_addr == rs1_addr) ? rd_data :
                  registers[rs1_addr];

assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 :
                  (write_enable && rd_addr != 5'b0 && rd_addr == rs2_addr) ? rd_data :
                  registers[rs2_addr];

always_ff @(posedge clk) begin
	if (write_enable && rd_addr != 5'b0)
		registers[rd_addr] <= rd_data;
end

endmodule

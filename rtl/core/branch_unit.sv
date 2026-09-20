module branch_unit (
	input logic [31:0] rs1_data,
	input logic [31:0] rs2_data,
	input logic [2:0] funct3,
	input logic branch_enable,
	output logic branch_taken
);

localparam logic [2:0] BR_BEQ  = 3'b000;
localparam logic [2:0] BR_BNE  = 3'b001;
localparam logic [2:0] BR_BLT  = 3'b100;
localparam logic [2:0] BR_BGE  = 3'b101;
localparam logic [2:0] BR_BLTU = 3'b110;
localparam logic [2:0] BR_BGEU = 3'b111;

always_comb begin
	branch_taken = 1'b0;

	if (branch_enable) begin
		case (funct3)
			BR_BEQ: branch_taken = (rs1_data == rs2_data);
			BR_BNE: branch_taken = (rs1_data != rs2_data);
			BR_BLT: branch_taken = ($signed(rs1_data) < $signed(rs2_data));
			BR_BGE: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
			BR_BLTU: branch_taken = (rs1_data < rs2_data);
			BR_BGEU: branch_taken = (rs1_data >= rs2_data);
			
			default: branch_taken = 1'b0;	
		endcase
	end
end

endmodule
	

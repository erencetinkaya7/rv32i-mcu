module immediate_generator (
	
	input logic [31:0] instruction,
	input logic [2:0] imm_sel,

	output logic [31:0] immediate
);


localparam logic [2:0] IMM_I = 3'b000;
localparam logic [2:0] IMM_S = 3'b001;
localparam logic [2:0] IMM_B = 3'b010;
localparam logic [2:0] IMM_U = 3'b011;
localparam logic [2:0] IMM_J = 3'b100;

always_comb begin
	case (imm_sel)
		IMM_I: immediate = {{20{instruction[31]}}, instruction[31:20]};
		IMM_S: immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
		IMM_B: immediate = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
		IMM_U: immediate = {instruction[31:12], 12'b0};
		IMM_J: immediate = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
	
		default: immediate = 32'b0;
	endcase
end
endmodule

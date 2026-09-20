module control_unit (
	input logic [6:0] opcode,
	input logic [2:0] funct3,
	
	output logic reg_write,
	output logic alu_src,
	output logic [2:0] imm_sel,
	output logic mem_write,
	output logic [1:0] result_src,
	
	output logic branch_enable,
	output logic jump,
	output logic jalr,
	output logic [1:0] alu_a_sel,

	output logic uses_rs1,
	output logic uses_rs2
);

localparam logic [2:0] IMM_I = 3'b000;
localparam logic [2:0] IMM_S = 3'b001;
localparam logic [2:0] IMM_B = 3'b010;
localparam logic [2:0] IMM_U = 3'b011;
localparam logic [2:0] IMM_J = 3'b100;

localparam logic [1:0] ALU_A_RS1  = 2'b00;
localparam logic [1:0] ALU_A_PC   = 2'b01;
localparam logic [1:0] ALU_A_ZERO = 2'b10;

always_comb begin
	jalr = 1'b0;
	jump = 1'b0;
	branch_enable = 1'b0;
	imm_sel = IMM_I;
	alu_a_sel = ALU_A_RS1;
	reg_write = 1'b0;
	alu_src = 1'b0;
	mem_write = 1'b0;
	result_src = 2'b0;
	uses_rs1 = 1'b0;
	uses_rs2 = 1'b0;

	case (opcode) // R-type
		7'b0110011: begin
			reg_write = 1'b1;
			alu_src = 1'b0;
			mem_write = 1'b0;
			result_src = 2'b0;
			uses_rs1 = 1'b1;
			uses_rs2 = 1'b1;
		end
		
		7'b0010011: begin // I-type
			reg_write = 1'b1;
			alu_src = 1'b1;
			imm_sel = IMM_I;
			mem_write = 1'b0;
			result_src = 2'b0;
			uses_rs1 = 1'b1;
		end
		
		7'b0000011: begin //lw
			reg_write = 1'b1;
			alu_src = 1'b1;
			imm_sel = IMM_I;
			mem_write = 1'b0;
			result_src = 2'b01;
			uses_rs1 = 1'b1;
		end

		7'b0100011: begin //sw
			reg_write = 1'b0;
			alu_src = 1'b1;
			imm_sel = IMM_S;
			mem_write = 1'b1;
			uses_rs1 = 1'b1;
			uses_rs2 = 1'b1;
		end

		7'b1100011: begin // B-type
			reg_write = 1'b0;
			imm_sel = IMM_B;
			branch_enable = 1'b1;
			uses_rs1 = 1'b1;
			uses_rs2 = 1'b1;
		end

		7'b0110111: begin // LUI
			reg_write = 1'b1;
			alu_src = 1'b1;
			alu_a_sel = ALU_A_ZERO;
			imm_sel = IMM_U;
			result_src = 2'b0;
		end

		7'b0010111: begin // AUIPC
			reg_write = 1'b1;
			alu_src = 1'b1;
			alu_a_sel = ALU_A_PC;
			imm_sel = IMM_U;
			result_src = 2'b0;
		end			

		7'b1101111: begin // JAL
			reg_write = 1'b1;
			imm_sel = IMM_J;
			jump = 1'b1;
			result_src = 2'b10;
		end

		7'b1100111: begin // JALR
			reg_write = 1'b1;
			alu_src = 1'b1;
			alu_a_sel = ALU_A_RS1;
			imm_sel = IMM_I;
			jalr = 1'b1;
			result_src = 2'b10;
			uses_rs1 = 1'b1;
		end

        7'b1110011: begin // SYSTEM
            case (funct3)
                3'b001,   // CSRRW
                3'b010: begin // CSRRS
                    reg_write = 1'b1;
                    uses_rs1  = 1'b1;
                end
                default: ;
            endcase
        end

		default: ;
	endcase
end

endmodule

// ID/EX pipeline register
// Stores decode-stage data and control for execution.

module id_ex_reg (

    input logic clk,
    input logic reset,
    input logic bubble,

    // Decode data
    input logic [31:0] pc_in,
    input logic [31:0] pc_plus4_in,
    input logic [31:0] rs1_data_in,
    input logic [31:0] rs2_data_in,
    input logic [31:0] immediate_in,

    input logic [4:0] rs1_in,
    input logic [4:0] rs2_in,
    input logic [4:0] rd_in,
    input logic [2:0] funct3_in,
    input logic [6:0] funct7_in,
    input logic [6:0] opcode_in,

    // Control
    input logic       reg_write_in,
    input logic       alu_src_in,
    input logic [1:0] alu_a_sel_in,
    input logic       mem_write_in,
    input logic [1:0] result_src_in,
    input logic       branch_enable_in,
    input logic       jump_in,
    input logic       jalr_in,

    // Decode data outputs
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus4_out,
    output logic [31:0] rs1_data_out,
    output logic [31:0] rs2_data_out,
    output logic [31:0] immediate_out,

    output logic [4:0] rs1_out,
    output logic [4:0] rs2_out,
    output logic [4:0] rd_out,
    output logic [2:0] funct3_out,
    output logic [6:0] funct7_out,
    output logic [6:0] opcode_out,

    // Control outputs
    output logic       reg_write_out,
    output logic       alu_src_out,
    output logic [1:0] alu_a_sel_out,
    output logic       mem_write_out,
    output logic [1:0] result_src_out,
    output logic       branch_enable_out,
    output logic       jump_out,
    output logic       jalr_out

);


// Capture decode-stage data and control
    always_ff @(posedge clk) begin
        if (reset) begin
            pc_out            <= 32'b0;
            pc_plus4_out      <= 32'b0;
            rs1_data_out      <= 32'b0;
            rs2_data_out      <= 32'b0;
            immediate_out     <= 32'b0;

            rs1_out           <= 5'b0;
            rs2_out           <= 5'b0;
            rd_out            <= 5'b0;
            funct3_out        <= 3'b0;
            funct7_out        <= 7'b0;
            opcode_out        <= 7'b0;

            reg_write_out     <= 1'b0;
            alu_src_out       <= 1'b0;
            alu_a_sel_out     <= 2'b0;
            mem_write_out     <= 1'b0;
            result_src_out    <= 2'b0;
            branch_enable_out <= 1'b0;
            jump_out          <= 1'b0;
            jalr_out          <= 1'b0;
        end

        // Insert a NOP into EX while the dependent instruction remains in ID.
        else if (bubble) begin
            pc_out            <= 32'b0;
            pc_plus4_out      <= 32'b0;
            rs1_data_out      <= 32'b0;
            rs2_data_out      <= 32'b0;
            immediate_out     <= 32'b0;

            rs1_out           <= 5'b0;
            rs2_out           <= 5'b0;
            rd_out            <= 5'b0;
            funct3_out        <= 3'b0;
            funct7_out        <= 7'b0;
            opcode_out        <= 7'b0;

            reg_write_out     <= 1'b0;
            alu_src_out       <= 1'b0;
            alu_a_sel_out     <= 2'b0;
            mem_write_out     <= 1'b0;
            result_src_out    <= 2'b0;
            branch_enable_out <= 1'b0;
            jump_out          <= 1'b0;
            jalr_out          <= 1'b0;
        end
        else begin
            pc_out            <= pc_in;
            pc_plus4_out      <= pc_plus4_in;
            rs1_data_out      <= rs1_data_in;
            rs2_data_out      <= rs2_data_in;
            immediate_out     <= immediate_in;

            rs1_out           <= rs1_in;
            rs2_out           <= rs2_in;
            rd_out            <= rd_in;
            funct3_out        <= funct3_in;
            funct7_out        <= funct7_in;
            opcode_out        <= opcode_in;

            reg_write_out     <= reg_write_in;
            alu_src_out       <= alu_src_in;
            alu_a_sel_out     <= alu_a_sel_in;
            mem_write_out     <= mem_write_in;
            result_src_out    <= result_src_in;
            branch_enable_out <= branch_enable_in;
            jump_out          <= jump_in;
            jalr_out          <= jalr_in;
        end
    end


endmodule

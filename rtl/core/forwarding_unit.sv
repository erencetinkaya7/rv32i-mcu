module forwarding_unit (
    
    input  logic [4:0] ex_rs1,
    input  logic [4:0] ex_rs2,

    input  logic [4:0] mem_rd,
    input  logic       mem_reg_write,
    input  logic [1:0] mem_result_src,

    input  logic [4:0] wb_rd,
    input  logic       wb_reg_write,

    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    always_comb begin

        // Default: use register-file values
        forward_a = 2'b00;
        forward_b = 2'b00;

        // MEM -> EX forwarding
        if (mem_reg_write &&
            (mem_rd != 5'd0) &&
            (mem_result_src != 2'b01) &&
            (mem_rd == ex_rs1))
            forward_a = 2'b10;

        if (mem_reg_write &&
            (mem_rd != 5'd0) &&
            (mem_result_src != 2'b01) &&
            (mem_rd == ex_rs2))
            forward_b = 2'b10;

        // WB -> EX forwarding
        // Only if a newer MEM-stage result is not already selected
        if (wb_reg_write &&
            (wb_rd != 5'd0) &&
            (wb_rd == ex_rs1) &&
            (forward_a == 2'b00))
            forward_a = 2'b01;

        if (wb_reg_write &&
            (wb_rd != 5'd0) &&
            (wb_rd == ex_rs2) &&
            (forward_b == 2'b00))
            forward_b = 2'b01;

    end

endmodule

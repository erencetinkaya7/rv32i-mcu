module hazard_unit (

    input logic [4:0] ex_rd,
    input logic       ex_reg_write,
    input logic [1:0] ex_result_src,

    input logic [4:0] id_rs1,
    input logic [4:0] id_rs2,
    input logic       id_uses_rs1,
    input logic       id_uses_rs2,

    output logic       load_use_hazard
);

    always_comb begin
        load_use_hazard = ex_reg_write &&
            (ex_result_src == 2'b01) &&
            (ex_rd != 5'd0) &&
            (
                (id_uses_rs1 && (ex_rd == id_rs1)) ||
                (id_uses_rs2 && (ex_rd == id_rs2))
            );
    end

endmodule

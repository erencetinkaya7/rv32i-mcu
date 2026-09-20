// IF/ID pipeline register
// Stores fetch-stage outputs for the decode stage.

module if_id_reg (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush,

    input  logic [31:0] pc_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [31:0] instruction_in,

    output logic [31:0] pc_out,
    output logic [31:0] pc_plus4_out,
    output logic [31:0] instruction_out,
    output logic        valid_out
);


    // Capture fetch-stage values
    always_ff @(posedge clk) begin
        if (reset) begin
            pc_out          <= 32'b0;
            pc_plus4_out    <= 32'b0;
            instruction_out <= 32'h0000_0013;
            valid_out       <= 1'b0;
        end else if (flush) begin
            pc_out          <= 32'b0;
            pc_plus4_out    <= 32'b0;
            instruction_out <= 32'h0000_0013;
            valid_out       <= 1'b0;
        end else if (enable) begin
            pc_out          <= pc_in;
            pc_plus4_out    <= pc_plus4_in;
            instruction_out <= instruction_in;
            valid_out       <= 1'b1;
        end
    end


endmodule

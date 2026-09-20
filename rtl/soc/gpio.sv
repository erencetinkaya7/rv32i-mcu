// Memory-mapped GPIO output register.

module gpio (
    input  logic        clk,
    input  logic        reset,
    input  logic        write_enable,
    input  logic [31:0] write_data,
    input  logic        btn,
    output logic [31:0] gpio_out,
    output logic [31:0] read_data
);

    logic btn_meta;
    logic btn_sync;

    always_ff @(posedge clk) begin
        if (reset) begin
            gpio_out <= 32'b0;
            btn_meta <= 1'b1;
            btn_sync <= 1'b1;
        end else begin
            // Two flip-flops reduce metastability risk from the physical button.
            btn_meta <= btn;
            btn_sync <= btn_meta;

            if (write_enable)
                gpio_out <= write_data;
        end
    end

    // The board button is active-low; software reads a synchronized press as 1.
    assign read_data = {31'b0, ~btn_sync};

endmodule

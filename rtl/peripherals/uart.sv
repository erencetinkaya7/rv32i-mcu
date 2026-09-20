// UART peripheral with TX and RX
module uart #(
    parameter integer CLOCK_FREQ = 27_000_000,
    parameter integer BAUD_RATE  = 115_200
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        write_enable,

    input  logic [31:0] write_data,
    output logic [31:0] read_data,
    output logic        tx,

    input  logic        rx,
    input  logic        rx_clear,

    output logic [7:0]  rx_data,
    output logic        rx_data_valid,
    output logic        rx_framing_error
);

    logic busy;
    logic start;

 // A write while busy is ignored; software polls the status register first.
    assign start     = write_enable && !busy;
    assign read_data = {31'b0, busy};

    uart_tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) tx_unit (
        .clk     (clk),
        .reset   (reset),
        .start   (start),
        .data_in (write_data[7:0]),
        .tx      (tx),
        .busy    (busy)
    );

// UART receiver
    uart_rx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) rx_unit (
        .clk           (clk),
        .reset         (reset),
        .rx            (rx),
        .clear         (rx_clear),
        .data_out      (rx_data),
        .data_valid    (rx_data_valid),
        .framing_error (rx_framing_error)
    );
endmodule

// 8N1 UART transmitter
module uart_tx #(
    parameter integer CLOCK_FREQ = 27_000_000,
    parameter integer BAUD_RATE  = 115_200
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       start,
    input  logic [7:0] data_in,
    output logic       tx,
    output logic       busy
);

    localparam integer CLKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
    localparam integer BAUD_COUNTER_WIDTH = $clog2(CLKS_PER_BIT);
    localparam logic [BAUD_COUNTER_WIDTH-1:0] BAUD_LAST = BAUD_COUNTER_WIDTH'(CLKS_PER_BIT - 1);
    logic [BAUD_COUNTER_WIDTH-1:0] baud_counter;
    logic [2:0] bit_index;
    logic [7:0] tx_data;

    typedef enum logic [1:0] { IDLE, START, DATA, STOP } state_t;
    state_t state;

    always_ff @(posedge clk) begin
        if (reset) begin
            state        <= IDLE;
            tx           <= 1'b1;
            busy         <= 1'b0;
            baud_counter <= '0;
            bit_index    <= '0;
            tx_data      <= '0;
        end else begin
            case (state)
                IDLE: begin
                    tx           <= 1'b1;
                    busy         <= 1'b0;
                    baud_counter <= '0;
                    bit_index    <= '0;
                    if (start) begin
                        tx_data <= data_in;
                        busy    <= 1'b1;
                        tx      <= 1'b0;
                        state   <= START;
                    end
                end
                START: begin
                    if (baud_counter == BAUD_LAST) begin
                        baud_counter <= '0;
                        bit_index    <= '0;
                        tx           <= tx_data[0];
                        state        <= DATA;
                    end else
                        baud_counter <= baud_counter + 1'b1;
                end
                DATA: begin
                    if (baud_counter == BAUD_LAST) begin
                        baud_counter <= '0;
                        if (bit_index == 3'd7) begin
                            tx    <= 1'b1;
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            tx        <= tx_data[bit_index + 1'b1];
                        end
                    end else
                        baud_counter <= baud_counter + 1'b1;
                end
                STOP: begin
                    if (baud_counter == BAUD_LAST) begin
                        baud_counter <= '0;
                        busy         <= 1'b0;
                        state        <= IDLE;
                    end else
                        baud_counter <= baud_counter + 1'b1;
                end
            endcase
        end
    end
endmodule

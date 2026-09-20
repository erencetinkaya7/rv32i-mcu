// 8N1 UART Receiver.

module uart_rx #(
    parameter integer CLOCK_FREQ = 27_000_000,
    parameter integer BAUD_RATE  = 115_200
) (
    input logic clk,
    input logic reset,
    input logic rx,
    input logic clear,

    output logic [7:0] data_out,
    output logic       data_valid,
    output logic       framing_error
);

// Timing
    localparam integer CLKS_PER_BIT = CLOCK_FREQ / BAUD_RATE; // 27 MHz / 115200 ≈ 234 clock
    localparam integer HALF_BIT_CLKS = CLKS_PER_BIT / 2;
    localparam integer COUNTER_WIDTH = $clog2(CLKS_PER_BIT);

    logic [COUNTER_WIDTH-1:0] baud_counter;
    localparam logic [COUNTER_WIDTH-1:0] HALF_BIT_LAST = HALF_BIT_CLKS[COUNTER_WIDTH-1:0] - 1'b1;
    localparam logic [COUNTER_WIDTH-1:0] BIT_LAST      = CLKS_PER_BIT[COUNTER_WIDTH-1:0] - 1'b1;
    logic [2:0]               bit_index;
    logic [7:0]               rx_data;

// RX input synchronizer
    logic rx_meta;
    logic rx_sync;

// Receive state
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state;

// RX input synchronizer and state registers
    always_ff @(posedge clk) begin
        if (reset) begin
            rx_meta       <= 1'b1;
            rx_sync       <= 1'b1;
            baud_counter  <= '0;
            bit_index     <= '0;
            rx_data       <= '0;
            data_out      <= '0;
            data_valid    <= 1'b0;
            framing_error <= 1'b0;
            state         <= IDLE;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;

            if (clear) begin
                data_valid    <= 1'b0;
                framing_error <= 1'b0;
            end

            // Receive state machine
            case (state)
                IDLE: begin
                    baud_counter <= '0;
                    bit_index    <= '0;

                    if (rx_sync == 1'b0)
                        state <= START;
                end

                START: begin
                    if (baud_counter == HALF_BIT_LAST) begin
                        baud_counter <= '0;

                        // Confirm that the line is still low at the start-bit center.
                        if (rx_sync == 1'b0) begin
                            bit_index <= '0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA: begin
                    if (baud_counter == BIT_LAST) begin
                        baud_counter <= '0;
                        rx_data[bit_index] <= rx_sync;

                        if (bit_index == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                STOP: begin
                    if (baud_counter == BIT_LAST) begin
                        baud_counter <= '0;

                        if (rx_sync == 1'b1) begin
                            data_out   <= rx_data;
                            data_valid <= 1'b1;
                        end else begin
                            framing_error <= 1'b1;
                        end

                        state <= IDLE;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

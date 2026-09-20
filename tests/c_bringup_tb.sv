`timescale 1ns/1ps

// Check the first bare-metal C program on the complete SoC.
module c_bringup_tb;
    localparam integer CLKS_PER_BIT = 10;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic btn = 1'b0;
    logic uart_rx = 1'b1;

    logic [31:0] debug_a0;
    logic [31:0] gpio_out;
    logic uart_tx;

    always #5 clk = ~clk;

    // Save the complete C bring-up waveform.
    initial begin
        $dumpfile("build/waves/c_bringup.vcd");
        $dumpvars(0, c_bringup_tb);
    end   

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE ("build/software/imem.hex"),
        .DMEM_INIT_FILE ("build/software/dmem.hex"),
        .UART_CLOCK_FREQ(1000),
        .UART_BAUD_RATE (100)
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .btn      (btn),
        .uart_rx  (uart_rx),
        .debug_a0 (debug_a0),
        .gpio_out (gpio_out),
        .uart_tx  (uart_tx)
    );

    // Drive one UART bit into the SoC receiver.
    task automatic send_uart_bit(input logic value);
        begin
            uart_rx = value;
            repeat (CLKS_PER_BIT) @(negedge clk);
        end
    endtask

    // Send one 8N1 UART frame, least-significant data bit first.
    task automatic send_uart_byte(input logic [7:0] value);
        integer bit_index;
        begin
            send_uart_bit(0);

            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                send_uart_bit(value[bit_index]);

            send_uart_bit(1);
        end
    endtask

    task automatic check_uart_bit(input logic expected);
        begin
            @(negedge clk);
            if (uart_tx !== expected)
                $fatal(1, "FAIL: UART bit is %b, expected %b",
                       uart_tx, expected);

            repeat (CLKS_PER_BIT - 1) @(negedge clk);
        end
    endtask

    task automatic check_uart_byte(input logic [7:0] expected);
        integer bit_index;
        begin
            @(negedge uart_tx);
            check_uart_bit(1'b0);

            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                check_uart_bit(expected[bit_index]);

            check_uart_bit(1'b1);
        end
    endtask

    task automatic check_gpio_pattern(input logic [31:0] expected);
        begin
            while (gpio_out !== expected)
                @(posedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        check_uart_byte("C");
        check_uart_byte(" ");
        check_uart_byte("R");
        check_uart_byte("E");
        check_uart_byte("A");
        check_uart_byte("D");
        check_uart_byte("Y");
        check_uart_byte(8'h0a);
        send_uart_byte("K");
        check_uart_byte("K");


        check_gpio_pattern(32'd1);
        check_gpio_pattern(32'd2);
        check_gpio_pattern(32'd4);

        $display("PASS: C program reached UART TX, UART RX echo, timer and GPIO");
        $finish;
    end

    // A broken program must fail instead of waiting forever.
    initial begin
        repeat (10000) @(posedge clk);
        $fatal(1, "FAIL: C bring-up simulation timeout");
    end
endmodule

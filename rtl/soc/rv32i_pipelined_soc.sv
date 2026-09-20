// Pipelined RV32I SoC

module rv32i_pipelined_soc #(
    parameter IMEM_INIT_FILE = "",
    parameter DMEM_INIT_FILE = "",
    parameter integer UART_CLOCK_FREQ = 27_000_000,
    parameter integer UART_BAUD_RATE  = 115_200
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        btn,
    input  logic        uart_rx,

    output logic [31:0] debug_a0,
    output logic [31:0] gpio_out,
    output logic        uart_tx
);

    // MMIO address map
    localparam logic [31:0] DATA_RAM_BASE       = 32'h0001_0000;
    localparam logic [31:0] GPIO_OUT_ADDR       = 32'h1000_0000;
    localparam logic [31:0] GPIO_IN_ADDR        = 32'h1000_0004;
    localparam logic [31:0] UART_TX_ADDR        = 32'h2000_0000;
    localparam logic [31:0] UART_STATUS_ADDR    = 32'h2000_0004;
    localparam logic [31:0] UART_RX_DATA_ADDR   = 32'h2000_0008;
    localparam logic [31:0] UART_RX_STATUS_ADDR = 32'h2000_000C;
    localparam logic [31:0] UART_RX_CLEAR_ADDR  = 32'h2000_0010;
    localparam logic [31:0] TIMER_LOAD_ADDR     = 32'h3000_0000;
    localparam logic [31:0] TIMER_STATUS_ADDR   = 32'h3000_0004;

    // Instruction bus
    logic [31:0] instruction_address;
    logic [31:0] instruction_data;

    // CPU data bus
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic [31:0] data_read_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;

    // RAM read path
    logic [31:0] ram_read_data;
    logic [31:0] gpio_read_data;
    logic [31:0] uart_read_data;
    logic [31:0] timer_read_data;
    logic [7:0]  uart_rx_data;
    logic        uart_rx_data_valid;
    logic        uart_rx_framing_error;

    // Address decoder
    logic ram_selected;
    logic gpio_out_selected;
    logic gpio_in_selected;
    logic uart_tx_selected;
    logic uart_status_selected;
    logic timer_load_selected;
    logic timer_status_selected;

    logic timer_busy;
    logic timer_done;

    logic uart_rx_data_selected;
    logic uart_rx_status_selected;
    logic uart_rx_clear_selected;

    // Data RAM: 0x0001_0000 - 0x0001_00FF
    assign ram_selected = (data_address[31:8] == DATA_RAM_BASE[31:8]);
    assign gpio_out_selected    = (data_address == GPIO_OUT_ADDR);
    assign gpio_in_selected     = (data_address == GPIO_IN_ADDR);
    assign uart_tx_selected     = (data_address == UART_TX_ADDR);
    assign uart_status_selected = (data_address == UART_STATUS_ADDR);
    assign timer_load_selected  = (data_address == TIMER_LOAD_ADDR);
    assign timer_status_selected = (data_address == TIMER_STATUS_ADDR);
    assign uart_rx_data_selected   = (data_address == UART_RX_DATA_ADDR);
    assign uart_rx_status_selected = (data_address == UART_RX_STATUS_ADDR);
    assign uart_rx_clear_selected  = (data_address == UART_RX_CLEAR_ADDR);

    // Instruction memory
    instruction_memory #(
        .INIT_FILE(IMEM_INIT_FILE)
    ) imem (
        .pc          (instruction_address),
        .instruction (instruction_data)
    );

    // Pipelined CPU
    rv32i_pipelined_core cpu (
        .clk                 (clk),
        .reset               (reset),
        .timer_irq           (timer_done),
        .instruction_data    (instruction_data),
        .instruction_address (instruction_address),
        .data_read_data      (data_read_data),
        .data_address        (data_address),
        .data_write_data     (data_write_data),
        .data_mem_write      (data_mem_write),
        .data_funct3         (data_funct3),
        .debug_a0            (debug_a0)
    );

    // Data RAM
    data_memory #(
        .INIT_FILE(DMEM_INIT_FILE)
    ) dmem (
        .clk        (clk),
        .mem_write  (data_mem_write && ram_selected),
        .address    (data_address),
        .write_data (data_write_data),
        .funct3     (data_funct3),
        .read_data  (ram_read_data)
    );

    // GPIO output register
    gpio gpio_periph (
        .clk          (clk),
        .reset        (reset),
        .write_enable (data_mem_write && gpio_out_selected),
        .write_data   (data_write_data),
        .btn          (btn),
        .gpio_out     (gpio_out),
        .read_data    (gpio_read_data)
    );

    // UART transmit peripheral
    uart #(
        .CLOCK_FREQ(UART_CLOCK_FREQ),
        .BAUD_RATE (UART_BAUD_RATE)
    ) uart_periph (
        .clk          (clk),
        .reset        (reset),
        .write_enable (data_mem_write && uart_tx_selected),
        .write_data   (data_write_data),
        .read_data    (uart_read_data),
        .rx            (uart_rx),
        .rx_clear      (data_mem_write && uart_rx_clear_selected),
        .rx_data       (uart_rx_data),
        .rx_data_valid (uart_rx_data_valid),
        .rx_framing_error(uart_rx_framing_error),
        .tx           (uart_tx)
    );

    // Timer load writes start a countdown; status reads return busy.
    timer timer_periph (
        .clk      (clk),
        .reset    (reset),
        .start    (data_mem_write && timer_load_selected),
        .count_in (data_write_data),
        .busy     (timer_busy),
        .done     (timer_done)
    );

    assign timer_read_data = {31'b0, timer_busy};

    // Read-data mux
    always_comb begin
        if (gpio_in_selected)
            data_read_data = gpio_read_data;
        else if (ram_selected)
            data_read_data = ram_read_data;
        else if (uart_status_selected)
            data_read_data = uart_read_data;
        else if (uart_rx_data_selected)
            data_read_data = {24'b0, uart_rx_data};
        else if (uart_rx_status_selected)
            data_read_data = {30'b0, uart_rx_framing_error, uart_rx_data_valid};
        else if (timer_status_selected)
            data_read_data = timer_read_data;
        else
            data_read_data = 32'b0;
    end

endmodule

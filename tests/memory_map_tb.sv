`timescale 1ns/1ps

// Drive the SoC buses directly while the CPU stays in reset.
module memory_map_tb;
    logic clk = 0;
    logic [31:0] pc = 0;
    logic [31:0] address = 0;
    logic [31:0] write_data = 0;
    logic write_enable = 0;
    logic [2:0] funct3 = 3'b010;

    always #5 clk = ~clk;

    rv32i_pipelined_soc dut (
        .clk(clk), .reset(1'b1), .btn(1'b0), .uart_rx(1'b1),
        .debug_a0(), .gpio_out(), .uart_tx()
    );

    // Replace CPU bus outputs so this test isolates memory and decoding.
    initial begin
        force dut.instruction_address = pc;
        force dut.data_address = address;
        force dut.data_write_data = write_data;
        force dut.data_mem_write = write_enable;
        force dut.data_funct3 = funct3;
    end

    task automatic check_instruction(input logic [31:0] addr,
                                     input logic [31:0] expected);
        pc = addr;
        #1;
        if (dut.instruction_data !== expected)
            $fatal(1, "IMEM %h: got %h, expected %h",
                   addr, dut.instruction_data, expected);
    endtask

    task automatic store_value(input logic [31:0] addr,
                               input logic [31:0] value,
                               input logic [2:0] width_code);
        @(negedge clk);
        address = addr;
        write_data = value;
        funct3 = width_code;
        write_enable = 1;
        @(negedge clk);
        write_enable = 0;
    endtask

    task automatic check_load(input logic [31:0] addr,
                              input logic [2:0] width_code,
                              input logic [31:0] expected);
        address = addr;
        funct3 = width_code;
        #1;
        if (dut.data_read_data !== expected)
            $fatal(1, "Load %h funct3=%b: got %h, expected %h",
                   addr, width_code, dut.data_read_data, expected);
    endtask

    initial begin
        // Distinct words exercise both new IMEM index bits and the last word.
        dut.imem.memory[0]    = 32'h11111111;
        dut.imem.memory[256]  = 32'h22222222;
        dut.imem.memory[512]  = 32'h33333333;
        dut.imem.memory[1023] = 32'h44444444;
        check_instruction(32'h00000000, 32'h11111111);
        check_instruction(32'h00000400, 32'h22222222);
        check_instruction(32'h00000800, 32'h33333333);
        check_instruction(32'h00000FFC, 32'h44444444);

        // Write first, then read all regions to detect address aliasing.
        store_value(32'h00010000, 32'h11223344, 3'b010);
        store_value(32'h00010100, 32'h55667788, 3'b010);
        store_value(32'h00010200, 32'h99AABBCC, 3'b010);
        store_value(32'h000103FC, 32'h12345678, 3'b010);
        check_load(32'h00010000, 3'b010, 32'h11223344);
        check_load(32'h00010100, 3'b010, 32'h55667788);
        check_load(32'h00010200, 3'b010, 32'h99AABBCC);
        check_load(32'h000103FC, 3'b010, 32'h12345678);

        // Last byte and upper halfword: preserve neighboring bytes.
        store_value(32'h000103FF, 32'h80, 3'b000);
        check_load(32'h000103FC, 3'b010, 32'h80345678);
        check_load(32'h000103FF, 3'b000, 32'hFFFFFF80);
        check_load(32'h000103FF, 3'b100, 32'h00000080);
        store_value(32'h000103FE, 32'hFEDC, 3'b001);
        check_load(32'h000103FC, 3'b010, 32'hFEDC5678);
        check_load(32'h000103FE, 3'b001, 32'hFFFFFEDC);
        check_load(32'h000103FE, 3'b101, 32'h0000FEDC);

        // Outside RAM: writes must not wrap into the first or last word.
        store_value(32'h00010400, 32'hDEADBEEF, 3'b010);
        check_load(32'h00010400, 3'b010, 32'b0);
        store_value(32'h0000FFFC, 32'hDEADBEEF, 3'b010);
        check_load(32'h0000FFFC, 3'b010, 32'b0);
        check_load(32'h00010000, 3'b010, 32'h11223344);
        check_load(32'h000103FC, 3'b010, 32'hFEDC5678);

        $display("PASS: IMEM addresses, DMEM regions, subword access and RAM boundaries");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Memory test timeout");
    end
endmodule

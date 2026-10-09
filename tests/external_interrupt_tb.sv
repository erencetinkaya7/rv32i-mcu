`timescale 1ns/1ps

// Exercise real CSR instructions and trap entry/return with a mock IRQ source.
module external_interrupt_tb;
    logic clk = 0;
    logic reset = 1;
    logic timer_irq = 0;
    logic external_irq = 0;
    logic clear_allowed = 1;
    logic [31:0] requested_mie = 0;
    logic [31:0] requested_mstatus = 0;
    logic [31:0] instruction_address, instruction_data;
    logic [31:0] data_address, write_data, read_data, debug_a0;
    logic mem_write;
    integer entries = 0;
    integer reports = 0;
    integer returns = 0;
    logic [31:0] causes [0:15];
    logic [31:0] saved_pc;
    logic [31:0] progress_before;

    always #5 clk = ~clk;
    assign read_data = (data_address == 0) ? requested_mie :
                       (data_address == 4) ? requested_mstatus : 32'b0;

    instruction_memory #(
        .INIT_FILE("build/interrupt-test/program.hex")
    ) imem (.pc(instruction_address), .instruction(instruction_data));

    rv32i_pipelined_core dut (
        .clk(clk), .reset(reset),
        .timer_irq(timer_irq), .external_irq(external_irq),
        .instruction_data(instruction_data),
        .instruction_address(instruction_address),
        .data_read_data(read_data), .data_address(data_address),
        .data_write_data(write_data), .data_mem_write(mem_write),
        .data_funct3(), .debug_a0(debug_a0)
    );

    // Observe accepted traps and software reports; never force CPU internals.
    always @(posedge clk) begin
        if (!reset) begin
            if (dut.interrupt_take) begin
                if (!dut.csr_mstatus[3])
                    $fatal(1, "Interrupt accepted with global enable off");
                if (entries >= 16)
                    $fatal(1, "Unexpected interrupt storm");
                causes[entries] = dut.trap_cause;
                saved_pc = dut.trap_pc;
                entries = entries + 1;
            end
            if (mem_write && data_address == 12) begin
                if (write_data !== causes[reports])
                    $fatal(1, "Handler read wrong mcause: %h", write_data);
                if (dut.csr_mepc !== saved_pc || dut.csr_mstatus[3] !== 0)
                    $fatal(1, "Incorrect trap state");
                reports = reports + 1;
            end
            if (dut.ex_mret)
                returns = returns + 1;
            if (mem_write && data_address == 20)
                $fatal(1, "Wrong-path store after MRET");
        end
    end

    // Model a peripheral that deasserts its level after a clear write.
    always @(negedge clk) begin
        if (!reset && mem_write && data_address == 16 && clear_allowed)
            external_irq = 0;
    end

    task automatic settle;
        repeat (60) @(negedge clk);
        #1;
    endtask

    initial begin
        $dumpfile("build/waves/external_interrupt.vcd");
        $dumpvars(0, external_interrupt_tb);
        repeat (3) @(negedge clk);
        reset = 0;

        // Source disabled, global enabled: pending must remain visible.
        requested_mstatus = 8;
        external_irq = 1;
        settle();
        if (entries != 0 || dut.csr_mip[11] !== 1)
            $fatal(1, "Source mask/pending test failed");

        // Source enabled, global disabled: still no entry.
        requested_mstatus = 0;
        settle();
        requested_mie = 32'h800;
        settle();
        if (entries != 0 || dut.csr_mip[11] !== 1)
            $fatal(1, "Global mask test failed");

        // Enable globally: service the previously pending request once.
        requested_mstatus = 8;
        settle();
        if (entries != 1 || causes[0] !== 32'h8000000b ||
            reports != 1 || returns != 1 || dut.csr_mip[11] !== 0 ||
            dut.csr_mstatus[3] !== 1)
            $fatal(1, "Pending external interrupt/clear/MRET test failed");

        // Queue both while masked, then enable: external precedes timer.
        requested_mstatus = 0;
        requested_mie = 32'h880;
        settle();
        external_irq = 1;
        timer_irq = 1;
        @(negedge clk);
        timer_irq = 0;
        settle();
        if (dut.csr_mip !== 32'h880 || entries != 1)
            $fatal(1, "Both requests did not remain pending");
        requested_mstatus = 8;
        settle();
        if (entries != 3 || causes[1] !== 32'h8000000b ||
            causes[2] !== 32'h80000007 || dut.csr_mip !== 0)
            $fatal(1, "Priority or retained timer request failed");

        // A masked external request must not block an enabled timer.
        requested_mie = 32'h80;
        settle();
        clear_allowed = 0;
        external_irq = 1;
        timer_irq = 1;
        @(negedge clk);
        timer_irq = 0;
        settle();
        if (entries != 4 || causes[3] !== 32'h80000007 ||
            dut.csr_mip[11] !== 1)
            $fatal(1, "Masked external request blocked timer");

        // Without source clear, a level must cause re-entry after MRET.
        requested_mie = 32'h880;
        wait (entries == 6);
        @(negedge clk);
        clear_allowed = 1;
        settle();
        if (entries != 6 || reports != 6 || returns != 6 ||
            causes[4] !== 32'h8000000b || causes[5] !== 32'h8000000b ||
            dut.csr_mip[11] !== 0)
            $fatal(1, "Level re-entry or source clear failed");
        progress_before = debug_a0;
        settle();
        if (entries != 6 || debug_a0 == progress_before)
            $fatal(1, "Main did not resume cleanly");

        $display("PASS: external IRQ masks, pending, priority, clear and MRET");
        $finish;
    end

    initial begin
        #50000;
        $fatal(1, "External interrupt test timeout");
    end
endmodule

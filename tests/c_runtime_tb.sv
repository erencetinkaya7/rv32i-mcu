`timescale 1ns/1ps

// Run startup twice without reloading RAM between resets.
module c_runtime_tb;
    logic clk = 0;
    logic reset = 1;
    logic [31:0] gpio_out;

    always #5 clk = ~clk;

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE("build/runtime/imem.hex"),
        .DMEM_INIT_FILE("build/runtime/dmem.hex")
    ) dut (
        .clk(clk), .reset(reset), .btn(1'b0), .uart_rx(1'b1),
        .debug_a0(), .gpio_out(gpio_out), .uart_tx()
    );

    task automatic reset_cpu;
        @(negedge clk);
        reset = 1;
        repeat (3) @(negedge clk);
        reset = 0;
    endtask

    task automatic check_completion;
        // C reports 1 on success, E1/E2/E3 for data/BSS/trap failures.
        wait (gpio_out != 0);
        if (gpio_out !== 32'd1)
            $fatal(1, "C startup failed: GPIO code %h", gpio_out);
    endtask

    initial begin
        reset_cpu();
        check_completion();
        $display("Startup values correct; C has now modified the variables.");

        reset_cpu();
        check_completion();
        $display("PASS: C .data scalars/arrays restored and .bss cleared across reset");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "C runtime test timeout");
    end
endmodule

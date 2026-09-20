// Software-started countdown timer.
module timer (
    input  logic        clk,
    input  logic        reset,
    input  logic        start,
    input  logic [31:0] count_in,
    output logic        busy,
    output logic        done
);

    logic [31:0] counter;

    always_ff @(posedge clk) begin
        if (reset) begin
            counter <= 32'b0;
            busy    <= 1'b0;
            done    <= 1'b0;
        end else begin
            // done is a one-cycle completion pulse.
            done <= 1'b0;

            if (start && !busy) begin
                if (count_in == 32'd0) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    counter <= count_in;
                    busy    <= 1'b1;
                end
            end else if (busy) begin
                if (counter == 32'd1) begin
                    counter <= 32'b0;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                end else begin
                    counter <= counter - 1'b1;
                end
            end
        end
    end

endmodule

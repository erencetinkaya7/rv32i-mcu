// Minimal machine-mode trap and interrupt CSRs

module csr_file (
    input  logic        clk,
    input  logic        reset,

    // Trap control
    input  logic        trap_enter,
    input  logic        trap_return,
    input  logic [31:0] trap_pc,
    input  logic [31:0] trap_cause,
    input  logic        timer_irq,

    // CSR access
    input  logic [11:0] csr_read_addr,
    output logic [31:0] csr_read_data,
    input  logic        csr_write_enable,
    input  logic [11:0] csr_write_addr,
    input  logic [31:0] csr_write_data,

    // CSR values
    output logic [31:0] mstatus,
    output logic [31:0] mie,
    output logic [31:0] mtvec,
    output logic [31:0] mepc,
    output logic [31:0] mcause,
    output logic [31:0] mip
);


    // Machine-mode CSR addresses
    localparam logic [11:0] CSR_MSTATUS = 12'h300;
    localparam logic [11:0] CSR_MIE     = 12'h304;
    localparam logic [11:0] CSR_MTVEC   = 12'h305;
    localparam logic [11:0] CSR_MEPC    = 12'h341;
    localparam logic [11:0] CSR_MCAUSE  = 12'h342;
    localparam logic [11:0] CSR_MIP     = 12'h344;

    localparam logic [31:0] MSTATUS_MASK = 32'h0000_0088;
    localparam logic [31:0] MIE_MASK     = 32'h0000_0080;
    localparam logic [31:0] TIMER_CAUSE  = 32'h8000_0007;

    logic timer_irq_pending;

    // MTIP is read-only and records a timer pulse until it is serviced.
    assign mip = {24'b0, timer_irq_pending, 7'b0};


    // CSR read
    always_comb begin
        case (csr_read_addr)
            CSR_MSTATUS: csr_read_data = mstatus;
            CSR_MIE:     csr_read_data = mie;
            CSR_MTVEC:   csr_read_data = mtvec;
            CSR_MEPC:    csr_read_data = mepc;
            CSR_MCAUSE:  csr_read_data = mcause;
            CSR_MIP:     csr_read_data = mip;
            default:     csr_read_data = 32'b0;
        endcase
    end


    // Trap state, interrupt pending and CSR writes
    always_ff @(posedge clk) begin
        if (reset) begin
            mstatus          <= 32'b0;
            mie              <= 32'b0;
            mtvec            <= 32'h0000_0080;
            mepc             <= 32'b0;
            mcause           <= 32'b0;
            timer_irq_pending <= 1'b0;
        end else begin
            if (timer_irq)
                timer_irq_pending <= 1'b1;

            if (trap_enter && (trap_cause == TIMER_CAUSE))
                timer_irq_pending <= 1'b0;

            if (trap_enter) begin
                mepc       <= {trap_pc[31:2], 2'b00};
                mcause     <= trap_cause;
                mstatus[7] <= mstatus[3];
                mstatus[3] <= 1'b0;
            end else if (trap_return) begin
                mstatus[3] <= mstatus[7];
                mstatus[7] <= 1'b1;
            end else if (csr_write_enable) begin
                case (csr_write_addr)
                    CSR_MSTATUS: mstatus <= csr_write_data & MSTATUS_MASK;
                    CSR_MIE:     mie     <= csr_write_data & MIE_MASK;
                    CSR_MTVEC:   mtvec   <= {csr_write_data[31:2], 2'b00};
                    CSR_MEPC:    mepc    <= {csr_write_data[31:2], 2'b00};
                    CSR_MCAUSE:  mcause  <= csr_write_data;
                    default: ;
                endcase
            end
        end
    end


endmodule

// 5-stage pipelined RV32I processor core
// Exposes separate instruction and data memory interfaces.

module rv32i_pipelined_core (

    input  logic        clk,
    input  logic        reset,
    input  logic        timer_irq,

    // Instruction interface
    input  logic [31:0] instruction_data,
    output logic [31:0] instruction_address,

    // Data interface
    input  logic [31:0] data_read_data,
    output logic [31:0] data_address,
    output logic [31:0] data_write_data,
    output logic        data_mem_write,
    output logic [2:0]  data_funct3,

    // Debug
    output logic [31:0] debug_a0

);


// Instruction Fetch

    logic [31:0] pc_next;
    logic [31:0] pc;
    logic [31:0] pc_plus4;
    logic load_use_hazard;
    logic ex_pc_redirect;
    logic ex_sync_redirect;
    logic interrupt_request;
    logic interrupt_take;
    logic trap_enter;
    logic [31:0] trap_pc;
    logic [31:0] trap_cause;

// CSR signals
    logic        ex_ecall;
    logic        ex_mret;
    logic        ex_csrrw;
    logic        ex_csrrs;
    logic        ex_csr_access;

    logic [31:0] csr_mstatus;
    logic [31:0] csr_mie;
    logic [31:0] csr_mtvec;
    logic [31:0] csr_mepc;
    logic [31:0] csr_mcause;
    logic [31:0] csr_mip;
    logic [31:0] csr_read_data;
    logic        csr_write_enable;
    logic [31:0] csr_write_data;

    logic [31:0] ex_execution_result;

    assign instruction_address = pc;
    assign pc_plus4 = pc + 32'd4;
    
    always_ff @(posedge clk) begin
        if (reset)
            pc <= 32'b0;
        // Redirects must win over a simultaneous load-use stall.
        else if (ex_pc_redirect)
            pc <= pc_next;
        else if (!load_use_hazard)
            pc <= pc_next;
    end


// IF/ID pipeline register

    logic [31:0] if_id_pc;
    logic [31:0] if_id_pc_plus4;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;

    if_id_reg if_id (
        .clk(clk),
        .reset(reset),
        .flush(ex_pc_redirect),
        // Inputs
        .enable(!load_use_hazard),
        .pc_in(pc),
        .pc_plus4_in(pc_plus4),
        .instruction_in(instruction_data),
        // Outputs
        .pc_out(if_id_pc),
        .pc_plus4_out(if_id_pc_plus4),
        .instruction_out(if_id_instruction),
        .valid_out(if_id_valid)
    );    


// Instruction Decode

    logic [6:0] id_opcode;
    logic [4:0] id_rd;
    logic [2:0] id_funct3;
    logic [4:0] id_rs1;
    logic [4:0] id_rs2;
    logic [6:0] id_funct7;

    logic        id_reg_write;
    logic        id_alu_src;
    logic [2:0]  id_imm_sel;
    logic        id_mem_write;
    logic [1:0]  id_result_src;
    logic        id_branch_enable;
    logic        id_jump;
    logic        id_jalr;
    logic [1:0]  id_alu_a_sel;
    logic [31:0] id_immediate;    

    logic [31:0] id_rs1_data;
    logic [31:0] id_rs2_data;

    logic id_uses_rs1;
    logic id_uses_rs2;


    instruction_fields fields (
        .instruction(if_id_instruction),

        .opcode(id_opcode),
        .rd(id_rd),
        .funct3(id_funct3),
        .rs1(id_rs1),
        .rs2(id_rs2),
        .funct7(id_funct7)
    );

    
// Main instruction control
    control_unit control (
        .opcode(id_opcode),
        .funct3(id_funct3),

        .reg_write(id_reg_write),
        .alu_src(id_alu_src),
        .imm_sel(id_imm_sel),
        .mem_write(id_mem_write),
        .result_src(id_result_src),
        .branch_enable(id_branch_enable),
        .jump(id_jump),
        .jalr(id_jalr),
        .alu_a_sel(id_alu_a_sel),
        .uses_rs1(id_uses_rs1),
        .uses_rs2(id_uses_rs2)
    );

// Immediate generation
    immediate_generator imm_gen (
        .instruction(if_id_instruction),
        .imm_sel(id_imm_sel),

        .immediate(id_immediate)
    );


 // MEM/WB pipeline signals
    logic [31:0] wb_alu_result;
    logic [31:0] wb_mem_data;
    logic [31:0] wb_pc_plus4;
    logic [4:0]  wb_rd;
    logic        wb_reg_write;
    logic [1:0]  wb_result_src;
    logic [31:0] wb_result;


    
// Register file
    register_file rf (
        .clk(clk),

        .write_enable(wb_reg_write),
        .rs1_addr(id_rs1),
        .rs2_addr(id_rs2),
        .rd_addr(wb_rd),
        .rd_data(wb_result),

        .rs1_data(id_rs1_data),
        .rs2_data(id_rs2_data),

        .debug_a0(debug_a0)
    );        


// ID/EX pipeline signals

    logic [31:0] ex_pc;
    logic [31:0] ex_pc_plus4;
    logic [31:0] ex_rs1_data;
    logic [31:0] ex_rs2_data;
    logic [31:0] ex_immediate;

    logic [4:0] ex_rs1;
    logic [4:0] ex_rs2;
    logic [4:0] ex_rd;
    logic [2:0] ex_funct3;
    logic [6:0] ex_funct7;
    logic [6:0] ex_opcode;

    logic       ex_reg_write;
    logic       ex_alu_src;
    logic [1:0] ex_alu_a_sel;
    logic       ex_mem_write;
    logic [1:0] ex_result_src;
    logic       ex_branch_enable;
    logic       ex_jump;
    logic       ex_jalr;
    logic [3:0] ex_alu_control;
    logic [31:0] ex_alu_a;
    logic [31:0] ex_alu_b;
    logic [31:0] ex_alu_result;
    logic        ex_branch_taken;
    logic [31:0] ex_branch_target;
    logic [31:0] ex_jalr_target;
    
    logic [31:0] ex_forwarded_rs1;
    logic [31:0] ex_forwarded_rs2;
    logic [1:0]  forward_a;
    logic [1:0]  forward_b;
    logic [31:0] mem_forward_data;


// EX/MEM pipeline signals
    logic [31:0] mem_alu_result;
    logic [31:0] mem_rs2_data;
    logic [2:0]  mem_funct3;
    logic        mem_mem_write;
    logic [1:0]  mem_result_src;
    logic [4:0]  mem_rd;
    logic        mem_reg_write;
    logic [31:0] mem_pc_plus4;

    assign mem_forward_data =
    (mem_result_src == 2'b10) ? mem_pc_plus4 :
                                mem_alu_result;

// Forwarding Unit

    forwarding_unit forwarding (
    .ex_rs1(ex_rs1),
    .ex_rs2(ex_rs2),

    .mem_rd(mem_rd),
    .mem_reg_write(mem_reg_write),
    .mem_result_src(mem_result_src),

    .wb_rd(wb_rd),
    .wb_reg_write(wb_reg_write),

    .forward_a(forward_a),
    .forward_b(forward_b)
    );

    always_comb begin
        case (forward_a)
            2'b10: ex_forwarded_rs1 = mem_forward_data;
            2'b01: ex_forwarded_rs1 = wb_result;
            default: ex_forwarded_rs1 = ex_rs1_data;
        endcase

        case (forward_b)
            2'b10: ex_forwarded_rs2 = mem_forward_data;
            2'b01: ex_forwarded_rs2 = wb_result;
            default: ex_forwarded_rs2 = ex_rs2_data;
        endcase
    end

// ID/EX pipeline register

    id_ex_reg id_ex (
        // Inputs
        .clk(clk),
        .reset(reset),
        .bubble(load_use_hazard | ex_pc_redirect),

        .pc_in(if_id_pc),
        .pc_plus4_in(if_id_pc_plus4),
        .rs1_data_in(id_rs1_data),
        .rs2_data_in(id_rs2_data),
        .immediate_in(id_immediate),

        .rs1_in(id_rs1),
        .rs2_in(id_rs2),
        .rd_in(id_rd),
        .funct3_in(id_funct3),
        .funct7_in(id_funct7),
        .opcode_in(id_opcode),

        .reg_write_in(id_reg_write),
        .alu_src_in(id_alu_src),
        .alu_a_sel_in(id_alu_a_sel),
        .mem_write_in(id_mem_write),
        .result_src_in(id_result_src),
        .branch_enable_in(id_branch_enable),
        .jump_in(id_jump),
        .jalr_in(id_jalr),
        // Outputs
        .pc_out(ex_pc),
        .pc_plus4_out(ex_pc_plus4),
        .rs1_data_out(ex_rs1_data),
        .rs2_data_out(ex_rs2_data),
        .immediate_out(ex_immediate),

        .rs1_out(ex_rs1),
        .rs2_out(ex_rs2),
        .rd_out(ex_rd),
        .funct3_out(ex_funct3),
        .funct7_out(ex_funct7),
        .opcode_out(ex_opcode),

        .reg_write_out(ex_reg_write),
        .alu_src_out(ex_alu_src),
        .alu_a_sel_out(ex_alu_a_sel),
        .mem_write_out(ex_mem_write),
        .result_src_out(ex_result_src),
        .branch_enable_out(ex_branch_enable),
        .jump_out(ex_jump),
        .jalr_out(ex_jalr)
);

// ECALL detection

    assign ex_ecall =
        (ex_opcode == 7'b1110011) &&
        (ex_funct3 == 3'b000) &&
        (ex_rd     == 5'd0) &&
        (ex_rs1    == 5'd0) &&
        (ex_rs2    == 5'd0) &&
        (ex_funct7 == 7'd0);

// MRET detection

    assign ex_mret =
        (ex_opcode == 7'b1110011) &&
        (ex_funct3 == 3'b000) &&
        (ex_rd == 5'd0) &&
        (ex_rs1 == 5'd0) &&
        (ex_immediate[11:0] == 12'h302);

    // CSR instruction detection

    assign ex_csrrw =
        (ex_opcode == 7'b1110011) &&
        (ex_funct3 == 3'b001);

    assign ex_csrrs =
        (ex_opcode == 7'b1110011) &&
        (ex_funct3 == 3'b010);

    assign ex_csr_access = ex_csrrw | ex_csrrs;

    // CSR write behavior

    assign csr_write_enable =
        ex_csrrw | (ex_csrrs && (ex_rs1 != 5'd0));

    assign csr_write_data =
        ex_csrrw
            ? ex_forwarded_rs1
            : csr_read_data | ex_forwarded_rs1;


// Machine-mode trap CSRs

    assign interrupt_request =
        csr_mstatus[3] & csr_mie[7] & csr_mip[7];

    // The EX instruction completes; the valid ID instruction is retried after MRET.
    assign interrupt_take =
        interrupt_request & if_id_valid &
        !ex_sync_redirect & !ex_csr_access;

    assign trap_enter = ex_ecall | interrupt_take;
    assign trap_pc = ex_ecall ? ex_pc : if_id_pc;
    assign trap_cause =
        ex_ecall ? 32'd11 : 32'h8000_0007;

    csr_file trap_csrs (
        .clk              (clk),
        .reset            (reset),

        .trap_enter       (trap_enter),
        .trap_return      (ex_mret),
        .trap_pc          (trap_pc),
        .trap_cause       (trap_cause),
        .timer_irq        (timer_irq),

        .csr_read_addr    (ex_immediate[11:0]),
        .csr_read_data    (csr_read_data),
        .csr_write_enable (csr_write_enable),
        .csr_write_addr   (ex_immediate[11:0]),
        .csr_write_data   (csr_write_data),

        .mstatus          (csr_mstatus),
        .mie              (csr_mie),
        .mtvec            (csr_mtvec),
        .mepc             (csr_mepc),
        .mcause           (csr_mcause),
        .mip              (csr_mip)
    );

// Hazard Unit

    hazard_unit hazard (

        .ex_rd          (ex_rd),
        .ex_reg_write   (ex_reg_write),
        .ex_result_src  (ex_result_src),

        .id_rs1         (id_rs1),
        .id_rs2         (id_rs2),
        .id_uses_rs1    (id_uses_rs1),
        .id_uses_rs2    (id_uses_rs2),

        .load_use_hazard(load_use_hazard)
    );

// EX Stage - ALU Decode

    alu_decoder alu_decoder_inst (
        .opcode(ex_opcode),
        .funct3(ex_funct3),
        .funct7(ex_funct7),

        .alu_control(ex_alu_control)
    );


// EX - Stage - ALU Operand Selection

    always_comb begin
        case (ex_alu_a_sel)
            2'b00:   ex_alu_a = ex_forwarded_rs1;
            2'b01:   ex_alu_a = ex_pc;
            2'b10:   ex_alu_a = 32'b0;
            default: ex_alu_a = 32'b0;
        endcase

        if (ex_alu_src)
            ex_alu_b = ex_immediate;
        else
            ex_alu_b = ex_forwarded_rs2;
    end



// ALU

    alu alu_inst (
        .a           (ex_alu_a),
        .b           (ex_alu_b),
        .alu_control (ex_alu_control),

        .result      (ex_alu_result)
    );

// Execution result selection

    assign ex_execution_result =
        ex_csr_access ? csr_read_data : ex_alu_result;

// Branch decision
    branch_unit branch_unit_inst (
        .rs1_data      (ex_forwarded_rs1),
        .rs2_data      (ex_forwarded_rs2),
        .funct3        (ex_funct3),
        .branch_enable (ex_branch_enable),

        .branch_taken  (ex_branch_taken)
    );

    // Control flow targets
    assign ex_branch_target = ex_pc + ex_immediate;
    assign ex_jalr_target   = (ex_forwarded_rs1 + ex_immediate) & 32'hFFFF_FFFE;

    assign ex_sync_redirect =
        ex_ecall | ex_mret | ex_branch_taken | ex_jump | ex_jalr;

    assign ex_pc_redirect = ex_sync_redirect | interrupt_take;

    assign pc_next =
        ex_ecall
            ? csr_mtvec
            : ex_mret
            ? csr_mepc
            : interrupt_take
            ? csr_mtvec
            : ex_jalr
            ? ex_jalr_target
            : ex_sync_redirect
            ? ex_branch_target
            : pc_plus4;

    

// EX/MEM pipeline register
    ex_mem_reg ex_mem (
        .clk            (clk),
        .reset          (reset),

        .alu_result_in  (ex_execution_result),
        .rs2_data_in    (ex_forwarded_rs2),
        .pc_plus4_in    (ex_pc_plus4),
        .rd_in          (ex_rd),
        .funct3_in      (ex_funct3),
        .reg_write_in   (ex_reg_write),
        .mem_write_in   (ex_mem_write),
        .result_src_in  (ex_result_src),

        .alu_result_out (mem_alu_result),
        .rs2_data_out   (mem_rs2_data),
        .pc_plus4_out   (mem_pc_plus4),
        .rd_out         (mem_rd),
        .funct3_out     (mem_funct3),
        .reg_write_out  (mem_reg_write),
        .mem_write_out  (mem_mem_write),
        .result_src_out (mem_result_src)
    );



// Data memory interface
    assign data_address    = mem_alu_result;
    assign data_write_data = mem_rs2_data;
    assign data_mem_write  = mem_mem_write;
    assign data_funct3     = mem_funct3;


// MEM/WB pipeline register
    mem_wb_reg mem_wb (
        .clk            (clk),
        .reset          (reset),

        .alu_result_in  (mem_alu_result),
        .mem_data_in    (data_read_data),
        .pc_plus4_in    (mem_pc_plus4),
        .rd_in          (mem_rd),
        .reg_write_in   (mem_reg_write),
        .result_src_in  (mem_result_src),

        .alu_result_out (wb_alu_result),
        .mem_data_out   (wb_mem_data),
        .pc_plus4_out   (wb_pc_plus4),
        .rd_out         (wb_rd),
        .reg_write_out  (wb_reg_write),
        .result_src_out (wb_result_src)
    );


// Writeback result selection

    always_comb begin
        case (wb_result_src)
            2'b00: wb_result = wb_alu_result;
            2'b01: wb_result = wb_mem_data;
            2'b10: wb_result = wb_pc_plus4;
            default: wb_result = 32'b0;
        endcase
    end
endmodule
   

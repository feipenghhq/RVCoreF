/* ------------------------------------------------------------------------------------------------
 * Copyright (c) 2022. Heqing Huang (feipenghhq@gmail.com)
 *
 * Project: RVCoreF
 * Author: Heqing Huang
 * Date Created: 08/13/2023
 *
 * ------------------------------------------------------------------------------------------------
 * Decoder: Instruction Decoder
 * ------------------------------------------------------------------------------------------------
 */

// Notes: We only detect illegal instruction detection on opcode.
// If other part of the instruction (such as funct3) is illegal, we don't detect that
// and the instruction might be treated as NOP depending on the encoding

`include "config.svh"
`include "core.svh"
`include "riscv_isa.svh"

module decoder (
    input logic [`XLEN-1:0]             instruction,
    // contrl signal to downstrem pipeline stage
    output logic [`ALU_OP_WIDTH-1:0]    alu_opcode,     // alu opcode
    output logic                        alu_src1_sel,   // alu src1 select
    output logic                        alu_src2_sel,   // alu src2 select
    output logic                        bxx,            // branch instructions (beq/blt/bltu)
    output logic                        bnxx,           // branch instructions (bne/bge/bgeu)
    output logic                        jump,           // jump instructions
    output logic                        mem_read,       // memory read
    output logic                        mem_write,      // memory write
    output logic [`MEM_OP_WIDTH-1:0]    mem_opcode,     // memory operation
    output logic                        rd_write,       // rd write
    output logic [`REG_AW-1:0]          rd_addr,        // rd address
    output logic                        rs1_read,       // rs1 read
    output logic [`REG_AW-1:0]          rs1_addr,       // rs1 address
    output logic                        rs2_read,       // rs2 read
    output logic [`REG_AW-1:0]          rs2_addr,       // rs2 address
    output logic [`XLEN-1:0]            immediate       // immediate value
);

    logic [1:0] rv32i_phase;
    logic [4:0] rv32i_opcode;
    logic [2:0] rv32i_funct3;
    logic [6:0] rv32i_funct7;

    logic [`XLEN-1:0] u_type_imm_val;
    logic [`XLEN-1:0] i_type_imm_val;
    logic [`XLEN-1:0] j_type_imm_val;
    logic [`XLEN-1:0] s_type_imm_val;
    logic [`XLEN-1:0] b_type_imm_val;
    logic is_u_type_imm;
    logic is_i_type_imm;
    logic is_j_type_imm;
    logic is_s_type_imm;
    logic is_b_type_imm;

    logic phase3;
    logic is_lui;
    logic is_auipc;
    logic is_jal;
    logic is_jalr;

    // I-type and R-type
    logic is_itype;
    logic is_rtype;

    logic is_add;
    logic is_sub;
    logic is_sll;
    logic is_slt;
    logic is_sltu;
    logic is_xor;
    logic is_srl;
    logic is_sra;
    logic is_or;
    logic is_and;

    // Load and Store instructions
    logic is_load;
    logic is_store;

    logic ls_is_unsigned;
    logic ls_is_half;
    logic ls_is_byte;
    logic ls_is_word;

    // Branch
    logic is_branch;
    logic is_beq;
    logic is_bne;
    logic is_blt;
    logic is_bge;
    logic is_bltu;
    logic is_bgeu;

    // -------------------------------------------
    // Extract Each field from Instruction
    // -------------------------------------------
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign rd_addr  = instruction[24:20];

    assign rv32i_phase  = instruction[1:0];
    assign rv32i_opcode = instruction[6:2];
    assign rv32i_funct3 = instruction[14:12];
    assign rv32i_funct7 = instruction[31:25];

    assign u_type_imm_val = {instruction[31:12], 12'b0};
    assign i_type_imm_val = {{20{instruction[31]}}, instruction[31:20]};
    assign j_type_imm_val = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
    assign s_type_imm_val = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    assign b_type_imm_val = {{20{instruction[31]}}, instruction[11],instruction[30:25],instruction[11:8], 1'b0};

    // -------------------------------------------
    // Decode the instruction
    // -------------------------------------------
    // RV32I Base Instruction Set (Not compressed)
    assign phase3   = (rv32i_phase == 2'b11);
    assign is_lui   = phase3 & (rv32i_opcode == `RV32I_OPCODE_LUI);
    assign is_auipc = phase3 & (rv32i_opcode == `RV32I_OPCODE_AUIPC);
    assign is_jal   = phase3 & (rv32i_opcode == `RV32I_OPCODE_JAL);
    assign is_jalr  = phase3 & (rv32i_opcode == `RV32I_OPCODE_JALR);

    // I-type and R-type
    assign is_itype = phase3 & (rv32i_opcode == `RV32I_OPCODE_ITYPE);
    assign is_rtype = phase3 & (rv32i_opcode == `RV32I_OPCODE_RTYPE);

    assign is_add  = (rv32i_funct3 == `RV32I_FUNC3_ADD) & ~instruction[30];
    assign is_sub  = (rv32i_funct3 == `RV32I_FUNC3_SUB) & instruction[30];
    assign is_sll  = (rv32i_funct3 == `RV32I_FUNC3_SLL);
    assign is_slt  = (rv32i_funct3 == `RV32I_FUNC3_SLT);
    assign is_sltu = (rv32i_funct3 == `RV32I_FUNC3_SLTU);
    assign is_xor  = (rv32i_funct3 == `RV32I_FUNC3_XOR);
    assign is_srl  = (rv32i_funct3 == `RV32I_FUNC3_SRL) & ~instruction[30];
    assign is_sra  = (rv32i_funct3 == `RV32I_FUNC3_SRA) & instruction[30];
    assign is_or   = (rv32i_funct3 == `RV32I_FUNC3_OR);
    assign is_and  = (rv32i_funct3 == `RV32I_FUNC3_AND);

    // Load and Store
    assign is_load  = phase3 & (rv32i_opcode == `RV32I_OPCODE_LOAD);
    assign is_store = phase3 & (rv32i_opcode == `RV32I_OPCODE_STORE);

    assign ls_is_unsigned = rv32i_funct3[2];
    assign ls_is_byte = (rv32i_funct3[1:0] == 2'h0);
    assign ls_is_half = (rv32i_funct3[1:0] == 2'h1);
    assign ls_is_word = (rv32i_funct3[1:0] == 2'h2);

    // Branch
    assign is_branch = (rv32i_opcode == `RV32I_OPCODE_BRANCH);
    assign is_beq  = is_branch & (rv32i_funct3 == `RV32I_FUNC3_BEQ);
    assign is_bne  = is_branch & (rv32i_funct3 == `RV32I_FUNC3_BNE);
    assign is_blt  = is_branch & (rv32i_funct3 == `RV32I_FUNC3_BLT);
    assign is_bge  = is_branch & (rv32i_funct3 == `RV32I_FUNC3_BGE);
    assign is_bltu = is_branch & (rv32i_funct3 == `RV32I_FUNC3_BLTU);
    assign is_bgeu = is_branch & (rv32i_funct3 == `RV32I_FUNC3_BGEU);

    // -------------------------------------------
    // Control signal generation
    // -------------------------------------------

    // select pc
    assign alu_src1_sel = is_jal | is_auipc;

    // select immediate value
    assign alu_src2_sel = jump | is_lui | is_auipc | is_itype;

    assign alu_opcode[`ALU_OP_ADD] = is_add;
    assign alu_opcode[`ALU_OP_SUB] = is_sub | is_beq | is_bne;
    assign alu_opcode[`ALU_OP_SLL] = is_sll;
    assign alu_opcode[`ALU_OP_SLT] = is_slt | is_blt | is_bge;
    assign alu_opcode[`ALU_OP_SLTU] = is_sltu | is_bltu | is_bgeu;
    assign alu_opcode[`ALU_OP_XOR] = is_xor;
    assign alu_opcode[`ALU_OP_SRL] = is_srl;
    assign alu_opcode[`ALU_OP_SRA] = is_sra;
    assign alu_opcode[`ALU_OP_OR]  = is_or;
    assign alu_opcode[`ALU_OP_AND] = is_and;

    assign mem_opcode[`MEM_OP_BYTE] = ls_is_byte;
    assign mem_opcode[`MEM_OP_HALF] = ls_is_half;
    assign mem_opcode[`MEM_OP_WORD] = ls_is_word;
    assign mem_opcode[`MEM_OP_UNSIGN] = ls_is_unsigned;

    assign jump = is_jal | is_jalr;
    assign rd_write = is_lui | is_auipc | jump | is_itype | is_rtype | is_load;
    assign rs1_read = is_rtype | is_itype | is_jalr | is_load;
    assign rs2_read = is_rtype | is_store;
    assign mem_read = is_load;
    assign mem_write = is_store;
    assign bxx = is_branch & ~rv32i_funct3[0];
    assign bnxx = is_branch & rv32i_funct3[0];

    assign is_i_type_imm = is_jalr | is_itype | is_load;
    assign is_u_type_imm = is_lui | is_auipc;
    assign is_j_type_imm = is_jal;
    assign is_s_type_imm = is_store;
    assign is_b_type_imm = is_branch;
    assign immediate = ({32{is_i_type_imm}} & i_type_imm_val) |
                       ({32{is_u_type_imm}} & u_type_imm_val) |
                       ({32{is_j_type_imm}} & j_type_imm_val) |
                       ({32{is_s_type_imm}} & s_type_imm_val) |
                       ({32{is_b_type_imm}} & b_type_imm_val) ;
endmodule
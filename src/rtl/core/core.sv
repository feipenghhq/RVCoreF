/* ------------------------------------------------------------------------------------------------
 * Copyright (c) 2022. Heqing Huang (feipenghhq@gmail.com)
 *
 * Project: RVCoreF
 * Author: Heqing Huang
 * Date Created: 08/16/2023
 *
 * ------------------------------------------------------------------------------------------------
 * CPU Core top level
 * ------------------------------------------------------------------------------------------------
 */

`include "config.svh"
`include "core.svh"

module core #(
    parameter PC_RESET_ADDR = `XLEN'h0,
    parameter ISA_ZICSR = 1,        // Support Zicsr instruction sets
    parameter SUPPORT_TRAP = 1      // Support exception and interrupt
) (
    input  logic                clk,
    input  logic                rst_b,
    // Instruction RAM Access
    output logic                iram_req,
    output logic                iram_write,
    output logic [`XLEN/8-1:0]  iram_wstrb,
    output logic [`XLEN-1:0]    iram_addr,
    output logic [`XLEN-1:0]    iram_wdata,
    input  logic                iram_ready,
    input  logic                iram_rvalid,
    input  logic [`XLEN-1:0]    iram_rdata,
    // Data RAM Access
    output logic                dram_req,
    output logic                dram_write,
    output logic [`XLEN/8-1:0]  dram_wstrb,
    output logic [`XLEN-1:0]    dram_addr,
    output logic [`XLEN-1:0]    dram_wdata,
    input  logic                dram_ready,
    input  logic                dram_rvalid,
    input  logic [`XLEN-1:0]    dram_rdata,
    // Interrput
    input  logic                external_interrupt,
    input  logic                software_interrupt,
    input  logic                timer_interrupt,
    input  logic                debug_interrupt
);

    // --------------------------------------
    //  Signal Definition
    // --------------------------------------

    // IF <--> ID
    logic                           id_pipe_valid;
    logic                           id_pipe_ready;
    logic                           id_pipe_flush;
    logic [`XLEN-1:0]               id_pipe_pc;
    logic [`XLEN-1:0]               id_pipe_instruction;
    // ID <--> EX
    logic                           ex_pipe_valid;
    logic                           ex_pipe_ready;
    logic                           ex_pipe_flush;
    logic [`XLEN-1:0]               ex_pipe_pc;
    logic [`XLEN-1:0]               ex_pipe_instruction;
    logic [`ALU_OP_WIDTH-1:0]       ex_pipe_alu_opcode;
    logic [`ALU_SRC1_WIDTH-1:0]     ex_pipe_alu_src1_sel;
    logic                           ex_pipe_alu_src2_sel_imm;
    logic                           ex_pipe_branch;
    logic [`BRANCH_OP_WIDTH-1:0]    ex_pipe_branch_opcode;
    logic                           ex_pipe_jump;
    logic [`XLEN-1:0]               ex_pipe_rs1_rdata;
    logic [`XLEN-1:0]               ex_pipe_rs2_rdata;
    logic                           ex_pipe_rd_write;
    logic [`REG_AW-1:0]             ex_pipe_rd_addr;
    logic                           ex_pipe_mem_read;
    logic                           ex_pipe_mem_write;
    logic [`MEM_OP_WIDTH-1:0]       ex_pipe_mem_opcode;
    logic                           ex_pipe_unsign;
    logic [`XLEN-1:0]               ex_pipe_immediate;
    logic                           ex_pipe_csr_write;
    logic                           ex_pipe_csr_set;
    logic                           ex_pipe_csr_clear;
    logic                           ex_pipe_csr_read;
    logic [11:0]                    ex_pipe_csr_addr;
    logic                           ex_pipe_exc_pending;
    logic [3:0]                     ex_pipe_exc_code;
    logic                           ex_pipe_exc_interrupt;
    // EX <--> MEM
    logic                           mem_pipe_ready;
    logic                           mem_pipe_flush;
    logic                           mem_pipe_valid;
    logic [`XLEN-1:0]               mem_pipe_pc;
    logic [`XLEN-1:0]               mem_pipe_instruction;
    logic                           mem_pipe_mem_read;
    logic [`MEM_OP_WIDTH-1:0]       mem_pipe_mem_opcode;
    logic [1:0]                     mem_pipe_mem_byte_addr;
    logic                           mem_pipe_unsign;
    logic                           mem_pipe_rd_write;
    logic [`REG_AW-1:0]             mem_pipe_rd_addr;
    logic [`XLEN-1:0]               mem_pipe_alu_result;
    logic                           mem_pipe_csr_write;
    logic                           mem_pipe_csr_set;
    logic                           mem_pipe_csr_clear;
    logic                           mem_pipe_csr_read;
    logic [`XLEN-1:0]               mem_pipe_csr_info;
    logic [11:0]                    mem_pipe_csr_addr;
    logic                           mem_pipe_exc_pending;
    logic [3:0]                     mem_pipe_exc_code;
    logic [`XLEN-1:0]               mem_pipe_exc_tval;
    logic                           mem_pipe_exc_interrupt;
    // MEM <--> WB
    logic                           wb_pipe_ready;
    logic                           wb_pipe_flush;
    logic                           wb_pipe_valid;
    logic [`XLEN-1:0]               wb_pipe_pc;
    logic [`XLEN-1:0]               wb_pipe_instruction;
    logic                           wb_pipe_rd_write;
    logic [`REG_AW-1:0]             wb_pipe_rd_addr;
    logic [`XLEN-1:0]               wb_pipe_rd_data;
    logic                           wb_pipe_csr_write;
    logic                           wb_pipe_csr_set;
    logic                           wb_pipe_csr_clear;
    logic                           wb_pipe_csr_read;
    logic [`XLEN-1:0]               wb_pipe_csr_info;
    logic [11:0]                    wb_pipe_csr_addr;
    logic                           wb_pipe_exc_pending;
    logic [3:0]                     wb_pipe_exc_code;
    logic [`XLEN-1:0]               wb_pipe_exc_tval;
    logic                           wb_pipe_exc_interrupt;
    // From EX stage
    logic                           ex_branch;
    logic [`XLEN-1:0]               ex_branch_pc;
    logic                           ex_rd_write;
    logic [`REG_AW-1:0]             ex_rd_addr;
    logic [`XLEN-1:0]               ex_rd_wdata;
    // From MEM stage
    logic                           mem_rd_write;
    logic [`REG_AW-1:0]             mem_rd_addr;
    logic [`XLEN-1:0]               mem_rd_wdata;
    logic                           mem_mem_read_wait;
    // From WB stage
    logic                           wb_rd_write;
    logic [`XLEN-1:0]               wb_rd_wdata;
    logic [`REG_AW-1:0]             wb_rd_addr;
    // MISC
    logic                           interrupt_req;

    // --------------------------------------
    // Glue logic
    // --------------------------------------

    assign interrupt_req = external_interrupt | software_interrupt | timer_interrupt | debug_interrupt;

    // --------------------------------------
    // Module Instantiation
    // --------------------------------------

    IF #(
        .PC_RESET_ADDR(PC_RESET_ADDR)
    ) u_if (.*);

    ID #(
        .ISA_ZICSR(ISA_ZICSR),
        .SUPPORT_TRAP(SUPPORT_TRAP)
    ) u_id (.*);

    EX u_ex (.*);

    MEM u_mem (.*);

    WB u_wb (.*);

endmodule
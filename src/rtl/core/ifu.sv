/* ------------------------------------------------------------------------------------------------
 * Copyright (c) 2022. Heqing Huang (feipenghhq@gmail.com)
 *
 * Project: RVCoreF
 * Author: Heqing Huang
 * Date Created: 08/12/2023
 *
 * ------------------------------------------------------------------------------------------------
 * IFU: Instruction Fetch Unit
 * ------------------------------------------------------------------------------------------------
 * IFU includes the following functions:
 * 1. IFU hold PC register and the logic to update PC
 * 2. IFU generate the address and control signals for accessing the Instruction RAM
 * ------------------------------------------------------------------------------------------------
 */

`include "config.svh"

module ifu (
    input  logic                clk,
    input  logic                rst_b,
    // Instruction RAM Access
    output logic                ram_req,
    output logic                ram_write,      // 1: write, 0: read
    output logic [`XLEN/8-1:0]  ram_wstrb,      // write strobe (write byte enable)
    output logic [`XLEN-1:0]    ram_addr,       // address
    output logic [`XLEN-1:0]    ram_wdata,
    output logic                ram_addr_ok,
    input  logic                ram_data_ok,
    input  logic [`XLEN-1:0]    ram_rdata,
    // Instruction and PC
    output logic [`XLEN-1:0]    pc_val,
    output logic [`XLEN-1:0]    instruction,
    output logic                instr_valid
);

    logic [`XLEN-1:0]   pc;
    logic [`XLEN-1:0]   next_pc;

    // -------------------------------------------
    // Instruction RAM logic
    // -------------------------------------------
    // 1. always read the instruction ram
    // 2. Assume that the ram is synchronouse ram and data come back at the next clock cycle
    // 3. We introduce a "Pre IF" stage where we update the PC. We send the read request on
    // the "Pre IF" stage and the address is next_pc so when data comes back it is in IF stage
    assign ram_req = 1'b1;
    assign ram_write = 1'b0;
    assign ram_wstrb = '0;
    assign ram_addr = next_pc;
    assign ram_wdata = '0;

    // -------------------------------------------
    // PC logic
    // -------------------------------------------

    assign pc_val = pc;
    assign next_pc = pc + `XLEN'h4;

    always @(posedge clk) begin
        if (!rst_b) begin
            pc <= `PC_RESET_ADDR - 4; // because we use next_pc for ram address, we need to minus 4 here
        end
        else begin
            pc <= next_pc;
        end
    end

    // -------------------------------------------
    // Instruction logic
    // -------------------------------------------

    assign instruction = ram_rdata;
    assign instr_valid = ram_data_ok;

endmodule
/* ------------------------------------------------------------------------------------------------
 * Copyright (c) 2022. Heqing Huang (feipenghhq@gmail.com)
 *
 * Project: RVCoreF
 * Author: Heqing Huang
 * Date Created: 08/31/2023
 *
 * ------------------------------------------------------------------------------------------------
 * riscv_tests_tb: Testbench for riscv_tests
 * ------------------------------------------------------------------------------------------------
 */

`timescale 1ns/10ps

`define RAM_PATH u_minisoc.memory.mem
`define REG_PATH u_minisoc.u_core.u_id.u_regfile.register

module tb();

    logic       clk;
    logic       rst_b;
    logic [7:0] GPIO;

    // ------------------------------
    // DUT
    // ------------------------------
    minisoc u_minisoc (.*);

    // ------------------------------
    // Drive clock and reset
    // ------------------------------
    // clocks
    initial clk = 0;
    always #5 clk = ~clk;
    // rst_b
    initial begin
        rst_b = 1'b0;
        repeat (5) @(posedge clk);
        #0 rst_b = 1'b1;
    end

    // ------------------------------
    // Load the memory
    // ------------------------------
    // read memory data (including both instruction and data)
    initial begin
        $readmemh("memory.data", `RAM_PATH);
    end

    // ------------------------------
    // Run test and check if the test passed or failed
    // ------------------------------

    initial begin
        fork
            test_timeout();
            check_test();
        join_any
    end

    // FAIL signature: x28 = 1 && x29 = 0
    // PASS signature: x28 = 1 && x29 = 1
    task check_test;
        logic           pass;
        logic           fail;
        logic [31:0]    test_num;
        while (1) begin
            #1000; // Check the result every 1000 ns
            pass = (`REG_PATH[28] == 1) && (`REG_PATH[29] == 1);
            fail = (`REG_PATH[28] == 1) && (`REG_PATH[29] == 0);
            test_num = `REG_PATH[3];
            if (pass) begin
                $info("TEST RESULT: PASS");
                #100;
                $finish;
            end
            else if (fail) begin
                $fatal(1, "TEST RESULT: FAIL.\nFailed Test Case: %0d", test_num);
                #100;
            end
        end
    endtask

    task test_timeout;
        #10000;
        $fatal(2, "TEST TIMEOUT");
    endtask

    initial begin
        if ($test$plusargs("DUMP")) begin
            $dumpfile("dump.vcd");
            $dumpvars(0,tb);
        end
    end

endmodule
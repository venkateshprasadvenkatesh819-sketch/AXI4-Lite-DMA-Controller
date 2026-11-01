`timescale 1ns/1ps

module tb_sync_fifo;

parameter DATA_WIDTH = 32;
    parameter DEPTH      = 16;

logic clk;
    logic rst_n;

logic wr_en;
    logic [DATA_WIDTH-1:0] data_in;

logic rd_en;
    logic [DATA_WIDTH-1:0] data_out;

logic full;
    logic empty;

    integer i;

// DUT
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .data_in(data_in),
        .rd_en(rd_en),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );

// Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

// FIFO write task
    task automatic fifo_write(input logic [31:0] data);
        begin
            @(negedge clk);

if (full)
                $fatal(1, "WRITE TASK ERROR: FIFO is full");

wr_en   = 1;
            data_in = data;

@(posedge clk);
            #1;

@(negedge clk);
            wr_en = 0;

$display("WRITE PASS: %h", data);
        end
    endtask

// FIFO read task
    task automatic fifo_read(input logic [31:0] expected);
        begin
            @(negedge clk);

if (empty)
                $fatal(1, "READ TASK ERROR: FIFO is empty");

            rd_en = 1;

@(posedge clk);
            #1;

if (data_out !== expected)
                $fatal(1,
                    "READ FAIL: Expected=%h Actual=%h",
                    expected, data_out);

            $display("READ PASS: %h", data_out);

@(negedge clk);
            rd_en = 0;
        end
    endtask

// Main test sequence
    initial begin

rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 0;

        $display("\n===== ADVANCED FIFO VERIFICATION START =====");

// TEST 1: Reset
        repeat (3) @(negedge clk);
        rst_n = 1;

        #1;

if (empty && !full)
            $display("RESET PASS");
        else
            $fatal(1, "RESET FAIL");

// TEST 2: Basic write and read
        $display("\n===== BASIC FIFO TEST =====");

fifo_write(32'h11111111);
        fifo_write(32'h22222222);
        fifo_write(32'h33333333);
        fifo_write(32'h44444444);

fifo_read(32'h11111111);
        fifo_read(32'h22222222);
        fifo_read(32'h33333333);
        fifo_read(32'h44444444);

if (empty)
            $display("BASIC FIFO TEST PASS");
        else
            $fatal(1, "BASIC FIFO TEST FAIL");

// TEST 3: Normal simultaneous read and write
        $display("\n===== NORMAL SIMULTANEOUS READ/WRITE =====");

        fifo_write(32'hAAAAAAAA);

@(negedge clk);
        wr_en   = 1;
        rd_en   = 1;
        data_in = 32'hBBBBBBBB;

@(posedge clk);
        #1;

if (data_out !== 32'hAAAAAAAA)
            $fatal(1, "NORMAL SIMULTANEOUS READ DATA FAIL");

if (empty || full)
            $fatal(1, "NORMAL SIMULTANEOUS COUNT FAIL");

        $display("NORMAL SIMULTANEOUS READ/WRITE PASS");

@(negedge clk);
        wr_en = 0;
        rd_en = 0;

        fifo_read(32'hBBBBBBBB);

if (!empty)
            $fatal(1, "FIFO SHOULD BE EMPTY");

        $display("NORMAL SIMULTANEOUS DATA ORDER PASS");

// TEST 4: Fill FIFO completely
        $display("\n===== FIFO FULL TEST =====");

        for (i = 0; i <DEPTH; i = i + 1)
            fifo_write(32'hA0000000 + i);

if (full && !empty)
            $display("FULL FLAG PASS");
        else
            $fatal(1, "FULL FLAG FAIL");

// TEST 5: Overflow protection
        $display("\n===== OVERFLOW PROTECTION TEST =====");

@(negedge clk);
        wr_en   = 1;
        data_in = 32'hDEADBEEF;

@(posedge clk);
        #1;

if (!full)
            $fatal(1, "OVERFLOW PROTECTION FAIL");

@(negedge clk);
        wr_en = 0;

        $display("OVERFLOW PROTECTION PASS");

// TEST 6: Full boundary simultaneous read and write
        $display("\n===== FULL BOUNDARY READ/WRITE TEST =====");

@(negedge clk);
        wr_en   = 1;
        rd_en   = 1;
        data_in = 32'hDEADBEEF;

@(posedge clk);
        #1;

if (data_out !== 32'hA0000000)
            $fatal(1, "FULL BOUNDARY: OLD DATA READ FAIL");

if (!full)
            $fatal(1, "FULL BOUNDARY: FIFO SHOULD REMAIN FULL");

        $display("FULL BOUNDARY READ/WRITE PASS");

@(negedge clk);
        wr_en = 0;
        rd_en = 0;

// TEST 7: Drain and verify FIFO order
        $display("\n===== FIFO DRAIN AND DATA ORDER TEST =====");

        for (i = 1; i <DEPTH; i = i + 1)
            fifo_read(32'hA0000000 + i);

        fifo_read(32'hDEADBEEF);

if (!empty)
            $fatal(1, "FIFO DRAIN FAIL");

        $display("FIFO DRAIN AND DATA ORDER PASS");

// TEST 8: Empty boundary simultaneous read and write
        $display("\n===== EMPTY BOUNDARY READ/WRITE TEST =====");

@(negedge clk);
        wr_en   = 1;
        rd_en   = 1;
        data_in = 32'hCAFEBABE;

@(posedge clk);
        #1;

if (empty)
            $fatal(1, "EMPTY BOUNDARY: WRITE WAS NOT ACCEPTED");

        $display("EMPTY BOUNDARY: WRITE ACCEPTED, READ REJECTED");

@(negedge clk);
        wr_en = 0;
        rd_en = 0;

        fifo_read(32'hCAFEBABE);

if (!empty)
            $fatal(1, "EMPTY BOUNDARY DATA CHECK FAIL");

        $display("EMPTY BOUNDARY READ/WRITE PASS");

// TEST 9: Underflow protection
        $display("\n===== UNDERFLOW PROTECTION TEST =====");

@(negedge clk);
        rd_en = 1;

@(posedge clk);
        #1;

if (!empty)
            $fatal(1, "UNDERFLOW PROTECTION FAIL");

@(negedge clk);
        rd_en = 0;

        $display("UNDERFLOW PROTECTION PASS");

// TEST 10: Reset during active operation
        $display("\n===== RESET DURING ACTIVE OPERATION =====");

        fifo_write(32'h12345678);

@(negedge clk);
        wr_en   = 1;
        rd_en   = 1;
        data_in = 32'h87654321;
        rst_n   = 0;

        #1;

if (!empty || full || data_out !== 0)
            $fatal(1, "ACTIVE RESET FAIL");

        $display("ASYNCHRONOUS RESET PASS");

@(negedge clk);
        wr_en = 0;
        rd_en = 0;
        rst_n = 1;

@(posedge clk);
        #1;

if (!empty || full)
            $fatal(1, "FIFO RESET RELEASE FAIL");

        $display("RESET RELEASE PASS");

// Final result
        $display("\n===== ALL ADVANCED FIFO TESTS PASSED =====");

#20;
        $finish;

    end

endmodule
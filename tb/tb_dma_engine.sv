`timescale 1ns/1ps

module tb_dma_engine;

parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter FIFO_DEPTH = 16;

logic clk;
    logic rst_n;

    logic start;

logic [ADDR_WIDTH-1:0] source_addr;
    logic [ADDR_WIDTH-1:0] dest_addr;
    logic [31:0] transfer_length;

logic busy;
    logic done;
    logic error;

logic mem_rd_en;
    logic [ADDR_WIDTH-1:0] mem_rd_addr;
    logic mem_rd_valid;
    logic [DATA_WIDTH-1:0] mem_rd_data;

logic mem_wr_en;
    logic [ADDR_WIDTH-1:0] mem_wr_addr;
    logic [DATA_WIDTH-1:0] mem_wr_data;
    logic mem_wr_ready;

// Memory models: 256 words each
    logic [31:0] source_memory [0:255];
    logic [31:0] dest_memory [0:255];

    integer i;

// DUT
    dma_engine #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

.start(start),
        .source_addr(source_addr),
        .dest_addr(dest_addr),
        .transfer_length(transfer_length),

.busy(busy),
        .done(done),
        .error(error),

.mem_rd_en(mem_rd_en),
        .mem_rd_addr(mem_rd_addr),
        .mem_rd_valid(mem_rd_valid),
        .mem_rd_data(mem_rd_data),

.mem_wr_en(mem_wr_en),
        .mem_wr_addr(mem_wr_addr),
        .mem_wr_data(mem_wr_data),
        .mem_wr_ready(mem_wr_ready)
    );

// Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

// Memory read and write model
    always @(posedge clk or negedge rst_n) begin


if (!rst_n) begin
    mem_rd_valid <= 0;
    mem_rd_data  <= 0;
end
else begin

    mem_rd_valid <= 0;

    // Source memory read response
    if (mem_rd_en) begin
        mem_rd_data  <= source_memory[mem_rd_addr[9:2]];
        mem_rd_valid <= 1;
    end

    // Destination memory write
    if (mem_wr_en && mem_wr_ready) begin
        dest_memory[mem_wr_addr[9:2]] <= mem_wr_data;

        $display("MEM WRITE: Address=%h Data=%h",
                 mem_wr_addr, mem_wr_data);
    end

end

end

// Main test
initial begin

    rst_n = 0;
    start = 0;

    source_addr = 0;
    dest_addr = 0;
    transfer_length = 0;

    mem_wr_ready = 1;

    $display("\n===== DMA ENGINE TEST START =====");

    // Initialize memories
    for (i = 0; i < 256; i = i + 1) begin
        source_memory[i] = 32'h10000000 + i;
        dest_memory[i] = 0;
    end

    // Reset
    repeat (3) @(negedge clk);
    rst_n = 1;

    $display("RESET PASS");

    // Configure DMA
    source_addr = 32'h00000010;
    dest_addr = 32'h00000080;
    transfer_length = 4;

    $display("\n===== DMA TRANSFER TEST =====");

    // Start DMA
    @(negedge clk);
    start = 1;

    @(negedge clk);
    start = 0;

    // Wait for completion
    wait(done || error);

    if (error)
        $fatal(1, "DMA TRANSFER ERROR");

    $display("DMA DONE SIGNAL PASS");

    // Verify destination memory
    for (i = 0; i < 4; i = i + 1) begin

        if (dest_memory[32 + i] !== source_memory[4 + i]) begin
            $fatal(1,
                "DATA MISMATCH: Index=%0d Expected=%h Actual=%h",
                i,
                source_memory[4 + i],
                dest_memory[32 + i]
            );
        end

        $display("DATA CHECK PASS: Source=%h Destination=%h",
                 source_memory[4 + i],
                 dest_memory[32 + i]);

    end

    $display("DMA DATA TRANSFER PASS");

    // Check busy status
    @(posedge clk);
    #1;

    if (busy)
        $fatal(1, "BUSY SHOULD BE LOW");

    $display("DMA BUSY STATUS PASS");

    // Zero-length error test
    $display("\n===== ZERO LENGTH ERROR TEST =====");

    @(negedge clk);
    transfer_length = 0;
    start = 1;

    @(negedge clk);
    start = 0;

    wait(error);

    $display("ZERO LENGTH ERROR PASS");

    $display("\n===== ALL DMA TESTS PASSED =====");

    #20;
    $finish;

end

// Timeout protection
initial begin
    #10000;
    $fatal(1, "DMA TEST TIMEOUT");
end

endmodule

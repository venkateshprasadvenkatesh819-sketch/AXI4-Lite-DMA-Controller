`timescale 1ns/1ps

module tb_dma_top;

    // ------------------------------------------------
    // CLOCK AND RESET
    // ------------------------------------------------

    logic ACLK;
    logic ARESETN;

    initial begin
        ACLK = 1'b0;
        forever #5 ACLK = ~ACLK;
    end

    // ------------------------------------------------
    // AXI4-LITE SIGNALS
    // ------------------------------------------------

    logic [31:0] S_AXI_AWADDR;
    logic        S_AXI_AWVALID;
    logic        S_AXI_AWREADY;

    logic [31:0] S_AXI_WDATA;
    logic [3:0]  S_AXI_WSTRB;
    logic        S_AXI_WVALID;
    logic        S_AXI_WREADY;

    logic [1:0]  S_AXI_BRESP;
    logic        S_AXI_BVALID;
    logic        S_AXI_BREADY;

    logic [31:0] S_AXI_ARADDR;
    logic        S_AXI_ARVALID;
    logic        S_AXI_ARREADY;

    logic [31:0] S_AXI_RDATA;
    logic [1:0]  S_AXI_RRESP;
    logic        S_AXI_RVALID;
    logic        S_AXI_RREADY;

    // ------------------------------------------------
    // MEMORY INTERFACE
    // ------------------------------------------------

    logic        mem_rd_en;
    logic [31:0] mem_rd_addr;
    logic        mem_rd_valid;
    logic [31:0] mem_rd_data;

    logic        mem_wr_en;
    logic [31:0] mem_wr_addr;
    logic [31:0] mem_wr_data;
    logic        mem_wr_ready;

    // ------------------------------------------------
    // DMA STATUS
    // ------------------------------------------------

    logic dma_busy;
    logic dma_done;
    logic dma_error;
    logic irq;

    // ------------------------------------------------
    // MEMORY ARRAYS
    // ------------------------------------------------

    logic [31:0] source_memory [0:255];
    logic [31:0] destination_memory [0:255];

    integer i;
    integer timeout_count;

    logic done_seen;
    logic error_seen;
    logic irq_seen;

    // ------------------------------------------------
    // DUT INSTANTIATION
    // ------------------------------------------------

    dma_top #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .FIFO_DEPTH(16)
    ) DUT (
        .ACLK(ACLK),
        .ARESETN(ARESETN),

        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),

        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),

        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),

        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),

        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),

        .mem_rd_en(mem_rd_en),
        .mem_rd_addr(mem_rd_addr),
        .mem_rd_valid(mem_rd_valid),
        .mem_rd_data(mem_rd_data),

        .mem_wr_en(mem_wr_en),
        .mem_wr_addr(mem_wr_addr),
        .mem_wr_data(mem_wr_data),
        .mem_wr_ready(mem_wr_ready),

        .dma_busy(dma_busy),
        .dma_done(dma_done),
        .dma_error(dma_error),
        .irq(irq)
    );
    initial begin
    $dumpfile("dma_top.vcd");
    $dumpvars(0, tb_dma_top);
end

    // ------------------------------------------------
    // MEMORY MODEL
    // ------------------------------------------------

    assign mem_wr_ready = 1'b1;

    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            mem_rd_valid <= 1'b0;
            mem_rd_data  <= 32'd0;
        end
        else begin

            // Default: no read response
            mem_rd_valid <= 1'b0;

            // Read response
            if (mem_rd_en) begin
                mem_rd_valid <= 1'b1;
                mem_rd_data <= source_memory[mem_rd_addr[9:2]];
            end

            // Write destination memory
            if (mem_wr_en && mem_wr_ready) begin
                destination_memory[mem_wr_addr[9:2]]
                    <= mem_wr_data;
            end
        end
    end

    // ------------------------------------------------
    // MONITOR COMPLETION AND INTERRUPT PULSES
    // ------------------------------------------------

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            done_seen  <= 1'b0;
            error_seen <= 1'b0;
            irq_seen   <= 1'b0;
        end
        else begin
            if (dma_done)
                done_seen <= 1'b1;

            if (dma_error)
                error_seen <= 1'b1;

            if (irq)
                irq_seen <= 1'b1;
        end
    end

    // ------------------------------------------------
    // AXI WRITE TASK
    // ------------------------------------------------

    task automatic axi_write(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [3:0]  strobe
    );

        integer aw_done;
        integer w_done;

        begin
            aw_done = 0;
            w_done  = 0;

            @(negedge ACLK);

            S_AXI_AWADDR  = address;
            S_AXI_AWVALID = 1'b1;

            S_AXI_WDATA  = data;
            S_AXI_WSTRB  = strobe;
            S_AXI_WVALID = 1'b1;

            // AW and W channels are handled independently
            while (!aw_done || !w_done) begin

                @(posedge ACLK);

                if (!aw_done && S_AXI_AWREADY)
                    aw_done = 1;

                if (!w_done && S_AXI_WREADY)
                    w_done = 1;

                @(negedge ACLK);

                if (aw_done)
                    S_AXI_AWVALID = 1'b0;

                if (w_done)
                    S_AXI_WVALID = 1'b0;
            end

            // Wait for write response
            while (S_AXI_BVALID !== 1'b1)
                @(negedge ACLK);

            S_AXI_BREADY = 1'b1;

            @(posedge ACLK);

            if (S_AXI_BRESP !== 2'b00)
                $fatal(1, "AXI WRITE FAILED: Address=%h BRESP=%b",
                       address, S_AXI_BRESP);

            @(negedge ACLK);
            S_AXI_BREADY = 1'b0;

            $display("AXI WRITE PASS: Address=%h Data=%h",
                     address, data);
        end

    endtask

    // ------------------------------------------------
    // AXI READ TASK
    // ------------------------------------------------

    task automatic axi_read(
        input  logic [31:0] address,
        output logic [31:0] read_data
    );

        logic [1:0] response;

        begin
            @(negedge ACLK);

            S_AXI_ARADDR  = address;
            S_AXI_ARVALID = 1'b1;

            // Address handshake
            do begin
                @(posedge ACLK);
            end while (!S_AXI_ARREADY);

            @(negedge ACLK);
            S_AXI_ARVALID = 1'b0;

            // Wait for read response
            while (S_AXI_RVALID !== 1'b1)
                @(negedge ACLK);

            S_AXI_RREADY = 1'b1;

            @(posedge ACLK);

            read_data = S_AXI_RDATA;
            response  = S_AXI_RRESP;

            if (response !== 2'b00)
                $fatal(1, "AXI READ FAILED: Address=%h RRESP=%b",
                       address, response);

            @(negedge ACLK);
            S_AXI_RREADY = 1'b0;

            $display("AXI READ PASS: Address=%h Data=%h",
                     address, read_data);
        end

    endtask

    // ------------------------------------------------
    // MAIN TEST SEQUENCE
    // ------------------------------------------------

    logic [31:0] read_value;

    initial begin

        $display("");
        $display("========================================");
        $display(" AXI4-LITE DMA INTEGRATION TEST START");
        $display("========================================");

        // Initialize AXI signals
        S_AXI_AWADDR  = 0;
        S_AXI_AWVALID = 0;
        S_AXI_WDATA   = 0;
        S_AXI_WSTRB   = 0;
        S_AXI_WVALID  = 0;
        S_AXI_BREADY  = 0;

        S_AXI_ARADDR  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;

        ARESETN = 1'b0;

        // Initialize memories
        for (i = 0; i < 256; i = i + 1) begin
            source_memory[i] =
                32'h10000000 + i;

            destination_memory[i] = 32'd0;
        end

        repeat (5) @(negedge ACLK);

        ARESETN = 1'b1;

        repeat (3) @(negedge ACLK);

        $display("RESET PASS");

        // --------------------------------------------
        // TEST 1: PROGRAM DMA REGISTERS
        // --------------------------------------------

        $display("");
        $display("===== DMA CONFIGURATION TEST =====");

        // Source address = 0x10 (word index 4)
        axi_write(32'h00000004, 32'h00000010, 4'b1111);

        // Destination address = 0x80 (word index 32)
        axi_write(32'h00000008, 32'h00000080, 4'b1111);

        // Transfer length = 4 words
        axi_write(32'h0000000C, 32'h00000004, 4'b1111);

        // Read back configuration
        axi_read(32'h00000004, read_value);

        if (read_value !== 32'h00000010)
            $fatal(1, "SOURCE ADDRESS READBACK FAILED");

        axi_read(32'h00000008, read_value);

        if (read_value !== 32'h00000080)
            $fatal(1, "DESTINATION ADDRESS READBACK FAILED");

        axi_read(32'h0000000C, read_value);

        if (read_value !== 32'h00000004)
            $fatal(1, "TRANSFER LENGTH READBACK FAILED");

        $display("DMA CONFIGURATION PASS");

        // --------------------------------------------
        // TEST 2: START DMA
        // --------------------------------------------

        $display("");
        $display("===== DMA TRANSFER TEST =====");

        done_seen  = 1'b0;
        error_seen = 1'b0;
        irq_seen   = 1'b0;

        axi_write(32'h00000000, 32'h00000001, 4'b1111);

        // Wait for DMA completion with timeout
        timeout_count = 0;

        while (!done_seen && !error_seen &&
               timeout_count < 500) begin

            @(negedge ACLK);
            timeout_count = timeout_count + 1;

        end

        if (timeout_count >= 500)
            $fatal(1, "DMA TIMEOUT");

        if (error_seen)
            $fatal(1, "DMA REPORTED ERROR DURING VALID TRANSFER");

        if (!done_seen)
            $fatal(1, "DMA COMPLETION NOT DETECTED");

        $display("DMA COMPLETION PASS");

        // --------------------------------------------
        // TEST 3: VERIFY DESTINATION MEMORY
        // --------------------------------------------

        $display("");
        $display("===== DATA INTEGRITY TEST =====");

        for (i = 0; i < 4; i = i + 1) begin

            $display(
                "SOURCE[%0d] = %h | DESTINATION[%0d] = %h",
                i + 4,
                source_memory[i + 4],
                i + 32,
                destination_memory[i + 32]
            );

            if (destination_memory[i + 32] !==
                source_memory[i + 4]) begin

                $fatal(1,
                    "DATA MISMATCH at destination index %0d",
                    i + 32);
            end

        end

        $display("DATA INTEGRITY PASS");
        $display("4 WORDS TRANSFERRED SUCCESSFULLY");

        if (!irq_seen)
            $fatal(1, "DMA INTERRUPT NOT DETECTED");

        $display("IRQ PASS");

        // --------------------------------------------
        // TEST 4: ZERO-LENGTH ERROR
        // --------------------------------------------

        $display("");
        $display("===== ZERO LENGTH ERROR TEST =====");

        // Clear the start control bit
        axi_write(32'h00000000, 32'h00000000, 4'b1111);

        // Set transfer length to zero
        axi_write(32'h0000000C, 32'h00000000, 4'b1111);

        // Clear previous status observations
        done_seen  = 1'b0;
        error_seen = 1'b0;
        irq_seen   = 1'b0;

        // Start invalid transfer
        axi_write(32'h00000000, 32'h00000001, 4'b1111);

        timeout_count = 0;

        while (!error_seen && timeout_count < 100) begin
            @(negedge ACLK);
            timeout_count = timeout_count + 1;
        end

        if (!error_seen)
            $fatal(1, "ZERO LENGTH ERROR NOT DETECTED");

        $display("ZERO LENGTH ERROR PASS");

        // --------------------------------------------
        // FINAL RESULT
        // --------------------------------------------

        $display("");
        $display("========================================");
        $display(" ALL INTEGRATED DMA TESTS PASSED");
        $display("========================================");

        #20;
        $finish;

    end

endmodule
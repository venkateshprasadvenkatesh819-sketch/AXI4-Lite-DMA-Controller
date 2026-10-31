
`timescale 1ns/1ps

module tb_axi_lite_regs;

    logic ACLK;
    logic ARESETN;

    logic [31:0] S_AXI_AWADDR;
    logic S_AXI_AWVALID;
    logic S_AXI_AWREADY;

    logic [31:0] S_AXI_WDATA;
    logic [3:0] S_AXI_WSTRB;
    logic S_AXI_WVALID;
    logic S_AXI_WREADY;

    logic [1:0] S_AXI_BRESP;
    logic S_AXI_BVALID;
    logic S_AXI_BREADY;

    logic [31:0] S_AXI_ARADDR;
    logic S_AXI_ARVALID;
    logic S_AXI_ARREADY;

    logic [31:0] S_AXI_RDATA;
    logic [1:0] S_AXI_RRESP;
    logic S_AXI_RVALID;
    logic S_AXI_RREADY;

    logic dma_start;
    logic [31:0] source_addr;
    logic [31:0] dest_addr;
    logic [31:0] transfer_length;

    logic dma_busy;
    logic dma_done;
    logic dma_error;
    logic irq_status;

    integer timeout_count;

    // DUT
    axi_lite_regs dut (
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

        .dma_start(dma_start),
        .source_addr(source_addr),
        .dest_addr(dest_addr),
        .transfer_length(transfer_length),

        .dma_busy(dma_busy),
        .dma_done(dma_done),
        .dma_error(dma_error),
        .irq_status(irq_status)
    );

    // Clock generation: 10 ns period
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;
    end

    // AXI write task
    task automatic axi_write(
        input logic [31:0] address,
        input logic [31:0] data
    );
        begin
            @(negedge ACLK);
            S_AXI_AWADDR  = address;
            S_AXI_AWVALID = 1;
            S_AXI_WDATA   = data;
            S_AXI_WSTRB   = 4'b1111;
            S_AXI_WVALID  = 1;

            wait (S_AXI_AWREADY && S_AXI_WREADY);
            @(negedge ACLK);
            S_AXI_AWVALID = 0;
            S_AXI_WVALID  = 0;

            timeout_count = 0;
            while (!S_AXI_BVALID && timeout_count < 20) begin
                @(negedge ACLK);
                timeout_count = timeout_count + 1;
            end

            if (!S_AXI_BVALID)
                $fatal(1, "WRITE TIMEOUT: address=%h", address);

            if (S_AXI_BRESP == 2'b00)
                $display("WRITE PASS: Address=%h Data=%h", address, data);
            else
                $fatal(1, "WRITE FAIL: Address=%h BRESP=%b",
                       address, S_AXI_BRESP);

            S_AXI_BREADY = 1;
            @(negedge ACLK);
            S_AXI_BREADY = 0;
        end
    endtask

    // AXI read task
    task automatic axi_read(
        input logic [31:0] address,
        input logic [31:0] expected_data
    );
        begin
            @(negedge ACLK);
            S_AXI_ARADDR  = address;
            S_AXI_ARVALID = 1;

            wait (S_AXI_ARREADY);
            @(negedge ACLK);
            S_AXI_ARVALID = 0;

            timeout_count = 0;
            while (!S_AXI_RVALID && timeout_count < 20) begin
                @(negedge ACLK);
                timeout_count = timeout_count + 1;
            end

            if (!S_AXI_RVALID)
                $fatal(1, "READ TIMEOUT: address=%h", address);

            if (S_AXI_RRESP != 2'b00)
                $fatal(1, "READ RESPONSE FAIL: address=%h RRESP=%b",
                       address, S_AXI_RRESP);

            if (S_AXI_RDATA !== expected_data)
                $fatal(1, "READ DATA FAIL: address=%h Expected=%h Actual=%h",
                       address, expected_data, S_AXI_RDATA);

            $display("READ PASS: Address=%h Data=%h",
                     address, S_AXI_RDATA);

            S_AXI_RREADY = 1;
            @(negedge ACLK);
            S_AXI_RREADY = 0;
        end
    endtask

    // Independent AW/W channel test: address first, data later
    task automatic axi_write_split(
        input logic [31:0] address,
        input logic [31:0] data
    );
        begin
            @(negedge ACLK);
            S_AXI_AWADDR  = address;
            S_AXI_AWVALID = 1;

            wait (S_AXI_AWREADY);
            @(negedge ACLK);
            S_AXI_AWVALID = 0;

            repeat (2) @(negedge ACLK);

            S_AXI_WDATA  = data;
            S_AXI_WSTRB  = 4'b1111;
            S_AXI_WVALID = 1;

            wait (S_AXI_WREADY);
            @(negedge ACLK);
            S_AXI_WVALID = 0;

            timeout_count = 0;
            while (!S_AXI_BVALID && timeout_count < 20) begin
                @(negedge ACLK);
                timeout_count = timeout_count + 1;
            end

            if (!S_AXI_BVALID)
                $fatal(1, "SPLIT WRITE TIMEOUT");

            if (S_AXI_BRESP != 2'b00)
                $fatal(1, "SPLIT WRITE FAIL: BRESP=%b", S_AXI_BRESP);

            $display("INDEPENDENT AW/W PASS");

            S_AXI_BREADY = 1;
            @(negedge ACLK);
            S_AXI_BREADY = 0;
        end
    endtask

    // Byte-strobe write task
    task automatic axi_write_masked(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [3:0] strb
    );
        begin
            @(negedge ACLK);
            S_AXI_AWADDR  = address;
            S_AXI_AWVALID = 1;
            S_AXI_WDATA   = data;
            S_AXI_WSTRB   = strb;
            S_AXI_WVALID  = 1;

            wait (S_AXI_AWREADY && S_AXI_WREADY);
            @(negedge ACLK);
            S_AXI_AWVALID = 0;
            S_AXI_WVALID  = 0;

            timeout_count = 0;
            while (!S_AXI_BVALID && timeout_count < 20) begin
                @(negedge ACLK);
                timeout_count = timeout_count + 1;
            end

            if (!S_AXI_BVALID)
                $fatal(1, "MASKED WRITE TIMEOUT");

            if (S_AXI_BRESP != 2'b00)
                $fatal(1, "MASKED WRITE FAIL: BRESP=%b", S_AXI_BRESP);

            $display("BYTE STROBE WRITE PASS");

            S_AXI_BREADY = 1;
            @(negedge ACLK);
            S_AXI_BREADY = 0;
        end
    endtask

    // Invalid write address test
    task automatic invalid_write_test;
        begin
            @(negedge ACLK);
            S_AXI_AWADDR  = 32'h20;
            S_AXI_AWVALID = 1;
            S_AXI_WDATA   = 32'h12345678;
            S_AXI_WSTRB   = 4'b1111;
            S_AXI_WVALID  = 1;

            wait (S_AXI_AWREADY && S_AXI_WREADY);
            @(negedge ACLK);
            S_AXI_AWVALID = 0;
            S_AXI_WVALID  = 0;

            timeout_count = 0;
            while (!S_AXI_BVALID && timeout_count < 20) begin
                @(negedge ACLK);
                timeout_count = timeout_count + 1;
            end

            if (!S_AXI_BVALID)
                $fatal(1, "INVALID WRITE TIMEOUT");

            if (S_AXI_BRESP != 2'b10)
                $fatal(1, "INVALID WRITE RESPONSE FAIL: BRESP=%b",
                       S_AXI_BRESP);

            $display("INVALID WRITE ADDRESS PASS");

            S_AXI_BREADY = 1;
            @(negedge ACLK);
            S_AXI_BREADY = 0;
        end
    endtask

    // Invalid read address test
    task automatic invalid_read_test;
        begin
            @(negedge ACLK);
            S_AXI_ARADDR  = 32'h20;
            S_AXI_ARVALID = 1;

            wait (S_AXI_ARREADY);
            @(negedge ACLK);
            S_AXI_ARVALID = 0;

            timeout_count = 0;
            while (!S_AXI_RVALID && timeout_count < 20) begin
                @(negedge ACLK);
                timeout_count = timeout_count + 1;
            end

            if (!S_AXI_RVALID)
                $fatal(1, "INVALID READ TIMEOUT");

            if (S_AXI_RRESP != 2'b10)
                $fatal(1, "INVALID READ RESPONSE FAIL: RRESP=%b",
                       S_AXI_RRESP);

            $display("INVALID READ ADDRESS PASS");

            S_AXI_RREADY = 1;
            @(negedge ACLK);
            S_AXI_RREADY = 0;
        end
    endtask

    // Write response backpressure test
    task automatic write_backpressure_test;
        logic [1:0] saved_response;
        begin
            @(negedge ACLK);
            S_AXI_AWADDR  = 32'h08;
            S_AXI_AWVALID = 1;
            S_AXI_WDATA   = 32'h40000000;
            S_AXI_WSTRB   = 4'b1111;
            S_AXI_WVALID  = 1;

            wait (S_AXI_AWREADY && S_AXI_WREADY);
            @(negedge ACLK);
            S_AXI_AWVALID = 0;
            S_AXI_WVALID  = 0;

            timeout_count = 0;
            while (!S_AXI_BVALID && timeout_count < 20) begin
                @(negedge ACLK);
                timeout_count = timeout_count + 1;
            end

            if (!S_AXI_BVALID)
                $fatal(1, "WRITE BACKPRESSURE TIMEOUT");

            saved_response = S_AXI_BRESP;
            repeat (3) begin
                @(negedge ACLK);
                if (!S_AXI_BVALID || S_AXI_BRESP !== saved_response)
                    $fatal(1, "WRITE BACKPRESSURE FAIL");
            end

            $display("WRITE BACKPRESSURE PASS");

            S_AXI_BREADY = 1;
            @(negedge ACLK);
            S_AXI_BREADY = 0;
        end
    endtask

    // Read response backpressure test
    task automatic read_backpressure_test;
        logic [31:0] saved_data;
        logic [1:0] saved_response;
        begin
            @(negedge ACLK);
            S_AXI_ARADDR  = 32'h08;
            S_AXI_ARVALID = 1;

            wait (S_AXI_ARREADY);
            @(negedge ACLK);
            S_AXI_ARVALID = 0;

            timeout_count = 0;
            while (!S_AXI_RVALID && timeout_count < 20) begin
                @(negedge ACLK);
                timeout_count = timeout_count + 1;
            end

            if (!S_AXI_RVALID)
                $fatal(1, "READ BACKPRESSURE TIMEOUT");

            saved_data = S_AXI_RDATA;
            saved_response = S_AXI_RRESP;

            repeat (3) begin
                @(negedge ACLK);
                if (!S_AXI_RVALID ||
                    S_AXI_RDATA !== saved_data ||
                    S_AXI_RRESP !== saved_response)
                    $fatal(1, "READ BACKPRESSURE FAIL");
            end

            $display("READ BACKPRESSURE PASS");

            S_AXI_RREADY = 1;
            @(negedge ACLK);
            S_AXI_RREADY = 0;
        end
    endtask

    // Main test sequence
    initial begin

        ARESETN = 0;

        S_AXI_AWADDR  = 0;
        S_AXI_AWVALID = 0;
        S_AXI_WDATA   = 0;
        S_AXI_WSTRB   = 0;
        S_AXI_WVALID  = 0;
        S_AXI_BREADY  = 0;

        S_AXI_ARADDR  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;

        dma_busy  = 0;
        dma_done  = 0;
        dma_error = 0;
        irq_status = 0;

        repeat (3) @(negedge ACLK);
        ARESETN = 1;

        $display("\n===== AXI4-LITE REGISTER TEST START =====");

        // TEST 1: Basic register writes
        axi_write(32'h04, 32'h10000000);
        axi_write(32'h08, 32'h20000000);
        axi_write(32'h0C, 32'h00000010);
        axi_write(32'h00, 32'h00000001);

        // TEST 2: Independent AW/W channels
        $display("\n===== INDEPENDENT AW/W TEST =====");
        axi_write_split(32'h08, 32'h30000000);
        axi_read(32'h08, 32'h30000000);

        // TEST 3: Byte strobes
        $display("\n===== BYTE STROBE TEST =====");
        axi_write_masked(32'h04, 32'hAABBCCDD, 4'b0010);
        axi_read(32'h04, 32'h1000CC00);

        // TEST 4: Register readback
        $display("\n===== REGISTER READBACK TEST =====");
        axi_read(32'h04, 32'h1000CC00);
        axi_read(32'h08, 32'h30000000);
        axi_read(32'h0C, 32'h00000010);
        axi_read(32'h00, 32'h00000001);

        // TEST 5: DMA output checks
        $display("\n===== DMA CONFIGURATION TEST =====");

        if (source_addr == 32'h1000CC00 &&
            dest_addr == 32'h30000000 &&
            transfer_length == 32'h00000010 &&
            dma_start == 1'b1)
            $display("DMA CONFIGURATION PASS");
        else
            $fatal(1, "DMA CONFIGURATION FAIL");

        // TEST 6: Status register
        $display("\n===== STATUS REGISTER TEST =====");
        dma_busy  = 1'b1;
        dma_done  = 1'b0;
        dma_error = 1'b0;
        axi_read(32'h10, 32'h00000001);

        // TEST 7: Invalid addresses
        $display("\n===== INVALID ADDRESS TEST =====");
        invalid_write_test();
        invalid_read_test();

        // TEST 8: Backpressure
        $display("\n===== BACKPRESSURE TEST =====");
        write_backpressure_test();
        read_backpressure_test();

        // Final result
        $display("\n===== ALL TESTS PASSED =====");

        #20;
        $finish;
    end

endmodule

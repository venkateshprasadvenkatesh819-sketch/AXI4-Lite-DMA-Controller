
module axi_lite_regs (
    input  logic        ACLK,
    input  logic        ARESETN,

    // Write address channel
    input  logic [31:0] S_AXI_AWADDR,
    input  logic        S_AXI_AWVALID,
    output logic        S_AXI_AWREADY,

    // Write data channel
    input  logic [31:0] S_AXI_WDATA,
    input  logic [3:0]  S_AXI_WSTRB,
    input  logic        S_AXI_WVALID,
    output logic        S_AXI_WREADY,

    // Write response channel
    output logic [1:0]  S_AXI_BRESP,
    output logic        S_AXI_BVALID,
    input  logic        S_AXI_BREADY,

    // Read address channel
    input  logic [31:0] S_AXI_ARADDR,
    input  logic        S_AXI_ARVALID,
    output logic        S_AXI_ARREADY,

    // Read data channel
    output logic [31:0] S_AXI_RDATA,
    output logic [1:0]  S_AXI_RRESP,
    output logic        S_AXI_RVALID,
    input  logic        S_AXI_RREADY,

    // DMA configuration outputs
    output logic        dma_start,
    output logic [31:0] source_addr,
    output logic [31:0] dest_addr,
    output logic [31:0] transfer_length,

    // DMA status inputs
    input  logic        dma_busy,
    input  logic        dma_done,
    input  logic        dma_error,
    input  logic        irq_status
);

    logic [31:0] control_reg;
    logic [31:0] source_reg;
    logic [31:0] dest_reg;
    logic [31:0] length_reg;

    logic [31:0] write_addr_reg;
    logic        aw_captured;
    logic        w_captured;
    logic [31:0] write_data_reg;
    logic [3:0]  write_strb_reg;

    assign dma_start       = control_reg[0];
    assign source_addr     = source_reg;
    assign dest_addr       = dest_reg;
    assign transfer_length = length_reg;

    // AXI4-Lite response codes:
    // 00 = OKAY, 10 = SLVERR
    assign S_AXI_BRESP = 2'b00;
    assign S_AXI_RRESP = 2'b00;

    // Accept one address and one data item at a time.
    assign S_AXI_AWREADY = ARESETN && !aw_captured &&
                           !S_AXI_BVALID;
    assign S_AXI_WREADY  = ARESETN && !w_captured &&
                           !S_AXI_BVALID;

    // Read address channel
    assign S_AXI_ARREADY = ARESETN && !S_AXI_RVALID;

    // Register writes
    integer i;

    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            control_reg    <= 32'd0;
            source_reg     <= 32'd0;
            dest_reg       <= 32'd0;
            length_reg     <= 32'd0;

            write_addr_reg <= 32'd0;
            write_data_reg <= 32'd0;
            write_strb_reg <= 4'd0;

            aw_captured    <= 1'b0;
            w_captured     <= 1'b0;
            S_AXI_BVALID   <= 1'b0;
        end else begin

            if (S_AXI_BVALID && S_AXI_BREADY)
                S_AXI_BVALID <= 1'b0;

            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                write_addr_reg <= S_AXI_AWADDR;
                aw_captured    <= 1'b1;
            end

            if (S_AXI_WVALID && S_AXI_WREADY) begin
                write_data_reg <= S_AXI_WDATA;
                write_strb_reg <= S_AXI_WSTRB;
                w_captured     <= 1'b1;
            end

            // Process the write only after both channels arrive.
            if ((aw_captured ||
                 (S_AXI_AWVALID && S_AXI_AWREADY)) &&
                (w_captured ||
                 (S_AXI_WVALID && S_AXI_WREADY)) &&
                !S_AXI_BVALID) begin

                case (aw_captured ? write_addr_reg :
                                      S_AXI_AWADDR)

                    32'h00: begin
                        for (i = 0; i < 4; i = i + 1)
                            if (aw_captured ? write_strb_reg[i] :
                                              S_AXI_WSTRB[i])
                                control_reg[i*8 +: 8] <=
                                    (aw_captured ? write_data_reg :
                                                   S_AXI_WDATA)
                                    [i*8 +: 8];
                    end

                    32'h04: begin
                        for (i = 0; i < 4; i = i + 1)
                            if (aw_captured ? write_strb_reg[i] :
                                              S_AXI_WSTRB[i])
                                source_reg[i*8 +: 8] <=
                                    (aw_captured ? write_data_reg :
                                                   S_AXI_WDATA)
                                    [i*8 +: 8];
                    end

                    32'h08: begin
                        for (i = 0; i < 4; i = i + 1)
                            if (aw_captured ? write_strb_reg[i] :
                                              S_AXI_WSTRB[i])
                                dest_reg[i*8 +: 8] <=
                                    (aw_captured ? write_data_reg :
                                                   S_AXI_WDATA)
                                    [i*8 +: 8];
                    end

                    32'h0C: begin
                        for (i = 0; i < 4; i = i + 1)
                            if (aw_captured ? write_strb_reg[i] :
                                              S_AXI_WSTRB[i])
                                length_reg[i*8 +: 8] <=
                                    (aw_captured ? write_data_reg :
                                                   S_AXI_WDATA)
                                    [i*8 +: 8];
                    end

                    default: begin
                        // Unmapped addresses are ignored in this
                        // initial version.
                    end
                endcase

                aw_captured  <= 1'b0;
                w_captured   <= 1'b0;
                S_AXI_BVALID <= 1'b1;
            end
        end
    end

    // Register reads
    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_RDATA  <= 32'd0;
            S_AXI_RVALID <= 1'b0;
        end else begin
            if (S_AXI_RVALID && S_AXI_RREADY)
                S_AXI_RVALID <= 1'b0;

            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                case (S_AXI_ARADDR)
                    32'h00: S_AXI_RDATA <= control_reg;
                    32'h04: S_AXI_RDATA <= source_reg;
                    32'h08: S_AXI_RDATA <= dest_reg;
                    32'h0C: S_AXI_RDATA <= length_reg;
                    32'h10: S_AXI_RDATA <=
                        {29'd0, dma_error, dma_done, dma_busy};
                    32'h14: S_AXI_RDATA <= {31'd0, irq_status};
                    default: S_AXI_RDATA <= 32'd0;
                endcase
                S_AXI_RVALID <= 1'b1;
            end
        end
    end

endmodule

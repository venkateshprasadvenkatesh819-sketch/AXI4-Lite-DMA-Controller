module axi_lite_regs (
    input  logic        ACLK,
    input  logic        ARESETN,

    // AXI4-Lite write address
    input  logic [31:0] S_AXI_AWADDR, //These are the Write channels. 
    input  logic        S_AXI_AWVALID,//The S_ stands for Slave 
    output logic        S_AXI_AWREADY,//(your hardware is the slave to the CPU master).

    // AXI4-Lite write data
    input  logic [31:0] S_AXI_WDATA,
    input  logic [3:0]  S_AXI_WSTRB,
    input  logic        S_AXI_WVALID,
    output logic        S_AXI_WREADY,

    // AXI4-Lite write response
    output logic [1:0]  S_AXI_BRESP,
    output logic        S_AXI_BVALID,
    input  logic        S_AXI_BREADY,

    // AXI4-Lite read address
    input  logic [31:0] S_AXI_ARADDR,
    input  logic        S_AXI_ARVALID,
    output logic        S_AXI_ARREADY,

    // AXI4-Lite read data/response
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

    // Register addresses
    localparam [31:0] REG_CONTROL = 32'h00;
    localparam [31:0] REG_SOURCE  = 32'h04;
    localparam [31:0] REG_DEST    = 32'h08;
    localparam [31:0] REG_LENGTH  = 32'h0C;
    localparam [31:0] REG_STATUS  = 32'h10;
    localparam [31:0] REG_IRQ     = 32'h14;

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    // Configuration registers
    logic [31:0] control_reg;
    logic [31:0] source_reg;
    logic [31:0] dest_reg;
    logic [31:0] length_reg;

    // Saved write-channel information
    logic [31:0] saved_addr;
    logic [31:0] saved_data;
    logic [3:0]  saved_strb;

    logic addr_saved;
    logic data_saved;

    // Current transaction values
    logic [31:0] selected_addr;
    logic [31:0] selected_data;
    logic [3:0]  selected_strb;

    logic addr_handshake;
    logic data_handshake;
    logic write_ready_to_commit;

    // Expose configuration registers
    assign dma_start       = control_reg[0];
    assign source_addr     = source_reg;
    assign dest_addr       = dest_reg;
    assign transfer_length = length_reg;

    // Channel readiness
    assign S_AXI_AWREADY =
        ARESETN && !addr_saved && !S_AXI_BVALID;

    assign S_AXI_WREADY =
        ARESETN && !data_saved && !S_AXI_BVALID;

    assign S_AXI_ARREADY =
        ARESETN && !S_AXI_RVALID;

    // Handshakes occur when VALID and READY are both high.
    assign addr_handshake =
        S_AXI_AWVALID && S_AXI_AWREADY;

    assign data_handshake =
        S_AXI_WVALID && S_AXI_WREADY;

    // Choose previously saved values when available.
    assign selected_addr =
        addr_saved ? saved_addr : S_AXI_AWADDR;

    assign selected_data =
        data_saved ? saved_data : S_AXI_WDATA;

    assign selected_strb =
        data_saved ? saved_strb : S_AXI_WSTRB;

    assign write_ready_to_commit =
        (addr_saved || addr_handshake) &&
        (data_saved || data_handshake) &&
        !S_AXI_BVALID;

    // ------------------------------------------------
    // Write channel and configuration registers
    // ------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            control_reg <= 32'd0;
            source_reg  <= 32'd0;
            dest_reg    <= 32'd0;
            length_reg  <= 32'd0;

            saved_addr <= 32'd0;
            saved_data <= 32'd0;
            saved_strb <= 4'd0;

            addr_saved  <= 1'b0;
            data_saved  <= 1'b0;

            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= RESP_OKAY;
        end else begin

            // Release response after the master accepts it.
            if (S_AXI_BVALID && S_AXI_BREADY)
                S_AXI_BVALID <= 1'b0;

            // Address and data can arrive in different cycles.
            if (addr_handshake) begin
                saved_addr <= S_AXI_AWADDR;
                addr_saved <= 1'b1;
            end

            if (data_handshake) begin
                saved_data <= S_AXI_WDATA;
                saved_strb <= S_AXI_WSTRB;
                data_saved <= 1'b1;
            end

            // Execute only after both address and data arrive.
            if (write_ready_to_commit) begin
                case (selected_addr)

                    REG_CONTROL: begin
                        if (selected_strb[0]) control_reg[7:0]   <= selected_data[7:0];
                        if (selected_strb[1]) control_reg[15:8]  <= selected_data[15:8];
                        if (selected_strb[2]) control_reg[23:16] <= selected_data[23:16];
                        if (selected_strb[3]) control_reg[31:24] <= selected_data[31:24];
                        S_AXI_BRESP <= RESP_OKAY;
                    end

                    REG_SOURCE: begin
                        if (selected_strb[0]) source_reg[7:0]   <= selected_data[7:0];
                        if (selected_strb[1]) source_reg[15:8]  <= selected_data[15:8];
                        if (selected_strb[2]) source_reg[23:16] <= selected_data[23:16];
                        if (selected_strb[3]) source_reg[31:24] <= selected_data[31:24];
                        S_AXI_BRESP <= RESP_OKAY;
                    end

                    REG_DEST: begin
                        if (selected_strb[0]) dest_reg[7:0]   <= selected_data[7:0];
                        if (selected_strb[1]) dest_reg[15:8]  <= selected_data[15:8];
                        if (selected_strb[2]) dest_reg[23:16] <= selected_data[23:16];
                        if (selected_strb[3]) dest_reg[31:24] <= selected_data[31:24];
                        S_AXI_BRESP <= RESP_OKAY;
                    end

                    REG_LENGTH: begin
                        if (selected_strb[0]) length_reg[7:0]   <= selected_data[7:0];
                        if (selected_strb[1]) length_reg[15:8]  <= selected_data[15:8];
                        if (selected_strb[2]) length_reg[23:16] <= selected_data[23:16];
                        if (selected_strb[3]) length_reg[31:24] <= selected_data[31:24];
                        S_AXI_BRESP <= RESP_OKAY;
                    end

                    default: begin
                        S_AXI_BRESP <= RESP_SLVERR;
                    end

                endcase

                addr_saved   <= 1'b0;
                data_saved   <= 1'b0;
                S_AXI_BVALID <= 1'b1;
            end
        end
    end

    // ------------------------------------------------
    // Read channel
    // ------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_RDATA  <= 32'd0;
            S_AXI_RRESP  <= RESP_OKAY;
            S_AXI_RVALID <= 1'b0;
        end else begin

            // Release response after the master accepts it.
            if (S_AXI_RVALID && S_AXI_RREADY)
                S_AXI_RVALID <= 1'b0;

            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                case (S_AXI_ARADDR)

                    REG_CONTROL: begin
                        S_AXI_RDATA <= control_reg;
                        S_AXI_RRESP <= RESP_OKAY;
                    end

                    REG_SOURCE: begin
                        S_AXI_RDATA <= source_reg;
                        S_AXI_RRESP <= RESP_OKAY;
                    end

                    REG_DEST: begin
                        S_AXI_RDATA <= dest_reg;
                        S_AXI_RRESP <= RESP_OKAY;
                    end

                    REG_LENGTH: begin
                        S_AXI_RDATA <= length_reg;
                        S_AXI_RRESP <= RESP_OKAY;
                    end

                    REG_STATUS: begin
                        S_AXI_RDATA <= {
                            29'd0, dma_error, dma_done, dma_busy
                        };
                        S_AXI_RRESP <= RESP_OKAY;
                    end

                    REG_IRQ: begin
                        S_AXI_RDATA <= {31'd0, irq_status};
                        S_AXI_RRESP <= RESP_OKAY;
                    end

                    default: begin
                        S_AXI_RDATA <= 32'd0;
                        S_AXI_RRESP <= RESP_SLVERR;
                    end

                endcase

                S_AXI_RVALID <= 1'b1;
            end
        end
    end

endmodule
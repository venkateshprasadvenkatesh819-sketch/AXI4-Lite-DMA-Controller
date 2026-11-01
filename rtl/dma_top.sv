
`timescale 1ns/1ps

module dma_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter FIFO_DEPTH = 16
)(
    input logic ACLK,
    input logic ARESETN,

    // --------------------------------
    // AXI4-Lite WRITE ADDRESS
    // --------------------------------
    input  logic [31:0] S_AXI_AWADDR,
    input  logic        S_AXI_AWVALID,
    output logic        S_AXI_AWREADY,

    // --------------------------------
    // AXI4-Lite WRITE DATA
    // --------------------------------
    input  logic [31:0] S_AXI_WDATA,
    input  logic [3:0]  S_AXI_WSTRB,
    input  logic        S_AXI_WVALID,
    output logic        S_AXI_WREADY,

    // --------------------------------
    // AXI4-Lite WRITE RESPONSE
    // --------------------------------
    output logic [1:0] S_AXI_BRESP,
    output logic       S_AXI_BVALID,
    input  logic       S_AXI_BREADY,

    // --------------------------------
    // AXI4-Lite READ ADDRESS
    // --------------------------------
    input  logic [31:0] S_AXI_ARADDR,
    input  logic        S_AXI_ARVALID,
    output logic        S_AXI_ARREADY,

    // --------------------------------
    // AXI4-Lite READ DATA
    // --------------------------------
    output logic [31:0] S_AXI_RDATA,
    output logic [1:0]  S_AXI_RRESP,
    output logic        S_AXI_RVALID,
    input  logic        S_AXI_RREADY,

    // --------------------------------
    // SOURCE MEMORY READ INTERFACE
    // --------------------------------
    output logic                  mem_rd_en,
    output logic [ADDR_WIDTH-1:0] mem_rd_addr,
    input  logic                  mem_rd_valid,
    input  logic [DATA_WIDTH-1:0] mem_rd_data,

    // --------------------------------
    // DESTINATION MEMORY WRITE INTERFACE
    // --------------------------------
    output logic                  mem_wr_en,
    output logic [ADDR_WIDTH-1:0] mem_wr_addr,
    output logic [DATA_WIDTH-1:0] mem_wr_data,
    input  logic                  mem_wr_ready,

    // --------------------------------
    // STATUS
    // --------------------------------
    output logic dma_busy,
    output logic dma_done,
    output logic dma_error,
    output logic irq
);

    // --------------------------------
    // INTERNAL SIGNALS
    // --------------------------------

    logic dma_start_level;
    logic dma_start_d;
    logic dma_start_pulse;

    logic [31:0] source_addr;
    logic [31:0] dest_addr;
    logic [31:0] transfer_length;

    // --------------------------------
    // START PULSE GENERATION
    // --------------------------------

    always_ff @(posedge ACLK or negedge ARESETN) begin

        if (!ARESETN)
            dma_start_d <= 1'b0;

        else
            dma_start_d <= dma_start_level;

    end

    assign dma_start_pulse = dma_start_level && !dma_start_d;

    // --------------------------------
    // INTERRUPT GENERATION
    // --------------------------------

    assign irq = dma_done || dma_error;

    // --------------------------------
    // AXI4-LITE REGISTER INTERFACE
    // --------------------------------

    axi_lite_regs register_interface (

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

        .dma_start(dma_start_level),
        .source_addr(source_addr),
        .dest_addr(dest_addr),
        .transfer_length(transfer_length),

        .dma_busy(dma_busy),
        .dma_done(dma_done),
        .dma_error(dma_error),
        .irq_status(irq)

    );

    // --------------------------------
    // DMA ENGINE
    // --------------------------------

    dma_engine #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dma_controller (

        .clk(ACLK),
        .rst_n(ARESETN),

        .start(dma_start_pulse),

        .source_addr(source_addr),
        .dest_addr(dest_addr),
        .transfer_length(transfer_length),

        .busy(dma_busy),
        .done(dma_done),
        .error(dma_error),

        .mem_rd_en(mem_rd_en),
        .mem_rd_addr(mem_rd_addr),
        .mem_rd_valid(mem_rd_valid),
        .mem_rd_data(mem_rd_data),

        .mem_wr_en(mem_wr_en),
        .mem_wr_addr(mem_wr_addr),
        .mem_wr_data(mem_wr_data),
        .mem_wr_ready(mem_wr_ready)

    );

endmodule


`timescale 1ns/1ps

module dma_engine #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter FIFO_DEPTH = 16
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // DMA configuration
    input  logic                  start,
    input  logic [ADDR_WIDTH-1:0] source_addr,
    input  logic [ADDR_WIDTH-1:0] dest_addr,
    input  logic [31:0]           transfer_length,

    // DMA status
    output logic                  busy,
    output logic                  done,
    output logic                  error,

    // Memory read interface
    output logic                  mem_rd_en,
    output logic [ADDR_WIDTH-1:0] mem_rd_addr,
    input  logic                  mem_rd_valid,
    input  logic [DATA_WIDTH-1:0] mem_rd_data,

    // Memory write interface
    output logic                  mem_wr_en,
    output logic [ADDR_WIDTH-1:0] mem_wr_addr,
    output logic [DATA_WIDTH-1:0] mem_wr_data,
    input  logic                  mem_wr_ready
);

    // ------------------------------------------------
    // FSM STATES
    // ------------------------------------------------

    typedef enum logic [2:0] {
        IDLE,
        READ_REQ,
        READ_WAIT,
        FIFO_POP,
        WRITE_REQ,
        DONE_STATE,
        ERROR_STATE
    } state_t;

    state_t state;

    // ------------------------------------------------
    // INTERNAL REGISTERS
    // ------------------------------------------------

    logic [ADDR_WIDTH-1:0] current_source_addr;
    logic [ADDR_WIDTH-1:0] current_dest_addr;

    logic [31:0] total_words;
    logic [31:0] words_transferred;

    // ------------------------------------------------
    // FIFO SIGNALS
    // ------------------------------------------------

    logic fifo_wr_en;
    logic fifo_rd_en;

    logic [DATA_WIDTH-1:0] fifo_data_in;
    logic [DATA_WIDTH-1:0] fifo_data_out;

    logic fifo_full;
    logic fifo_empty;

    // ------------------------------------------------
    // FIFO INSTANTIATION
    // ------------------------------------------------

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) dma_fifo (
        .clk(clk),
        .rst_n(rst_n),

        .wr_en(fifo_wr_en),
        .data_in(fifo_data_in),

        .rd_en(fifo_rd_en),
        .data_out(fifo_data_out),

        .full(fifo_full),
        .empty(fifo_empty)
    );

    // ------------------------------------------------
    // COMBINATIONAL OUTPUT LOGIC
    // ------------------------------------------------

    always_comb begin

        busy = 1'b0;
        done = 1'b0;
        error = 1'b0;

        mem_rd_en = 1'b0;
        mem_rd_addr = current_source_addr;

        mem_wr_en = 1'b0;
        mem_wr_addr = current_dest_addr;
        mem_wr_data = fifo_data_out;

        fifo_wr_en = 1'b0;
        fifo_rd_en = 1'b0;

        fifo_data_in = mem_rd_data;

        case (state)

            IDLE: begin
                busy = 1'b0;
            end

            READ_REQ: begin
                busy = 1'b1;
                mem_rd_en = 1'b1;
            end

            READ_WAIT: begin
                busy = 1'b1;

                if (mem_rd_valid && !fifo_full)
                    fifo_wr_en = 1'b1;
            end

            FIFO_POP: begin
                busy = 1'b1;

                if (!fifo_empty)
                    fifo_rd_en = 1'b1;
            end

            WRITE_REQ: begin
                busy = 1'b1;
                mem_wr_en = 1'b1;
            end

            DONE_STATE: begin
                done = 1'b1;
            end

            ERROR_STATE: begin
                error = 1'b1;
            end

            default: begin
                error = 1'b1;
            end

        endcase

    end

    // ------------------------------------------------
    // SEQUENTIAL FSM
    // ------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state <= IDLE;

            current_source_addr <= '0;
            current_dest_addr <= '0;

            total_words <= '0;
            words_transferred <= '0;

        end

        else begin

            case (state)

                // ------------------------------------
                // IDLE
                // ------------------------------------

                IDLE: begin

                    words_transferred <= '0;

                    if (start) begin

                        if (transfer_length == 0) begin
                            state <= ERROR_STATE;
                        end

                        else begin

                            current_source_addr <= source_addr;
                            current_dest_addr <= dest_addr;

                            total_words <= transfer_length;

                            state <= READ_REQ;

                        end

                    end

                end

                // ------------------------------------
                // READ REQUEST
                // ------------------------------------

                READ_REQ: begin
                    state <= READ_WAIT;
                end

                // ------------------------------------
                // WAIT FOR MEMORY RESPONSE
                // ------------------------------------

                READ_WAIT: begin

                    if (mem_rd_valid) begin

                        if (fifo_full)
                            state <= ERROR_STATE;

                        else
                            state <= FIFO_POP;

                    end

                end

                // ------------------------------------
                // FIFO READ
                // ------------------------------------

                FIFO_POP: begin

                    if (fifo_empty)
                        state <= ERROR_STATE;

                    else
                        state <= WRITE_REQ;

                end

                // ------------------------------------
                // MEMORY WRITE
                // ------------------------------------

                WRITE_REQ: begin

                    if (mem_wr_ready) begin

                        words_transferred <= words_transferred + 1'b1;

                        current_source_addr <=
                            current_source_addr + 4;

                        current_dest_addr <=
                            current_dest_addr + 4;

                        if (words_transferred == total_words - 1)
                            state <= DONE_STATE;

                        else
                            state <= READ_REQ;

                    end

                end

                // ------------------------------------
                // COMPLETE
                // ------------------------------------

                DONE_STATE: begin
                    state <= IDLE;
                end

                // ------------------------------------
                // ERROR
                // ------------------------------------

                ERROR_STATE: begin
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase

        end

    end

endmodule

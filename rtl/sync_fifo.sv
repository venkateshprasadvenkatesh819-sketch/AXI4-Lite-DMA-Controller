
`timescale 1ns/1ps

module sync_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16
)(
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] data_in,

    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] data_out,

    output logic                  full,
    output logic                  empty
);

    // Handle DEPTH=1 safely
    localparam PTR_WIDTH   = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam COUNT_WIDTH = $clog2(DEPTH + 1);

    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wr_ptr;
    logic [PTR_WIDTH-1:0] rd_ptr;

    logic [COUNT_WIDTH-1:0] count;

    // Accepted operations
    logic do_read;
    logic do_write;

    // FIFO status
    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // A read is accepted only when data is available.
    assign do_read = rd_en && !empty;

    // A write is accepted when space exists,
    // or when a simultaneous accepted read frees a slot.
    assign do_write = wr_en && (!full || do_read);

    // Synchronous FIFO operation
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            wr_ptr   <= '0;
            rd_ptr   <= '0;
            count    <= '0;
            data_out <= '0;
        end

        else begin

            // WRITE
            if (do_write) begin

                memory[wr_ptr] <= data_in;

                if (wr_ptr == DEPTH-1)
                    wr_ptr <= '0;
                else
                    wr_ptr <= wr_ptr + 1'b1;

            end

            // READ
            if (do_read) begin

                data_out <= memory[rd_ptr];

                if (rd_ptr == DEPTH-1)
                    rd_ptr <= '0;
                else
                    rd_ptr <= rd_ptr + 1'b1;

            end

            // COUNT UPDATE
            case ({do_write, do_read})

                2'b10: count <= count + 1'b1;

                2'b01: count <= count - 1'b1;

                2'b11: count <= count;

                default: count <= count;

            endcase

        end

    end

    // Parameter validation
    initial begin
        if (DEPTH < 1)
            $fatal(1, "FIFO DEPTH must be at least 1");
    end

endmodule

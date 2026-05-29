`timescale 1ns / 1ps

/**
 * @file      P_MEMORY.v
 * @brief     Posterior (P) Memory for Layered LDPC Decoder.
 * @details   Implemented as a Banked Register File to allow parallel read/write
 * operations per column without BRAM bottleneck collisions.
 */
module P_MEMORY #(
    parameter DATA_WIDTH = 6,
    parameter M_SIZE     = 512,
    parameter NB_COLS    = 5
)(
    input  wire                                           i_clk,
    input  wire                                           i_rst_n,
    input  wire                                           i_load_en,
    input  wire [(NB_COLS * M_SIZE * DATA_WIDTH) - 1 : 0] i_llr_data,
    
    // i_write_en MUST be a vector to control each bank independently
    input  wire [NB_COLS - 1 : 0]                         i_write_en,
    input  wire [(NB_COLS * M_SIZE * DATA_WIDTH) - 1 : 0] i_p_new_data,
    
    // o_p_old_data is simply a wire continuously reading out the banks
    output wire [(NB_COLS * M_SIZE * DATA_WIDTH) - 1 : 0] o_p_old_data
);

    //========================================================================
    // INTERNAL MEMORY ARCHITECTURE (5 Independent Banks)
    //========================================================================
    localparam BANK_WIDTH = M_SIZE * DATA_WIDTH;
    
    // 2D Array: 5 elements, each represents a column of size (512 * 6 bits)
    reg [BANK_WIDTH - 1 : 0] r_bank [0 : NB_COLS - 1];

    integer i;

    //========================================================================
    // SEQUENTIAL LOGIC: WRITE & LOAD OPERATIONS
    //========================================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            // Reset all banks
            for (i = 0; i < NB_COLS; i = i + 1) begin
                r_bank[i] <= {BANK_WIDTH{1'b0}};
            end
        end else if (i_load_en) begin
            // Load intrinsic channel LLR to all banks initially
            for (i = 0; i < NB_COLS; i = i + 1) begin
                r_bank[i] <= i_llr_data[(i * BANK_WIDTH) +: BANK_WIDTH];
            end
        end else begin
            // Layered Update: Only write to banks whose write_en bit is high
            for (i = 0; i < NB_COLS; i = i + 1) begin
                if (i_write_en[i]) begin
                    r_bank[i] <= i_p_new_data[(i * BANK_WIDTH) +: BANK_WIDTH];
                end
            end
        end
    end

    //========================================================================
    // COMBINATIONAL LOGIC: CONTINUOUS READ OUT (Flattening 2D to 1D)
    //========================================================================
    genvar j;
    generate
        for (j = 0; j < NB_COLS; j = j + 1) begin : gen_read_out
            assign o_p_old_data[(j * BANK_WIDTH) +: BANK_WIDTH] = r_bank[j];
        end
    endgenerate

endmodule
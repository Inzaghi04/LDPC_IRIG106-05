`timescale 1ns / 1ps

/**
 * @file      SUB_BARREL_SHIFTER.v
 * @brief     Combinational Barrel Shifter for sub-blocks.
 * @details   Performs cyclic shift on a sub-matrix array (M_SIZE = 128).
 * Synthesizes into a log2(M_SIZE) stage cascaded multiplexer network.
 */
module SUB_BARREL_SHIFTER #(
    parameter DATA_WIDTH  = 6,
    parameter M_SIZE      = 128,
    parameter SHIFT_WIDTH = 7
) (
    input  wire [(M_SIZE * DATA_WIDTH) - 1 : 0] i_data,
    input  wire [SHIFT_WIDTH - 1 : 0]           i_shift_val,
    output wire [(M_SIZE * DATA_WIDTH) - 1 : 0] o_data
);

    // 3D wire array for inter-stage routing
    wire [DATA_WIDTH - 1 : 0] w_stage [0 : SHIFT_WIDTH][0 : M_SIZE - 1];
    
    genvar i, k;

    //========================================================================
    // 1. UNPACK 1D TO 2D (Stage 0)
    //========================================================================
    generate
        for (i = 0; i < M_SIZE; i = i + 1) begin : gen_unpack
            assign w_stage[0][i] = i_data[i * DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    //========================================================================
    // 2. BARREL SHIFTER CASCADED MUX STAGES
    //========================================================================
    generate
        for (k = 0; k < SHIFT_WIDTH; k = k + 1) begin : gen_shift_stages
            for (i = 0; i < M_SIZE; i = i + 1) begin : gen_shift_elements
                // Static source index calculation
                localparam integer SRC_IDX = (i + M_SIZE - (1 << k)) % M_SIZE;
                
                assign w_stage[k + 1][i] = i_shift_val[k] ? w_stage[k][SRC_IDX] : w_stage[k][i];
            end
        end
    endgenerate

    //========================================================================
    // 3. PACK 2D TO 1D (Final Output)
    //========================================================================
    generate
        for (i = 0; i < M_SIZE; i = i + 1) begin : gen_pack
            assign o_data[i * DATA_WIDTH +: DATA_WIDTH] = w_stage[SHIFT_WIDTH][i];
        end
    endgenerate

endmodule
`timescale 1ns / 1ps

/**
 * @file      AR4JA_SHIFTER.v
 * @brief     Hybrid Routing Network for AR4JA LDPC Standard (IRIG-106).
 * @details   Implements a 2-stage shifting network:
 * - Stage 1: Four independent 128-element barrel shifters.
 * - Stage 2: 4x4 block permutation network (Macro Shift).
 */
module AR4JA_SHIFTER #(
    parameter DATA_WIDTH    = 6,
    parameter M_SIZE        = 512,
    parameter SUB_SIZE      = 128,          // M_SIZE / 4
    parameter MICRO_SHIFT_W = 7             // log2(SUB_SIZE)
) (
    input  wire [(M_SIZE * DATA_WIDTH) - 1 : 0]    i_data,
    input  wire [1 : 0]                            i_macro_shift,  // theta_k
    input  wire [(4 * MICRO_SHIFT_W) - 1 : 0]      i_micro_shifts, // phi_k(0) to phi_k(3)
    output wire [(M_SIZE * DATA_WIDTH) - 1 : 0]    o_data
);

    // Local constants for bus widths
    localparam SUB_BUS_W = SUB_SIZE * DATA_WIDTH;

    //========================================================================
    // STAGE 1: PARALLEL MICRO-SHIFTERS (phi_k)
    //========================================================================
    wire [SUB_BUS_W - 1 : 0] w_sub_in  [0 : 3];
    wire [SUB_BUS_W - 1 : 0] w_sub_out [0 : 3];

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_micro_shifters
            // Slice the flattened input bus into 4 independent sub-buses
            assign w_sub_in[i] = i_data[(i * SUB_BUS_W) +: SUB_BUS_W];
            
            // Extract the corresponding 7-bit shift value for each sub-block
            wire [MICRO_SHIFT_W - 1 : 0] w_shift_val = i_micro_shifts[(i * MICRO_SHIFT_W) +: MICRO_SHIFT_W];

            SUB_BARREL_SHIFTER #(
                .DATA_WIDTH(DATA_WIDTH),
                .M_SIZE(SUB_SIZE),
                .SHIFT_WIDTH(MICRO_SHIFT_W)
            ) u_micro_shifter (
                .i_data(w_sub_in[i]),
                .i_shift_val(w_shift_val),
                .o_data(w_sub_out[i])
            );
        end
    endgenerate

    //========================================================================
    // STAGE 2: MACRO BLOCK SWAPPER (theta_k)
    //========================================================================
    // Applies the block permutation: output_block(J) = input_block((J + 4 - theta_k) % 4)
    
    wire [SUB_BUS_W - 1 : 0] w_macro_out [0 : 3];

    // Combinational 4x4 multiplexer matrix
    assign w_macro_out[0] = (i_macro_shift == 2'd0) ? w_sub_out[0] :
                            (i_macro_shift == 2'd1) ? w_sub_out[3] :
                            (i_macro_shift == 2'd2) ? w_sub_out[2] : w_sub_out[1];

    assign w_macro_out[1] = (i_macro_shift == 2'd0) ? w_sub_out[1] :
                            (i_macro_shift == 2'd1) ? w_sub_out[0] :
                            (i_macro_shift == 2'd2) ? w_sub_out[3] : w_sub_out[2];

    assign w_macro_out[2] = (i_macro_shift == 2'd0) ? w_sub_out[2] :
                            (i_macro_shift == 2'd1) ? w_sub_out[1] :
                            (i_macro_shift == 2'd2) ? w_sub_out[0] : w_sub_out[3];

    assign w_macro_out[3] = (i_macro_shift == 2'd0) ? w_sub_out[3] :
                            (i_macro_shift == 2'd1) ? w_sub_out[2] :
                            (i_macro_shift == 2'd2) ? w_sub_out[1] : w_sub_out[0];

    //========================================================================
    // FINAL PACKING: 2D TO 1D
    //========================================================================
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_macro_pack
            assign o_data[(i * SUB_BUS_W) +: SUB_BUS_W] = w_macro_out[i];
        end
    endgenerate

endmodule
`timescale 1ns / 1ps

/**
 * @file      AR4JA_INV_SHIFTER.v
 * @brief     Inverse Hybrid Routing Network for AR4JA LDPC.
 * @details   Executes Inverse Macro Swap first, then Inverse Micro Shifts.
 */
module AR4JA_INV_SHIFTER #(
    parameter DATA_WIDTH    = 6,
    parameter M_SIZE        = 512,
    parameter SUB_SIZE      = 128,
    parameter MICRO_SHIFT_W = 7
) (
    input  wire [(M_SIZE * DATA_WIDTH) - 1 : 0]    i_data,
    input  wire [1 : 0]                            i_macro_shift, 
    input  wire [(4 * MICRO_SHIFT_W) - 1 : 0]      i_micro_shifts,
    output wire [(M_SIZE * DATA_WIDTH) - 1 : 0]    o_data
);
    localparam SUB_BUS_W = SUB_SIZE * DATA_WIDTH;
    wire [SUB_BUS_W - 1 : 0] w_sub_in [0 : 3];

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_unpack
            assign w_sub_in[i] = i_data[(i * SUB_BUS_W) +: SUB_BUS_W];
        end
    endgenerate

    // 1. INVERSE MACRO SWAP (Shift Left instead of Right)
    wire [SUB_BUS_W - 1 : 0] w_macro_out [0 : 3];
    assign w_macro_out[0] = (i_macro_shift == 2'd0) ? w_sub_in[0] : (i_macro_shift == 2'd1) ? w_sub_in[1] : (i_macro_shift == 2'd2) ? w_sub_in[2] : w_sub_in[3];
    assign w_macro_out[1] = (i_macro_shift == 2'd0) ? w_sub_in[1] : (i_macro_shift == 2'd1) ? w_sub_in[2] : (i_macro_shift == 2'd2) ? w_sub_in[3] : w_sub_in[0];
    assign w_macro_out[2] = (i_macro_shift == 2'd0) ? w_sub_in[2] : (i_macro_shift == 2'd1) ? w_sub_in[3] : (i_macro_shift == 2'd2) ? w_sub_in[0] : w_sub_in[1];
    assign w_macro_out[3] = (i_macro_shift == 2'd0) ? w_sub_in[3] : (i_macro_shift == 2'd1) ? w_sub_in[0] : (i_macro_shift == 2'd2) ? w_sub_in[1] : w_sub_in[2];

    // 2. INVERSE MICRO SHIFTS (128 - phi)
    wire [SUB_BUS_W - 1 : 0] w_micro_out [0 : 3];
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_inv_micro
            wire [MICRO_SHIFT_W - 1 : 0] w_phi = i_micro_shifts[(i * MICRO_SHIFT_W) +: MICRO_SHIFT_W];
            wire [MICRO_SHIFT_W - 1 : 0] w_inv_phi = (SUB_SIZE - w_phi) % SUB_SIZE;

            SUB_BARREL_SHIFTER #(.DATA_WIDTH(DATA_WIDTH), .M_SIZE(SUB_SIZE), .SHIFT_WIDTH(MICRO_SHIFT_W)) 
            u_micro_shifter (
                .i_data(w_macro_out[i]),
                .i_shift_val(w_inv_phi),
                .o_data(w_micro_out[i])
            );
            assign o_data[(i * SUB_BUS_W) +: SUB_BUS_W] = w_micro_out[i];
        end
    endgenerate
endmodule
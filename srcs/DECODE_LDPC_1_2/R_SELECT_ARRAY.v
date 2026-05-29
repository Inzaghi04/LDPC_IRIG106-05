`timescale 1ns / 1ps
module R_SELECT_ARRAY #(
    parameter DATA_WIDTH    = 5,
    parameter INDEX_WIDTH   = 3,
    parameter DEGREE        = 6
) (
    input wire [DATA_WIDTH - 1 : 0] i_min1,
    input wire [DATA_WIDTH - 1 : 0] i_min2,
    input wire [INDEX_WIDTH - 1 : 0] i_min1_idx,
    input wire i_total_sign,
    input wire [DEGREE - 1 : 0] i_q_signs,
    output wire [DEGREE * (DATA_WIDTH + 1) - 1 : 0] o_r_messages
);
    genvar i;
    generate
        for (i = 0; i < DEGREE; i = i + 1) begin : gen_r_construct
            wire w_is_min1;
            wire [DATA_WIDTH - 1 : 0] w_r_mag;
            wire w_r_sign;
            assign w_is_min1 = (i[INDEX_WIDTH-1:0] == i_min1_idx);
            assign w_r_mag = w_is_min1 ? i_min2 : i_min1;
            assign w_r_sign = i_total_sign ^ i_q_signs[i];
            assign o_r_messages[(i * (DATA_WIDTH + 1)) +: (DATA_WIDTH + 1)] = {w_r_sign, w_r_mag};
        end
    endgenerate
endmodule
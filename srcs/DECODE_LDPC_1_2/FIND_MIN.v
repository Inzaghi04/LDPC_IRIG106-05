`timescale 1ns / 1ps
module FIND_MIN # (
    parameter DATA_WIDTH = 5,
    parameter INDEX_WIDTH = 4
) (
    input wire [DATA_WIDTH-1:0] i_a_min1,
    input wire [DATA_WIDTH-1:0] i_a_min2,
    input wire [INDEX_WIDTH-1:0] i_a_idx,

    input wire [DATA_WIDTH-1:0] i_b_min1,
    input wire [DATA_WIDTH-1:0] i_b_min2,
    input wire [INDEX_WIDTH-1:0] i_b_idx,

    output reg [DATA_WIDTH-1:0] o_min1,
    output reg [DATA_WIDTH-1:0] o_min2,
    output reg [INDEX_WIDTH-1:0] o_idx
);
    always @(*) begin
        if (i_a_min1 < i_b_min1) begin
            o_min1 = i_a_min1;
            o_idx = i_a_idx;
            o_min2 = (i_a_min2 < i_b_min1) ? i_a_min2 : i_b_min1;
        end else begin
            o_min1 = i_b_min1;
            o_idx = i_b_idx;
            o_min2 = (i_b_min2 < i_a_min1) ? i_b_min2 : i_a_min1;
        end
    end
 
endmodule
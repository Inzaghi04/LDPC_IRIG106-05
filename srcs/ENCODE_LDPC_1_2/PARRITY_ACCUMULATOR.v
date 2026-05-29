`timescale 1ns / 1ps
module PARITY_ACCUMULATOR (
    input wire i_clk,
    input wire i_rst_n,
    input wire i_clr, // [ADDED] Clear signal for new frames
    input wire i_en,
    input wire [1023:0] i_w_row,
    input wire i_data,
    output reg [1023:0] o_parity
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_parity <= 1024'b0;
        end else if (i_clr) begin
            // [FIXED] Clear accumulator on new frame start
            o_parity <= 1024'b0; 
        end else if (i_en) begin
            if (i_data) o_parity <= o_parity ^ i_w_row;
        end
    end
endmodule
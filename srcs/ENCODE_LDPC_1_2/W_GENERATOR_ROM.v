`timescale 1ns / 1ps
module W_GENERATOR_ROM (
    input wire i_clk,
    input wire i_rst_n,
    input wire i_en_load,
    input wire [2:0] i_index,
    input wire [127:0] i_seed,
    input wire i_en_shift,
    output reg [1023:0] o_w_row
);
    reg [127:0] r_circular_shift_block [0:7];
    assign o_w_row = {
        r_circular_shift_block[7],
        r_circular_shift_block[6],
        r_circular_shift_block[5],
        r_circular_shift_block[4],
        r_circular_shift_block[3],
        r_circular_shift_block[2],
        r_circular_shift_block[1],
        r_circular_shift_block[0]
    };
                    
    integer i;
    always@(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                r_circular_shift_block[i] <= 128'b0; 
            end
        end else begin
            if (i_en_load) begin
                r_circular_shift_block[i_index] <= i_seed;
            end else if (i_en_shift) begin
                for  (i = 0; i < 8; i = i + 1) begin
                    r_circular_shift_block[i] <= {r_circular_shift_block[i][0], r_circular_shift_block[i][127:1]};
                end
            end
        end
    end
endmodule
`timescale 1ns / 1ps
module MESSAGE_BUFFER (
    input wire i_clk,
    input wire i_rst_n,
    input wire i_en_load,
    input wire i_en_shift,
    input wire [1023:0] i_data,
    output wire o_data,
    output wire [1023:0] o_msg
);
    reg [1023:0] r_buffer;
    assign o_data = r_buffer[0]; 
    assign o_msg = r_buffer;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_buffer <= 1024'b0;
        end else if (i_en_load) begin         
            r_buffer <= i_data;
        end else if (i_en_shift) begin
            r_buffer <= {r_buffer[0], r_buffer[1023:1]};
        end
    end
endmodule
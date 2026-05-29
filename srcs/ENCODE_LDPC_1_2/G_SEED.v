`timescale 1ns / 1ps
module G_SEED (
    input wire         i_clk,
    input wire         i_enable,
    input wire [5:0]   i_addr, // 6-bit address input
    output reg [127:0] o_data
);
    (*rom_style = "block"*)
    reg [127:0] memory_array [0:63];
    initial begin
        $readmemh("C:/Verilog/LDPC_IRIG106/LDPC_1_2/srcs/ENCODE_LDPC_1_2/g_seed.mem", memory_array);
    end
    always @(posedge i_clk) begin
        if (i_enable) begin
            o_data <= memory_array[i_addr];
        end
    end
endmodule
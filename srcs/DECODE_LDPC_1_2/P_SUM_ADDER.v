`timescale 1ns / 1ps
module P_SUM_ADDER #(
    parameter DATA_WIDTH = 6,
    localparam signed [DATA_WIDTH:0] MAX_VALUE = (1 << (DATA_WIDTH - 1)) - 1,
    localparam signed [DATA_WIDTH:0] MIN_VALUE = -(1 << (DATA_WIDTH - 1))
)
(
    input wire [DATA_WIDTH - 1 : 0] i_Q,
    input wire [DATA_WIDTH - 2 : 0] i_R_mag,
    input wire i_R_sign,
    output wire [DATA_WIDTH - 1 : 0] o_P,
    output wire o_hd_bit
);
    wire signed [DATA_WIDTH - 1 : 0] w_R_tc;    
    assign w_R_tc = i_R_sign ? -{1'b0, i_R_mag} : {1'b0, i_R_mag};

    wire signed [DATA_WIDTH : 0] w_Q_ext;
    wire signed [DATA_WIDTH : 0] w_R_ext;

    assign w_Q_ext = {i_Q[DATA_WIDTH-1], i_Q};
    assign w_R_ext = {w_R_tc[DATA_WIDTH-1], w_R_tc};

    wire signed [DATA_WIDTH : 0] w_P_ext;
    assign w_P_ext = w_Q_ext + w_R_ext;
    
    reg [DATA_WIDTH - 1 : 0] r_P_sat;
    
    always @(*) begin
        if (w_P_ext > MAX_VALUE) begin
            r_P_sat = MAX_VALUE[DATA_WIDTH-1:0];
        end else if (w_P_ext < MIN_VALUE) begin
            r_P_sat = MIN_VALUE[DATA_WIDTH-1:0];
        end else begin
            r_P_sat = w_P_ext[DATA_WIDTH-1:0];
        end
    end
    assign o_P = r_P_sat;
    assign o_hd_bit = r_P_sat[DATA_WIDTH - 1];
endmodule
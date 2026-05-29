`timescale 1ns / 1ps
module Q_SUBTRACTOR #(
    parameter DATA_WIDTH = 6, // 1 sign bit + 5 magnitude bits
    // Use localparam for internal constants to prevent external override
    parameter signed [DATA_WIDTH:0] MAX_VALUE = (1 << (DATA_WIDTH - 1)) - 1,
    parameter signed [DATA_WIDTH:0] MIN_VALUE = -(1 << (DATA_WIDTH - 1))
)(
    input  wire [DATA_WIDTH - 1 : 0] i_P,
    input  wire [DATA_WIDTH - 1 : 0] i_R,
    
    output reg  [DATA_WIDTH - 1 : 0] o_Q,         // Saturated Two's Complement Q
    output wire                      o_sign,      // Extracted Sign bit
    output wire [DATA_WIDTH - 2 : 0] o_magnitude  // Extracted Magnitude
);
    wire signed [DATA_WIDTH : 0] w_P_ext;
    wire signed [DATA_WIDTH : 0] w_R_ext;
    wire signed [DATA_WIDTH : 0] w_Q_ext;
    //========================================================================
    // 1. SIGN EXTENSION & TWO'S COMPLEMENT SUBTRACTION
    //========================================================================
    assign w_P_ext = {i_P[DATA_WIDTH-1], i_P};
    assign w_R_ext = {i_R[DATA_WIDTH-1], i_R};
    
    // Subtraction uses signed arithmetic for accurate hardware generation
    assign w_Q_ext = w_P_ext - w_R_ext;
    //========================================================================
    // 2. SATURATION CLAMPING LOGIC
    //========================================================================
    always @(*) begin
        if (w_Q_ext > MAX_VALUE) begin
            o_Q = MAX_VALUE[DATA_WIDTH-1:0];
        end else if (w_Q_ext < MIN_VALUE) begin
            o_Q = MIN_VALUE[DATA_WIDTH-1:0];
        end else begin
            o_Q = w_Q_ext[DATA_WIDTH-1:0];
        end
    end
    //========================================================================
    // 3. SIGN-MAGNITUDE CONVERSION
    //========================================================================
    assign o_sign      = o_Q[DATA_WIDTH - 1];
    
    // If negative, invert and add 1 (Two's complement to Magnitude)
    assign o_magnitude = o_sign ? (~o_Q[DATA_WIDTH-2:0] + 1'b1) : o_Q[DATA_WIDTH-2:0];
endmodule
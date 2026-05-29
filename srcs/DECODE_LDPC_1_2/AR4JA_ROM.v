`timescale 1ns / 1ps

/**
 * @file      AR4JA_ROM.v
 * @brief     Combinational Look-Up Table for IRIG-106 AR4JA LDPC.
 * @details   Stores Theta (Macro Shift) and Phi (Micro Shifts) values for 
 * Code Rate 1/2, Info Block Size 1024, M = 512.
 * Reference: IRIG-106 Table R-2.
 */
module AR4JA_ROM #(
    parameter MICRO_SHIFT_W = 7 // log2(128)
)(
    input  wire [3:0]                             i_pi_id,        // Permutation Matrix ID (0 for Identity, 1-8 for Pi_k)
    output reg  [1:0]                             o_macro_shift,  // theta_k
    output reg  [(4 * MICRO_SHIFT_W) - 1 : 0]     o_micro_shifts  // {phi_k(3), phi_k(2), phi_k(1), phi_k(0)}
);

    always @(*) begin
        case (i_pi_id)
            //----------------------------------------------------------------
            // ID = 0: Identity Matrix (I_M) - No shift, no swap
            //----------------------------------------------------------------
            4'd0: begin
                o_macro_shift  = 2'd0;
                o_micro_shifts = {7'd0, 7'd0, 7'd0, 7'd0};
            end
            
            //----------------------------------------------------------------
            // ID = 1 to 8: Permutation Matrices (Pi_k) from Table R-2
            // Note: Concatenation order is {phi(3), phi(2), phi(1), phi(0)}
            //----------------------------------------------------------------
            4'd1: begin
                o_macro_shift  = 2'd3;
                o_micro_shifts = {7'd0, 7'd0, 7'd0, 7'd16};
            end
            
            4'd2: begin
                o_macro_shift  = 2'd0;
                o_micro_shifts = {7'd35, 7'd8, 7'd53, 7'd103};
            end
            
            4'd3: begin
                o_macro_shift  = 2'd1;
                o_micro_shifts = {7'd97, 7'd119, 7'd74, 7'd105};
            end
            
            4'd4: begin
                o_macro_shift  = 2'd2;
                o_micro_shifts = {7'd112, 7'd89, 7'd45, 7'd0};
            end
            
            4'd5: begin
                o_macro_shift  = 2'd2;
                o_micro_shifts = {7'd64, 7'd31, 7'd47, 7'd50};
            end
            
            4'd6: begin
                o_macro_shift  = 2'd3;
                o_micro_shifts = {7'd93, 7'd122, 7'd0, 7'd29};
            end
            
            4'd7: begin
                o_macro_shift  = 2'd0;
                o_micro_shifts = {7'd99, 7'd1, 7'd59, 7'd115};
            end
            
            4'd8: begin
                o_macro_shift  = 2'd1;
                o_micro_shifts = {7'd94, 7'd69, 7'd102, 7'd30};
            end
            
            //----------------------------------------------------------------
            // Default Case (Safety catch for synthesis)
            //----------------------------------------------------------------
            default: begin
                o_macro_shift  = 2'd0;
                o_micro_shifts = {7'd0, 7'd0, 7'd0, 7'd0};
            end
        endcase
    end

endmodule
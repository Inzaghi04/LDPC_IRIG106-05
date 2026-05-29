`timescale 1ns / 1ps

/**
 * @file      DECODER_FSM_CONTROLLER.v
 * @brief     Finite State Machine for AR4JA Layered LDPC Decoder.
 * @details   Fixed Infinite Loop Bug: Sequential logic now uses r_current_state.
 */
module DECODER_FSM_CONTROLLER #(
    parameter SHIFT_WIDTH   = 9,
    parameter MICRO_SHIFT_W = 7,
    parameter MAX_ITER      = 10,
    parameter NB_ROWS       = 3
)(
    input  wire                               i_clk,
    input  wire                               i_rst_n,
    
    input  wire                               i_start,
    output reg                                o_done,
    
    output reg                                o_load_llr,
    output reg                                o_init_fs,
    output reg  [1:0]                         o_layer_idx,
    output reg                                o_write_en,
    
    output wire [1:0]                         o_macro_shift,
    output wire [(4 * MICRO_SHIFT_W) - 1 : 0] o_micro_shifts
);

    localparam [2:0] 
        S_IDLE        = 3'd0,
        S_LOAD        = 3'd1,
        S_DECODE_FIRE = 3'd2, 
        S_WAIT_PIPE   = 3'd3, 
        S_DONE        = 3'd4;

    reg [2:0] r_current_state, r_next_state;
    reg [3:0] r_iter_cnt;       
    reg [1:0] r_layer_cnt;      
    reg [1:0] r_wait_cnt;       
    reg [3:0] r_pi_id;          

    AR4JA_ROM #(.MICRO_SHIFT_W(MICRO_SHIFT_W)) u_ar4ja_rom (
        .i_pi_id(r_pi_id),
        .o_macro_shift(o_macro_shift),
        .o_micro_shifts(o_micro_shifts)
    );

    //========================================================================
    // 1. STATE TRANSITION
    //========================================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) r_current_state <= S_IDLE;
        else          r_current_state <= r_next_state;
    end

    //========================================================================
    // 2. NEXT STATE LOGIC
    //========================================================================
    always @(*) begin
        r_next_state = r_current_state;
        case (r_current_state)
            S_IDLE:        if (i_start) r_next_state = S_LOAD;
            S_LOAD:        r_next_state = S_DECODE_FIRE;
            S_DECODE_FIRE: r_next_state = S_WAIT_PIPE;
            S_WAIT_PIPE: begin
                if (r_wait_cnt == 2'd2) begin 
                    if (r_layer_cnt == NB_ROWS - 1) begin
                        if (r_iter_cnt == MAX_ITER - 1) r_next_state = S_DONE;
                        else                            r_next_state = S_DECODE_FIRE;
                    end else begin
                        r_next_state = S_DECODE_FIRE;
                    end
                end
            end
            S_DONE:        r_next_state = S_IDLE;
        endcase
    end

    //========================================================================
    // 3. SEQUENTIAL OUTPUTS & COUNTERS (Dùng r_current_state)
    //========================================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_done      <= 1'b0; o_load_llr  <= 1'b0;
            o_init_fs   <= 1'b0; o_write_en  <= 1'b0;
            o_layer_idx <= 2'd0; r_iter_cnt  <= 4'd0;
            r_layer_cnt <= 2'd0; r_wait_cnt  <= 2'd0;
            r_pi_id     <= 4'd0;
        end else begin
            // Reset cờ xung (Pulse flags)
            o_done      <= 1'b0; o_load_llr  <= 1'b0;
            o_init_fs   <= 1'b0; o_write_en  <= 1'b0;

            case (r_current_state)
                S_IDLE: begin
                    r_iter_cnt  <= 4'd0; r_layer_cnt <= 2'd0; r_wait_cnt  <= 2'd0;
                end
                S_LOAD: begin
                    o_load_llr <= 1'b1; o_init_fs  <= 1'b1;
                end
                S_DECODE_FIRE: begin
                    o_write_en  <= 1'b1;
                    o_layer_idx <= r_layer_cnt;
                    r_wait_cnt  <= 2'd0; 
                    
                    if (r_layer_cnt == 0)      r_pi_id <= 4'd1;
                    else if (r_layer_cnt == 1) r_pi_id <= 4'd2;
                    else                       r_pi_id <= 4'd5;
                end
                S_WAIT_PIPE: begin
                    r_wait_cnt <= r_wait_cnt + 1'b1;
                    // Logic tăng đếm được bảo vệ tuyệt đối ở nhịp Clock cuối cùng
                    if (r_wait_cnt == 2'd2) begin
                        if (r_layer_cnt == NB_ROWS - 1) begin
                            r_layer_cnt <= 2'd0; 
                            if (r_iter_cnt != MAX_ITER - 1) r_iter_cnt <= r_iter_cnt + 1'b1; 
                        end else begin
                            r_layer_cnt <= r_layer_cnt + 1'b1;
                        end
                    end
                end
                S_DONE: o_done <= 1'b1;
            endcase
        end
    end
endmodule
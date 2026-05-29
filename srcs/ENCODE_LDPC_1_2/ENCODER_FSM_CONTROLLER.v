`timescale 1ns / 1ps

/**
 * @file      ENCODER_FSM_CONTROLLER.v
 * @brief     Finite State Machine for LDPC Encoder.
 * @details   Generates clear pulses for the parity accumulator upon new frame load.
 */
module ENCODER_FSM_CONTROLLER (
    input  wire          i_clk,
    input  wire          i_rst_n,
    input  wire          i_start,
    
    /* Control Outputs to MESSAGE_BUFFER */
    output reg           o_msg_en_load,
    output reg           o_msg_en_shift,
    
    /* Control Outputs to G_SEED ROM */
    output reg           o_seed_rom_en,
    output reg  [5:0]    o_seed_rom_addr,
    
    /* Control Outputs to W_GENERATOR_ROM */
    output reg           o_w_en_load,
    output reg  [2:0]    o_w_index,
    output reg           o_w_en_shift,
    
    /* Control Outputs to PARITY_ACCUMULATOR */
    output reg           o_parity_en,
    output reg           o_parity_clr,   // [FIXED] Clear pulse output
    
    /* Status Outputs to External System */
    output reg           o_valid
);

    localparam STATE_IDLE        = 0;
    localparam STATE_LOAD_DATA   = 1;
    localparam STATE_LOAD_SEED   = 2;
    localparam STATE_PROCESS     = 3;
    localparam STATE_CHECK_GROUP = 4;
    localparam STATE_DONE        = 5;

    reg [2:0] r_state;
    reg [2:0] r_group_cnt; // Tracks current circulant group (0 to 7)
    reg [7:0] r_step_cnt;  // Multi-purpose execution step counter

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state          <= STATE_IDLE;
            r_group_cnt      <= 3'b0;
            r_step_cnt       <= 8'b0;
            o_msg_en_load    <= 1'b0;
            o_msg_en_shift   <= 1'b0;
            o_seed_rom_en    <= 1'b0;
            o_seed_rom_addr  <= 6'b0;
            o_w_en_load      <= 1'b0;
            o_w_index        <= 3'b0;
            o_w_en_shift     <= 1'b0;
            o_parity_en      <= 1'b0;
            o_parity_clr     <= 1'b0; // [FIXED] Initialize clear signal
            o_valid          <= 1'b0;
        end else begin
            // Default pulse values
            o_msg_en_load    <= 1'b0;
            o_msg_en_shift   <= 1'b0;
            o_seed_rom_en    <= 1'b0;
            o_w_en_load      <= 1'b0;
            o_w_en_shift     <= 1'b0;
            o_parity_en      <= 1'b0;
            o_parity_clr     <= 1'b0; // [FIXED] Default low
            
            case (r_state)
                STATE_IDLE: begin
                    o_valid     <= 1'b0;
                    r_group_cnt <= 3'b0;
                    r_step_cnt  <= 8'b0;
                    if (i_start) begin
                        r_state <= STATE_LOAD_DATA;
                    end
                end
                
                STATE_LOAD_DATA: begin
                    o_msg_en_load <= 1'b1;
                    o_parity_clr  <= 1'b1; // [FIXED] Fire clear pulse for new frame
                    r_state       <= STATE_LOAD_SEED;
                    r_step_cnt    <= 8'd0;
                end
                
                STATE_LOAD_SEED: begin
                    if (r_step_cnt < 8) begin
                        o_seed_rom_en   <= 1'b1;
                        o_seed_rom_addr <= (r_group_cnt * 8) + r_step_cnt[2:0];
                    end
                    if (r_step_cnt > 0) begin
                        o_w_en_load     <= 1'b1;
                        o_w_index       <= r_step_cnt[2:0] - 3'd1;
                    end
                    
                    if (r_step_cnt < 8) begin
                        r_step_cnt <= r_step_cnt + 8'd1;
                    end else begin
                        r_step_cnt <= 8'd0;
                        r_state    <= STATE_PROCESS;
                    end
                end
                
                STATE_PROCESS: begin
                    o_msg_en_shift <= 1'b1;
                    o_w_en_shift   <= 1'b1;
                    o_parity_en    <= 1'b1;
                    
                    if (r_step_cnt < 127) begin
                        r_step_cnt <= r_step_cnt + 8'd1;
                    end else begin
                        r_step_cnt <= 8'd0;
                        r_state    <= STATE_CHECK_GROUP;
                    end
                end
                
                STATE_CHECK_GROUP: begin
                    if (r_group_cnt < 7) begin
                        r_group_cnt <= r_group_cnt + 3'd1;
                        r_state     <= STATE_LOAD_SEED;
                    end else begin
                        r_state <= STATE_DONE;
                    end
                end
                
                STATE_DONE: begin
                    o_valid <= 1'b1;
                    r_state <= STATE_IDLE;
                end
                
                default: r_state <= STATE_IDLE;
            endcase
        end
    end
endmodule
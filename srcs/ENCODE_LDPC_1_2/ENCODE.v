`timescale 1ns / 1ps

/**
 * @file      ENCODE.v
 * @brief     Top-level Encoder for LDPC System.
 */
module ENCODE (
    input  wire          i_clk,
    input  wire          i_rst_n,
    input  wire          i_start,
    input  wire [1023:0] i_data,
    output wire [2047:0] o_codeword,
    output wire          o_valid
);

    //========================================================================
    // INTERNAL WIRES (Interconnects)
    //========================================================================
    // FSM to Message Buffer
    wire w_msg_en_load;
    wire w_msg_en_shift;
    
    // FSM to G_SEED ROM
    wire w_seed_rom_en;
    wire [5:0] w_seed_rom_addr;
    
    // FSM to W_GENERATOR_ROM
    wire w_w_en_load;
    wire [2:0] w_w_index;
    wire w_w_en_shift;
    
    // FSM to Parity Accumulator
    wire w_parity_en;
    wire w_parity_clr; // [FIXED] Wire for clear signal
    
    // Data Path Interconnects
    wire [127:0]  w_seed_data;
    wire [1023:0] w_matrix_row;
    wire          w_msg_bit;
    wire [1023:0] w_sys_data;
    wire [1023:0] w_parity_data;

    //========================================================================
    // MODULE INSTANTIATIONS
    //========================================================================
    ENCODER_FSM_CONTROLLER u_fsm (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),
        .i_start         (i_start),
        
        .o_msg_en_load   (w_msg_en_load),
        .o_msg_en_shift  (w_msg_en_shift),
        
        .o_seed_rom_en   (w_seed_rom_en),
        .o_seed_rom_addr (w_seed_rom_addr),
        
        .o_w_en_load     (w_w_en_load),
        .o_w_index       (w_w_index),
        .o_w_en_shift    (w_w_en_shift),
        
        .o_parity_en     (w_parity_en),
        .o_parity_clr    (w_parity_clr), // [FIXED] Connect clear output
        .o_valid         (o_valid)
    );

    MESSAGE_BUFFER u_msg_buf (
        .i_clk       (i_clk),
        .i_rst_n     (i_rst_n),
        .i_en_load   (w_msg_en_load),
        .i_en_shift  (w_msg_en_shift),
        .i_data      (i_data),
        .o_data      (w_msg_bit),
        .o_msg       (w_sys_data)
    );

    G_SEED u_seed (
        .i_clk   (i_clk),
        .i_enable(w_seed_rom_en),
        .i_addr  (w_seed_rom_addr),
        .o_data  (w_seed_data)
    );

    W_GENERATOR_ROM u_w_gen (
        .i_clk      (i_clk),
        .i_rst_n    (i_rst_n),
        .i_en_load  (w_w_en_load),
        .i_index    (w_w_index),
        .i_en_shift (w_w_en_shift),
        .i_seed     (w_seed_data),
        .o_w_row    (w_matrix_row)
    );

    PARITY_ACCUMULATOR u_parity_acc (
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),
        .i_clr   (w_parity_clr), // [FIXED] Connect clear input
        .i_en    (w_parity_en),
        .i_w_row (w_matrix_row),
        .i_data  (w_msg_bit),
        .o_parity(w_parity_data)
    );

    //========================================================================
    // OUTPUT ASSIGNMENTS
    //========================================================================
    assign o_codeword = {w_parity_data, w_sys_data};

endmodule
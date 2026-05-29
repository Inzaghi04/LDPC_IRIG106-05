`timescale 1ns / 1ps

/**
 * @file      DECODE.v
 * @brief     Top-Level Module for IRIG-106 AR4JA Layered LDPC Decoder.
 * @details   Encapsulates the FSM Controller (Brain) and the Datapath (Muscle).
 * Configured for Code Rate 1/2, M = 512, Information Block Size = 1024.
 * @standard  IEEE 1364-2001
 */
module DECODE #(
    // Base Matrix & Architectural Parameters
    parameter DATA_WIDTH    = 6,
    parameter M_SIZE        = 512,
    parameter SUB_SIZE      = 128,   // M_SIZE / 4 for AR4JA
    parameter MICRO_SHIFT_W = 7,     // log2(SUB_SIZE)
    parameter DEGREE        = 6,     // Max Check Node Degree
    parameter MAX_ITER      = 10,    // Maximum number of decoding iterations
    parameter NB_ROWS       = 3,     // Number of rows in the Base Matrix
    parameter NB_COLS       = 5,     // Number of columns in the Base Matrix Rate 1/2
    parameter INFO_SIZE     = 1024,  // 2 * M_SIZE (Information bits)
    parameter TOTAL_V_NODES = 2560   // NB_COLS * M_SIZE (Total Variable Nodes)
)(
    // Clock and Reset
    input  wire                                 i_clk,
    input  wire                                 i_rst_n,
    
    // Control Interface (Host / MAC Layer)
    input  wire                                 i_start,      // Trigger new frame decoding
    output wire                                 o_done,       // High when decoding is finished
    
    // Data Interface (Channel / Demodulator)
    // Input must accommodate all 5 columns of the H matrix (Information + Parity)
    input  wire [(TOTAL_V_NODES * DATA_WIDTH) - 1 : 0] i_llr_data,   
    
    // Output extracts only the Information Block (first 2 columns)
    output wire [INFO_SIZE - 1 : 0]                    o_hd_bits     
);

    //========================================================================
    // INTERNAL ROUTING WIRES (The PCB Traces)
    //========================================================================
    // System Control Signals
    wire                                 w_load_llr;
    wire                                 w_init_fs;
    wire [1:0]                           w_layer_idx;
    wire                                 w_write_en;
    
    // AR4JA Routing Signals (From FSM ROM to Datapath Shifters)
    wire [1:0]                           w_macro_shift;
    wire [(4 * MICRO_SHIFT_W) - 1 : 0]   w_micro_shifts;
    
    // Full Hard-Decision bus from Datapath (includes parity bits)
    wire [TOTAL_V_NODES - 1 : 0]         w_all_hd_bits;

    //========================================================================
    // 1. HARD-DECISION EXTRACTION (Truncation)
    //========================================================================
    // Extract only the first 1024 bits (Column 0 and Column 1 of the Base Matrix)
    // which represent the original unencoded information block.
    assign o_hd_bits = w_all_hd_bits[M_SIZE + INFO_SIZE - 1 : M_SIZE];

    //========================================================================
    // 2. THE BRAIN: MAIN FSM CONTROLLER
    //========================================================================
    DECODER_FSM_CONTROLLER #(
        .SHIFT_WIDTH(9),
        .MICRO_SHIFT_W(MICRO_SHIFT_W),
        .MAX_ITER(MAX_ITER),
        .NB_ROWS(NB_ROWS)
    ) u_fsm_controller (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        
        .i_start(i_start),
        .o_done(o_done),
        
        .o_load_llr(w_load_llr),
        .o_init_fs(w_init_fs),
        .o_layer_idx(w_layer_idx),
        .o_write_en(w_write_en),
        
        .o_macro_shift(w_macro_shift),
        .o_micro_shifts(w_micro_shifts)
    );

    //========================================================================
    // 3. THE MUSCLE: PIPELINED DATAPATH
    //========================================================================
    DATAPATH_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .M_SIZE(M_SIZE),
        .SUB_SIZE(SUB_SIZE),
        .MICRO_SHIFT_W(MICRO_SHIFT_W),
        .DEGREE(DEGREE),
        .NB_COLS(NB_COLS),             // Truyền xuống
        .TOTAL_V_NODES(TOTAL_V_NODES)  // Truyền xuống
    ) u_datapath (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        
        // FSM Control Inputs
        .i_start_frame(w_init_fs), 
        .i_load_llr(w_load_llr),
        .i_layer_idx(w_layer_idx),
        .i_write_en(w_write_en),
        
        // AR4JA Routing Inputs
        .i_macro_shift(w_macro_shift),
        .i_micro_shifts(w_micro_shifts),
        
        // Data I/O
        .i_llr_data(i_llr_data),
        .o_hd_bits(w_all_hd_bits) // Connects the full 2560-bit bus
    );

endmodule
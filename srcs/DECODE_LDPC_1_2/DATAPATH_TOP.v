`timescale 1ns / 1ps

/**
 * @file      DATAPATH_TOP.v
 * @brief     Pipelined Top-level Datapath for AR4JA Layered LDPC Decoder.
 * @details   Integrates memory and math cores with 3-Stage Pipeline.
 * Check Node Unit (CNU) and R-messages are temporarily stubbed
 * to prevent X/Z state propagation until full routing is implemented.
 */
module DATAPATH_TOP #(
    parameter DATA_WIDTH    = 6,
    parameter M_SIZE        = 512,
    parameter SUB_SIZE      = 128,
    parameter MICRO_SHIFT_W = 7,
    parameter DEGREE        = 6,
    parameter NB_ROWS       = 3,     
    parameter NB_COLS       = 5, 
    parameter TOTAL_V_NODES = 2560 
)(
    input  wire                                           i_clk,
    input  wire                                           i_rst_n,
    
    /* Control Signals from Main FSM */
    input  wire                                           i_start_frame,
    input  wire                                           i_load_llr,
    input  wire [1:0]                                     i_layer_idx,
    input  wire                                           i_write_en,
    
    /* AR4JA Routing Signals (From FSM ROM) */
    input  wire [1:0]                                     i_macro_shift, 
    input  wire [(4 * MICRO_SHIFT_W) - 1 : 0]             i_micro_shifts,
    
    input  wire [(TOTAL_V_NODES * DATA_WIDTH) - 1 : 0]    i_llr_data,
    output wire [TOTAL_V_NODES - 1 : 0]                   o_hd_bits
);

    //========================================================================
    // LOCAL PARAMETERS 
    //========================================================================
    localparam M_BUS_W     = M_SIZE * DATA_WIDTH;
    localparam FULL_BUS_W  = TOTAL_V_NODES * DATA_WIDTH;
    localparam STATE_WIDTH = (DATA_WIDTH - 1) * 2 + 3 + DEGREE; // Min1 + Min2 + Idx + Signs
    localparam FS_BUS_W    = M_SIZE * STATE_WIDTH;

    //========================================================================
    // 0. MEMORY STAGES
    //========================================================================
    wire [FULL_BUS_W - 1 : 0] w_P_old;
    wire [FS_BUS_W - 1 : 0]   w_fs_old_state;
    
    wire [FULL_BUS_W - 1 : 0] w_stg3_P_new;
    wire [FS_BUS_W - 1 : 0]   w_stg2_fs_new_state;
    wire [1:0]                w_stg3_layer_idx;
    wire                      w_stg3_write_en;

    P_MEMORY #(.DATA_WIDTH(DATA_WIDTH), .M_SIZE(M_SIZE), .NB_COLS(NB_COLS)) 
    u_P_MEM (
        .i_clk(i_clk),             
        .i_rst_n(i_rst_n),
        .i_load_en(i_load_llr),    
        .i_llr_data(i_llr_data),
        .i_write_en({NB_COLS{w_stg3_write_en}}), 
        .i_p_new_data(w_stg3_P_new),
        .o_p_old_data(w_P_old)
    );

    // Stub for CNU output state until CNU_ARRAY is instantiated
    assign w_stg2_fs_new_state = {FS_BUS_W{1'b0}};

    FS_MEMORY #(
        .MAG_WIDTH(DATA_WIDTH - 1),
        .IDX_WIDTH(3),
        .DEGREE(DEGREE),
        .M_SIZE(M_SIZE),
        .NB_ROWS(NB_ROWS)
    ) u_FS_MEM (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start_frame),
        .i_write_en(w_stg3_write_en),
        .i_layer_idx(i_layer_idx),
        .i_new_state_data(w_stg2_fs_new_state),
        .o_state_data(w_fs_old_state)
    );

    //========================================================================
    // STAGE 1: Q-GEN -> AR4JA FORWARD SHIFT 
    //========================================================================
    wire [FULL_BUS_W - 1 : 0] w_stg1_Q_tc;
    wire [FULL_BUS_W - 1 : 0] w_stg1_Q_sm;
    wire [FULL_BUS_W - 1 : 0] w_stg1_Q_shifted;
    wire [FULL_BUS_W - 1 : 0] w_stg1_Q_tc_shifted; 
    
    genvar c, i;
    generate
        for (c = 0; c < NB_COLS; c = c + 1) begin : gen_cols
            
            // Generate Q_SUBTRACTOR array
            for (i = 0; i < M_SIZE; i = i + 1) begin : gen_q_sub
                wire [DATA_WIDTH - 1 : 0] w_P_in = w_P_old[(c * M_BUS_W) + (i * DATA_WIDTH) +: DATA_WIDTH];
                wire [DATA_WIDTH - 1 : 0] w_R_stub = {DATA_WIDTH{1'b0}}; // Stub to prevent Z state
                
                Q_SUBTRACTOR #(.DATA_WIDTH(DATA_WIDTH)) u_q_sub (
                    .i_P(w_P_in),
                    .i_R(w_R_stub),
                    .o_Q(w_stg1_Q_tc[(c * M_BUS_W) + (i * DATA_WIDTH) +: DATA_WIDTH]),
                    .o_sign(w_stg1_Q_sm[(c * M_BUS_W) + (i * DATA_WIDTH) + DATA_WIDTH - 1]),
                    .o_magnitude(w_stg1_Q_sm[(c * M_BUS_W) + (i * DATA_WIDTH) +: DATA_WIDTH - 1])
                );
            end

            // Sign-Magnitude Forward Shifter (To CNU)
            AR4JA_SHIFTER #(
                .DATA_WIDTH(DATA_WIDTH), .M_SIZE(M_SIZE), .SUB_SIZE(SUB_SIZE), .MICRO_SHIFT_W(MICRO_SHIFT_W)
            ) u_fwd_shifter (
                .i_data(w_stg1_Q_sm[c * M_BUS_W +: M_BUS_W]),
                .i_macro_shift(i_macro_shift),
                .i_micro_shifts(i_micro_shifts),
                .o_data(w_stg1_Q_shifted[c * M_BUS_W +: M_BUS_W])
            );

            // Two's Complement Forward Shifter (To Pipeline)
            AR4JA_SHIFTER #(
                .DATA_WIDTH(DATA_WIDTH), .M_SIZE(M_SIZE), .SUB_SIZE(SUB_SIZE), .MICRO_SHIFT_W(MICRO_SHIFT_W)
            ) u_fwd_tc_shifter (
                .i_data(w_stg1_Q_tc[c * M_BUS_W +: M_BUS_W]),
                .i_macro_shift(i_macro_shift),
                .i_micro_shifts(i_micro_shifts),
                .o_data(w_stg1_Q_tc_shifted[c * M_BUS_W +: M_BUS_W])
            );
        end
    endgenerate

    //========================================================================
    // PIPELINE REGISTER CUT 1 
    //========================================================================
    reg [FULL_BUS_W - 1 : 0]              r_stg1_Q_tc_delay;
    reg [1:0]                             r_stg1_layer_idx;
    reg                                   r_stg1_write_en;
    reg [1:0]                             r_stg1_macro_shift;
    reg [(4 * MICRO_SHIFT_W) - 1 : 0]     r_stg1_micro_shifts;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_stg1_Q_tc_delay    <= {FULL_BUS_W{1'b0}};
            r_stg1_layer_idx     <= 2'b00;
            r_stg1_write_en      <= 1'b0;
            r_stg1_macro_shift   <= 2'b00;
            r_stg1_micro_shifts  <= {(4 * MICRO_SHIFT_W){1'b0}};
        end else begin
            r_stg1_Q_tc_delay    <= w_stg1_Q_tc_shifted; 
            r_stg1_layer_idx     <= i_layer_idx;
            r_stg1_write_en      <= i_write_en;
            r_stg1_macro_shift   <= i_macro_shift;
            r_stg1_micro_shifts  <= i_micro_shifts;
        end
    end

    //========================================================================
    // PIPELINE REGISTER CUT 2 
    //========================================================================
    reg [FULL_BUS_W - 1 : 0]              r_stg2_Q_tc_delay;
    reg [1:0]                             r_stg2_layer_idx;
    reg                                   r_stg2_write_en;
    reg [1:0]                             r_stg2_macro_shift;
    reg [(4 * MICRO_SHIFT_W) - 1 : 0]     r_stg2_micro_shifts;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_stg2_Q_tc_delay   <= {FULL_BUS_W{1'b0}};
            r_stg2_layer_idx    <= 2'b00;
            r_stg2_write_en     <= 1'b0;
            r_stg2_macro_shift  <= 2'b00;
            r_stg2_micro_shifts <= {(4 * MICRO_SHIFT_W){1'b0}};
        end else begin
            r_stg2_Q_tc_delay   <= r_stg1_Q_tc_delay;
            r_stg2_layer_idx    <= r_stg1_layer_idx;
            r_stg2_write_en     <= r_stg1_write_en;
            r_stg2_macro_shift  <= r_stg1_macro_shift;
            r_stg2_micro_shifts <= r_stg1_micro_shifts;
        end
    end

    //========================================================================
    // STAGE 3: P-ADDER -> AR4JA INVERSE SHIFT 
    //========================================================================
    wire [FULL_BUS_W - 1 : 0] w_stg3_P_new_shifted;

    generate
        for (c = 0; c < NB_COLS; c = c + 1) begin : gen_stg3_cols
            
            for (i = 0; i < M_SIZE; i = i + 1) begin : gen_p_add
                wire [4:0] w_R_new_mag_stub  = 5'd0;
                wire       w_R_new_sign_stub = 1'b0;

                P_SUM_ADDER #(.DATA_WIDTH(DATA_WIDTH)) u_p_add (
                    .i_Q(r_stg2_Q_tc_delay[(c * M_BUS_W) + (i * DATA_WIDTH) +: DATA_WIDTH]),
                    .i_R_mag(w_R_new_mag_stub),  
                    .i_R_sign(w_R_new_sign_stub), 
                    .o_P(w_stg3_P_new_shifted[(c * M_BUS_W) + (i * DATA_WIDTH) +: DATA_WIDTH]),
                    .o_hd_bit() 
                );
            end

            AR4JA_INV_SHIFTER #(
                .DATA_WIDTH(DATA_WIDTH), .M_SIZE(M_SIZE), .SUB_SIZE(SUB_SIZE), .MICRO_SHIFT_W(MICRO_SHIFT_W)
            ) u_inv_shifter (
                .i_data(w_stg3_P_new_shifted[c * M_BUS_W +: M_BUS_W]),
                .i_macro_shift(r_stg2_macro_shift),   
                .i_micro_shifts(r_stg2_micro_shifts), 
                .o_data(w_stg3_P_new[c * M_BUS_W +: M_BUS_W])
            );
        end
    endgenerate

    //========================================================================
    // HARD DECISION EXTRACTION (Unshifted Domain)
    //========================================================================
    genvar v;
    generate
        for (v = 0; v < TOTAL_V_NODES; v = v + 1) begin : gen_hd_extract
            assign o_hd_bits[v] = w_P_old[(v * DATA_WIDTH) + (DATA_WIDTH - 1)];
        end
    endgenerate

    assign w_stg3_layer_idx = r_stg2_layer_idx;
    assign w_stg3_write_en  = r_stg2_write_en;

endmodule
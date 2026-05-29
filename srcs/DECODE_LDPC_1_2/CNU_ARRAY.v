`timescale 1ns / 1ps
module CNU_ARRAY #(
    parameter DATA_WIDTH  = 5,
    parameter INDEX_WIDTH = 3,  // 0 -> 5
    parameter DEGREE      = 6
)(
    input  wire [(DEGREE * DATA_WIDTH) - 1 : 0] i_magnitudes,
    input  wire [DEGREE - 1 : 0]                i_signs,
    
    output wire [DATA_WIDTH - 1 : 0]            o_min1,
    output wire [DATA_WIDTH - 1 : 0]            o_min2,
    output wire [INDEX_WIDTH - 1 : 0]           o_min1_idx,
    output wire                                 o_total_sign,
    output wire                                 o_parity_check
);

    wire [DATA_WIDTH-1:0] w_max_val = {DATA_WIDTH{1'b1}};

    //========================================================================
    // INTERNAL WIRES
    //========================================================================
    // STAGE 1 WIRES
    wire [DATA_WIDTH-1:0]  w_t1_min1 [0:2];
    wire [DATA_WIDTH-1:0]  w_t1_min2 [0:2];
    wire [INDEX_WIDTH-1:0] w_t1_idx  [0:2];

    // STAGE 2 WIRES
    wire [DATA_WIDTH-1:0]  w_t2_min1;
    wire [DATA_WIDTH-1:0]  w_t2_min2;
    wire [INDEX_WIDTH-1:0] w_t2_idx;

    //========================================================================
    // SIGN LOGIC
    //========================================================================
    assign o_total_sign   = ^i_signs;
    assign o_parity_check = o_total_sign;

    //========================================================================
    // TREE COMPARATOR STAGE 1: Lá (0&1), (2&3), (4&5)
    //========================================================================
    FIND_MIN u_find_min_0 (
        .i_a_min1 (i_magnitudes[DATA_WIDTH*1-1 : DATA_WIDTH*0]),
        .i_a_min2 (w_max_val), // Ép bằng Max
        .i_a_idx  (3'd0),
        
        .i_b_min1 (i_magnitudes[DATA_WIDTH*2-1 : DATA_WIDTH*1]),
        .i_b_min2 (w_max_val), // Ép bằng Max
        .i_b_idx  (3'd1),
        
        .o_min1   (w_t1_min1[0]),
        .o_min2   (w_t1_min2[0]),
        .o_idx    (w_t1_idx[0])
    );

    FIND_MIN u_find_min_1 (
        .i_a_min1 (i_magnitudes[DATA_WIDTH*3-1 : DATA_WIDTH*2]),
        .i_a_min2 (w_max_val),
        .i_a_idx  (3'd2),
        
        .i_b_min1 (i_magnitudes[DATA_WIDTH*4-1 : DATA_WIDTH*3]),
        .i_b_min2 (w_max_val),
        .i_b_idx  (3'd3),
        
        .o_min1   (w_t1_min1[1]),
        .o_min2   (w_t1_min2[1]),
        .o_idx    (w_t1_idx[1])
    );

    FIND_MIN u_find_min_2 (
        .i_a_min1 (i_magnitudes[DATA_WIDTH*5-1 : DATA_WIDTH*4]),
        .i_a_min2 (w_max_val),
        .i_a_idx  (3'd4),
        
        .i_b_min1 (i_magnitudes[DATA_WIDTH*6-1 : DATA_WIDTH*5]),
        .i_b_min2 (w_max_val),
        .i_b_idx  (3'd5),
        
        .o_min1   (w_t1_min1[2]),
        .o_min2   (w_t1_min2[2]),
        .o_idx    (w_t1_idx[2])
    );

    //========================================================================
    // TREE COMPARATOR STAGE 2: Nhánh (0&1) vs (2&3)
    //========================================================================
    FIND_MIN u_find_min_3 (
        .i_a_min1 (w_t1_min1[0]),
        .i_a_min2 (w_t1_min2[0]),
        .i_a_idx  (w_t1_idx[0]),
        
        .i_b_min1 (w_t1_min1[1]),
        .i_b_min2 (w_t1_min2[1]),
        .i_b_idx  (w_t1_idx[1]),
        
        .o_min1   (w_t2_min1),
        .o_min2   (w_t2_min2),
        .o_idx    (w_t2_idx)
    );

    //========================================================================
    // TREE COMPARATOR STAGE 3: Gốc (Kết quả Stage 2 vs Nhánh 4&5)
    //========================================================================
    FIND_MIN u_find_min_4 (
        .i_a_min1 (w_t2_min1),
        .i_a_min2 (w_t2_min2),
        .i_a_idx  (w_t2_idx),
        
        .i_b_min1 (w_t1_min1[2]),
        .i_b_min2 (w_t1_min2[2]),
        .i_b_idx  (w_t1_idx[2]),
        
        .o_min1   (o_min1),
        .o_min2   (o_min2),
        .o_idx    (o_min1_idx)
    );

endmodule
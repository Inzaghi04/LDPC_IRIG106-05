`timescale 1ns / 1ps

/**
 * @file      FS_MEMORY.v
 * @brief     Final State Memory for Check Nodes (Layered LDPC).
 * @details   Stores Min1, Min2, Index, and Signs for each row (layer) of the Base Matrix.
 * Includes asynchronous read and synchronous write capabilities.
 */
module FS_MEMORY #(
    parameter MAG_WIDTH = 5,
    parameter IDX_WIDTH = 3,
    parameter DEGREE    = 6,
    parameter M_SIZE    = 512,
    parameter NB_ROWS   = 3
) (
    input  wire                       i_clk,
    input  wire                       i_rst_n,
    input  wire                       i_start,
    input  wire                       i_write_en,
    input  wire [1:0]                 i_layer_idx,
    
    // Lưu ý: Khai báo kích thước I/O trực tiếp từ công thức để tránh dùng port tự định nghĩa
    input  wire [(M_SIZE * ((MAG_WIDTH * 2) + IDX_WIDTH + DEGREE)) - 1 : 0] i_new_state_data,
    output wire [(M_SIZE * ((MAG_WIDTH * 2) + IDX_WIDTH + DEGREE)) - 1 : 0] o_state_data
);

    //========================================================================
    // LOCAL PARAMETERS (Hằng số nội bộ bảo mật, không bị ghi đè)
    //========================================================================
    localparam STATE_WIDTH = (MAG_WIDTH * 2) + IDX_WIDTH + DEGREE;
    localparam ROW_WIDTH   = M_SIZE * STATE_WIDTH;

    //========================================================================
    // INTERNAL MEMORY CORE (Sổ ghi chép 3 trang)
    //========================================================================
    reg [ROW_WIDTH - 1 : 0] r_mem [0 : NB_ROWS - 1];

    //========================================================================
    // INITIALIZATION LOGIC (Nạp giá trị Max cho Min1, Min2)
    //========================================================================
    // Cú pháp chuẩn IEEE: Khởi tạo Sign=0, Idx=0, Min2=Max, Min1=Max
    localparam [STATE_WIDTH - 1 : 0] INIT_NODE_VAL = {
        {DEGREE{1'b0}}, 
        {IDX_WIDTH{1'b0}}, 
        {MAG_WIDTH{1'b1}}, 
        {MAG_WIDTH{1'b1}}
    };
    
    wire [ROW_WIDTH - 1 : 0] w_init_row_val;
    assign w_init_row_val = {M_SIZE{INIT_NODE_VAL}};

    //========================================================================
    // SEQUENTIAL LOGIC: WRITE & INIT
    //========================================================================
    integer i;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (i = 0; i < NB_ROWS; i = i + 1) begin
                r_mem[i] <= {ROW_WIDTH{1'b0}};
            end
        end else if (i_start) begin
            // Nạp băng đạn chứa giá trị MAX vào toàn bộ 3 hàng
            for (i = 0; i < NB_ROWS; i = i + 1) begin
                r_mem[i] <= w_init_row_val;
            end
        end else if (i_write_en) begin
            // Chỉ ghi đè hàng hiện tại do FSM yêu cầu
            r_mem[i_layer_idx] <= i_new_state_data;
        end
    end

    //========================================================================
    // COMBINATIONAL LOGIC: ASYNCHRONOUS READ
    //========================================================================
    assign o_state_data = r_mem[i_layer_idx];

endmodule
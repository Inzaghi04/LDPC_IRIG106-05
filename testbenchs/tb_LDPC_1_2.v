`timescale 1ns / 1ps

/**
 * @file      tb_LDPC_System.v
 * @brief     End-to-End Testbench for IRIG-106 AR4JA LDPC (Encode + Decode).
 * @details   Simulates BPSK modulation, Puncturing, and Light AWGN Channel.
 * Evaluates Bit Error Rate (BER) for Ideal and Noisy conditions.
 */
module tb_LDPC_System;

    //========================================================================
    // SYSTEM PARAMETERS
    //========================================================================
    localparam DATA_WIDTH    = 6;
    localparam M_SIZE        = 512;
    localparam INFO_SIZE     = 1024;
    localparam TOTAL_V_NODES = 2560; // 5 * 512
    localparam CODEWORD_SIZE = 2048; // INFO + PARITY

    //========================================================================
    // TESTBENCH SIGNALS
    //========================================================================
    reg  clk;
    reg  rst_n;

    // Encoder Signals
    reg  enc_start;
    reg  [INFO_SIZE - 1 : 0]     r_tx_info;
    wire [CODEWORD_SIZE - 1 : 0] w_tx_codeword;
    wire enc_valid;

    // Decoder Signals
    reg  dec_start;
    reg  [(TOTAL_V_NODES * DATA_WIDTH) - 1 : 0] r_rx_llr;
    wire [INFO_SIZE - 1 : 0]     w_rx_decoded_info;
    wire dec_done;

    //========================================================================
    // CLOCK GENERATION (100 MHz)
    //========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //========================================================================
    // MODULE INSTANTIATIONS
    //========================================================================
    // 1. Lõi Mã hóa (ENCODE)
    ENCODE u_encoder (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_start(enc_start),
        .i_data(r_tx_info),
        .o_codeword(w_tx_codeword),
        .o_valid(enc_valid)
    );

    // 2. Lõi Giải mã (DECODE)
    DECODE #(
        .DATA_WIDTH(DATA_WIDTH), 
        .M_SIZE(M_SIZE), 
        .INFO_SIZE(INFO_SIZE), 
        .TOTAL_V_NODES(TOTAL_V_NODES)
    ) u_decoder (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_start(dec_start),
        .o_done(dec_done),
        .i_llr_data(r_rx_llr),
        .o_hd_bits(w_rx_decoded_info)
    );

    //========================================================================
    // KÊNH TRUYỀN MÔ PHỎNG (BPSK + Puncturing + Noise)
    //========================================================================
    task apply_channel;
        input integer add_noise; // 0 = Ideal, 1 = Noisy
        integer j;
        reg signed [7:0] temp_llr; // Dùng 8-bit để tính toán tránh tràn
        begin
            // Bước 1: Đục lỗ (Puncturing) 512 bit đầu tiên của AR4JA
            // LLR = 0 có nghĩa là "Mù thông tin hoàn toàn"
            for (j = 0; j < 512; j = j + 1) begin
                r_rx_llr[j*DATA_WIDTH +: DATA_WIDTH] = 6'd0; 
            end
            
            // Bước 2: Điều chế BPSK & Chèn nhiễu cho 2048 bit phát đi
            for (j = 0; j < 2048; j = j + 1) begin
                // BPSK: Bit 0 -> LLR Dương (+15), Bit 1 -> LLR Âm (-15)
                temp_llr = (w_tx_codeword[j] == 1'b0) ? 8'sd15 : -8'sd15;
                
                // Bơm nhiễu nếu ở Case 2 (Nhiễu ngẫu nhiên từ -12 đến +12)
                if (add_noise) begin
                    temp_llr = temp_llr + ($random % 13); 
                end
                
                // Cắt bão hòa (Saturation) về hệ 6-bit có dấu (-32 đến +31)
                if (temp_llr > 31) temp_llr = 31;
                if (temp_llr < -32) temp_llr = -32;
                
                // Nhồi vào bó cáp đẩy xuống DECODE (Bắt đầu từ index 512)
                r_rx_llr[(j+512)*DATA_WIDTH +: DATA_WIDTH] = temp_llr[5:0];
            end
        end
    endtask

    //========================================================================
    // HÀM KIỂM TRA LỖI (BER CHECKER)
    //========================================================================
    task check_errors;
        input integer case_num;
        integer i, errors;
        real ber;
        begin
            errors = 0;
            for (i = 0; i < INFO_SIZE; i = i + 1) begin
                if (r_tx_info[i] !== w_rx_decoded_info[i]) begin
                    errors = errors + 1;
                end
            end
            
            ber = (errors * 1.0) / INFO_SIZE;
            
            $display("--------------------------------------------------");
            if (errors == 0) begin
                $display("CASE %0d RESULT : [SUCCESS] Perfect Decode!", case_num);
            end else begin
                $display("CASE %0d RESULT : [FAILED] Decoding has errors.", case_num);
            end
            $display("Total Bit Errors: %0d / %0d", errors, INFO_SIZE);
            $display("BER (Bit Error Rate): %f", ber);
            $display("--------------------------------------------------\n");
        end
    endtask

    //========================================================================
    // MAIN TEST SCENARIO
    //========================================================================
    initial begin
        // Khởi tạo trạng thái
        rst_n = 0;
        enc_start = 0;
        dec_start = 0;
        r_tx_info = {INFO_SIZE{1'b0}};
        r_rx_llr  = {(TOTAL_V_NODES * DATA_WIDTH){1'b0}};
        
        // Nhả Reset
        #100 rst_n = 1;
        #50;

        // Bơm gói tin ngẫu nhiên để test
        r_tx_info = {32{32'hDEAD_BEEF}}; // Gói tin test pattern

        //====================================================================
        // CASE 1: KÊNH TRUYỀN LÝ TƯỞNG (Không nhiễu)
        //====================================================================
        $display("\n>>> STARTING CASE 1: IDEAL CHANNEL <<<");
        
        // 1. Bắn cờ Encode
        @(posedge clk) enc_start = 1;
        @(posedge clk) enc_start = 0;
        
        // 2. Chờ Encode làm xong
        wait(enc_valid == 1'b1);
        $display("[Case 1] Encoding Finished. Sending through Ideal Channel...");
        
        // 3. Cho đi qua kênh truyền (add_noise = 0)
        apply_channel(0);
        
        // 4. Bắn cờ Decode
        @(posedge clk) dec_start = 1;
        @(posedge clk) dec_start = 0;
        
        // 5. Chờ Decode làm xong và check lỗi
        wait(dec_done == 1'b1);
        #10;
        check_errors(1);


        //====================================================================
        // CASE 2: KÊNH TRUYỀN CÓ NHIỄU (Light AWGN)
        //====================================================================
        $display(">>> STARTING CASE 2: NOISY CHANNEL <<<");
        
        // Đổi gói tin khác cho khách quan
        r_tx_info = {32{32'h1234_5678}};
        
        @(posedge clk) enc_start = 1;
        @(posedge clk) enc_start = 0;
        
        wait(enc_valid == 1'b1);
        $display("[Case 2] Encoding Finished. Sending through Noisy Channel...");
        
        // Cho đi qua kênh truyền (add_noise = 1)
        apply_channel(1);
        
        @(posedge clk) dec_start = 1;
        @(posedge clk) dec_start = 0;
        
        wait(dec_done == 1'b1);
        #10;
        check_errors(2);

        // Kết thúc mô phỏng
        $display(">>> SIMULATION COMPLETED <<<");
        $finish;
    end

endmodule
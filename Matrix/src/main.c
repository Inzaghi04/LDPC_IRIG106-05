#include "MATRIX_H.h"
#include "MATRIX_G.h"
#include <time.h>     // time()
#include "encode.h"
#include "decode.h"
int main ()
{
    LDPC_init_H_matrix();
    // LDPC_export_H_matrix_to_csv("data/H_matrix.csv");
    // LDPC_extract_Q();
    // //export_Q_to_csv("data/H_matrix_Q.csv");
    // LDPC_extract_P();
    // //export_P_to_csv("data/H_matrix_P.csv");
    // if (LDPC_inverse_P() == 1)
    // {
    //     LDPC_compute_W();
    //     //LDPC_extract_G_seeds("data/G_matrix_seeds.csv");
    //     LDPC_verify_G_HT();
    // } else {
    //     printf("[ERROR] Matrix P is not invertible. Cannot compute G matrix.\n");
    // }
    //==================ENCODER TEST===========================//
    srand(time(NULL));
    uint8_t message[1024];
    uint8_t codeword[2048];
    printf("[INFO] Message:\n");
    for (int i = 0; i < 1024; i++)
    {
        message[i] = rand() % 2;
        printf("%d", message[i]);
    }
    encode(message, codeword);
    printf("\n[RESULT] Codeword:\n");
    for (int i = 0; i < 2048; i++) {
        printf("%d", codeword[i]);
    }
    printf("\n[INFO] Encode Successful!\n");
    /* ======================================================== */
    /* AWGN CHANNEL SIMULATION (NOISE TEST)                     */
    /* ======================================================== */
    float ebno_db = 2.5f; /* Test with Eb/N0 = 2.5 dB */
    float code_rate = 0.5f;
    
    /* Calculate noise variance based on Eb/N0 */
    float ebno_linear = powf(10.0f, ebno_db / 10.0f);
    float sigma = sqrtf(1.0f / (2.0f * code_rate * ebno_linear));
    float variance = sigma * sigma;

    printf("[INFO] Simulating AWGN Channel at Eb/N0 = %.2f dB\n", ebno_db);
    printf("       Noise Sigma = %f, Variance = %f\n", sigma, variance);

    float rx_llrs[2048];
    int raw_channel_errors = 0;

    for(int i = 0; i < 2048; i++) 
    {
        /* 1. BPSK Modulation: bit 0 -> +1.0, bit 1 -> -1.0 */
        float tx_symbol = (codeword[i] == 0) ? 1.0f : -1.0f;
        
        /* 2. Add Gaussian Noise */
        float noise = generate_gaussian_noise(sigma);
        float rx_symbol = tx_symbol + noise;
        
        /* Count raw bit errors BEFORE decoding (Hard decision on rx_symbol) */
        uint8_t hard_decision = (rx_symbol < 0.0f) ? 1 : 0;
        if (hard_decision != codeword[i]) {
            raw_channel_errors++;
        }

        /* 3. Compute True LLR for the Min-Sum decoder */
        rx_llrs[i] = (2.0f * rx_symbol) / variance;
    }

    printf("[INFO] Raw channel bit errors BEFORE decoding: %d (BER: %.4f)\n", 
            raw_channel_errors, (float)raw_channel_errors / 2048.0f);

    /* ======================================================== */
    /* RUN DECODER                                              */
    /* ======================================================== */
    uint8_t decoded_bits[2560];
    int success = ldpc_decode(rx_llrs, decoded_bits, 20);

    /* Verify Results against original payload */
    int error_count = 0;
    for(int i = 0; i < 1024; i++) {
        if(decoded_bits[i] != message[i]) {
            error_count++;
        }
    }

    if (success && error_count == 0) {
        printf("[SUCCESS] Noise Test Passed! Decoder recovered all %d bits perfectly.\n", K_BITS);
    } else {
        printf("[FAILED] Noise Test Failed. Decoder left %d bit errors.\n", error_count);
    }
    return 0;
}
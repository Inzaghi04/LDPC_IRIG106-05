#include "decode.h"
float M_c2v[H_ROWS][MAX_ROW_WEIGHT];
float M_v2c[H_COLS][MAX_COL_WEIGHT];

void init_llr(const float *rx, float *llr) {
    /* 1. Map transmitted message & parity bits to the first 2048 nodes */
    for (int i = 0; i < 2048; i++) {
        llr[i] = rx[i]; 
    }
    
    /* 2. Map the punctured state nodes to the LAST 512 nodes */
    for (int i = 2048; i < 2560; i++) {
        llr[i] = 0.0f;  /* Punctured bits (no information) */
    }
}
void check_node_update(float *L_vc, float *L_cv, int deg) 
{
    float min1 = 1e9;
    float min2 = 1e9;
    int min1_idx = -1;
    int sign_total = 1;
    
    /* First Pass: Find min1, min2 and calculate total sign product */
    for (int i = 0; i < deg; i++) 
    {
        float val = L_vc[i];
        if (val < 0) sign_total *= -1;
        
        float abs_val = fabsf(val);
        if (abs_val < min1) 
        {
            min2 = min1;
            min1 = abs_val;
            min1_idx = i;
        } 
        else if (abs_val < min2) 
        {
            min2 = abs_val;
        }
    }
    
    /* Normalized Min-Sum Scaling Factor */
    const float ALPHA = 0.75f;
    
    /* Second Pass: Generate output messages */
    for (int i = 0; i < deg; i++) 
    {
        float val = L_vc[i];
        int sign = (val < 0) ? -1 : 1;
        int out_sign = sign_total * sign;
        
        float min_val = (i == min1_idx) ? min2 : min1;
        
        /* Apply attenuation to prevent LLR explosion */
        L_cv[i] = out_sign * min_val * ALPHA; 
    }
}
void variable_node_update(float L_ch, float *L_cv, float *L_vc, int deg) {
    float unclamped_sum = L_ch;
    for (int i = 0; i < deg; i++) {
        unclamped_sum += L_cv[i];
    }
    
    /* Hardware perspective: LLR Saturation / Clipping */
    const float MAX_LLR = 15.0f;

    for (int i = 0; i < deg; i++) {
        /* Calculate extrinsic message first */
        float msg = unclamped_sum - L_cv[i];
        
        /* Clip outgoing messages to prevent precision overflow */
        if (msg > MAX_LLR) msg = MAX_LLR;
        else if (msg < -MAX_LLR) msg = -MAX_LLR;
        
        L_vc[i] = msg;
    }
}

void decision(float L_ch, float *L_cv, int deg, uint8_t *bit) {
    float L_total = L_ch;
    for (int i = 0; i < deg; i++) {
        L_total += L_cv[i];
    }
    *bit = (L_total < 0.0f) ? 1 : 0;
}
int ldpc_decode(float *rx_llrs, uint8_t *decoded_bits, int max_iter) {
    float L_ch[H_COLS];
    init_llr(rx_llrs, L_ch);

    /* Initialize Check-to-Variable and Variable-to-Check messages */
    memset(M_c2v, 0, sizeof(M_c2v));
    for (int v = 0; v < H_COLS; v++) {
        for (int i = 0; i < LDPC_H_var_nodes[v].degree; i++) {
            M_v2c[v][i] = L_ch[v];
        }
    }

    for (int iter = 0; iter < max_iter; iter++) {
        /* 1. Check Node Update (CNU) */
        for (int c = 0; c < H_ROWS; c++) {
            int deg = LDPC_H_check_nodes[c].degree;
            float L_vc_in[MAX_ROW_WEIGHT];
            float L_cv_out[MAX_ROW_WEIGHT];

            /* Route messages from V2C memory into local buffer */
            for (int i = 0; i < deg; i++) {
                int v = LDPC_H_check_nodes[c].connected_vars[i];
                int edge_idx = 0;
                for (int j = 0; j < LDPC_H_var_nodes[v].degree; j++) {
                    if (LDPC_H_var_nodes[v].connected_checks[j] == c) {
                        edge_idx = j;
                        break;
                    }
                }
                L_vc_in[i] = M_v2c[v][edge_idx];
            }

            check_node_update(L_vc_in, L_cv_out, deg);

            /* Route messages from local buffer back to C2V memory */
            for (int i = 0; i < deg; i++) {
                M_c2v[c][i] = L_cv_out[i];
            }
        }

        /* 2. Variable Node Update (VNU) & Decision */
        int syndrome_ok = 1;
        for (int v = 0; v < H_COLS; v++) {
            int deg = LDPC_H_var_nodes[v].degree;
            float L_cv_in[MAX_COL_WEIGHT];
            float L_vc_out[MAX_COL_WEIGHT];

            /* Route messages from C2V memory into local buffer */
            for (int i = 0; i < deg; i++) {
                int c =  LDPC_H_var_nodes[v].connected_checks[i];
                int edge_idx = 0;
                for (int j = 0; j < LDPC_H_check_nodes[c].degree; j++) {
                    if (LDPC_H_check_nodes[c].connected_vars[j] == v) {
                        edge_idx = j;
                        break;
                    }
                }
                L_cv_in[i] = M_c2v[c][edge_idx];
            }

            variable_node_update(L_ch[v], L_cv_in, L_vc_out, deg);

            /* Route messages from local buffer back to V2C memory */
            for (int i = 0; i < deg; i++) {
                M_v2c[v][i] = L_vc_out[i];
            }

            decision(L_ch[v], L_cv_in, deg, &decoded_bits[v]);
        }

        /* 3. Syndrome Check (Early Termination) */
        for (int c = 0; c < H_ROWS; c++) {
            uint8_t parity = 0;
            for (int i = 0; i < LDPC_H_check_nodes[c].degree; i++) {
                int v = LDPC_H_check_nodes[c].connected_vars[i];
                parity ^= decoded_bits[v];
            }
            if (parity != 0) {
                syndrome_ok = 0;
                break;
            }
        }

        if (syndrome_ok) {
            printf("[INFO] Decoder converged at Iteration %d\n", iter + 1);
            return 1;
        }
    }
    
    printf("[WARN] Decoder failed to converge after %d iterations\n", max_iter);
    return 0;
}
double generate_gaussian_noise(double sigma)
{
    double u1 = (double)rand() / RAND_MAX;
    double u2 = (double)rand() / RAND_MAX;
    if (u1 <= 0.0) u1 = 1e-9;
    double z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2);
    return z0 * sigma;
}
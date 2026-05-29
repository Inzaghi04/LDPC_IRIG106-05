
#include "MATRIX_G.h"
int LDPC_matrix_Q[H_ROWS][K_BITS];
int LDPC_matrix_P[P_SIZE][P_SIZE];

int LDPC_inv_P[P_SIZE][P_SIZE];
int LDPC_matrix_W_T[P_SIZE][K_BITS];
int LDPC_matrix_W[K_BITS][P_SIZE];
int FULL_G[K_BITS][H_COLS];       
int FULL_H_T[H_COLS][H_ROWS];     
int RESULT_G_HT[K_BITS][H_ROWS];  
void LDPC_extract_Q(void)
{
    memset(LDPC_matrix_Q, 0, sizeof(LDPC_matrix_Q));
    for (int r = 0; r < H_ROWS; r++)
    {
        for (int i = 0; i < LDPC_H_check_nodes[r].degree; i++)
        {
            int c = LDPC_H_check_nodes[r].connected_vars[i];
            if (c < K_BITS)
            {
                /* SỬ DỤNG XOR ĐỂ CỘNG MODULO-2 */
                LDPC_matrix_Q[r][c] ^= 1; 
            }
        }
    }
}
void export_Q_to_csv(const char* filename) {
    FILE *file = fopen(filename, "w");
    if (file == NULL) {
        printf("[ERROR] Cannot open file %s for writing.\n", filename);
        return;
    }
    fprintf(file, "Row,Col\n");
    for (int r = 0; r < H_ROWS; r++)
    {
        for (int c = 0; c < K_BITS; c++)
        {
            if (LDPC_matrix_Q[r][c] == 1)
            {
                fprintf(file, "%d,%d\n", r, c);
            }
        }
    }
    fclose(file);
    printf("[INFO] Matrix Q successfully exported to %s\n", filename);
}
void LDPC_extract_P(void)
{
    memset(LDPC_matrix_P, 0, sizeof(LDPC_matrix_P));
    for (int r = 0; r < H_ROWS; r++)
    {
        for (int i = 0; i < LDPC_H_check_nodes[r].degree; i++)
        {
            int c = LDPC_H_check_nodes[r].connected_vars[i];
            if (c >= K_BITS)
            {
                int p_col = c - K_BITS;
                if (p_col < P_SIZE && r < P_SIZE)
                {
                    /* SỬ DỤNG XOR ĐỂ CỘNG MODULO-2 */
                    LDPC_matrix_P[r][p_col] ^= 1;
                }
            }
        }
    }
}
void export_P_to_csv(const char* filename)
{
    FILE *file = fopen(filename, "w");
    if (file == NULL)
    {
        printf("[ERROR] Cannot open file %s for writing.\n", filename);
        return;
    }
    fprintf(file, "Row,Col\n");
    for (int r = 0; r < P_SIZE; r++)
    {
        for (int c = 0; c < P_SIZE; c++)
        {
            if (LDPC_matrix_P[r][c] == 1)
            {
                fprintf(file, "%d,%d\n", r, c);
            }
        }
    }
    fclose(file);
    printf("[INFO] Matrix P successfully exported to %s\n", filename);
}

int LDPC_inverse_P(void)
{
    static int work_P[P_SIZE][P_SIZE];
    
    /* BƯỚC 1: Sửa lỗi khởi tạo */
    for (int r = 0; r < P_SIZE; r++)
    {
        for (int c = 0; c < P_SIZE; c++)
        {
            work_P[r][c] = LDPC_matrix_P[r][c];
            LDPC_inv_P[r][c] = (r == c) ? 1 : 0; /* ĐÃ ĐỔI THÀNH LDPC_inv_P */
        }
    }

    for (int i = 0; i < P_SIZE; i++)
    {
        /* BƯỚC 2: Sửa lỗi logic Gauss-Jordan (Đưa lệnh if quay trở lại) */
        if (work_P[i][i] == 0) 
        {
            int swap_row = -1;
            for (int j = i + 1; j < P_SIZE; j++)
            {
                if (work_P[j][i] == 1)
                {
                    swap_row = j;
                    break;
                }
            }
            
            if (swap_row == -1) 
            {
                printf("[ERROR] Ma trận suy biến tại cột %d\n", i);
                return 0;
            }

            for (int k = 0; k < P_SIZE; k++) 
            {
                int temp = work_P[i][k];
                work_P[i][k] = work_P[swap_row][k];
                work_P[swap_row][k] = temp;

                temp = LDPC_inv_P[i][k];
                LDPC_inv_P[i][k] = LDPC_inv_P[swap_row][k];
                LDPC_inv_P[swap_row][k] = temp;
            }
        }

        /* Khử các hàng khác */
        for (int j = 0; j < P_SIZE; j++)
        {
            if (j != i && work_P[j][i] == 1)
            {
                for (int k = 0; k < P_SIZE; k++)
                {
                    work_P[j][k] ^= work_P[i][k];
                    LDPC_inv_P[j][k] ^= LDPC_inv_P[i][k];
                }
            }
        }
    }
    return 1;
}

void LDPC_compute_W(void)
{
    memset(LDPC_matrix_W_T, 0, sizeof(LDPC_matrix_W_T));
    for (int r = 0; r < P_SIZE; r++)
    {
        for (int c = 0; c < K_BITS; c++)
        {
            int sum = 0;
            for (int k = 0; k < P_SIZE; k++)
            {
                sum ^= (LDPC_inv_P[r][k] & LDPC_matrix_Q[k][c]);
            }
            LDPC_matrix_W_T[r][c] = sum;
        }
    }
    for (int r = 0; r < P_SIZE; r++)
    {
        for (int c = 0; c < K_BITS; c++)
        {
            LDPC_matrix_W[c][r] = LDPC_matrix_W_T[r][c];
        }
    }
}
void LDPC_extract_G_seeds(const char* filename) 
{
    FILE *file = fopen(filename, "w");
    if (file == NULL)
    {
        printf("[ERROR] Cannot open file %s for writing.\n", filename);
        return;
    }
    /* Duyệt qua 8 khối tuần hoàn (M/4 = 128) */
    for (int group = 0; group < 8; group++) 
    {
        /* Lấy hàng đầu tiên của mỗi khối để làm Seed */
        int row = group * 128; 
        
        /* 1024 bit của mỗi khối sẽ được chia thành 8 dòng.
         * Mỗi dòng in ra 128 bit (tương đương 32 ký tự Hex). */
        for (int line = 0; line < 8; line++) 
        {
            /* Giới hạn của C là 64-bit, nên ta chia 128 bit thành 2 nửa (chunks) */
            for (int chunk = 0; chunk < 2; chunk++) 
            {
                uint64_t hex_word = 0;
                
                /* Ghép 64 bit đơn lẻ thành một số nguyên 64-bit */
                for (int bit = 0; bit < 64; bit++) 
                {
                    /* Công thức tính chỉ số cột tuyệt đối */
                    int col = line * 128 + chunk * 64 + bit;
                    
                    if (LDPC_matrix_W[row][col] == 1) 
                    {
                        hex_word |= (1ULL << (63 - bit));
                    }
                }
                
                /* In ra 16 ký tự Hex in hoa (%016X), dính liền nhau */
                fprintf(file, "%016llX", (unsigned long long)hex_word);
            }
            
            /* Xuống dòng khi đã in đủ 32 ký tự Hex (2 chunks) */
            fprintf(file, "\n");
        }
    }
    fclose(file);
    printf("[INFO] G matrix seeds successfully extracted to %s\n", filename);
}

void LDPC_verify_G_HT(void)
{
    int total_errors = 0;
    memset(FULL_G, 0, sizeof(FULL_G));
    for (int i = 0; i < K_BITS; i++)
    {
        for (int j = 0; j < H_COLS; j++)
        {
            if (j < K_BITS) {
                FULL_G[i][j] = (i == j) ? 1 : 0;
            } else {
                FULL_G[i][j] = LDPC_matrix_W[i][j - K_BITS];
            }
        }
    }
    memset(FULL_H_T, 0, sizeof(FULL_H_T));
    for (int r = 0; r < H_ROWS; r++)
    {
        for (int k = 0; k < LDPC_H_check_nodes[r].degree; k++)
        {
            int c = LDPC_H_check_nodes[r].connected_vars[k];
            /* Chuyển vị: Hàng 'r' của H trở thành Cột 'r' của H^T */
            FULL_H_T[c][r] = 1; 
        }
    }
    memset(RESULT_G_HT, 0, sizeof(RESULT_G_HT));

    for (int i = 0; i < K_BITS; i++)
    {
        for (int j = 0; j < H_ROWS; j++)
        {
            int dot_product = 0;
            
            /* Nhân vô hướng Hàng i của G với Cột j của H^T */
            for (int k = 0; k < H_COLS; k++)
            {
                dot_product ^= (FULL_G[i][k] & FULL_H_T[k][j]);
            }
            
            /* Lưu thẳng vào ma trận kết quả */
            RESULT_G_HT[i][j] = dot_product;

            /* Nếu phần tử kết quả bị khác 0, ghi nhận lỗi ngay lập tức */
            if (dot_product != 0)
            {
                total_errors++;
            }
        }
    }
    if (total_errors == 0)
    {
        printf("[SUCCESS] G * H^T = 0. Verification passed!\n");
    }
    else
    {
        printf("[FAILURE] G * H^T has %d non-zero entries. Verification failed.\n", total_errors);
    }
}
/**
 * @file      matrix_h.c
 * @brief     Implementation file for Tanner Graph construction.
 */

#include "MATRIX_H.h"
#include <stdio.h>
#include <string.h>

/* Actual memory allocation */
CheckNode    LDPC_H_check_nodes[H_ROWS];
VariableNode LDPC_H_var_nodes[H_COLS];

/* Public Tables */
const uint8_t LDPC_THETA_TABLE[8] = {3, 0, 1, 2, 2, 3, 0, 1};
const uint8_t LDPC_PHI_TABLE[8][4] = {
    {16, 0, 0, 0}, {103, 53, 8, 35}, {105, 74, 119, 97}, {0, 45, 89, 112}, 
    {50, 47, 31, 64}, {29, 0, 122, 93}, {115, 59, 1, 99}, {30, 102, 69, 94}
};

uint16_t LDPC_compute_pi_k(uint16_t i, uint8_t theta, const uint8_t *phi) {
    uint16_t group = i >> 7; 
    uint16_t term1 = M_OVER_4 * ((theta + group) & 3);
    uint16_t term2 = (phi[group] + i) & 127;
    return term1 + term2;
}

void LDPC_add_connection(uint16_t row, uint16_t col) {
    if (LDPC_H_check_nodes[row].degree < MAX_ROW_WEIGHT) {
        LDPC_H_check_nodes[row].connected_vars[LDPC_H_check_nodes[row].degree] = col;
        LDPC_H_check_nodes[row].degree++;
    }
    if (LDPC_H_var_nodes[col].degree < MAX_COL_WEIGHT) {
        LDPC_H_var_nodes[col].connected_checks[LDPC_H_var_nodes[col].degree] = row;
        LDPC_H_var_nodes[col].degree++;
    }
}

void LDPC_add_identity_block(uint16_t row_offset, uint16_t col_offset) {
    for (uint16_t i = 0; i < M; i++) {
        LDPC_add_connection(row_offset + i, col_offset + i);
    }
}

void LDPC_add_pi_k_block(uint16_t row_offset, uint16_t col_offset, uint8_t k_idx) {
    uint8_t table_idx = k_idx - 1;
    for (uint16_t i = 0; i < M; i++) {
        uint16_t local_col = LDPC_compute_pi_k(i, LDPC_THETA_TABLE[table_idx], LDPC_PHI_TABLE[table_idx]);
        LDPC_add_connection(row_offset + i, col_offset + local_col);
    }
}

void LDPC_init_H_matrix(void) {
    memset(LDPC_H_check_nodes, 0, sizeof(LDPC_H_check_nodes));
    memset(LDPC_H_var_nodes, 0, sizeof(LDPC_H_var_nodes));
    
    LDPC_add_identity_block(0 * M, 2 * M);
    LDPC_add_identity_block(0 * M, 4 * M);
    LDPC_add_pi_k_block(0 * M, 4 * M, 1);

    LDPC_add_identity_block(1 * M, 0 * M);
    LDPC_add_identity_block(1 * M, 1 * M);
    LDPC_add_identity_block(1 * M, 3 * M);
    LDPC_add_pi_k_block(1 * M, 4 * M, 2);
    LDPC_add_pi_k_block(1 * M, 4 * M, 3);
    LDPC_add_pi_k_block(1 * M, 4 * M, 4);

    LDPC_add_identity_block(2 * M, 0 * M);
    LDPC_add_pi_k_block(2 * M, 1 * M, 5);
    LDPC_add_pi_k_block(2 * M, 1 * M, 6);
    LDPC_add_pi_k_block(2 * M, 3 * M, 7);
    LDPC_add_pi_k_block(2 * M, 3 * M, 8);
    LDPC_add_identity_block(2 * M, 4 * M);
}

void LDPC_export_H_matrix_to_csv(const char* filename) {
    FILE *file = fopen(filename, "w");
    if (file == NULL) {
        printf("[ERROR] Cannot open file %s for writing.\n", filename);
        return;
    }

    fprintf(file, "Row,Col\n");
    for (uint16_t r = 0; r < H_ROWS; r++) {
        for (uint8_t i = 0; i < LDPC_H_check_nodes[r].degree; i++) {
            uint16_t c = LDPC_H_check_nodes[r].connected_vars[i];
            fprintf(file, "%u,%u\n", r, c);
        }
    }

    fclose(file);
    printf("[INFO] H Matrix successfully exported to %s\n", filename);
}
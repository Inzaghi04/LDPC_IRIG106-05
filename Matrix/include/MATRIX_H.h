/**
 * @file      matrix_h.h
 * @brief     Header file for IRIG 106-15 LDPC Parity Check Matrix (H) generation.
 * @details   Reusable library for Tanner Graph construction and manipulation.
 */

#ifndef MATRIX_H_H
#define MATRIX_H_H

#include <stdint.h>

#define M               512
#define M_OVER_4        (M / 4)
#define H_ROWS          1536
#define H_COLS          2560
#define MAX_ROW_WEIGHT  8
#define MAX_COL_WEIGHT  8

typedef struct {
    uint16_t connected_vars[MAX_ROW_WEIGHT]; 
    uint8_t  degree;                         
} CheckNode;

typedef struct {
    uint16_t connected_checks[MAX_COL_WEIGHT]; 
    uint8_t  degree;                           
} VariableNode;

/* Exposed Global Variables */
extern CheckNode    LDPC_H_check_nodes[H_ROWS];
extern VariableNode LDPC_H_var_nodes[H_COLS];

/* Exposed Permutation Tables */
extern const uint8_t LDPC_THETA_TABLE[8];
extern const uint8_t LDPC_PHI_TABLE[8][4];

/* ========================================================================= */
/* API FUNCTIONS                                                             */
/* ========================================================================= */

/**
 * @brief   Initializes the H matrix Tanner Graph.
 */
void LDPC_init_H_matrix(void);

/**
 * @brief   Exports the constructed H matrix to a CSV file.
 */
void LDPC_export_H_matrix_to_csv(const char* filename);

/**
 * @brief   Computes the local column index for the Pi_k permutation matrix.
 */
uint16_t LDPC_compute_pi_k(uint16_t i, uint8_t theta, const uint8_t *phi);

/**
 * @brief   Adds a bidirectional edge between a Check Node and a Variable Node.
 */
void LDPC_add_connection(uint16_t row, uint16_t col);

/**
 * @brief   Adds an Identity Matrix (I_M) block to the graph.
 */
void LDPC_add_identity_block(uint16_t row_offset, uint16_t col_offset);

/**
 * @brief   Adds a Permutation Matrix (Pi_k) block to the graph.
 */
void LDPC_add_pi_k_block(uint16_t row_offset, uint16_t col_offset, uint8_t k_idx);

#endif /* MATRIX_H */
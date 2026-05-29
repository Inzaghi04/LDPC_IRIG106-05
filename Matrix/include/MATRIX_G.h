#ifndef MATRIX_G_H
#define MATRIX_G_H
#include "MATRIX_H.h"
#include <stdio.h>
#include <string.h>
#define K_BITS 1024
#define P_SIZE 1536
void LDPC_extract_Q(void);
void export_Q_to_csv(const char* filename);
void LDPC_extract_P(void);
void export_P_to_csv(const char* filename);
void transposeMatrix(void);
int LDPC_inverse_P(void);
void LDPC_compute_W(void);
void LDPC_extract_G_seeds(const char* filename);
void LDPC_verify_G_HT(void);
#endif /* MATRIX_G_H */
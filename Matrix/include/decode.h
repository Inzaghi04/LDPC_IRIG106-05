#ifndef DECODE_H
#define DECODE_H
#include "MATRIX_H.h"
#include "MATRIX_G.h"
#include <math.h>
#include <stdlib.h>  // rand(), srand()
#define PI 3.14159265358979323846
void init_llr(const float *rx, float *llr);
void check_node_update(float *L_vc, float *L_cv, int deg);
void variable_node_update(float L_ch, float *L_cv, float *L_vc, int deg);
void decision(float L_ch, float *L_cv, int deg, uint8_t *bit);
int ldpc_decode(float *rx_llrs, uint8_t *decoded_bits, int max_iter);
double generate_gaussian_noise(double sigma);
#endif /* DECODE_H */
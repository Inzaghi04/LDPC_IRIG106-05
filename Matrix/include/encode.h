 #ifndef ENCODE_H
#define ENCODE_H
#include "MATRIX_H.h"
#include "MATRIX_G.h"
#include <stdio.h>
void shift_128(uint64_t *block);
void encode(const uint8_t *message, uint8_t *codeword);
#endif /* ENCODE_H */
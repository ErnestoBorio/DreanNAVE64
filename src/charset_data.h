#ifndef CHARSET_DATA_H
#define CHARSET_DATA_H

#include <stdint.h>

#define CHARSET_SIZE 2048
#define CHARSET_NUM_CHARS 256

// Star background character definitions (Chars 0x75 to 0x7F)
#define CHAR_STAR_75 0x75
#define CHAR_STAR_76 0x76
#define CHAR_STAR_77 0x77
#define CHAR_STAR_78 0x78
#define CHAR_STAR_79 0x79
#define CHAR_STAR_7A 0x7A
#define CHAR_STAR_7B 0x7B
#define CHAR_STAR_7C 0x7C
#define CHAR_STAR_7D 0x7D
#define CHAR_STAR_7E 0x7E
#define CHAR_STAR_7F 0x7F

// Full 2048-byte rotated custom charset definition
extern const uint8_t g_custom_charset[CHARSET_SIZE];

#endif // CHARSET_DATA_H

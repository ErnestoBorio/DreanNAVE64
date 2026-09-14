#include "input.h"
#include "c64_hardware.h"

void input_init(void) {
    // Port A & B as inputs initially
    CIA1_DIR_A = 0x00;
    CIA1_DIR_B = 0x00;
}

void input_update(InputState* state) {
    if (!state) return;

    // Default input state
    state->up = false;
    state->down = false;
    state->left = false;
    state->right = false;
    state->fire = false;

    // 1. Read Joystick Port 2 (Active Low on CIA1 Data A)
    CIA1_DIR_A = 0x00;
    uint8_t joy = CIA1_DATA_A;

    if (!(joy & 0x01)) state->up = true;
    if (!(joy & 0x02)) state->down = true;
    if (!(joy & 0x04)) state->left = true;
    if (!(joy & 0x08)) state->right = true;
    if (!(joy & 0x10)) state->fire = true;

    // 2. Scan C64 Keyboard Matrix for Dual Key Sets (R-D-F-G and U-H-J-K)
    CIA1_DIR_A = 0xFF; // Set Port A as outputs for matrix column selection

    // Scan Column 2 (Active Low bit 2 = 0xFB)
    CIA1_DATA_A = 0xFB;
    uint8_t col2 = CIA1_DATA_B;
    if (!(col2 & 0x08)) state->up = true;    // 'R' key (Up in Horizontal)
    if (!(col2 & 0x04)) state->left = true;  // 'D' key (Left in Horizontal)
    if (!(col2 & 0x20)) state->down = true;  // 'F' key (Down in Horizontal)

    // Scan Column 3 (Active Low bit 3 = 0xF7)
    CIA1_DATA_A = 0xF7;
    uint8_t col3 = CIA1_DATA_B;
    if (!(col3 & 0x04)) state->right = true; // 'G' key (Right in Horizontal)
    if (!(col3 & 0x40)) state->right = true; // 'U' key (Screen Up / Native Right in TATE)
    if (!(col3 & 0x20)) state->up = true;    // 'H' key (Screen Left / Native Up in TATE)

    // Scan Column 4 (Active Low bit 4 = 0xEF)
    CIA1_DATA_A = 0xEF;
    uint8_t col4 = CIA1_DATA_B;
    if (!(col4 & 0x04)) state->left = true;  // 'J' key (Screen Down / Native Left in TATE)
    if (!(col4 & 0x20)) state->down = true;  // 'K' key (Screen Right / Native Down in TATE)

    // Scan Column 7 (Active Low bit 7 = 0x7F) for Space key (Fire)
    CIA1_DATA_A = 0x7F;
    uint8_t col7 = CIA1_DATA_B;
    if (!(col7 & 0x10)) state->fire = true;  // Space key

    // Reset Port A to input mode for next frame
    CIA1_DIR_A = 0x00;
}

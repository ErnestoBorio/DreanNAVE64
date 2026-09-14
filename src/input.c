#include "input.h"
#include "c64_hardware.h"

void input_init(void) {
    // Initialize CIA1 Port A & B as inputs with high pull-ups
    CIA1_DIR_A = 0x00;
    CIA1_DIR_B = 0x00;
    CIA1_DATA_A = 0xFF;
    CIA1_DATA_B = 0xFF;
}

void input_update(InputState* state) {
    if (!state) return;

    state->up = false;
    state->down = false;
    state->left = false;
    state->right = false;
    state->fire = false;

    // 1. Read Joystick Port 2 (Ensure Port A and B are inputs)
    CIA1_DIR_A = 0x00;
    CIA1_DIR_B = 0x00;
    
    uint8_t joy2 = CIA1_DATA_A;

    if (!(joy2 & 0x01)) state->up = true;
    if (!(joy2 & 0x02)) state->down = true;
    if (!(joy2 & 0x04)) state->left = true;
    if (!(joy2 & 0x08)) state->right = true;
    if (!(joy2 & 0x10)) state->fire = true;

    // 2. Scan Keyboard Matrix
    // Set Port A as output (column select), Port B as input (row read)
    CIA1_DIR_A = 0xFF;
    CIA1_DIR_B = 0x00;

    // --- Column PA2 (0xFB = ~0x04): R, D, F ---
    CIA1_DATA_A = 0xFB;
    uint8_t pb_col2 = CIA1_DATA_B;
    if (!(pb_col2 & 0x02)) state->up = true;    // 'R' (PB1) -> Up (Horizontal)
    if (!(pb_col2 & 0x04)) state->left = true;  // 'D' (PB2) -> Left (Horizontal)
    if (!(pb_col2 & 0x20)) state->down = true;  // 'F' (PB5) -> Down (Horizontal)

    // --- Column PA3 (0xF7 = ~0x08): G, H, U ---
    CIA1_DATA_A = 0xF7;
    uint8_t pb_col3 = CIA1_DATA_B;
    if (!(pb_col3 & 0x04)) state->right = true; // 'G' (PB2) -> Right (Horizontal)
    if (!(pb_col3 & 0x20)) state->up = true;    // 'H' (PB5) -> Screen Left / Native Up (TATE)
    if (!(pb_col3 & 0x40)) state->right = true; // 'U' (PB6) -> Screen Up / Native Right (TATE)

    // --- Column PA4 (0xEF = ~0x10): J, K ---
    CIA1_DATA_A = 0xEF;
    uint8_t pb_col4 = CIA1_DATA_B;
    if (!(pb_col4 & 0x04)) state->left = true;  // 'J' (PB2) -> Screen Down / Native Left (TATE)
    if (!(pb_col4 & 0x20)) state->down = true;  // 'K' (PB5) -> Screen Right / Native Down (TATE)

    // --- Column PA0 (0xFE = ~0x01): Space ---
    CIA1_DATA_A = 0xFE;
    uint8_t pb_col0 = CIA1_DATA_B;
    if (!(pb_col0 & 0x10)) state->fire = true;  // Space (PB4) -> Fire

    // Reset CIA1 Port A & B to input mode for next frame
    CIA1_DATA_A = 0xFF;
    CIA1_DIR_A = 0x00;
    CIA1_DIR_B = 0x00;
}

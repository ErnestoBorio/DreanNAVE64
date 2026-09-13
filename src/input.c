#include "input.h"

void input_init(void) {
    // Phase 0 stub
}

void input_update(InputState* state) {
    if (!state) return;
    state->up = false;
    state->down = false;
    state->left = false;
    state->right = false;
    state->fire = false;
}

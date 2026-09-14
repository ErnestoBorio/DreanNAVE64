#ifndef INPUT_H
#define INPUT_H

#include <stdbool.h>
#include <stdint.h>

typedef struct {
    bool up;
    bool down;
    bool left;
    bool right;
    bool fire;
} InputState;

void input_init(void);
void input_update(InputState* state);

#endif // INPUT_H


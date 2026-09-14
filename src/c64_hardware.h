#ifndef C64_HARDWARE_H
#define C64_HARDWARE_H

#include <stdint.h>
#include <stdbool.h>

// VIC-II Registers
#define VIC_SPR0_X          (*(volatile uint8_t*)0xD000)
#define VIC_SPR0_Y          (*(volatile uint8_t*)0xD001)
#define VIC_SPR1_X          (*(volatile uint8_t*)0xD002)
#define VIC_SPR1_Y          (*(volatile uint8_t*)0xD003)
#define VIC_SPR_MSB         (*(volatile uint8_t*)0xD010)
#define VIC_CTRL1           (*(volatile uint8_t*)0xD011)
#define VIC_RASTER          (*(volatile uint8_t*)0xD012)
#define VIC_SPR_ENABLE      (*(volatile uint8_t*)0xD015)
#define VIC_CTRL2           (*(volatile uint8_t*)0xD016)
#define VIC_SPR_EXP_Y       (*(volatile uint8_t*)0xD017)
#define VIC_MEM_SETUP       (*(volatile uint8_t*)0xD018)
#define VIC_IRQ_FLAGS       (*(volatile uint8_t*)0xD019)
#define VIC_IRQ_ENABLE      (*(volatile uint8_t*)0xD01A)
#define VIC_BORDER_COLOR    (*(volatile uint8_t*)0xD020)
#define VIC_BG_COLOR0       (*(volatile uint8_t*)0xD021)
#define VIC_SPR_MULTICOLOR  (*(volatile uint8_t*)0xD01C)
#define VIC_SPR_MC0         (*(volatile uint8_t*)0xD025)
#define VIC_SPR_MC1         (*(volatile uint8_t*)0xD026)
#define VIC_SPR0_COLOR      (*(volatile uint8_t*)0xD027)

// CIA Registers for Joystick & Keyboard Input
#define CIA1_DATA_A         (*(volatile uint8_t*)0xDC00) // Joystick 2 / Keyboard Column
#define CIA1_DATA_B         (*(volatile uint8_t*)0xDC01) // Joystick 1 / Keyboard Row
#define CIA1_DIR_A          (*(volatile uint8_t*)0xDC02)
#define CIA1_DIR_B          (*(volatile uint8_t*)0xDC03)

// Memory Layout Constants
#define SCREEN_RAM          ((volatile uint8_t*)0x0400)
#define COLOR_RAM           ((volatile uint8_t*)0xD800)
#define SPRITE_PTRS         ((volatile uint8_t*)0x07F8)

// Color Palette Constants
#define COLOR_BLACK         0
#define COLOR_WHITE         1
#define COLOR_RED           2
#define COLOR_CYAN          3
#define COLOR_PURPLE        4
#define COLOR_GREEN         5
#define COLOR_BLUE          6
#define COLOR_YELLOW        7
#define COLOR_ORANGE        8
#define COLOR_BROWN         9
#define COLOR_LIGHT_RED     10
#define COLOR_DARK_GRAY     11
#define COLOR_MEDIUM_GRAY   12
#define COLOR_LIGHT_GREEN   13
#define COLOR_LIGHT_BLUE    14
#define COLOR_LIGHT_GRAY    15

// Screen bounds in VIC-II Sprite Coordinate Space
#define SPRITE_MIN_X        24
#define SPRITE_MAX_X        320
#define SPRITE_MIN_Y        50
#define SPRITE_MAX_Y        240

#endif // C64_HARDWARE_H


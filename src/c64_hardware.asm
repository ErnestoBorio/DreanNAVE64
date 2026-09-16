; ==============================================================================
; C64_HARDWARE.ASM - Commodore 64 Hardware Registers & Memory Map Equates
; ==============================================================================
; This file defines symbolic names (equates) for all hardware registers on the
; VIC-II graphics chip, CIA1/CIA2 I/O chips, RAM pointer tables, and color constants.
; ==============================================================================

; ------------------------------------------------------------------------------
; VIC-II Graphics Chip Registers ($D000 - $D02E)
; ------------------------------------------------------------------------------
VIC_SPR0_X          = $d000     ; Sprite 0 X-coordinate (0..255)
VIC_SPR0_Y          = $d001     ; Sprite 0 Y-coordinate (0..255)
VIC_SPR1_X          = $d002     ; Sprite 1 X-coordinate (0..255)
VIC_SPR1_Y          = $d003     ; Sprite 1 Y-coordinate (0..255)
VIC_SPR_MSB         = $d010     ; Most Significant Bit (MSB) of Sprite X-coordinates (Bits 0..7)
VIC_CTRL1           = $d011     ; VIC Control Register 1 (Bit 7: Raster Bit 8, Bit 5: Screen On)
VIC_RASTER          = $d012     ; Current Raster Line Counter (Bits 0..7, 0..255)
VIC_SPR_ENABLE      = $d015     ; Sprite Enable Mask (Bit 0=Spr0, Bit 1=Spr1, ..., Bit 7=Spr7)
VIC_CTRL2           = $d016     ; VIC Control Register 2 (Bits 0..2: Fine X-scroll 0..7, Bit 3: 38/40 cols)
VIC_SPR_EXP_Y       = $d017     ; Sprite Expand Y (Height doubled when bit set)
VIC_MEM_SETUP       = $d018     ; Memory Control (Bits 4..7: Screen RAM, Bits 1..3: Charset RAM)
VIC_IRQ_FLAGS       = $d019     ; Interrupt Flag Register (Bit 0: Raster IRQ triggered)
VIC_IRQ_ENABLE      = $d01a     ; Interrupt Enable Register (Bit 0: Enable Raster IRQ)
VIC_SPR_MULTICOLOR  = $d01c     ; Sprite Multicolor Mode Mask (1=Multicolor 4-color, 0=Hi-res 2-color)
VIC_BORDER_COLOR    = $d020     ; Border Color Register (0..15)
VIC_BG_COLOR0       = $d021     ; Background Color 0 Register (0..15)
VIC_SPR_MC0         = $d025     ; Sprite Shared Multicolor 0 ($D025)
VIC_SPR_MC1         = $d026     ; Sprite Shared Multicolor 1 ($D026)
VIC_SPR0_COLOR      = $d027     ; Sprite 0 Individual Color ($D027)
VIC_SPR1_COLOR      = $d028     ; Sprite 1 Individual Color ($D028)

; ------------------------------------------------------------------------------
; CIA 1 Complex Interface Adapter ($DC00 - $DC0F) - Joysticks & Keyboard
; ------------------------------------------------------------------------------
CIA1_DATA_A         = $dc00     ; Port A Data Register (Joystick 2 inputs / Keyboard Matrix Columns)
CIA1_DATA_B         = $dc01     ; Port B Data Register (Joystick 1 inputs / Keyboard Matrix Rows)
CIA1_DIR_A          = $dc02     ; Port A Data Direction Register (1 = Output, 0 = Input)
CIA1_DIR_B          = $dc03     ; Port B Data Direction Register (1 = Output, 0 = Input)
CIA1_ICR            = $dc0d     ; Interrupt Control & Status Register (Bit 7: IRQ occurred)
CIA1_CRA            = $dc0e     ; Control Register A (Bit 0: Start/Stop Timer A)
CIA1_CRB            = $dc0f     ; Control Register B (Bit 0: Start/Stop Timer B)

; ------------------------------------------------------------------------------
; CIA 2 Complex Interface Adapter ($DD00 - $DD0F) - VIC Bank & NMIs
; ------------------------------------------------------------------------------
CIA2_DATA_A         = $dd00     ; Port A (Bits 0..1 select VIC-II 16KB Memory Bank)
CIA2_ICR            = $dd0d     ; Interrupt Control & Status Register (Bit 7: NMI occurred)
CIA2_CRA            = $dd0e     ; Control Register A (Bit 0: Start/Stop Timer A)
CIA2_CRB            = $dd0f     ; Control Register B (Bit 0: Start/Stop Timer B)

; ------------------------------------------------------------------------------
; System Vectors & Hardware RAM Pointers
; ------------------------------------------------------------------------------
IRQ_VECTOR          = $0314     ; Hardware RAM Interrupt Vector (Low/High byte)
NMI_VECTOR          = $0318     ; Hardware RAM NMI Vector (Low/High byte)
SCREEN_RAM          = $0400     ; 1000-byte Screen Character RAM ($0400 - $07E7)
SPRITE_PTRS         = $07f8     ; 8-byte Sprite Pointer Table ($07F8 - $07FF)
COLOR_RAM           = $d800     ; 1000-byte Color RAM ($D800 - $DBE7)

; ------------------------------------------------------------------------------
; C64 Color Constants (0..15)
; ------------------------------------------------------------------------------
COLOR_BLACK         = 0
COLOR_WHITE         = 1
COLOR_RED           = 2
COLOR_CYAN          = 3
COLOR_PURPLE        = 4
COLOR_GREEN         = 5
COLOR_BLUE          = 6
COLOR_YELLOW        = 7
COLOR_ORANGE        = 8
COLOR_BROWN         = 9
COLOR_LIGHT_RED     = 10
COLOR_DARK_GRAY     = 11
COLOR_MEDIUM_GRAY   = 12
COLOR_LIGHT_GREEN   = 13
COLOR_LIGHT_BLUE    = 14
COLOR_LIGHT_GRAY    = 15
COLOR_PINK          = COLOR_PURPLE  ; C64 Purple maps to Pink

; ------------------------------------------------------------------------------
; Screen Bounds in VIC-II Sprite Coordinate Space
; ------------------------------------------------------------------------------
SPRITE_MIN_X        = 24
SPRITE_MAX_X        = 320
SPRITE_MIN_Y        = 50
SPRITE_MAX_Y        = 240


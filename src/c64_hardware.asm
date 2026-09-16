; ==============================================================================
; C64_HARDWARE.ASM - Commodore 64 Hardware Registers & Equates
; ==============================================================================
; Target: Commodore 64 (MOS 6510 CPU, VIC-II 6569/8565 PAL, CIA 6526 x2, SID 6581)
; Assembler: ACME 6502 Assembler
; ==============================================================================

; ------------------------------------------------------------------------------
; VIC-II Registers ($D000 - $D02E)
; ------------------------------------------------------------------------------
VIC_SPR0_X          = $d000     ; Sprite 0 X coordinate (bits 0-7)
VIC_SPR0_Y          = $d001     ; Sprite 0 Y coordinate (bits 0-7)
VIC_SPR1_X          = $d002     ; Sprite 1 X coordinate (bits 0-7)
VIC_SPR1_Y          = $d003     ; Sprite 1 Y coordinate (bits 0-7)
VIC_SPR2_X          = $d004     ; Sprite 2 X coordinate (bits 0-7)
VIC_SPR2_Y          = $d005     ; Sprite 2 Y coordinate (bits 0-7)
VIC_SPR3_X          = $d006     ; Sprite 3 X coordinate (bits 0-7)
VIC_SPR3_Y          = $d007     ; Sprite 3 Y coordinate (bits 0-7)
VIC_SPR4_X          = $d008     ; Sprite 4 X coordinate (bits 0-7)
VIC_SPR4_Y          = $d009     ; Sprite 4 Y coordinate (bits 0-7)
VIC_SPR5_X          = $d00a     ; Sprite 5 X coordinate (bits 0-7)
VIC_SPR5_Y          = $d00b     ; Sprite 5 Y coordinate (bits 0-7)
VIC_SPR6_X          = $d00c     ; Sprite 6 X coordinate (bits 0-7)
VIC_SPR6_Y          = $d00d     ; Sprite 6 Y coordinate (bits 0-7)
VIC_SPR7_X          = $d00e     ; Sprite 7 X coordinate (bits 0-7)
VIC_SPR7_Y          = $d00f     ; Sprite 7 Y coordinate (bits 0-7)
VIC_SPR_MSB         = $d010     ; Most Significant Bit (bit 8) for Sprite X coordinates (0-7)
VIC_CTRL1           = $d011     ; Control register 1 (Bit 7 = Raster Bit 8, Bit 4 = Screen Blank)
VIC_RASTER          = $d012     ; Current raster line counter (Bits 0-7)
VIC_SPR_ENABLE      = $d015     ; Sprite enable register (1 bit per sprite)
VIC_CTRL2           = $d016     ; Control register 2 (Bits 0-2 = X scroll, Bit 3 = 38/40 cols)
VIC_SPR_EXP_Y       = $d017     ; Sprite vertical expansion (1 = 2x height)
VIC_MEM_SETUP       = $d018     ; Memory setup (Bits 4-7 = Screen RAM, Bits 1-3 = Charset)
VIC_IRQ_FLAGS       = $d019     ; Interrupt flags register (Write 1 to clear)
VIC_IRQ_ENABLE      = $d01a     ; Interrupt mask register (Bit 0 = Raster IRQ)
VIC_SPR_PRIORITY    = $d01b     ; Sprite to background priority (0 = Foreground)
VIC_SPR_MULTICOLOR  = $d01c     ; Sprite multicolor mode enable (1 = Multicolor)
VIC_SPR_EXP_X       = $d01d     ; Sprite horizontal expansion (1 = 2x width)
VIC_SPR_COLL_SPR    = $d01e     ; Sprite-to-sprite collision latch
VIC_SPR_COLL_BG     = $d01f     ; Sprite-to-background collision latch
VIC_BORDER_COLOR    = $d020     ; Border color register (0-15)
VIC_BG_COLOR0       = $d021     ; Background color 0 register (0-15)
VIC_BG_COLOR1       = $d022     ; Background color 1
VIC_BG_COLOR2       = $d023     ; Background color 2
VIC_BG_COLOR3       = $d024     ; Background color 3
VIC_SPR_MC0         = $d025     ; Shared sprite multicolor 0
VIC_SPR_MC1         = $d026     ; Shared sprite multicolor 1
VIC_SPR0_COLOR      = $d027     ; Sprite 0 individual color
VIC_SPR1_COLOR      = $d028     ; Sprite 1 individual color
VIC_SPR2_COLOR      = $d029     ; Sprite 2 individual color
VIC_SPR3_COLOR      = $d02a     ; Sprite 3 individual color
VIC_SPR4_COLOR      = $d02b     ; Sprite 4 individual color
VIC_SPR5_COLOR      = $d02c     ; Sprite 5 individual color
VIC_SPR6_COLOR      = $d02d     ; Sprite 6 individual color
VIC_SPR7_COLOR      = $d02e     ; Sprite 7 individual color

; ------------------------------------------------------------------------------
; CIA 1 Registers ($DC00 - $DC0F) - Keyboard Matrix & Joystick Port 2
; ------------------------------------------------------------------------------
CIA1_DATA_A         = $dc00     ; Port A Data (Joystick 2 read / Keyboard column select)
CIA1_DATA_B         = $dc01     ; Port B Data (Joystick 1 read / Keyboard row read)
CIA1_DIR_A          = $dc02     ; Port A Data Direction Register (0 = Input, 1 = Output)
CIA1_DIR_B          = $dc03     ; Port B Data Direction Register
CIA1_ICR            = $dc0d     ; Interrupt Control Register (Read = Ack, Write = Mask)
CIA1_CRA            = $dc0e     ; Control Register A (Timer A control)
CIA1_CRB            = $dc0f     ; Control Register B (Timer B control)

; ------------------------------------------------------------------------------
; CIA 2 Registers ($DD00 - $DD0F) - VIC-II Bank & RS-232 / NMI
; ------------------------------------------------------------------------------
CIA2_DATA_A         = $dd00     ; Port A Data (Bits 0-1 = VIC-II Bank select)
CIA2_DIR_A          = $dd02     ; Port A Data Direction
CIA2_ICR            = $dd0d     ; Interrupt Control Register (NMI control)
CIA2_CRA            = $dd0e     ; Control Register A
CIA2_CRB            = $dd0f     ; Control Register B

; ------------------------------------------------------------------------------
; Standard Memory Pointers & System Vectors
; ------------------------------------------------------------------------------
SCREEN_RAM          = $0400     ; Screen text RAM (40 cols x 25 rows = 1000 bytes)
COLOR_RAM           = $d800     ; Color RAM (4-bit nibbles: $D800 - $DBE7)
SPRITE_PTRS         = $07f8     ; Sprite Data Pointers for Sprites 0-7 ($07F8 - $07FF)
IRQ_VECTOR          = $0314     ; Hardware Maskable Interrupt vector ($0314 - $0315)
NMI_VECTOR          = $0318     ; Hardware Non-Maskable Interrupt vector ($0318 - $0319)

; ------------------------------------------------------------------------------
; C64 Standard Color Palette (0 - 15)
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

; ------------------------------------------------------------------------------
; Screen & Playfield Coordinate Constants (PAL C64)
; ------------------------------------------------------------------------------
SPRITE_MIN_X        = 24        ; Left visible border edge
SPRITE_MAX_X        = 320       ; Right visible border edge (16-bit: High=1, Low=64)
SPRITE_MIN_Y        = 50        ; Top visible border edge
SPRITE_MAX_Y        = 240       ; Bottom visible border edge


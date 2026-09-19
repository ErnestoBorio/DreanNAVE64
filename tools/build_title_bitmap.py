#!/usr/bin/env python3
"""
tools/build_title_bitmap.py - Pre-bakes the 320x200 C64 Hi-Res Title Screen Bitmap.

Reads:
- refes/NAVE_logo.png (83x194 monochrome 1-bit PNG)
- src/charset_data.asm (for 8x8 font glyphs, including char 102 copyright and char 103 copyleft)

Generates:
- bin/title_bitmap.bin (8000 bytes raw C64 bitmap data for VIC-II Hi-Res mode)
"""

import os
import struct
import zlib

def load_png(filename):
    with open(filename, 'rb') as f:
        data = f.read()

    pos = 8
    idat = bytearray()
    w, h = 0, 0
    while pos < len(data):
        length, ctype = struct.unpack('>I4s', data[pos:pos+8])
        if ctype == b'IHDR':
            w, h = struct.unpack('>II', data[pos+8:pos+8+8])
        elif ctype == b'IDAT':
            idat.extend(data[pos+8:pos+8+length])
        pos += 8 + length + 4

    raw = zlib.decompress(idat)
    stride = 1 + (w + 7) // 8
    pixels = [[0] * w for _ in range(h)]
    for y in range(h):
        line = raw[y * stride + 1 : (y + 1) * stride]
        for x in range(w):
            byte_idx = x // 8
            bit_idx = 7 - (x % 8)
            if line[byte_idx] & (1 << bit_idx):
                pixels[y][x] = 1
    return w, h, pixels

def parse_charset(filename):
    charset = {}
    with open(filename, 'r') as f:
        lines = f.readlines()

    current_char = None
    for line in lines:
        line = line.strip()
        if line.startswith('; Char $'):
            p1 = line.find('(')
            p2 = line.find(')')
            if p1 != -1 and p2 != -1:
                current_char = int(line[p1+1:p2])
        elif line.startswith('!byte') and current_char is not None:
            parts = [int(p.strip().replace('$', '0x'), 16) for p in line[5:].split(',')]
            if len(parts) == 8:
                charset[current_char] = parts
                current_char = None
    return charset

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    logo_path = os.path.join(repo_root, 'refes', 'NAVE_logo.png')
    charset_path = os.path.join(repo_root, 'src', 'charset_data.asm')
    out_bin = os.path.join(repo_root, 'bin', 'title_bitmap.bin')

    logo_w, logo_h, logo_pixels = load_png(logo_path)
    charset = parse_charset(charset_path)

    # 320x200 pixel matrix (C64 standard coordinates: X=0..319, Y=0..199)
    # In TATE (90 deg CCW rotation):
    # - Top of vertical screen is high X (Columns 39..29)
    # - Bottom of vertical screen is low X (Columns 0..8)
    # - Left of vertical screen is low Y (Row 0..2)
    # - Right of vertical screen is high Y (Row 22..24)
    pixels = [[0] * 320 for _ in range(200)]

    # 1. Place NAVE logo at top of TATE screen (X = 234..316, Y = 3..196)
    # logo_w = 83, logo_h = 194
    for ly in range(logo_h):
        for lx in range(logo_w):
            if logo_pixels[ly][lx]:
                c64_x = 234 + lx
                c64_y = 3 + ly
                pixels[c64_y][c64_x] = 1

    # Helper to draw character glyph from charset at Column C (0..39), Row R (0..24)
    def draw_char(col_c, row_r, ch):
        glyph = charset.get(ch, [0]*8)
        for s in range(8):
            y = row_r * 8 + s
            b = glyph[s]
            for px in range(8):
                if b & (1 << (7 - px)):
                    x = col_c * 8 + px
                    if 0 <= x < 320 and 0 <= y < 200:
                        pixels[y][x] = 1

    def str_to_codes(s):
        codes = []
        for c in s:
            if c == ' ':
                codes.append(32)
            elif '0' <= c <= '9' or 'A' <= c <= 'Z':
                codes.append(ord(c))
            elif 'a' <= c <= 'z':
                codes.append(ord(c.upper()))
            else:
                codes.append(ord(c))
        return codes

    def draw_string(col_c, start_row, char_codes):
        for i, ch in enumerate(char_codes):
            draw_char(col_c, start_row + i, ch)

    # 2. "HIGH SCORE" at Column 25, Rows 7..16 (10 chars, centered: (25-10)//2 = 7)
    draw_string(25, 7, str_to_codes('HIGH SCORE'))

    # 3. Default "000" at Column 23, Rows 11..13 (3 chars, centered: (25-3)//2 = 11)
    # Note: 6502 runtime will stamp actual g_high_score into Column 23 upon entering title!
    draw_string(23, 11, str_to_codes('000'))

    # 4. "(C)2012 VIDEOGAMO INC" at Column 17, Rows 3..21 (19 chars: [102] + 18 chars, centered: (25-19)//2 = 3)
    c_line = [102] + str_to_codes('2012 VIDEOGAMO INC')
    draw_string(17, 3, c_line)

    # 5. "(D)2026 DREAN64" at Column 15, Rows 6..18 (13 chars: [103] + 12 chars, centered: (25-13)//2 = 6)
    d_line = [103] + str_to_codes('2026 DREAN64')
    draw_string(15, 6, d_line)

    # 6. "PRESS FIRE TO START" at Column 8, Rows 3..21 (19 chars, centered: (25-19)//2 = 3)
    draw_string(8, 3, str_to_codes('PRESS FIRE TO START'))

    # Convert 320x200 pixels to C64 Hi-Res Bitmap Format (8000 bytes)
    # Cell order: Row 0 (Cols 0..39), Row 1 (Cols 0..39), ..., Row 24 (Cols 0..39)
    # Inside each cell: 8 scanlines (s=0..7), Bit 7 = leftmost pixel (x % 8 = 0)
    bitmap = bytearray(8000)
    for r in range(25):
        for c in range(40):
            cell_offset = (r * 40 + c) * 8
            for s in range(8):
                y = r * 8 + s
                byte_val = 0
                for px in range(8):
                    x = c * 8 + px
                    if pixels[y][x]:
                        byte_val |= (1 << (7 - px))
                bitmap[cell_offset + s] = byte_val

    # Write binary to both assets/ and bin/
    assets_bin = os.path.join(repo_root, 'assets', 'title_bitmap.bin')
    os.makedirs(os.path.dirname(assets_bin), exist_ok=True)
    with open(assets_bin, 'wb') as f:
        f.write(bitmap)
    print(f'Generated {assets_bin} ({len(bitmap)} bytes).')

    os.makedirs(os.path.dirname(out_bin), exist_ok=True)
    with open(out_bin, 'wb') as f:
        f.write(bitmap)
    print(f'Generated {out_bin} ({len(bitmap)} bytes).')

    # Also generate a TATE rotated PNG preview (200 wide x 320 high)
    def save_png(filename, w, h, img_rows):
        def chunk(ctype, cdata):
            crc = zlib.crc32(ctype + cdata) & 0xffffffff
            return struct.pack('>I', len(cdata)) + ctype + cdata + struct.pack('>I', crc)

        raw = bytearray()
        for row in img_rows:
            raw.append(0) # Filter type 0 (None)
            raw.extend(row)
        compressed = zlib.compress(bytes(raw), 9)

        ihdr = struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0)
        png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', compressed) + chunk(b'IEND', b'')
        with open(filename, 'wb') as f:
            f.write(png)

    # In TATE view:
    # Width = 200 (C64 Y: 0..199), Height = 320 (C64 X: 319..0)
    tate_w, tate_h = 200, 320
    tate_rows = []
    for ty in range(tate_h):
        c64_x = 319 - ty
        row = bytearray(tate_w)
        for tx in range(tate_w):
            c64_y = tx
            if pixels[c64_y][c64_x]:
                row[tx] = 255
        tate_rows.append(row)

    preview_path = os.path.join(repo_root, 'bin', 'tate_title_preview.png')
    save_png(preview_path, tate_w, tate_h, tate_rows)
    print(f'Generated preview: {preview_path}')

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Scalable C64 Asset Pipeline Converter
Converts all PNG assets in assets/ into C byte arrays and header files.
Supports single sprites, multi-frame sprite sheets, and custom 8x8 charsets.
"""

import os
import glob
import json
import zlib
import struct

def read_png(path):
    with open(path, 'rb') as f:
        data = f.read()

    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f"{path} is not a PNG file")

    offset = 8
    width, height, bit_depth, color_type = 0, 0, 0, 0
    idat_data = bytearray()

    while offset < len(data):
        length, chunk_type = struct.unpack('>I4s', data[offset:offset+8])
        chunk_data = data[offset+8:offset+8+length]
        offset += 12 + length

        if chunk_type == b'IHDR':
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack('>IIBBBBB', chunk_data)
        elif chunk_type == b'IDAT':
            idat_data.extend(chunk_data)
        elif chunk_type == b'IEND':
            break

    decompressed = zlib.decompress(idat_data)
    bpp = 4 if color_type == 6 else (3 if color_type == 2 else 1)
    stride = width * bpp + 1
    
    pixels = []
    prev_line = [0] * (width * bpp)
    
    for y in range(height):
        line = decompressed[y * stride : (y + 1) * stride]
        filter_type = line[0]
        line_data = bytearray(line[1:])
        
        if filter_type == 1:
            for i in range(bpp, len(line_data)):
                line_data[i] = (line_data[i] + line_data[i - bpp]) & 0xFF
        elif filter_type == 2:
            for i in range(len(line_data)):
                line_data[i] = (line_data[i] + prev_line[i]) & 0xFF
        elif filter_type == 3:
            for i in range(len(line_data)):
                left = line_data[i - bpp] if i >= bpp else 0
                line_data[i] = (line_data[i] + ((left + prev_line[i]) // 2)) & 0xFF
        elif filter_type == 4:
            for i in range(len(line_data)):
                left = line_data[i - bpp] if i >= bpp else 0
                up = prev_line[i]
                upper_left = prev_line[i - bpp] if i >= bpp else 0
                p = left + up - upper_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - upper_left)
                pr = left if pa <= pb and pa <= pc else (up if pb <= pc else upper_left)
                line_data[i] = (line_data[i] + pr) & 0xFF

        prev_line = line_data
        
        row_colors = []
        for x in range(width):
            if bpp == 4:
                r, g, b, a = line_data[x*4:x*4+4]
                row_colors.append((r, g, b, a))
            elif bpp == 3:
                r, g, b = line_data[x*3:x*3+3]
                row_colors.append((r, g, b, 255))
        pixels.append(row_colors)

    return width, height, pixels


def map_color_to_multicolor_bits(r, g, b, a):
    """Map RGBA pixel to C64 Multicolor Sprite 2-bit pair."""
    if a == 0:
        return 0b00 # %00 = Transparent / Background
    elif r > 200 and g > 200 and b > 200:
        return 0b10 # %10 = Individual Sprite Color ($D027) - White
    elif r > 100 and g > 100 and b > 200:
        return 0b11 # %11 = Sprite Multicolor 1 ($D026) - Light Blue
    else:
        return 0b01 # %01 = Sprite Multicolor 0 ($D025) - Medium Gray


def map_color_to_hires_bit(r, g, b, a):
    """Map RGBA pixel to C64 Hires 1-bit value."""
    if a == 0 or (r < 50 and g < 50 and b < 50):
        return 0 # 0 = Background
    return 1     # 1 = Foreground


def convert_single_sprite_frame(pix, img_w, img_h, x_offset=0, y_offset=0, multicolor=True):
    """Extract a 24x21 sprite frame starting at (x_offset, y_offset) into 64 bytes."""
    sprite_bytes = []

    for y in range(21):
        py = y_offset + y
        row_pix = pix[py] if py < img_h else [(0, 0, 0, 0)] * img_w

        if multicolor:
            row_bits = []
            for fp in range(12): # 12 fat pixels (24 hires pixels)
                px0 = x_offset + fp * 2
                px1 = x_offset + fp * 2 + 1

                c0 = row_pix[px0] if px0 < img_w else (0, 0, 0, 0)
                c1 = row_pix[px1] if px1 < img_w else (0, 0, 0, 0)

                # Sample non-transparent color
                c = c0 if c0[3] > 0 else c1
                bits = map_color_to_multicolor_bits(c[0], c[1], c[2], c[3])
                row_bits.append(bits)

            # Pack 12 fat pixels (2 bits each) into 3 bytes
            b0 = (row_bits[0] << 6) | (row_bits[1] << 4) | (row_bits[2] << 2) | row_bits[3]
            b1 = (row_bits[4] << 6) | (row_bits[5] << 4) | (row_bits[6] << 2) | row_bits[7]
            b2 = (row_bits[8] << 6) | (row_bits[9] << 4) | (row_bits[10] << 2) | row_bits[11]
            sprite_bytes.extend([b0, b1, b2])

        else:
            # Hires Monochrome Sprite (24 bits = 3 bytes per row)
            b0, b1, b2 = 0, 0, 0
            for bit in range(8):
                px = x_offset + bit
                c = row_pix[px] if px < img_w else (0, 0, 0, 0)
                if map_color_to_hires_bit(c[0], c[1], c[2], c[3]):
                    b0 |= (1 << (7 - bit))

            for bit in range(8):
                px = x_offset + 8 + bit
                c = row_pix[px] if px < img_w else (0, 0, 0, 0)
                if map_color_to_hires_bit(c[0], c[1], c[2], c[3]):
                    b1 |= (1 << (7 - bit))

            for bit in range(8):
                px = x_offset + 16 + bit
                c = row_pix[px] if px < img_w else (0, 0, 0, 0)
                if map_color_to_hires_bit(c[0], c[1], c[2], c[3]):
                    b2 |= (1 << (7 - bit))

            sprite_bytes.extend([b0, b1, b2])

    sprite_bytes.append(0x00) # 64th byte padding for hardware sprite alignment
    return sprite_bytes


def convert_char_cell(pix, img_w, img_h, x_offset=0, y_offset=0):
    """Extract an 8x8 character cell starting at (x_offset, y_offset) into 8 bytes."""
    char_bytes = []
    for y in range(8):
        py = y_offset + y
        row_pix = pix[py] if py < img_h else [(0, 0, 0, 0)] * img_w
        byte_val = 0
        for x in range(8):
            px = x_offset + x
            c = row_pix[px] if px < img_w else (0, 0, 0, 0)
            if map_color_to_hires_bit(c[0], c[1], c[2], c[3]):
                byte_val |= (1 << (7 - x))
        char_bytes.append(byte_val)
    return char_bytes


def load_manifest(assets_dir):
    manifest_path = os.path.join(assets_dir, 'manifest.json')
    if os.path.exists(manifest_path):
        with open(manifest_path, 'r') as f:
            return json.load(f)
    return {}


def process_all_assets():
    assets_dir = 'assets'
    if not os.path.exists(assets_dir):
        print(f"Directory '{assets_dir}' not found.")
        return

    manifest = load_manifest(assets_dir)
    png_files = sorted(glob.glob(os.path.join(assets_dir, '*.png')))

    if not png_files:
        print("No PNG assets found in assets/")
        return

    all_assets_meta = []
    generated_c_code = ""
    generated_h_code = ""

    header_declarations = []
    source_definitions = []

    print(f"Found {len(png_files)} asset PNG file(s) in assets/...")

    for png_path in png_files:
        base_name = os.path.basename(png_path)
        name_no_ext = os.path.splitext(base_name)[0]
        var_name = f"g_gfx_{name_no_ext}"

        # Get metadata from manifest or defaults
        asset_config = manifest.get(base_name, {})
        asset_type = asset_config.get('type', 'sprite') # 'sprite' or 'charset'
        multicolor = asset_config.get('multicolor', True)
        frame_w = asset_config.get('frame_width', 24)
        frame_h = asset_config.get('frame_height', 21)

        w, h, pix = read_png(png_path)

        if asset_type == 'sprite':
            # Calculate sprite frames in grid
            frames_x = max(1, w // frame_w)
            frames_y = max(1, h // frame_h)
            num_frames = frames_x * frames_y

            total_bytes = num_frames * 64
            all_bytes = []

            for fy in range(frames_y):
                for fx in range(frames_x):
                    x_off = fx * frame_w
                    y_off = fy * frame_h
                    frame_bytes = convert_single_sprite_frame(pix, w, h, x_off, y_off, multicolor=multicolor)
                    all_bytes.extend(frame_bytes)

            header_declarations.append(f"// Asset: {base_name} ({num_frames} frame(s), {total_bytes} bytes)")
            header_declarations.append(f"#define {var_name.upper()}_FRAMES {num_frames}")
            header_declarations.append(f"extern const uint8_t {var_name}[{total_bytes}];\n")

            c_def = f"// Asset: {base_name} generated from {png_path}\n"
            c_def += f"const uint8_t {var_name}[{total_bytes}] = {{\n"
            for f_idx in range(num_frames):
                c_def += f"    // Frame {f_idx}\n"
                f_bytes = all_bytes[f_idx * 64 : (f_idx + 1) * 64]
                for row_idx in range(0, 64, 3):
                    chunk = f_bytes[row_idx:row_idx+3]
                    hex_str = ", ".join(f"0x{b:02X}" for b in chunk)
                    c_def += f"    {hex_str},\n"
            c_def += "};\n"
            source_definitions.append(c_def)

        elif asset_type == 'charset':
            chars_x = max(1, w // 8)
            chars_y = max(1, h // 8)
            num_chars = chars_x * chars_y
            total_bytes = num_chars * 8
            all_bytes = []

            for cy in range(chars_y):
                for cx in range(chars_x):
                    x_off = cx * 8
                    y_off = cy * 8
                    cell_bytes = convert_char_cell(pix, w, h, x_off, y_off)
                    all_bytes.extend(cell_bytes)

            header_declarations.append(f"// Charset Asset: {base_name} ({num_chars} char(s), {total_bytes} bytes)")
            header_declarations.append(f"#define {var_name.upper()}_CHARS {num_chars}")
            header_declarations.append(f"extern const uint8_t {var_name}[{total_bytes}];\n")

            c_def = f"// Charset: {base_name} generated from {png_path}\n"
            c_def += f"const uint8_t {var_name}[{total_bytes}] = {{\n"
            for c_idx in range(num_chars):
                c_def += f"    // Char {c_idx}\n    "
                c_bytes = all_bytes[c_idx * 8 : (c_idx + 1) * 8]
                hex_str = ", ".join(f"0x{b:02X}" for b in c_bytes)
                c_def += f"{hex_str},\n"
            c_def += "};\n"
            source_definitions.append(c_def)

        print(f" -> Processed {base_name} as {asset_type} ({var_name})")

    # Output unified C Header src/gfx_assets.h
    h_out = """#ifndef GFX_ASSETS_H
#define GFX_ASSETS_H

#include <stdint.h>

""" + "\n".join(header_declarations) + """
#endif // GFX_ASSETS_H
"""
    with open('src/gfx_assets.h', 'w') as f:
        f.write(h_out)

    # Output backward-compatible wrapper src/gfx_player.h
    wrapper_h = """#ifndef GFX_PLAYER_H
#define GFX_PLAYER_H

#include "gfx_assets.h"

// Alias for player nave0 sprite
#define g_player_nave0_sprite g_gfx_nave0

#endif // GFX_PLAYER_H
"""
    with open('src/gfx_player.h', 'w') as f:
        f.write(wrapper_h)

    # Output unified C Implementation src/gfx_assets.c
    c_out = """#include "gfx_assets.h"

""" + "\n".join(source_definitions)

    with open('src/gfx_assets.c', 'w') as f:
        f.write(c_out)

    print("Successfully built asset pipeline -> generated src/gfx_assets.h and src/gfx_assets.c")

if __name__ == '__main__':
    process_all_assets()

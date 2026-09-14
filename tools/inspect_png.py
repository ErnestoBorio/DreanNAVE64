"""
PNG Asset Inspection Diagnostic Tool for Drean NAVE 64.

This utility parses PNG images directly using the Python standard library
(without third-party dependencies like Pillow). It decodes chunk headers (IHDR, IDAT, IEND),
decompresses raw DEFLATE data, applies PNG scanline un-filtering (Sub, Up, Average, Paeth),
and extracts RGBA pixel matrices.

Features:
- Prints PNG dimensions, bit depth, and color type.
- Identifies and lists all unique RGBA color values present in the image.
- Renders a visual ASCII representation of the pixel grid for rapid CLI debugging
  of C64 sprite canvas bounds, fat-pixel alignment, and color palette mappings.
"""

import zlib
import struct
import sys

def read_png(path):
    with open(path, 'rb') as f:
        data = f.read()

    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError("Not a PNG file")

    offset = 8
    width, height, bit_depth, color_type = 0, 0, 0, 0
    idat_data = bytearray()

    while offset < len(data):
        length, chunk_type = struct.unpack('>I4s', data[offset:offset+8])
        chunk_data = data[offset+8:offset+8+length]
        offset += 12 + length

        if chunk_type == b'IHDR':
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack('>IIBBBBB', chunk_data)
            print(f"PNG Header: Width={width}, Height={height}, BitDepth={bit_depth}, ColorType={color_type}")
        elif chunk_type == b'IDAT':
            idat_data.extend(chunk_data)
        elif chunk_type == b'IEND':
            break

    decompressed = zlib.decompress(idat_data)
    
    # Simple unfilter for 8-bit RGBA or RGB
    bpp = 4 if color_type == 6 else (3 if color_type == 2 else 1)
    stride = width * bpp + 1
    
    pixels = []
    prev_line = [0] * (width * bpp)
    
    for y in range(height):
        line = decompressed[y * stride : (y + 1) * stride]
        filter_type = line[0]
        line_data = bytearray(line[1:])
        
        if filter_type == 1: # Sub
            for i in range(bpp, len(line_data)):
                line_data[i] = (line_data[i] + line_data[i - bpp]) & 0xFF
        elif filter_type == 2: # Up
            for i in range(len(line_data)):
                line_data[i] = (line_data[i] + prev_line[i]) & 0xFF
        elif filter_type == 3: # Average
            for i in range(len(line_data)):
                left = line_data[i - bpp] if i >= bpp else 0
                line_data[i] = (line_data[i] + ((left + prev_line[i]) // 2)) & 0xFF
        elif filter_type == 4: # Paeth
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

if __name__ == '__main__':
    w, h, pix = read_png('assets/nave0.png')
    unique_colors = set()
    for y in range(h):
        for x in range(w):
            unique_colors.add(pix[y][x])
    print(f"Unique colors ({len(unique_colors)}):")
    for c in sorted(unique_colors):
        print(" ", c)

    print("\nVisual ASCII Grid:")
    color_map = {}
    chars = ['.', '#', '*', 'O', 'X', '@']
    for idx, c in enumerate(sorted(unique_colors)):
        color_map[c] = chars[idx % len(chars)]
        
    for y in range(h):
        line_str = "".join(color_map[pix[y][x]] for x in range(w))
        print(f"{y:02d}: {line_str}")


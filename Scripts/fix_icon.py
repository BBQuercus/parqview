#!/usr/bin/env python3
from PIL import Image
import os

# Load the formatted icon
img = Image.open('icon_formatted.png')

# Convert to RGBA to ensure alpha channel
if img.mode != 'RGBA':
    img = img.convert('RGBA')

# Create iconset directory
os.makedirs('AppIcon.iconset', exist_ok=True)

# Define sizes
sizes = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

for size, scale in sizes:
    actual_size = size * scale
    resized = img.resize((actual_size, actual_size), Image.Resampling.LANCZOS)
    
    if scale == 1:
        filename = f'AppIcon.iconset/icon_{size}x{size}.png'
    else:
        filename = f'AppIcon.iconset/icon_{size}x{size}@2x.png'
    
    resized.save(filename, 'PNG')
    print(f'Created {filename}')

print('Iconset created successfully!')
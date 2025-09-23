#!/usr/bin/env python3
"""
Format icon for macOS app following Apple's design guidelines.
- Adds rounded corners (22.5% of icon size)
- Adds padding (about 10% on each side)
- Maintains transparency
"""

from PIL import Image, ImageDraw
import sys
import os

def create_rounded_rectangle_mask(size, radius):
    """Create a mask for rounded rectangle."""
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)
    
    # Draw the rounded rectangle
    draw.rounded_rectangle(
        [(0, 0), (size[0]-1, size[1]-1)],
        radius=radius,
        fill=255
    )
    
    return mask

def process_icon(input_path, output_path):
    """Process the icon to match macOS guidelines."""
    # Open the original icon
    img = Image.open(input_path).convert("RGBA")
    
    # Calculate dimensions for the padded version
    # macOS icons should have about 10% padding
    original_size = img.size[0]
    padding_percent = 0.10
    new_size = int(original_size * (1 - 2 * padding_percent))
    
    # Resize the image to account for padding
    img_resized = img.resize((new_size, new_size), Image.Resampling.LANCZOS)
    
    # Create a new image with white background
    final_img = Image.new('RGBA', (original_size, original_size), (255, 255, 255, 255))
    paste_position = int(original_size * padding_percent)
    final_img.paste(img_resized, (paste_position, paste_position), img_resized)
    
    # Apply rounded corners (22.5% of size according to macOS guidelines)
    radius = int(original_size * 0.225)
    mask = create_rounded_rectangle_mask((original_size, original_size), radius)
    
    # Create output image with rounded corners and white background
    output = Image.new('RGBA', (original_size, original_size), (0, 0, 0, 0))
    output.paste(final_img, (0, 0))
    output.putalpha(mask)
    
    # Save the result
    output.save(output_path, 'PNG')
    print(f"Processed icon saved to {output_path}")

def main():
    input_file = "icon.png"
    output_file = "icon_formatted.png"
    
    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found")
        sys.exit(1)
    
    process_icon(input_file, output_file)
    
    # Also create all the required sizes
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_32x32.png"),
        (64, "icon_64x64.png"),
        (128, "icon_128x128.png"),
        (256, "icon_256x256.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_1024x1024.png"),
    ]
    
    # Load the formatted icon
    formatted = Image.open(output_file)
    
    # Create a directory for the iconset
    iconset_dir = "AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    for size, filename in sizes:
        resized = formatted.resize((size, size), Image.Resampling.LANCZOS)
        output_path = os.path.join(iconset_dir, filename)
        resized.save(output_path, 'PNG')
        print(f"Created {output_path}")
        
        # Also create @2x versions for some sizes
        if size in [16, 32, 128, 256, 512]:
            size_2x = size * 2
            if size_2x <= 1024:
                resized_2x = formatted.resize((size_2x, size_2x), Image.Resampling.LANCZOS)
                filename_2x = filename.replace('.png', '@2x.png')
                output_path_2x = os.path.join(iconset_dir, filename_2x)
                resized_2x.save(output_path_2x, 'PNG')
                print(f"Created {output_path_2x}")

if __name__ == "__main__":
    main()
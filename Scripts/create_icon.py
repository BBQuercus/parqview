#!/usr/bin/env python3
"""
Create a simple app icon for ParqView
"""

import os
import subprocess

# Create a simple icon using iconutil
# We'll create a iconset directory with different sizes

def create_icon():
    # Create iconset directory
    iconset_dir = "AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    # Define sizes needed for macOS icons
    sizes = [
        (16, "16x16"),
        (32, "16x16@2x"),
        (32, "32x32"),
        (64, "32x32@2x"),
        (128, "128x128"),
        (256, "128x128@2x"),
        (256, "256x256"),
        (512, "256x256@2x"),
        (512, "512x512"),
        (1024, "512x512@2x"),
    ]
    
    # Create a simple icon using sips and ImageMagick (if available) or create programmatically
    try:
        # Try to use PIL if available
        from PIL import Image, ImageDraw, ImageFont
        
        for size, name in sizes:
            # Create a new image with a gradient background
            img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            draw = ImageDraw.Draw(img)
            
            # Draw a rounded rectangle background
            padding = size // 8
            draw.rounded_rectangle(
                [(padding, padding), (size - padding, size - padding)],
                radius=size // 6,
                fill=(41, 128, 185, 255),  # Nice blue color
                outline=(30, 96, 145, 255),
                width=max(1, size // 32)
            )
            
            # Add "PQ" text
            text = "PQ"
            # Try to use a font, fall back to default if not available
            try:
                font_size = size // 3
                # Default font
                draw.text(
                    (size // 2, size // 2),
                    text,
                    fill=(255, 255, 255, 255),
                    anchor="mm"
                )
            except:
                pass
            
            # Save the icon
            img.save(f"{iconset_dir}/icon_{name}.png")
            print(f"Created icon_{name}.png")
        
        # Create the icns file
        subprocess.run(["iconutil", "-c", "icns", iconset_dir], check=True)
        print("Created AppIcon.icns")
        
        # Clean up
        subprocess.run(["rm", "-rf", iconset_dir], check=True)
        
        return True
        
    except ImportError:
        print("PIL not available, creating basic icon using system tools")
        
        # Create a very basic icon using system tools
        # First create a simple PNG using base64 encoded image
        basic_icon = """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
7D8B2PH/AORfAqDWJ+pnJDoAAAAASUVORK5CYII="""
        
        import base64
        icon_data = base64.b64decode(basic_icon)
        
        # Write the PNG file
        with open("temp_icon.png", "wb") as f:
            f.write(icon_data)
        
        # Create iconset directory
        os.makedirs(iconset_dir, exist_ok=True)
        
        # Use sips to resize for different sizes
        for size, name in sizes:
            subprocess.run([
                "sips", "-z", str(size), str(size), 
                "temp_icon.png", 
                "--out", f"{iconset_dir}/icon_{name}.png"
            ], capture_output=True)
        
        # Create the icns file
        subprocess.run(["iconutil", "-c", "icns", iconset_dir], check=True)
        print("Created AppIcon.icns")
        
        # Clean up
        subprocess.run(["rm", "-rf", iconset_dir, "temp_icon.png"], check=True)
        
        return True

if __name__ == "__main__":
    try:
        if create_icon():
            print("\n✅ Successfully created AppIcon.icns")
        else:
            print("\n❌ Failed to create icon")
    except Exception as e:
        print(f"\n❌ Error creating icon: {e}")
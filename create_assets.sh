#!/bin/bash

# Create placeholder assets for DMG builder

echo "Creating assets directory..."
mkdir -p assets

# Create a simple icon using Python PIL if available
cat > create_icon.py << 'EOF'
try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    
    # Create a 1024x1024 icon
    size = 1024
    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw a rounded rectangle background
    padding = size // 10
    draw.rounded_rectangle(
        [padding, padding, size - padding, size - padding],
        radius=size // 8,
        fill=(37, 99, 235, 255)  # Blue color
    )
    
    # Add text
    try:
        # Try to use a nice font if available
        font_size = size // 6
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = None
    
    # Draw "AI" text
    text = "AI"
    if font:
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
    else:
        text_width = size // 3
        text_height = size // 3
    
    text_x = (size - text_width) // 2
    text_y = (size - text_height) // 2 - size // 10
    
    draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)
    
    # Draw "Search" text below
    text2 = "Search"
    if font:
        font2 = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size // 2)
        bbox2 = draw.textbbox((0, 0), text2, font=font2)
        text_width2 = bbox2[2] - bbox2[0]
        text_height2 = bbox2[3] - bbox2[1]
    else:
        font2 = None
        text_width2 = size // 3
        text_height2 = size // 6
    
    text_x2 = (size - text_width2) // 2
    text_y2 = text_y + text_height + size // 20
    
    draw.text((text_x2, text_y2), text2, fill=(255, 255, 255, 255), font=font2)
    
    # Save icon
    img.save('assets/icon.png', 'PNG')
    print("Created icon.png")
    
except ImportError:
    print("PIL not available. Creating simple icon with ImageMagick if available...")
    import os
    
    # Try ImageMagick
    cmd = '''convert -size 1024x1024 xc:none \
        -fill "rgb(37,99,235)" \
        -draw "roundrectangle 100,100 924,924 100,100" \
        -fill white -pointsize 200 \
        -gravity center -annotate +0-50 "AI" \
        -pointsize 100 -annotate +0+100 "Search" \
        assets/icon.png'''
    
    if os.system(cmd) != 0:
        print("Neither PIL nor ImageMagick available. Please create icon.png manually.")
EOF

# Create DMG background
cat > create_dmg_bg.py << 'EOF'
try:
    from PIL import Image, ImageDraw, ImageFont
    
    # Create a 800x400 background
    width, height = 800, 400
    img = Image.new('RGBA', (width, height), (245, 245, 245, 255))
    draw = ImageDraw.Draw(img)
    
    # Draw a gradient-like background
    for y in range(height):
        color_value = 245 - int(10 * (y / height))
        draw.line([(0, y), (width, y)], fill=(color_value, color_value, color_value, 255))
    
    # Add instruction text
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
        font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
    except:
        font = None
        font_small = None
    
    # Draw arrow
    arrow_start = (300, 200)
    arrow_end = (500, 200)
    draw.line([arrow_start, arrow_end], fill=(100, 100, 100, 255), width=3)
    # Arrow head
    draw.polygon([
        arrow_end,
        (arrow_end[0] - 10, arrow_end[1] - 10),
        (arrow_end[0] - 10, arrow_end[1] + 10)
    ], fill=(100, 100, 100, 255))
    
    # Add text
    text1 = "Drag AI Search Tool to Applications"
    draw.text((width // 2, 100), text1, 
              fill=(50, 50, 50, 255), font=font, anchor="mm")
    
    # Save background
    img.save('assets/dmg_background.png', 'PNG')
    print("Created dmg_background.png")
    
except ImportError:
    print("PIL not available. Please create dmg_background.png manually.")
EOF

# Run the Python scripts
echo "Creating icon..."
python3 create_icon.py

echo "Creating DMG background..."
python3 create_dmg_bg.py

# Clean up
rm create_icon.py create_dmg_bg.py

echo "Assets created in ./assets/"
echo "You can replace these with custom graphics if desired."
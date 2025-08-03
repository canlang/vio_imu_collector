#!/usr/bin/env python3
"""
Create a custom app icon for the Sensor Data Collector app.
This creates a 1024x1024 PNG icon suitable for app icons.
"""

from PIL import Image, ImageDraw, ImageFont
import math

def create_app_icon():
    # Create a 1024x1024 image with transparent background
    size = 1024
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Background gradient circle
    center = size // 2
    radius = size // 2 - 20
    
    # Create gradient background (more vibrant)
    for i in range(radius):
        # Enhanced gradient from bright blue to deep blue
        progress = 1 - (i / radius)
        r = int(20 + (80 * progress))
        g = int(120 + (120 * progress))
        b = int(200 + (55 * progress))
        draw.ellipse([center - i, center - i, center + i, center + i], fill=(r, g, b, 255))
    
    # Draw main circle border (thicker)
    border_width = 15
    draw.ellipse([center - radius, center - radius, center + radius, center + radius], 
                outline=(255, 255, 255, 255), width=border_width)
    
    # Draw LARGER sensor wave patterns (representing IMU data)
    wave_color = (255, 255, 255, 255)
    wave_size = 8  # Much larger wave dots
    
    # Accelerometer wave (top) - BIGGER
    for i in range(15):  # Fewer but larger points
        x = center - 200 + i * 25
        y = center - 120 + int(50 * math.sin(i * 0.4))
        draw.ellipse([x-wave_size, y-wave_size, x+wave_size, y+wave_size], fill=wave_color)
    
    # Gyroscope wave (middle) - BIGGER
    for i in range(15):
        x = center - 200 + i * 25
        y = center + int(60 * math.sin(i * 0.3 + 1))
        draw.ellipse([x-wave_size, y-wave_size, x+wave_size, y+wave_size], fill=wave_color)
    
    # Magnetometer wave (bottom) - BIGGER
    for i in range(15):
        x = center - 200 + i * 25
        y = center + 120 + int(40 * math.sin(i * 0.5 + 2))
        draw.ellipse([x-wave_size, y-wave_size, x+wave_size, y+wave_size], fill=wave_color)
    
    # Draw LARGER ARKit camera symbol (center)
    camera_size = 140  # Much bigger
    camera_x = center - camera_size // 2
    camera_y = center - camera_size // 2
    
    # Camera body (larger with rounded corners)
    draw.rounded_rectangle([camera_x, camera_y, camera_x + camera_size, camera_y + camera_size],
                          radius=20, fill=(255, 255, 255, 255), outline=(220, 220, 220), width=4)
    
    # Camera lens (much larger)
    lens_radius = 45
    draw.ellipse([center - lens_radius, center - lens_radius, 
                 center + lens_radius, center + lens_radius], 
                fill=(40, 40, 40, 255), outline=(80, 80, 80), width=4)
    
    # Lens center (larger)
    small_lens_radius = 25
    draw.ellipse([center - small_lens_radius, center - small_lens_radius, 
                 center + small_lens_radius, center + small_lens_radius], 
                fill=(80, 80, 80, 255))
    
    # Lens reflection (larger)
    reflection_radius = 15
    draw.ellipse([center - reflection_radius + 8, center - reflection_radius - 8, 
                 center + reflection_radius + 8, center + reflection_radius - 8], 
                fill=(180, 180, 180, 200))
    
    # Draw LARGER coordinate axes (representing 3D tracking)
    axis_length = 100  # Much longer
    axis_width = 12    # Much thicker
    
    # X-axis (red) - positioned better
    axis_start_x = center + 80
    axis_start_y = center + 80
    draw.line([axis_start_x, axis_start_y, axis_start_x + axis_length, axis_start_y], 
              fill=(255, 80, 80, 255), width=axis_width)
    # Arrow head for X
    draw.polygon([(axis_start_x + axis_length, axis_start_y),
                  (axis_start_x + axis_length - 20, axis_start_y - 12),
                  (axis_start_x + axis_length - 20, axis_start_y + 12)], 
                 fill=(255, 80, 80, 255))
    
    # Y-axis (green)
    draw.line([axis_start_x, axis_start_y, axis_start_x, axis_start_y - axis_length], 
              fill=(80, 255, 80, 255), width=axis_width)
    # Arrow head for Y
    draw.polygon([(axis_start_x, axis_start_y - axis_length),
                  (axis_start_x - 12, axis_start_y - axis_length + 20),
                  (axis_start_x + 12, axis_start_y - axis_length + 20)], 
                 fill=(80, 255, 80, 255))
    
    # Z-axis (blue) - diagonal to represent depth
    z_end_x = axis_start_x - int(axis_length * 0.7)
    z_end_y = axis_start_y + int(axis_length * 0.7)
    draw.line([axis_start_x, axis_start_y, z_end_x, z_end_y], 
              fill=(80, 120, 255, 255), width=axis_width)
    # Arrow head for Z
    draw.polygon([(z_end_x, z_end_y),
                  (z_end_x + 15, z_end_y - 8),
                  (z_end_x + 8, z_end_y + 15)], 
                 fill=(80, 120, 255, 255))
    
    # Add LARGER dots around the border to represent data points
    for angle in range(0, 360, 45):  # Fewer, larger dots
        rad = math.radians(angle)
        dot_x = center + int((radius - 60) * math.cos(rad))
        dot_y = center + int((radius - 60) * math.sin(rad))
        dot_size = 8
        draw.ellipse([dot_x-dot_size, dot_y-dot_size, dot_x+dot_size, dot_y+dot_size], 
                     fill=(255, 255, 255, 255))
    
    return image

def main():
    # Create the icon
    icon = create_app_icon()
    
    # Save as PNG
    icon_path = "assets/icon/app_icon.png"
    icon.save(icon_path, "PNG")
    print(f"App icon created: {icon_path}")
    
    # Also create a smaller preview
    preview = icon.resize((256, 256), Image.Resampling.LANCZOS)
    preview.save("assets/icon/app_icon_preview.png", "PNG")
    print("Preview icon created: assets/icon/app_icon_preview.png")

if __name__ == "__main__":
    main()

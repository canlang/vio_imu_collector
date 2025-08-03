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
    
    # Create gradient background
    for i in range(radius):
        # Gradient from blue to dark blue
        alpha = int(255 * (1 - i / radius))
        color = (30 + int(70 * (1 - i / radius)), 100 + int(100 * (1 - i / radius)), 200 + int(55 * (1 - i / radius)), 255)
        draw.ellipse([center - i, center - i, center + i, center + i], fill=color)
    
    # Draw main circle border
    border_width = 8
    draw.ellipse([center - radius, center - radius, center + radius, center + radius], 
                outline=(255, 255, 255, 200), width=border_width)
    
    # Draw sensor wave patterns (representing IMU data)
    wave_color = (255, 255, 255, 180)
    
    # Accelerometer wave (top)
    for i in range(20):
        x = center - 150 + i * 15
        y = center - 80 + int(30 * math.sin(i * 0.5))
        draw.ellipse([x-3, y-3, x+3, y+3], fill=wave_color)
    
    # Gyroscope wave (middle)
    for i in range(20):
        x = center - 150 + i * 15
        y = center + int(40 * math.sin(i * 0.3 + 1))
        draw.ellipse([x-3, y-3, x+3, y+3], fill=wave_color)
    
    # Magnetometer wave (bottom)
    for i in range(20):
        x = center - 150 + i * 15
        y = center + 80 + int(20 * math.sin(i * 0.7 + 2))
        draw.ellipse([x-3, y-3, x+3, y+3], fill=wave_color)
    
    # Draw ARKit camera symbol (center)
    camera_size = 80
    camera_x = center - camera_size // 2
    camera_y = center - camera_size // 2
    
    # Camera body
    draw.rounded_rectangle([camera_x, camera_y, camera_x + camera_size, camera_y + camera_size],
                          radius=10, fill=(255, 255, 255, 220))
    
    # Camera lens
    lens_radius = 25
    draw.ellipse([center - lens_radius, center - lens_radius, 
                 center + lens_radius, center + lens_radius], 
                fill=(50, 50, 50, 255))
    
    # Lens center
    small_lens_radius = 15
    draw.ellipse([center - small_lens_radius, center - small_lens_radius, 
                 center + small_lens_radius, center + small_lens_radius], 
                fill=(100, 100, 100, 255))
    
    # Lens reflection
    reflection_radius = 8
    draw.ellipse([center - reflection_radius + 5, center - reflection_radius - 5, 
                 center + reflection_radius + 5, center + reflection_radius - 5], 
                fill=(200, 200, 200, 150))
    
    # Draw corner coordinate axes (representing 3D tracking)
    axis_length = 60
    axis_width = 6
    
    # X-axis (red)
    draw.line([center + 120, center + 120, center + 120 + axis_length, center + 120], 
              fill=(255, 100, 100, 255), width=axis_width)
    
    # Y-axis (green)
    draw.line([center + 120, center + 120, center + 120, center + 120 - axis_length], 
              fill=(100, 255, 100, 255), width=axis_width)
    
    # Z-axis (blue) - diagonal to represent depth
    draw.line([center + 120, center + 120, center + 120 - 30, center + 120 + 30], 
              fill=(100, 150, 255, 255), width=axis_width)
    
    # Add small dots around the border to represent data points
    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        dot_x = center + int((radius - 40) * math.cos(rad))
        dot_y = center + int((radius - 40) * math.sin(rad))
        draw.ellipse([dot_x-4, dot_y-4, dot_x+4, dot_y+4], fill=(255, 255, 255, 150))
    
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

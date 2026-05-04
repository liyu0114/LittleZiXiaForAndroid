#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
小紫霞 Logo 生成器
从原图中提取右边的小鸟，制作 APP logo
"""

from PIL import Image, ImageDraw, ImageFilter
import os

# 输入输出路径
input_path = r"C:\Users\Administrator\.openclaw\media\inbound\1ee38221-e6b7-412a-b9d4-b8fef26f5077.jpg"
output_dir = r"D:\LittleZiXia\openclaw_app\assets"
os.makedirs(output_dir, exist_ok=True)

# 打开原图
img = Image.open(input_path)
width, height = img.size
print(f"原图尺寸: {width}x{height}")

# 右边小鸟的大致区域（需要根据实际图片调整）
# 假设小鸟在右半部分
crop_box = (width // 2, 0, width, height)
bird = img.crop(crop_box)

# 生成不同尺寸的 logo
sizes = [
    ((192, 192), "icon_192.png"),
    ((144, 144), "icon_144.png"),
    ((96, 96), "icon_96.png"),
    ((72, 72), "icon_72.png"),
    ((48, 48), "icon_48.png"),
    ((512, 512), "icon_512.png"),
]

for size, filename in sizes:
    # 调整大小
    icon = bird.resize(size, Image.Resampling.LANCZOS)
    
    # 创建圆角背景
    background = Image.new('RGBA', size, (0, 0, 0, 0))
    
    # 绘制圆角矩形背景（紫色渐变）
    draw = ImageDraw.Draw(background)
    corner_radius = size[0] // 5
    
    # 紫色背景
    draw.rounded_rectangle(
        [0, 0, size[0]-1, size[1]-1],
        radius=corner_radius,
        fill=(147, 112, 219, 255)  # 中紫色
    )
    
    # 将小鸟图片转换为 RGBA 并叠加
    icon_rgba = icon.convert('RGBA')
    
    # 合成
    result = Image.alpha_composite(background, icon_rgba)
    
    # 保存
    output_path = os.path.join(output_dir, filename)
    result.save(output_path, 'PNG')
    print(f"已生成: {output_path}")

# 生成主 logo（带紫色边框）
main_size = (512, 512)
icon = bird.resize(main_size, Image.Resampling.LANCZOS)
icon_rgba = icon.convert('RGBA')

# 创建带渐变的背景
background = Image.new('RGBA', main_size, (0, 0, 0, 0))
draw = ImageDraw.Draw(background)

# 绘制圆角背景
draw.rounded_rectangle(
    [0, 0, main_size[0]-1, main_size[1]-1],
    radius=main_size[0] // 5,
    fill=(138, 43, 226, 255)  # 蓝紫色
)

# 合成
logo = Image.alpha_composite(background, icon_rgba)
logo_path = os.path.join(output_dir, "logo.png")
logo.save(logo_path, 'PNG')
print(f"主 Logo: {logo_path}")

# 生成简单版本（圆形裁剪）
mask = Image.new('L', main_size, 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.ellipse([20, 20, main_size[0]-20, main_size[1]-20], fill=255)

# 应用圆形遮罩
circular = Image.new('RGBA', main_size, (0, 0, 0, 0))
circular.paste(icon_rgba, mask=mask)
circular_path = os.path.join(output_dir, "logo_circular.png")
circular.save(circular_path, 'PNG')
print(f"圆形 Logo: {circular_path}")

print("\n✅ Logo 生成完成！")
print(f"输出目录: {output_dir}")

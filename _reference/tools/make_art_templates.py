#!/usr/bin/env python3
"""生成美术用的「可画范围」模板图（10 倍放大，直接当参考图层）。

产出（存在则跳过，--force 覆盖）：
  _reference/art_templates/player_guide_10x.png   主角：28x38 画布 + 脚底线
  _reference/art_templates/echo_guide_10x.png     虚影：28x38 画布 + 头顶 28x8 可踩薄片

为什么是 10 倍：28x38 的 1 倍图在 PS/Aseprite 里太小，看不清 2px 安全区。
10 倍图（280x380）里 1 游戏像素 = 10 图像像素，画完整体缩小 10 倍导出即可。
图上的字只是给你看的参考图层内容，导出前隐藏即可。
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "_reference" / "art_templates"
S = 10                      # 放大倍数
W, H = 28, 38               # 设计尺寸（= 碰撞框）
FONT = "C:/Windows/Fonts/msyh.ttc"

RED = (230, 70, 70, 255)        # 碰撞框（主角）
TEAL = (60, 190, 150, 255)      # 薄片（虚影）
ORANGE = (255, 138, 61, 255)    # 接触线
CYAN = (80, 170, 220, 255)      # 安全区
GRID = (255, 255, 255, 20)      # 网格（很淡）
LABEL = (255, 255, 255, 240)


def font(size: int):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def base_canvas(border_color) -> tuple:
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # 每 5 游戏像素一条网格（10 倍下 = 50px）
    for x in range(5, W, 5):
        d.line([(x * S, 0), (x * S, H * S)], fill=GRID, width=1)
    for y in range(5, H, 5):
        d.line([(0, y * S), (W * S, y * S)], fill=GRID, width=1)

    # 画布边界 = 碰撞框
    d.rectangle([1, 1, W * S - 2, H * S - 2], outline=border_color, width=3)
    # 2px 安全区内缩
    m = 2 * S
    d.rectangle([m, m, W * S - 1 - m, H * S - 1 - m], outline=CYAN, width=1)
    # 垂直中线
    d.line([(W * S // 2, 0), (W * S // 2, H * S)], fill=(255, 255, 255, 32), width=1)
    return img, d


def chip(d, xy, text, color, size=15):
    """给文字加一块深色底：模板图是透明底，纯白字在画图软件里会看不见。"""
    f = font(size)
    pad = 4
    box = d.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    x, y = xy
    d.rounded_rectangle([x, y, x + w + pad * 2, y + h + pad * 2], radius=4,
                        fill=(12, 16, 22, 210))
    d.text((x + pad, y + pad - box[1]), text, font=f, fill=color)


def player_template() -> Image.Image:
    img, d = base_canvas(RED)
    y = H * S - 4
    d.line([(2, y), (W * S - 3, y)], fill=ORANGE, width=4)
    for x in (2, W * S - 3):
        d.line([(x, y - 9), (x, y + 3)], fill=ORANGE, width=3)

    chip(d, (8, 8), "28x38 画布", LABEL)
    chip(d, (8, y - 34), "脚底线", ORANGE)
    return img


def echo_template() -> Image.Image:
    img, d = base_canvas(TEAL)
    band = 8 * S
    overlay = Image.new("RGBA", (W * S, band), (60, 190, 150, 48))
    img.alpha_composite(overlay, (0, 0))
    d.line([(2, 3), (W * S - 3, 3)], fill=ORANGE, width=4)
    # 薄片下沿虚线
    x = 0
    while x < W * S:
        d.line([(x, band), (min(x + 7, W * S - 1), band)], fill=TEAL, width=2)
        x += 14

    chip(d, (8, 12), "可踩 28x8", LABEL)
    chip(d, (8, band + 10), "下面没有碰撞", TEAL, 13)
    return img


def main() -> None:
    force = "--force" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = {
        "player_guide_10x.png": player_template,
        "echo_guide_10x.png": echo_template,
    }
    for name, fn in jobs.items():
        path = OUT / name
        if path.exists() and not force:
            print(f"skip  {path.relative_to(ROOT)}（已存在，--force 覆盖）")
            continue
        fn().save(path)
        print(f"write {path.relative_to(ROOT)}  {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()

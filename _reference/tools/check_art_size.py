#!/usr/bin/env python3
"""校验 assets/ 下的贴图尺寸是否还在规格内（美术交图后跑一遍）。

用法:
    python _reference/tools/check_art_size.py

规则分四类（详细说明见 README「3.4 角色可画范围」）：
  actor  主角。Sprite 按**原尺寸 1:1** 绘制（只再乘「碰撞体 / design_size」），
         所以画布必须正好 28x38：画成 56x76 就会显示成两倍大。
  echo   虚影。会被缩放到 body_size（默认 28x38），**任意尺寸都能用**；
         只是比例不是 14:19 时会被拉歪（提示，不算错）。
  block  物块。九宫格源图，**尺寸必须完全一致**，否则四边固定的像素宽度会错。
  ui     按钮/图标。按 1:1 像素摆放，尺寸必须一致。

退出码：0 全部通过；1 有不可接受的问题。
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

# 路径 -> (宽, 高, 类别)
SPEC = {
    "assets/actors/player.png": (28, 38, "actor"),
    "assets/actors/player_death_cross.png": (28, 38, "actor"),
    "assets/echo/echo_body.png": (28, 38, "echo"),
    "assets/echo/echo_cross.png": (28, 38, "echo"),
    "assets/blocks/solid_ground.png": (32, 32, "block"),
    "assets/blocks/solid_wall.png": (32, 32, "block"),
    "assets/blocks/plate_off.png": (8, 8, "block"),
    "assets/blocks/door.png": (8, 8, "block"),
    "assets/blocks/exit.png": (16, 16, "block"),
    "assets/blocks/spike_tile.png": (20, 20, "block"),
    "assets/ui/continue_normal.png": (92, 92, "ui"),
    "assets/ui/continue_hover.png": (92, 92, "ui"),
    "assets/ui/continue_pressed.png": (92, 92, "ui"),
}

OK = "\033[32mOK  \033[0m"
WARN = "\033[33mWARN\033[0m"
BAD = "\033[31mBAD \033[0m"


def main() -> int:
    problems = 0
    warns = 0
    for rel, (ew, eh, kind) in SPEC.items():
        path = ROOT / rel
        if not path.exists():
            print(f"{BAD} {rel:42s} 文件不存在（少了这张图游戏会报错）")
            problems += 1
            continue
        w, h = Image.open(path).size
        if (w, h) == (ew, eh):
            print(f"{OK} {rel:42s} {w}x{h}")
            continue
        if kind == "echo":
            # 虚影按 body_size 缩放，尺寸本身不影响玩法；只有比例歪了才提示
            same_ratio = abs(w / h - ew / eh) < 0.01
            if same_ratio:
                print(f"{WARN} {rel:42s} {w}x{h}（等比，会被缩放到 {ew}x{eh}，能用）")
            else:
                print(f"{WARN} {rel:42s} {w}x{h}（比例和 {ew}x{eh} 不同，缩放后会被拉歪）")
            warns += 1
        elif kind == "actor":
            # 主角是 1:1 绘制，尺寸不对就会显示成「几倍大的角色」，不会被自动缩回去
            kx, ky = w / ew, h / eh
            if abs(kx - ky) < 0.01:
                detail = f"会显示成 {kx:.2f} 倍大小"
            else:
                detail = f"x 方向 {kx:.2f} 倍、y 方向 {ky:.2f} 倍（比例被拉歪）"
            print(f"{BAD} {rel:42s} {w}x{h}（规格 {ew}x{eh}，{detail}）")
            print(f"       画布必须正好 {ew}x{eh}；要画大图只能同时改 player.gd 的 design_size")
            problems += 1
        else:
            why = "九宫格边距会错" if kind == "block" else "1:1 摆放会错位"
            print(f"{BAD} {rel:42s} {w}x{h}（规格 {ew}x{eh}，{why}）")
            problems += 1

    # 规格外的图只提示，不算错（可能是新增素材还没登记）
    known = set(SPEC)
    for p in sorted((ROOT / "assets").rglob("*.png")):
        rel = p.relative_to(ROOT).as_posix()
        if rel not in known:
            print(f"{WARN} {rel:42s} {Image.open(p).size}（未登记规格）")
            warns += 1

    print(f"\n结果：{problems} 个必须修，{warns} 个提示")
    if problems:
        print("改法见 README「3.4 角色可画范围」；角色画布必须正好 28x38，物块必须像素级一致。")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

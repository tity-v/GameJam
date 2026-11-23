"""导入网页批量包。默认生成独立场景，--install 显式安装章节槽位。"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("output", help="项目内新的 res://scenes/levels/子目录")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--install", action="store_true", help="备份并更新 catalog.tres 中对应章节槽位")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    if not args.output.startswith("res://scenes/levels/"):
        parser.error("输出应为项目内新的 res://scenes/levels/子目录")
    target = (project / args.output[6:]).resolve()
    if not target.is_relative_to(project / "scenes" / "levels") or target.exists():
        parser.error("输出目录已存在或不在 scenes/levels 内，请指定新的目录")
    if args.bundle.stat().st_size > 128 * 1024**2:
        parser.error("包超过 128 MB")
    bundle = json.loads(args.bundle.read_text(encoding="utf-8-sig"))
    if bundle.get("format") != "past-self-library" or bundle.get("version") != 1:
        parser.error("需要本地工作台导出的批量包或整章包 JSON")
    entries = bundle.get("levels")
    chapters = bundle.get("chapters", [])
    if not isinstance(entries, list) or not 1 <= len(entries) <= 200:
        parser.error("关卡数量须在 1 至 200 之间")
    ids = set()
    for entry in entries:
        ident = entry.get("id")
        body = entry.get("body")
        if not isinstance(ident, str) or not ident or ident in ids or not isinstance(body, dict):
            parser.error("关卡 ID 或正文无效")
        ids.add(ident)
        if body.get("version") not in (1, 2) or not isinstance(body.get("components"), list):
            parser.error("关卡地图格式无效")
        size = body.get("map", {})
        if any(type(size.get(k)) is not int or not 1 <= size[k] <= 128 for k in ("columns", "rows")):
            parser.error("地图行列无效")
        if int(body.get("chapter") or 0) not in range(5):
            parser.error("章号须在 1 至 4 之间，或留空使用通用风格")
    placements = {}
    numbers = set()
    for chapter in chapters:
        number = chapter.get("number")
        rooms = chapter.get("rooms")
        if type(number) is not int or not 1 <= number <= 4 or number in numbers or not isinstance(rooms, list) or len(rooms) != 5:
            parser.error("章号须唯一且为 1–4，每章五间")
        numbers.add(number)
        for order, room in enumerate(rooms):
            ident = room.get("id")
            if ident not in ids or ident in placements or room.get("direction") not in ("left", "right", "up", "down"):
                parser.error("章节引用缺失、重复或方向无效")
            placements[ident] = (number, order, room)
    if args.install and not chapters:
        parser.error("--install 需要包中包含章节编排")
    # 所有输出先进入新建暂存目录。整个批次成功后再移至目标。
    levels_dir = project / "scenes" / "levels"
    stage = Path(tempfile.mkdtemp(prefix="web-stage-", dir=levels_dir))
    try:
        manifest = {"chapters": [], "levels": []}
        filenames = {}
        for index, entry in enumerate(entries):
            ident = entry["id"]
            body = dict(entry["body"])
            body["levelId"] = ident
            if ident in placements:
                number, order, slot = placements[ident]
                body.update(chapter=number, exitDirection=slot["direction"])
                filename = f"chapter_{number:02d}_room_{order+1:02d}.tscn"
            else:
                filename = f"room_{index+1:03d}.tscn"
            filenames[ident] = filename
            source = stage / "source.json"
            source.write_text(json.dumps(body, ensure_ascii=False), encoding="utf-8")
            output = stage / filename
            res_path = "res://" + output.relative_to(project).as_posix()
            command = [args.godot, "--headless", "--path", str(project), "--log-file", str(stage / "import.log"),
                       "--script", "res://graybox/import_web_map.gd", "--", str(source), res_path]
            subprocess.run(command, check=True, timeout=120)
            if not output.exists():
                raise RuntimeError(f"没有生成 {filename}")
            manifest["levels"].append({"id": ident, "scene": args.output.rstrip("/") + "/" + filename,
                                       "title": body.get("name", filename), "chapter": body.get("chapter", 0)})
        for chapter in chapters:
            manifest["chapters"].append({
                "number": chapter["number"],
                "rooms": [{"id": room["id"], "title": room.get("title") or next(
                    e["body"]["name"] for e in entries if e["id"] == room["id"]),
                    "direction": room["direction"], "scene": args.output.rstrip("/") + "/" + filenames[room["id"]]}
                    for room in chapter["rooms"]]
            })
        (stage / "source.json").unlink(missing_ok=True)
        (stage / "import.log").unlink(missing_ok=True)
        (stage / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
        target.parent.mkdir(parents=True, exist_ok=True)
        stage.rename(target)
        if args.install:
            subprocess.run([args.godot, "--headless", "--path", str(project),
                            "--script", "res://graybox/install_web_catalog.gd", "--", str(target / "manifest.json")],
                           check=True, timeout=120)
        print(f"已生成 {len(entries)} 间、{len(chapters)} 章 → {target}")
        if chapters and not args.install:
            print("章节槽位尚未更新，可加 --install 并使用新的输出目录再次导入。")
    finally:
        if stage.exists():
            shutil.rmtree(stage)


if __name__ == "__main__":
    main()

#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""生成音效候选试听页（离线、点击即播、不需要联网）。

用法:
    python _reference/tools/make_audio_preview.py --src <原始素材目录>
    python _reference/tools/make_audio_preview.py --src <原始素材目录> --out _reference/audio_preview

原始素材目录约定三个子目录:
    yd/      yd-Sounds 包解压结果（ogg）
    moxie/   8-bit Platformer SFX 解压结果（wav）
    macro/   Jump 1/2/3（wav）

只做两件事: 把音频平铺复制到输出目录 + 生成 index.html。
音频用相对路径引用，因此 HTML 和音频必须在同一目录。
"""
import argparse
import base64
import struct
import wave
from pathlib import Path

# ---------------------------------------------------------------- 元数据
# group: 试听页分组标题
# 每条 (源文件相对名, 平铺后的文件名, 中文名, 一句话说明, 风险等级)
# 风险等级: ok=作者自证可放心用 / warn=CC0 声明清晰但授权链不可追溯 / risk=存疑
SOURCES = {
    "yd": {
        "label": "yd · Platformer Sounds",
        "url": "https://opengameart.org/content/platformer-sounds-terminal-interaction-door-shots-bang-and-footsteps",
        "license": "CC0（上传者自述，部分由 Freesound CC0 拼装，逐条不可追溯）",
        "risk": "warn",
    },
    "moxie": {
        "label": "MoxieCat · 8-bit Platformer SFX",
        "url": "https://opengameart.org/content/8-bit-platformer-sfx-0",
        "license": "CC0（附 FamiTracker 源工程，可自证为本人制作）",
        "risk": "ok",
    },
    "macro": {
        "label": "Macro · Jump Landing",
        "url": "https://opengameart.org/content/jump-landing",
        "license": "CC0（标注存疑：同作者的 Cat SFX 标 CC-BY 3.0）",
        "risk": "risk",
    },
}

GROUPS = [
    ("jump", "跳跃", "整局最高频的音，只挑一条。听「起跳瞬间是否干脆」"),
    ("land", "落地", "需要比跳跃闷、比跳跃轻，否则会盖住跳跃"),
    ("death", "死亡", "要明显区别于受击，玩家得立刻知道「这条命没了」"),
    ("revive", "复活 / 传送", "虚影生成、玩家归位都走这条"),
    ("plate", "压力板", "按下 / 弹起用同一条，弹起把 pitch_scale 拨到 1.35"),
    ("door", "滑门", "开门轻、关门重。示例房间的门 160px 高，关门声要有「砸下来」的重量"),
    ("step", "脚步", "只在玩家跑动时 Loop；停下必须立刻停"),
    ("ui", "界面", "菜单点击、翻页、暂停。音量要比游戏内低 6dB"),
    ("extra", "备选库（本作暂时用不上）", "留着备查，不接入"),
]

ITEMS = [
    # ---- 跳跃
    ("moxie", "jump_1.wav", "moxie_jump_1.wav", "jump", "MoxieCat · jump_1", "8-bit 方波，0.29s，极干脆"),
    ("macro", "Jump1.wav", "macro_jump1.wav", "jump", "Macro · Jump 1", "写实起跳，带气声"),
    ("macro", "Jump2.wav", "macro_jump2.wav", "jump", "Macro · Jump 2", "同上，音高略低"),
    ("macro", "Jump3.wav", "macro_jump3.wav", "jump", "Macro · Jump 3", "同上，尾巴更长"),
    # ---- 落地
    ("yd", "landing.ogg", "yd_landing.ogg", "land", "yd · landing", "闷响落地，最贴「地砖」设定"),
    ("moxie", "spring.wav", "moxie_spring.wav", "land", "MoxieCat · spring", "弹跳感，偏卡通，作对照"),
    # ---- 死亡
    ("moxie", "playerhurt.wav", "moxie_playerhurt.wav", "death", "MoxieCat · playerhurt", "8-bit 受击，0.50s"),
    ("moxie", "warlockhurt.wav", "moxie_warlockhurt.wav", "death", "MoxieCat · warlockhurt", "2.82s，偏魔法，做死亡可能太长"),
    # ---- 复活
    ("yd", "beep_message.ogg", "yd_beep_message.ogg", "revive", "yd · beep_message", "终端打字声，像「数据回灌」"),
    ("moxie", "lift.wav", "moxie_lift.wav", "revive", "MoxieCat · lift", "上升音，0.41s"),
    ("moxie", "warlockexploding.wav", "moxie_warlockexploding.wav", "revive", "MoxieCat · warlockexploding", "爆散，适合虚影生成"),
    # ---- 压力板
    ("moxie", "button.wav", "moxie_button.wav", "plate", "MoxieCat · button", "咔哒 0.29s，做按下"),
    ("moxie", "trapdoor.wav", "moxie_trapdoor.wav", "plate", "MoxieCat · trapdoor", "翻板 0.94s，偏机关，可做关门"),
    # ---- 门
    ("yd", "door_open.ogg", "yd_door_open.ogg", "door", "yd · door_open", "滑门轨道音，唯一有「滑」感的"),
    ("yd", "cogs.ogg", "yd_cogs.ogg", "door", "yd · cogs", "齿轮，机械感备选"),
    ("moxie", "trapdoor.wav", "moxie_trapdoor2.wav", "door", "MoxieCat · trapdoor（同压力板）", "做关门，和压力板冲突要挑一个"),
    # ---- 脚步
    ("yd", "steps_platform.ogg", "yd_steps_platform.ogg", "step", "yd · steps_platform", "瓷砖脚步"),
    ("yd", "steps_platform2.ogg", "yd_steps_platform2.ogg", "step", "yd · steps_platform2", "同上，另一版"),
    ("yd", "steps_stairs.ogg", "yd_steps_stairs.ogg", "step", "yd · steps_stairs", "楼梯脚步"),
    ("yd", "steps_stairs1.ogg", "yd_steps_stairs1.ogg", "step", "yd · steps_stairs1", "同上，另一版"),
    ("yd", "steps_chain.ogg", "yd_steps_chain.ogg", "step", "yd · steps_chain", "金属平台脚步"),
    # ---- UI
    ("moxie", "button.wav", "moxie_button2.wav", "ui", "MoxieCat · button（同压力板）", "做菜单点击，音量压 6dB"),
    ("moxie", "dashwoosh.wav", "moxie_dashwoosh.wav", "ui", "MoxieCat · dashwoosh", "翻页 whoosh"),
    ("moxie", "throw.wav", "moxie_throw.wav", "ui", "MoxieCat · throw", "轻抛，做取消 / 返回"),
    # ---- 备选
    ("yd", "boxopen.ogg", "yd_boxopen.ogg", "extra", "yd · boxopen", "开箱"),
    ("yd", "explode.ogg", "yd_explode.ogg", "extra", "yd · explode", "爆炸"),
    ("yd", "kill_shoot.ogg", "yd_kill_shoot.ogg", "extra", "yd · kill_shoot", "射击"),
    ("moxie", "dashcharge.wav", "moxie_dashcharge.wav", "extra", "MoxieCat · dashcharge", "蓄力 3.36s"),
    ("moxie", "lightningcharge.wav", "moxie_lightningcharge.wav", "extra", "MoxieCat · lightningcharge", "蓄电 3.36s"),
    ("moxie", "lightningstrike.wav", "moxie_lightningstrike.wav", "extra", "MoxieCat · lightningstrike", "落雷 4.42s"),
    ("moxie", "warlockfalling.wav", "moxie_warlockfalling.wav", "extra", "MoxieCat · warlockfalling", "下坠"),
    ("moxie", "warlocklaugh1.wav", "moxie_warlocklaugh1.wav", "extra", "MoxieCat · warlocklaugh1", "笑"),
    ("moxie", "warlocklaugh2.wav", "moxie_warlocklaugh2.wav", "extra", "MoxieCat · warlocklaugh2", "笑"),
]


def wav_duration(path: Path) -> float:
    with wave.open(str(path)) as w:
        return w.getnframes() / float(w.getframerate())


def ogg_duration(path: Path) -> float:
    """读 vorbis identification header 的采样率 + 最后一页的 granule position。"""
    data = path.read_bytes()
    idx = data.find(b"\x01vorbis")
    if idx < 0:
        return 0.0
    rate = struct.unpack("<I", data[idx + 11:idx + 15])[0]
    if not rate:
        return 0.0
    last = data.rfind(b"OggS")
    if last < 0 or last + 14 > len(data):
        return 0.0
    granule = struct.unpack("<q", data[last + 6:last + 14])[0]
    return granule / float(rate)


def duration(path: Path) -> float:
    try:
        if path.suffix.lower() == ".wav":
            return wav_duration(path)
        if path.suffix.lower() == ".ogg":
            return ogg_duration(path)
    except Exception:
        pass
    return 0.0


RISK_TEXT = {
    "ok": "零疑点",
    "warn": "授权链不可追溯",
    "risk": "存疑",
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="原始素材目录（含 yd/ moxie/ macro/ 子目录）")
    ap.add_argument("--out", default="_reference/audio_preview", help="输出目录")
    ap.add_argument("--zip", default="", help="可选：同时打成一个可直接发给别人的 zip")
    args = ap.parse_args()

    src = Path(args.src)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    # 清掉上一次生成的音频，避免改名后留垃圾（只删本脚本管理的前缀）
    for old in out.iterdir():
        if old.is_file() and old.suffix.lower() in (".wav", ".ogg") and "_" in old.name:
            old.unlink()

    rows = []
    for pack, rel, flat, group, name, note in ITEMS:
        sp = src / pack / rel
        if not sp.exists():
            print("MISS", sp)
            continue
        dst = out / flat
        dst.write_bytes(sp.read_bytes())
        rows.append({
            "file": flat,
            "group": group,
            "name": name,
            "note": note,
            "pack": pack,
            "dur": duration(dst),
            "risk": SOURCES[pack]["risk"],
        })

    html = render(rows)
    (out / "index.html").write_text(html, encoding="utf-8")
    total = sum((out / r["file"]).stat().st_size for r in rows)
    print("OK rows=%d  bytes=%d  ->  %s" % (len(rows), total, out / "index.html"))

    if args.zip:
        pack_zip(out, Path(args.zip), total)


HOWTO = """音效候选试听台 —— 打开方式

1. 解压这个文件夹，双击 audio-preview/index.html，用 Chrome 或 Edge 打开。
   音频就在同一个文件夹里，不联网、不下载、不装任何东西。

2. 点一行就播放，空格暂停，上下方向键换行，回车播放。

3. 双击后点行没声音？换 Chrome 打开（右键 index.html -> 打开方式）。
   还不行就是被挪动了位置：index.html 和那些 .wav/.ogg 必须在同一个文件夹里。

标签含义
  绿  零疑点          作者能自证是自己做的（MoxieCat，附了源工程）
  黄  授权链不可追溯  CC0 声明清楚，但自述拼装自多个来源（yd）
  橙  存疑            同作者另一个包标的是 CC-BY 3.0（Macro）

还需要挑的：跳跃、落地、死亡、复活 四条。其余槽位已按推荐方案配好。
"""


def pack_zip(out: Path, zip_path: Path, total: int) -> None:
    import zipfile

    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("audio-preview/HOWTO.txt", HOWTO.encode("utf-8"))
        for f in sorted(out.iterdir()):
            if f.is_file():
                z.write(f, "audio-preview/" + f.name)
    size = zip_path.stat().st_size
    print("ZIP %s  %.2f MB（原 %d MB，压缩率 %.0f%%）"
          % (zip_path, size / 1048576, total // 1048576, (1 - size / max(total, 1)) * 100))


def render(rows) -> str:
    body_groups = []
    for gid, title, hint in GROUPS:
        items = [r for r in rows if r["group"] == gid]
        if not items:
            continue
        cards = "\n".join(card(r) for r in items)
        body_groups.append(
            f'<section><h2>{title}<span>{hint}</span></h2><div class="list">{cards}</div></section>'
        )

    return (
        HTML_HEAD
        + '<div class="wrap">'
        + HEADER
        + '<div class="toolbar">'
        + '<label>总音量<input id="vol" type="range" min="0" max="100" value="85"></label>'
        + '<label class="chk"><input id="loop" type="checkbox"> 循环当前</label>'
        + '<button id="stop" class="ghost">全部停止</button>'
        + '<span class="tip">空格 播放/暂停 · ↑↓ 切换 · 回车 播放</span>'
        + "</div>"
        + "\n".join(body_groups)
        + FOOTER
        + '</div><audio id="player"></audio>'
        + HTML_SCRIPT
    )


def card(r) -> str:
    dur = f'{r["dur"]:.2f}s' if r["dur"] else "—"
    return (
        f'<div class="row" data-src="{r["file"]}" tabindex="0">'
        f'<button class="play" aria-label="播放"><span class="ico">▶</span></button>'
        f'<div class="meta"><b>{r["name"]}</b><em>{r["note"]}</em></div>'
        f'<span class="dur">{dur}</span>'
        f'<span class="risk {r["risk"]}">{RISK_TEXT[r["risk"]]}</span>'
        f'<div class="bar"><i></i></div>'
        f"</div>"
    )


HTML_HEAD = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>音效候选试听台</title>
<style>
:root{
  --bg:#0e1219; --panel:#161d2a; --panel2:#1b2434; --line:#26303f;
  --text:#e6ecf5; --dim:#8b98ad; --amber:#e0a944; --mint:#6fcf97;
  --warn:#d9b04a; --risk:#e08a5a; --blue:#5b9bd5;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);
  font:14px/1.6 "PingFang SC","Microsoft YaHei",-apple-system,system-ui,sans-serif;
  -webkit-font-smoothing:antialiased}
.wrap{max-width:900px;margin:0 auto;padding:36px 24px 80px}
header h1{margin:0 0 6px;font-size:23px;font-weight:600;letter-spacing:.02em}
header p{margin:0;color:var(--dim);font-size:13px}
.legend{display:flex;gap:16px;flex-wrap:wrap;margin:16px 0 0;font-size:12px;color:var(--dim)}
.legend i{display:inline-block;width:7px;height:7px;border-radius:50%;margin-right:6px;vertical-align:1px}
.toolbar{display:flex;align-items:center;gap:18px;flex-wrap:wrap;
  margin:22px 0 6px;padding:12px 16px;background:var(--panel);border:1px solid var(--line);border-radius:10px;
  position:sticky;top:12px;z-index:9;backdrop-filter:blur(6px)}
.toolbar label{display:flex;align-items:center;gap:8px;color:var(--dim);font-size:12px}
.toolbar input[type=range]{width:110px;accent-color:var(--amber)}
.toolbar input[type=checkbox]{accent-color:var(--amber)}
.toolbar .chk{cursor:pointer}
button.ghost{background:transparent;color:var(--dim);border:1px solid var(--line);
  border-radius:6px;padding:4px 12px;font-size:12px;cursor:pointer;font-family:inherit}
button.ghost:hover{color:var(--text);border-color:#3a4859}
.toolbar .tip{margin-left:auto;color:#5d6a7d;font-size:11px}
section{margin-top:34px}
section h2{display:flex;align-items:baseline;gap:12px;margin:0 0 10px;
  font-size:15px;font-weight:600;color:var(--amber);letter-spacing:.03em}
section h2 span{font-size:12px;font-weight:400;color:#5d6a7d}
.list{display:flex;flex-direction:column;gap:6px}
.row{position:relative;display:flex;align-items:center;gap:14px;
  padding:11px 16px;background:var(--panel);border:1px solid var(--line);border-radius:9px;
  cursor:pointer;overflow:hidden;transition:border-color .15s,background .15s}
.row:hover{background:var(--panel2);border-color:#33414f}
.row:focus{outline:none;border-color:var(--amber)}
.row.on{background:var(--panel2);border-color:var(--amber)}
.play{flex:0 0 30px;height:30px;border-radius:50%;border:1px solid var(--line);
  background:#121a26;color:var(--dim);cursor:pointer;font-size:11px;line-height:1;
  display:flex;align-items:center;justify-content:center;transition:.15s}
.row:hover .play,.row.on .play{border-color:var(--amber);color:var(--amber)}
.meta{flex:1;min-width:0}
.meta b{display:block;font-weight:500;font-size:13.5px}
.meta em{display:block;font-style:normal;color:var(--dim);font-size:12px;
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.dur{flex:0 0 auto;color:#5d6a7d;font-size:12px;font-variant-numeric:tabular-nums;min-width:46px;text-align:right}
.risk{flex:0 0 auto;font-size:11px;padding:2px 9px;border-radius:20px;border:1px solid;white-space:nowrap}
.risk.ok{color:var(--mint);border-color:rgba(111,207,151,.35);background:rgba(111,207,151,.08)}
.risk.warn{color:var(--warn);border-color:rgba(217,176,74,.35);background:rgba(217,176,74,.08)}
.risk.risk{color:var(--risk);border-color:rgba(224,138,90,.4);background:rgba(224,138,90,.1)}
.bar{position:absolute;left:0;bottom:0;height:2px;width:100%;background:transparent}
.bar i{display:block;height:100%;width:0;background:var(--amber);transition:width .05s linear}
footer{margin-top:44px;padding-top:20px;border-top:1px solid var(--line);color:#5d6a7d;font-size:12px}
footer b{color:var(--dim);font-weight:500}
footer ul{margin:8px 0 0;padding-left:18px}
footer li{margin:3px 0}
</style></head><body>"""

HEADER = """
<header>
  <h1>音效候选试听台</h1>
  <p>31 条候选 · 来自 3 个 CC0 来源包 · 点击即播，音频就在本目录里，断网也能听</p>
  <div class="legend">
    <span><i style="background:#6fcf97"></i>零疑点：作者能自证</span>
    <span><i style="background:#d9b04a"></i>授权链不可追溯：CC0 声明清晰但拼装自多源</span>
    <span><i style="background:#e08a5a"></i>存疑：同作者其它包标了 CC-BY</span>
  </div>
</header>
"""

FOOTER = """
<footer>
<b>还差什么</b>
<ul>
  <li>Kenney 三个包（Impact / UI / Interface）<b>本机下载被拦</b>（官网直连 403），需要你在浏览器里手动听一下再定。</li>
  <li>这份清单里没有「办公室底噪」「虚影走动」——原始包里没有合适的，需要另找或不做。</li>
  <li>选定后我会把原件按 <code>assets/audio/sfx/</code> 规则改名入库，并写 <code>LICENSE.md</code> 记录来源。</li>
</ul>
</footer>
"""

HTML_SCRIPT = """
<script>
(function(){
  var player = document.getElementById('player');
  var vol = document.getElementById('vol');
  var loop = document.getElementById('loop');
  var rows = Array.prototype.slice.call(document.querySelectorAll('.row'));
  var cur = -1, idx = 0;
  player.volume = vol.value / 100;

  function playRow(i){
    var row = rows[i];
    if(!row) return;
    rows.forEach(function(r){ r.classList.remove('on'); r.querySelector('.ico').textContent = '▶'; });
    if(cur === i && !player.paused){ player.pause(); return; }
    cur = i; idx = i;
    row.classList.add('on');
    if(player.getAttribute('src') !== row.dataset.src){
      player.setAttribute('src', row.dataset.src);
    }
    player.loop = loop.checked;
    row.querySelector('.ico').textContent = '❚❚';
    player.currentTime = 0;
    var p = player.play();
    if(p && p.catch){ p.catch(function(){ row.querySelector('.ico').textContent = '▶'; }); }
  }

  rows.forEach(function(row,i){
    row.addEventListener('click', function(e){
      if(e.target.classList.contains('play') || e.target.classList.contains('ico')) return;
      playRow(i);
    });
    row.querySelector('.play').addEventListener('click', function(e){ e.stopPropagation(); playRow(i); });
    row.addEventListener('focus', function(){ idx = i; });
  });

  player.addEventListener('timeupdate', function(){
    var row = rows[cur]; if(!row) return;
    var d = player.duration;
    if(!d || !isFinite(d)) return;
    row.querySelector('.bar i').style.width = (player.currentTime / d * 100) + '%';
  });
  player.addEventListener('ended', function(){
    if(!rows[cur]) return;
    rows[cur].querySelector('.bar i').style.width = '0';
    rows[cur].querySelector('.ico').textContent = '▶';
  });

  vol.addEventListener('input', function(){ player.volume = vol.value / 100; });
  loop.addEventListener('change', function(){ player.loop = loop.checked; });
  document.getElementById('stop').addEventListener('click', function(){
    player.pause();
    rows.forEach(function(r){ r.classList.remove('on'); r.querySelector('.ico').textContent='▶'; r.querySelector('.bar i').style.width='0'; });
  });

  document.addEventListener('keydown', function(e){
    if(e.target.tagName === 'INPUT') return;
    if(e.code === 'Space'){ e.preventDefault(); playRow(cur < 0 ? idx : cur); }
    else if(e.code === 'ArrowDown' || e.code === 'ArrowUp'){
      e.preventDefault();
      idx = Math.max(0, Math.min(rows.length - 1, idx + (e.code === 'ArrowDown' ? 1 : -1)));
      rows[idx].focus();
      rows[idx].scrollIntoView({block:'nearest'});
    }
    else if(e.code === 'Enter'){ e.preventDefault(); playRow(idx); }
  });
})();
</script>
</body></html>
"""

if __name__ == "__main__":
    main()

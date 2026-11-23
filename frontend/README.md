# 游戏前端

Godot 4.7.2。打开 `frontend/entry.tscn`，按 F6 验收。选章页展示四个章节，点进某一章后是该章的关卡列表，五间房可任选其一进入；未解锁的显示锁定，目录里 `scene` 为空的显示待接入。第一章首个房间已接入，其余房间待交付。同章内完成后直接换房，第五间完成后显示章节结算，第四章结束后显示全部通关。若下一间尚未接入，则停在房间完成页。选章卡片优先定位到首个已解锁且未完成的房间，但进去之后是列表，不再替玩家决定进哪一间；整章通关后可以从头重玩任意一间。暂停页和房间完成页的「选择关卡」直接落到当前这一章。继续游戏从最近玩的关卡出生点开始。Esc 暂停页的重试重建当前关卡，游戏内 R 沿用关卡自己的复位流程。Esc 在章节列表上退回选章页。

## 更换样式、文案和关卡

- 在 Inspector 打开 `db/pixel_theme.tres` 更改字体、颜色、边框和间距。各页继承 `view/page.tscn`，可分别调整面板尺寸。
- 在 `db/copy.tres` 修改文案和操作说明。
- 在 `db/catalog.tres` 按顺序设置关卡。每一项填写 `id`、`title` 和 `scene`。保留 ID 可以继承原存档；空路径显示待接入。每五项为一章。每个场景由关卡作者设置固定取景，按一个屏幕布置谜题。前端只负责换场。
- 章节页的格子名取 `title` 去掉「第 N 章 · 」之后的部分（`Flow.room_label`）。所以第二章那种自带场名的标题（`第 2 章 · 错过 · 过站`）会显示成「错过 · 过站」；占位标题（`房间 3/5`）统一收敛成「房间 3」。想让关卡列表有好读的名字，就写进 `title`。
- 换场分两种：同章顺序推进时画面朝出口对侧滑走、下一间从对侧推入（0.24s）；跨章、重试、选关跳转一律 0.10s 黑出 + 0.10s 黑入。滑动的方向由出口在屏幕哪一侧决定，所以**关卡必须把 `RespawnPoint` 摆在出口的对边**，否则滑完人会从中间冒出来。这条由 `tests/test_transition_space.gd` 逐对检查。
- 需要强制时可以在目录项里加 `link`：`"cut"` 一律切黑、`"h"` 横滑、`"v"` 纵滑。不写就按出口位置推断。
- 关卡根节点提供布尔完成状态，现有接口为 `won`。旧结算面板路径默认为 `UI/Win`。与现有约定不同的项目，在目录资源里修改适配字段。已有 HUD 和暂停入口的节点路径也集中于该资源。

## 安装和拆卸

1. 验收通过后，由项目负责人在 Project Settings 将 Main Scene 指向 `res://frontend/entry.tscn`。保留现有 Autoload 项，前端会话启动后接管旧暂停的处理和 HUD 的显示。
2. 拆卸时将 Main Scene 改回原关卡入口并移除 `frontend/`。直接 F6 运行关卡会继续走关卡自己的暂停、HUD 和结算。
3. 设置与进度分别存到 `user://frontend/settings.cfg` 和 `user://frontend/progress.cfg`。进度重置只改进度文件。不可识别的存档会保存在同目录，文件名带 `.invalid-`。

`db/` 放可编辑配置，`systems/` 管目录和进度数据，`glue/` 管加载关卡、存档和当前项目适配，`view/` 显示状态并传出按钮请求。

## 回归

```powershell
godot --headless --path . --fixed-fps 60 --script res://frontend/tests/test_frontend.gd
godot --headless --path . --fixed-fps 60 --script res://frontend/tests/test_transition_space.gd
godot --headless --path . --fixed-fps 60 --script res://_reference/tools/test_complete_room.gd
godot --headless --path . --fixed-fps 60 --script res://graybox/tests/test_graybox_kit.gd
```

前端回归用测试目录把同一个真实房间挂到 20 个不同 ID，从而验证完整的导航、解锁、结算和继续游戏。测试存档位于被 Git 忽略的 `build/`，运行结束后自动清理。

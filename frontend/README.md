# 游戏前端

Godot 4.7.2。打开 `frontend/entry.tscn`，按 F6 验收。选关目录列出 20 个稳定 ID，第 1 关接现有完整房间，第 2 至 20 关等待策划交付场景。继续游戏从最近玩的关卡出生点开始。Esc 暂停页的重试重建当前关卡，游戏内 R 沿用关卡自己的复位流程。

## 更换样式、文案和关卡

- 在 Inspector 打开 `db/pixel_theme.tres` 更改字体、颜色、边框和间距。各页继承 `view/page.tscn`，可分别调整面板尺寸。
- 在 `db/copy.tres` 修改文案和操作说明。
- 在 `db/catalog.tres` 按顺序设置关卡。每一项填写 `id`、`title` 和 `scene`。保留 ID 可以继承原存档；空路径显示待接入。也可配置网格列数。
- 关卡根节点提供布尔完成状态，现有接口为 `won`。旧结算面板路径默认为 `UI/Win`。与现有约定不同的项目，在目录资源里修改适配字段。已有 HUD 和暂停入口的节点路径也集中于该资源。

## 安装和拆卸

1. 验收通过后，由项目负责人在 Project Settings 将 Main Scene 指向 `res://frontend/entry.tscn`。保留现有 Autoload 项，前端会话启动后接管旧暂停的处理和 HUD 的显示。
2. 拆卸时将 Main Scene 改回原关卡入口并移除 `frontend/`。直接 F6 运行关卡会继续走关卡自己的暂停、HUD 和结算。
3. 设置与进度分别存到 `user://frontend/settings.cfg` 和 `user://frontend/progress.cfg`。进度重置只改进度文件。不可识别的存档会保存在同目录，文件名带 `.invalid-`。

`db/` 放可编辑配置，`systems/` 管目录和进度数据，`glue/` 管加载关卡、存档和当前项目适配，`view/` 显示状态并传出按钮请求。

## 回归

```powershell
godot --headless --path . --fixed-fps 60 --script res://frontend/tests/test_frontend.gd
godot --headless --path . --fixed-fps 60 --script res://_reference/tools/test_complete_room.gd
godot --headless --path . --fixed-fps 60 --script res://graybox/tests/test_graybox_kit.gd
```

前端回归用测试目录把同一个真实房间挂到 20 个不同 ID，从而验证完整的导航、解锁、结算和继续游戏。测试存档位于被 Git 忽略的 `build/`，运行结束后自动清理。

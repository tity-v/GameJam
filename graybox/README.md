# 关卡灰盒搭建套件

**新建房间**　点 Godot 顶栏「项目 → 工具 → 新建灰盒房间」。工具自动选下一空位、放好玩家、出生点、地板和出口，并打开新场景。拖组件搭关后按 F6 单测，按 F5 走章节流程。交付时一起提交新场景和 frontend/db/catalog.tres。


使用 Godot 4.7.2。模板和机关扩展都在 `res://graybox/`，使用项目现有的玩家、Echo、物理层和全局输入。按 **F5** 从主菜单运行整个游戏。要单测房间，打开房间场景按 **F6**。双压板示例在 `res://scenes/levels/complete_room.tscn`。

## 搭一间新房

1. 打开 `graybox/base_level.tscn`，使用 **场景 → 场景另存为**，在自己的关卡目录保存副本。保留根脚本以及 `RespawnPoint`、`Player`、`EchoManager` 和 `UI/Win/Replay` 的接线。
2. 在 `Terrain` 下拖入 `scenes/blocks/solid_ground.tscn` 或 `solid_wall.tscn`，在每个关卡实例上用 **Block Size** 调宽高。地面块也可以用作静态平台。装饰放在 `Decor`，通过 `Camera2D` 的位置和 **Limit** 调整画面。
3. 移动 `RespawnPoint` 的十字标记，首次出生和复活都用这个位置。标记是玩家碰撞框的左上角，例如 38px 高的玩家站在 Y=576 的地板上时，标记可以放在 Y=538。替换标记或玩家实例后，在根节点 Inspector 重新指定 **Spawn Point** 和 **Player**。
4. 把压板、门、出口和尖刺拖到 `Mechanisms`，在 Inspector 里配置。选节点时打开字段旁的节点选择器。
5. 保存并按 **F6**。按 **E** 主动死亡，重生后留下 Echo。关卡内按 **R** 清除 Echo、回到出生点并复位压力板并关闭门。通关后点 **再玩一次** 完整复位房间。保存后重新打开场景，核对布局和关联仍然有效。

| 零件 | Inspector 配置 |
| --- | --- |
| `scenes/blocks/solid_ground.tscn`、`scenes/blocks/solid_wall.tscn` | 拖到 Terrain，用 **Block Size** 调整平台或墙的尺寸。 |
| `scenes/blocks/spike_tile.tscn` | 拖到 Mechanisms，放在地面上，用 **Block Size** 调整尖刺范围。 |
| `graybox/respawn_point.tscn` | 模板自带。需要补回时放在房间根节点下，命名为 `RespawnPoint`。 |
| `graybox/pressure_plate.tscn` | **Block Size** 决定宽高，**Accepts Player** 和 **Accepts Echo** 决定触发对象。黄色边框标出接受脚底的位置范围，压板下方应有地面。 |
| `graybox/door.tscn` | 向 **Plate Paths** 列表添加元素，并逐项选择压板。所有板同时激活才开门。松开任意一块板后关门。 |
| `graybox/exit.tscn` | **Block Size** 调检测范围。玩家或已激活虚影进入即可过关。 |

检查场景树中门、出口和房间根节点的配置警告，补全缺失的节点关联。要查看已配置的双板示例，选中 `complete_room.tscn` 中的门。

## 程序对接与验收

- 复用共享的 `player`、`echo`、`respawn_point` 组和 `EchoManager.player_path`。灰盒房间调用玩家现有的出生点接口，结算与完整重载仍由房间控制器提供。
- 用两块板验证同时踩住才开门，松开任意一块即关门。验证移动出生点、修改两个地形实例、Echo 足部踩板、玩家可过门、Echo 可以通关，以及「再玩一次」完整复位。

`db/` 保存灰盒编辑器预览参数和配置提示。`glue/` 通过场景中序列化的引用接入共享玩家、机关和房间接口。`view/` 只依据边框参数和零件显示尺寸绘制编辑器检测范围。模块沿用既有物理优先级。

```powershell
godot --headless --path . --fixed-fps 60 --script res://graybox/tests/test_graybox_kit.gd
godot --headless --path . --fixed-fps 60 --script res://_reference/tools/test_complete_room.gd
```

## 地形与房间文字

将 `terrain.tscn` 拖到房间的 Terrain 节点下，用 Block Size 调整尺寸，在 Collision Mode 中选择全向实体或单向顶面。两种碰撞共用同一地形组件。
将 `room_text.tscn` 拖到 Decor 下，在 Inspector 的 Text 中填写提示，可直接移动、复制并设置字体大小和颜色。
房间出口使用 `exit.tscn`，始终开放。

## 可组合机关

在房间中实例化以下场景，引用通过 Inspector 设置。细黄线仅在编辑器里绘制。门的 Plate Paths 可同时绑定拉杆和压板，全部激活时开门。

| 场景 | 设置 |
|---|---|
| platform.tscn | 放下即从当前位置水平往返 160 像素。调 End Offset 可改为竖直或斜向；黄线实点是起点，空心圈是终点。需要复用标记时仍可绑定 Start Point、End Point。Speed Override 可按房间设置像素/秒，0 使用数据库默认值。 |
| lever.tscn | Initially Right 控制初始朝向。向右偏时从右侧向左推，向左偏时反向推。拖到门的 Plate Paths 或传送门的 Switch Source。 |
| portal.tscn | Destination 可选标记或另一扇门。Close After Use 控制一次性关闭。可选 Switch Source 控制启用条件。关闭后角色直接穿过。 |
| box.tscn | Box Size 同步外观、碰撞和质量。压力板的 Accepts Boxes 可独立设置。 |
| color_recorder.tscn | 拖成移动平台、箱子、门、传送门、压板或拉杆的子节点。Tint 设置编辑配色和回放颜色。死亡保留本轮记录，复活后原组件复位，组件虚影按记录重放位置、碰撞和开关状态。虚影箱子可压板，虚影平台能承载，虚影拉杆和压板能驱动绑定的门，虚影传送门按录制时的开关状态传送角色。R 清除记录。 |

速度、密度、推力、拨杆行程和影像透明度集中在 db/mechanisms.tres。新房间使用 base_level.tscn 的 EchoManager，传送后的虚影会继续按原来的移动增量行走，并根据它当时遇到的传送门状态决定是否传送。

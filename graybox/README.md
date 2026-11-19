# 关卡灰盒搭建套件

使用 Godot 4.7.2。模板和机关扩展都在 `res://graybox/`，使用项目现有的玩家、Echo、物理层和全局输入。现成解谜示例是 `res://scenes/levels/complete_room.tscn`，可按 F5 运行。

## 搭一间新房

1. 打开 `graybox/base_level.tscn`，使用 **场景 → 场景另存为**，在自己的关卡目录保存副本。保留根脚本以及 `RespawnPoint`、`Player`、`EchoManager` 和 `UI/Win/Replay` 的接线。
2. 在 `Terrain` 下拖入 `scenes/blocks/solid_ground.tscn` 或 `solid_wall.tscn`，在每个关卡实例上用 **Block Size** 调宽高。地面块也可以用作静态平台。装饰放在 `Decor`，通过 `Camera2D` 的位置和 **Limit** 调整画面。
3. 移动 `RespawnPoint` 的十字标记，首次出生和复活都用这个位置。标记是玩家碰撞框的左上角，例如 38px 高的玩家站在 Y=576 的地板上时，标记可以放在 Y=538。替换标记或玩家实例后，在根节点 Inspector 重新指定 **Spawn Point** 和 **Player**。
4. 把下表的灰盒场景拖到 `Mechanisms`，在 Inspector 里配置。选节点时打开字段旁的节点选择器。
5. 保存并按 **F6**。按 **E** 主动死亡，重生后留下 Echo。关卡内按 **R** 清除 Echo 并回出生点，锁存门保持开启。通关后点 **再玩一次** 完整复位房间。保存后重新打开场景，核对布局和关联仍然有效。

| 零件 | Inspector 配置 |
| --- | --- |
| `graybox/respawn_point.tscn` | 模板自带。需要补回时放在房间根节点下，命名为 `RespawnPoint`。 |
| `graybox/pressure_plate.tscn` | **Block Size** 决定宽高，**Accepts Player** 和 **Accepts Echo** 决定触发对象。黄色边框标出接受脚底的位置范围，压板下方应有地面。 |
| `graybox/door.tscn` | 向 **Plate Paths** 列表添加元素，并逐项选择压板。所有板同时激活才开门。勾选 **Latch Open** 时保持开启直到完整重置。持续型门取消勾选，并把 **Safety Player** 指向当前房间的玩家。触发条件失效且玩家离开门身后关门。 |
| `graybox/exit.tscn` | **Door Path** 选择关联门，**Block Size** 调检测范围。绿色边框标出范围。门打开后只有当前玩家能触发通关。 |

检查场景树中门、出口和房间根节点的配置警告，补全缺失的节点关联。要查看已配置的双板示例，选中 `complete_room.tscn` 中的门。

## 程序对接与验收

- 复用共享的 `player`、`echo`、`respawn_point` 组和 `EchoManager.player_path`。灰盒房间调用玩家现有的出生点接口，结算与完整重载仍由房间控制器提供。
- 用一块板测持续门，用两块板测锁存门。验证移动出生点、修改两个地形实例、Echo 足部踩板、玩家可过门、Echo 不能通关，以及「再玩一次」完整复位。

`db/` 保存灰盒编辑器预览参数和配置提示。`glue/` 通过场景中序列化的引用接入共享玩家、机关和房间接口。`view/` 只依据边框参数和零件显示尺寸绘制编辑器检测范围。模块沿用既有物理优先级。

```powershell
godot --headless --path . --fixed-fps 60 --script res://graybox/tests/test_graybox_kit.gd
godot --headless --path . --fixed-fps 60 --script res://_reference/tools/test_complete_room.gd
```

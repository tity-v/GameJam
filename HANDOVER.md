# 交接文档 — Your Past Self（Godot 4.7 复刻）

> 面向接手这个仓库的程序。看完能回答三个问题：**现在做到哪了、代码为什么长这样、下一步从哪下手。**
> 策划/美术看 `README.md` 就够，那份讲怎么改内容；这份讲怎么改代码。

---

## 0. 一句话

把 2D 平台解谜游戏《过去的你》的第一关搬进 Godot 4.7，并实现它的核心机制：**死后留下一个重放你上一轮动作的虚影，用虚影替你踩机关、当垫脚**。

当前状态：**机制闭环已跑通，关卡规则未完成**——第一关实际是**过不去的**（门是实体墙，压力板不响应）。这不是 bug，是待办。

---

## 1. 五分钟跑起来

| 项 | 值 |
|---|---|
| 引擎 | **Godot 4.7.2**（`config/features` 写死 4.7，低版本打开会提示） |
| 渲染 | `gl_compatibility`（兼容模式，老显卡/笔记本也能跑） |
| 视口 | 1280 × 720，`canvas_items` 拉伸 |
| 主场景 | `res://scenes/levels/level_01.tscn` |
| 代码规模 | 10 个脚本，共约 800 行 GDScript |

打开方式：Godot 项目管理器 → 导入 → 选仓库根目录（`project.godot` 在根）。

**按键**：`A/D` 移动（方向键也行）· `Space` 跳跃（长按更高）· `E` 自杀 · `R` 重置全部虚影 · `Esc` 暂停。

**每局必做的验证动作**（30 秒判断环境是否正常）：
1. 开局站在地面，`y = 522`
2. 按住 `D` 跑，撞到 x=790 的门停住 → 说明碰撞与关卡数据都加载对了
3. 按 `E`，方块淡出带红叉，1.3 秒后回出生点，同时留下一个蓝色虚影
4. 虚影重放完再活 1.3 秒后消失
5. 按 `F1`：角色身上出现黄色碰撞框、脚下出现橙色粗线，且橙线正好压在地面顶面（560）

---

## 2. 当前完成度

| 功能 | 状态 | 实现位置 |
|---|---|---|
| 第一关地图 / 物块 / 贴图 | 完成 | `scenes/levels/level_01.tscn`、`assets/blocks/` |
| 主角移动、跳跃（长短按两档） | 完成 | `scripts/player.gd` |
| 与地形 / 墙壁 / 门的实体碰撞 | 完成 | 物块 `StaticBody2D` + `player.gd` mask |
| 死亡（E / 掉出地图）与固定点重生 | 完成 | `player.gd` 的 `die()` / `respawn()` |
| 虚影：录制轨迹、死亡生成、复活同步重放 | 完成 | `scripts/echo_manager.gd`、`echo.gd` |
| 虚影单向碰撞（侧面穿、头顶站） | 完成 | `echo.tscn` 的 `Top` 薄片 |
| 虚影上限 5 条，满员顶掉最早 | 完成 | `echo_manager.gd` 的 `_add_echo()` |
| 虚影尸体多存活 1.3 秒（可踩） | 完成 | `echo.gd` 的 `fade_duration` |
| `R` 重置全部虚影 | 完成 | `echo_manager.gd` 的 `clear_all()` |
| `Esc` 暂停 + 点击继续 | 完成 | `scenes/ui/pause_menu.tscn`（autoload） |
| 底部操作提示栏 + 虚影计数 | 完成 | `scenes/ui/hud.tscn`（autoload） |
| 碰撞框可视化（脚底线 / 可踩线，`F1` 开关） | 完成 | `scripts/hitbox_debug.gd` |
| **压力板 → 开门** | **未做** | — |
| **出口结算 / 通关** | **未做** | — |
| **尖刺伤害判定** | **未做**（尖刺物块已备好） | — |
| 关卡名 / 关卡提示文字（原版有） | 未做 | — |
| 第 2–8 关 | 未做 | 原数据见 `_reference/source_from_game/scripts/platformer/levels.gd` |

---

## 3. 代码结构

### 3.1 场景树（`level_01.tscn`）

```
Level01 (Node2D)
├── Background (ColorRect)          #101720
├── Grid (Node2D) → VLine0..VLine1520   20 条竖网格线，x 每 80
├── Solids (Node2D)
│   ├── Ground   instance solid_ground.tscn   (-40, 560, 1800×120)
│   └── Wall     instance solid_wall.tscn     (-40, 0, 40×680)
├── Plates (Node2D)
│   ├── PlateA   instance plate_off.tscn      (390, 548, 75×12)
│   └── LabelA   (Label)                      压力板上的「A」
├── Doors (Node2D)
│   └── Door0    instance door.tscn           (790, 390, 30×170)
├── Exit         instance exit.tscn           (1370, 495, 52×65)
├── RespawnPoint (Marker2D, groups=["respawn_point"])  (90, 522)
├── Player       instance player.tscn
├── EchoManager  (Node2D, groups=["echo_manager"])  script=echo_manager.gd
└── Camera2D     script=camera_follow.gd
```

**加新关卡时，`RespawnPoint` / `EchoManager` / `Camera2D` 三样必须带上**，否则分别会：重生点退回初始位置、没有虚影、镜头不动。建议下一步抽一个 `LevelBase.tscn` 作为基场景（见 §8）。

### 3.2 脚本职责

| 脚本 | 行数 | 职责 | 挂在哪 |
|---|---|---|---|
| `player.gd` | 222 | 移动/跳跃手感、死亡淡出、重生、被虚影带着走 | `player.tscn` |
| `echo_manager.gd` | 142 | 录轨迹、生成虚影、FIFO 上限、R 重置 | 关卡内节点 |
| `echo.gd` | 115 | 逐帧重放轨迹、单向碰撞、尸体淡出 | `echo.tscn` |
| `hud.gd` | 57 | 刷新「回声 n/5」、闪现提示淡出 | autoload `Hud` |
| `camera_follow.gd` | 48 | 水平跟随 + 边界夹取 + 瞬移归位 | 关卡内 `Camera2D` |
| `pause_menu.gd` | 41 | `Esc` 切换 `SceneTree.paused` | autoload `PauseMenu` |
| `block.gd` | 38 | `block_size` 同步贴图与碰撞（`@tool`） | 所有物块场景根 |
| `key_hint.gd` | 21 | 一组「键帽 + 说明」 | `key_hint.tscn` |
| `keycap.gd` | 18 | 单个键帽 | `keycap.tscn` |
| `hitbox_debug.gd` | 95 | 碰撞框可视化（纯 `_draw`，不参与物理；`@tool` + F1 开关） | 玩家/虚影的 `HitboxDebug` 子节点 |

### 3.3 信号流

唯一的跨系统通信是主角的两个信号，其余全靠直接调用：

```
player.die()  ──emit──> player.died ──> echo_manager._on_player_died()
                                           └─ 停止录制，用 _trail 生成一条虚影

player.respawn() ─emit─> player.respawned ─> echo_manager._on_player_respawned()
                                           └─ 清空本轮轨迹，所有虚影 reset() 回第 0 帧
```

`EchoManager → HUD` 用的是组查找 + `has_method()` 鸭子类型（`_flash_hud`），没有硬依赖，HUD 缺失时静默跳过。

### 3.4 物理层与坐标约定

**碰撞层**（已在 `project.godot` 的 `[layer_names]` 命名）：

| 层 | 名称 | 谁在用 |
|---|---|---|
| 1 | `World` | 所有物块（未显式设置，默认 1） |
| 2 | `Player` | 主角 `collision_layer = 2` |
| 3 | `Echo` | 虚影 `collision_layer = 4` |

主角 `collision_mask = 5`（= World | Echo）——**只检测世界和虚影，不检测自己**。
虚影 `collision_mask = 0`——它不主动检测任何东西，纯被动挨踩。

> 注意层号与值不同：层 3 的位值是 4。代码里 `set_collision_layer_value(3, true)` 用的是**层号 3**，不是值 4，别混。

**坐标约定（重要）**：所有角色的 `position` 是**包围盒左上角**，不是中心。这是原版 `actor.pos` 的约定，`levels.gd` 里的 `Rect2(x, y, w, h)` 可以直接抄。

- 出生点 `(90, 522)`，主角 28×38 → 脚底 560 = 地面顶部
- 物块也是左上角对齐（`CollisionShape2D.position` 自动取 `block_size / 2`）
- `Camera2D` 需要用 `target_center_offset_x = 14` 补回半个身位

**执行顺序**：`EchoManager.process_physics_priority = -10`，保证每帧**先推进虚影、再跑玩家**。玩家靠 `_carry()` 读虚影的 `last_delta` 被带着走。如果把这个值改掉，站在移动虚影头上会开始抖。

### 3.5 碰撞可视化（`hitbox_debug.gd`）

玩家和虚影场景里各挂了一个 `HitboxDebug` 子节点，用 `shape_path` 指向同级 `CollisionShape2D`，
把那个 shape 的矩形**原样读出来画一遍**——所以框永远等于真实碰撞，不存在「画一套、判定另一套」。

| 节点 | 画的内容 | 意义 |
|---|---|---|
| `player.tscn / HitboxDebug` | 黄色框 28×38 + **底边橙色粗线**（`feet_line`） | 框是「能不能钻过缝」，橙线是真正踩地的那条边 |
| `echo.tscn / HitboxDebug` | 青绿框 28×8 + **顶边橙色粗线**（`stand_line`） | 薄片就是虚影唯一的实体部分，橙线是可踩面 |

两条橙线**用同一个颜色、同一种画法**（2px 实线 + 两端短刻度），所以「贴着站上去了吗」是一眼的事：
重合 = 引擎判定成立的瞬间。

**关键约定：线不是碰撞体，框才是。** 橙线只是画在 shape 的边线上，它不会推、不会挡、不会让角色提前落地。
真正让角色停下的是 `CollisionShape2D` 与地面的重叠——视觉上就是两条线压在一起的那一刻。
这也是为什么调尺寸只看这两条线就够：线对齐了，判定必然是对的。

- **纯 `_draw`，不参与物理**：删掉节点、关掉 `visible`、按 `F1` 都不改变任何手感
- `@tool` + `_process` 里比对矩形：编辑器里改 `shape.size` / `block_size` 立刻重画，美术不用运行游戏
- 运行时 `F1` 全局切换（调试键，故意没做成 `input` 动作，走 `physical_keycode == KEY_F1`，不污染输入映射）
- 可调项：`box_fill` / `box_line` / `contact_color` / `tick`；虚影那边把框改成青绿是为了不和虚影本体的蓝色糊在一起
- **改尺寸后的自检顺序**：框贴住贴图 → 橙线压在地面顶面 → 站到虚影头上两条橙线重合。
  框偏左上、脚陷进地里 = 只改了 `shape.size` 忘了改 `Collision.position`（见 §5 最后一行）

### 3.6 角色尺寸与美术交付规格

> 给美术看的版本是 `README.md` §3.4（那边是「怎么画」）。这里写「为什么必须这样」，
> 接手程序改角色尺寸前先读完这一节，否则很容易把美术的图改坏。

**一句话：可画范围就是碰撞框，28×38，画布多一点少一点都不行。**

引擎的真实行为（`player.gd` 的 `_fit_visuals()`）：

```
Sprite.scale = 碰撞体尺寸 / design_size        design_size 默认 28×38
实际绘制尺寸 = 贴图尺寸 × Sprite.scale
```

也就是说，**只有当「碰撞体」变了，贴图才会被补偿**。贴图自己变大，`scale` 仍然是 `(1,1)`，
角色就直接按原尺寸画出来。实测（把 `player.png` 换成 56×76 再重新导入）：

```
texture = (56, 76)   scale = (1, 1)   实际绘制 = (56, 76)   碰撞体 = (28, 38)
```

→ 角色比碰撞框大一圈，脚穿进地里、头插进平台，看起来像"贴图和碰撞错位"，其实是图交错了。

**所以：**

| 项 | 规则 |
|---|---|
| 主角画布 | 正好 28×38（`design_size` 的值） |
| 死亡叉号 | 同样 28×38（和 `Sprite` 共用同一套缩放） |
| 虚影两张图 | 同样 28×38，但只有顶部 28×8 薄片有碰撞，头顶轮廓要平 |
| 想画 4 倍大图 | **只能同时把 `design_size` 改成 112×152**，还要同步叉号与虚影，不推荐；直接画 28×38 最省事 |
| 物块 | 九宫格源图，尺寸必须和 §4.4 的表一致（改了要同步 tscn 里的 patch margins） |

**交付给美术的三件东西**（缺一件就会反复返工）：

1. 模板图 `_reference/art_templates/player_guide_10x.png` / `echo_guide_10x.png`
   （10 倍，红框=碰撞框、青线=2px 安全区、橙线=脚底/可踩线；由 `make_art_templates.py` 生成）
2. 交图校验 `python _reference/tools/check_art_size.py`（角色尺寸错会直接说"会显示成 2.00 倍大小"）
3. 游戏里按 `F1`：黄框贴住角色、橙线压在地面，才算对

**一条纪律**：「五条硬规则」和模板图用法只写在 `README.md` §3.4，本文件只保留程序必须知道的**因果与数字**。
改规则时改 README，别在两个文件里各维护一份——之前就出现过 README 说"可以画 4 倍等比缩放"
而实际不会缩放的情况，美术照做后全部返工。**凡是"引擎会帮你缩放"的直觉，先写测试验证再写进文档。**

---

## 4. 五个关键设计决策

这一节是接手时最该看的——**它们都推翻了更直觉的做法**，改之前先读理由。

### 4.1 虚影录「轨迹」，不录「指令」

原版是**逐帧记录按键**，死亡后拿指令重跑一遍 AABB 物理。这里改成**逐帧记录坐标**（`PackedVector2Array`）。

原因：主角是 `CharacterBody2D`，Godot 的两个 `CharacterBody2D` 之间**不会发生碰撞**，所以虚影必须改成 `StaticBody2D` 才能被踩。一旦成了静态体，它就不能参与物理模拟，指令重放无从谈起。

副作用是好事：重放出来和当时看到的**逐帧一致**，不存在物理误差累积导致的漂移。

代价：轨迹不能当录像回放给其他系统用（原版可以），并且内存随存活时间线性增长——所以有 `MAX_FRAMES = 6000`（100 秒）截断。

### 4.2 虚影只有「头顶一层薄片」是实体

`echo.tscn` 的 `Top` 是一个 28×8 的 `RectangleShape2D`，`one_way_collision = true`，只在 `y = 4` 处。

效果：

| 玩家从哪来 | 结果 |
|---|---|
| 上方落下 | 踩住（`is_on_floor = true`） |
| 侧面走过 | 直接穿过 |
| 下方跳起 | 完全不受阻 |

这精确对应原版「虚影只能当平台，不能当墙」的设计。想改成实心方块，改 `Top` 的 `shape.size` 和 `one_way_collision` 即可，但会破坏原设计意图。

### 4.3 虚影比玩家多活 1.3 秒，且与玩家同一条时间轴

玩家的时间轴是「活 T 秒 → 死 1.3 秒」；虚影是「重放 T 秒 → 死 1.3 秒」。所以它**天然比玩家晚 1.3 秒消失**，不是额外加了个计时器。

这 1.3 秒里**碰撞仍然开着**。目的是后面做尖刺关：原版第 5 关的解法就是「让回声掉进尖刺，趁它消失前跳上身体，跨过尖刺」。

相关数值：`echo.gd` 的 `fade_duration = 1.3`（对齐 `player.gd` 的 `death_duration`）、`death_min_alpha = 0.18`（尸体不会彻底看不见，踩上去脚下始终有东西）。

### 4.4 物块尺寸收敛到 `block_size`，贴图用九宫格

以前地面是 1800×120 的整图，美术必须画准尺寸，改尺寸要同步改碰撞 `size` + `position` + 关卡摆放坐标三处。

现在：物块场景根节点挂 `block.gd`，`@export var block_size` 是**唯一尺寸来源**，setter 同步 `Patch.size` 与 `Collision`（含居中偏移）。脚本标 `@tool`，编辑器里改完碰撞框立刻跟着动。

贴图随之改成小尺寸源图（地面 32×32、出口 16×16、门 8×8），`NinePatchRect` 拉伸时边角不变形；尖刺用 `TextureRect` + `TILE` 平铺而不是拉伸。

`RectangleShape2D` 加了 `resource_local_to_scene = true`——**不加的话同类物块的所有实例共享一份 shape，改一个全变**。

### 4.5 素材生成器全部「已存在则跳过」

`_reference/tools/make_*.py` 是当初搬运时的一次性脚本，现在都有 guard：目标文件存在就跳过，只有显式 `--force` 才覆盖。

它们会重写 `level_01.tscn` 和 `project.godot`（输入映射、autoload、碰撞层命名）。**策划在编辑器里改关卡后跑 `--force`，全部回滚。**

---

## 5. 已知坑（都踩过，别再踩）

| 现象 | 原因 | 解法 |
|---|---|---|
| 虚影帧号卡在 0、帧数还在涨，「重放的是当前这轮」 | `PackedVector2Array` 传参是**共享缓冲**，虚影和录制中的 `_trail` 指向同一份数据 | `echo.setup(trail.duplicate())`，且复活时直接 `_trail = PackedVector2Array()` 换新数组 |
| 第二条命开始虚影穿模，玩家踩空 | 虚影播完时 `set_collision_layer_value(3, false)`，`reset()` 里忘了开回来 | `reset()` 里显式打开层 3 |
| 键盘映射写了但按键完全没反应 | `InputEventKey.new()` 不设 `device = -1`，序列化出来是 `device: 16` | `project.godot` 里所有事件都是 `device: -1`，**别手改这个值** |
| 物块全变成 64×64 小方块 | tscn 里 `block_size` 写在 `script = ExtResource(...)` **之前**，脚本还没挂上，自定义属性被丢弃，回落到默认值 | 节点属性顺序必须是 `script` 先、自定义属性后 |
| 改一个地面的尺寸，所有地面都变了 | 场景里的 `RectangleShape2D` sub_resource 默认被所有实例共享 | `resource_local_to_scene = true` |
| 玩家重生时镜头从死亡点一路滑回出生点 | `Camera2D` 开了平滑，瞬移会触发插值 | 重生后调 `camera_follow.gd` 的 `snap_to_target()` |
| 暂停菜单按 ESC 关不掉 | 暂停菜单自身也是 `PAUSABLE`，`get_tree().paused = true` 后连自己的输入都停了 | `PauseMenu` 的 `process_mode = ALWAYS`（场景里已设 `process_mode = 3`） |
| headless 测试里鼠标点击无效（键盘正常） | `Input.parse_input_event()` 送的**鼠标**事件到不了 GUI | 用 `root.push_input(ev, true)`，真实鼠标走的也是这条路径 |
| `.gdignore` 目录里的测试脚本跑不了 | 以为 `.gdignore` 会完全屏蔽 | `--script res://_reference/tools/xxx.gd` 仍可显式加载，能用 |
| 场景里改了属性，重启又变回去 | 生成器被跑过（`--force`） | 别跑 `--force`；改了关卡就提交 git |
| 改了角色尺寸后，脚陷进地里 / 贴图与碰撞错位 | 只改了 `Collision.shape.size`，没改 `Collision.position`（它是相对左上角原点的中心偏移） | `position = shape.size / 2`；按 `F1` 看一眼框是否贴在方块上，框偏左上就是漏了这步（§3.5） |
| 调完尺寸觉得「明明对齐了还是踩空」 | 看的是贴图边缘，不是碰撞（贴图可以比 shape 画大一圈） | 判定永远以橙色线/黄框为准，别拿美术图的像素边缘当碰撞边界 |
| 角色看着比碰撞框大一圈 / 隔空停住 / 脚陷进地里 | 贴图不是 28×38（引擎 1:1 绘制，**不会**把大图缩回去），或四周留了透明边 | 跑 `python _reference/tools/check_art_size.py`；画布必须正好 28×38（§3.6） |

---

## 6. 三条改动路径

### 策划：改关卡
打开 `level_01.tscn`，拖实例。改物块大小用检查器的 `block_size`。改重生点挪 `RespawnPoint`。详规见 `README.md` 第三、四节。

### 美术：换图
覆盖 `assets/` 下的同名 png。物块是九宫格源图（尺寸见 `README.md` 3.1），不是最终尺寸图。

改完角色/物块的尺寸后按 `F1` 开调试层自检一遍（§3.5）：黄框要贴住贴图、橙色脚底线要压在地面顶面。
**换图本身不用动碰撞**——只要新图的透明区域不变，保持 `shape.size` 不动就是对的。

交图前让他跑 `python _reference/tools/check_art_size.py`：尺寸/比例不对会直接标 `BAD`。
可画范围与模板图见 `README.md` §3.4。

### 程序：改逻辑
数值都是 `@export`，优先在检查器里调，别硬编码。新增机制按现有模式走：

- 需要每帧推进的东西 → 挂进关卡，注意 `process_physics_priority`
- 需要和玩家通信 → 用信号，别在 `EchoManager` 里反向 `get_node("../../Player")`
- 需要新物理层 → 先在 `project.godot` 的 `[layer_names]` 里命名，再改 mask

---

## 7. 测试怎么跑

没有单元测试框架，用的是 **headless 场景脚本**：脚本 `extends SceneTree`，在 `_process` 里按帧数推进、读节点状态、`print` 断言结果。

```bash
# 1) 先导入资源（首次或新增素材后必做）
godot --headless --path . --import

# 2) 跑单个测试
godot --headless --path . --fixed-fps 60 --script res://_reference/tools/test_player_movement.gd

# 3) 全跑一遍
for t in test_player_movement test_death_respawn test_pause test_echo_system \
         test_echo_lifetime test_reset_echoes test_echo_cap test_blocks_layout \
         test_collider_size test_hitbox_debug; do
  echo "=== $t ==="
  godot --headless --path . --fixed-fps 60 --script "res://_reference/tools/$t.gd"
done
```

`--fixed-fps 60` **不能省**：测试里的帧数断言基于固定步长。

| 测试 | 覆盖内容 |
|---|---|
| `test_player_movement` | 站立高度、满速 210、松手停住、撞墙停位、两档跳高、空中转向 |
| `test_death_respawn` | E 自杀、死亡中吞输入、1.3s 复活、相机归位、掉出地图判死 |
| `test_pause` | ESC 暂停、暂停中位移为 0、点空白不恢复、点按钮恢复 |
| `test_echo_system` | 侧面穿、头顶踩、上跳穿、门挡人、上限 5、重放、被带着走 |
| `test_echo_lifetime` | 重放后多活 78 帧（1.3s）、尸体期可踩可跳、叉号不随淡出 |
| `test_reset_echoes` | R 清空、重置后从当下重录、暂停中 R 无效 |
| `test_echo_cap` | FIFO 顶掉最早的一条、尸体也占名额、HUD 提示 |
| `test_blocks_layout` | block_size 同步贴图与碰撞、九宫格 margin、实例不串台、叉号随尺寸缩放 |
| `test_collider_size` | 改主角尺寸的安全性：正确同步后脚底仍贴 560、只改 size 不改 position 会陷 19px、6000px/s 不穿墙、4×4 不抖 |
| `test_hitbox_debug` | 调试框矩形范围、脚底线/可踩线世界坐标、踩上去两线重合（0.00px）、F1 开关、改尺寸后框跟随 |

**这些测试是回归网，改完物理或虚影相关代码务必全跑一遍。**

---

## 8. 未完成项与建议路线

按依赖顺序，前一项不做后一项会返工：

**8.1 压力板 → 开门（最高优先级）**

这是第一关能不能通的关键。需要：
- 压力板改成 `Area2D`（或 `StaticBody2D` + 检测区），玩家或虚影站上去即触发
- 门要能「升起」：`door.tscn` 加位移/缩放动画，同时**关闭碰撞**
- 原版有「需要 N 块板同时踩」（`levels.gd` 的 `NEEDS`）和锁存语义，第一关 `NEEDS = 1`，可以先做单板版本
- 虚影是 `StaticBody2D`，站在板上同样能触发——**这正是整个游戏的第一道谜题**

**8.2 出口结算**

`exit.tscn` 现在是纯展示。加 `Area2D` 检测玩家，触发后显示通关、停输入。

**8.3 尖刺 hazard + 尸体垫脚**

`spike_tile.tscn` 已备好（`TEXTURE_RECT` 平铺）。需要 `Area2D` + `die()`。做完后用 §4.3 的 1.3 秒验证原版第 5 关的解法。

**8.4 关卡数据外置（架构债）**

现在 `level_01.tscn` 是脚本生成的，改关卡只能在编辑器里手拖。要做第 2–8 关，建议**先把 `levels.gd` 的 8 关数据转成自定义 `Resource`（`.tres`）**，再用一个 `LevelBuilder` 在运行时铺块——比复制 8 份 tscn 可维护得多，也让策划改数字而不是拖坐标。

前提：先抽 `LevelBase.tscn`（含 `RespawnPoint` / `EchoManager` / `Camera2D` / `Player`），新关卡继承它。

**8.5 与原版的已知差异**

- 原版虚影满 5 条时**禁止死亡**（按 E 无反应）；这里改成永远能死、新的顶旧的，因为没 HUD 时会像卡死
- 原版有 `draw_string` 画的关卡名/提示/操作说明；这里只有底部操作栏
- 原版死亡时 `x` 方向保留惯性滑动；这里保留了（`_tick_death` 里用 `friction` 减速）

---

## 9. 上传仓库前必读

### 9.1 版权（重要）

`_reference/source_from_game/` 是**从原版游戏 exe 反编译出来的完整工程源码**（`world.gd` / `main.gd` / `levels.gd` 等）。

- 它是**逆向工程产物**，不是我们的代码，**不能进任何公开仓库**
- 已在 `.gitignore` 里排除
- 同理，`_reference/preview_level01_original.png` 是原版游戏画面截图，也排除了

**结论：这个仓库建 Private。** 如果要公开，除了上面的排除项，还要确认 `README.md` 里「复刻」的表述方式，以及 `_reference/level01_data.py`（从原版反编译出的关卡坐标与配色常量）是否保留——保守做法是公开版把整个 `_reference/` 排除。

### 9.2 哪些进仓库，哪些不进

一共 102 个文件会入库，其中 64 个是游戏本体、38 个在 `_reference/`。

| 内容 | 进仓库 | 说明 |
|---|---|---|
| `project.godot` | ✅ **必须在根目录** | Godot 靠它在根目录认项目，挪进子目录就打不开了 |
| `assets/` `scenes/` `scripts/` | ✅ | 游戏本体，97K + 56K + 56K，不需要 Git LFS |
| `*.gd.uid` | ✅ | Godot 4.4+ 的资源 UID，**必须提交**，保证跨机器引用不乱 |
| `README.md` `HANDOVER.md` | ✅ 根目录 | GitHub 会自动渲染根目录 `README.md` |
| `.gitignore` `.gitattributes` | ✅ | 后者管换行与二进制，缺了 `.tscn` 会整片 diff |
| `_reference/tools/` | ✅（Private） | 里面有 **10 个 `test_*.gd` 回归测试**，团队要能跑；`make_*.py` 已冻结 |
| `_reference/preview_*.png` | ✅（Private） | 我们自己构建版本的截图，作为视觉基线 |
| `_reference/source_from_game/` | ❌ 已忽略 | 反编译源码，**泄露即侵权** |
| `_reference/preview_level01_original.png` | ❌ 已忽略 | 原版游戏画面 |
| `.godot/`（2.7 MB） | ❌ 已忽略 | 导入缓存，每台机器自动重建，提交必然二进制冲突 |
| `.workbuddy/` | ❌ 已忽略 | AI 协作记录 |
| `*.zip`（`YourPastSelf-2-Windows.zip`） | ❌ 不要上传 | 原版游戏包，同时踩版权和体积两个坑 |

> 公开版的差异：把 `_reference/` 整个排除，同时把 `_reference/tools/test_*.gd` 挪到 `tests/`
> （否则公开仓库既没有测试、也没有生成脚本）。这一步现在不做，等真要开源再说。

**另外 13 个 `.import` 文件也在库里**（每个 png 一个，Godot 4 的导入设置就存在这里）。
少了它们不是不能跑，但过滤/压缩参数会回落到默认值，画面可能和现在不一样——**别忽略 `.import`**。

仓库里**没有**、但也不影响跑的东西：

| 东西 | 情况 |
|---|---|
| `.godot/`（2.7 MB） | 首次打开/`--import` 自动重建，实测约十秒 |
| `export_presets.cfg` | 被忽略。要统一导出 Windows 包时再提交一份，注意里面可能带本机路径与签名信息 |
| `LICENSE` | 没放。Private 不需要；**要公开必须先选定许可证** |
| `icon.svg` | 没配，`project.godot` 里没有 `config/icon`，导出时用默认图标 |
| `_capture.gd` | 当初的临时截图脚本，已删（新截图写法见 §10） |

### 9.3 仓库里怎么摆

**单项目 = 仓库根目录就是 Godot 项目根目录。** 不要套一层 `game/` 或 `src/`，否则 `project.godot` 不在根，克隆下来引擎不认。

```
your-past-self/            ← GitHub 仓库
├── project.godot          ← 必须在根
├── README.md              ← 给策划/美术看的（GitHub 首页自动渲染这份）
├── HANDOVER.md            ← 给程序看的
├── .gitignore
├── .gitattributes
├── assets/                ← 美术换图只碰这里
├── scenes/                ← 关卡、角色、物块、UI
├── scripts/               ← 10 个 .gd
└── _reference/            ← 对照资料 + 测试（Private 才进）
```

以后真要做多项目 monorepo（比如再加一个工具站），才需要把整个 Godot 项目挪进 `game/`，
并同步改所有 `res://` 之外的本机路径——现在没必要。

### 9.4 建仓库并推送（五步）

**第 1 步：在 GitHub 建空仓库**

网页 → New repository：

| 项 | 填什么 |
|---|---|
| Repository name | `your-past-self` |
| Visibility | **Private**（见 §9.1） |
| Initialize this repository with | **全部不勾**（不要 README / .gitignore / license） |

⚠️ 一定建**空**仓库。勾了 README，GitHub 会先有一个 commit，你 push 时会被拒（`fetch first`），
新手常在这里卡住，然后被迫 `--force`，容易把东西推错。

**第 2 步：本地提交**（仓库已 `git init`，直接到第 3 步也行）

```bash
git add -A
git status --short          # 102 行左右；不该出现 .godot/ 和 source_from_game/
git commit -m "第一关复刻：地形、角色、死亡重生、虚影系统、暂停与 HUD"
```

**第 3 步：连远程并推**

```bash
git remote add origin https://github.com/<你的用户名>/your-past-self.git
git branch -M main
git push -u origin main
```

推送时会要凭据：密码那一栏**不能填账号密码**，要填 **Personal Access Token**
（GitHub → Settings → Developer settings → Personal access tokens → Fine-grained → 勾 `Contents: Read and write`）。
装了 GitHub CLI 的话更省事：`gh auth login` 之后 `gh repo create your-past-self --private --source=. --push`。

**第 4 步：验证别人能跑**

自己另找一台机器（或删掉 `.godot/` 后再打开）克隆一份，用 Godot 导入根目录，
确认：能进 `level_01`、按 `F1` 有碰撞框、10 个测试脚本能跑。
`.godot/` 不在仓库里是**正常**的，第一次打开会重建（约十几秒）。

**这一步已经实测过**：把仓库克隆到干净目录（无 `.godot/`）后
`--import` 无任何 error/warning，`test_hitbox_debug` 全项通过（脚底线与可踩线 0.00px 重合），
`--quit-after 30` 启动干净，且克隆出的 `assets/*.import` 与源仓库逐字节一致。
**结论：仓库是自洽的，只靠仓库里的 102 个文件就能跑起来。**

**第 5 步：加队友**

Settings → Collaborators 邀请；对方 `git clone` 后直接用 Godot 打开，不需要额外配置。

### 9.5 提交前自检

```bash
git status --short | wc -l                      # 预期 102 上下；几百个 = .gitignore 没生效
git status --short | grep -E "\.godot/|source_from_game"   # 必须无输出
git ls-files | grep -c "\.uid$"                 # 应有 10 个（每个 .gd 一个）
```

注意 `.gd.uid` 文件（Godot 4.4+ 生成）**应该提交**，它保证资源 UID 跨机器稳定，不要 ignore。

### 9.6 仓库描述建议

> Godot 4.7 平台解谜原型。核心机制：死亡留下重放轨迹的虚影，可踩、可穿、可当替身踩机关。

Topics 建议：`godot` `godot4` `platformer` `puzzle` `gdscript` `2d`

---

## 10. 常用命令速查

```bash
# 导入资源（新增/替换素材后）
godot --headless --path . --import

# 启动游戏
godot --path .

# 跑测试（必须带 --fixed-fps 60）
godot --headless --path . --fixed-fps 60 --script res://_reference/tools/<test>.gd

# 无头启动自检（检查场景/脚本有无加载错误）
godot --headless --path . --quit-after 20

# 美术交图后校验贴图尺寸（角色必须 28×38）
python _reference/tools/check_art_size.py

# 重新生成「可画范围」模板图（--force 覆盖）
python _reference/tools/make_art_templates.py

# 截图：仓库里没有截图脚本（早期用过的一次性 _capture.gd 已删除，别照着旧命令找）
# 需要新图时临时写一个 SceneTree 脚本，运行几帧后：
#   get_viewport().get_texture().get_image().save_png("res://_reference/preview_xxx.png")
# 必须真渲染（不能 --headless），加 --rendering-driver opengl3 更稳。
```

---

## 11. 交接时的口头补充

1. **第一关过不去不是 bug**，是压板/开门没做。别花时间找「隐藏出口」。
2. **门是实体墙**，这是上一轮需求明确要求的，不是忘加碰撞。
3. 游戏内所有视觉都是贴图，**脚本里只剩调试层还有 `_draw`**（`hitbox_debug.gd` 画黄框和橙线）。
   想改角色/物块外观，改 `assets/` 里的图；看到画面上的黄框橙线不是 bug，是按了 `F1` 或节点没隐藏。
4. 虚影系统比原版「宽容」：满 5 条还能死、R 可以随时清场。这两处是刻意偏离原版的，理由在 §8.5。
5. 数值手感原来照抄原版 `actor.gd`，**2026-11-19 起已整体重调**（满速 273、凹形起停、跳跃 115px/0.78s、下落 ×1.1、空中惯性与反向急停）。现值、逐帧实测和调参公式见 **`docs/手感调参.md`**；别再拿 `actor.gd` 的数字当预期值。
6. 交美术前先教他按 `F1`：改尺寸时只看橙线，不要拿贴图像素边缘当碰撞——这是这个项目最容易反复沟通的一件事（§3.5）。
7. 给美术交付尺寸，别口头说"大概 28×38"——直接给 `_reference/art_templates/` 里的模板图 + 一句
   `python _reference/tools/check_art_size.py`。规格与原因见 §3.6，美术版在 `README.md` §3.4。

---

## 12. 手感重调（2026-11-19）

`scripts/player.gd` 的水平移动和跳跃整套重调过，和原版数值不再一致。完整数值、逐帧实测、调参公式见 **`docs/手感调参.md`**。

| 项 | 原版 | 现在 |
|---|---|---|
| 满速 | 210 | **273** |
| 地面起步 | 1800 线性，7 帧 | **2730 凹形，6 帧** |
| 地面刹停 | 2200 线性，6 帧 | **5460 凹形，3 帧** |
| 空中起步 | 1300 线性，10 帧 | **2355 直线，7 帧** |
| 空中松手 | 跟随地面摩擦，3 帧停 | **400 阻力，0.68s / 93px 滑停** |
| 空中反向 | 约 0.32s | **2 帧归零 + 7 帧反向** |
| 跳跃 | 89px / 44 帧 | **115px / 47 帧** |
| 下落重力 | 与上升相同 | **×1.1** |

新增验证脚本：`_reference/tools/test_speed_curve.gd`、`test_air_turn.gd`、`test_air_drag.gd`、`test_jump_curve.gd`；
画图脚本在 `_reference/tools/charts/`（Python + Pillow，字体路径写死 Windows）。

副作用：满速跳距从 154px 涨到约 213px；跳高 115px，低于 115px 的天花板会撞头。关卡沟距若按旧速度摆的，需要复核。

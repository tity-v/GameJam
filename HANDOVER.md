> 后续更新：新增可通关房间 complete_room。历史场景与原始交接记录保留；新增系统、规则及测试见 docs/完整房间使用说明.md。

# 交接文档 — Your Past Self（Godot 4.7 复刻）

> 面向接手这个仓库的程序。看完能回答三个问题：**现在做到哪了、代码为什么长这样、下一步从哪下手。**
> 策划/美术看 `README.md` 就够，那份讲怎么改内容；这份讲怎么改代码。

---

## 0. 一句话

把 2D 平台解谜游戏《过去的你》的第一关搬进 Godot 4.7，并实现它的核心机制：**死后留下一个重放你上一轮动作的虚影，用虚影替你踩机关、当垫脚**。

当前状态：**机制闭环已跑通，且有一个能从头打到尾的房间** `complete_room`（压力板→双板锁存开门→出口结算，含尖刺致死与 `R` 回到初始状态）。
历史场景 `level_01` 仍是「过不去」的状态（门是实体墙、压力板不响应），保留作为对照，不是 bug。

---

## 1. 五分钟跑起来

| 项 | 值 |
|---|---|
| 引擎 | **Godot 4.7.2**（`config/features` 写死 4.7，低版本打开会提示） |
| 渲染 | `gl_compatibility`（兼容模式，老显卡/笔记本也能跑） |
| 视口 | 1280 × 720，`canvas_items` 拉伸 |
| 主场景 | `res://scenes/levels/complete_room.tscn`（`level_01.tscn` 保留为历史场景） |
| 代码规模 | 16 个脚本，共约 1154 行 GDScript；17 个回归测试 |

打开方式：Godot 项目管理器 → 导入 → 选仓库根目录（`project.godot` 在根）。

**按键**：`A/D` 移动（方向键也行）· `Space` 跳跃（长按更高）· `E` 自杀 · `R` 回到本关初始状态（清虚影 + 机关复位 + 回出生点）· `Esc` 暂停。

**每局必做的验证动作**（30 秒判断环境是否正常，以下数字对应主场景 `complete_room`）：

1. 开局站在地面，脚底 `y = 576`（角色原点 y=538）
2. 按住 `D` 跑，撞到 **x=850** 的门停住 → 说明碰撞与关卡数据都加载对了
   （门占 x 850~914、y 416~576；这里答不上来就说明场景没进对）
3. 按 `E`，方块淡出带红叉，1.3 秒后回出生点，同时留下一个蓝色虚影
4. 虚影重放完再活 1.3 秒后消失
5. 按 `F1`：角色身上出现黄色碰撞框、脚下出现橙色粗线，且橙线正好压在地面顶面（576）
6. 把门解开（回声踩 A、自己踩 B）后按 `R`：人回出生点、虚影清空、**门重新关上且能挡住人**，
   板恢复未踩状态，但场景没有重载（`R` = 回到初始状态，见 §3.2 的接入契约）

> 换成 `level_01.tscn` 时这些数字都不同（那关地面顶面 560、门在 x=790），别拿一套数去对另一关。

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
| 录制上限（`max_frames`，超出丢最旧一半） | 完成 | `echo_manager.gd` 的滚动窗口；断言见 `test_echo_recording_cap.gd` |
| 虚影尸体多存活 1.3 秒（可踩） | 完成 | `echo.gd` 的 `fade_duration` |
| `R` 回到初始状态：清虚影 + 玩家回出生点 + **机关复位**（门关上、板松开、出口熄灭） | 完成 | `echo_manager.gd` 的 `reset_all()` → `player.reset_to_spawn()` + `room_controller.reset_mechanisms()` |
| `Esc` 暂停 + 点击继续 | 完成 | `scenes/ui/pause_menu.tscn`（autoload） |
| 底部操作提示栏 + 虚影计数 | 完成 | `scenes/ui/hud.tscn`（autoload） |
| 碰撞框可视化（脚底线 / 可踩线，`F1` 开关） | 完成 | `scripts/hitbox_debug.gd` |
| **压力板 → 开门**（双板锁存） | 完成 | `scripts/pressure_plate.gd`、`scripts/puzzle_door.gd` |
| **出口结算 / 通关** | 完成 | `scripts/level_exit.gd`、`scenes/levels/complete_room.tscn` |
| **尖刺伤害判定** | 完成（**只杀玩家**，虚影无感；尖刺块本身无碰撞体） | `scripts/spike_hazard.gd` |
| **虚影对环境有体积**（压力板认、墙和关着的门挡得住、尖刺不杀、出口不认） | 完成 | `scripts/actor_bounds.gd`、`echo.gd` 的 `_clip_motion()`；断言见 `test_echo_environment.gd` |
| **房间整体重置（通关面板 Replay → 重载场景）** | 完成 | `scripts/room_controller.gd` |
| 角色脚下/身体边缘判定 | 完成 | `scripts/actor_bounds.gd`（供压力板/出口/尖刺共用） |
| 可通关房间搭建 | 完成 | `scenes/levels/complete_room.tscn`（说明见 `docs/完整房间使用说明.md`） |
| 关卡名 / 关卡提示文字（原版有） | 未做 | — |
| 第 2–8 关 | 未做 | 原数据见 `_reference/source_from_game/scripts/platformer/levels.gd` |

---

## 3. 代码结构

### 3.1 场景树（`level_01.tscn`）

> 主场景已切到 `complete_room.tscn`，它的节点结构（压力板 / 门 / 出口 / 尖刺 / 提示文字）
> 见 `docs/完整房间使用说明.md`。本节保留 `level_01` 的树，用来理解最基础的那一层。

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
| `player.gd` | 307 | 移动/跳跃手感、死亡淡出、重生、被虚影带着走 | `player.tscn` |
| `echo_manager.gd` | 179 | 录轨迹（滚动窗口上限）、生成虚影、FIFO 上限、R 重置（人回起点 → 机关复位 → 清虚影） | 关卡内节点 |
| `echo.gd` | 168 | 逐帧重放轨迹、世界阻挡（`cast_motion`）、单向碰撞、尸体淡出 | `echo.tscn` |
| `hitbox_debug.gd` | 95 | 碰撞框可视化（纯 `_draw`，不参与物理；`@tool` + F1 开关） | 玩家/虚影的 `HitboxDebug` 子节点 |
| `hud.gd` | 57 | 刷新「回声 n/5」、闪现提示淡出 | autoload `Hud` |
| `camera_follow.gd` | 48 | 水平跟随 + 边界夹取 + 瞬移归位 | 关卡内 `Camera2D` |
| `pause_menu.gd` | 41 | `Esc` 切换 `SceneTree.paused` | autoload `PauseMenu` |
| `block.gd` | 38 | `block_size` 同步贴图与碰撞（`@tool`） | 所有物块场景根 |
| `pressure_plate.gd` | 49 | 判断「谁站在板上」（玩家/虚影，可分别开关）、`reset_mechanism()` | `plate_off.tscn` |
| `level_exit.gd` | 25 | 门开后站上出口 → 结算 | `exit.tscn` |
| `puzzle_door.gd` | 37 | 多块压力板全满足才开门，带锁存；`reset_mechanism()` 会**连锁存一起忘掉** | `door.tscn` |
| `room_controller.gd` | 36 | 房间状态（`won` / `resetting`）、`reset_mechanisms()`（按 `mechanism` 组收口）、通关面板 Replay 的整关重来 | `complete_room.tscn` 根 |
| `actor_bounds.gd` | 22 | 共用「脚底/身体范围」判定工具（静态函数） | 被上面几个脚本 `preload` |
| `key_hint.gd` | 21 | 一组「键帽 + 说明」 | `key_hint.tscn` |
| `keycap.gd` | 18 | 单个键帽 | `keycap.tscn` |
| `spike_hazard.gd` | 13 | 碰到尖刺 → 致死 | `spike_tile.tscn` |

合计 16 个脚本、1154 行（`wc -l` 口径）。

**新增机关的接入契约（两条，缺一条就会「按 R 不复位」）**

1. 在 `_ready()` 里 `add_to_group("mechanism")`——`room_controller.reset_mechanisms()` 只遍历这个组，
   不按节点名找，所以加机关不用回来改控制器；
2. 实现 `reset_mechanism()`，自己把「初始状态」写完（贴图、碰撞、内部锁存标志一起）。

典型陷阱：`puzzle_door.gd` 的锁存早退是 `if opened and latch_open: return`，
复位时如果只把碰撞开回来、忘了先 `opened = false`，下一帧会直接 return，
门看起来关了却能穿——`test_complete_room.gd` 的 `R re-enables door collision` + `closed door blocks player again after R` 就是拦这个的。

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
虚影 `collision_mask = 0`——**引擎不会推它**（位置由脚本逐帧喂，见 §4.1）。
但它每帧自己做一次 `cast_motion`，只扫 `World` 层来截短这一步的位移，所以墙和关着的门挡得住它（§4.3）。
「mask = 0」和「会被挡住」并不矛盾：前者是**不做碰撞响应**，后者是**先查询再决定走多远**。

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
| 物块 | 九宫格源图，尺寸必须和 §4.5 的表一致（改了要同步 tscn 里的 patch margins） |

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

⚠️ 这张表只描述**虚影对玩家的关系**（谁能穿过谁）。反方向——**世界对虚影**——已经改成「挡得住」，
见 §4.3。两件事别混：虚影不是墙，但它自己会撞墙。

### 4.3 虚影自己会被世界挡住，但不交给物理

这条是 2026-11-19 后期加的，**推翻了原先「虚影穿墙不是 bug」的结论**。改之前先看这里的三个约束。

需求是「虚影不能穿墙、不能穿关着的门」。最直觉的做法是给 `echo.tscn` 加 `collision_mask = 1`，
**这是错的**：虚影是 `StaticBody2D`，位置由脚本每帧喂进去，一旦开启 mask，引擎会在物理步里推它，
和喂进来的坐标互相打架——表现是抖动、回弹、被挤出门外，整关错位。

实际做法是**每帧把这一步的位移截短**（`echo.gd`）：

```gdscript
last_delta = _clip_motion(frames[next] - frames[frame_index])
global_position += last_delta      # 增量，不是赋值成记录坐标
```

`_clip_motion()` 用 `PhysicsDirectSpaceState2D.cast_motion`（形状扫描）问一句「这一步能走多远」，
撞上就只走到接触点。三个细节都不能省：

| 细节 | 为什么 |
|---|---|
| **必须增量推进** | 原来写 `global_position = frames[next]`。被墙截住之后，若记录轨迹跨过那面墙，绝对赋值会在下一帧直接**隧穿**过去，扫描等于白做 |
| **只扫 layer 1（World）** | 虚影之间不互相挡、玩家也推不动它。多扫一层就会出现「虚影被另一个虚影卡住」这种没人想调的行为 |
| **扫描形状内缩 1px**（26×36 塞在 28×38 里） | 不内缩的话，「脚正好贴地」这种静止接触会被判成碰撞，虚影一出生就卡在原地 |

**代价（关卡设计约束）**：被挡住时**帧号照常前进**，只是位置停在墙边。于是会出现
「录的时候门开着、重放时门关着 → 虚影卡在门外，永远走不到门里的压力板」。
这是新规则的必然结果，不是 bug。**别设计「关键路线依赖一扇之后会关的门」的关卡**，否则那关无解。

断言在 `test_echo_environment.gd`（19 条），其中三条专盯这条规则：
`closed door blocks echo` / `echo stops at the door surface, not inside it` / `open door lets echo through`。
门占 x=850~914，测试里虚影从 x=790 每帧 5px 向右，实测停在 **x≈823**（身体右边正好贴到 850）。

### 4.4 虚影比玩家多活 1.3 秒，且与玩家同一条时间轴

玩家的时间轴是「活 T 秒 → 死 1.3 秒」；虚影是「重放 T 秒 → 死 1.3 秒」。所以它**天然比玩家晚 1.3 秒消失**，不是额外加了个计时器。

这 1.3 秒里**碰撞仍然开着**，这是后面做尖刺关的支点：踩在尸体头上跨过尖刺。

⚠️ **但别照原版的做法理解**。本作的尖刺**不杀虚影**（`spike_hazard.gd` 只遍历 `player` 组），
尖刺块本身也**没有碰撞体**（`spike_tile.tscn` 里只有 `Patch`，没有 `Collision`）。
所以原版第 5 关那种「让回声掉进尖刺、它自己死在上面」在这里**不成立**——
虚影会直接穿过尖刺，继续走完轨迹。

现在的替代解法是「**玩家自己死在尖刺上**」：死亡位置就是虚影轨迹的终点，
重放结束时尸体正好落在尖刺处，再趁这 1.3 秒踩上去。代价是时机要算准
（尸体出现 = 复活后再过"虚影时长"那么久）。想做回原版那种，得让 `spike_hazard`
也判定虚影、命中就提前进入淡出——那是设计选择，见 §13。

相关数值：`echo.gd` 的 `fade_duration = 1.3`（对齐 `player.gd` 的 `death_duration`）、`death_min_alpha = 0.18`（尸体不会彻底看不见，踩上去脚下始终有东西）。

### 4.5 物块尺寸收敛到 `block_size`，贴图用九宫格

以前地面是 1800×120 的整图，美术必须画准尺寸，改尺寸要同步改碰撞 `size` + `position` + 关卡摆放坐标三处。

现在：物块场景根节点挂 `block.gd`，`@export var block_size` 是**唯一尺寸来源**，setter 同步 `Patch.size` 与 `Collision`（含居中偏移）。脚本标 `@tool`，编辑器里改完碰撞框立刻跟着动。

贴图随之改成小尺寸源图（地面 32×32、出口 16×16、门 8×8），`NinePatchRect` 拉伸时边角不变形；尖刺用 `TextureRect` + `TILE` 平铺而不是拉伸。

`RectangleShape2D` 加了 `resource_local_to_scene = true`——**不加的话同类物块的所有实例共享一份 shape，改一个全变**。

### 4.6 素材生成器全部「已存在则跳过」

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
| 虚影被门挡住，没走到压力板上 | **不是 bug**：虚影每帧做 `cast_motion`，撞上就停在接触点，而帧号继续走。录的时候门开着、重放时门关着就会这样 | 关卡设计上避免「关键路线依赖一扇之后会关的门」；要放开就查 `echo.gd` 的 `_clip_motion`（README §6.1） |
| 按 `R` 之后门又关上了，以为「开门白解了」 | **设计如此**：R 是「回到本关初始状态」，虚影与机关一起复位 | 想保留开门进度就别按 R；整关重来（含节点重建）仍是通关面板的 Replay |
| 按 `R` 之后门看着关了，人却能穿过去 | `puzzle_door.reset_mechanism()` 里只开了碰撞、没先把 `opened` 置 false，`latch_open` 的早退分支下一帧就 return | 顺序必须是 `opened = false` → `$Collision.set_deferred("disabled", false)`；断言见 `test_complete_room` |
| 新加的机关按 `R` 不复位，其它机关正常 | 忘了登记 `mechanism` 组，或没写 `reset_mechanism()` | 照 §3.2「新增机关的接入契约」两条做 |
| 虚影压板时灵时不灵，或换皮后范围变大 | 压力板取的是 `Body` **贴图矩形**当体积，贴图尺寸变了判定就变 | `echo_body.png` 保持 28×38；`test_echo_environment.gd` 第 1 条就是这个断言 |

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

`spike_tile.tscn` 已备好（`TEXTURE_RECT` 平铺）。需要 `Area2D` + `die()`。做完后用 §4.4 的 1.3 秒验证原版第 5 关的解法。

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

一共 160 个文件会入库：`scripts/` 32（16 个 `.gd` + 16 个 `.uid`）、`assets/` 45、
`scenes/` 15、`docs/` 10、`_reference/` 53、根目录 5。
（数字会随开发变，以 `git ls-files | wc -l` 为准；结构稳定的是「哪些该进、哪些不该进」。）

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
git status --short          # 160 行左右；不该出现 .godot/ 和 source_from_game/
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
确认：能进 `complete_room`、按 `F1` 有碰撞框、17 个测试脚本能跑。
`.godot/` 不在仓库里是**正常**的，第一次打开会重建（约十几秒）。

**这一步已经实测过**：把仓库克隆到干净目录（无 `.godot/`）后
`--import` 无任何 error/warning，`test_hitbox_debug` 全项通过（脚底线与可踩线 0.00px 重合），
`--quit-after 30` 启动干净，且克隆出的 `assets/*.import` 与源仓库逐字节一致。
**结论：仓库是自洽的，只靠仓库里的文件就能跑起来**（截至 `9af6e71` 为 159 个文件）。

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
8. **虚影会被墙和关着的门挡住，但绝不要给它加 `collision_mask`**。挡住靠的是每帧 `cast_motion`
   截短位移（§4.3）；加 mask 会让引擎去推它，和喂进去的坐标打架，整关错位。
   同理，看到「虚影卡在门外没踩到板」先查关卡设计，别急着改碰撞层。

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

---

## 13. 系统审计：已知限制（确认存在、但没改）

2026-11-19 把虚影 / 机关 / 死亡链路逐行过了一遍。下面是**确认存在但刻意没动**的东西，
按优先级排；改之前先看「影响」，有些是真的不用修。

| 现象 | 真正的原因 | 影响 | 建议 |
|---|---|---|---|
| 虚影的**起始帧**如果和碰撞体重叠，会直接穿出去 | `cast_motion` 只判扫掠碰撞，不管"一开始就重叠" | 门在虚影身上关闭、或关卡中途改了地形才会遇到。实测：从门内 x=870 起步，40 帧后走到 1065，整扇门穿过去了 | 触发条件窄，**暂时接受**。真要做，在 `setup()` 里先用 `intersect_shape` 把起点推到空位 |
| 虚影贴墙时"粘"住，不沿墙滑 | `_clip_motion` 只截短位移，不做滑动求解 | 录的是"贴着墙滑下去"的路径时，虚影的水平分量被吃掉（垂直方向仍然正常） | 要滑就得对 `cast_motion` 结果做投影，会引入和录制路径的偏差，**不建议现在做** |
| 尖刺不杀虚影 | `spike_hazard.gd` 只遍历 `player` 组；尖刺块本身也没有碰撞体 | 原版「让回声掉进尖刺」不成立，得改成玩家自己死在尖刺上（§4.4） | 设计选择。要改就命中虚影时让它进入淡出，同时补断言 |
| `R` 不是"重载场景" | `R` 走 `reset_all()`：人回起点、机关复位、虚影清空，但**节点不重建**（相机、HUD、录制对象都还在） | 效果上等价于回到初始状态；只有极少数依赖 `_ready()` 重新初始化的状态才需要 Replay | 若哪天加了"只在本局内累计"的状态（如计时器、收集数），记得在 `reset_mechanisms()` 或 `reset_all()` 里一起清 |
| 三个关卡是复制粘贴 | `level_01` / `complete_room` / `office_build` 各存一份 Player + EchoManager + Camera | 改一个机制要改三处，最容易漏的是新加的那关 | 抽 `LevelBase.tscn`（§3 结尾也提过） |
| `kill_y = 750` 写在玩家节点上 | 沿用原版常量 | 做比 750 更高的关卡要逐实例改 | 改成关卡级参数，或跟相机视野算 |
| 机关每帧都 `get_nodes_in_group` | `actor_bounds.actors()` 每次调用都新建数组 | 5 条虚影的规模下无所谓（每帧 3 次小分配） | 别提前优化，机关数量上百再说 |

**本轮已修掉的**：录制上限满 100 秒后只是"停止追加"，虚影重放的是这一生**最初**的 100 秒，
尸体落在几百像素之前（实测调成 1 秒上限时差 320px）。现在改成滚动窗口丢最旧一半，
保留最近一段，尸体落点回到死亡处，断言在 `test_echo_recording_cap.gd`。

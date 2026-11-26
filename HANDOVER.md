> 后续更新：新增可通关房间 complete_room。历史场景与原始交接记录保留；新增系统、规则及测试见 docs/完整房间使用说明.md。

# 交接文档 — Your Past Self（Godot 4.7 复刻）

> 面向接手这个仓库的程序。看完能回答三个问题：**现在做到哪了、代码为什么长这样、下一步从哪下手。**
> 策划/美术看 `README.md` 就够，那份讲怎么改内容；这份讲怎么改代码。

---

## 0. 一句话

把 2D 平台解谜游戏《过去的你》的第一关搬进 Godot 4.7，并实现它的核心机制：**死后留下一个重放你上一轮动作的虚影，用虚影替你踩机关、当垫脚**。

当前状态：**有完整入口和第一章**——启动进 `frontend/entry.tscn` 主菜单，四章 × 五间共 20 关的目录里
第一章五间已接入并能连着打通（`scenes/levels/chapter_01_room_01..05.tscn`，灰盒块拼）。
机制示例房间 `complete_room` 保留：压力板 → 双板同时踩住才开门（松开任一板就关，见 §4.8）→ 出口结算，
含尖刺致死与 `R` 回到初始状态。
历史场景 `level_01` 仍是「过不去」的状态（门是实体墙、压力板不响应），保留作为对照，不是 bug。

---

## 1. 五分钟跑起来

| 项 | 值 |
|---|---|
| 引擎 | **Godot 4.7.2**（`config/features` 写死 4.7，低版本打开会提示） |
| 渲染 | `gl_compatibility`（兼容模式，老显卡/笔记本也能跑） |
| 视口 | 1280 × 704（= 40 × 22 个 32px 瓦片），`canvas_items` 拉伸 |
| 主场景 | `res://frontend/entry.tscn`（主菜单 → 选章 → 章内选关 → 关卡）；单房间调试打开房间按 **F6** |
| 代码规模 | `scripts/` 17 个脚本约 1333 行，另有 `frontend/`（10 个）与 `graybox/`（6 个）；24 个回归测试 + 前端 2 套 + 灰盒 2 套 |

打开方式：Godot 项目管理器 → 导入 → 选仓库根目录（`project.godot` 在根）。

**按键**：`A/D` 移动（方向键也行）· `Space` 跳跃（长按更高）· `E` 自杀 · `R` 回到本关初始状态（清虚影 + 机关复位 + 回出生点）· `Esc` 暂停。

**每局必做的验证动作**（30 秒判断环境是否正常，以下数字对应机制示例房间 `complete_room`）：

1. 开局站在地面，脚底 `y = 576`（角色原点 y=532，碰撞高 44）
2. 按住 `D` 跑，撞到 **x=832** 的门停住 → 说明碰撞与关卡数据都加载对了
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
| **压力板 → 开门**（双板同时踩住才开；松开任一板就关，但门口站着玩家时会等它走出去再关） | 完成 | `scripts/pressure_plate.gd`、`scripts/puzzle_door.gd`；断言见 `test_door_safety.gd` |
| **出口结算 / 通关** | 完成 | `scripts/level_exit.gd`、`scenes/levels/complete_room.tscn` |
| **尖刺伤害判定** | 完成（**只杀玩家**，虚影无感；尖刺块本身无碰撞体） | `scripts/spike_hazard.gd` |
| **虚影对环境有体积**（压力板认、墙和关着的门挡得住、尖刺不杀、出口不认） | 完成 | `scripts/actor_bounds.gd`、`echo.gd` 的 `_clip_motion()`；断言见 `test_echo_environment.gd` |
| **虚影的位移扫描与玩家同源**（单向台面能从下往上穿、实心墙/关着的门照样挡） | 完成 | `echo.gd` 的 `_cast_motion()`：隐形 `CharacterBody2D` + `move_and_collide(test_only)`；断言见 `test_echo_oneway.gd` |
| **拉杆拨过就不再挡人**（是开关不是门，玩家和虚影都能穿过） | 完成 | `lever.gd` 拨动后碰撞体保持禁用，只有 `reset_mechanism()` 才恢复；断言见 `test_lever_pass.gd` |
| **虚影判定体积与贴图解耦**（`body_size`，换皮不改谜题） | 完成 | `echo.gd` 的 `body_rect()` / `fit_visuals()`；断言见 `test_echo_contract.gd` |
| **虚影单一激活状态**（回放 / 碰撞 / 机关同源，不会“看不见却挡人”） | 完成 | `echo.gd` 的 `_active`、`setup()` / `reset()`；断言见 `test_echo_contract.gd` |
| **房间整体重置（通关面板 Replay → 重载场景）** | 完成 | `scripts/room_controller.gd` |
| **关卡网格**：整屏 40×22 格 × 32px、空瓦片铺满整张地图、机关全部贴格线 | 完成 | `assets/tiles/`、`_reference/tools/room_grid.py`；断言见 `test_grid_room.gd`，说明见 §3.7 |
| **楼内布景**：天花板梁 + 墙面色带 + 立管 + 接地阴影 + 踢脚 + 前景立柱，纯画面不参与碰撞 | 完成 | `scenes/levels/old_building/dressing.gd`（挂在 `old_building/base.tscn` 的 `Dressing` z=-3 与 `Foreground` z=1），窗/通风口/地面轮廓自动从兄弟节点推导 |
| **灰盒搭建套件**（同学交付）：模板场景、机关零件、编辑器预览、独立验收 | 完成 | `graybox/README.md`；验收 `graybox/tests/test_graybox_kit.gd` |
| **游戏前端**（同学交付）：主菜单 / 选章 / **章内选关** / 暂停 / 设置 / 结算 / 全通 / 存档，20 关目录、章内换房 | 完成 | `frontend/README.md`；验收 `frontend/tests/test_frontend.gd` |
| **第一章五间**（同学交付）：块拼房间，各自一套压板/门/出口 谜题 | 完成 | `scenes/levels/chapter_01_room_0*.tscn` |
| **人物两帧待机动画**（眨眼），外观与判定解耦 | 完成 | `scripts/character_portrait.gd`；说明 `docs/人物动画与尺寸调整.md`，断言 `test_character_portrait.gd` |
| 角色脚下/身体边缘判定 | 完成 | `scripts/actor_bounds.gd`（供压力板/出口/尖刺共用） |
| 可通关房间搭建 | 完成 | `scenes/levels/complete_room.tscn`（说明见 `docs/完整房间使用说明.md`） |
| **第三章黑幕照明**（全屏 shader 按光源挖椭圆洞，`falloff` 控制由内向外衰减） | 完成 | `scenes/levels/dark_building/blackout.gdshader`、`blackout.gd` |
| **打火手电**（`Shift`：底光 40/90 ↔ 打火 96/150，亮 2.5s / 冷却 1.5s） | 完成 | `scenes/levels/chapter_03/torch.gd` |
| **3-1 打火教学原型**（坑 / 96px 高台 / 虚影经过把铁栅抬起来） | 原型可玩 | `scenes/levels/chapter_03/room_31_proto.tscn`（已占目录 `level_11`，主界面 → 第 3 章 → 第 1 间即可进）；断言 `test_room31.gd` 23 条 |
| **3-2 光控升降原型**（双竖井四段 / 两块光敏板 / 火盆替身供光 / 无光先滑再落） | 原型可玩 | `scenes/levels/chapter_03/room_32_proto.tscn`（已占目录 `level_12`）；断言 `test_room32.gd` 49 条 + `test_room32_loop.gd` 15 条（真录制→重放→两段换乘→撞出口通关的完整闭环）；R 复位 / 砸人 / 掉进凹槽被压（单向板死锁）/ 自己打火 `test_chapter3_edge.gd` 44 条 |
| **试玩解锁**（`catalog.preview_unlock`）：跳过顺序解锁，任意章任意已接入的房间可直接点 | 完成，当前为 `true` | `frontend/db/catalog.tres` 的 `preview_unlock`；正式版本需设回 `false`，否则顺序解锁失效 |
| 关卡名 / 关卡提示文字（原版有） | 未做 | — |
| 第 2–8 关 | 未做 | 原数据见 `_reference/source_from_game/scripts/platformer/levels.gd` |

---

## 3. 代码结构

### 3.1 场景树（`level_01.tscn`）

> 主场景现在是 `frontend/entry.tscn`（前端会话层，按目录换场景）。机制示例房间 `complete_room`
> 的节点结构（压力板 / 门 / 出口 / 尖刺 / 提示文字）见 `docs/完整房间使用说明.md`；
> 本节保留 `level_01` 的树，用来理解最基础的那一层。

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
| `echo.gd` | 288 | 逐帧重放轨迹、世界阻挡（隐形 `CharacterBody2D` 的 `move_and_collide(test_only)`，与玩家同源）、单向碰撞、尸体淡出；`body_size`（判定体积）、`_active`（唯一激活状态） | `echo.tscn` |
| `hitbox_debug.gd` | 95 | 碰撞框可视化（纯 `_draw`，不参与物理；`@tool` + F1 开关） | 玩家/虚影的 `HitboxDebug` 子节点 |
| `hud.gd` | 57 | 刷新「回声 n/5」、闪现提示淡出 | autoload `Hud` |
| `camera_follow.gd` | 48 | 水平跟随 + 边界夹取 + 瞬移归位 | 关卡内 `Camera2D` |
| `pause_menu.gd` | 41 | `Esc` 切换 `SceneTree.paused` | autoload `PauseMenu` |
| `block.gd` | 38 | `block_size` 同步贴图与碰撞（`@tool`） | 所有物块场景根 |
| `pressure_plate.gd` | 49 | 判断「谁站在板上」（玩家/虚影，可分别开关）、`reset_mechanism()` | `plate_off.tscn` |
| `level_exit.gd` | 25 | 门开后站上出口 → 结算 | `exit.tscn` |
| `puzzle_door.gd` | 54 | 多块压力板全满足才开门；松开任一板就关，关之前先看门口有没有玩家（`_player_in_doorway()`，避免把人夹死）；`reset_mechanism()` 是硬关 | `door.tscn` |
| `room_controller.gd` | 36 | 房间状态（`won` / `resetting`）、`reset_mechanisms()`（按 `mechanism` 组收口）、通关面板 Replay 的整关重来 | `complete_room.tscn` 根 |
| `actor_bounds.gd` | 34 | 共用「脚底/身体范围」判定工具（静态函数；虚影只读 `body_size` 与 `is_active()`） | 被上面几个脚本 `preload` |
| `key_hint.gd` | 21 | 一组「键帽 + 说明」 | `key_hint.tscn` |
| `keycap.gd` | 18 | 单个键帽 | `keycap.tscn` |
| `spike_hazard.gd` | 13 | 碰到尖刺 → 致死 | `spike_tile.tscn` |

合计 16 个脚本、1244 行（`wc -l` 口径）。

**第三章 3-1 / 3-2 专用（挂在原型关卡的节点上，不在上表）**

| 脚本 | 职责 |
|---|---|
| `torch.gd` | 玩家手电：`Shift` 打火 2.5s / 冷却 1.5s；注册 `torch_light`，黑幕与光敏板都读它的 `radii` |
| `light_sensor.gd` | 光敏板：光斑**覆盖**判定（`radii.x ≥ min_radius` 且光心到板心距离 ≤ `radii.x`）；`rail_local_x` 决定它指哪条井壁导轨；`hint_fire` / `hint_lit` 可换文案 |
| `lift.gd` | 光控平台：有光加速升、无光先刹再落；`bottom_y` / `top_y` 定行程，`rail_x` 对齐井壁导轨。同一脚本可挂多个实例（3-2 用了两个） |
| `brazier.gd` | 火盆：可点燃的替身光源。引燃 1.2s（`t²` 曲线）→ 烧 6s → 渐灭 1.5s；`radii` 从 0 涨到 140/190 |
| `specter.gd` / `gate.gd` | 3-1 的预告虚影与铁栅（都进 `mechanism` 组） |

**新增机关的接入契约（两条，缺一条就会「按 R 不复位」）**

1. 在 `_ready()` 里 `add_to_group("mechanism")`——`room_controller.reset_mechanisms()` 只遍历这个组，
   不按节点名找，所以加机关不用回来改控制器；
2. 实现 `reset_mechanism()`，自己把「初始状态」写完（贴图、碰撞、内部状态一起）。

典型陷阱：复位门时如果只把碰撞开回来、忘了先把 `opened` 置回 false，下一帧的
`_physics_process` 会认为「状态没变」直接 return，门看起来关了却能穿。
顺序必须是 `opened = false` → `$Collision.set_deferred("disabled", false)`，
`test_complete_room.gd` 的 `R re-enables door collision` + `closed door blocks player again after R` 就是拦这个的。

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

- 出生点 `(90, 516)`，主角 32×44 → 脚底 560 = 地面顶部
- 物块也是左上角对齐（`CollisionShape2D.position` 自动取 `block_size / 2`）
- `Camera2D` 需要用 `target_center_offset_x = 14` 补回半个身位

**执行顺序**：`EchoManager.process_physics_priority = -10`，保证每帧**先推进虚影、再跑玩家**。玩家靠 `_carry()` 读虚影的 `last_delta` 被带着走。如果把这个值改掉，站在移动虚影头上会开始抖。

### 3.5 碰撞可视化（`hitbox_debug.gd`）

玩家和虚影场景里各挂了一个 `HitboxDebug` 子节点，用 `shape_path` 指向同级 `CollisionShape2D`，
把那个 shape 的矩形**原样读出来画一遍**——所以框永远等于真实碰撞，不存在「画一套、判定另一套」。

| 节点 | 画的内容 | 意义 |
|---|---|---|
| `player.tscn / HitboxDebug` | 黄色框 32×44 + **底边橙色粗线**（`feet_line`） | 框是「能不能钻过缝」，橙线是真正踩地的那条边 |
| `echo.tscn / HitboxDebug` | 青绿框 32×8 + **顶边橙色粗线**（`stand_line`） | 薄片就是虚影唯一的实体部分，橙线是可踩面 |

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

> 给美术看的版本是 `README.md` §3.4（那边是「怎么画」）。这里写「为什么是这样」，
> 接手程序改角色尺寸前先读完这一节。

**一句话：判定和外观是两套数字，互不影响。** 判定 32×44（玩家取 `Collision.shape.size`，
虚影取 `body_size`）；外观固定 **48 高**、底部对齐，宽度由画布自己的长宽比决定。
判定永远不读贴图——这是 11-19 那次 `body_size` 改造定下的规则，别退回去。

11-19 之前是另一套：贴图 1:1 当判定，画布必须正好 28×38。那时换一张稍大的图就会改谜题
（多留几像素透明边，"刚好碰不到"的压力板变成"踩得到"）。现在的规则：

| 项 | 规则 |
|---|---|
| 判定 | 玩家 32×44；虚影 32×44（`body_size`） |
| 外观 | 高 = 判定高 × `visual_height_ratio`（48/44）≈ **48**；宽 = 48 × 画布宽 ÷ 画布高（380×400 → 45.6） |
| 对齐 | 画布**底边** = 碰撞底边，所以人物比碰撞框高 4px，头发可以伸出判定范围 |
| 虚影可踩薄片 | 碰撞框顶部那条，宽 = `body_size.x`、高 8；人物头顶比它高 4px |
| 死亡叉号 | 仍按 `碰撞尺寸 / design_size(28×38)` 缩放——它标的是**判定矩形**，不是人物剪影 |
| 换图 | 换 `Sprite.texture`（闭眼帧填 `blink_texture`），或运行时 `set_art(睁眼, 闭眼)` + 再调 `fit_visuals()` |
| 旧图 | `actors/player.png`、`echo/echo_body.png` 是 28×38 的占位图，场景已不引用，留作参考 |

**踩过的坑（11-20 修掉）**：`character_portrait` 过去每帧硬写 `texture = 常量`，
美术把新 png 拖到 `Sprite` 上完全没有反应；`fit_to_body()` 又拿常量图的高度算比例，
换一张不同尺寸的图会被缩成几像素。现在睁眼帧取场景里的贴图、比例按当前贴图算，
换角色只改资源，不用动脚本。

**交付给美术的三件东西**（缺一件就会反复返工）：

1. 画布说明：`README.md` §3.4 的四条硬规则（画布比例决定胖瘦、判定不跟贴图、脚底对齐、虚影头顶要平）
2. 交图校验 `python _reference/tools/check_art_size.py`（尺寸类别不对会 `BAD`）
3. 游戏里按 `F1`：黄框贴住角色、橙线压在地面，才算对

**一条纪律**：规则只写在 `README.md` §3.4，本文件只保留程序必须知道的**因果与数字**。
改规则时改 README，别在两个文件里各维护一份——之前出现过 README 写"可以画 4 倍等比缩放"
而引擎实际不缩放，美术照做后全部返工。**凡是"引擎会帮你缩放"的直觉，先写测试验证再写进文档。**

---

### 3.7 关卡网格：40 × 22 格，每格 32 × 32 像素

> 给策划/美术看的操作版是 `README.md` §四。这里写「为什么长这样」和「改的时候会踩什么」。

**一句话：一个房间 = 40 × 22 个瓦片 = 1280 × 704 像素 = 正好一屏。像素坐标除以 32 就是格子坐标。**

改之前房间是「16px 的美术图集 + 节点 `scale = 2`」凑出来的：引擎里一格占 32px，画布上只有 16px，
策划在编辑器里量的格子和美术手上的图差一倍；地图边界其实只是那块 `Polygon2D` 底色，
哪一格能站、哪一格是空的，只能靠猜和试。现在图集本身就是 32×32、节点 `scale = 1`：

| 项 | 值 |
|---|---|
| 格子 | 32 × 32 px |
| 地图 | 40 列 × 22 行 = 1280 × 704 px |
| 视口 | 1280 × 704（`project.godot`）——一屏就是一关，不需要相机滚动 |
| 地面顶边 | y = 576（第 18 行的上边线），玩家脚底就踩在这条线上 |
| 相机 | 固定 (640, 352)，即房间中心 |

**房间场景的三个瓦片层**（顺序 = 绘制顺序，后面的盖在前面的上面）：

```
Background        Polygon2D      1280×704 纯色底，垫在最后
Map_Placeholder   TileMapLayer   880 个空瓦片（air 0:1）铺满整张地图，collision_enabled = false
World             TileMapLayer   地表 / 内层 / 两侧墙，有碰撞——玩家和虚影撞到的是这一层
Decor             TileMapLayer   装饰，无碰撞，留给美术
```

**空瓦片（`air`）为什么值得单独存在**：地图边界不再是「背景色块大概多大」，而是 880 个格子里
实打实的瓦片。策划在编辑器里能直接数格子、框选一片整体移动；美术拿到的是同一张 40×22 的纸，
不会出现「我以为这里还能画，其实是空的」。游戏里它只有一条 alpha≈40 的极淡格线，看得出网格，
但不抢戏。

**图集** `assets/tiles/placeholder_32.png`（4×2 格，`make_grid_tiles.py` 生成）：

| atlas 坐标 | 名字 | 语义 | 碰撞 |
|---|---|---|---|
| (0,0) | solid_top | 地表，顶部 3px 高光 | 实心 ±16 |
| (1,0) | solid_fill | 地下内层 | 实心 ±16 |
| (2,0) | solid_wall | 竖直墙体（右侧加深） | 实心 ±16 |
| (3,0) | one_way | 单向板，只占顶部 8px | one_way |
| (0,1) | air | 空瓦片，铺满整张地图 | 无 |
| (1,1) | decor | 装饰板 | 无 |
| (2,1) | spawn_mark | 出生点标记 | 无 |

**机关也在这张网格上**（`block_size` 不变，只是位置贴到格线）：

| 机关 | 像素矩形 | 格子 | 规则 |
|---|---|---|---|
| 出生点 | (128, 532, 32×44) | x = 4 列 | 脚底 576 |
| 尖刺 | (32, 544, 64×32) | 1–2 列, 17 行 | 底边贴 576 |
| 压力板 A / B | (352 / 640, 564, 64×12) | 11 / 20 列, 17 行 | 宽 2 格，底边贴 576 |
| 门 | (832, 416, 64×160) | 26–27 列, 13–17 行 | 2×5 格，底边贴 576 |
| 出口 | (1120, 448, 64×128) | 35–36 列, 14–17 行 | 2×4 格，底边贴 576 |

判定规则统一成一句：**左边贴 32 的倍数、底边贴 576、宽是 32 的倍数**。`test_grid_room.gd`
逐个机关断言这三条，谁挪了半个格子会当场炸。

**改地图的两条路**：

1. **在编辑器里刷** `World` 层（就是普通 TileMapLayer，画完保存即可）——适合局部调整
2. **改 `_reference/tools/room_grid.py` 的 `LAYOUT`**（40 个字符 × 22 行，图例在文件头），
   再 `python _reference/tools/make_room.py --force` 重新生成；加 `--preview` 只出预览图不动场景

第 2 条存在的理由：瓦片数据是二进制（2 字节头 + 每格 12 字节），人眼从 `.tscn` 里看不出哪格错了；
整张地图重排时用 ASCII 描述比在编辑器里一格一格点更可靠，也方便 diff 和 review。
`make_room.py` 的重写是幂等的：只替换 `Background` 到 `RespawnPoint` 之间那一段，机关和 UI 不碰。

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
| **扫描形状内缩 1px**（31×43 塞在 32×44 里） | 不内缩的话，「脚正好贴地」这种静止接触会被判成碰撞，虚影一出生就卡在原地 |

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

### 4.7 虚影的两个「单一真相」：`body_size` 与 `_active`

这一节是给以后改虚影的人看的。两条规则各自只允许有一个来源，破了就会出现
「美术换张图把谜题改了」和「看不见的虚影把板压住了」这类极难定位的问题。

**① 判定体积 = `body_size`，不是贴图**

| 用途 | 取什么 |
|---|---|
| 机关判定（压力板） | `echo.body_rect()` → `Rect2(global_position, body_size)` |
| 撞墙扫描（`_clip_motion`） | probe = `body_size` 内缩 1px（32×44 → 31×43） |
| 头顶可踩薄片 | 宽度 = `body_size.x`，高度固定 8 |
| 外观（Body） | `character_portrait.fit_to_body()`：高 = `body_size.y × 48/44`（44 → 48），宽按**画布自己的长宽比**，底部对齐 |

改之前是反过来的：`Body` 贴图矩形直接当判定，贴图多留 2px 透明边，
「刚好碰不到」的压力板就变成「踩得到」。现在换任何尺寸的图都只改外观
（等比缩放到 48 高、底部对齐），判定仍是 `body_size` 32×44。
对应断言在 `test_echo_contract.gd`（`set_art()` 换成 56×76 的图后 `body_rect()` 仍是 32×44、
外观保持原图长宽比且脚底对齐、4px 重叠仍算踩住、完全离开仍不算）。

⚠️ `Top` 的 shape 是场景里的 `sub_resource`，多实例共享。`fit_visuals()` 里先
`duplicate()` 再改尺寸，否则改一个虚影的身体尺寸会把全场虚影的薄片一起改掉。

**② 激活状态 = `_active`，不是 `visible`**

`_active` 同时决定四件事：显示、碰撞层 bit 3（值 4）、`advance()` 是否推进、机关是否认它。

| 时刻 | `_active` | 说明 |
|---|---|---|
| `setup(trail)` 刚生成（玩家还在死亡淡出） | `false` | 不显示、无碰撞、帧号停在 0，压力板不认 |
| 玩家复活 → `reset()` | `true` | 三件事同时生效，从第 0 帧开始重放 |
| 播完进入 1.3s 淡出 | `true` | 尸体仍能踩、仍压得住板 |
| `_complete()` 淡出结束 | `false` | 显示与碰撞一起撤掉，机关随即释放 |

改之前是分裂的：`setup()` 里直接把碰撞层打开，`echo_manager` 再 `visible = false`，
而 `advance()` 照常推进——于是同一具虚影「物理上存在、机关上不存在」，
玩家死亡那 1 秒多里可能被一个看不见的平台托住。

**所以：以后让虚影出现，只调 `reset()`，不要手改 `visible`。**
同理，机关判断虚影在不在场，只调 `is_active()` / `actor_bounds.available()`，不要看 `visible`。

---

### 4.8 门「松开就关」，但绝不允许关在玩家身上

门的语义在 11-19 改过一次：**去掉了 `latch_open`（锁存）**，现在是「所有关联压板同时被踩住
才开，松开任意一块就关」。这样第一章五间房能用同一套门，也让「两条回声各踩一块板、你自己穿过去」
变成真正的时间配合题，而不是一次开门永久通行。

代价是门可能正好关在玩家身上，而 **CharacterBody2D 一旦被 StaticBody2D 包住就推不动**——
实测把玩家放在门洞里按住 `D` 跑 130 帧：`x` 一个像素都没变，`y` 在 543↔564 之间抖动，
除了按 `R` 没有别的出路。所以 `puzzle_door._physics_process()` 在关门前多做一步：

```gdscript
if not satisfied and _player_in_doorway():
    return          # 门口有人：先不关，等人走出去
```

三条边界，改之前先读：

1. **只认玩家，不认虚影**。虚影被门关住只是看着卡住，不会造成软锁；反过来让虚影也能顶门，
   一条刚好停在门口的轨迹就能把门永久撑开。
2. **R 复位是硬关**，不看门口——调用前玩家已经被送回出生点（`reset_all()` 的顺序：人 → 机关 → 虚影）。
3. 这不是「延迟关门的动画」，而是**状态机不前进**：`opened` 保持 true、碰撞保持关闭，
   所以这期间出口依旧可用。断言在 `test_door_safety.gd`（人站门里不关 / 能走出去 / 走后补关 /
   关上是墙 / 虚影顶不开门）。

这个守卫原来写在 `graybox/glue/door.gd` 的 `safety_player` 字段上（需要手动接线）。现在收进核心脚本，
自动扫 `player` 组，`safety_player` 字段和相关提示已删除。

### 4.9 换场只有两种，且方向必须和出生位置配对

房间正好一屏（40×22 格 = 1280×704），所以换场是「整屏替换」，不是卷轴。语法只有两条：

| 情况 | 转场 | 语义 |
|---|---|---|
| 同章、顺序推进（刚打完这间、自动进下一间） | 旧截图朝出口对侧移出，新房间从同侧推入，**0.24s** | 并列的房间 |
| 跨章 / 重试 / 选关跳转 / 继续游戏 | 黑出 0.10s → 换场景 → 黑入 0.10s | 空间上没有关系 |
| 死亡复活 | 原地淡出，不加遮罩 | 同一空间，只是时间重置 |

判定点只有一个：`session.transition_kind(from, to)`，纯函数。
`launch()` 的第三个参数 `auto_advance` 只有自动推进那条路传 `true`——
选关、重试、章节跳转一律切黑，因为它们没有「空间连续」可言。

**核心契约**：`exit_edge(i) == opposite(enter_edge(i+1))`。
从右边出去就必须从左边进来。现在五间房满足（出口 x=1088/1184 全在右半，
`RespawnPoint` x=56/248/420 全在左半），但**没有任何东西天然保证以后也满足**——
队友加房间时把出生点摆中间，效果就破了，而且滑动本身还在，不会立刻发现。

所以 `frontend/tests/test_transition_space.gd` 锁死它：逐对房间读 `Exit` 中心与
`RespawnPoint`，断言边配对；并断言跨章 / 跳关 / 重试一律 cut、时长 0.24 与 0.10。

两条容易踩的：

1. **滑动那 0.24s 必须锁玩家输入**（`player.lock_input(0.24)`）。滑入时人已经站在新房间里，
   只是被旧截图盖着；按着方向键 0.24s 能跑 65px，画面露出来人就偏了。
   锁用的是「到期自动解除」，不是布尔开关——前端中途被释放也不会永久锁死。
2. **目录里可以写 `"link"` 覆盖推断**：`"cut"` 强制切黑、`"h"` 横滑、`"v"` 纵滑。
   第二章真做「上楼」时才用得上 `"v"`；现在没有任何一关的出口在上下半区，
   纵滑分支属于「已实现、未使用」。

### 4.10 3-2 为什么是两口井，不是一口井挖深一点

一口井只有一条行程。最早的版本是单井 576→128 直通到底，中层楼板挂在井右、顶层楼板挂在井左，
靠两次「错边」伪造出三段。能走通，但**中层是个死路**：平台到 352 时玩家跳得上中层（水平只差 36px），
平台再到 128 之后落差 180px（> 满跳 115px；轻点 1 帧只有 54px），既上不去也回不来。

改成双井后，每段只服务一层：

| | 行程 | 供光源 | 玩家动作 |
|---|---|---|---|
| 井 A（列 9~12） | 576 → 352 | 死后留下的虚影（4.6s） | 先死一次，重生后跑上平台 |
| 井 B（列 20~22） | 352 → 128 | 火盆（引燃 1.2s，烧 6s） | 站上平台，打火点着火盆 |

第二段的能源是这关真正的设计难点。平台**严格跟着光走**（无光 0.33s 刹车后下落，没有"锁高度"），
而玩家站上平台之后，火把到井外的板永远超过打火半径（3-2 是 176px vs 96）。
所以每一段都必须有一个「不在台上的光源」：

- 第一段用虚影——它复刻的是玩家死前站在那里这件事；
- 第二段用火盆——**这就是「光可以来自别人」这条机制的第二次变奏**，
  玩家在第一段被迫理解它，第二段要主动用它。

火盆的位置是三个距离同时成立的解：

```
火盆 750 ──46──> 玩家站在平台上的火把（点得着）
   └────120────> 板 B 板心 880（火盆满亮 140，照得到）
玩家火把 704 ──176──> 板 B（打火半径 96，点不着 —— 所以必须借火盆的光）
```

三个数缺一个设计就塌：46 大了点不着火盆，120 大了板 B 不亮，176 小了玩家自己就能绕过火盆。

#### 台板为什么是单向的（从下面能穿上去）

台板的 `CollisionShape2D` 设了 `one_way_collision = true`：从上方站立正常，从下方完全没有碰撞。

这不是「平台游戏惯例」，是为了堵一个**死锁**。井底凹槽（288~384，地面 608）只有 96×32，
平台升走之后玩家很容易掉进去；平台无光落回 576 时，板体占 576~592，
和凹槽地面 608 之间只剩 16px，而玩家判定高 44px。旧版本实测：人被按进地面 20px（y=584.6），
之后跳跃、横移全部失效（x 一动不动），只能自杀。

改成单向之后，平台直接从人身上穿过去，玩家原地一个跳就站到台面上，再走出去。
断言是 `test_chapter3_edge.gd` 的 `_case_squeeze_in_pit`（7 条：没被压进地面 / 没死 /
原地跳能上 / 跳上去是 on_floor / 没被横着弹开 / 能走出来 / 全程没死），改回双向立刻红。

## 5. 已知坑（都踩过，别再踩）

| 现象 | 原因 | 解法 |
|---|---|---|
| 虚影帧号卡在 0、帧数还在涨，「重放的是当前这轮」 | `PackedVector2Array` 传参是**共享缓冲**，虚影和录制中的 `_trail` 指向同一份数据 | `echo.setup(trail.duplicate())`，且复活时直接 `_trail = PackedVector2Array()` 换新数组 |
| 第二条命开始虚影穿模，玩家踩空 | 虚影播完时 `set_collision_layer_value(3, false)`，`reset()` 里忘了开回来 | `reset()` 里显式打开层 3 |
| 键盘映射写了但按键完全没反应 | `InputEventKey.new()` 不设 `device = -1`，序列化出来是 `device: 16` | `project.godot` 里所有事件都是 `device: -1`，**别手改这个值** |
| 按 R 后升降台还停在半空（写完 `position.y = 576`，再读还是 128） | `AnimatableBody2D` 的 transform 归物理服务器管，**物理帧之外写 `position` 会被静默回滚**；`sync_to_physics` 下连 `lift.position.y = 300` 都读不回来 | 复位只置一个 `_reset_pending`，真正搬位置放到自己的 `_physics_process()` 开头执行 |
| 按 R 后铁栅还开着、预告虚影还杵在出口旁，玩家直接走过去就通关 | 新机关忘了 `add_to_group("mechanism")` + `reset_mechanism()`，`room_controller.reset_mechanisms()` 根本扫不到它 | 任何需要「回到初始状态」的节点都进 `mechanism` 组；`gate.gd` / `specter.gd` 已补上 |
| 队友试玩完原型关，正式进度里多出一个「已完成」，还自动跳进下一间 | `session.gd` 每帧检测 `won` → `mark_complete()` + `save_progress()`，试玩模式（`preview_unlock`）也照写 | 只在 `not flow.unlock_all` 时写；`test_frontend.gd` 有「试玩模式通关不写完成记录」断言 |
| 物块全变成 64×64 小方块 | tscn 里 `block_size` 写在 `script = ExtResource(...)` **之前**，脚本还没挂上，自定义属性被丢弃，回落到默认值 | 节点属性顺序必须是 `script` 先、自定义属性后 |
| 改一个地面的尺寸，所有地面都变了 | 场景里的 `RectangleShape2D` sub_resource 默认被所有实例共享 | `resource_local_to_scene = true` |
| 玩家重生时镜头从死亡点一路滑回出生点 | `Camera2D` 开了平滑，瞬移会触发插值 | 重生后调 `camera_follow.gd` 的 `snap_to_target()` |
| 暂停菜单按 ESC 关不掉 | 暂停菜单自身也是 `PAUSABLE`，`get_tree().paused = true` 后连自己的输入都停了 | `PauseMenu` 的 `process_mode = ALWAYS`（场景里已设 `process_mode = 3`） |
| headless 测试里鼠标点击无效（键盘正常） | `Input.parse_input_event()` 送的**鼠标**事件到不了 GUI | 用 `root.push_input(ev, true)`，真实鼠标走的也是这条路径 |
| `.gdignore` 目录里的测试脚本跑不了 | 以为 `.gdignore` 会完全屏蔽 | `--script res://_reference/tools/xxx.gd` 仍可显式加载，能用 |
| 场景里改了属性，重启又变回去 | 生成器被跑过（`--force`） | 别跑 `--force`；改了关卡就提交 git |
| 改了角色尺寸后，脚陷进地里 / 贴图与碰撞错位 | 只改了 `Collision.shape.size`，没改 `Collision.position`（它是相对左上角原点的中心偏移） | `position = shape.size / 2`；按 `F1` 看一眼框是否贴在方块上，框偏左上就是漏了这步（§3.5） |
| 调完尺寸觉得「明明对齐了还是踩空」 | 看的是贴图边缘，不是碰撞（贴图可以比 shape 画大一圈） | 判定永远以橙色线/黄框为准，别拿美术图的像素边缘当碰撞边界 |
| 角色看着比碰撞框大一圈 / 隔空停住 / 脚陷进地里 | 角色有两套尺寸：判定 32×44（碰撞体 / `body_size`），外观固定 **48 高**、画布底边对齐脚底；四周留透明边会显得"没碰到就停住" | 判定只认黄框/橙线（§3.5）；外观只由 `character_portrait.fit_to_body()` 决定，画布比例只影响胖瘦（§3.4） |
| 把新角色图拖到 `Sprite.texture` 上，游戏里没反应 | `character_portrait` 过去每帧硬写 `texture = 常量`，下一帧就把你的图顶回去了 | 现在睁眼帧就是场景里给的贴图，直接换即可；运行时换皮用 `set_art(睁眼, 闭眼)`，再调一次 `fit_visuals()` |
| 门关在玩家身上，人横向完全推不动 | 门是「松开任一板就关」，如果关的瞬间玩家在门洞里，`CharacterBody2D` 被 `StaticBody2D` 包住就出不来（实测 x 不变、y 抖动） | `puzzle_door._player_in_doorway()` 会等门口空出来再关（§4.8）；**别把这个守卫删掉**，断言 `test_door_safety.gd` |
| 虚影被门挡住，没走到压力板上 | **不是 bug**：虚影每帧做位移扫描，撞上就停在接触点，而帧号继续走。录的时候门开着、重放时门关着就会这样 | 关卡设计上避免「关键路线依赖一扇之后会关的门」；要放开就查 `echo.gd` 的 `_clip_motion`（README §6.1） |
| 玩家踩着虚影能跳上单向台面，**虚影重放同一段轨迹却卡在台面底下**（头顶死贴台面底面，之后一动不动） | 原来用 `direct_space_state.cast_motion()`，它是纯形状查询，**不认 `one_way`**，把单向台面当成实心天花板；玩家走的是 `body_test_motion`，认 | 扫描改走隐形 `CharacterBody2D` 的 `move_and_collide(test_only)`，和玩家同一条底层路径（`echo.gd` 的 `_cast_motion`）；断言 `test_echo_oneway.gd`（穿得上去 + 落得下 + 门还挡得住，三条一起守） |
| **主角能过拉杆、虚影过不了**：玩家拨杆穿过去没事，虚影重放同一段却卡在杆前面一动不动（实测停在杆右侧 997） | 玩家拨杆后碰撞体禁用，他趁这几帧穿过去；走远后 `touching` 变 false，杆又恢复实体。玩家已经过去了看不见，虚影是**之后**才重放的，正好撞上恢复后的杆。而且杆已 `active`，side 翻转，虚影连推都推不动 | 拨过就保持禁用，只有 R 复位才恢复（`lever.gd` 文件头注释）；断言 `test_lever_pass.gd`（未拨时是实体 / 拨过不挡人 / 复位后恢复） |
| 按 `R` 之后门又关上了，以为「开门白解了」 | **设计如此**：R 是「回到本关初始状态」，虚影与机关一起复位 | 想保留开门进度就别按 R；整关重来（含节点重建）仍是通关面板的 Replay |
| 按 `R` 之后门看着关了，人却能穿过去 | `puzzle_door.reset_mechanism()` 里只开了碰撞、没先把 `opened` 置 false，下一帧 `_physics_process` 判「状态没变」直接 return | 顺序必须是 `opened = false` → `$Collision.set_deferred("disabled", false)`；断言见 `test_complete_room` |
| 新加的机关按 `R` 不复位，其它机关正常 | 忘了登记 `mechanism` 组，或没写 `reset_mechanism()` | 照 §3.2「新增机关的接入契约」两条做 |
| 人掉进井底、平台落回来把人压在 16px 的缝里，之后彻底动不了只能自杀 | 台板用默认的双向碰撞。玩家判定高 44px，可板底到凹槽地面只剩 16px，根本站不下，物理引擎只能把人按进地面（实测 y=584.6），速度归零 | 台板设 `one_way_collision = true`（从下方无碰撞，原地跳能上台面）；断言 `test_chapter3_edge.gd` 的 `_case_squeeze_in_pit` |
| 换皮后虚影压板范围变了 | 判定被改回读 `Body` 贴图矩形了（贴图多留几像素透明边，`rect` 就变大） | 判定只准读 `body_size`（§4.7）；`test_echo_contract.gd` 会用 56×76 的图验一遍 |
| 虚影还没出现就能挡人 / 压住板，或画面出现了板却不亮 | 显示、碰撞层、机关判定各判各的（`visible` / 层 bit / `is_gone`） | 全部统一走 `_active`：让虚影登场只调 `reset()`，**不要再手改 `visible`**（§4.7） |
| 地图看着好好的，走上去墙是假的 / 地面只有第一格能踩 | `TileSet` 里碰撞多边形写成了**图集绝对坐标**（`16..48`、`48..80`…）。它要的是**瓦片局部坐标**（以瓦片中心为原点，每个格子都是同一份 `±16`） | 所有格子共用 `PackedVector2Array(-16, -16, 16, -16, 16, 16, -16, 16)`；判定看 `test_grid_room.gd` 的「左墙(8,300) 是实的」 |
| 黑幕里怎么调曲线都不觉得「光变亮了」 | 黑幕是 `canvas_item` 遮罩，**只能盖黑、不能提亮**，上限就是场景原色 | `falloff` 只管暗得多快；真要「发光」得另叠一层 `blend_add`，别在遮罩上找 |
| 编辑器里打开带黑幕的关卡整屏全黑，以为场景坏了 | shader 的 `sources` / `count` 由 `blackout.gd` 每帧喂，编辑器里这个脚本不跑，`count` 还是 0 → 整层不透明黑 | Scene 面板把 `Blackout` 的眼睛关掉再编辑地形 |
| 玩家自杀留下的虚影不照亮 | 玩家自带光和虚影的光共用 `personal_radii`，第三章为了「只靠手电」把它压到 `(2,2)`，虚影被一起关掉 | 已拆成独立的 `echo_radii`；断言「虚影照亮半径独立于玩家」 |
| 预录虚影掉出地图后出现在**玩家出生点** | 虚影 `extends player.gd`，`reset_to_spawn()` 用的是 `respawn_position`，而它在 `_ready` 里被设成全局唯一的 `respawn_point` | `specter.gd` 自己存 `_start` 并走 `_restart()`；断言「虚影掉出地图回自己起点」 |
| 加了第二块光敏板后，板 B 的井壁导轨画到了隔壁井里 | `RAIL_X` 是写死的常量（`-16`）。它表达的是「这块板所在的那面井壁」，写死就等于假设全场只有一口井 | 改成 `@export rail_local_x`：板 A 用默认 `-16`（世界 384），板 B 设 `-148`（节点 788 → 井 B 左壁 640）。`lift.gd` 的 `rail_x` 必须跟着对上（板 B 的滑块是 `-48`），否则滑块飘在导轨外面 |
| 玩家站在平台上打火，结果开关跟着平台一起升走了 / 到顶才发现人没上来 | 「开关在井外」只是必要条件，真正的条件是**人站上平台之后，光还够不够得到开关**。板 B 第一版放在悬挑台边上，与平台只差 4px，玩家走过去就点得着，点完平台升走、人被留在原地 | 判据一律用距离算：板 B 板心 880，玩家站平台时火把在 704，差 176 > 打火半径 96 → 自己点不着；火盆在 750，距火把 46（点得着）、距板 B 120 ≤ 火盆满亮 140（照得到）。断言「站平台 B 打火点不着板 B」守这条 |
| 火盆点着后玩家被困在井对面的悬挑台上 | 悬挑台与平台 B 台面只差 4px，玩家走得到；在那里点火盆等于让电梯先走 | 有意保留的**可恢复失误**：火盆烧 6s 自动灭 → 板 B 灭 → 平台从顶层落回 352 → 玩家走回平台重来。燃料不能给长（10s 会被当成卡死） |

---

## 6. 三条改动路径

### 策划：改关卡
可玩房间是 `scenes/levels/complete_room.tscn`（`level_01.tscn` 是旧版块状关卡，留着做对照）。

- **刷地形**：选中 `World` 层，用 TileMap 的画笔刷。格子 32px，40 列 × 22 行，一格都不能多出边界
- **机关**：拖实例，尺寸在检查器改 `block_size`（贴图与碰撞一起变）。放完对齐格线：左边贴 32 的倍数、
  底边贴 576、宽是 32 的倍数（§3.7 有对照表，`test_grid_room.gd` 会验）
- **不用再改 `Background`**：地图边界是 `Map_Placeholder` 那 880 个空瓦片，不是色块
- **整张图重排**：改 `_reference/tools/room_grid.py` → `make_room.py --force`

其余拖拽规则见 `README.md` 第三、四节。

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

# 3) 全跑一遍（用 glob 扫目录，别手写名单——手写的名单一定会漏掉新加的）
for f in _reference/tools/test_*.gd; do
  echo "=== $f ==="
  godot --headless --path . --fixed-fps 60 --script "res://$f"
done
# 判定标准：输出里没有 FAIL / SCRIPT ERROR，且脚本自己打的「失败项：0」
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
| `test_grid_room` | **关卡网格契约**：视口 = 40×22×32、空瓦片铺满 880 格、三层属性、图集语义（实心有碰撞/空的没有）、物理实证（地面顶边 576、两侧墙）、机关贴格线、相机中心 |
| `test_complete_room` | 真实按键走完整关：虚影踩板、双板开门、出口结算、R 复位（人/虚影/机关）、门重新变实体、Replay 整关重来、尖刺致死与重生 |
| `test_echo_environment` | 虚影被世界挡住（门/墙）、被挡后不隧穿、开门能过、虚影踩板、站出口不结算 |
| `test_echo_contract` | `body_size` 与 `_active` 两个单一真相：换皮不改判定、未激活时显示/碰撞/机关全关 |
| `test_echo_recording_cap` | 录制上限滚动窗口：满了丢最旧一半，尸体落点不被截断 |
| `test_door_safety` | 门「松开即关」的安全性：玩家站门洞里门不关 / 人能走出去 / 走后补关 / 关上是墙 / 虚影顶不开门 |
| `test_character_portrait` | 两帧眨眼与暂停冻结、外观高 48 与脚底对齐、换图不改判定 |
| `test_air_drag` / `test_air_turn` / `test_jump_curve` / `test_speed_curve` | 手感曲线（逐帧数值，见 `docs/手感调参.md`） |
| `graybox/tests/test_graybox_kit` | 灰盒套件自己的验收（模板搭建、保存重开、单板/双板门、出口）。在 `.gdignore` 目录里，要显式 `--script res://graybox/tests/test_graybox_kit.gd` |
| `frontend/tests/test_transition_space` | **换场语法**：逐对房间的出口边 == 下一间进入边的对侧、跨章/跳关/重试一律切黑、滑动 0.24s 与切黑 0.10s、玩家转场锁能自动解除 |

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

一共 396 个文件会入库：`scripts/` 40、`assets/` 74、`scenes/` 57、`docs/` 17、
`_reference/` 74、`graybox/` 77、`frontend/` 47、`addons/` 5、根目录 5。
（数字会随开发变，以 `git ls-files | wc -l` 为准；结构稳定的是「哪些该进、哪些不该进」。）

| 内容 | 进仓库 | 说明 |
|---|---|---|
| `project.godot` | ✅ **必须在根目录** | Godot 靠它在根目录认项目，挪进子目录就打不开了 |
| `assets/` `scenes/` `scripts/` | ✅ | 游戏本体，97K + 56K + 56K，不需要 Git LFS |
| `*.gd.uid` | ✅ | Godot 4.4+ 的资源 UID，**必须提交**，保证跨机器引用不乱 |
| `README.md` `HANDOVER.md` | ✅ 根目录 | GitHub 会自动渲染根目录 `README.md` |
| `.gitignore` `.gitattributes` | ✅ | 后者管换行与二进制，缺了 `.tscn` 会整片 diff |
| `_reference/tools/` | ✅（Private） | 里面有 **24 个 `test_*.gd` 回归测试**，团队要能跑；`make_*.py` 已冻结 |
| `graybox/` | ✅ | 另一位同学交付的**灰盒搭建套件**（模板场景 + 机关 + 编辑器预览）。第一章五间房都是用它的块拼法搭的（`solid_ground.tscn`），和 40×22 瓦片网格并行，取舍见 §13 |
| `frontend/` | ✅ | 另一位同学交付的**游戏前端**：主菜单 / 选关 / 暂停 / 设置 / 结算 / 全通 + 存档（`user://frontend/*.cfg`）。按 `db/catalog.tres` 的 20 关目录换场景 |
| `_reference/preview_*.png` | ✅（Private） | 我们自己构建版本的截图，作为视觉基线；网格房间的两张见 `preview_grid_room*.png` |
| `_reference/art_source/office_atlas_16.png` | ✅（Private） | 旧的 16px 办公室图集。换成 32px 占位图集后它不再被任何场景引用，移到 `_reference/` 作美术参考（该目录有 `.gdignore`，引擎不导入） |
| `_reference/source_from_game/` | ❌ 已忽略 | 反编译源码，**泄露即侵权** |
| `_reference/preview_level01_original.png` | ❌ 已忽略 | 原版游戏画面 |
| `.godot/`（2.7 MB） | ❌ 已忽略 | 导入缓存，每台机器自动重建，提交必然二进制冲突 |
| `.workbuddy/` | ❌ 已忽略 | AI 协作记录 |
| `*.zip`（`YourPastSelf-2-Windows.zip`） | ❌ 不要上传 | 原版游戏包，同时踩版权和体积两个坑 |

> 公开版的差异：把 `_reference/` 整个排除，同时把 `_reference/tools/test_*.gd` 挪到 `tests/`
> （否则公开仓库既没有测试、也没有生成脚本）。这一步现在不做，等真要开源再说。

**另外 29 个 `.import` 文件也在库里**（每个 png 一个，Godot 4 的导入设置就存在这里）。
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
│   ├── tiles/             ← 关卡网格图集（32×32 占位瓦片）
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
确认：F5 能进主菜单并打开第一章第一间、按 `F1` 有碰撞框、24 个测试脚本能跑。
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

# 美术交图后校验贴图尺寸 / 瓦片格线（角色判定 32×44、外观 48 高）
python _reference/tools/check_art_size.py

# 关卡网格：重建 32px 占位图集 / 把 room_grid.py 的布局写回房间 / 只看预览图
python _reference/tools/make_grid_tiles.py --force
python _reference/tools/make_room.py --force
python _reference/tools/make_room.py --preview
python _reference/tools/room_grid.py          # 打印 40x22 布局与机关格子坐标

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
5. 数值手感原来照抄原版 `actor.gd`，**2026-11-19 起已整体重调**（满速 273、凹形起停、跳跃 115.1px/0.78s、下落 ×1.1、空中惯性与反向急停）。现值、逐帧实测和调参公式见 **`docs/手感调参.md`**；别再拿 `actor.gd` 的数字当预期值。
6. 交美术前先教他按 `F1`：改尺寸时只看橙线，不要拿贴图像素边缘当碰撞——这是这个项目最容易反复沟通的一件事（§3.5）。
7. 给美术交付尺寸，别口头说"大概 48 高"——直接给 `README.md` §3.4 的四条硬规则 + 一句
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
| 跳跃 | 89px / 44 帧 | **115.1px / 47 帧**（2026-11-21 从 143.6px 回退到此值） |
| 下落重力 | 与上升相同 | **×1.1** |

新增验证脚本：`_reference/tools/test_speed_curve.gd`、`test_air_turn.gd`、`test_air_drag.gd`、`test_jump_curve.gd`；
画图脚本在 `_reference/tools/charts/`（Python + Pillow，字体路径写死 Windows）。

副作用：满速跳距从 154px 涨到约 213px（6.66 格）；跳高 115.1px（3.60 格），低于 115.1px 的天花板会撞头。
关卡沟距若按旧速度摆的，需要复核。**跳高上限是 -718**（示例房间门高 160px，-712 实测仍被挡、-720 直接跳过门）。
将来若要抬高度，别越过这条线，而且必须同步压 `jump_cut`——否则任何一次点按都至少 2 格，1 格小跳会消失。

> **2026-11-21 回退记录**：曾于 11-20 改成 `-680 / cut 0.45`（满跳 143.6px），
> 目的是够到第一章离地 128px 的台子并修掉「轻点踩在 2 格线上」。
> 团队决定回到 `-610 / 0.65 / coyote 0.10`，本表与上文已按现值修正。
> 代价是这两个问题重新存在，成因与可选处理见 `docs/跳跃卡手分析.md`。

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
| 场景是复制粘贴 | `level_01` / `complete_room` / `office_build` / `graybox/base_level` / 第一章五间各存一份 Player + EchoManager + Camera | 改一个机制要改八处，最容易漏的是新加的那处 | `graybox/glue/room.gd` 已经是「LevelBase 的雏形」（继承 `room_controller` 并管 spawn/player 接线），下一步是把 `complete_room` 也挂上去，而不是再抄一遍 |
| **两套并行的摆地形方式**：网格房间用 32px 瓦片（§3.7），`graybox` 套件用 `solid_ground.tscn` 块拼 | 灰盒套件是另一位同学独立交付的，和改网格几乎同时落地 | 同一个房间有两种画法，新人不知道该跟哪套；块拼出来的房间和 40×22 网格对不齐 | 二选一：① 把 `graybox/base_level.tscn` 的 `Terrain` 换成同一套瓦片层（一次能改完）；② 明确分工——网格房间=正式关卡，灰盒套件=快速试搭。**目前倾向 ①** |
| `kill_y = 750` 写在玩家节点上 | 沿用原版常量 | 做比 750 更高的关卡要逐实例改 | 改成关卡级参数，或跟相机视野算 |
| 机关每帧都 `get_nodes_in_group` | `actor_bounds.actors()` 每次调用都新建数组 | 5 条虚影的规模下无所谓（每帧 3 次小分配） | 别提前优化，机关数量上百再说 |

**本轮已修掉的**：录制上限满 100 秒后只是"停止追加"，虚影重放的是这一生**最初**的 100 秒，
尸体落在几百像素之前（实测调成 1 秒上限时差 320px）。现在改成滚动窗口丢最旧一半，
保留最近一段，尸体落点回到死亡处，断言在 `test_echo_recording_cap.gd`。

**11-20 修掉的**：① 门「松开即关」会把玩家夹死在门洞里（x 完全推不动，只能按 R）——
现在关门前检查 `_player_in_doorway()`，断言 `test_door_safety.gd`；
② `character_portrait` 每帧硬写 `texture`，导致换角色图完全没反应——
现在睁眼帧取场景里的贴图，运行时换皮走 `set_art()`；③ 三处硬编码 28×38 的旧断言
（`test_blocks_layout` / `test_echo_contract` / `test_echo_environment`）改成读
`body_size` 与 `visual_height_ratio`，尺寸再改也不会假红。

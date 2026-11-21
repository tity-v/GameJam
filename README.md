# Your Past Self — Godot 项目结构说明

> 启动入口是 `frontend/entry.tscn`（主菜单 → 选章 → 关卡）。四章 × 五间共 20 关的目录在
> `frontend/db/catalog.tres`，第一章五间已接入；`scenes/levels/complete_room.tscn` 是双压板机制示例，
> 不在关卡目录里，要单测就打开它按 **F6**。
> 机制现状：压板开门（**松开任一压板就关门**，门口站着玩家时门会等它走出去再关）、出口结算、尖刺致死；
> `R` 为「回到本关初始状态」（清空虚影 + 玩家回出生点 + 机关复位，不重载场景）。
> 解法与搭建说明见 [完整房间使用说明](docs/完整房间使用说明.md)。


第一关已从原版 `YourPastSelf.exe` 搬进 Godot 4.7。本项目按「场景化」组织：
**每个游戏元素都是独立 `.tscn`，外观由贴图决定，逻辑在 `scripts/` 里，场景只挂引用。**
策划改关卡、美术换贴图，都不需要改代码。

> **程序接手请看 [`HANDOVER.md`](HANDOVER.md)** —— 当前完成度、架构决策与被否决的方案、已知坑、未完成项排序、上传仓库前的版权注意事项。

---

## 一、目录

```
assets/                 美术素材（可直接替换同名文件）
  actors/office_character/idle.png, blink.png   角色睁眼/闭眼帧（380×400）
  actors/player_death_cross.png                  死亡叉号
  blocks/*.png          地面 / 墙 / 压板 / 门 / 出口 / 尖刺（九宫格源图）
  tiles/                关卡网格瓦片：placeholder_32.png + tileset_32.tres（32×32）
  echo/*.png            虚影与虚影死亡叉号
  ui/continue_*.png     暂停「继续」按钮三态
frontend/              游戏前端：主菜单 / 选关 / 暂停 / 结算 / 存档
scenes/
  blocks/*.tscn         物块：NinePatchRect + 碰撞体（各一个独立场景）
  player/player.tscn    主角
  echo/echo.tscn        虚影
  levels/complete_room.tscn  机制示例房间（40×22 网格，不在关卡目录里）
  levels/tutorial_relay.tscn、tutorial_steps.tscn  第一章前两间
  levels/chapter_01_room_03..05.tscn  第一章第三至第五间
  levels/drafts/        工具生成的独立关卡草稿
  levels/level_01.tscn       旧版块状关卡（历史对照，别再往里加东西）
  ui/                   hud / pause_menu / key_hint / keycap
scripts/                逻辑
_reference/             反编译出的原始工程 + 素材工具（Godot 不导入）
```

---

## 二、必读：两个文件是「正式资产」

| 文件 | 谁维护 | 注意 |
|---|---|---|
| `frontend/db/catalog.tres` 引用的关卡场景 | 策划 / 关卡 | 在 Godot 编辑；新关卡先做成草稿 |
| `assets/**/*.png` | 美术 | 覆盖同名文件即可换皮 |

`_reference/tools/` 下的 `make_level.py`、`make_blocks.py`、`make_player.py`、
`make_echo_assets.py` 是**当初把原版搬过来时的一次性脚本**，现在全部加了保护：

- 目标文件已存在 → **直接跳过，不覆盖**
- 只有显式加 `--force` 才会重写（**会冲掉你手动改的关卡和美术**）

所以现在跑它们不会有副作用，但也请不要再跑 `--force`。

---

## 三、美术换图规格

### 3.1 物块：画小图，自动拉伸

物块**不再是「按最终像素尺寸画」的整图**，而是**九宫格（9-slice）源图**：
美术画一张小图，游戏里按需要的尺寸拉伸，边角不变形。

| 文件 | 源图尺寸 | 九宫格 | 说明 |
|---|---|---|---|
| `blocks/solid_ground.png` | 32 × 32 | 上边 3px 固定 | 地面。顶部 3px 亮线，下面纯填充 |
| `blocks/solid_wall.png` | 32 × 32 | 上边 3px 固定 | 左墙，同上 |
| `blocks/plate_off.png` | 8 × 8 | 无（整块拉伸） | 压力板，纯色 |
| `blocks/door.png` | 8 × 8 | 无（整块拉伸） | 门，纯色 |
| `blocks/exit.png` | 16 × 16 | 四边 3px 固定 | 出口，3px 边框 + 半透明内部 |
| `blocks/spike_tile.png` | 20 × 20 | 无（平铺重复） | 尖刺，一格；拉宽会变成多个尖刺，**不会被拉长** |

**换图 = 覆盖同名 png**。只要保持「源图尺寸 + 九宫格留白规则」不变，
拉伸出来的观感就和现在一致：地面拉多高，顶边永远是 3px；出口拉多大，边框永远是 3px。

### 3.2 物块尺寸：只改一处

每个物块场景的根节点都有一个 **`block_size`**（`scripts/block.gd` 提供）。
它是唯一尺寸来源：

- 贴图节点 `Patch.size` 跟着它
- 碰撞体 `Collision.shape.size` 跟着它，`position` 自动设成 `block_size / 2`
- 脚本带 `@tool`，**在编辑器里改 `block_size`，碰撞框会立刻跟着动**

所以改尺寸的正确姿势是：

1. 打开 `scenes/blocks/solid_ground.tscn`，选中根节点，改 `block_size` → 影响**所有**地面
2. 只想改关卡里某一个块：在 `level_01.tscn` 里选中那个实例，在检查器里改它的 `block_size`（会作为实例覆盖存在关卡文件里，不影响本体）

> 不用再手算碰撞体的 `size` 和 `position`，也不用担心「美术图变了碰撞没变」。
> 同一类物块的多个实例各自持有独立碰撞资源（`resource_local_to_scene`），改一个不会串到别的。

### 3.3 主角 / 虚影 / UI

角色美术是**一张 380×400 的透明 PNG + 一张闭眼帧**，由 `scripts/character_portrait.gd`
负责眨眼、等比缩放、脚底对齐和虚影的青色着色；其余仍是 1:1 像素图（`centered = false`）。

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `actors/office_character/idle.png` | 380 × 400 | 睁开眼（主角与虚影共用） |
| `actors/office_character/blink.png` | 380 × 400 | 闭眼帧，每 3 秒眨 0.15 秒 |
| `actors/player_death_cross.png` | 28 × 38 | 死亡叉号，标的是**碰撞框**，不是人物剪影 |
| `echo/echo_cross.png` | 28 × 38 | 虚影死亡叉号 |
| `ui/continue_*.png` | 92 × 92 | 暂停按钮三态 |
| `actors/player.png`、`echo/echo_body.png` | 28 × 38 | 历史占位图，场景已不引用，留着当参考 |

角色尺寸只有一个来源：玩家看 `player.tscn` 的 `Collision.shape.size`（**32×44**），虚影看
`echo.gd` 的 `body_size`（**32×44**）。外观再按 `visual_height_ratio`（48/44）放大到 **48 高**并底部对齐，
所以人物看起来比碰撞框高 4px，头发/装饰允许伸出判定范围。

### 3.4 角色可画范围（美术必看）

| | 主角 | 虚影 |
|---|---|---|
| 画布 | 任意尺寸，当前素材 380 × 400 | 同一张图（青色半透明），判定独立 |
| 缩放 | 高 = **48**（碰撞 44 × 48/44），宽按画布自己的长宽比 | 同上，判定仍用 `body_size` 32×44 |
| 有碰撞的范围 | 32 × 44，从脚底往上算 | 只有**头顶 32×8** 单向薄片 |
| 关键线 | 画布**底边** = 脚底线 | 画布底边 = 脚底；可踩线在碰撞框顶部，比头顶低 4px |
| 透明边 | 判定是矩形、不跟 alpha，四周留空会显得"没碰到就停住" | 同左 |

**四条硬规则**：

1. **画布比例决定胖瘦**。宽度 = 48 × (画布宽 ÷ 画布高)，380×400 出来大约 45.6 宽。
   换比例前先确认人物不会变胖变瘦。
2. **别指望"画大一点判定就大一点"**。判定固定 32×44，换图不改谜题（`test_echo_contract` 钉着）。
3. **脚底贴住画布底边**。`fit_to_body()` 把画布底边对齐碰撞底边，底部留空就是悬空。
4. **虚影头顶要平**。可踩薄片是碰撞框顶部那条 32×8，头顶比它高 4px，头太尖会有"踩在空气上"的观感。

换角色：把 `Sprite` 的 `texture` 换成新图（闭眼帧填 `blink_texture`），或者运行时调
`character_portrait.set_art(睁眼, 闭眼)`，换完让宿主再 `fit_visuals()` 一次。
⚠️ 不要往 `character_portrait` 里写死图片路径——之前那样每帧覆盖 `texture`，结果"把图拖上去完全没反应"。

> `_reference/art_templates/*_guide_10x.png` 是 28×38 时代画的 10 倍模板，现在只能当比例参考。

**交图前自检**（两秒）：

```bash
python _reference/tools/check_art_size.py
```

- 通过 → 全部 `OK`
- 尺寸不对 → `BAD`，并直接告诉你"会显示成 1.5 倍大小 / x、y 被拉歪"
- 新增了没登记规格的图 → `WARN`，只是提醒，不影响运行

改完图进游戏按 `F1`，看黄框有没有贴住角色、橙线有没有压在地面（§3.5）。

### 3.5 碰撞调试层（调尺寸时开着看）

玩家和虚影场景里各挂了一个 `HitboxDebug` 节点（`scripts/hitbox_debug.gd`），
**纯绘制、不参与物理**，把碰撞范围直接画在画面上：

| 画的东西 | 含义 |
|---|---|
| 玩家周围的**黄色框** | 玩家完整碰撞体（32×44），就是「能不能钻过缝」的判定范围 |
| 玩家底部的**橙色粗线** | 脚底线。这条线才是真正踩地/踩虚影的地方 |
| 虚影顶部的**青绿色细框** | 可踩薄片（32×8，单向碰撞）——**只有这块有碰撞**，侧面和下方都没有 |
| 虚影顶部的**橙色粗线** | 可踩线，和脚底线同一个颜色 |

**两条橙线重合 = 踩上了。** 调整尺寸时盯着这两条线，比看数字直观。

> **线不会挡人，框才会。** 橙线只是把 `shape` 的那条边标出来，真正发生碰撞的是碰撞体与地面重叠的瞬间——
> 视觉上刚好就是两条线压在一起。所以「线对齐了」等于「判定是对的」，但别指望线本身有推挤效果。

- **编辑器里也生效**（`@tool`）：改 `shape.size` 或 `block_size`，框立刻重画，不用运行游戏
- **运行时按 F1** 全局开关（所有实例一起）
- 想改颜色 / 临时关掉：选中 `HitboxDebug` 节点，在检查器改 `box_fill` / `box_line` / `contact_color`，或取消 `visible`
- 觉得碍事可以直接删掉这个节点，**不影响任何碰撞和手感**

### 3.6 关卡瓦片：一格 32×32，一张图 7 格

关卡地形不用九宫格物块，用瓦片图集：`assets/tiles/placeholder_32.png`（128 × 64，4 列 × 2 行）。
配套的 `assets/tiles/tileset_32.tres` 里写了 `tile_size = 32` 和每格的碰撞。

| 位置 | 名字 | 画什么 | 有碰撞 |
|---|---|---|---|
| (0,0) | solid_top | 地表：顶部 3px 亮线 + 填充 | ✅ 整格 |
| (1,0) | solid_fill | 地下内层（无亮线） | ✅ 整格 |
| (2,0) | solid_wall | 竖墙（右侧加深） | ✅ 整格 |
| (3,0) | one_way | 单向板，只画上面 8px | ✅ 只有上面 8px |
| (0,1) | air | 空瓦片：只画极淡格线 + 四角小点 | ❌ |
| (1,1) | decor | 装饰板，半透明 | ❌ |
| (2,1) | spawn_mark | 出生点十字标记 | ❌ |

三条硬规矩：

1. **一格正好 32×32**，整张图的宽高必须是 32 的整数倍
2. **碰撞不在图上，在 `tileset_32.tres` 里**——所以换图不会改玩法。想让某格变成实心/空心，改 tres 的
   `physics_layer_0/polygon_0`，别指望「画得实一点」就有碰撞
3. **瓦片不要留透明边**。九宫格物块允许留边，瓦片不允许：留了边，相邻两格之间就会露缝

想改配色/质感：直接覆盖这个 png。想重新生成一版占位图：`python _reference/tools/make_grid_tiles.py --force`
——⚠️ 这会**覆盖手绘的图集**，只在还没人画之前跑。

---

## 四、用 Godot 搭建关卡

### 4.1 新建草稿

1. 用 Godot 4.7.2 打开本工程的 `project.godot`。点击 **项目 → 工具 → 新建灰盒房间**，输入一个未使用的草稿名。菜单缺失时，在 **项目 → 项目设置 → 插件** 检查灰盒插件是否启用。
2. 工具在 `scenes/levels/drafts/` 创建独立的 `.tscn`，打开 2D 视图并选中 `World`。模板自带玩家、出生点、回声管理器、固定相机和基础地面。新草稿不会自动出现在章节里。
3. 房间默认 **40×22 格，每格 32×32 像素**，对应一屏 **1280×704**。选中 `World`，在底部 **TileMap** 面板选砖。画笔画单格，矩形工具铺地，右键擦除。图集第一行前三块是实体砖，第四块是能从下方穿过的单向砖。装饰画在无碰撞的 `Decor` 层。
4. 移动 `RespawnPoint` 到安全位置。标记是角色碰撞框左上角，**脚底 = 标记 Y + 44 像素**。默认地面顶边在 Y=576，所以模板出生点 Y=532。换了地面高度就重新放出生点，给角色头顶和两侧留空间。

### 4.2 搭一个能玩的最小房间

在场景树选中 `Mechanisms`，从文件系统实例化下面的场景。选中关卡中的实例，在检查器调整位置和 **Block Size**，这样只改本房间里的这个实例。

| 组件 | 怎么配置 |
|---|---|
| `graybox/pressure_plate.tscn` | 放在可站立的地面上。用 **Accepts Player** 和 **Accepts Echo** 选择谁能踩板。黄色边框是脚底判定的编辑器预览。 |
| `graybox/door.tscn` | 放在出口通路上，在 **Plate Paths** 添加一项并用节点选择器选压力板。绑定多个开关时，全部激活才开门。 |
| `graybox/exit.tscn` | 放在门后，在 **Door Path** 选这扇门。门打开后，当前玩家进入出口即通关。无需门的房间可改用 `graybox/open_exit.tscn`。 |
| `scenes/blocks/spike_tile.tscn` | 放在需要造成死亡的位置。先留一段安全地面，便于测试起跳和落脚。 |

保存后按 **F6** 运行当前房间。先踩板再离开，确认门能开关。站稳在板上按 **E** 主动死亡，复活后看回声重走路线，趁它踩板时通过门抵达出口。**R** 会清空回声并复位机关，想从头验收时再用。检查场景树的配置警告，确认门和出口都绑到了本场景里的节点。

### 4.3 从一屏灰盒到正式关卡

- 调布局时先留出出生和观察区，让玩家能看见目标以及机关触发后的变化。可以用下层安排回声行进、上层安排本体通路，让同一屏容纳两条看得清的路线。第一次踩头练习下面留安全落脚处。
- 按 **F6** 从空场走完预期解法，再试提前死亡、离板太早、跳空和按 **R** 重试。调整地形、落脚宽度和过门时间，避免解法依赖精确贴边或玩家不知道要等多久。可打开 `scenes/levels/complete_room.tscn` 查看双板门示例。
- 定稿后保存，保持该场景处于当前标签页，点 **项目 → 工具 → 将当前房间接入章节**，选目标槽位。已有场景的槽位会弹出替换确认。工具更新 `frontend/db/catalog.tres` 的场景路径，保留槽位 ID 和原场景文件。
- 接入后按 **F5** 从主菜单进入对应章节，验证选关、出口和下一关。交接时附上房间路径、目标槽位、简短解法和实测结果。提交房间场景及其新依赖，已接入章节时一并提交 `frontend/db/catalog.tres`。

更多零件和检查器参数见 [灰盒套件手册](graybox/README.md)，包括移动平台、拉杆、传送门、箱子和染色录制器。

---

## 五、改底部操作提示（HUD）

HUD 是 autoload（`project.godot` → `[autoload]` → `Hud`），**所有关卡共用**，不用每关摆。

| 想改什么 | 打开哪个场景 | 操作 |
|---|---|---|
| 加/删一条操作提示 | `scenes/ui/hud.tscn` → `Root/Hints` | 复制一个 `KeyHint` 实例，改检查器里的 `keys` 和 `desc` |
| 键帽文字 | 同上 | `keys` 是字符串数组，`["A","D"]` 就是两个键帽 |
| 说明文字 | 同上 | `desc` |
| 键帽样式（圆角/颜色/九宫格图） | `scenes/ui/keycap.tscn` | `PanelContainer` 的 `theme_override_styles/panel` |
| 说明文字样式 | `scenes/ui/key_hint.tscn` | `Desc` 节点（颜色、字号） |
| 整条底栏背景 | `scenes/ui/hud.tscn` → `BarBg` | `theme_override_styles/panel`，可换九宫格贴图 |
| 右侧「回声 n / 5」 | `hud.tscn` → `Count` | 文字由 `hud.gd` 自动刷新，样式随便改 |

`scripts/hud.gd` 只做两件事：刷新回声计数、显示一行闪现提示（虚影重置/满员替换）。
**加一条操作提示不需要碰它。**

---

## 六、虚影（回声）换皮

`scenes/echo/echo.tscn` 里两个 Sprite2D：

- `Body` — 本体，死亡淡出只作用在它身上（`modulate.a` 从 1 → 0.18）
- `Cross` — 死亡叉号，默认隐藏，只在「死亡 1.3 秒」期间显示，**不跟着淡**

换皮 = 改 `Body` 的 `texture`（或调 `character_portrait.set_art()`），再加 `echo_tint` 的青色；
`Cross` 换 `echo_cross.png`。玩家踩它用的是头顶一条 32×8 的单向薄片（`Top` 节点），
宽度由 `body_size` 算，和外观无关，换图不用动它。
（虚影自己撞墙、撞门的判定不在这条薄片上，见下一节。）

### 6.1 虚影的体积落在哪（改机制前必看）

虚影是「重放坐标」而不是「跑物理」，位置由轨迹喂进去；但它**每帧会做一次形状扫描**，所以对世界是有实体的：

| 对象 | 认不认虚影的体积 | 依据 |
|---|---|---|
| **压力板** | ✅ 认，按 `body_size`（默认 **32×44**）算 | `actor_bounds.gd` 取 `echo.body_rect()`，**看脚底**是否落在板面高度带内——不读贴图 |
| **墙 / 关着的门** | ✅ 挡住，撞上停在墙面 | `echo.gd` 的 `_clip_motion()`：每帧 `cast_motion` 只扫 layer 1 |
| 出口 | ❌ 只认玩家 | 只遍历 `player` 组（虚影站在出口上不会通关） |
| 尖刺 | ❌ 只杀玩家 | 同上（虚影不会被扎死） |
| 玩家踩虚影头顶 | ✅ 只有 32×8 薄片 | `echo.tscn` 的 `Top`，单向碰撞 |

三条容易踩的：

1. **压力板的"体积"来自 `body_size`，不是贴图**——美术换图只改外观高度（固定 48），判定仍是 32×44。想改体积改 `body_size`，别改图片（`test_echo_contract.gd` 钉住这条）。
2. **挡住是"截短位移"，不是"改碰撞层"**：给 echo 设 `collision_mask` 会让引擎自己推它，和喂进去的坐标打架；现在的做法是 `cast_motion` 算出安全比例，只让虚影走到接触点。改这段别看错地方。
3. **被挡住的虚影会停在墙边，但时间照走**（帧号继续前进）。所以「录的时候门开着、重放时门关着」→ 虚影卡在门外，**不会**到板上去。这是预期行为，关卡设计要避开（别让关键路线依赖一扇之后会关的门）。

**虚影只有一个激活状态**：生成时（玩家还在死亡淡出）不显示、无碰撞、不推进、机关不认；
玩家复活时 `reset()` 才三件事同时生效。所以不会出现「看不见的虚影把板压住 / 把人托住」。
让虚影出现只调 `reset()`，不要手改 `visible`。

回归测试：`test_echo_environment.gd`（压板/释放/悬空不触发/门挡得住/开门能过/尸体淡出 1.3 秒内仍压得住板）
+ `test_echo_contract.gd`（换图不改判定 / 未激活不生效 / 复活才登场）。

---

## 七、场景 → 脚本 对照

| 场景 | 脚本 | 职责 |
|---|---|---|
| `levels/level_01.tscn` | — | 关卡布局、重生点、相机 |
| `blocks/*.tscn` | `scripts/block.gd` | 物块尺寸同步：`block_size` → 贴图 + 碰撞 |
| `player/player.tscn` | `scripts/player.gd` | 移动、跳跃、死亡/重生 |
| （玩家/虚影里的 HitboxDebug） | `scripts/hitbox_debug.gd` | 碰撞框可视化，纯绘制，F1 开关，**不参与物理** |
| `echo/echo.tscn` | `scripts/echo.gd` | 轨迹重放、单向碰撞、死亡延时 |
| （关卡里的 EchoManager） | `scripts/echo_manager.gd` | 录制、生成虚影、上限、`R` 重置（人回起点 → 机关复位 → 清虚影） |
| （关卡里的 Camera2D） | `scripts/camera_follow.gd` | 跟随 + 边界夹取 |
| `ui/hud.tscn` | `scripts/hud.gd` | 底部操作栏、回声计数、闪现提示 |
| `ui/key_hint.tscn` | `scripts/key_hint.gd` | 一组「键帽 + 说明」 |
| `ui/keycap.tscn` | `scripts/keycap.gd` | 单个键帽 |
| `ui/pause_menu.tscn` | `scripts/pause_menu.gd` | ESC 暂停 / 继续 |
| （暂停里的按钮） | — | `TextureButton`，外观全在 `assets/ui/continue_*.png`，无脚本 |

---

## 八、可调数值在哪

| 数值 | 位置 | 当前值 |
|---|---|---|
| 移动速度 / 加速度 / 摩擦 | `player.gd` 的 `@export` | 273 / 2730 / 5460 |
| 跳跃初速 / 重力 / 短跳系数 | `player.gd` 的 `@export` | -610 / 1550 / 0.65 |
| 死亡动画时长 | `player.gd` 的 `death_duration` | 1.3s |
| 虚影死亡（尸体）时长 | `echo.gd` 的 `fade_duration` | 1.3s |
| 虚影上限 | `echo_manager.gd` 的 `MAX_ECHOES` | 5 |
| 掉出地图判死高度 | `player.gd` 的 `kill_y` | 750 |

主角和虚影的数值都是 `@export`，可以在编辑器检查器里直接改，不用动代码。

---

## 九、`_reference/` 是什么

反编译原始游戏得到的对照资料 + 一次性工具，带 `.gdignore`，**Godot 不会导入、跑游戏不需要它**。

- `source_from_game/` — 反编译出的原版工程（`world.gd` / `main.gd` / `levels.gd`），调数值时可对照
- `tools/` — 素材生成脚本（`make_blocks` / `make_player` / `make_echo_assets` / `make_ui_assets` / `make_level`，均已冻结）
  + 自动化测试脚本（`test_*.gd`，headless 运行）
  + **`check_art_size.py`**（交图后校验尺寸）、`make_art_templates.py`（重新生成可画范围模板）
- `art_templates/` — 角色可画范围模板图（10 倍），见 §3.4
- `preview_*.png` — 各阶段验证截图

---

## 十、还没做

- 压力板 → 开门逻辑（门现在是实体墙，第一关**过不去**）
- 出口结算
- 尖刺的伤害判定
- 箱子、移动平台、第 2–8 关

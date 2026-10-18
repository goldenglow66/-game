# UI 框架独立化与场景化 · 设计文档（待审）

**目标工程**：`C:\Users\Lenovo\Desktop\gamemake\cage-shadow`
**当前版本**：HEAD `7afeaa4` · Godot 4.7.2-stable
**文档状态**：设计稿，**尚未写任何代码**
**结论先行**：UI 目录（`ui/`）将成为可整体搬运的独立模块——不 import 任何游戏类型，只认一份纯数据契约；游戏侧新增 `ui_bridge.gd` 单向投喂数据、接收操作。

---

## 一、目标与范围

### 做什么

1. 把 UI 的**静态骨架**从 GDScript 代码迁移到 `.tscn` 场景（可在编辑器里打开、拖动、实时预览）
2. 把 UI 层与游戏逻辑**彻底解耦**：UI 只依赖 `UIState` 契约，不认识 `RunState` / `Game` / `UpgradeDB` / `EnemyDB` / `Events`
3. 新增 `ui/scenes/preview/ui_preview.tscn`：**不启动游戏**，按 F6 直接预览全部界面状态
4. 建立 `theme.tres` 主题资源与 `ui_components.gd` 组件库，取代散落的静态工厂函数

### 不做什么（本批）

- **不改视觉**：配色常量、字号、间距、发光效果原样保留。美术精细化等用户提供素材后再做
- **不改玩法逻辑**：血条数值、伤害、经济、词条效果一律不动
- **不重写动态列表**：改造台 9 项、黑市商品、终端残页、事件选项、Toast、飘字等运行时生成的内容仍由代码构建
- **不做新界面**：地图、图鉴、设置菜单留到下个批次

---

## 二、现状：耦合点清单（迁移的精确工作量）

### 2.1 文件规模

| 文件 | 行数 | 说明 |
|---|---|---|
| `scripts/ui/ui_root.gd` | 1448（65 个函数） | 全部 UI |
| `scripts/ui/reward_choice.gd` | 279 | 数据舱三选一 |
| `scripts/ui/ui_theme.gd` | 164 | 配色 + 系统字体加载 + 样式工厂 |
| `scenes/Main.tscn` | — | 只有一个空 `Node2D` |

### 2.2 游戏侧对 UI 的直接调用（`main.gd`，69 处）

这些是**迁移的硬约束**——改掉它们意味着 9 个自检一起挂：

```
ui.open_panel(kind)              ui.close_panel()
ui.panel_title.text              ui.panel_body.get_child_count()
ui.panel_footer.text             ui.panel_open
ui.reward.choices[i]             ui.reward.index
ui.reward.is_open()              ui.reward.call("_confirm")
ui.call("_rebuild_panel")        ui.call("_do_event_option", i)
ui.call("_buy_field_item", id)   ui.call("toggle_pause")
ui.call("set_paused", false)     ui.paused
ui.pause_layer.visible           ui.pause_box.get_child_count()
ui.mode                          ui.get("_boss")
ui.show_title()                  ui.show_hub()
ui.show_hud()                    ui.show_gameover(victory, banked)
```

### 2.3 UI 侧对游戏逻辑的反向依赖

| UI 位置 | 依赖 | 说明 |
|---|---|---|
| `HudLayer._draw()` 1323-1397 | `RunState` 全部血条字段 + `Game.difficulty_name()` / `Game.shards_bank` / `Game.coins_bank` / `UpgradeDB.get_upgrade()` | HUD 直接读游戏状态 |
| `_build_rig()` 745-789 | `Game.META_UPGRADES` / `Game.meta_upgrades` / `Game.meta_cost()` / `Game.buy_meta()` / `Game.shards_bank` | 改造台业务逻辑写在 UI 里 |
| `_build_market()` 793-841 | `Game.SHOP_ITEMS` / `Game.pending_boons` / `Game.shop_price()` / `Game.buy_shop_item()` / `Game.refund_shop()` / `Game.coins_bank` | 同上 |
| `_build_terminal()` 852-886 | `Game.intel_seen` / `Game.mark_intel_seen()` | 同上 |
| `_build_exit()` 898-927 | `Game.difficulty` / `Game.difficulty_name()` | 同上 |
| `_build_event_node()` 443-500 | `EventDB.get_event()` / `RunState` / `_current_service_room()` | 同上 |
| `_build_bench()` / `_build_field_market()` / `_build_rest_node()` | `RunState` / `Game` | 同上 |
| `show_title()` 306-322 / `show_gameover()` 343-357 | `Game.stats` / `Game.shards_bank` | 同上 |
| `goto_screen()` 367-373 / `_set_player_controls()` 415-417 | `Game.main.call(...)` | UI 反向驱动游戏 |
| `reward_choice.gd` 全文 | `RunState` / `Events` / `Sfx` / `UpgradeDB` | 三选一直接写回 RunState |
| `_ready()` 50-62 | `Events.*` 九个信号 | 事件总线直连 |

---

## 三、目标结构

```
ui/                                  ← 独立模块，可整体搬到别的工程
├─ scenes/
│   ├─ ui_root.tscn                  总装（CanvasLayer）
│   ├─ hud.tscn                      HUD 骨架
│   ├─ status_bar.tscn               单条状态条（自绘，保留发光）
│   ├─ panel.tscn                    面板基线（10 个面板共用）
│   ├─ title.tscn                    标题页
│   ├─ pause.tscn                    暂停菜单
│   ├─ gameover.tscn                 结算
│   ├─ reward_choice.tscn            数据舱三选一
│   └─ preview/
│       └─ ui_preview.tscn           ★ F6 独立预览，假数据驱动
├─ scripts/
│   ├─ ui_root.gd                    屏幕切换调度（薄）
│   ├─ hud.gd                        HUD 渲染（只读 UIState）
│   ├─ status_bar.gd                 状态条绘制 + 追赶动画
│   ├─ panel.gd                      面板渲染（只读 UIState）
│   ├─ title.gd / pause.gd / gameover.gd / reward_choice.gd
│   ├─ ui_state.gd                   ★ 唯一数据契约
│   ├─ ui_theme.gd                   配色常量 + 字体（保留，瘦身）
│   ├─ ui_components.gd              行/按钮/标题 组件工厂
│   └─ ui_preview.gd                 预览数据源
├─ assets/
│   ├─ theme.tres                    Theme 资源（字体/字号/按钮/面板 StyleBox）
│   └─ fonts/main.ttf                Noto Sans SC（OFL，17.7 MB）

scripts/core/ui_bridge.gd            ← 游戏侧桥接（不属于 ui/，因为它认识游戏类型）
```

**独立性验收命令**（迁移完成后必须为空）：

```powershell
Select-String -Path .\ui\scripts\*.gd -Pattern "RunState|UpgradeDB|EnemyDB|EventDB|Game\.|Events\.|Sfx\."
```

---

## 四、`ui_state.gd` 数据契约

**原则**：UI 只读这个对象；所有业务计算（价格、可用性、文案拼接、克制关系）都在 bridge 里完成。UI 侧不做任何 `if` 业务判断。

```gdscript
class_name UIState extends RefCounted
## UI 层唯一数据源。纯数据，不含任何游戏类型引用。

# ---- 屏幕 ----
var screen: String = "title"          # "title" | "hub" | "run" | "gameover"

# ---- HUD 状态条 ----
var hp: float = 120.0
var hp_max: float = 120.0
var ge: float = 80.0
var ge_max: float = 80.0
var st: float = 100.0
var st_max: float = 100.0
var heat: float = 0.0
var heat_max: float = 100.0
var pollution: float = 0.0            # 0-100

# ---- HUD 文字 ----
var where_text: String = ""           # "织网 · 第 2 扇区 · 难度 普通" / "B2 裁断安全屋"
var element_text: String = ""         # "铳械模块  燃烧   [Tab 切换]"
var shards_bank: int = 0
var coins_bank: int = 0
var shards_run: int = 0
var acquired_count: int = 0
var acquired_names: String = ""       # 已拼接好，UI 直接显示
var consumables_text: String = ""     # 已拼接好

# ---- Boss ----
var boss_active: bool = false
var boss_name: String = ""
var boss_hp: float = 0.0
var boss_hp_max: float = 1.0

# ---- 骇入 ----
var hack_ratio: float = 0.0           # 0-1，0 表示不显示
var hack_label: String = ""

# ---- 交互提示 ----
var interact_text: String = ""
var interact_visible: bool = false

# ---- 面板 ----
var panel_open: bool = false
var panel_kind: String = ""
var panel_title: String = ""
var panel_footer: String = ""
var panel_rows: Array = []            # 见 4.1
var panel_actions: Array = []         # 底部按钮，见 4.2

# ---- 数据舱三选一 ----
var reward_open: bool = false
var reward_cards: Array = []          # 见 4.3

# ---- 结算 ----
var gameover_open: bool = false
var gameover_victory: bool = false
var gameover_title: String = ""
var gameover_lines: Array = []        # [{text, size, color_key}]

# ---- 暂停 ----
var paused: bool = false
```

### 4.1 `panel_rows` 行协议（5 种 kind，UI 渲染器只需认识这 5 种）

```gdscript
# 富文本段落
{"kind": "rich",  "bbcode": "[color=#7d8899]消耗织网碎片……[/color]", "size": 16}

# 普通文字
{"kind": "label", "text": "可用碎片：72", "size": 18, "color": "gold", "align": "left"}

# 间距 / 分隔线
{"kind": "spacer", "h": 4}
{"kind": "divider", "color": "line"}

# 条目行：左信息 + 右按钮
{"kind": "item",
 "title": "外壳强化  [1/3]",
 "desc": "耐久上限 +10",
 "title_color": "bright",          # bright | text | dim
 "buttons": [
    {"id": "meta:shell_hp", "text": "升级 120", "accent": "cyan", "disabled": false},
 ]}
```

**颜色键**（与 `UITheme` 常量同名，UI 侧查表）：`bright` `text` `dim` `cyan` `violet` `amber` `red` `green` `gold` `line`。

### 4.2 `panel_actions`（面板底部按钮）

```gdscript
[{"id": "close", "text": "离开", "accent": "line"}]
```

### 4.3 `reward_cards`（三选一卡片）

```gdscript
{"id": "sword_edge_1", "name": "刃口重塑", "desc": "……",
 "rarity": "rare", "rarity_label": "稀  有", "accent": "blue",
 "stacks": 1, "max_stacks": 3, "tags_text": "剑术 · 通用"}
```

---

## 五、UI → 游戏 的出口

UI 只发**一个**信号，bridge 负责解释：

```gdscript
signal ui_action(id: String, payload: Dictionary)
```

| 场景 | `id` | `payload` |
|---|---|---|
| 标题页按钮 | `"goto_hub"` / `"begin_run"` / `"wipe_save"` | `{}` |
| 面板条目按钮 | `"panel:meta:shell_hp"` / `"panel:shop:medkit"` / `"panel:refund:medkit"` / `"panel:event:0"` … | `{}` |
| 关闭面板 | `"panel:close"` | `{}` |
| 三选一选择 | `"reward_pick"` | `{"id": "sword_edge_1"}` |
| 暂停菜单 | `"pause_resume"` / `"pause_title"` / `"pause_save_quit"` | `{}` |
| 结算 | `"goto_hub"` | `{}` |

**约定**：`id` 字符串在 bridge 里做前缀路由（`panel:` → 面板动作，`reward_` → 三选一）。UI 侧完全不关心 `meta:` / `shop:` 的区别，只负责把点到的按钮 `id` 原样抛出去。

---

## 六、`ui_bridge.gd` 职责

位置：`scripts/core/ui_bridge.gd`（**游戏侧**，认得所有游戏类型）

```gdscript
var root: UIRoot                  # ui_root.tscn 实例
var state: UIState                # 复用的同一份，避免每帧 new

func _ready() -> void:
    root.ui_action.connect(_on_ui_action)
    # 接管原来 UIRoot._ready() 里的 9 个 Events 信号，转成 UI 方法调用

func push() -> void:              # 每帧或状态变化时调用
    _fill_hud(state)
    _fill_panel(state)
    _fill_reward(state)
    root.apply_state(state)

func _on_ui_action(id: String, payload: Dictionary) -> void:
    # panel:meta:shell_hp  → Game.buy_meta("shell_hp") → _refresh_panel() → push()
    # reward_pick          → run.add_upgrade(id) → root.close_reward()
    # goto_hub             → Game.main.goto_hub()
    ...
    push()
```

**原来埋在 UI 里的业务逻辑搬到这里**：`meta_cost`、`shop_price`、`buy_meta`、`buy_shop_item`、`refund_shop`、`intel_seen`、事件选项结算、`_do_event_option`、`_buy_field_item`、`_do_rest_node`。

**桥接层的行构建函数**（每个对应一个面板）：

| bridge 方法 | 替代旧代码 |
|---|---|
| `_rows_bench()` | `_build_bench()` 717-745 |
| `_rows_rig()` | `_build_rig()` 745-789 |
| `_rows_market()` | `_build_market()` 793-841 |
| `_rows_terminal()` | `_build_terminal()` 852-886 |
| `_rows_exit()` | `_build_exit()` 898-927 |
| `_rows_event()` | `_build_event_node()` 443-500 |
| `_rows_field_market()` | `_build_field_market()` 617-651 |
| `_rows_rest_node()` | `_build_rest_node()` 678-699 |
| `_rows_unknown()` | `_build_unknown()` 927-935 |

---

## 七、场景层级设计

### 7.1 `ui_root.tscn`

```
UIRoot (CanvasLayer, layer=10, process_mode=ALWAYS)
└─ UIRootControl (Control, full_rect, MOUSE_FILTER_IGNORE)
   ├─ Hud                 (hud.tscn, invisible 初始)
   ├─ InteractHint        (Label, center_bottom, offset -440/-168/-134/440)
   ├─ BannerBox           (VBoxContainer, center_top, offset 112-212, alpha=0)
   │   ├─ BannerTitle     (Label, 46, bright)
   │   └─ BannerSub       (Label, 19, dim)
   ├─ Subtitle            (Label, 19, bright, autowrap, center_bottom, alpha=0)
   ├─ ToastBox            (VBoxContainer, top_right, offset -430/-28/130/460)
   ├─ PanelLayer          (Control, full_rect, invisible)
   │   ├─ Dim             (ColorRect, Color(0.02,0.03,0.045,0.74), MOUSE_FILTER_STOP)
   │   └─ Center          (CenterContainer, full_rect)
   │       └─ PanelFrame  (panel.tscn 实例)
   ├─ TitleLayer          (title.tscn, invisible)
   ├─ GameoverLayer       (gameover.tscn, invisible)
   ├─ RewardChoice        (reward_choice.tscn, invisible)
   └─ PauseLayer          (pause.tscn, invisible)
```

### 7.2 `hud.tscn`（`_draw()` 手绘 → 节点树）

```
Hud (Control, full_rect, MOUSE_FILTER_IGNORE)
├─ StatsPanel (VBoxContainer, anchor top_left, offset 26/24, width 300, sep 4)
│   ├─ BarHp        (status_bar.tscn, h=18, color=red)
│   ├─ BarGe        (status_bar.tscn, h=13, color=violet)
│   ├─ BarSt        (status_bar.tscn, h=9,  color=green)
│   ├─ BarHeat      (status_bar.tscn, h=7,  color=amber)
│   ├─ BarPollution (status_bar.tscn, h=6,  color=cyan)
│   ├─ WhereLabel   (Label, 13, dim)
│   └─ ElementLabel (Label, 13, violet)
├─ CurrencyBox (VBoxContainer, top_right, offset -28, sep 2)
│   ├─ ShardsLabel    (Label, 18, cyan, right)
│   ├─ CoinsLabel     (Label, 18, gold, right)
│   └─ RunShardsLabel (Label, 15, dim, right)
├─ AcquiredBox (VBoxContainer, bottom_left, offset 28/-44)
│   ├─ CountLabel  (Label, 14, dim)
│   └─ NamesLabel  (Label, 13, dim)
├─ ConsumablesLabel (Label, 14, dim, bottom_right)
├─ BossBar (Control, _draw 自绘, 底部居中)
└─ HackBar (Control, _draw 自绘, 中下)
```

**关键点**：`status_bar.tscn` 内部仍是 `_draw()` 自绘（槽 + 填充 + 发光 + 掉血缓冲层），**视觉零变化**；但它成为一个可复用节点，位置由 `VBoxContainer` 排，不再靠手写 `y += 23.0`。

`status_bar.gd` 属性：

```gdscript
@export var bar_height: int = 18
@export var fill_color: Color = Color.RED
@export var show_label: bool = true
var value: float = 0.0
var max_value: float = 1.0
var _display: float = 0.0        # 平滑追赶用
var _buffer: float = 0.0         # 掉血缓冲层
```

### 7.3 `panel.tscn`（10 个面板共用）

```
PanelFrame (PanelContainer, custom_minimum_size 820×560)
└─ Margin (MarginContainer, l=22 r=22 t=18 b=16)
   └─ Col (VBoxContainer, sep 10)
      ├─ TitleLabel  (Label, 26, bright)
      ├─ Divider1    (ColorRect, h=1, line)
      ├─ Scroll      (ScrollContainer, expand_vertical, h-scroll off)
      │   └─ Body    (VBoxContainer, sep 8, expand_horizontal)
      ├─ Divider2    (ColorRect, h=1, line)
      ├─ FooterLabel (Label, 15, dim)
      └─ ActionsBox  (HBoxContainer, sep 8)   ← 面板底部按钮
```

`panel.gd` 提供：

```gdscript
func apply(state: UIState) -> void      # 重建 Body 与 ActionsBox
```

**注意**：每次 `apply()` 重建 Body 的做法与现状一致（现状也是 `_clear_body()` + 重建）。后续可优化为 diff 更新，本批不做。

### 7.4 `title.tscn` / `pause.tscn` / `gameover.tscn` / `reward_choice.tscn`

结构与现状一一对应，只是从代码搬到场景。按钮文字、颜色、锚点保持不变。

---

## 八、独立预览：`ui_preview.tscn`

```
UIPreview (Control, full_rect)
├─ UIRoot  (ui_root.tscn 实例)
└─ DebugBar (HBoxContainer, 顶部, 仅在预览场景里存在)
    按钮：标题 / 安全屋 / 出击HUD / 满血 / 濒死 / Boss / 骇入中 / 三选一 /
          面板·长椅 / 面板·改造台 / 面板·黑市 / 面板·终端 / 面板·出击 / 面板·事件 / 结算
```

`ui_preview.gd` 直接构造假 `UIState` 并 `root.apply_state(...)`。**不加载游戏、不读存档、不启动 RunState。**

这是「独立」最直观的证明：设计师不跑游戏也能看到每一个界面。

---

## 九、迁移映射表

| 旧代码 | 新位置 | 类型 |
|---|---|---|
| `ui_root.gd:_build()` 67-143 | `ui_root.tscn` | 静态骨架 |
| `_build_panel()` 145-196 | `panel.tscn` | 静态骨架 |
| `_build_title()` 198-264 | `title.tscn` | 静态骨架 |
| `_build_gameover()` 266-302 | `gameover.tscn` | 静态骨架 |
| `_build_pause()` 1215-1250 | `pause.tscn` | 静态骨架 |
| `HudLayer._draw()` 1323-1397 | `hud.tscn` + `status_bar.tscn` + `hud.gd` | 静态骨架 + 渲染 |
| `_build_event_node()` 443-500 | `ui_bridge.gd:_rows_event()` | 业务 → bridge |
| `_build_rig()` 745-789 | `ui_bridge.gd:_rows_rig()` | 业务 → bridge |
| `_build_market()` 793-841 | `ui_bridge.gd:_rows_market()` | 业务 → bridge |
| `_build_terminal()` 852-886 | `ui_bridge.gd:_rows_terminal()` | 业务 → bridge |
| `_build_bench()` 717-745 | `ui_bridge.gd:_rows_bench()` | 业务 → bridge |
| `_build_exit()` 898-927 | `ui_bridge.gd:_rows_exit()` | 业务 → bridge |
| `_build_field_market()` 617-651 | `ui_bridge.gd:_rows_field_market()` | 业务 → bridge |
| `_build_rest_node()` 678-699 | `ui_bridge.gd:_rows_rest_node()` | 业务 → bridge |
| `_build_unknown()` 927-935 | `ui_bridge.gd:_rows_unknown()` | 业务 → bridge |
| `reward_choice.gd` 279 行 | `reward_choice.tscn` + `reward_choice.gd`（卡片仍代码生成） | 混合 |
| `show_title/hub/hud/gameover` 306-357 | `ui_root.gd`（保留，但数据由 bridge 传入） | 保留 |
| `_focus_first_button` / `_move_focus` / `_release_ui_focus` 1006-1042 | `ui_root.gd`（保留） | 保留 |
| `_unhandled_input` 1176-1210 | `ui_root.gd`（保留） | 保留 |
| `goto_screen` 367-373 | **删除**，改由 `ui_action` 上抛 | 解耦 |
| `_set_player_controls` 415-417 | 移入 bridge | 解耦 |
| `_on_banner` / `_on_subtitle` / `_on_toast` / `_on_hack_progress` / `_on_boss_*` | bridge 转调 UI 方法 | 解耦 |

---

## 十、`main.gd` 的同步改动（自检接口）

自检断言直接读写 UI 内部字段，必须提供等价 API，**断言语义不变**：

| 现状写法 | 迁移后 | 说明 |
|---|---|---|
| `ui.panel_body.get_child_count()` | `ui.panel_row_count()` | 返回当前渲染的行数 |
| `ui.panel_title.text` | `ui.get_panel_title()` | 或保留 `panel_title` 属性代理 |
| `ui.panel_footer.text` | `ui.get_panel_footer()` | 同上 |
| `ui.panel_open` | `ui.panel_open`（保留属性） | 直接保留 |
| `ui.reward.choices` | `ui.get_reward_choices()` | 或保留属性 |
| `ui.reward.index = i` | `ui.set_reward_index(i)` | 保留 setter |
| `ui.reward.call("_confirm")` | `ui.confirm_reward()` | 公开方法 |
| `ui.call("_rebuild_panel")` | `bridge.refresh_panel()` | 数据重建在 bridge |
| `ui.call("_do_event_option", i)` | `bridge.do_event_option(i)` | 业务移到 bridge |
| `ui.call("_buy_field_item", id)` | `bridge.buy_field_item(id)` | 同上 |
| `ui.call("toggle_pause")` / `set_paused` | 保留在 `ui_root.gd` | 纯 UI 行为 |
| `ui.paused` / `ui.mode` / `ui.pause_layer` / `ui.pause_box` | 保留 | 无需改动 |
| `ui.get("_boss")` | `ui.get_boss()` | 或保留字段 |

**原则**：`main.gd` 的自检段落尽量少改——保留属性名与公开方法名，把变化挡在 UI 内部。

---

## 十一、分阶段计划与验收

| 阶段 | 内容 | 预计 |
|---|---|---|
| **0** 资产与契约 | 字体入 `ui/assets/fonts/main.ttf`（Noto Sans SC 完整版 17.7 MB）· 生成 `theme.tres` · 写 `ui_state.gd` · 搭 `ui_preview.tscn` 空壳（F6 能跑出空 HUD） | 40 分 |
| **1** HUD | `status_bar.tscn` + `hud.tscn` + `hud.gd`（只读 UIState）· Boss 条 · 骇入条 · 平滑追赶动画 | 1 小时 |
| **2** 面板与桥接 | `panel.tscn` 基线 · `ui_components.gd` · 10 个面板的行构建迁到 `ui_bridge.gd` · `main.gd` 接 bridge | 2 小时 |
| **3** 其余界面 | `title.tscn` / `pause.tscn` / `gameover.tscn` / `reward_choice.tscn` 场景化 | 1 小时 |
| **4** 总装与清场 | `ui_root.tscn` 总装 · 删旧构建代码 · 9 个自检同步 · 独立性 grep · 全界面截图回归 · 提交 | 1 小时 |

**每阶段验收（缺一不可）**：

1. `godot --headless --path . --selfcheck` 等 **9 个自检全部 exit=0、零 SCRIPT ERROR**
2. `project_run` 后 `logs_read(source="game")` **零错误零警告**
3. `editor_screenshot(source="game")` 截图与旧版**肉眼无差异**（本批不改视觉）
4. 阶段 2 起追加：`ui/scenes/preview/ui_preview.tscn` 能 F6 独立运行并切换所有状态
5. 阶段 4 追加：独立性 grep 为空

**回滚策略**：每阶段通过验收后立即 git 提交一次；任一阶段卡住则 `git checkout` 回上一提交点。

---

## 十二、风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| 自检断言依赖 UI 内部字段 | 9 个自检一起挂 | 十节的等价 API 表；保留属性名与方法名 |
| 面板行重建导致焦点丢失 | 键盘导航断掉 | `apply()` 后按 `_remember_focus_id` 恢复焦点 |
| `_draw()` 自绘迁到节点后视觉偏移 | 血条位置/发光变化 | `status_bar.gd` 内部绘制参数逐像素照抄现实现 |
| 每帧 `push()` 造成 GC 压力 | 战斗掉帧 | `UIState` 复用同一实例；只在变化时 `apply_state` |
| 过度抽象 | 代码比现在更难读 | 不做泛型绑定框架；只有 `ui_state.gd` + `ui_bridge.gd` 两个新文件承担解耦 |
| 字体 17.7 MB 进仓库 | clone 变慢 | 用户已确认接受；后续可子集化 |

---

## 十三、待你确认

1. **独立程度**：本文件按「**彻底独立**」设计（UI 零游戏依赖，bridge 承担全部业务）。如果你只想要「场景能独立预览、代码耦不耦无所谓」，阶段 2 可以砍掉 bridge 的一半工作，省约 1.5 小时，但 `ui/` 目录搬不走。**默认按彻底独立执行**，需要降级请明示。
2. **面板刷新方式**：保持现状的「每次重建 Body」，还是这轮就做「按行 diff 更新」？（后者多约 1 小时，但能消除焦点闪烁的根因）
3. **`theme.tres` 的粒度**：只放字体 + 字号 + Button/PanelContainer 的 StyleBox，还是把 Label 各颜色变体也做成主题变体？（后者更规范，但 Label 现在都用 `add_theme_color_override`，改动面更大）

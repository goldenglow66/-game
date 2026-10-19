# 笼中墟影 / Ghost in the Iron Shell

科幻风**横板动作肉鸽**。以《Ghost in the Iron Shell · 笼中墟影》完整游戏设定文档为素材基准
（世界观、角色、敌人、Boss、美术方向、数值表），但**剔除原大纲的 ARPG + 类银河恶魔城类型定位**，
游戏结构改为横板动作 roguelike / roguelite。

## 世界观（摘自设定文档第 2、3 章）

第三次世界大战——**根协议战争**——打完之后，蓝星剩下一层铁皮，和一张还没断的网。
沃克的「茧」计划与新世盟的战争早已结束，但双方的遗产都还活着：撒在地表的是**盲区**，埋在地底的是**织网**。

主角 **Scheris** 的"网络幽灵"不是灵魂魔法——是人格数据在一次裁断行动中被迫离体保存的结果。
肉身早在旧城事故里死透了，记忆被新世盟选择性重写过，让她相信自己只是接受过极端义体改造的特工。
外壳的金属身体分三层：外层战斗装甲、中层神经转译网、内层**幽灵锚定核**。
沃克碎片会黏在锚定核上，所以她会在推进中听见旧世界广播、看见不存在的行人、短暂说出沃克的语句。

> 游戏目前只落了这套设定最表层的一层：**外壳 + 幽灵形态 + 污染值**。叙事部分还没接进来。

## 体验支柱（设定文档 1.1）

| 支柱 | 设定文档想做的事 | 游戏里现在到哪一步 |
|---|---|---|
| 互联探索 | 大区域形成回环，玩家用新能力重新理解旧区域 | **没做**。现在是程序化扇区的线性推进，不是银河城式回环 |
| 可信的背叛 | 新世盟不突然黑化，靠情报筛选、任务矛盾与封锁记录铺垫 | **没做**。叙事还没接进游戏 |
| 战斗组合 | 剑主输出、盾控节奏、铳做远距打断与元素策略、幽灵解系统层 | **已成型**。三段连击 + 完美格挡 + 六种铳模块 + 骇入瘫痪 |
| 选择不只是按钮 | 声望、污染值、证据收集、非致命处理都影响终局 | **半成品**。污染值在跑，但只影响数值与少数事件，没有结局分支 |

> **类型定位是改过的**：原大纲是 ARPG + 类银河恶魔城，本工程做成横板动作 roguelike。
> 保留世界观、角色、敌人、Boss、数值表与美术方向，换掉探索结构与成长循环——
> 上表里那两个"没做"，基本就是这次换类型留下的缺口。

## 一局是怎么打的

1. **B2 裁断安全屋**（据点）：长椅、外壳改造台（碎片买永久升级）、黑市、离线终端、出击升降机。
2. **程序化扇区 × 3 层**：每层 6 个房间，类型从战斗 / 精英 / 商店 / 休整 / 事件 / 核心里按种子排班。
   同一种子必定生成同一张图，换种子就换一张。
3. **清空房间 → 数据舱三选一**：词条只在本局生效，是构筑的主干。
4. **每层末尾一个具名 Boss**：倒下解锁一个铳械模块，然后下潜。
5. **第 3 层 Boss 倒下**：胜利结算，碎片带回据点；中途死亡按难度比例带回一部分。

单场战斗照着设定文档「观察 → 破节奏 → 组合输出 → 资源回收」做的：
Q 探测标出敌人（幽灵体必须被标记才打得中）→ 盾 / 铳打断敌人节奏 → 剑输出 →
处决、骇入或节点回收幽灵能量。

## 大纲里有、游戏里还没有的

- **核心系统**：设定是初始 1 槽、最多 3 槽、只在「核心节点」拿到、分强化型与改机型、每枚都带代价。
  暂停界面里那三个圆形槽位**目前只是占位**，数据层没接。
- **幽灵污染值**：设定里它不是善恶值，是"强能力与真相的代价"——高污染解锁高压对话、关闭隐藏结局。
  现在它只是一个会累积的数值。
- **叙事与支线**：序幕「异常信号」、「裁断之刃」、「碎片化叙事」都没进游戏，只有零散角色台词。
- **传送仓与传送网络**：做了一套更简单的替代品（续关存档 + 五个手动栏位），不是设定里那套。
- **技能树 / 武器升级 / 材料掉落**：现在是「局内词条 + 据点永久升级」两套，没有技能树。

## 运行

需要 **Godot 4.7.x**。本工程是纯 GDScript，不需要 .NET SDK（用的是 mono 版可执行文件，仅因为它是本机安装的那个）。

```powershell
$godot = "C:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
$proj  = "C:\Users\Lenovo\Desktop\gamemake\cage-shadow"

& $godot --path $proj -e     # 打开编辑器
& $godot --path $proj        # 直接运行
```

### 克隆之后第一次运行

`.godot/` 不入库，**首次必须先导入一次**，否则会报
`Could not find type "RunState" in the current scope` 这类全局类名解析错误：

```powershell
& $godot --headless --path $proj --import
```

新增任何带 `class_name` 的脚本之后，也要重跑一次 `--import`。

## 可选：godot-ai MCP 插件

本仓库**不含** `addons/`。开发时用了 [godot-ai](https://github.com/hi-godot/godot-ai) 4.3.0
（Godot 编辑器插件 + MCP 服务器），让 AI 客户端能读到编辑器状态、日志、场景树、性能面板。

想复现这套环境：从 [Godot Asset Library 条目 5050](https://godotengine.org/asset-library/asset/5050)
或该项目的 release 包安装到 `res://addons/godot_ai/`，然后在编辑器里启用插件。

**注意**：插件启用后会自动往 `project.godot` 写入两处配置——

```ini
[autoload]
_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"

[editor_plugins]
enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")
```

仓库里的 `project.godot` 是**不含这两处的干净版本**。本地启用插件后 `git status` 会显示
`project.godot` 被修改——这是预期的，**不要把这两处提交上来**。

## 操作

| 键 | 动作 |
|---|---|
| A / D | 移动 |
| Space | 跳跃（可二段） |
| Shift | 冲刺 |
| J / 鼠标左键 | 挥剑（长按蓄力） |
| K / 鼠标右键 | 格挡（窗口内为完美格挡） |
| L / 鼠标中键 | 铳 |
| Tab | 切换铳械模块 |
| I | 幽灵形态 |
| I 形态下点 J | 骇入最近的敌人（按住不放，直到进度条走完） |
| Q | 探测回波（幽灵体必须被标记才能打出伤害） |
| E | 交互 |
| Esc | 关面板 / 暂停 |
| F3 | 调试叠加层 |

**这些键都能改**：标题页 →「游戏设置」→「按键设置」，点某行的「修改」再按新键即可，
冲突键会自动从原来那个动作身上摘掉。自定义存在 `cage_save.json` 的 `settings.keybinds` 里，
只记改过的动作；列表底部有「恢复默认」。手柄绑定固定，这一版不做自定义。

**界面导航**：任何带按钮的界面（标题页 / 据点面板 / 局内服务 / 三选一 / 暂停菜单 / 结算页）打开时会自动选中第一个按钮，用 **W / S**（或 ↑ / ↓）上下移动，**Enter / 空格**确认，**Esc** 返回上一层。鼠标操作不受影响。

## 存档

| 文件 | 内容 | 时机 |
|---|---|---|
| `cage_save.json` | 跨局元进度：碎片、盲区币、永久升级、难度、统计、玩家设置 | 随时自动 |
| `cage_run.json` | 当前这一局：种子、层数、房间、血量、词条 | 进新房间自动；暂停菜单可手动 |
| `cage_slot_1..5.json` | 五个手动存档栏位 | 标题页「游戏存档」 |

手动保存记**精确坐标**，读档站回原处；自动存档只记**房间入口**，
且不记商店 / 休整房的内部状态——所以直接关掉游戏再续关，那些交互物会重新生成。

## 自检入口

工程内置一批无头自检，参数走 `OS.get_cmdline_user_args()`，所以要写在 `--` 之后。
**一律带上 `--quit-after <帧数>`**，否则进程可能不退出。

```powershell
$g = "C:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
$p = "C:\Users\Lenovo\Desktop\gamemake\cage-shadow"

& $g --headless --path $p --quit-after 3600 -- --selfcheck     # 标题 → 安全屋 → 五个面板 → 出击 → 翻层 → 死亡结算 → 回据点
& $g --headless --path $p --quit-after 9000 -- --combatcheck   # 战斗房刷怪 → 敌人追击开火 → 清空 → 三选一 → 开门推进
& $g --headless --path $p --quit-after 3600 -- --mapcheck      # 跨多个种子验证房间生成不崩且布局有差异
& $g --headless --path $p --quit-after 9000 -- --bosscheck     # 具名 Boss → 击杀 → 解锁铳械模块 → 下潜 → 第三层胜利结算
& $g --headless --path $p --quit-after 3600 -- --elementcheck  # 六种模块切换 + 五类克制倍率 + 弹道是否带着 element 字段
& $g --headless --path $p --quit-after 3600 -- --servicecheck  # 局内售货机 / 维修节点的实体与面板
& $g --headless --path $p --quit-after 3600 -- --pausecheck    # 暂停菜单：确认世界真的停住
& $g --headless --path $p --quit-after 5400 -- --hackcheck     # 幽灵骇入：抗性表、瘫痪、三条中断路径
& $g --headless --path $p --quit-after 5400 -- --eventcheck    # 事件房：面板、四种效果分支、余额不足禁用
```

> **自检不会碰你的存档。** 带 `--selfcheck` / `--combatcheck` / … / `--eventcheck` / `--shot`
> 运行时，存档路径会自动切到 `user://cage_save_selfcheck.json`（见 `scripts/core/game.gd`
> 的 `SAVE_PATH_SANDBOX`），正式游玩的 `cage_save.json` 原样不动。
> 这两者最初是共用一个文件的，跑一次 `--bosscheck` 就会把碎片、胜场和出击次数写进玩家进度。

截图模式要真渲染（不能用 `--headless`）：

```powershell
& $godot --path $p --position -3200,-3200 --quit-after 7200 -- --shot
# 输出到 C:\Users\Lenovo\Desktop\gamemake\_shots\
```

## 目录

```
cage-shadow/
├─ project.godot          1280×720 / 独占全屏 / viewport 拉伸 / GL 兼容渲染器
├─ scenes/Main.tscn       唯一场景，其余节点全部代码构建
├─ scripts/
│  ├─ core/               事件总线、输入映射与按键自定义、元进度与存档、局内状态、音效合成、主状态机与自检
│  ├─ data/               局内词条库 + 六种铳械模块 + 事件房奇遇库
│  ├─ enemies/            敌人档案（含具名 Boss）与敌人实体
│  ├─ fx/                 轻量特效：残影 / 火花 / 伤害数字 / 光环 / 浮动文字
│  ├─ ui/                 HUD（自绘）与仍走代码构建的各个面板
│  ├─ units/              玩家与弹道
│  └─ world/              安全屋、关卡生成、房间、门、拾取物、相机、环境背景
├─ ui/                    已场景化的界面，每个都能单独打开 / F6 预览
│  ├─ scenes/             title / pause_menu / pause_equip / pause / archive / settings
│  ├─ scenes/preview/     各自独立的假数据预览场景
│  └─ scripts/            对应的 Control 脚本（只发信号，不认识 Game）
└─ docs/ROADMAP.md        分阶段路线图
```

## 美术与音频

**零外部素材**：所有画面由 `_draw()` 程序化绘制，所有音效由 `AudioStreamWAV`
在 `scripts/core/sfx.gd` 里合成 PCM。仓库里没有图片和音频文件需要管理。

中文字形靠运行时加载系统字体（`scripts/ui/ui_theme.gd` 的 `get_font()`）：
先找 `res://assets/fonts/main.ttf|otf|ttc`，找不到再回退到系统里的
Microsoft YaHei / SimHei / Noto Sans CJK SC 等。

# 笼中墟影 / Ghost in the Iron Shell

科幻风**横板动作肉鸽**。以《Ghost in the Iron Shell · 笼中墟影》完整游戏设定文档为素材基准
（世界观、角色、敌人、Boss、美术方向、数值表），但**剔除原大纲的 ARPG + 类银河恶魔城类型定位**，
游戏结构改为横板动作 roguelike / roguelite。

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

**界面导航**：任何带按钮的界面（标题页 / 据点面板 / 局内服务 / 三选一 / 暂停菜单 / 结算页）打开时会自动选中第一个按钮，用 **W / S**（或 ↑ / ↓）上下移动，**Enter / 空格**确认，**Esc** 返回上一层。鼠标操作不受影响。

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
├─ project.godot          1280×720，autoload: Events / Game / Sfx
├─ scenes/Main.tscn       唯一场景，其余节点全部代码构建
├─ scripts/
│  ├─ core/               事件总线、输入映射、元进度与存档、局内状态、音效合成、主状态机与自检
│  ├─ data/               局内词条库 + 六种铳械模块 + 事件房奇遇库
│  ├─ enemies/            敌人档案（含具名 Boss）与敌人实体
│  ├─ fx/                 轻量特效：残影 / 火花 / 伤害数字 / 光环 / 浮动文字
│  ├─ ui/                 全息 UI 主题、HUD 与各面板、数据舱三选一
│  ├─ units/              玩家与弹道
│  └─ world/              安全屋、关卡生成、房间、门、拾取物、相机、环境背景
└─ docs/ROADMAP.md        分阶段路线图
```

## 美术与音频

**零外部素材**：所有画面由 `_draw()` 程序化绘制，所有音效由 `AudioStreamWAV`
在 `scripts/core/sfx.gd` 里合成 PCM。仓库里没有图片和音频文件需要管理。

中文字形靠运行时加载系统字体（`scripts/ui/ui_theme.gd` 的 `get_font()`）：
先找 `res://assets/fonts/main.ttf|otf|ttc`，找不到再回退到系统里的
Microsoft YaHei / SimHei / Noto Sans CJK SC 等。

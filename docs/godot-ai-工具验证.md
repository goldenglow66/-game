# godot-ai MCP 工具可用性验证（交接文档）

**来源会话**：DSH 新会话（cwd `C:\Users\Lenovo\Desktop\gamemake\文案`）
**用途**：把「Godot MCP 工具全部可调用」这一验证结论交接给开发会话「科幻横板肉鸽动作游戏制作」
**目标工程**：`C:\Users\Lenovo\Desktop\gamemake\cage-shadow`

---

## 一句话结论

**godot-ai 插件（v4.3.0）的 47 个工具全部已注册且全部可调用**，`exclude_domains` 为空。
工具本身无故障；报错的场景都是**前置条件不满足**（类型不匹配 / 资源不存在 / 游戏未运行），属于正确拒绝。

## 连接信息

```
session_id     : cage-shadow@51fd1a2921e2412b
project_path   : C:/Users/Lenovo/Desktop/gamemake/cage-shadow/
godot_version  : 4.7.2-stable (official)
plugin_version : 4.3.0        protocol_version: 2
server_launch  : uvx          editor_pid: 31944
current_scene  : res://scenes/Main.tscn
readiness      : ready        play_state: stopped
```

注：`session_manage` 里同时存在第二个同名会话 `cage-shadow@c3d773ac3fec0c7e`（editor_pid 41776，`is_active: false`），是旧编辑器进程的残留注册。多开会话时应先 `session_activate` 指定，否则可能打到错误的编辑器。

---

## 二、实测矩阵

### ✅ 已验证可直接调用（36 个）

| 域 | 工具 | 实测证据 |
|---|---|---|
| 会话 | `session_manage`、`session_activate` | 列出 2 个会话、字段完整 |
| 编辑器 | `editor_state`、`editor_manage`(state/selection_get/monitors_get) | 30 项性能监视器真实读数；选中路径 `/Main` |
| 编辑器 | `editor_screenshot`(viewport_2d) | 出图 1700×709 → 480×200 PNG |
| 场景 | `scene_get_hierarchy`、`scene_manage`(get_roots) | 读到 `/Main`(Node2D)，total 1 |
| 节点 | `node_create`、`node_find`、`node_get_properties`、`node_set_property` | 建 `/Main/TempProbe` 并改写 position |
| 节点 | `node_manage`(get_children/get_groups/add_to_group/duplicate/delete) | 全套通过 |
| 脚本 | `script_create`、`script_manage`(read/find_symbols)、`script_patch`、`script_attach` | 建脚本→读→改→挂载，`diagnostics_status: checked`、`reloaded: true` |
| 信号 | `signal_manage`(list/connect) | 连上 `ready → ping` |
| 批处理 | `batch_execute` | 2 条子命令顺序执行，`succeeded: 2` |
| 资源 | `resource_manage`(search/get_info/load/create/gradient_texture_create) | 建 Environment / GradientTexture2D 成功 |
| 文件 | `filesystem_manage`(search/read_text/write_text/remove/scan) | 读写删全通；`scan` 报 `global_class_count: 77` |
| 材质 | `material_manage`(list/create/set_param) | 建 .tres 并设 `albedo_color` |
| 主题 | `theme_manage`(create/set_color/apply) | 建主题、设 `Label.font_color`、应用到 Control |
| UI | `ui_manage`(build_layout/set_text/set_anchor_preset) | 建 Control+Label 子树、改文本、设 center 锚点 |
| 相机 | `camera_manage`(list/create/configure) | 建 Camera2D 并设 zoom |
| 粒子 | `particle_manage`(create/set_main) | 建 GPUParticles2D，自动建 ProcessMaterial |
| 动画 | `animation_create`、`animation_manage`(player_create/create_simple) | 建播放器 + 建带 1 条轨道的动画 |
| 日志 | `logs_read`(plugin/editor/all) | 编辑器有 **37 条** GDScript 警告（见下） |
| 输入 | `input_map_manage`(list/ensure_action/ensure_binding/remove_action) | 建 F9 绑定并成功移除 |
| 项目 | `project_manage`(settings_get) | 读到 `笼中墟影 / Ghost in the Iron Shell` |
| 单例 | `autoload_manage`(list) | Events / Game / Sfx / `_mcp_game_helper` |
| API | `api_manage`(get_class) | Node2D 属性+继承链+默认值 |
| 测试 | `test_run`、`test_manage`(results_get) | 正确报「`res://tests/` 目录不存在」 |
| 音频 | `audio_manage`(list) | 正确返回 0 条（工程目前无音频资源） |
| 客户端 | `client_manage`(status) | 26 个客户端，DeepSeek Harness = configured |
| 扩展 | `custom_manage`(list) | 返回 0（无第三方注册工具） |
| 资源读取 | `read_mcp_resource` | `godot://project/info` 返回真实 JSON |

### ⚠️ 工具正常、前置条件不满足（7 个，均为正确拒绝）

| 工具 | 触发条件 | 报错原文 |
|---|---|---|
| `editor_screenshot`(viewport) | 场景是 2D 根节点 | `EDITOR_NOT_READY: ... viewport_not_3d ... suggestion=use source='viewport_2d'` |
| `animation_manage`(list) | 目标不是 AnimationPlayer | `WRONG_TYPE: Node at /Main is not an AnimationPlayer (got Node2D)` |
| `csg_manage` | 父节点不是 Node3D | `WRONG_TYPE: CSG parent must be a Node3D (got Node2D)` |
| `gridmap_manage` | 目标不是 GridMap | `WRONG_TYPE: Node is not a GridMap: /Main` |
| `tilemap_manage` | 目标不是 TileMapLayer | `WRONG_TYPE: Node is not a TileMapLayer: /Main` |
| `tileset_manage` | TileSet 不存在 | `RESOURCE_NOT_FOUND: TileSet resource not found: res://nonexistent.tres` |
| `navigation_manage`(path_get) | 无导航区域 | 正常返回 `point_count: 0`（空路径，非报错） |

**这条很重要**：项目当前是纯 2D 程序化构建（`Main.tscn` 只有一个 Node2D 根，所有节点由代码生成），所以**CSG / GridMap / TileMap / TileSet / 3D 截图这几族工具对现在的工程结构用不上**——除非将来改成编辑器里摆关卡。

### ⏸ 未实测（有意跳过，避免改动你的编辑器状态 / 项目配置）

| 工具 | 跳过原因 |
|---|---|
| `game_manage`（全部 12 个 op） | 需要游戏在运行 |
| `project_run`、`project_manage`(stop) | 会启动游戏窗口，等你确认后再试 |
| `editor_manage`(quit) | 会关闭你的编辑器 |
| `editor_reload_plugin` | 会断连并重建会话 |
| `client_manage`(configure/remove) | 会改写客户端配置文件 |
| `scene_manage`(create/save_as)、`scene_save` | 会切换/覆写当前场景 |
| `autoload_manage`(add/remove)、`project_manage`(settings_set/set_main_scene) | 会改 `project.godot` |

## 三、踩过的坑（写代码时会用到）

1. **`project_run` 默认 `autosave: true`** —— 会把编辑器内存里的节点改动写进 `Main.tscn`。做冒烟测试要显式传 `autosave: false`。
2. **`filesystem_manage` / `navigation_manage(bake)` 不能放进 `batch_execute`**，必须直接调用。
3. **写文件类工具不可撤销**：`script_create`/`write_text`/`material_manage(create)` 等返回 `undoable: false` 并附 `cleanup.rm` 清单——探针文件要手动删。
4. **`input_map_manage` 的写操作直接落盘 `project.godot`**（`persisted: true`），不是内存改动。
5. **节点/属性/动画类写操作 `undoable: true`**，走编辑器 undo 栈。
6. **`script_patch` / `script_create` 对已加载脚本会热重载**（`reloaded: true`），改脚本即时生效，不必重启编辑器。
7. `filesystem_manage(remove)` 默认进回收站，探针文件用 `permanent: true` 才真删。
8. **`game_manage` 的 `input_action` / `input_sequence` 不产生 `InputEvent`** —— 它们直接改 `Input` 的动作状态（等价 `Input.action_press()`），只会被 `Input.is_action_pressed()` 这类**轮询**读法看到，**进不了 `_unhandled_input(event)`**。要触发事件驱动的输入处理，必须用 `input_key`（`{"key": "Down", "pressed": true}`，再发一次 `false`）。这一条害我先误判过一次，见第七节。

## 四、探针清理结果（已确认零残留）

- 临时节点 7 个（`TempProbe` / `TempProbeCopy` / `ProbeCam` / `ProbeParticles` / `ProbeUI` / `ProbeAnim` / `ProbeBatch`）→ 全部删除，`/Main` 子节点数回到 **0**，**未保存场景文件**
- 临时文件 6 个（`_probe_tmp.gd` / `_probe_mat.tres` / `_probe_theme.tres` / `_probe_env.tres` / `_probe_grad.tres` / `_probe_fs.txt`）→ 永久删除，`filesystem_manage(search "_probe")` 返回 0
- 输入动作 `_probe_action` → 已移除，`input_map_manage(list)` 回到 **0 条**
- `git status --porcelain` 只剩 ` M project.godot` 与 `?? addons/`

**关于 `M project.godot`**：diff 内容**与探针无关**，是你安装插件时产生的，只多了两处：

```ini
Events="*res://scripts/core/events.gd"
Game="*res://scripts/core/game.gd"
Sfx="*res://scripts/core/sfx.gd"
+_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"

+[editor_plugins]
+enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")
```

这两处应该提交。另外 `?? addons/` 说明 `addons/` 目录**未被 git 跟踪**——插件的 `.gitignore` 可能把 `addons/` 排除了，clone 下来的工程不会带插件。要不要入库由你定。

## 五、顺带读到的工程现状（对开发有用的旁证）

- `Main.tscn` 全文 8 行，只有 `/Main`(Node2D, position 63,96) + `res://scripts/core/main.gd`，符合「代码优先」设计
- autoload 4 个：`Events` / `Game` / `Sfx` / `_mcp_game_helper`
- **键位走的是运行时 InputMap，不是 `project.godot`**：`input_map_manage(list)` 返回 **0 条**，是因为 `scripts/core/input_actions.gd` 的 `InputActions.register_all()` 在启动时才把动作注册进 InputMap。文件里没有 ≠ 运行时没有。
- 编辑器警告 37 条，全部来自 `res://scripts/core/events.gd`，形如：
  `GDScript::reload: The signal "player_spawned" is declared but never explicitly used in the class.`（第 8–19 行等，信号总线声明了但类内未用，属噪音非错误）
- `global_class_count: 77`（含插件自身类）
- 无音频资源、无材质资源、无 TileSet、无 `res://tests/` 目录

---

## 六、运行类工具补测（第二轮，已全部完成）

第一轮跳过的运行类工具，第二轮全部实测通过：

| 工具 / op | 结果 |
|---|---|
| `project_run`(main, autosave=false) | 两次启动均成功；`run_token` 递增 1→2 |
| `project_manage`(stop) | `stopped: true`、`was_running: true`、`readiness_after: ready` |
| `editor_screenshot`(game) | 真渲染帧 1280×720，`stale_frame: false` |
| `logs_read`(game) | 两个 run 各 1 行，**零报错** |
| `game_manage`(get_scene_tree) | 16 个节点，`/Main` → BackgroundLayer / World / UIRoot |
| `game_manage`(get_node_info) | `/Main/UIRoot/UIRootControl` 100+ 属性 |
| `game_manage`(get_ui_elements) | 11 个可见 Control，含 `TitleInfo` 文本「已出击 5 次 · 最长下潜 3 扇区 · 织网碎片 72」 |
| `game_manage`(debug_status) | `frames_drawn` / `physics_frames` / `time_scale` 实时读数 |
| `game_manage`(input_state) | 全量动作表（含项目自定义的 `attack`/`dash`/`ghost`/`probe` 等） |
| `game_manage`(input_sequence) | `steps_applied: 2`、`completed: true`、`frames_elapsed: 26` |
| `game_manage`(input_key) | `Down` 按下与释放均 `sent: true` |
| `game_manage`(input_mouse) | motion 事件 `sent: true` |
| `game_manage`(suspend) | `suspended: true`、`time_scale: 0.0`、`verified: true`、`path: embed_signal` |
| `game_manage`(next_frame) | `ticks_advanced: 1`、`verified: true`、触发焦点交还（`main_screen: "Game"`） |
| `game_manage`(resume) | `suspended: false`、`time_scale: 1.0`、`verified: true` |
| `editor_manage`(game_eval) | 返回 `{"screen": 0.0, "world_children": 0.0, "engine_fps": 240.0}` |

**唯一未测**：`game_manage`(input_gamepad) —— 需要真实手柄设备，工程也没接手柄。

### 重要使用提示

1. **`project_run` 返回 `status: "not_live"` 不代表启动失败**。它只等 3 秒，而 Godot 启动游戏约需 5 秒。实测两次都是先返回 `not_live` + `reason: "Game launched but did not become live before the helper-ready window elapsed"`，随后轮询 `editor_state` 就变成 `live` / `helper_live: true`。**别急着重试，先查 `editor_state`**。
2. **`project_run` 务必传 `autosave: false`**，否则编辑器内存里的 MCP 改动会被写进 `Main.tscn`。
3. `game_eval` 直接在游戏进程里跑 GDScript 并返回值，是读运行时内部状态最快的路。示例（已验证可用）：
   ```gdscript
   var m = get_node_or_null("/root/Main")
   if m == null:
       return {"error": "no /root/Main"}
   var w = get_node_or_null("/root/Main/World")
   return {"screen": m.get("screen"), "world_children": (w.get_child_count() if w else -1), "engine_fps": Engine.get_frames_per_second()}
   ```
4. `suspend` / `resume` / `next_frame` 走 `path: "embed_signal"`，会同步 Game View 的挂起按钮状态；`next_frame` 还会把焦点交还给游戏窗口。
5. 两次运行游戏**均未写存档**（`%APPDATA%\cage-shadow\cage_save.json` 时间戳保持 2:21:36 不变），`git status` 也始终只有 ` M project.godot` 与 `?? addons/`。**但跑无头自检会写存档** —— 见第八节。
6. `game_eval` 编译失败时只说 `EVAL_COMPILE_ERROR`，具体错误拿不到（"去看编辑器的输出面板"）。**带 `if ...: return ...` 的多行块容易编译不过**，写成单行 + 三元表达式最稳：
   ```gdscript
   var m = get_node_or_null("/root/Main"); var vp = m.get_viewport(); var f = vp.gui_get_focus_owner(); return {"index": (f.get_index() if f != null else -1)}
   ```
   游戏窗口被遮住、主循环停滞时它会报 `EVAL_GAME_NOT_READY`，同样条件下 `editor_screenshot` 会返回 `stale_frame: true` 并附说明。

## 七、发现并修好的一个真实缺口：整个 UI 只能鼠标操作

### 起因
`input_sequence` 注入 `move_down` / `ui_down` 后标题菜单高亮不动。

### 排查到的代码事实
- `scripts/ui/ui_root.gd` 的 `_mk_button()` 是**全工程唯一的按钮工厂**，20+ 个调用点（标题页 3、结算页 1、据点面板区 18、暂停菜单 4）全部经过它；而它在 `ui_root.gd:941` 写死 `b.focus_mode = Control.FOCUS_NONE`
- `ui_root.gd:1089` 的 `_unhandled_input()` 只处理 `pause` / `cancel` / `interact`，没有任何上下导航分支
- 全工程 `is_action_just_pressed` 只出现在 `scripts/units/player.gd`（第 210/218/225/253/257/261/264/268 行）
- 对比：`scripts/ui/reward_choice.gd:234` 的三选一**有**自己的 `_unhandled_input` 键盘处理，所以它是唯一能用键盘的界面

**结论**：不只是标题页 —— 据点五个面板、局内服务面板、暂停菜单、结算页**全都只能点鼠标**。纯键盘玩家进门就卡住。

### 修复（`scripts/ui/ui_root.gd`，10 处改动）
1. `_mk_button()`：`FOCUS_NONE` → `Control.FOCUS_ALL`，并加 `focus` 样式（白色描边 2px，跟按钮自身的 accent 色区分开，键盘走到哪一眼能看见）与 `font_focus_color`
2. 新增「键盘可达」小节：`_buttons_in()`（`find_children("*", "Button", true, false)` 收集可聚焦按钮，按渲染位置先 y 后 x 排序）、`_active_ui_layer()`（优先序 暂停层 → 面板层 → 结算层 → 标题层，都没有返回 `null`）、`_focus_first_button()`（延一帧等布局算完再 `grab_focus()`）、`_move_focus(dir)`（读 `gui_get_focus_owner()`，环形移动）、`_release_ui_focus()`
3. `_unhandled_input()` 在 `if paused: return` **之前**插入 `move_up` / `move_down` 分支（这样暂停菜单也吃这套）；没有可见 UI 层时 `_move_focus` 返回 `false`、不消费输入，**游戏中按 W/S 依然是玩家移动**
4. 聚焦时机：`show_title()` 末尾、`show_gameover()` 末尾、`_rebuild_panel()` 末尾、`set_paused(true)` 的 `_rebuild_pause()` 之后
5. 释放时机：`show_hub()`、`show_hud()`、`close_panel()`、`set_paused(false)`、`_on_reward_choices()`（**这条最关键**：三选一靠 `_unhandled_input` 收 `confirm`，旧按钮若还持有焦点，Enter 会被 Button 在 `_gui_input` 阶段吃掉）
6. 确认键不用自己实现：`Button` 内建的 `ui_accept`（Enter / Space）在有焦点时自动触发 `pressed`

### 验证（实测）
| 操作 | 结果 |
| --- | --- |
| 启动到标题页 | 白框自动落在「进入安全屋」上 ✅ |
| `input_key("Down")` | 焦点移到「直接出击（测试）」✅ |
| 再按一次 `Down` | 焦点移到「清除存档」，`game_eval` 读到 `index: 2` ✅ |

环形回绕（`(idx + dir + size) % size`）与暂停/面板内的导航未逐项实测 —— 游戏窗口被浏览器盖住后主循环停滞（`loop_live: false`），`input_key` 送不进去。这几处走的是同一套 `_move_focus` / `_focus_first_button`，逻辑一致。

### 教训
「注入输入没反应」有三种完全不同的原因，排查时必须分清：① 游戏真的没接这个动作；② 注入了，但走的是轮询路径，事件驱动的代码收不到（本例的 `input_action`）；③ 窗口后台、主循环停滞。我一开始把 ② 当成了 ①，绕了远路。

---

## 八、另一个已修的坑：无头自检会写玩家存档

### 怎么发现的
跑完九个无头自检做工程体检后，`%APPDATA%\cage-shadow\cage_save.json` 时间戳从 `2:21:36` 跳到 `2:54:54`，`shards_bank` 从 72 变成 144 —— 正好等于 bosscheck 输出的 `[BOSS] final: ... banked=72 shards_bank=144`。

### 根因
`scripts/core/game.gd:9` 的 `const SAVE_PATH := "user://cage_save.json"` 被自检和正式游玩共用；自检会真跑 `start_run` → `end_run` 结算，沿途 9 处调用 `save_meta()`（`game.gd:122/142/225/245/258/277/319/349`）。

### 修复（`scripts/core/game.gd`，6 处）
- 新增 `const SAVE_PATH_SANDBOX := "user://cage_save_selfcheck.json"` 与 `var save_path: String = SAVE_PATH`
- `_ready()` 里 `if is_autotest_run(): save_path = SAVE_PATH_SANDBOX`，并打印 `[Game] 自检模式：存档切到 ...（玩家存档 ... 不动）`
- `load_meta()` / `save_meta()` 的 `FileAccess` 调用与 `push_warning` 全部改用 `save_path`
- 新增 `static func is_autotest_run() -> bool:`，遍历 `OS.get_cmdline_user_args()`，`if s.ends_with("check") or s == "--shot": return true`

### 验证
- 重跑 `--bosscheck`：打印切路径提示，玩家存档时间戳 `unchanged=True`，沙盒存档独立生成
- 回归 `selfcheck` / `combatcheck` / `eventcheck` 全绿，玩家存档纹丝不动
- `README.md` 自检章节与 `docs/ROADMAP.md` 第 4 节都补了说明

### 已经造成的污染（已回滚）
体检期间被写坏过一次，按可确认的字段精确回滚：`coins_bank` 1360 → 1020、`shards_bank` 144 → 72、`runs` 7 → 5。`wins` / `deaths` / `playtime` 无法确知原值，未动。污染值备份在 `cage_save.dirty-backup.json`，更早那份在 `cage_save.asfound-20261016-0254.json`。游戏内 TitleInfo 已确认回到「已出击 5 次 · 最长下潜 3 扇区 · 织网碎片 72」。

### 顺带一提
编辑器那 37 条警告里有 4 条是真能清的（其余 33 条是 `events.gd` 信号总线的必然噪音）：
- `scripts/enemies/enemy.gd:83` 局部变量 `scale` 遮蔽 `Node2D.scale`
- `scripts/enemies/enemy.gd:559` `_is_weak_spot()` 的参数 `info` 未使用
- `scripts/units/player.gd:95` 类变量 `_step_t` 未使用
- `scripts/world/run_world.gd:361` `_offer_reward()` 的参数 `r` 未使用

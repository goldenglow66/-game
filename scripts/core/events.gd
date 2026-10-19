extends Node
## 全局事件总线（Autoload: `Events`）。
##
## 【它是什么】
## 整个游戏里"发生了某件事"的广播中心。任何节点都可以 `Events.xxx.emit(...)` 喊一嗓子，
## 任何节点都可以 `Events.xxx.connect(...)` 举手接收，**双方不需要认识对方**。
##
## 【为什么要它】
## 没有总线的话，敌人死亡要通知：房间计数、掉落物生成、UI 飘字、音效、成就统计……
## 每个通知点都得让"敌人"持有"房间""UI""音效"的引用。一旦某个节点被重建，
## 旧引用就变成野指针，游戏随机崩溃。有了总线，敌人只管喊，谁听谁负责。
##
## 【怎么用】
## 发：`Events.toast.emit("存档已保存", UITheme.CYAN)`
## 收：`Events.toast.connect(_on_toast)`   ← 通常写在接收方自己的 `_ready()` 里
##
## 【注意】
## - 信号**只广播、不返回值**。需要拿结果的场景（比如"这次伤害打掉多少血"）
##   应该用函数调用，不要用信号。
## - 编辑器会对这里的 signal 报 `declared but never used` 警告，**这是误报**：
##   signal 由其他文件的 `emit` / `connect` 使用，GDScript 只看当前文件自然看不到。
##   可以放心无视，不要为了消警告去删信号。

# ================== 玩家 ==================
# 发：player.gd（自身状态变化时）
# 收：ui_root.gd 的 HUD、fx_lite.gd 的特效、run_world.gd 的死亡判定

## 玩家节点进入场景后广播，携带玩家引用本身。
signal player_spawned(player: Node2D)
## 玩家死亡（血量为 0）。由 run_world 决定结算流程。
signal player_died()
## 生命值变化，给 HUD 血条用。
signal player_hp_changed(current: float, maximum: float)
## 幽灵能量（GE）变化。GE 是幽灵形态的燃料。
signal player_ge_changed(current: float, maximum: float)
## 姿态值（ST/韧性）变化。ST 被打空会进入姿态崩溃。
signal player_st_changed(current: float, maximum: float)
## 铳的热量变化。热量满了会过热禁射。
signal player_heat_changed(current: float, maximum: float)
## 格挡状态变化（举起/放下盾）。
signal player_guard_changed(is_guarding: bool)
## 幽灵形态开关。幽灵形态下可以相位滑行、骇入敌人。
signal ghost_form_changed(active: bool)
## 污染值变化。污染过高会有负面事件。
signal pollution_changed(value: float)


# ================== 战斗 ==================
# 发：player.gd / enemy.gd / projectile.gd
# 收：fx_lite.gd（火花飘字）、game_camera.gd（震屏）、sfx.gd（打击音）、ui_root.gd

## 造成伤害时广播。info 结构：{target, amount, kind, crit, position, source}
signal damage_dealt(info: Dictionary)
## 受到伤害时广播。info 结构：{amount, kind, position, source}
signal damage_taken(info: Dictionary)
## 敌人死亡，携带敌人节点和死亡世界坐标（用于掉落与飘字）。
signal enemy_killed(enemy: Node, position: Vector2)
## 请求"卡肉"（命中瞬间短暂定格）。duration 单位秒，通常 0.03~0.08。
signal hitstop_requested(duration: float)
## 请求镜头震动。amount 是幅度（像素），duration 是持续时间。
signal shake_requested(amount: float, duration: float)
## 完美格挡触发（在受击窗口内按盾），携带触发位置，用来放特效。
signal perfect_guard(position: Vector2)
## 一次骇入完成，携带被骇入的敌人。
signal hack_completed(target: Node)
## 骇入进度推送。ratio 为 0..1；target 传 null 表示这次骇入已结束（成功或中断）。
signal hack_progress(target: Node, ratio: float)


# ================== 局内流程 ==================
# 发：main.gd（切场景）、run_world.gd（进出房间）
# 收：ui_root.gd（Boss 血条、横幅）、level.gd（生成房间）

## 一局开始，携带这局的随机种子（同种子必生成同一张图）。
signal run_started(seed_value: int)
## 一局结束。victory 为 true 表示打通第 3 层。
signal run_ended(victory: bool)
## 进入某一层。index 从 0 开始，theme_id 是主题标识（铁笼/织网…）。
signal floor_started(index: int, theme_id: String)
## 进入某个房间，携带 Room 对象。
signal room_entered(room)
## 房间清空（敌人全灭），携带 Room 对象。
signal room_cleared(room)
## Boss 登场，携带 Boss 节点（UI 据此挂 Boss 血条）。
signal boss_started(boss: Node)
## Boss 被击败，携带 Boss 节点。
signal boss_defeated(boss: Node)


# ================== 构筑与经济 ==================
# 发：run_world.gd（清房后）、ui_root.gd（玩家选了词条）
# 收：ui_root.gd 的三选一面板、HUD 的资源显示

## 提供一次三选一的候选词条（Array[Dictionary]）。
signal reward_choices_offered(choices: Array)
## 玩家实际取了一个词条，携带该词条数据。
signal upgrade_taken(upgrade: Dictionary)
## 货币变化（盲区币 / 织网碎片），携带变化后的数值。
signal currency_changed(amount: int)


# ================== 表现与叙事 ==================
# 发：任何想提示玩家的地方
# 收：ui_root.gd（右下角提示条 / 底部字幕 / 居中横幅）

## 右下角冒一条短提示。color 决定颜色（青色=正常、红色=失败）。
signal toast(text: String, color: Color)
## 屏幕底部字幕。speaker 是说话人名（如"卡斯特"），空字符串表示旁白。
signal subtitle(text: String, speaker: String)
## 屏幕中上的大横幅，用于"织网 · 第 1 扇区"这种章节标题。
signal banner(title: String, subtitle: String)


# ================== 据点（安全屋） ==================
# 发：interactable.gd（玩家按 E 碰到可交互物）
# 收：ui_root.gd（开对应面板）、hub.gd

## 玩家触发了某个可交互物。kind 决定开哪个面板：
## bench / rig / market / terminal / exit
signal hub_interact(kind: String, source: Node)
## 据点面板被关闭，携带面板类型（有些逻辑要在关闭时刷新状态）。
signal hub_panel_closed(kind: String)
## 请求出击（从据点进关卡）。
signal hub_request_run()

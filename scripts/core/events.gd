extends Node
## 全局事件总线（Autoload: Events）
##
## 设计原则：发出者不关心谁在听。战斗、房间、UI、音频、存档各自订阅自己需要的信号，
## 避免节点之间互相持有引用而导致的耦合与引用失效。

# ---------------- 玩家 ----------------
signal player_spawned(player: Node2D)
signal player_died()
signal player_hp_changed(current: float, maximum: float)
signal player_ge_changed(current: float, maximum: float)
signal player_st_changed(current: float, maximum: float)
signal player_heat_changed(current: float, maximum: float)
signal player_guard_changed(is_guarding: bool)
signal ghost_form_changed(active: bool)
signal pollution_changed(value: float)

# ---------------- 战斗 ----------------
signal damage_dealt(info: Dictionary)      # {target, amount, kind, crit, position, source}
signal damage_taken(info: Dictionary)      # {amount, kind, position, source}
signal enemy_killed(enemy: Node, position: Vector2)
signal hitstop_requested(duration: float)
signal shake_requested(amount: float, duration: float)
signal perfect_guard(position: Vector2)
signal hack_completed(target: Node)
signal hack_progress(target: Node, ratio: float)   # ratio 0..1；target 为 null 表示骇入结束

# ---------------- 局内流程 ----------------
signal run_started(seed_value: int)
signal run_ended(victory: bool)
signal floor_started(index: int, theme_id: String)
signal room_entered(room)
signal room_cleared(room)
signal boss_started(boss: Node)
signal boss_defeated(boss: Node)

# ---------------- 构筑与经济 ----------------
signal reward_choices_offered(choices: Array)
signal upgrade_taken(upgrade: Dictionary)
signal currency_changed(amount: int)

# ---------------- 表现与叙事 ----------------
signal toast(text: String, color: Color)
signal subtitle(text: String, speaker: String)
signal banner(title: String, subtitle: String)

# ---------------- 据点（安全屋） ----------------
signal hub_interact(kind: String, source: Node)
signal hub_panel_closed(kind: String)
signal hub_request_run()

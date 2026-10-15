extends Node
## 全局游戏管理（Autoload: Game）
##
## 负责：输入映射注册、元进度与存档、当前这一局（RunState）的生命周期、
## 难度倍率、全局打击停顿（hitstop）。具体关卡与 UI 由 Main 场景驱动。

enum Difficulty { ASSIST, NORMAL, HARD, OFFLINE }

const SAVE_PATH := "user://cage_save.json"
const SAVE_VERSION := 1

## 据点永久升级（消耗织网碎片）。数值刻意保守，避免永久成长压过局内构筑。
const META_UPGRADES := {
	"shell_hp":         {"name": "外壳扩容", "desc": "最大耐久 +10", "max": 10, "cost_base": 60, "cost_step": 45, "icon": "shell"},
	"energy_cap":       {"name": "锚定核扩容", "desc": "幽灵能量上限 +5", "max": 8, "cost_base": 70, "cost_step": 55, "icon": "ghost"},
	"blade_polish":     {"name": "剑刃打磨", "desc": "剑伤害 +4%", "max": 10, "cost_base": 80, "cost_step": 60, "icon": "sword"},
	"barrel_calib":     {"name": "铳管校准", "desc": "铳伤害 +4%", "max": 10, "cost_base": 80, "cost_step": 60, "icon": "gun"},
	"shield_laminate":  {"name": "护盾层压", "desc": "格挡减伤 +2%", "max": 8, "cost_base": 90, "cost_step": 70, "icon": "shield"},
	"targeting":        {"name": "目标解析", "desc": "暴击率 +1%", "max": 6, "cost_base": 100, "cost_step": 80, "icon": "util"},
	"scavenger":        {"name": "拾荒直觉", "desc": "碎片获取 +10%", "max": 5, "cost_base": 120, "cost_step": 90, "icon": "util"},
	"vault_key":        {"name": "暗格权限", "desc": "开局额外携带 1 个随机词条", "max": 3, "cost_base": 260, "cost_step": 220, "icon": "util"},
	"revive_protocol":  {"name": "重启协议", "desc": "每局首次被击倒时就地重启", "max": 1, "cost_base": 600, "cost_step": 0, "icon": "shell"},
}

## 安全屋黑市（消耗盲区币）。买到的东西存在 pending_boons 里，下一局开局结算。
const SHOP_ITEMS := {
	"repair_kit":  {"name": "修理包", "desc": "下一局开局携带 1 个修理包", "price": 60, "icon": "util"},
	"battery":     {"name": "护盾电池", "desc": "下一局开局携带 1 个护盾电池", "price": 85, "icon": "shield"},
	"scrap_cache": {"name": "废料缓存", "desc": "下一局开局额外获得 25 织网碎片", "price": 45, "icon": "util"},
	"stim":        {"name": "强化针剂", "desc": "下一局最大耐久 +15 并立即补足", "price": 110, "icon": "shell"},
}

## 局外解锁与统计
var shards_bank: int = 0
var coins_bank: int = 0
var pending_boons: Dictionary = {}       # 黑市已购 / 待下一局生效
var meta_upgrades: Dictionary = {}
var stats: Dictionary = {"runs": 0, "kills": 0, "deaths": 0, "best_floor": 0, "wins": 0, "playtime": 0.0}
var intel_seen: Array[String] = []       # 已解锁的记忆残页 / 情报
var difficulty: int = Difficulty.NORMAL
var settings: Dictionary = {"master_volume": 0.85, "shake": 1.0, "damage_numbers": true, "screenshake_enabled": true}

## 当前这一局
var run: RunState = null
var main: Node = null                     # Main 场景根节点引用（由 Main 注册）

var _hitstop_end_ms: int = 0
var _pending_seed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputActions.register_all()
	load_meta()


# ================= 存档 =================

func load_meta() -> void:
	meta_upgrades.clear()
	for key in META_UPGRADES.keys():
		meta_upgrades[key] = 0

	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存档解析失败，使用默认值")
		return
	var data: Dictionary = parsed
	shards_bank = int(data.get("shards_bank", 0))
	coins_bank = int(data.get("coins_bank", 0))
	var boons = data.get("pending_boons", {})
	if typeof(boons) == TYPE_DICTIONARY:
		pending_boons = boons.duplicate()
	difficulty = int(data.get("difficulty", Difficulty.NORMAL))
	var mu: Dictionary = data.get("meta_upgrades", {})
	for key in META_UPGRADES.keys():
		meta_upgrades[key] = int(mu.get(key, 0))
	var st: Dictionary = data.get("stats", {})
	for key in stats.keys():
		stats[key] = st.get(key, stats[key])
	var intel = data.get("intel_seen", [])
	if typeof(intel) == TYPE_ARRAY:
		intel_seen.clear()
		for item in intel:
			intel_seen.append(str(item))


func save_meta() -> void:
	var data := {
		"version": SAVE_VERSION,
		"shards_bank": shards_bank,
		"coins_bank": coins_bank,
		"pending_boons": pending_boons,
		"difficulty": difficulty,
		"meta_upgrades": meta_upgrades,
		"stats": stats,
		"intel_seen": intel_seen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("无法写入存档：%s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func reset_save() -> void:
	shards_bank = 0
	coins_bank = 0
	pending_boons.clear()
	stats = {"runs": 0, "kills": 0, "deaths": 0, "best_floor": 0, "wins": 0, "playtime": 0.0}
	intel_seen.clear()
	for key in META_UPGRADES.keys():
		meta_upgrades[key] = 0
	save_meta()


func meta_cost(key: String) -> int:
	if not META_UPGRADES.has(key):
		return 0
	var d: Dictionary = META_UPGRADES[key]
	var level := int(meta_upgrades.get(key, 0))
	var max_level := int(d["max"])
	if level >= max_level:
		return -1
	return int(d["cost_base"]) + int(d["cost_step"]) * level


func buy_meta(key: String) -> bool:
	var cost := meta_cost(key)
	if cost < 0 or shards_bank < cost:
		return false
	shards_bank -= cost
	meta_upgrades[key] = int(meta_upgrades.get(key, 0)) + 1
	save_meta()
	Sfx.play("ui_confirm")
	return true


# ================= 难度 =================

func difficulty_name() -> String:
	match difficulty:
		Difficulty.ASSIST: return "辅助"
		Difficulty.NORMAL: return "普通"
		Difficulty.HARD: return "硬核"
		Difficulty.OFFLINE: return "断网"
	return "普通"


func enemy_hp_mult() -> float:
	match difficulty:
		Difficulty.ASSIST: return 0.8
		Difficulty.NORMAL: return 1.0
		Difficulty.HARD: return 1.25
		Difficulty.OFFLINE: return 1.4
	return 1.0


func enemy_damage_mult() -> float:
	match difficulty:
		Difficulty.ASSIST: return 0.7
		Difficulty.NORMAL: return 1.0
		Difficulty.HARD: return 1.35
		Difficulty.OFFLINE: return 1.5
	return 1.0


func drop_ratio() -> float:
	match difficulty:
		Difficulty.ASSIST: return 0.10
		Difficulty.NORMAL: return 0.35
		Difficulty.HARD: return 0.50
		Difficulty.OFFLINE: return 0.60
	return 0.35


func pollution_gain_mult() -> float:
	return 1.15 if difficulty == Difficulty.OFFLINE else 1.0


# ================= 局（run）生命周期 =================

func start_run(p_seed: int = 0) -> RunState:
	_pending_seed = p_seed
	run = RunState.new(p_seed)
	# 暗格权限：开局携带随机词条
	var extra := int(meta_upgrades.get("vault_key", 0))
	for i in extra:
		var picks := UpgradeDB.roll_choices(run.rng, 1, run.stacks, 0)
		if not picks.is_empty():
			run.add_upgrade(picks[0]["id"])
	_apply_pending_boons(run)
	stats["runs"] = int(stats.get("runs", 0)) + 1
	Events.run_started.emit(run.seed_value)
	return run


## 黑市买到的东西在开局一次性结算，然后清空（避免重复生效）
func _apply_pending_boons(r: RunState) -> void:
	if pending_boons.is_empty():
		return
	for key in pending_boons.keys():
		var n := int(pending_boons[key])
		if n <= 0:
			continue
		match str(key):
			"repair_kit":
				r.consumables["repair_kit"] = mini(RunState.CONSUMABLE_CAP, int(r.consumables.get("repair_kit", 0)) + n)
			"battery":
				r.consumables["battery"] = mini(RunState.CONSUMABLE_CAP, int(r.consumables.get("battery", 0)) + n)
			"scrap_cache":
				r.add_shards(25 * n)
			"stim":
				r.max_hp += 15.0 * float(n)
				r.hp = minf(r.max_hp, r.hp + 15.0 * float(n))
	pending_boons.clear()
	save_meta()


func shop_price(key: String) -> int:
	if not SHOP_ITEMS.has(key):
		return -1
	return int(SHOP_ITEMS[key]["price"])


func can_buy_shop(key: String) -> bool:
	var p := shop_price(key)
	return p > 0 and coins_bank >= p


func buy_shop_item(key: String) -> bool:
	if not can_buy_shop(key):
		Sfx.play("ui_deny")
		return false
	coins_bank -= shop_price(key)
	pending_boons[key] = int(pending_boons.get(key, 0)) + 1
	save_meta()
	Sfx.play("ui_confirm")
	return true


## 撤单：把已购但还未结算的补给退回盲区币
func refund_shop(key: String) -> bool:
	if int(pending_boons.get(key, 0)) <= 0:
		return false
	pending_boons[key] = int(pending_boons[key]) - 1
	if int(pending_boons[key]) <= 0:
		pending_boons.erase(key)
	coins_bank += shop_price(key)
	save_meta()
	Sfx.play("ui_move")
	return true


func end_run(victory: bool) -> int:
	if run == null:
		return 0
	var banked := 0
	if victory:
		banked = run.settle_victory()
		stats["wins"] = int(stats.get("wins", 0)) + 1
	else:
		banked = run.settle_death(drop_ratio())
		stats["deaths"] = int(stats.get("deaths", 0)) + 1
	shards_bank += banked
	stats["kills"] = int(stats.get("kills", 0)) + run.kills
	stats["best_floor"] = max(int(stats.get("best_floor", 0)), run.floor_index + 1)
	stats["playtime"] = float(stats.get("playtime", 0.0)) + run.time_alive_seconds()
	save_meta()
	Events.run_ended.emit(victory)
	return banked


func finish_run_to_hub(victory: bool) -> int:
	var banked := end_run(victory)
	run = null
	if main != null and main.has_method("goto_hub"):
		main.goto_hub()
	return banked


func abandon_run() -> void:
	if run != null:
		shards_bank += int(run.shards_banked)
	run = null


## 据点状态：玩家在安全屋里也需要一份 RunState 来驱动资源与 HUD。
## 与真正的一局不同，这里不计入 stats["runs"]。
func ensure_hub_state() -> RunState:
	if run == null:
		run = RunState.new(0)
		run.hp = run.max_hp
		run.ge = run.max_ge
		run.st = run.max_st
	return run


func hub_rest() -> void:
	var r := ensure_hub_state()
	r.hp = r.max_hp
	r.ge = r.max_ge
	r.st = r.max_st
	r.heat = 0.0
	r.pollution = 0.0
	Events.player_hp_changed.emit(r.hp, r.max_hp)
	Events.player_ge_changed.emit(r.ge, r.max_ge)
	Events.player_st_changed.emit(r.st, r.max_st)
	Events.player_heat_changed.emit(r.heat, r.max_heat)
	Events.pollution_changed.emit(r.pollution)
	save_meta()


# ================= 表现 =================

## 打击停顿：短暂压低 time_scale，用真实时间计时以免被自身影响
func do_hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	var now := Time.get_ticks_msec()
	_hitstop_end_ms = max(_hitstop_end_ms, now + int(duration * 1000.0))
	Engine.time_scale = 0.02


func shake(amount: float, duration: float = 0.25) -> void:
	if not bool(settings.get("screenshake_enabled", true)):
		return
	Events.shake_requested.emit(amount * float(settings.get("shake", 1.0)), duration)


func _process(_delta: float) -> void:
	if _hitstop_end_ms > 0 and Time.get_ticks_msec() >= _hitstop_end_ms:
		_hitstop_end_ms = 0
		Engine.time_scale = 1.0


func add_intel(id: String) -> bool:
	if intel_seen.has(id):
		return false
	intel_seen.append(id)
	save_meta()
	return true

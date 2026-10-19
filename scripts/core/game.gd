extends Node
## 全局游戏管理（Autoload: Game）
##
## 负责：输入映射注册、元进度与存档、当前这一局（RunState）的生命周期、
## 难度倍率、全局打击停顿（hitstop）。具体关卡与 UI 由 Main 场景驱动。

enum Difficulty { ASSIST, NORMAL, HARD, OFFLINE }

const SAVE_PATH := "user://cage_save.json"
const SAVE_VERSION := 1

## 自检 / 截图模式专用的沙盒存档。
## 无头自检会真跑 start_run → end_run 的完整结算流程，若与玩家共用 SAVE_PATH，
## 跑一次 `--bosscheck` 就会把碎片、胜场、出击次数直接写进玩家进度里。
const SAVE_PATH_SANDBOX := "user://cage_save_selfcheck.json"

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

## 本次运行实际读写的存档路径。自检模式会切到 SAVE_PATH_SANDBOX。
var save_path: String = SAVE_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputActions.register_all()
	if is_autotest_run():
		save_path = SAVE_PATH_SANDBOX
		print("[Game] 自检模式：存档切到 %s（玩家存档 %s 不动）" % [save_path, SAVE_PATH])
	load_meta()


## 当前是否是自检 / 截图运行。
## 这些运行会走完整的开局 → 结算流程，必须和玩家存档隔离。
## 自检参数写在 `--` 之后，全部以 check 结尾（截图用的 --shot 是唯一例外）。
static func is_autotest_run() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.ends_with("check") or s == "--shot":
			return true
	return false


# ================= 存档 =================

func load_meta() -> void:
	meta_upgrades.clear()
	for key in META_UPGRADES.keys():
		meta_upgrades[key] = 0

	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
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
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("无法写入存档：%s" % save_path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func reset_save() -> void:
	clear_run_save()
	shards_bank = 0
	coins_bank = 0
	pending_boons.clear()
	stats = {"runs": 0, "kills": 0, "deaths": 0, "best_floor": 0, "wins": 0, "playtime": 0.0}
	intel_seen.clear()
	for key in META_UPGRADES.keys():
		meta_upgrades[key] = 0
	save_meta()


# ---------------- 局内续关存档 ----------------

## 局内续关存档，跟据点元进度（cage_save.json）分开存放。
##
## 两种写法，由 `mode` 区分：
## - `"manual"`：玩家在暂停菜单主动保存 —— 记精确坐标 + 房间 payload，
##   读档后站回原处，商店/事件房保持保存时的状态。
## - `"auto"`：每进一个新房间静默写一次 —— 只记房间入口，不记 payload。
##   玩家直接关窗口（非正常退出）时，最后一次自动记录就是回退点，
##   读档后从那个房间门口开始，商店/休整房回到原始可交互状态。
const RUN_SAVE_PATH := "user://cage_run.json"
const RUN_SAVE_VERSION := 2

## 当前正在跑的 RunWorld，由 run_world.gd 注册；存档时从它读房间清理状态。
var run_world: Node = null

## 读档后等 RunWorld 消费的快照，消费完立刻清空，避免被下一局误用。
var resume_snapshot: Dictionary = {}


## 只认得出「能用的」存档：版本不匹配或结构坏掉的文件当作不存在，
## 免得标题页出现一个点下去必然失败的「继续本局」。
func has_run_save() -> bool:
	return not read_run_save().is_empty()


func clear_run_save() -> void:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))


## 把当前这一局写进续关存档。当前不在局内或写盘失败返回 false。
## mode = "manual" 记精确坐标与房间状态；"auto" 只记房间入口。
func save_run(mode: String = "manual") -> bool:
	if run == null or run_world == null or not is_instance_valid(run_world):
		return false

	var level = run_world.get("level")
	var cleared: Array[int] = []
	var room_index: int = 0
	var here = run_world.get("_current_room")
	if here != null:
		room_index = int(here.index)
	if level != null:
		for item in level.rooms:
			var room: Room = item
			if room.cleared:
				cleared.append(room.index)

	var data := {
		"version": RUN_SAVE_VERSION,
		"mode": mode,
		"run": run.to_dict(),
		"cleared": cleared,
		"room_index": room_index,
		"saved_at": Time.get_unix_time_from_system(),
	}

	if mode == "manual":
		var p = run_world.get("player")
		if p != null:
			data["pos"] = {"x": p.global_position.x, "y": p.global_position.y}
		data["payloads"] = _collect_room_payloads(level)

	return _write_save_file(RUN_SAVE_PATH, data)


## 收集房间 payload 里可序列化的部分（丢掉节点引用）。
## 现在商店是无限货架、没有「已购」概念，所以这份数据主要用于事件房；
## 以后商店要记库存，把清单塞进 payload 就能随手动存档一起保住。
func _collect_room_payloads(level) -> Dictionary:
	var out := {}
	if level == null:
		return out
	for item in level.rooms:
		var room: Room = item
		var src: Dictionary = room.payload
		if src.is_empty():
			continue
		var clean := {}
		for k in src.keys():
			var v = src[k]
			# 只留标量。Color / Vector2 / 节点引用序列化过去会变成字符串或直接丢失，
			# 恢复时反而添乱，一律不进存档。
			if not (v is String or v is int or v is float or v is bool):
				continue
			clean[str(k)] = v
		if not clean.is_empty():
			out[str(room.index)] = clean
	return out


## 读出续关存档；没有或版本不匹配返回空字典。
func read_run_save() -> Dictionary:
	return _read_save_file(RUN_SAVE_PATH)


# ================= 存档栏位（标题页「游戏存档」） =================
## 五个手动栏位。栏位里放的是一份「续关存档的副本」—— 只备份局内进度，
## 据点里的永久升级 / 织网碎片 / 盲区币不受栏位影响，不会被读档回滚。
const SLOT_COUNT := 5


func slot_path(i: int) -> String:
	# 文件名用 1..SLOT_COUNT，和界面上的「01」「02」对得上，方便手动排查。
	return "user://cage_slot_%d.json" % (i + 1)


## 栏位摘要，给界面显示用；空栏位或文件不可用返回空字典。
func slot_meta(i: int) -> Dictionary:
	var d := _read_save_file(slot_path(i))
	if d.is_empty():
		return {}
	var r: Dictionary = d.get("run", {})
	var cleared = d.get("cleared", [])
	return {
		"floor": int(r.get("floor_index", 0)),
		"room": int(d.get("room_index", 0)),
		"rooms_cleared": cleared.size() if typeof(cleared) == TYPE_ARRAY else int(r.get("rooms_cleared", 0)),
		"hp": float(r.get("hp", 0.0)),
		"max_hp": float(r.get("max_hp", 1.0)),
		"saved_at": float(d.get("saved_at", 0.0)),
		"mode": str(d.get("mode", "auto")),
	}


## 把当前续关存档复制进第 i 个栏位。当前没有存档时返回 false。
func save_slot(i: int) -> bool:
	var d := read_run_save()
	if d.is_empty():
		return false
	return _write_save_file(slot_path(i), d)


## 把第 i 个栏位写回当前续关存档，之后回标题页就能「继续本局」。
func load_slot(i: int) -> bool:
	var d := _read_save_file(slot_path(i))
	if d.is_empty():
		return false
	return _write_save_file(RUN_SAVE_PATH, d)


func delete_slot(i: int) -> void:
	var p := slot_path(i)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != RUN_SAVE_VERSION:
		return {}
	if typeof(data.get("run")) != TYPE_DICTIONARY:
		return {}
	return data


func _write_save_file(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("无法写入存档：%s" % path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


## 把续关存档载进 Game.run，并把房间状态留给 RunWorld 消费。成功返回 true。
func prepare_resume() -> bool:
	var data := read_run_save()
	if data.is_empty():
		return false
	resume_snapshot = data
	run = RunState.from_dict(data["run"])
	return true


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
	# 开新局 = 旧的续关存档作废，免得「继续本局」把玩家拉回上一局
	clear_run_save()
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
	clear_run_save()
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
	clear_run_save()
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

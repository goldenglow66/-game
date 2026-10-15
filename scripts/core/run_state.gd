class_name RunState
extends RefCounted
## 一局（run）的完整状态：资源、构筑词条、局内进度。
##
## 与 MetaProgress 分离：RunState 死亡即销毁，只有碎片/盲区币带回据点。

# ---------------- 随机与进度 ----------------
var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var floor_index: int = 0          # 当前扇区（0 起）
var room_index: int = 0           # 本扇区内的房间序号
var rooms_cleared: int = 0
var kills: int = 0
var elites_killed: int = 0
var bosses_killed: int = 0
var start_time_ms: int = 0

# ---------------- 资源 ----------------
var max_hp: float = 120.0
## 本局内的一次性上限加成（事件奖励等）。recalc() 会从 base + 词条重算 max_hp，
## 所以这类加成必须单独记着，否则下一次重算就把它抹掉了。
var bonus_max_hp: float = 0.0
var hp: float = 120.0
var max_ge: float = 80.0
var ge: float = 80.0
var max_st: float = 100.0
var st: float = 100.0
var max_heat: float = 100.0
var heat: float = 0.0
var pollution: float = 0.0        # 幽灵污染 0-100

var shards: int = 0               # 织网碎片（局内获取，死亡后按规则带回）
var coins: int = 0                # 盲区币
var shards_banked: int = 0        # 已确认带回的碎片

# ---------------- 构筑 ----------------
var stacks: Dictionary = {}       # upgrade_id -> 层数
var stats: Dictionary = {}        # recalc() 汇总后的属性表
var acquired_order: Array[String] = []
var consumables: Dictionary = {}  # "repair_kit"/"battery" -> 数量
var weapon: Dictionary = {
	"sword": "blade",             # blade（冷兵器剑） / laser（激光剑）
	"gun_element": "basic",
	"elements_owned": ["basic"],
}

# ---------------- 局内临时 ----------------
var revive_used: bool = false
var pending_choice: Array = []
var narrative_flags: Dictionary = {}

const CONSUMABLE_CAP := 3


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	rng.seed = seed_value
	start_time_ms = Time.get_ticks_msec()
	recalc(true)


# ================= 属性汇总 =================

func _base_stats() -> Dictionary:
	return {
		# 外壳
		"max_hp": 120.0,
		"max_hp_mult": 0.0,
		"damage_taken_mult": 0.0,
		"fall_damage_mult": 0.0,
		"room_clear_heal": 0.0,
		"revive_once": 0.0,
		# 机动
		"move_speed_mult": 0.0,
		"dash_distance_mult": 0.0,
		"dash_iframe_bonus": 0.0,
		"air_dash_count": 0.0,
		"extra_jumps": 0.0,
		"max_st": 100.0,
		"st_regen_mult": 0.0,
		# 剑
		"sword_damage_mult": 0.0,
		"sword_speed_mult": 0.0,
		"sword_charge_mult": 0.0,
		"charge_time_mult": 0.0,
		"sword_range_mult": 0.0,
		"sword_knockback_mult": 0.0,
		"combo3_st_gain": 0.0,
		"armor_pen": 0.0,
		"ghost_exit_strike": 0.0,
		"execute_ge_gain": 0.0,
		# 盾
		"guard_reduction": 0.65,
		"guard_cost_mult": 0.0,
		"parry_window": 0.22,
		"parry_window_bonus": 0.0,
		"bash_damage_mult": 0.0,
		"bash_poise_mult": 0.0,
		"reflect_projectile": 0.0,
		"low_hp_guard_bonus": 0.0,
		"parry_counter_mult": 0.0,
		"bash_shockwave": 0.0,
		# 铳
		"gun_damage_mult": 0.0,
		"max_heat": 100.0,
		"heat_recovery_mult": 0.0,
		"gun_range_mult": 0.0,
		"gun_pierce": 0.0,
		"gun_overload": 0.0,
		"element_slot": 0.0,
		"element_swap_speed": 0.0,
		"element_swap_heat": 0.0,
		"gun_cooldown_mult": 0.0,
		# 幽灵
		"max_ge": 80.0,
		"ghost_cost_mult": 0.0,
		"hack_speed_mult": 0.0,
		"ghost_move_mult": 0.0,
		"hijack_enemy": 0.0,
		"hack_kill_ge": 0.0,
		"ghost_phase_dash": 0.0,
		"probe_radius_mult": 0.0,
		# 通用
		"all_damage_mult": 0.0,
		"attack_speed_mult": 0.0,
		"crit_chance": 0.05,
		"crit_mult": 0.5,
		"kill_heal": 0.0,
		"thorns": 0.0,
		"enemy_slow_aura": 0.0,
		"low_hp_damage": 0.0,
		"pollution_power": 0.0,
		"pollution_gain_mult": 0.0,
		"pollution_resist": 0.0,
		"room_clear_ge": 0.0,
		"pickup_range_mult": 0.0,
		"shard_gain_mult": 0.0,
		"coin_gain_mult": 0.0,
		"bonus_cache": 0.0,
	}


func recalc(init_vitals: bool = false) -> void:
	var prev_max_hp := max_hp
	var prev_max_ge := max_ge
	var s := _base_stats()

	# 1) 永久升级（据点投入的织网碎片）
	var meta: Dictionary = Game.meta_upgrades
	s["max_hp"] += 10.0 * float(meta.get("shell_hp", 0))
	s["max_ge"] += 5.0 * float(meta.get("energy_cap", 0))
	s["sword_damage_mult"] += 0.04 * float(meta.get("blade_polish", 0))
	s["gun_damage_mult"] += 0.04 * float(meta.get("barrel_calib", 0))
	s["guard_reduction"] += 0.02 * float(meta.get("shield_laminate", 0))
	s["shard_gain_mult"] += 0.10 * float(meta.get("scavenger", 0))
	s["crit_chance"] += 0.01 * float(meta.get("targeting", 0))

	# 2) 局内词条
	for id in stacks.keys():
		var up: Dictionary = UpgradeDB.get_upgrade(id)
		if up.is_empty():
			continue
		var count: float = float(stacks[id])
		for eff in up.get("effects", []):
			var key: String = eff.get("key", "")
			if key == "":
				continue
			var add: float = float(eff.get("add", 0.0)) * count
			s[key] = float(s.get(key, 0.0)) + add

	# 3) 派生
	s["max_hp"] = s["max_hp"] * (1.0 + float(s["max_hp_mult"]))
	s["parry_window"] = s["parry_window"] + float(s["parry_window_bonus"])
	# 污染汲取：每 20 点污染提供额外伤害
	if float(s["pollution_power"]) > 0.0:
		s["all_damage_mult"] = float(s["all_damage_mult"]) + float(s["pollution_power"]) * floor(pollution / 20.0)

	stats = s
	max_hp = float(s["max_hp"]) + bonus_max_hp
	max_ge = float(s["max_ge"])
	max_st = float(s["max_st"])
	max_heat = float(s["max_heat"])

	if init_vitals:
		hp = max_hp
		ge = max_ge
		st = max_st
		heat = 0.0
	else:
		# 上限提升时，当前值同步补上同等差额（不会凭空回满血，也不会因换装掉血）
		hp = clampf(hp + maxf(0.0, max_hp - prev_max_hp), 0.0, max_hp)
		ge = clampf(ge + maxf(0.0, max_ge - prev_max_ge), 0.0, max_ge)
		st = minf(st, max_st)
		heat = minf(heat, max_heat)


func stat(key: String, default_value: float = 0.0) -> float:
	return float(stats.get(key, default_value))


func mult(key: String) -> float:
	return 1.0 + float(stats.get(key, 0.0))


# ================= 词条获取 =================

func has_stack_room(id: String) -> bool:
	var up: Dictionary = UpgradeDB.get_upgrade(id)
	if up.is_empty():
		return false
	return int(stacks.get(id, 0)) < int(up.get("max_stacks", 1))


func add_upgrade(id: String) -> void:
	var up: Dictionary = UpgradeDB.get_upgrade(id)
	if up.is_empty():
		return
	# 即时道具不走层数，直接结算
	if id == "util_repair_kit":
		heal(float(up["effects"][0]["add"]))
		return
	if id == "util_battery":
		ge = min(max_ge, ge + float(up["effects"][0]["add"]))
		Events.player_ge_changed.emit(ge, max_ge)
		return

	stacks[id] = int(stacks.get(id, 0)) + 1
	acquired_order.append(id)
	recalc(false)

	if id == "gun_element_slot":
		grant_random_element()
	Events.upgrade_taken.emit(up)


func grant_random_element() -> String:
	var pool: Array = []
	for key in UpgradeDB.ELEMENTS.keys():
		if key != "basic" and not weapon["elements_owned"].has(key):
			pool.append(key)
	if pool.is_empty():
		return ""
	var pick: String = pool[rng.randi() % pool.size()]
	weapon["elements_owned"].append(pick)
	return pick


func set_element(element_id: String) -> void:
	if weapon["elements_owned"].has(element_id):
		weapon["gun_element"] = element_id


func current_element() -> Dictionary:
	var id := str(weapon.get("gun_element", "basic"))
	var d: Dictionary = UpgradeDB.ELEMENTS.get(id, UpgradeDB.ELEMENTS["basic"])
	# 注入 id：克制判定、UI 与切换都靠它，而 ELEMENTS 表里本身没写 id
	var out := d.duplicate()
	out["id"] = id
	return out


# ================= 资源操作 =================

func heal(amount: float) -> void:
	hp = clampf(hp + amount, 0.0, max_hp)
	Events.player_hp_changed.emit(hp, max_hp)


func add_shards(amount: int) -> void:
	var gain := int(round(float(amount) * mult("shard_gain_mult")))
	shards += gain
	Events.currency_changed.emit(shards)


func add_coins(amount: int) -> void:
	var gain := int(round(float(amount) * mult("coin_gain_mult")))
	coins += gain
	Events.currency_changed.emit(shards)


func add_pollution(amount: float) -> void:
	if amount <= 0.0:
		return
	var resist: float = clampf(stat("pollution_resist"), 0.0, 0.9)
	var gain: float = amount * (1.0 + stat("pollution_gain_mult")) * (1.0 - resist)
	pollution = clampf(pollution + gain, 0.0, 100.0)
	Events.pollution_changed.emit(pollution)


func reduce_pollution(amount: float) -> void:
	pollution = clampf(pollution - amount, 0.0, 100.0)
	Events.pollution_changed.emit(pollution)


func time_alive_seconds() -> float:
	return float(Time.get_ticks_msec() - start_time_ms) / 1000.0


## 死亡时按难度惩罚结算，返回真正带回据点的碎片
func settle_death(drop_ratio: float) -> int:
	var lost := int(round(float(shards) * drop_ratio))
	shards = max(0, shards - lost)
	shards_banked = int(round(float(shards) * 0.55))
	return shards_banked


func settle_victory() -> int:
	shards_banked = shards
	return shards_banked

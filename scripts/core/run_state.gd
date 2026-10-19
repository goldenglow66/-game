class_name RunState
extends RefCounted
## 一局（run）的完整状态：资源、构筑词条、局内进度。
##
## 【它是什么】
## 从「出击升降机」走进织网，到死亡/通关之前，玩家的所有数据都挂在这个对象上：
## 血、能量、热量、污染、碎片、盲区币、拿了哪些词条、走到第几层第几间房。
##
## 【它不是什么】
## 据点里的**永久**进度（改造台升级、碎片存款、统计）在 `Game`（cage_save.json）里，
## 不在这里。本对象死亡即销毁 —— 只有 `settle_death()` / `settle_victory()` 算出来的
## 那部分碎片会被带回据点。
##
## 【核心机制：属性汇总】
## 玩家的实际属性**不直接存在字段里**，而是 `recalc()` 算出来的一张表（`stats`）。
## 算法：基础值 → 叠加永久升级 → 叠加局内词条 → 派生计算。
## 所以"拿了一个词条"本身不改血量，而是改 `stacks`，然后重算整张表。
## 需要读属性时统一用 `stat("key")` / `mult("key")`，不要直接算。
##
## 【存档】
## `to_dict()` / `from_dict()` 负责局内续关序列化。`stats` 不存（能重算），
## 只存 `stacks` 等源头数据，读档时重算，这样即使改了词条数值老存档也不会错。

# ================== 随机与进度 ==================

## 本局种子。同一个种子必定生成同一张地图、同一批敌人，用于复现与调试。
var seed_value: int = 0
## 由 seed_value 播种的随机数发生器。**局内所有随机都必须用它**，
## 不要用全局 randi()，否则种子复现就失效了。
var rng := RandomNumberGenerator.new()
var floor_index: int = 0          # 当前扇区（0 起，共 3 层）
var room_index: int = 0           # 本扇区内的房间序号（0 起）
var rooms_cleared: int = 0        # 本局已清空的房间总数
var kills: int = 0
var elites_killed: int = 0
var bosses_killed: int = 0
## 本局开始时刻（毫秒时间戳），用于结算界面的"用时"。
var start_time_ms: int = 0

# ================== 资源 ==================
# 这五个都是「当前值 / 上限值」成对出现，上限由 recalc() 算出。

var max_hp: float = 120.0
## 本局内的一次性上限加成（事件奖励等）。
## recalc() 每次都从 base + 词条重新算 max_hp，所以这类加成必须单独记一笔，
## 否则下一次重算就把它抹掉了。
var bonus_max_hp: float = 0.0
var hp: float = 120.0

var max_ge: float = 80.0          # 幽灵能量上限
var ge: float = 80.0              # 进幽灵形态要烧的能量
var max_st: float = 100.0         # 姿态（韧性）上限
var st: float = 100.0             # 被打空会姿态崩溃、硬直
var max_heat: float = 100.0       # 铳的热量上限
var heat: float = 0.0             # 满了会过热禁射
var pollution: float = 0.0        # 幽灵污染 0-100，越高副作用越重

var shards: int = 0               # 织网碎片：局内货币，死亡后只带回一部分
var coins: int = 0                # 盲区币：局内货币，只能在本局商店花
var shards_banked: int = 0        # 已确认带回据点的碎片（结算时算出来）

# ================== 构筑 ==================

## 已获得的词条：upgrade_id -> 层数。这是构筑的唯一源头，
## 属性表由它推导，不要在这里之外另存属性。
var stacks: Dictionary = {}
## recalc() 汇总出来的属性表（key 见 `_base_stats()`）。只读，不要手改。
var stats: Dictionary = {}
## 拿词条的先后顺序，用于结算界面展示构筑路线。
var acquired_order: Array[String] = []
## 消耗品库存："repair_kit"（修理包）/ "battery"（锚定电池）-> 数量
var consumables: Dictionary = {}
## 武器配置。sword 决定剑的形态，gun_element 是当前铳元素，
## elements_owned 是已解锁的元素列表。
var weapon: Dictionary = {
	"sword": "blade",             # blade（冷兵器剑） / laser（激光剑）
	"gun_element": "basic",
	"elements_owned": ["basic"],
}

# ================== 局内临时 ==================

## 复活协议是否已用掉（改造台的 revive_once 只能触发一次）。
var revive_used: bool = false
## 待玩家选择的三选一候选。UI 打开时填，选完清空。
var pending_choice: Array = []
## 叙事标记（看过哪段剧情、做过哪个选择），供后续事件判断。
var narrative_flags: Dictionary = {}

const CONSUMABLE_CAP := 3


## 新建一局。`p_seed` 传 0 表示随机取一个新种子。
func _init(p_seed: int = 0) -> void:
	seed_value = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	rng.seed = seed_value
	start_time_ms = Time.get_ticks_msec()
	# 新开局：属性表算出来后，当前值直接拉满
	recalc(true)


# ================== 属性汇总 ==================

## 属性表的**基础值**。所有 key 都是浮点数，加成类默认 0.0，
## 之后按「永久升级 → 局内词条」两层往上加。
##
## 【怎么看这张表】
## - `max_*` 是上限，非 0 起始；其余加成类基本都是 0.0（表示"没有加成"）。
## - `xxx_mult` 类的语义是**加算百分比**：0.15 表示 +15%，用时通过 `mult(key)`
##   转成乘数（1.15），不要直接当乘数用。
## - `xxx_reduction` / `xxx_chance` 是直接比率，不是加成。
func _base_stats() -> Dictionary:
	return {
		# ---- 外壳（生存） ----
		"max_hp": 120.0,
		"max_hp_mult": 0.0,           # 生命上限 +N%
		"damage_taken_mult": 0.0,     # 受到伤害 -N%（注意这是"减伤"，负数才是伤害增加）
		"fall_damage_mult": 0.0,
		"room_clear_heal": 0.0,       # 每清空一个房间回多少血
		"revive_once": 0.0,           # >0 表示拥有一次复活
		# ---- 机动 ----
		"move_speed_mult": 0.0,
		"dash_distance_mult": 0.0,
		"dash_iframe_bonus": 0.0,     # 冲刺无敌帧额外时长（秒）
		"air_dash_count": 0.0,        # 额外的空中冲刺次数
		"extra_jumps": 0.0,           # 额外跳跃次数
		"max_st": 100.0,
		"st_regen_mult": 0.0,         # 姿态回复速度 +N%
		# ---- 剑（近战） ----
		"sword_damage_mult": 0.0,
		"sword_speed_mult": 0.0,      # 挥剑速度 +N%
		"sword_charge_mult": 0.0,     # 蓄力重斩伤害 +N%
		"charge_time_mult": 0.0,      # 蓄力时间 -N%（更快）
		"sword_range_mult": 0.0,
		"sword_knockback_mult": 0.0,
		"combo3_st_gain": 0.0,        # 三段连击中第三段命中回复的姿态
		"armor_pen": 0.0,             # 破甲：无视多少减伤
		"ghost_exit_strike": 0.0,     # 幽灵形态退出时的突袭伤害
		"execute_ge_gain": 0.0,       # 处决回复的能量
		# ---- 盾（格挡） ----
		"guard_reduction": 0.65,      # 格挡减伤率（基础 65%）
		"guard_cost_mult": 0.0,       # 格挡的体力消耗 -N%
		"parry_window": 0.22,         # 完美格挡判定窗口（秒）
		"parry_window_bonus": 0.0,    # 窗口额外延长（秒）
		"bash_damage_mult": 0.0,      # 盾击伤害 +N%
		"bash_poise_mult": 0.0,       # 盾击削姿态 +N%
		"reflect_projectile": 0.0,    # >0 表示能把弹道反射回去
		"low_hp_guard_bonus": 0.0,    # 残血时格挡额外减伤
		"parry_counter_mult": 0.0,    # 完美格挡后的反击伤害 +N%
		"bash_shockwave": 0.0,        # >0 盾击产生冲击波
		# ---- 铳（远程） ----
		"gun_damage_mult": 0.0,
		"max_heat": 100.0,
		"heat_recovery_mult": 0.0,    # 散热速度 +N%
		"gun_range_mult": 0.0,
		"gun_pierce": 0.0,            # 穿透敌人数
		"gun_overload": 0.0,          # 过载：满热时伤害加成
		"element_slot": 0.0,          # 额外元素槽
		"element_swap_speed": 0.0,
		"element_swap_heat": 0.0,     # 切换元素产生多少热
		"gun_cooldown_mult": 0.0,     # 射击间隔 -N%
		# ---- 幽灵形态 ----
		"max_ge": 80.0,
		"ghost_cost_mult": 0.0,       # 幽灵形态能耗 -N%
		"hack_speed_mult": 0.0,       # 骇入速度 +N%
		"ghost_move_mult": 0.0,       # 幽灵形态移速 +N%
		"hijack_enemy": 0.0,          # >0 骇入成功后能夺取敌人
		"hack_kill_ge": 0.0,          # 骇入击杀回复的能量
		"ghost_phase_dash": 0.0,      # >0 幽灵形态可穿透冲刺
		"probe_radius_mult": 0.0,     # 探测半径 +N%
		# ---- 通用 ----
		"all_damage_mult": 0.0,       # 所有伤害 +N%
		"attack_speed_mult": 0.0,
		"crit_chance": 0.05,          # 暴击率（基础 5%）
		"crit_mult": 0.5,             # 暴击伤害倍率（1 + 0.5）
		"kill_heal": 0.0,             # 击杀回血
		"thorns": 0.0,                # 反伤
		"enemy_slow_aura": 0.0,       # 周围敌人减速光环
		"low_hp_damage": 0.0,         # 残血时伤害加成
		"pollution_power": 0.0,       # 每 20 点污染换取伤害加成
		"pollution_gain_mult": 0.0,   # 污染积累速度 +N%
		"pollution_resist": 0.0,      # 污染抗性（最多 90%）
		"room_clear_ge": 0.0,         # 清房回能量
		"pickup_range_mult": 0.0,     # 拾取范围 +N%
		"shard_gain_mult": 0.0,       # 碎片获取 +N%
		"coin_gain_mult": 0.0,        # 盲区币获取 +N%
		"bonus_cache": 0.0,           # 额外掉落缓存
	}


## 重算整张属性表并同步上限。
##
## `init_vitals = true`：把当前值拉满（新建一局时用）。
## `init_vitals = false`：保留当前值，但上限提升时把差额补进当前值 ——
## 这样"拿了 +10 最大生命"会同时回 10 点血，而"脱装备降上限"不会直接把人降死。
##
## 调用时机：新建局、拿词条、读档之后。
func recalc(init_vitals: bool = false) -> void:
	var prev_max_hp := max_hp
	var prev_max_ge := max_ge
	var s := _base_stats()

	# 第 1 层叠加：据点永久升级（花织网碎片买的，跨局有效）
	var meta: Dictionary = Game.meta_upgrades
	s["max_hp"] += 10.0 * float(meta.get("shell_hp", 0))
	s["max_ge"] += 5.0 * float(meta.get("energy_cap", 0))
	s["sword_damage_mult"] += 0.04 * float(meta.get("blade_polish", 0))
	s["gun_damage_mult"] += 0.04 * float(meta.get("barrel_calib", 0))
	s["guard_reduction"] += 0.02 * float(meta.get("shield_laminate", 0))
	s["shard_gain_mult"] += 0.10 * float(meta.get("scavenger", 0))
	s["crit_chance"] += 0.01 * float(meta.get("targeting", 0))

	# 第 2 层叠加：本局词条，按层数乘算
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

	# 第 3 层：派生计算（依赖前面叠加完的原始值）
	s["max_hp"] = s["max_hp"] * (1.0 + float(s["max_hp_mult"]))
	s["parry_window"] = s["parry_window"] + float(s["parry_window_bonus"])
	# 污染汲取：每 20 点污染提供一份额外伤害
	if float(s["pollution_power"]) > 0.0:
		s["all_damage_mult"] = float(s["all_damage_mult"]) + float(s["pollution_power"]) * floor(pollution / 20.0)

	stats = s
	# bonus_max_hp 是「事件给的一次性上限」，不参与上面的乘算，最后直接加
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
		# 上限提升时，当前值同步补上同等差额（不会凭空回满血，也不会因降上限直接掉血）
		hp = clampf(hp + maxf(0.0, max_hp - prev_max_hp), 0.0, max_hp)
		ge = clampf(ge + maxf(0.0, max_ge - prev_max_ge), 0.0, max_ge)
		st = minf(st, max_st)
		heat = minf(heat, max_heat)


## 读一个属性值（已含所有加成）。
func stat(key: String, default_value: float = 0.0) -> float:
	return float(stats.get(key, default_value))


## 读一个「xxx_mult」类属性，返回**乘数**而不是百分比。
## 例：stats 里 sword_damage_mult = 0.15 → mult("sword_damage_mult") = 1.15
func mult(key: String) -> float:
	return 1.0 + float(stats.get(key, 0.0))


# ================== 词条获取 ==================

## 这个词条还能不能再拿（层数没顶）。
func has_stack_room(id: String) -> bool:
	var up: Dictionary = UpgradeDB.get_upgrade(id)
	if up.is_empty():
		return false
	return int(stacks.get(id, 0)) < int(up.get("max_stacks", 1))


## 获得一个词条，并重算属性。
## 三选一、事件奖励、商店购买都走这里。
func add_upgrade(id: String) -> void:
	var up: Dictionary = UpgradeDB.get_upgrade(id)
	if up.is_empty():
		return
	# 即时道具不占层数，拿到直接结算
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

	# 「元素槽」这个词条额外解锁一个随机铳元素
	if id == "gun_element_slot":
		grant_random_element()
	Events.upgrade_taken.emit(up)


## 从还没解锁的元素里随机给一个，返回元素 id（池子空了返回空串）。
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


## 切换到指定元素（没解锁则忽略）。
func set_element(element_id: String) -> void:
	if weapon["elements_owned"].has(element_id):
		weapon["gun_element"] = element_id


## 取当前铳元素的完整数据（含 id、名称、克制说明）。
func current_element() -> Dictionary:
	var id := str(weapon.get("gun_element", "basic"))
	var d: Dictionary = UpgradeDB.ELEMENTS.get(id, UpgradeDB.ELEMENTS["basic"])
	# 注入 id：克制判定、UI 显示与切换都靠它，而 ELEMENTS 表里本身没写 id
	var out := d.duplicate()
	out["id"] = id
	return out


# ================== 资源操作 ==================

func heal(amount: float) -> void:
	hp = clampf(hp + amount, 0.0, max_hp)
	Events.player_hp_changed.emit(hp, max_hp)


## 加碎片（自动套用 shard_gain_mult 加成）。
func add_shards(amount: int) -> void:
	var gain := int(round(float(amount) * mult("shard_gain_mult")))
	shards += gain
	Events.currency_changed.emit(shards)


## 加盲区币（自动套用 coin_gain_mult 加成）。
func add_coins(amount: int) -> void:
	var gain := int(round(float(amount) * mult("coin_gain_mult")))
	coins += gain
	Events.currency_changed.emit(shards)


## 累积污染。会被 pollution_resist 削减、被 pollution_gain_mult 放大。
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


## 本局已经打了多久（秒）。
func time_alive_seconds() -> float:
	return float(Time.get_ticks_msec() - start_time_ms) / 1000.0


## 死亡结算：按难度比例先扣掉一部分碎片，再把剩下的 55% 带回据点。
## `drop_ratio` 由难度决定（难度越高掉得越多）。返回真正带回的碎片数。
func settle_death(drop_ratio: float) -> int:
	var lost := int(round(float(shards) * drop_ratio))
	shards = max(0, shards - lost)
	shards_banked = int(round(float(shards) * 0.55))
	return shards_banked


## 通关结算：碎片全部带回。
func settle_victory() -> int:
	shards_banked = shards
	return shards_banked


# ================== 存档序列化 ==================
#
# 局内续关只存「这一局的状态」，据点元进度另有 cage_save.json。
# `stats` 是 recalc() 的产物，不存；读档时按存档里的 stacks 重算，
# 这样永久升级和词条数值改动都能自动跟上，老存档不会因为改表而失效。

func to_dict() -> Dictionary:
	return {
		"seed_value": seed_value,
		"floor_index": floor_index,
		"room_index": room_index,
		"rooms_cleared": rooms_cleared,
		"kills": kills,
		"elites_killed": elites_killed,
		"bosses_killed": bosses_killed,
		"max_hp": max_hp,
		"bonus_max_hp": bonus_max_hp,
		"hp": hp,
		"max_ge": max_ge,
		"ge": ge,
		"max_st": max_st,
		"st": st,
		"max_heat": max_heat,
		"heat": heat,
		"pollution": pollution,
		"shards": shards,
		"coins": coins,
		"shards_banked": shards_banked,
		"stacks": stacks.duplicate(),
		"acquired_order": acquired_order.duplicate(),
		"consumables": consumables.duplicate(),
		"weapon": weapon.duplicate(true),
		"revive_used": revive_used,
		"narrative_flags": narrative_flags.duplicate(true),
	}


## 从存档字典还原一局。存档缺字段时用默认值兜底，所以加新字段不用改老存档。
static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new(int(d.get("seed_value", 0)))
	r.floor_index = int(d.get("floor_index", 0))
	r.room_index = int(d.get("room_index", 0))
	r.rooms_cleared = int(d.get("rooms_cleared", 0))
	r.kills = int(d.get("kills", 0))
	r.elites_killed = int(d.get("elites_killed", 0))
	r.bosses_killed = int(d.get("bosses_killed", 0))
	r.bonus_max_hp = float(d.get("bonus_max_hp", 0.0))
	r.pollution = float(d.get("pollution", 0.0))
	r.shards = int(d.get("shards", 0))
	r.coins = int(d.get("coins", 0))
	r.shards_banked = int(d.get("shards_banked", 0))
	r.revive_used = bool(d.get("revive_used", false))

	# 注意：变量名不能叫 `st` —— 那是本类的一个字段（姿态值），
	# 同名会让 GDScript 报 shadowing 警告，也容易读错。
	var stacks_src = d.get("stacks", {})
	if typeof(stacks_src) == TYPE_DICTIONARY:
		r.stacks = {}
		for k in stacks_src.keys():
			r.stacks[str(k)] = int(stacks_src[k])

	var order = d.get("acquired_order", [])
	if typeof(order) == TYPE_ARRAY:
		r.acquired_order.clear()
		for item in order:
			r.acquired_order.append(str(item))

	var cons = d.get("consumables", {})
	if typeof(cons) == TYPE_DICTIONARY:
		r.consumables = {}
		for k in cons.keys():
			r.consumables[str(k)] = int(cons[k])

	var wp = d.get("weapon", {})
	if typeof(wp) == TYPE_DICTIONARY and not wp.is_empty():
		r.weapon = wp.duplicate(true)

	var flags = d.get("narrative_flags", {})
	if typeof(flags) == TYPE_DICTIONARY:
		r.narrative_flags = flags.duplicate(true)

	# 先按存下来的构筑重算一遍上限与属性，再用存档里的当前值覆盖 ——
	# 这样读档后的血量不会因为「上限变了」被 recalc 挪动。
	r.recalc(false)
	r.max_hp = float(d.get("max_hp", r.max_hp))
	r.max_ge = float(d.get("max_ge", r.max_ge))
	r.max_st = float(d.get("max_st", r.max_st))
	r.max_heat = float(d.get("max_heat", r.max_heat))
	r.hp = clampf(float(d.get("hp", r.hp)), 0.0, r.max_hp)
	r.ge = clampf(float(d.get("ge", r.ge)), 0.0, r.max_ge)
	r.st = clampf(float(d.get("st", r.st)), 0.0, r.max_st)
	r.heat = clampf(float(d.get("heat", 0.0)), 0.0, r.max_heat)
	return r

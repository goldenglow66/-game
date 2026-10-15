class_name UpgradeDB
extends RefCounted
## 局内构筑词条库（肉鸽核心）。
##
## 词条来源：《笼中墟影》设定文档的技能树（表 6-5）、铳械模块（表 6-3）、
## 配件（表 10-3）与武器/盾升级线（表 6-1 / 6-2）。
## 每条词条只描述「效果」，具体数值结算由 RunState.recalc() 汇总到 stats 表。

const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_EPIC := "epic"
const RARITY_LEGEND := "legend"

const RARITY_COLOR := {
	"common": Color(0.72, 0.78, 0.85),
	"rare": Color(0.38, 0.72, 1.0),
	"epic": Color(0.74, 0.45, 1.0),
	"legend": Color(1.0, 0.72, 0.25),
}

const RARITY_WEIGHT := {
	"common": 100.0,
	"rare": 42.0,
	"epic": 14.0,
	"legend": 3.0,
}

const TAG_SWORD := "sword"
const TAG_SHIELD := "shield"
const TAG_GUN := "gun"
const TAG_GHOST := "ghost"
const TAG_SHELL := "shell"
const TAG_UTIL := "util"

## id -> 定义
const DB := {
	# ---------------- 外壳树（生存 / 机动） ----------------
	"shell_dura1": {
		"name": "外壳耐久 I", "desc": "外壳最大耐久 +25", "rarity": "common",
		"tags": ["shell"], "max_stacks": 6,
		"effects": [{"key": "max_hp", "add": 25.0}],
	},
	"shell_dura2": {
		"name": "外壳耐久 II", "desc": "最大耐久 +18%，坠落伤害 -20%", "rarity": "rare",
		"tags": ["shell"], "max_stacks": 4,
		"effects": [{"key": "max_hp_mult", "add": 0.18}, {"key": "fall_damage_mult", "add": -0.20}],
	},
	"shell_dash": {
		"name": "冲刺轴承", "desc": "闪避距离 +14%，闪避无敌帧 +2 帧", "rarity": "common",
		"tags": ["shell"], "max_stacks": 4,
		"effects": [{"key": "dash_distance_mult", "add": 0.14}, {"key": "dash_iframe_bonus", "add": 2.0}],
	},
	"shell_air_dash": {
		"name": "空中二段冲刺", "desc": "解锁空中冲刺（+1 次）", "rarity": "epic",
		"tags": ["shell"], "max_stacks": 1,
		"effects": [{"key": "air_dash_count", "add": 1.0}],
	},
	"shell_regen": {
		"name": "自修复纤维", "desc": "每清空一个房间回复 12 耐久", "rarity": "rare",
		"tags": ["shell"], "max_stacks": 3,
		"effects": [{"key": "room_clear_heal", "add": 12.0}],
	},
	"shell_plating": {
		"name": "根壁残片", "desc": "受到伤害 -8%", "rarity": "rare",
		"tags": ["shell", "util"], "max_stacks": 4,
		"effects": [{"key": "damage_taken_mult", "add": -0.08}],
	},
	"shell_empty_core": {
		"name": "空壳核心", "desc": "耐久归零时保留 1 点并免疫 1.5 秒（每局一次）", "rarity": "legend",
		"tags": ["shell"], "max_stacks": 1,
		"effects": [{"key": "revive_once", "add": 1.0}],
	},

	# ---------------- 剑术树 ----------------
	"sword_edge": {
		"name": "刃口校准", "desc": "剑伤害 +12%", "rarity": "common",
		"tags": ["sword"], "max_stacks": 6,
		"effects": [{"key": "sword_damage_mult", "add": 0.12}],
	},
	"sword_speed": {
		"name": "轻量化刀身", "desc": "剑攻速 +10%", "rarity": "common",
		"tags": ["sword"], "max_stacks": 5,
		"effects": [{"key": "sword_speed_mult", "add": 0.10}],
	},
	"sword_heavy": {
		"name": "重斩入门", "desc": "蓄力伤害 +18%，蓄力时间 -6%", "rarity": "common",
		"tags": ["sword"], "max_stacks": 5,
		"effects": [{"key": "sword_charge_mult", "add": 0.18}, {"key": "charge_time_mult", "add": -0.06}],
	},
	"sword_combo": {
		"name": "连携斩", "desc": "第三段命中回复 5 姿态稳定", "rarity": "rare",
		"tags": ["sword"], "max_stacks": 3,
		"effects": [{"key": "combo3_st_gain", "add": 5.0}],
	},
	"sword_armor_pen": {
		"name": "破甲刃", "desc": "对装甲单位伤害 +16%", "rarity": "rare",
		"tags": ["sword"], "max_stacks": 4,
		"effects": [{"key": "armor_pen", "add": 0.16}],
	},
	"sword_ghost_strike": {
		"name": "幽影首击", "desc": "脱离幽灵形态后 3 秒内剑击 +45%", "rarity": "epic",
		"tags": ["sword", "ghost"], "max_stacks": 2,
		"effects": [{"key": "ghost_exit_strike", "add": 0.45}],
	},
	"sword_execute": {
		"name": "终端斩断", "desc": "斩杀低耐久目标时回复 12 幽灵能量", "rarity": "epic",
		"tags": ["sword", "ghost"], "max_stacks": 2,
		"effects": [{"key": "execute_ge_gain", "add": 12.0}],
	},
	"sword_wide": {
		"name": "横扫二段", "desc": "轻击判定范围 +18%，击退 +20%", "rarity": "rare",
		"tags": ["sword"], "max_stacks": 3,
		"effects": [{"key": "sword_range_mult", "add": 0.18}, {"key": "sword_knockback_mult", "add": 0.20}],
	},

	# ---------------- 盾术树 ----------------
	"shield_steady": {
		"name": "稳态格挡", "desc": "格挡消耗 -12%，格挡减伤 +4%", "rarity": "common",
		"tags": ["shield"], "max_stacks": 5,
		"effects": [{"key": "guard_cost_mult", "add": -0.12}, {"key": "guard_reduction", "add": 0.04}],
	},
	"shield_window": {
		"name": "反击窗口", "desc": "完美格挡窗口 +0.03 秒", "rarity": "rare",
		"tags": ["shield"], "max_stacks": 4,
		"effects": [{"key": "parry_window_bonus", "add": 0.03}],
	},
	"shield_bash": {
		"name": "盾击打断", "desc": "盾击伤害 +30%，盾击姿态伤害 +25%", "rarity": "common",
		"tags": ["shield"], "max_stacks": 5,
		"effects": [{"key": "bash_damage_mult", "add": 0.30}, {"key": "bash_poise_mult", "add": 0.25}],
	},
	"shield_reflect": {
		"name": "能量折返", "desc": "完美格挡反弹小型弹道", "rarity": "epic",
		"tags": ["shield"], "max_stacks": 1,
		"effects": [{"key": "reflect_projectile", "add": 1.0}],
	},
	"shield_unyield": {
		"name": "不屈协议", "desc": "耐久低于 30% 时格挡减伤 +12%，格挡不消耗姿态", "rarity": "epic",
		"tags": ["shield"], "max_stacks": 2,
		"effects": [{"key": "low_hp_guard_bonus", "add": 0.12}],
	},
	"shield_counter": {
		"name": "反相反击", "desc": "完美格挡后 2 秒内剑伤害 +40%", "rarity": "rare",
		"tags": ["shield", "sword"], "max_stacks": 3,
		"effects": [{"key": "parry_counter_mult", "add": 0.40}],
	},
	"shield_shockwave": {
		"name": "盾波", "desc": "盾击释放冲击波，命中多个目标", "rarity": "rare",
		"tags": ["shield"], "max_stacks": 2,
		"effects": [{"key": "bash_shockwave", "add": 1.0}],
	},

	# ---------------- 铳械树 ----------------
	"gun_damage": {
		"name": "束波聚焦", "desc": "铳伤害 +14%", "rarity": "common",
		"tags": ["gun"], "max_stacks": 6,
		"effects": [{"key": "gun_damage_mult", "add": 0.14}],
	},
	"gun_cooling": {
		"name": "冷却风道", "desc": "过热恢复速度 +20%，过热阈值 +15", "rarity": "common",
		"tags": ["gun"], "max_stacks": 5,
		"effects": [{"key": "heat_recovery_mult", "add": 0.20}, {"key": "max_heat", "add": 15.0}],
	},
	"gun_range": {
		"name": "短束聚焦", "desc": "铳有效射程 +20%", "rarity": "common",
		"tags": ["gun"], "max_stacks": 3,
		"effects": [{"key": "gun_range_mult", "add": 0.20}],
	},
	"gun_element_slot": {
		"name": "元素槽", "desc": "解锁一个随机元素模块", "rarity": "rare",
		"tags": ["gun"], "max_stacks": 1,
		"effects": [{"key": "element_slot", "add": 1.0}],
	},
	"gun_overload": {
		"name": "过载一击", "desc": "铳满热量时下一发造成 3 倍伤害并清空热量", "rarity": "epic",
		"tags": ["gun"], "max_stacks": 1,
		"effects": [{"key": "gun_overload", "add": 1.0}],
	},
	"gun_pierce": {
		"name": "贯穿束", "desc": "铳弹道贯穿 1 个额外目标", "rarity": "rare",
		"tags": ["gun"], "max_stacks": 2,
		"effects": [{"key": "gun_pierce", "add": 1.0}],
	},
	"gun_switch": {
		"name": "快速换模", "desc": "切换元素模块时间 -50%，切换时回复 8 热量", "rarity": "rare",
		"tags": ["gun"], "max_stacks": 2,
		"effects": [{"key": "element_swap_speed", "add": 0.50}, {"key": "element_swap_heat", "add": 8.0}],
	},

	# ---------------- 幽灵树 ----------------
	"ghost_capacity": {
		"name": "锚定核扩容", "desc": "幽灵能量上限 +20", "rarity": "common",
		"tags": ["ghost"], "max_stacks": 5,
		"effects": [{"key": "max_ge", "add": 20.0}],
	},
	"ghost_efficiency": {
		"name": "低耗探测", "desc": "探测与骇入消耗 -18%", "rarity": "common",
		"tags": ["ghost"], "max_stacks": 4,
		"effects": [{"key": "ghost_cost_mult", "add": -0.18}],
	},
	"ghost_hack_speed": {
		"name": "骇入加速", "desc": "骇入读条 -22%", "rarity": "common",
		"tags": ["ghost"], "max_stacks": 4,
		"effects": [{"key": "hack_speed_mult", "add": 0.22}],
	},
	"ghost_glide": {
		"name": "残影滑行", "desc": "幽灵形态移动速度 +18%", "rarity": "rare",
		"tags": ["ghost"], "max_stacks": 3,
		"effects": [{"key": "ghost_move_mult", "add": 0.18}],
	},
	"ghost_overload": {
		"name": "敌意倒戈", "desc": "骇入轻型机械后使其为你作战 6 秒", "rarity": "epic",
		"tags": ["ghost"], "max_stacks": 1,
		"effects": [{"key": "hijack_enemy", "add": 1.0}],
	},
	"ghost_drain": {
		"name": "数据汲取", "desc": "骇入击杀获得 8 幽灵能量", "rarity": "rare",
		"tags": ["ghost"], "max_stacks": 3,
		"effects": [{"key": "hack_kill_ge", "add": 8.0}],
	},
	"ghost_isolation": {
		"name": "自我隔离", "desc": "幽灵污染增长 -30%", "rarity": "epic",
		"tags": ["ghost", "util"], "max_stacks": 2,
		"effects": [{"key": "pollution_resist", "add": 0.30}],
	},
	"ghost_phase": {
		"name": "相位穿墙", "desc": "幽灵形态下冲刺可穿过薄墙与弹幕", "rarity": "epic",
		"tags": ["ghost"], "max_stacks": 1,
		"effects": [{"key": "ghost_phase_dash", "add": 1.0}],
	},

	# ---------------- 通用 / 经济 ----------------
	"util_magnet": {
		"name": "旧城磁扣", "desc": "拾取范围 +40%", "rarity": "common",
		"tags": ["util"], "max_stacks": 3,
		"effects": [{"key": "pickup_range_mult", "add": 0.40}],
	},
	"util_scavenger": {
		"name": "拾荒者背囊", "desc": "获得碎片 +20%", "rarity": "common",
		"tags": ["util"], "max_stacks": 5,
		"effects": [{"key": "shard_gain_mult", "add": 0.20}],
	},
	"util_broker": {
		"name": "黑市门路", "desc": "获得盲区币 +25%", "rarity": "common",
		"tags": ["util"], "max_stacks": 4,
		"effects": [{"key": "coin_gain_mult", "add": 0.25}],
	},
	"util_lifesteal": {
		"name": "应急回充", "desc": "击杀回复 4 耐久", "rarity": "rare",
		"tags": ["util"], "max_stacks": 4,
		"effects": [{"key": "kill_heal", "add": 4.0}],
	},
	"util_crit": {
		"name": "协议漏洞", "desc": "暴击率 +8%，暴击伤害 +25%", "rarity": "rare",
		"tags": ["util"], "max_stacks": 5,
		"effects": [{"key": "crit_chance", "add": 0.08}, {"key": "crit_mult", "add": 0.25}],
	},
	"util_thorns": {
		"name": "反馈电流", "desc": "被近战命中时反弹 12 伤害", "rarity": "rare",
		"tags": ["util"], "max_stacks": 3,
		"effects": [{"key": "thorns", "add": 12.0}],
	},
	"util_slow_field": {
		"name": "干扰阵", "desc": "附近敌人移动速度 -12%", "rarity": "rare",
		"tags": ["util"], "max_stacks": 3,
		"effects": [{"key": "enemy_slow_aura", "add": 0.12}],
	},
	"util_dmg_aura": {
		"name": "根协议残响", "desc": "所有伤害 +10%", "rarity": "epic",
		"tags": ["util"], "max_stacks": 4,
		"effects": [{"key": "all_damage_mult", "add": 0.10}],
	},
	"util_second_wind": {
		"name": "二次呼吸", "desc": "清空房间后回复 15 幽灵能量", "rarity": "rare",
		"tags": ["util"], "max_stacks": 3,
		"effects": [{"key": "room_clear_ge", "add": 15.0}],
	},
	"util_overclock": {
		"name": "超频协议", "desc": "攻速 +8%，受到伤害 +5%", "rarity": "rare",
		"tags": ["util"], "max_stacks": 4,
		"effects": [{"key": "attack_speed_mult", "add": 0.08}, {"key": "damage_taken_mult", "add": 0.05}],
	},
	"util_pollution_tap": {
		"name": "污染汲取", "desc": "污染值每 20 点提供 +10% 伤害，但污染增长 +25%", "rarity": "epic",
		"tags": ["util"], "max_stacks": 2,
		"effects": [{"key": "pollution_power", "add": 0.10}, {"key": "pollution_gain_mult", "add": 0.25}],
	},
	"util_deadman": {
		"name": "死手开关", "desc": "耐久低于 25% 时伤害 +30%", "rarity": "epic",
		"tags": ["util"], "max_stacks": 2,
		"effects": [{"key": "low_hp_damage", "add": 0.30}],
	},
	"util_shard_magnet": {
		"name": "碎片共鸣", "desc": "房间清空奖励 +1 碎片箱", "rarity": "epic",
		"tags": ["util"], "max_stacks": 2,
		"effects": [{"key": "bonus_cache", "add": 1.0}],
	},
	"util_repair_kit": {
		"name": "便携修复包", "desc": "立即回复 40 耐久（消耗品）", "rarity": "common",
		"tags": ["util"], "max_stacks": 99,
		"effects": [{"key": "instant_heal", "add": 40.0}],
	},
	"util_battery": {
		"name": "幽灵电池", "desc": "立即回复 30 幽灵能量（消耗品）", "rarity": "common",
		"tags": ["util"], "max_stacks": 99,
		"effects": [{"key": "instant_ge", "add": 30.0}],
	},
}

## 元素模块：铳的第二种射击模式（表 6-3）
const ELEMENTS := {
	"basic": {"name": "基础束波", "color": Color(0.55, 0.85, 1.0), "damage": 18.0, "shots": 3, "heat": 18.0, "cooldown": 0.75, "desc": "短距离三段能量波。"},
	"burn": {"name": "灼烧模块", "color": Color(1.0, 0.55, 0.2), "damage": 14.0, "shots": 3, "heat": 22.0, "cooldown": 1.0, "dot": 6.0, "dot_time": 3.0, "desc": "对有机/布甲强，可点燃油污。"},
	"slow": {"name": "减速模块", "color": Color(0.45, 1.0, 0.85), "damage": 16.0, "shots": 3, "heat": 24.0, "cooldown": 1.1, "slow": 0.25, "slow_time": 4.0, "desc": "命中降低移动与攻速。"},
	"poison": {"name": "中毒模块", "color": Color(0.6, 1.0, 0.35), "damage": 12.0, "shots": 3, "heat": 20.0, "cooldown": 1.0, "dot": 8.0, "dot_time": 5.0, "desc": "对装甲弱，对高血人形强。"},
	"emp": {"name": "电磁模块", "color": Color(0.85, 0.7, 1.0), "damage": 20.0, "shots": 2, "heat": 28.0, "cooldown": 1.25, "bonus_vs": "machine", "bonus": 0.35, "desc": "对机械 +35%，可短路炮塔与门锁。"},
	"shock": {"name": "震荡模块", "color": Color(1.0, 0.85, 0.4), "damage": 26.0, "shots": 1, "heat": 30.0, "cooldown": 1.35, "poise": 2.0, "desc": "高姿态伤害，可打断蓄力。"},
}


static func get_upgrade(id: String) -> Dictionary:
	if not DB.has(id):
		return {}
	var d: Dictionary = DB[id].duplicate(true)
	d["id"] = id
	return d


static func all_ids() -> Array:
	return DB.keys()


## 随机三选一（或 N 选一）。exclude 用于排除已满层的词条。
static func roll_choices(rng: RandomNumberGenerator, count: int, stacks: Dictionary, floor_index: int, tag_filter: Array = []) -> Array:
	var pool: Array[String] = []
	for id in DB.keys():
		var d: Dictionary = DB[id]
		var max_stacks: int = int(d.get("max_stacks", 1))
		if int(stacks.get(id, 0)) >= max_stacks:
			continue
		var rarity: String = d.get("rarity", "common")
		# 高稀有度随层数解锁：第 1 层不出传说，第 3 层起才可能出现史诗
		if rarity == "legend" and floor_index < 2:
			continue
		if rarity == "epic" and floor_index < 1:
			continue
		if not tag_filter.is_empty():
			var tags: Array = d.get("tags", [])
			var ok := false
			for t in tag_filter:
				if tags.has(t):
					ok = true
					break
			if not ok:
				continue
		pool.append(id)

	var picks: Array[String] = []
	for i in count:
		if pool.is_empty():
			break
		var total := 0.0
		for id in pool:
			total += float(RARITY_WEIGHT.get(DB[id].get("rarity", "common"), 50.0))
		var r := rng.randf() * total
		var acc := 0.0
		var chosen: String = pool[0]
		for id in pool:
			acc += float(RARITY_WEIGHT.get(DB[id].get("rarity", "common"), 50.0))
			if r <= acc:
				chosen = id
				break
		picks.append(chosen)
		pool.erase(chosen)

	var result: Array = []
	for id in picks:
		result.append(get_upgrade(id))
	return result


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLOR.get(rarity, Color.WHITE)

class_name EnemyDB
extends RefCounted
## 敌人档案。
##
## 数据基准：《Ghost in the Iron Shell / 笼中墟影》表 8-1「敌人总表」（21 种）。
## 原表给的是 HP / 伤害 / 出现区域；这里补上横板动作肉鸽必需的行为参数
## （behavior / speed / poise / 攻击距离 / 冷却），并保留五类克制关系。
##
## 克制关系（表 8-1 附注）：
##   机械   ← 电磁（emp）
##   人形   ← 中毒 / 破姿态（poison / poise）
##   异常生物 ← 灼烧（burn）
##   智能体 ← 深度骇入（骇入伤害）
##   幽灵体 ← 需探测（probe）才能稳定命中

enum Cat { MACHINE, HUMAN, BIO, AI_CORE, GHOST }

const CAT_NAME := {
	Cat.MACHINE: "机械",
	Cat.HUMAN: "人形",
	Cat.BIO: "异常生物",
	Cat.AI_CORE: "智能体",
	Cat.GHOST: "幽灵体",
}

## 区域标签：与关卡主题对应（0 废都旧区 / 1 织网内环 / 2 盲区荒漠 / 3 移动堡垒 / 4 地下城）
const ZONE_WASTE := "waste"
const ZONE_WEB := "web"
const ZONE_DUNE := "dune"
const ZONE_FORT := "fort"
const ZONE_UNDER := "under"

## behavior 取值
const WALKER := "walker"     # 地面巡逻兵：追击后近战
const RUSHER := "rusher"     # 地面突击：高速冲锋
const RANGED := "ranged"     # 地面射手：保持距离放弹
const LOBBER := "lobber"     # 投掷手：抛物线弹
const TURRET := "turret"     # 固定炮台：不移动
const FLYER := "flyer"       # 空中单位：悬停逼近
const SWARM := "swarm"       # 群体小型单位
const ELITE := "elite"       # 精英：多段近战 + 高姿态

const DB := {
	# ---------- 废都旧区 ----------
	"splitter_drone": {
		"name": "裂线巡机", "hp": 70.0, "damage": 12.0, "speed": 104.0,
		"behavior": WALKER, "category": Cat.MACHINE, "poise": 14.0,
		"w": 34.0, "h": 42.0, "color": Color("6d7c8c"), "accent": Color("ffd166"),
		"shards": 3, "coins": 2, "tier": 1, "zone": ZONE_WASTE,
		"reach": 46.0, "attack_cd": 1.35, "windup": 0.34, "aggro": 430.0,
	},
	"offnet_mob": {
		"name": "失网暴民", "hp": 85.0, "damage": 16.0, "speed": 118.0,
		"behavior": RUSHER, "category": Cat.HUMAN, "poise": 10.0,
		"w": 32.0, "h": 48.0, "color": Color("8a6a52"), "accent": Color("ff8a3d"),
		"shards": 4, "coins": 3, "tier": 1, "zone": ZONE_WASTE,
		"reach": 44.0, "attack_cd": 1.1, "windup": 0.30, "aggro": 460.0,
	},
	"legacy_turret": {
		"name": "旧式炮塔", "hp": 120.0, "damage": 18.0, "speed": 0.0,
		"behavior": TURRET, "category": Cat.MACHINE, "poise": 40.0,
		"w": 40.0, "h": 52.0, "color": Color("59636f"), "accent": Color("ff6b5b"),
		"shards": 5, "coins": 3, "tier": 1, "zone": ZONE_WASTE,
		"reach": 520.0, "attack_cd": 1.9, "windup": 0.55, "aggro": 560.0,
		"ranged": true, "burst": 2,
	},
	"cable_parasite": {
		"name": "线缆寄生体", "hp": 95.0, "damage": 14.0, "speed": 72.0,
		"behavior": WALKER, "category": Cat.BIO, "poise": 12.0,
		"w": 38.0, "h": 36.0, "color": Color("4a6b52"), "accent": Color("9ee37d"),
		"shards": 4, "coins": 2, "tier": 1, "zone": ZONE_WASTE,
		"reach": 52.0, "attack_cd": 1.5, "windup": 0.42, "aggro": 380.0,
	},
	"pickdog": {
		"name": "盲区拾荒犬", "hp": 100.0, "damage": 18.0, "speed": 152.0,
		"behavior": RUSHER, "category": Cat.BIO, "poise": 8.0,
		"w": 44.0, "h": 30.0, "color": Color("7a5c3a"), "accent": Color("e8c86a"),
		"shards": 4, "coins": 3, "tier": 1, "zone": ZONE_WASTE,
		"reach": 46.0, "attack_cd": 0.95, "windup": 0.22, "aggro": 520.0,
	},

	# ---------- 织网内环 ----------
	"web_infantry": {
		"name": "守网步兵", "hp": 150.0, "damage": 24.0, "speed": 112.0,
		"behavior": WALKER, "category": Cat.HUMAN, "poise": 22.0,
		"w": 34.0, "h": 50.0, "color": Color("3f4a63"), "accent": Color("4fd6c8"),
		"shards": 6, "coins": 4, "tier": 2, "zone": ZONE_WEB,
		"reach": 52.0, "attack_cd": 1.25, "windup": 0.36, "aggro": 470.0,
	},
	"scan_monk": {
		"name": "扫描修士", "hp": 110.0, "damage": 20.0, "speed": 88.0,
		"behavior": RANGED, "category": Cat.HUMAN, "poise": 14.0,
		"w": 34.0, "h": 50.0, "color": Color("5b4a72"), "accent": Color("a98bf0"),
		"shards": 6, "coins": 4, "tier": 2, "zone": ZONE_WEB,
		"reach": 420.0, "attack_cd": 2.0, "windup": 0.62, "aggro": 560.0,
		"ranged": true, "burst": 1, "keep_dist": 250.0,
	},
	"crown_knight": {
		"name": "根冠骑士", "hp": 320.0, "damage": 38.0, "speed": 96.0,
		"behavior": ELITE, "category": Cat.HUMAN, "poise": 60.0,
		"w": 44.0, "h": 60.0, "color": Color("6b5230"), "accent": Color("e8c86a"),
		"shards": 16, "coins": 10, "tier": 2, "zone": ZONE_WEB, "elite": true,
		"reach": 62.0, "attack_cd": 1.6, "windup": 0.48, "aggro": 600.0,
		"combo": 3,
	},
	"web_swarm": {
		"name": "守网蜂群", "hp": 60.0, "damage": 10.0, "speed": 168.0,
		"behavior": SWARM, "category": Cat.MACHINE, "poise": 6.0,
		"w": 24.0, "h": 24.0, "color": Color("4a5a70"), "accent": Color("4fd6c8"),
		"shards": 2, "coins": 1, "tier": 2, "zone": ZONE_WEB, "group": 4,
		"reach": 34.0, "attack_cd": 0.9, "windup": 0.20, "aggro": 520.0,
	},
	"interrog_drone": {
		"name": "审讯无人机", "hp": 105.0, "damage": 14.0, "speed": 120.0,
		"behavior": FLYER, "category": Cat.MACHINE, "poise": 12.0,
		"w": 36.0, "h": 26.0, "color": Color("46536b"), "accent": Color("ff6b5b"),
		"shards": 5, "coins": 3, "tier": 2, "zone": ZONE_WEB,
		"reach": 380.0, "attack_cd": 1.7, "windup": 0.5, "aggro": 540.0,
		"ranged": true, "burst": 3, "keep_dist": 200.0,
	},
	"rewrite_spider": {
		"name": "改写蛛", "hp": 90.0, "damage": 15.0, "speed": 130.0,
		"behavior": RANGED, "category": Cat.AI_CORE, "poise": 10.0,
		"w": 42.0, "h": 26.0, "color": Color("3c4a55"), "accent": Color("7de3c8"),
		"shards": 6, "coins": 4, "tier": 2, "zone": ZONE_WEB,
		"reach": 360.0, "attack_cd": 1.6, "windup": 0.44, "aggro": 500.0,
		"ranged": true, "burst": 1, "keep_dist": 230.0,
	},
	"memory_shade": {
		"name": "记忆残影", "hp": 145.0, "damage": 25.0, "speed": 108.0,
		"behavior": WALKER, "category": Cat.GHOST, "poise": 18.0,
		"w": 34.0, "h": 48.0, "color": Color("6a7fa8"), "accent": Color("cfe4ff"),
		"shards": 8, "coins": 5, "tier": 3, "zone": ZONE_UNDER,
		"reach": 50.0, "attack_cd": 1.3, "windup": 0.34, "aggro": 480.0,
		"ghost": true,
	},
	"protocol_judge": {
		"name": "根协议判官", "hp": 480.0, "damage": 52.0, "speed": 92.0,
		"behavior": ELITE, "category": Cat.AI_CORE, "poise": 80.0,
		"w": 48.0, "h": 66.0, "color": Color("54406b"), "accent": Color("c46bff"),
		"shards": 22, "coins": 14, "tier": 3, "zone": ZONE_UNDER, "elite": true,
		"reach": 68.0, "attack_cd": 1.5, "windup": 0.46, "aggro": 640.0,
		"combo": 3, "ranged": true, "burst": 2,
	},

	# ---------- 盲区荒漠 ----------
	"sandbone_raider": {
		"name": "沙骨掠夺者", "hp": 130.0, "damage": 22.0, "speed": 108.0,
		"behavior": WALKER, "category": Cat.HUMAN, "poise": 20.0,
		"w": 36.0, "h": 50.0, "color": Color("9a7a4e"), "accent": Color("ffb347"),
		"shards": 6, "coins": 5, "tier": 2, "zone": ZONE_DUNE,
		"reach": 50.0, "attack_cd": 1.25, "windup": 0.36, "aggro": 470.0,
	},
	"sandstorm_beacon": {
		"name": "沙暴信标机", "hp": 160.0, "damage": 20.0, "speed": 0.0,
		"behavior": TURRET, "category": Cat.MACHINE, "poise": 46.0,
		"w": 38.0, "h": 58.0, "color": Color("8a7350"), "accent": Color("ffd166"),
		"shards": 7, "coins": 5, "tier": 2, "zone": ZONE_DUNE,
		"reach": 560.0, "attack_cd": 2.2, "windup": 0.7, "aggro": 620.0,
		"ranged": true, "burst": 1,
	},
	"redline_bomber": {
		"name": "红线投弹手", "hp": 115.0, "damage": 26.0, "speed": 92.0,
		"behavior": LOBBER, "category": Cat.HUMAN, "poise": 14.0,
		"w": 34.0, "h": 50.0, "color": Color("8a4a44"), "accent": Color("ff6b5b"),
		"shards": 6, "coins": 4, "tier": 2, "zone": ZONE_DUNE,
		"reach": 400.0, "attack_cd": 2.1, "windup": 0.66, "aggro": 540.0,
		"ranged": true, "burst": 1, "keep_dist": 280.0, "arc": true,
	},

	# ---------- 移动堡垒 ----------
	"breach_assaulter": {
		"name": "破茧突击者", "hp": 180.0, "damage": 30.0, "speed": 142.0,
		"behavior": RUSHER, "category": Cat.HUMAN, "poise": 24.0,
		"w": 36.0, "h": 52.0, "color": Color("3f5a52"), "accent": Color("7dffb0"),
		"shards": 8, "coins": 6, "tier": 3, "zone": ZONE_FORT,
		"reach": 52.0, "attack_cd": 1.05, "windup": 0.26, "aggro": 560.0,
	},
	"novus_mp": {
		"name": "新世盟宪兵", "hp": 170.0, "damage": 28.0, "speed": 106.0,
		"behavior": WALKER, "category": Cat.HUMAN, "poise": 26.0,
		"w": 36.0, "h": 52.0, "color": Color("54607a"), "accent": Color("8fd0ff"),
		"shards": 8, "coins": 6, "tier": 3, "zone": ZONE_FORT,
		"reach": 54.0, "attack_cd": 1.2, "windup": 0.34, "aggro": 520.0,
	},
	"fort_cleaner": {
		"name": "堡垒清洁机", "hp": 380.0, "damage": 42.0, "speed": 84.0,
		"behavior": ELITE, "category": Cat.MACHINE, "poise": 70.0,
		"w": 54.0, "h": 60.0, "color": Color("6a7a86"), "accent": Color("ff4d4d"),
		"shards": 18, "coins": 12, "tier": 3, "zone": ZONE_FORT, "elite": true,
		"reach": 66.0, "attack_cd": 1.8, "windup": 0.55, "aggro": 600.0,
		"combo": 2,
	},

	# ---------- 地下城 ----------
	"cocoon_guard": {
		"name": "茧化守卫", "hp": 260.0, "damage": 36.0, "speed": 96.0,
		"behavior": WALKER, "category": Cat.BIO, "poise": 44.0,
		"w": 46.0, "h": 58.0, "color": Color("5a3550"), "accent": Color("ff7ad0"),
		"shards": 12, "coins": 8, "tier": 3, "zone": ZONE_UNDER,
		"reach": 60.0, "attack_cd": 1.45, "windup": 0.44, "aggro": 520.0,
	},
	"hollow_copy": {
		"name": "空壳复制体", "hp": 360.0, "damage": 34.0, "speed": 128.0,
		"behavior": ELITE, "category": Cat.AI_CORE, "poise": 56.0,
		"w": 34.0, "h": 50.0, "color": Color("4a4a5e"), "accent": Color("4fd6c8"),
		"shards": 20, "coins": 12, "tier": 3, "zone": ZONE_UNDER, "elite": true,
		"reach": 60.0, "attack_cd": 1.2, "windup": 0.34, "aggro": 620.0,
		"combo": 3,
	},
}

## 按扇区深度决定敌人池：越深越倾向后两个区域标签。
const ZONE_BY_FLOOR := [
	[ZONE_WASTE, ZONE_WASTE, ZONE_WEB],
	[ZONE_WASTE, ZONE_WEB, ZONE_DUNE],
	[ZONE_WEB, ZONE_DUNE, ZONE_FORT],
	[ZONE_DUNE, ZONE_FORT, ZONE_UNDER],
	[ZONE_FORT, ZONE_UNDER, ZONE_UNDER],
]


# ================= Boss =================
# 设定文档表 9-1 列了 13 个 Boss；一局三层，这里每层取一个。
# Boss 的差异来自体型、血量、阶段和台词，而不是新写一个类 —— 复用精英单位再放大。

const BOSSES := [
	{
		"name": "铆 钉", "title": "B1 · 织网铆接体", "base": "crown_knight",
		"hp_mult": 9.0, "dmg_mult": 1.15, "scale": 1.9, "accent": Color("e0554f"),
		"intro": "它的关节是用守网步兵的脊椎焊出来的。",
	},
	{
		"name": "塞 勒", "title": "B3 · 内环执法者", "base": "protocol_judge",
		"hp_mult": 10.0, "dmg_mult": 1.2, "scale": 2.05, "accent": Color("a98bf0"),
		"intro": "判官不需要理由，它只负责把结果念出来。",
	},
	{
		"name": "霍尔斯特", "title": "B7 · 守网者", "base": "cocoon_guard",
		"hp_mult": 13.0, "dmg_mult": 1.3, "scale": 2.35, "accent": Color("4fd6c8"),
		"intro": "沃克不是人名，是秩序最后的发音。",
	},
]


static func boss_for_floor(floor_index: int) -> Dictionary:
	if BOSSES.is_empty():
		return {}
	return BOSSES[clampi(floor_index, 0, BOSSES.size() - 1)]


static func get_enemy(id: String) -> Dictionary:
	var d: Dictionary = DB.get(id, {})
	if d.is_empty():
		return {}
	var out: Dictionary = d.duplicate(true)
	out["id"] = id
	return out


static func all_ids() -> Array:
	return DB.keys()


## 难度缩放：扇区越深敌人越强（与 Game 的难度倍率相乘）。
static func floor_scale(floor_index: int) -> Dictionary:
	var f := float(maxi(0, floor_index))
	return {
		"hp": 1.0 + f * 0.22,
		"damage": 1.0 + f * 0.14,
		"shards": 1.0 + f * 0.10,
	}


## 抽取一批敌人档案，返回 id 数组（已按 group 展开）。
static func roll_pack(rng: RandomNumberGenerator, floor_index: int, count: int, allow_elite: bool) -> Array:
	var zones: Array = ZONE_BY_FLOOR[clampi(floor_index, 0, ZONE_BY_FLOOR.size() - 1)]
	var pool: Array = []
	for id in DB.keys():
		var d: Dictionary = DB[id]
		if not zones.has(d.get("zone", ZONE_WASTE)):
			continue
		if bool(d.get("elite", false)) and not allow_elite:
			continue
		pool.append(id)
	if pool.is_empty():
		pool = ["splitter_drone"]

	# 权重：tier 越接近当前深度越容易出
	var weighted: Array = []
	for id in pool:
		var d: Dictionary = DB[id]
		var tier: int = int(d.get("tier", 1))
		var depth: int = clampi(floor_index + 1, 1, 3)
		var w: int = 10 - absi(tier - depth) * 4
		if bool(d.get("elite", false)):
			w = maxi(1, w - 6)
		for i in maxi(1, w):
			weighted.append(id)

	var out: Array = []
	var guard := 0
	while out.size() < count and guard < 120:
		guard += 1
		var pick: String = str(weighted[rng.randi_range(0, weighted.size() - 1)])
		var d2: Dictionary = DB[pick]
		var group := int(d2.get("group", 1))
		for i in group:
			if out.size() >= count + group:
				break
			out.append(pick)
	return out


static func category_color(cat: int) -> Color:
	match cat:
		Cat.MACHINE: return Color("8fb8d8")
		Cat.HUMAN: return Color("e8b06a")
		Cat.BIO: return Color("9ee37d")
		Cat.AI_CORE: return Color("c46bff")
		Cat.GHOST: return Color("cfe4ff")
	return Color.WHITE

class_name EventDB
extends RefCounted
## 事件房（EVENT）的奇遇数据。素材取自设定文档：图尔克（盲区黑市商贩 / 坏收音机支线）、
## 记忆水面、人格茧、裁断（柯恩的地下抵抗组织）。
##
## 设计原则与表 9-1 一致：优先给情报、权限、改写机会，而不是纯数值。
## 每个选项都可以带代价，代价不够时按钮会被禁用并说明原因。
##
## 选项字段：
##   label        按钮主文字
##   desc         按钮下方小字
##   effect       主效果（见 OPT_* 常量）
##   amount       主效果数值
##   cost_coins   需要花掉的盲区币
##   cost_shards  需要花掉的织网碎片
##   shards       额外固定获得的碎片
##   coins        额外固定获得的盲区币
##   pollution    污染变化（正为增加）
##   max_hp       本局最大耐久增量（同时补上等量当前耐久）
##   heal_full    是否回满耐久
##   consumable   给一个消耗品（repair_kit / battery）
##   intel        解锁的情报 id（对应 UIRoot.INTEL_PAGES）
##   extra_reward 额外一次三选一

const OPT_NONE := "none"
const OPT_SHARDS := "shards"
const OPT_COINS := "coins"
const OPT_HEAL := "heal"
const OPT_POLLUTION := "pollution"
const OPT_MAX_HP := "max_hp"
const OPT_CONSUMABLE := "consumable"
const OPT_INTEL := "intel"
const OPT_EXTRA_REWARD := "extra_reward"


const DB := {
	"turck_stall": {
		"title": "图尔克的摊位",
		"subtitle": "盲区黑市 · 临时接口",
		"speaker": "图尔克",
		"line": "坏掉的东西我收，没坏的东西我也收。你要什么？",
		"options": [
			{
				"label": "买一份坐标",
				"desc": "-60 盲区币 · 多一次改写机会",
				"effect": OPT_EXTRA_REWARD,
				"cost_coins": 60,
			},
			{
				"label": "把废料卖给他",
				"desc": "+25 织网碎片",
				"effect": OPT_SHARDS,
				"amount": 25,
			},
			{
				"label": "不交易",
				"desc": "继续走",
				"effect": OPT_NONE,
			},
		],
	},
	"broken_radio": {
		"title": "坏掉的收音机",
		"subtitle": "图尔克的存货 · 三年没响过",
		"speaker": "图尔克",
		"line": "这玩意儿三年没响过了。你要是能修好，里面那段东西归你。",
		"options": [
			{
				"label": "换零件修好它",
				"desc": "-40 织网碎片 · 一段不该存在的录音",
				"effect": OPT_INTEL,
				"intel": "intel_walker_radio",
				"cost_shards": 40,
			},
			{
				"label": "拆了当零件",
				"desc": "+30 织网碎片",
				"effect": OPT_SHARDS,
				"amount": 30,
			},
			{
				"label": "让它继续哑着",
				"desc": "什么都不做",
				"effect": OPT_NONE,
			},
		],
	},
	"memory_pool": {
		"title": "记忆水面",
		"subtitle": "人格茧渗漏 · 未归档",
		"speaker": "卡斯特",
		"line": "别碰。……你碰了，是吧。",
		"options": [
			{
				"label": "把手伸进去",
				"desc": "+18 污染 · 一段改写",
				"effect": OPT_EXTRA_REWARD,
				"pollution": 18.0,
			},
			{
				"label": "取样带走",
				"desc": "+15 织网碎片",
				"effect": OPT_SHARDS,
				"amount": 15,
			},
			{
				"label": "绕开走",
				"desc": "什么都不做",
				"effect": OPT_NONE,
			},
		],
	},
	"cocoon_husk": {
		"title": "茧化残骸",
		"subtitle": "人格茧 · 已经空了很久",
		"speaker": "卡斯特",
		"line": "这层壳子曾经装过一个人。现在只是材料。",
		"options": [
			{
				"label": "割下外壳材料",
				"desc": "本局最大耐久 +30",
				"effect": OPT_MAX_HP,
				"amount": 30,
			},
			{
				"label": "一把火烧了",
				"desc": "污染 -12 · +12 织网碎片",
				"effect": OPT_POLLUTION,
				"pollution": -12.0,
				"shards": 12,
			},
			{
				"label": "不动它",
				"desc": "什么都不做",
				"effect": OPT_NONE,
			},
		],
	},
	"covenant_courier": {
		"title": "裁断信使",
		"subtitle": "柯恩的人 · 单程",
		"speaker": "柯恩",
		"line": "你不是他们派出去的刀，你是他们准备带回来的鞘。",
		"options": [
			{
				"label": "领取补给",
				"desc": "回满耐久 · 修理包 ×1",
				"effect": OPT_CONSUMABLE,
				"consumable": "repair_kit",
				"heal_full": true,
			},
			{
				"label": "交出碎片换情报",
				"desc": "-50 织网碎片 · 一次改写 + 一段情报",
				"effect": OPT_INTEL,
				"intel": "intel_covenant_truth",
				"cost_shards": 50,
				"extra_reward": true,
			},
			{
				"label": "只接一句口信",
				"desc": "什么都不做",
				"effect": OPT_NONE,
			},
		],
	},
}


static func get_event(id: String) -> Dictionary:
	var src: Dictionary = DB.get(id, {})
	if src.is_empty():
		return {}
	# DB 是 const：直接改返回的引用会报 "Invalid assignment on read-only value"，
	# 必须深拷贝一份再注入 id。
	var d := src.duplicate(true)
	d["id"] = id
	return d


static func all_ids() -> Array:
	return DB.keys()


static func roll_event(rng: RandomNumberGenerator, _floor_index: int) -> String:
	var ids: Array = DB.keys()
	if ids.is_empty():
		return ""
	return str(ids[rng.randi_range(0, ids.size() - 1)])


## 选项当前是否可负担
static func can_afford(option: Dictionary, run: RunState) -> bool:
	if run == null:
		return false
	if option.has("cost_coins") and run.coins < int(option["cost_coins"]):
		return false
	if option.has("cost_shards") and run.shards < int(option["cost_shards"]):
		return false
	return true


## 不可负担时的短原因（可负担返回空串）
static func afford_hint(option: Dictionary, run: RunState) -> String:
	if run == null:
		return ""
	if option.has("cost_coins") and run.coins < int(option["cost_coins"]):
		return "盲区币不足"
	if option.has("cost_shards") and run.shards < int(option["cost_shards"]):
		return "织网碎片不足"
	return ""

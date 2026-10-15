class_name Room
extends RefCounted
## 一个房间（横板关卡的一段）。房间之间由闸门隔开，进入后关门清怪、清空开门。

enum Kind { START, COMBAT, ELITE, REWARD, SHOP, REST, EVENT, BOSS, EXIT }

const KIND_NAME := {
	Kind.START: "入口",
	Kind.COMBAT: "战斗",
	Kind.ELITE: "精英",
	Kind.REWARD: "数据舱",
	Kind.SHOP: "黑市",
	Kind.REST: "维修站",
	Kind.EVENT: "终端",
	Kind.BOSS: "核心",
	Kind.EXIT: "升降井",
}

var index: int = 0
var kind: int = Kind.COMBAT
var x_start: float = 0.0
var x_end: float = 0.0
var floor_y: float = 0.0
var ceiling_y: float = -560.0
var platforms: Array[Rect2] = []
var spawn_points: Array[Vector2] = []
var prop_points: Array[Vector2] = []

var entered: bool = false
var cleared: bool = false
var enemies: Array = []              # 存活的敌人
var spawn_count: int = 0             # 应生成的敌人数量
var enemy_ids: Array = []            # 预定的敌人种类
var gate_left: Node = null
var gate_right: Node = null
var payload: Dictionary = {}         # 房间内容（奖励 id、商店库存等）


func width() -> float:
	return x_end - x_start


func center() -> Vector2:
	return Vector2((x_start + x_end) * 0.5, floor_y)


func contains_x(x: float) -> bool:
	return x >= x_start and x <= x_end


func random_spawn(rng: RandomNumberGenerator, edge_margin: float = 160.0) -> Vector2:
	if not spawn_points.is_empty():
		var candidates: Array[Vector2] = []
		var max_x := x_end - edge_margin
		var min_x := x_start + edge_margin
		for p in spawn_points:
			if p.x >= min_x and p.x <= max_x:
				candidates.append(p)
		if not candidates.is_empty():
			return candidates[rng.randi() % candidates.size()]
	return Vector2(rng.randf_range(x_start + edge_margin, x_end - edge_margin), floor_y)


func kind_name() -> String:
	return KIND_NAME.get(kind, "未知")

class_name Room
extends RefCounted
## 一个房间 —— 横板关卡的一段，房间之间由闸门隔开。
##
## 【它不是节点】这只是一份**纯数据**（RefCounted），描述"这一段的坐标范围、
## 有哪些平台、该刷几只什么怪"。真正的绘制由 `level.gd` 统一 `_draw()`，
## 实体由 `run_world.gd` 实例化。所以在这里找不到任何 `add_child()`。
##
## 【生命周期】房间被 `_enter_room()` 进入 → 若 `spawn_count > 0` 就关门刷怪 →
## 清完后 `cleared = true`、开门。`entered` / `cleared` 两个标记会被存档读到
## （只存 index 列表），读档时据此恢复"哪些房间已经清过"。
##
## 【房间类型决定内容】Kind 枚举的每一类对应不同的 populate 逻辑，
## 具体在 `run_world.gd` 里按 `kind` 分支处理。

enum Kind { START, COMBAT, ELITE, REWARD, SHOP, REST, EVENT, BOSS, EXIT }

## 类型 → 中文名。UI 提示与 toast 都用这里，改文案只改这一处。
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

# ---- 几何（由 level.gd 生成时填入） ----
var index: int = 0                    # 在本扇区里的序号，0 起
var kind: int = Kind.COMBAT
var x_start: float = 0.0              # 左边界（世界坐标）
var x_end: float = 0.0                # 右边界
var floor_y: float = 0.0              # 地面高度（玩家站立线）
var ceiling_y: float = -560.0
var platforms: Array[Rect2] = []      # 三层平台的矩形，仅供绘制与立足参考
var spawn_points: Array[Vector2] = [] # 敌人可出现的候选点
var prop_points: Array[Vector2] = []  # 装饰物落点

# ---- 运行时状态 ----
var entered: bool = false             # 玩家是否进去过
var cleared: bool = false             # 是否已清空（清空才开门）
var enemies: Array = []               # 当前存活的敌人节点
var spawn_count: int = 0              # 应刷几只；为 0 表示这不是战斗房
var enemy_ids: Array = []             # 预定的敌人种类（按顺序取）
var gate_left: Node = null            # 左闸门节点引用
var gate_right: Node = null
## 房间内容。手动存档会把它一起存下来（只存标量），
## 所以商店/事件房读档后能保持原状；自动存档不存它，房间会重新生成成原始状态。
var payload: Dictionary = {}


func width() -> float:
	return x_end - x_start


func center() -> Vector2:
	return Vector2((x_start + x_end) * 0.5, floor_y)


func contains_x(x: float) -> bool:
	return x >= x_start and x <= x_end


## 在房间内随机取一个刷怪点。`edge_margin` 用来避开贴着闸门的位置 ——
## 否则敌人可能一出生就卡在门里。
##
## 有一条硬性偏好：**只要存在地面点位，就只在地面刷**。
## 原因来自一次实机试玩：敌人生成在平台上、玩家站在地面，而横扫近战和多数敌人的
## 追击都不会跨高度（敌人也下不来），于是双方隔着两百像素面面相觑 —— 房间永远清不掉，
## 闸门永远不开，整局卡死。平台上刷怪留给飞行单位再做，目前先保证「打得着」。
func random_spawn(rng: RandomNumberGenerator, edge_margin: float = 160.0) -> Vector2:
	var candidates: Array[Vector2] = []
	var max_x := x_end - edge_margin
	var min_x := x_start + edge_margin
	for p in spawn_points:
		if p.x >= min_x and p.x <= max_x:
			candidates.append(p)
	if candidates.is_empty():
		return Vector2(rng.randf_range(min_x, max_x), floor_y)
	var ground: Array[Vector2] = []
	for p in candidates:
		if p.y >= floor_y - 1.0:
			ground.append(p)
	var pool: Array[Vector2] = ground if not ground.is_empty() else candidates
	return pool[rng.randi() % pool.size()]


func kind_name() -> String:
	return KIND_NAME.get(kind, "未知")

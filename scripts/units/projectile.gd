class_name Projectile
extends Node2D
## 能量弹道。玩家与敌人共用，用 team 区分阵营。

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

var velocity := Vector2.ZERO
var damage: float = 10.0
var poise: float = 4.0
var color: Color = Color(0.55, 0.85, 1.0)
var team: String = "player"
var max_range: float = 420.0
var traveled: float = 0.0
var source: Node = null
var pierce: int = 0
var slow: float = 0.0
var slow_time: float = 0.0
var dot: float = 0.0
var dot_time: float = 0.0
var element: String = ""
var dead: bool = false
var _hit_targets: Array = []


func setup(data: Dictionary) -> void:
	global_position = data.get("position", Vector2.ZERO)
	var dir: Vector2 = data.get("direction", Vector2.RIGHT)
	velocity = dir.normalized() * float(data.get("speed", 1100.0))
	damage = float(data.get("damage", 10.0))
	poise = float(data.get("poise", 4.0))
	color = data.get("color", Color(0.55, 0.85, 1.0))
	team = data.get("team", "player")
	max_range = float(data.get("range", 420.0))
	source = data.get("source")
	slow = float(data.get("slow", 0.0))
	slow_time = float(data.get("slow_time", 0.0))
	dot = float(data.get("dot", 0.0))
	dot_time = float(data.get("dot_time", 0.0))
	pierce = int(data.get("pierce", 0))
	element = str(data.get("element", ""))
	z_index = 18


func _ready() -> void:
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if dead:
		return
	var from := global_position
	var to := from + velocity * delta
	var dist := from.distance_to(to)
	traveled += dist
	if traveled >= max_range:
		_explode()
		return

	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.collision_mask = (LAYER_ENEMY if team == "player" else LAYER_PLAYER) | LAYER_WORLD
	q.collide_with_areas = false
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		queue_redraw()
		return

	var collider = hit.get("collider")
	global_position = hit.get("position", to)
	if collider == null:
		_explode()
		return
	# 撞墙
	if collider is StaticBody2D or collider is TileMapLayer:
		_explode()
		return
	if _hit_targets.has(collider):
		global_position = to
		return
	_hit_targets.append(collider)
	if collider.has_method("take_hit"):
		collider.take_hit({
			"amount": damage,
			"poise": poise,
			"kind": "projectile",
			"crit": false,
			"position": global_position,
			"source": source,
			"source_position": from,
			"knockback": velocity.normalized() * 90.0,
			"slow": slow,
			"slow_time": slow_time,
			"dot": dot,
			"dot_time": dot_time,
			"element": element,
		})
	FXLite.spawn_hit_spark(get_parent(), global_position, color, 4)
	if pierce > 0:
		pierce -= 1
		queue_redraw()
		return
	_explode()


func _explode() -> void:
	if dead:
		return
	dead = true
	FXLite.spawn_ring(get_parent(), global_position, color, 22.0, 2.0)
	queue_free()


func _draw() -> void:
	# 沿本地 X 轴绘制（rotation 已对齐速度方向）
	var w := 20.0
	draw_line(Vector2(-w, 0), Vector2(0, 0), Color(color.r, color.g, color.b, 0.25), 6.0)
	draw_line(Vector2(-w, 0), Vector2(0, 0), Color(color.r, color.g, color.b, 0.9), 2.4)
	draw_circle(Vector2.ZERO, 3.0, Color(color.r, color.g, color.b, 1.0))

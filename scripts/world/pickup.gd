class_name Pickup
extends Area2D
## 掉落物：织网碎片 / 盲区币 / 应急修复包。
##
## 玩家碰撞层固定为 2，所以这里只用 collision_mask 监听玩家，自己不占层。
## 距离玩家足够近时会被「磁吸」拉过去，吸附半径受词条 pickup_range_mult 影响。

const BASE_MAGNET := 92.0
const MAGNET_SPEED := 520.0

var kind: String = "shard"
var value: int = 1
var tint: Color = Color("4fd6c8")
var _t: float = 0.0
var _life: float = 0.0
var _vel := Vector2.ZERO
var _picked: bool = false
var _player: Node2D = null
var _shape: CollisionShape2D


func setup(p_kind: String, p_value: int, p_color: Color, pos: Vector2) -> void:
	kind = p_kind
	value = p_value
	tint = p_color
	global_position = pos
	_vel = Vector2(randf_range(-70.0, 70.0), randf_range(-220.0, -120.0))


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 14

	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	_shape.shape = circle
	add_child(_shape)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _picked:
		return
	_t += delta
	_life += delta

	# 抛落
	_vel.y = minf(700.0, _vel.y + 1500.0 * delta)
	_vel.x = move_toward(_vel.x, 0.0, 500.0 * delta)
	global_position += _vel * delta
	if global_position.y > 120.0:
		global_position.y = 120.0
		_vel.y = 0.0
		_vel.x = move_toward(_vel.x, 0.0, 900.0 * delta)

	# 磁吸
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	var radius := BASE_MAGNET
	var run := Game.run
	if run != null:
		radius *= 1.0 + run.stat("pickup_range_mult")
	if _player != null and is_instance_valid(_player):
		var to: Vector2 = _player.global_position + Vector2(0.0, -24.0) - global_position
		if to.length() < radius:
			global_position += to.normalized() * MAGNET_SPEED * delta
			if to.length() < 22.0:
				_collect()

	queue_redraw()


func _find_player() -> Node2D:
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node2D:
			return n
	var parent := get_parent()
	if parent != null:
		for c in parent.get_children():
			if c is Player:
				return c
	return null


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		_collect()


func _collect() -> void:
	if _picked:
		return
	_picked = true
	var run := Game.run
	if run != null:
		match kind:
			"shard":
				run.add_shards(value)
				Sfx.play_varied("shard", -12.0, 0.10)
			"coin":
				run.add_coins(value)
				Sfx.play_varied("coin", -12.0, 0.12)
			"hp":
				run.heal(float(value))
				Sfx.play_varied("heal", -8.0, 0.08)
			_:
				run.add_shards(value)
	FXLite.spawn_hit_spark(get_parent(), global_position, tint, 3)
	queue_free()


func _draw() -> void:
	var bob := sin(_t * 5.0) * 2.4
	var c := tint
	match kind:
		"coin":
			draw_circle(Vector2(0.0, bob), 6.0, c)
			draw_circle(Vector2(0.0, bob), 3.0, c.lightened(0.4))
			draw_arc(Vector2(0.0, bob), 8.5, 0.0, TAU, 16, Color(c.r, c.g, c.b, 0.35), 1.5)
		"hp":
			draw_rect(Rect2(-2.0, -7.0 + bob, 4.0, 14.0), c)
			draw_rect(Rect2(-7.0, -2.0 + bob, 14.0, 4.0), c)
		_:
			var pts := PackedVector2Array([
				Vector2(0.0, -8.0 + bob), Vector2(6.0, 0.0 + bob),
				Vector2(0.0, 8.0 + bob), Vector2(-6.0, 0.0 + bob),
			])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.85))
			draw_polyline(pts + PackedVector2Array([pts[0]]), c.lightened(0.5), 1.2)

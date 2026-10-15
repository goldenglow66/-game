class_name Gate
extends StaticBody2D
## 房间之间的能量闸门：清空房间后开启，进入战斗时关闭。

var is_open: bool = true
var gate_height: float = 600.0
var gate_width: float = 26.0
var accent: Color = Color("4fd6c8")
var _shape: CollisionShape2D
var _glow: float = 0.0


func _init() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 5


func setup(pos: Vector2, height: float, color: Color, start_open: bool) -> void:
	position = pos
	gate_height = height
	accent = color
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(gate_width, gate_height)
	_shape.shape = rect
	add_child(_shape)
	set_open(start_open)


func set_open(open: bool) -> void:
	is_open = open
	collision_layer = 0 if open else 1
	queue_redraw()


func _process(delta: float) -> void:
	if not is_open:
		_glow = minf(1.0, _glow + delta * 3.0)
		if _glow > 0.02:
			queue_redraw()


func _draw() -> void:
	var half := gate_height * 0.5
	var c := accent
	var alpha := 0.0 if is_open else (0.35 + 0.25 * _glow)
	if is_open:
		alpha = 0.08
	# 主体
	draw_rect(Rect2(-gate_width * 0.5, -half, gate_width, gate_height), Color(c.r, c.g, c.b, alpha * 0.35))
	# 横条纹
	var step := 30.0
	var y := -half
	var i := 0
	while y < half:
		var a := alpha * (0.5 + 0.5 * sin(_glow * 4.0 + float(i)))
		draw_line(Vector2(-gate_width * 0.5, y), Vector2(gate_width * 0.5, y), Color(c.r, c.g, c.b, a), 2.0)
		y += step
		i += 1
	# 上下端
	draw_rect(Rect2(-gate_width * 0.5 - 4.0, -half - 10.0, gate_width + 8.0, 12.0), Color(c.r, c.g, c.b, alpha * 1.2))
	draw_rect(Rect2(-gate_width * 0.5 - 4.0, half - 2.0, gate_width + 8.0, 12.0), Color(c.r, c.g, c.b, alpha * 1.2))

class_name Interactable
extends Area2D
## 场景中的可交互点（长椅、改造台、黑市、终端、出击门……）。
##
## 玩家用 shape 查询找到它（layer 8 / 值 128），按交互键后触发 used 信号或 hub_interact 事件。

signal used(player)

@export var prompt_text: String = "交互"
@export var kind: String = "generic"      ## bench / rig / market / terminal / exit
@export var enabled: bool = true
@export var label_text: String = ""

var _shape: CollisionShape2D
var _glow_t: float = 0.0
var accent: Color = Color("4fd6c8")


func _init() -> void:
	collision_layer = 128
	collision_mask = 0
	monitoring = false
	monitorable = true
	z_index = 8


func setup(p_kind: String, p_label: String, p_prompt: String, size: Vector2, p_accent: Color) -> void:
	kind = p_kind
	label_text = p_label
	prompt_text = p_prompt
	accent = p_accent
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(_shape)


func _process(delta: float) -> void:
	_glow_t += delta
	queue_redraw()


func prompt() -> String:
	return prompt_text


## 增益掉落物的画法：悬浮菱形晶体 + 稀有度光环 + 地面光圈。
## 占位图形，等有美术素材再换成贴图。
func _draw_reward(c: Color, pulse: float) -> void:
	var bob := sin(_glow_t * 3.0) * 3.0
	var cy := -34.0 + bob
	# 外层光晕
	draw_circle(Vector2(0.0, cy), 24.0, Color(c.r, c.g, c.b, 0.10 + 0.10 * pulse))
	# 菱形晶体
	var pts := PackedVector2Array([
		Vector2(0.0, cy - 14.0), Vector2(9.0, cy), Vector2(0.0, cy + 14.0), Vector2(-9.0, cy),
	])
	draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.9))
	draw_polyline(pts + PackedVector2Array([pts[0]]), c.lightened(0.6), 1.8)
	# 地面光圈（压扁的椭圆）
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_arc(Vector2(0.0, 0.0), 30.0, 0.0, TAU, 24, Color(c.r, c.g, c.b, 0.22 + 0.14 * pulse), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 顶端指示三角，告诉玩家这里有东西可捡
	var ty := cy - 26.0 - 2.0 * pulse
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.0, ty), Vector2(5.0, ty), Vector2(0.0, ty + 8.0),
	]), Color(c.r, c.g, c.b, 0.8 + 0.2 * pulse))


func interact(player: Node) -> void:
	if not enabled:
		Events.toast.emit("暂时无法使用", UITheme.TEXT_DIM)
		Sfx.play("ui_deny", -6.0)
		return
	Sfx.play("ui_confirm", -4.0)
	used.emit(player)
	Events.hub_interact.emit(kind, self)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_glow_t * 2.4)
	var c := accent
	# 增益掉落物要一眼能从背景里挑出来，所以单独一套画法。
	if kind == "reward":
		_draw_reward(c, pulse)
		return
	# 交互范围提示（地面光圈）
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_arc(Vector2(0.0, 0.0), 34.0, 0.0, TAU, 24, Color(c.r, c.g, c.b, 0.10 + 0.10 * pulse), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 悬浮指示器
	var y := -78.0 - 3.0 * pulse
	draw_line(Vector2(0.0, -52.0), Vector2(0.0, y + 8.0), Color(c.r, c.g, c.b, 0.35), 1.0)
	var pts := PackedVector2Array([
		Vector2(-6.0, y), Vector2(6.0, y), Vector2(0.0, y + 9.0),
	])
	draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.75 + 0.25 * pulse))

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

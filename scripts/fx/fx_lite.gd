class_name FXLite
extends RefCounted
## 轻量特效工厂：所有特效都是自绘制的临时 Node2D，播完自动销毁。
## 目的是在没有任何美术资源的前提下，给打击/移动提供必要的视觉反馈。


static func _spawn(parent: Node, node: Node2D) -> Node2D:
	if parent == null or not is_instance_valid(parent):
		return null
	parent.add_child(node)
	return node


## 冲刺残影
static func spawn_afterimage(parent: Node, pos: Vector2, color: Color, w: float, h: float) -> void:
	var n := FX_Afterimage.new()
	n.setup(pos, color, w, h)
	_spawn(parent, n)


## 命中火花
static func spawn_hit_spark(parent: Node, pos: Vector2, color: Color, count: int = 6) -> void:
	var n := FX_Spark.new()
	n.setup(pos, color, count)
	_spawn(parent, n)


## 伤害数字
static func spawn_damage_number(parent: Node, pos: Vector2, amount: float, crit: bool = false, color: Color = Color.WHITE) -> void:
	if not bool(Game.settings.get("damage_numbers", true)):
		return
	var n := FX_DamageNumber.new()
	n.setup(pos, amount, crit, color)
	_spawn(parent, n)


## 扩散环（完美格挡 / 冲击波）
static func spawn_ring(parent: Node, pos: Vector2, color: Color, radius: float = 60.0, width: float = 3.0) -> void:
	var n := FX_Ring.new()
	n.setup(pos, color, radius, width)
	_spawn(parent, n)


## 文字提示（拾取、破防等）
static func spawn_float_text(parent: Node, pos: Vector2, text: String, color: Color) -> void:
	var n := FX_FloatText.new()
	n.setup(pos, text, color)
	_spawn(parent, n)


# =====================================================================

class FX_Afterimage extends Node2D:
	var life: float = 0.26
	var age: float = 0.0
	var color: Color = Color(0.4, 0.9, 1.0, 0.5)
	var w: float = 26.0
	var h: float = 46.0

	func setup(pos: Vector2, c: Color, width: float, height: float) -> void:
		global_position = pos
		color = c
		w = width
		h = height
		z_index = 15

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - age / life
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(color.r, color.g, color.b, color.a * k * 0.7))
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w, 3.0), Color(color.r, color.g, color.b, color.a * k))


class FX_Spark extends Node2D:
	var life: float = 0.28
	var age: float = 0.0
	var color: Color = Color.WHITE
	var parts: Array = []

	func setup(pos: Vector2, c: Color, count: int) -> void:
		global_position = pos
		color = c
		z_index = 30
		var r := RandomNumberGenerator.new()
		r.randomize()
		for i in count:
			var ang := r.randf_range(-PI, PI)
			var spd := r.randf_range(90.0, 340.0)
			parts.append({"v": Vector2(cos(ang), sin(ang)) * spd, "p": Vector2.ZERO, "len": r.randf_range(4.0, 14.0)})

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		for p in parts:
			p["p"] += p["v"] * delta
			p["v"] *= 0.90
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - age / life
		for p in parts:
			var pos: Vector2 = p["p"]
			var dir := pos.normalized() if pos.length() > 0.01 else Vector2.RIGHT
			draw_line(pos, pos - dir * float(p["len"]) * k, Color(color.r, color.g, color.b, k), 2.0)


class FX_Ring extends Node2D:
	var life: float = 0.34
	var age: float = 0.0
	var color: Color = Color.WHITE
	var radius: float = 60.0
	var line_w: float = 3.0

	func setup(pos: Vector2, c: Color, r: float, w: float) -> void:
		global_position = pos
		color = c
		radius = r
		line_w = w
		z_index = 29

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := age / life
		var r := radius * (0.25 + 0.75 * ease(k, 0.35))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color.r, color.g, color.b, (1.0 - k) * 0.9), line_w)


class FX_DamageNumber extends Node2D:
	var life: float = 0.75
	var age: float = 0.0
	var amount: float = 0.0
	var crit: bool = false
	var color: Color = Color.WHITE
	var vel := Vector2.ZERO

	func setup(pos: Vector2, a: float, c: bool, col: Color) -> void:
		global_position = pos
		amount = a
		crit = c
		color = col
		z_index = 40
		var r := RandomNumberGenerator.new()
		r.randomize()
		vel = Vector2(r.randf_range(-46.0, 46.0), r.randf_range(-190.0, -130.0))

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		global_position += vel * delta
		vel.y += 420.0 * delta
		vel.x *= 0.94
		queue_redraw()

	func _draw() -> void:
		var k := clampf(1.0 - (age - life * 0.5) / (life * 0.5), 0.0, 1.0)
		var size := 22 if crit else 17
		var txt := str(int(round(amount)))
		var col := Color(1.0, 0.85, 0.35) if crit else color
		var font := UITheme.get_font()
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(font, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85 * k))
		draw_string(font, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.r, col.g, col.b, k))


class FX_FloatText extends Node2D:
	var life: float = 1.1
	var age: float = 0.0
	var text: String = ""
	var color: Color = Color.WHITE

	func setup(pos: Vector2, t: String, c: Color) -> void:
		global_position = pos
		text = t
		color = c
		z_index = 41

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		global_position.y -= 34.0 * delta
		queue_redraw()

	func _draw() -> void:
		var k := clampf(1.0 - (age - life * 0.55) / (life * 0.45), 0.0, 1.0)
		var font := UITheme.get_font()
		var size := 16
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8 * k))
		draw_string(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.r, color.g, color.b, k))

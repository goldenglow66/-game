class_name AmbientBackground
extends Node2D
## 标题与据点的氛围背景：远景城市剪影 + 落雨 + 霓虹余晖。
## 纯 _draw 生成，不依赖任何外部素材；挂在 CanvasLayer 上，坐标即视口坐标。

const RAIN_COUNT := 150
const VW := 1280.0
const VH := 720.0

var _t: float = 0.0
var _rain: Array = []          # [x, y, speed, length]
var _skyline: Array = []       # {x, w, h, layer}
var _neon: Array = []          # {x, y, color, phase}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = -100
	_rng.seed = 991733
	_build_skyline()
	_build_neon()
	_build_rain()
	set_process(true)


func _build_skyline() -> void:
	for layer in 2:
		var x := -240.0
		while x < VW + 240.0:
			var w := _rng.randf_range(70.0, 190.0)
			var h := _rng.randf_range(140.0, 420.0) * (0.65 if layer == 1 else 1.0)
			_skyline.append({"x": x, "w": w, "h": h, "layer": layer})
			x += w + _rng.randf_range(4.0, 26.0)


func _build_neon() -> void:
	var palette := [
		Color("4fd6c8"), Color("a98bf0"), Color("ffb347"), Color("e0554f"),
	]
	for i in 26:
		_neon.append({
			"x": _rng.randf_range(0.0, VW),
			"y": _rng.randf_range(180.0, 520.0),
			"color": palette[_rng.randi_range(0, palette.size() - 1)],
			"phase": _rng.randf_range(0.0, TAU),
		})


func _build_rain() -> void:
	for i in RAIN_COUNT:
		_rain.append([
			_rng.randf_range(-160.0, VW + 160.0),
			_rng.randf_range(-VH, VH),
			_rng.randf_range(620.0, 1320.0),
			_rng.randf_range(14.0, 34.0),
		])


func _process(delta: float) -> void:
	_t += delta
	for d in _rain:
		d[1] += float(d[2]) * delta
		d[0] += float(d[2]) * delta * 0.14
		if float(d[1]) > VH + 40.0:
			d[1] = -40.0
			d[0] = _rng.randf_range(-160.0, VW + 160.0)
		if float(d[0]) > VW + 160.0:
			d[0] -= VW + 320.0
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_skyline()
	_draw_neon()
	_draw_rain()


func _draw_sky() -> void:
	var bands := 14
	for i in bands:
		var f := float(i) / float(bands - 1)
		var c := Color("05070c").lerp(Color("141a26"), f)
		draw_rect(Rect2(0.0, VH * f - 1.0, VW, VH / float(bands) + 2.0), c)
	# 地平线雾光
	draw_rect(Rect2(0.0, VH * 0.62, VW, VH * 0.38), Color(0.09, 0.12, 0.18, 0.55))


func _draw_skyline() -> void:
	for b in _skyline:
		var layer := int(b["layer"])
		var base := VH * (0.78 if layer == 0 else 0.70)
		var c := Color("090c13") if layer == 0 else Color("0e121b")
		var h := float(b["h"])
		draw_rect(Rect2(float(b["x"]), base - h, float(b["w"]), h + 260.0), c)
		# 窗光
		if layer == 0:
			var cols := int(float(b["w"]) / 16.0)
			var rows := int(h / 22.0)
			for cx: int in range(cols):
				for ry: int in range(rows):
					if _hash01(int(b["x"]) + cx * 7 + ry * 31) > 0.82:
						var wx := float(b["x"]) + 6.0 + float(cx) * 16.0
						var wy := base - h + 8.0 + float(ry) * 22.0
						var warm := _hash01(int(b["x"]) + cx + ry) > 0.5
						var col := Color(0.85, 0.62, 0.30, 0.5) if warm else Color(0.32, 0.72, 0.72, 0.42)
						draw_rect(Rect2(wx, wy, 5.0, 7.0), col)


func _draw_neon() -> void:
	for n in _neon:
		var c: Color = n["color"]
		var pulse := 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 1.3 + float(n["phase"])))
		var p := Vector2(float(n["x"]), float(n["y"]))
		draw_circle(p, 34.0, Color(c.r, c.g, c.b, 0.035 * pulse))
		draw_circle(p, 9.0, Color(c.r, c.g, c.b, 0.16 * pulse))
		draw_circle(p, 2.6, Color(c.r, c.g, c.b, 0.7 * pulse))


func _draw_rain() -> void:
	var col := Color(0.62, 0.75, 0.86, 0.16)
	for d in _rain:
		var p := Vector2(float(d[0]), float(d[1]))
		draw_line(p, p + Vector2(-3.2, float(d[3])), col, 1.0)


func _hash01(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177
	x = x & 0x7fffffff
	return float(x % 10007) / 10007.0

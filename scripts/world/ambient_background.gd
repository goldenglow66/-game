class_name AmbientBackground
extends Node2D
## 标题与据点的氛围背景：远景城市剪影 + 落雨 + 霓虹余晖。
## 纯 _draw 生成，不依赖任何外部素材；挂在 CanvasLayer 上，坐标即视口坐标。
##
## 绘制分两层，因为两部分的刷新频率完全不同：
##   StaticLayer —— 天空、雾光、城市剪影（上千个矩形，只在视口尺寸变化时重画一次）
##   RainLayer   —— 霓虹脉动与雨滴（每帧重画）
## 以前整层每帧全量重画，城市剪影那些窗户方块白烧了大半的绘制预算。

const RAIN_COUNT := 150
## 背景按视口尺寸铺满：窗口拉大时这些值会跟着变，不能写成常量。
var _vw: float = 1280.0
var _vh: float = 720.0

var _t: float = 0.0
var _rain: Array = []          # [x, y, speed, length]
var _skyline: Array = []       # {x, w, h, layer}
var _neon: Array = []          # {x, y, color, phase}
var _rng := RandomNumberGenerator.new()

var _static: Node2D
var _rain_layer: Node2D


func _ready() -> void:
	z_index = -100
	_sync_bounds()
	_rng.seed = 991733
	_build_skyline()
	_build_neon()
	_build_rain()

	var s := StaticLayer.new()
	s.bg = self
	s.z_index = -2
	add_child(s)
	_static = s

	var r := RainLayer.new()
	r.bg = self
	r.z_index = -1
	add_child(r)
	_rain_layer = r

	get_viewport().size_changed.connect(_on_viewport_resized)
	set_process(true)


## 视口尺寸跟着窗口走，背景必须重铺，否则窗口一拉大就露出底色。
func _sync_bounds() -> void:
	var vp := get_viewport_rect()
	_vw = maxf(vp.size.x, 320.0)
	_vh = maxf(vp.size.y, 240.0)


func _on_viewport_resized() -> void:
	_sync_bounds()
	_skyline.clear()
	_neon.clear()
	_rain.clear()
	_rng.seed = 991733
	_build_skyline()
	_build_neon()
	_build_rain()
	if _static != null:
		_static.queue_redraw()
	if _rain_layer != null:
		_rain_layer.queue_redraw()


func _build_skyline() -> void:
	for layer in 2:
		var x := -240.0
		while x < _vw + 240.0:
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
			"x": _rng.randf_range(0.0, _vw),
			"y": _rng.randf_range(180.0, 520.0),
			"color": palette[_rng.randi_range(0, palette.size() - 1)],
			"phase": _rng.randf_range(0.0, TAU),
		})


func _build_rain() -> void:
	for i in RAIN_COUNT:
		_rain.append([
			_rng.randf_range(-160.0, _vw + 160.0),
			_rng.randf_range(-_vh, _vh),
			_rng.randf_range(620.0, 1320.0),
			_rng.randf_range(14.0, 34.0),
		])


func _process(delta: float) -> void:
	_t += delta
	for d in _rain:
		d[1] += float(d[2]) * delta
		d[0] += float(d[2]) * delta * 0.14
		if float(d[1]) > _vh + 40.0:
			d[1] = -40.0
			d[0] = _rng.randf_range(-160.0, _vw + 160.0)
		if float(d[0]) > _vw + 160.0:
			d[0] -= _vw + 320.0
	# 只重画动态层：城市剪影要等视口尺寸变了才重画。
	if _rain_layer != null:
		_rain_layer.queue_redraw()


## 静态部分：天空渐变、雾光、城市剪影与窗光。调用方是 StaticLayer。
func paint_static(ci: CanvasItem) -> void:
	var bands := 14
	for i in bands:
		var f := float(i) / float(bands - 1)
		var c := Color("05070c").lerp(Color("141a26"), f)
		ci.draw_rect(Rect2(0.0, _vh * f - 1.0, _vw, _vh / float(bands) + 2.0), c)
	# 地平线雾光
	ci.draw_rect(Rect2(0.0, _vh * 0.62, _vw, _vh * 0.38), Color(0.09, 0.12, 0.18, 0.55))

	for b in _skyline:
		var layer := int(b["layer"])
		var base := _vh * (0.78 if layer == 0 else 0.70)
		var c := Color("090c13") if layer == 0 else Color("0e121b")
		var h := float(b["h"])
		ci.draw_rect(Rect2(float(b["x"]), base - h, float(b["w"]), h + 260.0), c)
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
						ci.draw_rect(Rect2(wx, wy, 5.0, 7.0), col)


## 动态部分：霓虹脉动 + 雨滴。调用方是 RainLayer。
func paint_dynamic(ci: CanvasItem) -> void:
	for n in _neon:
		var c: Color = n["color"]
		var pulse := 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 1.3 + float(n["phase"])))
		var p := Vector2(float(n["x"]), float(n["y"]))
		ci.draw_circle(p, 34.0, Color(c.r, c.g, c.b, 0.035 * pulse))
		ci.draw_circle(p, 9.0, Color(c.r, c.g, c.b, 0.16 * pulse))
		ci.draw_circle(p, 2.6, Color(c.r, c.g, c.b, 0.7 * pulse))

	var col := Color(0.62, 0.75, 0.86, 0.16)
	for d in _rain:
		var p := Vector2(float(d[0]), float(d[1]))
		ci.draw_line(p, p + Vector2(-3.2, float(d[3])), col, 1.0)


func _hash01(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177
	x = x & 0x7fffffff
	return float(x % 10007) / 10007.0


class StaticLayer extends Node2D:
	var bg: AmbientBackground

	func _draw() -> void:
		if bg != null:
			bg.paint_static(self)


class RainLayer extends Node2D:
	var bg: AmbientBackground

	func _draw() -> void:
		if bg != null:
			bg.paint_dynamic(self)

class_name GameCamera
extends Camera2D
## 横板跟随相机：带前视偏移、房间范围限制与打击震屏。

var target: Node2D = null
var shake_amount: float = 0.0
var shake_time: float = 0.0
var look_ahead: float = 70.0
var last_facing: int = 1
var confine_left: float = -INF
var confine_right: float = INF
var confine_top: float = -INF
var confine_bottom: float = INF


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0
	ignore_rotation = true
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	Events.shake_requested.connect(_on_shake)


func set_confines(left: float, right: float, top: float, bottom: float) -> void:
	confine_left = left
	confine_right = right
	confine_top = top
	confine_bottom = bottom


func _on_shake(amount: float, duration: float) -> void:
	shake_amount = maxf(shake_amount, amount)
	shake_time = maxf(shake_time, duration)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var f: int = 1
		if "facing" in target:
			f = int(target.facing)
		last_facing = f
		var desired := target.global_position + Vector2(float(f) * look_ahead, -70.0)
		var half_w := 640.0
		var half_h := 360.0
		if confine_left > -INF:
			desired.x = maxf(desired.x, confine_left + half_w)
		if confine_right < INF:
			desired.x = minf(desired.x, confine_right - half_w)
		if confine_top > -INF:
			desired.y = maxf(desired.y, confine_top + half_h)
		if confine_bottom < INF:
			desired.y = minf(desired.y, confine_bottom - half_h)
		# 区域比视口小时居中
		if confine_right - confine_left < half_w * 2.0 and confine_left > -INF:
			desired.x = (confine_left + confine_right) * 0.5
		if confine_bottom - confine_top < half_h * 2.0 and confine_top > -INF:
			desired.y = (confine_top + confine_bottom) * 0.5
		global_position = desired

	if shake_time > 0.0:
		shake_time -= delta
		if shake_time <= 0.0:
			shake_amount = 0.0
			offset = Vector2.ZERO
		else:
			offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount

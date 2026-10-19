class_name Hub
extends Node2D
## 「B2 裁断安全屋」——废都旧区据点。
##
## 单张横板小地图：可自由走动、跳跃、冲刺、挥剑试手感；五个交互点
## （长椅 / 改造台 / 黑市 / 离线终端 / 出击升降机）。
## 美术方向对齐设定文档：焊接安全屋、暗橙灯、离线终端、手工义体。

const WIDTH := 1900.0
const FLOOR_Y := 0.0
const CEIL_Y := -560.0
const SPAWN_X := 560.0

const ORANGE := Color("ff8a3d")
const ORANGE_DIM := Color("7a3a12")
const METAL := Color("191d26")
const METAL_LIGHT := Color("2b3342")

var solids: StaticBody2D
var props_layer: Node2D
var player: Player = null
var camera: GameCamera = null
var interactables: Array[Interactable] = []
var _t: float = 0.0
var _refresh: float = 0.0


func _ready() -> void:
	Game.ensure_hub_state()
	_build_solids()
	_build_props()
	_spawn_player()
	_spawn_camera()
	queue_redraw()
	Events.banner.emit("B2 · 裁断安全屋", "废都旧区 — 唯一可信基地")
	await get_tree().create_timer(2.6).timeout
	Events.subtitle.emit("外壳我重新焊过了。别再把幽灵核插进不该插的地方。", "卡斯特")


# ================= 构建 =================

func _build_solids() -> void:
	solids = StaticBody2D.new()
	solids.name = "Solids"
	solids.collision_layer = 1
	solids.collision_mask = 0
	add_child(solids)

	# 地板 / 天花板
	_add_box(Vector2(WIDTH * 0.5, FLOOR_Y + 150.0), Vector2(WIDTH + 800.0, 300.0))
	_add_box(Vector2(WIDTH * 0.5, CEIL_Y - 110.0), Vector2(WIDTH + 800.0, 220.0))
	# 两端封口
	_add_box(Vector2(-40.0, CEIL_Y * 0.5), Vector2(80.0, absf(CEIL_Y) + 300.0))
	_add_box(Vector2(WIDTH + 40.0, CEIL_Y * 0.5), Vector2(80.0, absf(CEIL_Y) + 300.0))

	# 两处挑高平台（上方堆放补给箱）
	_add_box(Vector2(600.0, -240.0 + 14.0), Vector2(300.0, 28.0))
	_add_box(Vector2(1290.0, -262.0 + 14.0), Vector2(260.0, 28.0))


func _add_box(center: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = center
	solids.add_child(cs)


func _build_props() -> void:
	props_layer = Node2D.new()
	props_layer.name = "Props"
	add_child(props_layer)

	_add_interactable("bench", "长椅", "坐下休整（回满状态 / 保存）", Vector2(300.0, 0.0), Vector2(120.0, 90.0), ORANGE)
	_add_interactable("rig", "改造台", "打开外壳改造（永久升级）", Vector2(680.0, 0.0), Vector2(130.0, 110.0), UITheme.CYAN)
	_add_interactable("market", "黑市终端", "打开黑市（盲区币）", Vector2(1040.0, 0.0), Vector2(130.0, 110.0), UITheme.GOLD)
	_add_interactable("terminal", "离线终端", "读取情报与记忆残页", Vector2(1380.0, 0.0), Vector2(110.0, 120.0), UITheme.VIOLET)
	_add_interactable("exit", "出击升降机", "出勤：进入织网", Vector2(1740.0, 0.0), Vector2(140.0, 200.0), UITheme.RED)


## 在场景里放一个可交互物件（长椅 / 改造台 / 黑市 / 离线终端 / 出击升降机）。
##
## 参数：`kind` 是面板标识（`bench` / `rig` / `market` / `terminal` / `exit`），
## UI 那边拿它决定开哪个面板；`prompt` 是靠近时屏幕中央那行提示。
##
## 【交互链路 —— 这条线不经过 Hub 自己】
## 玩家按 E → `player._try_interact()` 找最近的可交互物 → `Interactable.interact()`
## → `Events.hub_interact.emit(kind, self)` → `ui_root._on_hub_interact()` 开面板。
## 所以这里不需要接 `used` 信号。
func _add_interactable(kind: String, label: String, prompt: String, pos: Vector2, size: Vector2, accent: Color) -> void:
	var it := Interactable.new()
	it.position = pos
	it.setup(kind, label, prompt, size, accent)
	props_layer.add_child(it)
	interactables.append(it)


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = Vector2(SPAWN_X, FLOOR_Y)
	add_child(player)


func _spawn_camera() -> void:
	camera = GameCamera.new()
	camera.name = "Camera"
	camera.target = player
	camera.look_ahead = 46.0
	camera.set_confines(-60.0, WIDTH + 60.0, CEIL_Y - 40.0, FLOOR_Y + 60.0)
	add_child(camera)
	camera.make_current()


# ================= 交互 =================

## 开关玩家的物理与逻辑处理。打开据点面板时会把玩家冻住 ——
## 否则玩家能在菜单还开着的时候继续走动，又碰到别的交互物叠出第二个面板。
func set_controls_enabled(v: bool) -> void:
	if player != null and is_instance_valid(player):
		player.set_physics_process(v)
		player.set_process(v)


# ================= 绘制 =================

func _process(delta: float) -> void:
	_t += delta
	_refresh += delta
	if _refresh >= 0.12:
		_refresh = 0.0
		queue_redraw()


func _draw() -> void:
	_draw_room()
	_draw_lamps()
	_draw_platforms()
	_draw_props()
	_draw_signage()


func _draw_room() -> void:
	var w := WIDTH
	# 底
	draw_rect(Rect2(-500.0, CEIL_Y - 600.0, w + 1000.0, 1600.0), Color("080a0e"))
	# 后墙金属板
	var panel_w := 190.0
	var n := int(w / panel_w) + 1
	for i in n:
		var x := float(i) * panel_w
		var shade := 0.018 * float(i % 3)
		draw_rect(Rect2(x + 3.0, CEIL_Y, panel_w - 6.0, absf(CEIL_Y)), Color("12161d").lightened(shade))
		for k in 4:
			var ry := CEIL_Y + 72.0 + float(k) * 128.0
			draw_circle(Vector2(x + 16.0, ry), 2.6, METAL_LIGHT)
			draw_circle(Vector2(x + panel_w - 16.0, ry), 2.6, METAL_LIGHT)
		# 焊接缝
		draw_line(Vector2(x, CEIL_Y), Vector2(x, 0.0), Color("080a0e"), 3.0)
		draw_line(Vector2(x + 2.0, CEIL_Y), Vector2(x + 2.0, 0.0), Color("1d232e"), 1.0)

	# 电缆（后墙斜拉）
	draw_line(Vector2(120.0, CEIL_Y + 40.0), Vector2(420.0, -120.0), Color("101520"), 3.0)
	draw_line(Vector2(1500.0, CEIL_Y + 40.0), Vector2(1180.0, -150.0), Color("101520"), 3.0)

	# 天花板管道
	for i in 3:
		var py := CEIL_Y + 24.0 + float(i) * 32.0
		draw_rect(Rect2(-200.0, py, w + 400.0, 15.0), Color("161b24"))
		draw_rect(Rect2(-200.0, py, w + 400.0, 3.0), Color("252d3a"))
		if i == 1:
			for k in 14:
				var cx := 90.0 + float(k) * 132.0
				draw_rect(Rect2(cx, py - 4.0, 8.0, 23.0), Color("1e2530"))

	# 地板
	draw_rect(Rect2(-400.0, FLOOR_Y, w + 800.0, 300.0), METAL)
	draw_rect(Rect2(-400.0, FLOOR_Y, w + 800.0, 6.0), METAL_LIGHT)
	draw_rect(Rect2(-400.0, FLOOR_Y + 6.0, w + 800.0, 2.0), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.42))
	for i in int(w / 64.0) + 2:
		var gx := -400.0 + float(i) * 64.0
		draw_line(Vector2(gx, 10.0), Vector2(gx - 26.0, 280.0), Color("11141a"), 1.0)


func _draw_lamps() -> void:
	for i in 5:
		var lx := 210.0 + float(i) * 380.0
		var y := CEIL_Y + 118.0
		var pulse := 0.72 + 0.28 * sin(_t * 1.5 + float(i) * 1.7)
		var pts := PackedVector2Array([
			Vector2(lx - 26.0, y + 6.0), Vector2(lx + 26.0, y + 6.0),
			Vector2(lx + 175.0, FLOOR_Y), Vector2(lx - 175.0, FLOOR_Y),
		])
		draw_colored_polygon(pts, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.05 * pulse))
		draw_rect(Rect2(lx - 30.0, y - 14.0, 60.0, 18.0), Color("212834"))
		draw_rect(Rect2(lx - 30.0, y - 14.0, 60.0, 3.0), Color("333d4d"))
		draw_circle(Vector2(lx, y + 8.0), 9.0, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.30 * pulse))
		draw_circle(Vector2(lx, y + 8.0), 4.0, Color(1.0, 0.82, 0.55, 0.95 * pulse))


func _draw_platforms() -> void:
	for r: Rect2 in [Rect2(450.0, -240.0, 300.0, 28.0), Rect2(1160.0, -262.0, 260.0, 28.0)]:
		draw_rect(r, Color("1d222c"))
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0), METAL_LIGHT)
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 3.0, r.size.x, 3.0), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.55))
		# 支撑桁架
		var cx := r.position.x + r.size.x * 0.5
		draw_line(Vector2(r.position.x + 20.0, r.position.y + r.size.y), Vector2(cx, 0.0), Color("161b24"), 4.0)
		draw_line(Vector2(r.position.x + r.size.x - 20.0, r.position.y + r.size.y), Vector2(cx, 0.0), Color("161b24"), 4.0)
	# 平台上的补给箱
	_draw_crate(520.0, -240.0, 54.0, 44.0)
	_draw_crate(575.0, -240.0, 40.0, 32.0)
	_draw_crate(1230.0, -262.0, 46.0, 40.0)


func _draw_crate(x: float, ground_y: float, w: float, h: float) -> void:
	var r := Rect2(x, ground_y - h, w, h)
	draw_rect(r, Color("1a1f28"))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3.0), Color("2f3846"))
	draw_line(r.position + Vector2(4.0, 4.0), r.end - Vector2(4.0, 4.0), Color("252c38"), 1.0)
	draw_line(Vector2(r.end.x - 4.0, r.position.y + 4.0), Vector2(r.position.x + 4.0, r.end.y - 4.0), Color("252c38"), 1.0)
	draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 6.0, r.position.y + 6.0, 12.0, 4.0), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.5))


func _draw_props() -> void:
	for it in interactables:
		if not is_instance_valid(it):
			continue
		match it.kind:
			"bench": _draw_bench(it.position.x)
			"rig": _draw_rig(it.position.x)
			"market": _draw_market(it.position.x)
			"terminal": _draw_terminal(it.position.x)
			"exit": _draw_exit(it.position.x)


func _draw_bench(x: float) -> void:
	draw_rect(Rect2(x - 62.0, -34.0, 124.0, 16.0), Color("232b36"))
	draw_rect(Rect2(x - 62.0, -34.0, 124.0, 4.0), Color("38424f"))
	draw_rect(Rect2(x - 56.0, -20.0, 10.0, 20.0), Color("1a2029"))
	draw_rect(Rect2(x + 46.0, -20.0, 10.0, 20.0), Color("1a2029"))
	draw_rect(Rect2(x - 54.0, -74.0, 12.0, 42.0), Color("202733"))
	# 靠垫（手工义体布料）
	draw_rect(Rect2(x - 44.0, -30.0, 52.0, 8.0), Color("3a2a24"))
	draw_rect(Rect2(x - 40.0, -70.0, 44.0, 8.0), Color("3a2a24"))


func _draw_rig(x: float) -> void:
	# 工作台
	draw_rect(Rect2(x - 78.0, -58.0, 156.0, 12.0), Color("242c38"))
	draw_rect(Rect2(x - 78.0, -58.0, 156.0, 4.0), UITheme.CYAN.darkened(0.4))
	draw_rect(Rect2(x - 68.0, -46.0, 12.0, 46.0), Color("1a2029"))
	draw_rect(Rect2(x + 56.0, -46.0, 12.0, 46.0), Color("1a2029"))
	# 悬挂机械臂
	draw_rect(Rect2(x + 18.0, -150.0, 10.0, 74.0), Color("1e2530"))
	draw_rect(Rect2(x - 2.0, -86.0, 40.0, 12.0), Color("262e3b"))
	draw_circle(Vector2(x + 6.0, -80.0), 6.0, UITheme.CYAN.darkened(0.2))
	# 台面上的外壳部件
	draw_rect(Rect2(x - 52.0, -74.0, 34.0, 16.0), Color("1b212b"))
	draw_rect(Rect2(x - 46.0, -78.0, 22.0, 5.0), UITheme.CYAN.darkened(0.3))


func _draw_market(x: float) -> void:
	# 货架
	for i in 3:
		var sy := -70.0 - float(i) * 46.0
		draw_rect(Rect2(x - 74.0, sy, 148.0, 8.0), Color("232a35"))
		draw_rect(Rect2(x - 74.0, sy, 148.0, 2.0), Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.35))
	draw_rect(Rect2(x - 78.0, -212.0, 8.0, 212.0), Color("1a2029"))
	draw_rect(Rect2(x + 70.0, -212.0, 8.0, 212.0), Color("1a2029"))
	_draw_crate(x - 60.0, -70.0, 30.0, 24.0)
	_draw_crate(x - 22.0, -70.0, 26.0, 20.0)
	_draw_crate(x + 24.0, -70.0, 34.0, 26.0)
	_draw_crate(x - 40.0, -116.0, 30.0, 22.0)
	_draw_crate(x + 6.0, -116.0, 26.0, 20.0)


func _draw_terminal(x: float) -> void:
	# 立式离线终端
	draw_rect(Rect2(x - 26.0, -128.0, 52.0, 128.0), Color("1b212b"))
	draw_rect(Rect2(x - 26.0, -128.0, 52.0, 4.0), Color("343d4c"))
	draw_rect(Rect2(x - 20.0, -116.0, 40.0, 52.0), Color("0e1218"))
	var vio := UITheme.VIOLET
	for i in 5:
		var ly := -110.0 + float(i) * 10.0
		var lw := 30.0 - float(i % 3) * 7.0
		draw_rect(Rect2(x - 16.0, ly, lw, 3.0), Color(vio.r, vio.g, vio.b, 0.35 + 0.3 * sin(_t * 2.0 + float(i))))
	draw_rect(Rect2(x - 22.0, -54.0, 44.0, 6.0), Color("232a35"))


func _draw_exit(x: float) -> void:
	var acc := UITheme.RED
	# 升降机门框
	draw_rect(Rect2(x - 78.0, -216.0, 156.0, 216.0), Color("141922"))
	draw_rect(Rect2(x - 78.0, -216.0, 156.0, 6.0), Color("2a323f"))
	draw_rect(Rect2(x - 68.0, -204.0, 136.0, 204.0), Color("0b0e13"))
	# 门缝
	draw_rect(Rect2(x - 3.0, -204.0, 6.0, 204.0), Color("070a0e"))
	# 状态灯
	for i in 4:
		var ly := -180.0 + float(i) * 52.0
		var lit := 0.4 + 0.6 * sin(_t * 3.0 + float(i) * 0.8)
		draw_circle(Vector2(x - 56.0, ly), 3.5, Color(acc.r, acc.g, acc.b, 0.35 + 0.5 * lit))
		draw_circle(Vector2(x + 56.0, ly), 3.5, Color(acc.r, acc.g, acc.b, 0.35 + 0.5 * lit))
	# 顶部警示条
	var stripe_w := 22.0
	for i in 6:
		var sx := x - 66.0 + float(i) * stripe_w
		if i % 2 == 0:
			draw_rect(Rect2(sx, -232.0, stripe_w, 12.0), Color(acc.r, acc.g, acc.b, 0.55))
		else:
			draw_rect(Rect2(sx, -232.0, stripe_w, 12.0), Color("1a1f28"))


func _draw_signage() -> void:
	var font := UITheme.get_font()
	var title := "B2 焊接区 07 · 裁断"
	var sub := "「剪断动脉 · 保留选择」— 柯恩"
	draw_string_outline(font, Vector2(520.0, CEIL_Y + 258.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.75))
	draw_string(font, Vector2(520.0, CEIL_Y + 258.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.66, 0.70, 0.78, 0.92))
	draw_string(font, Vector2(522.0, CEIL_Y + 284.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.62))
	# 一侧的撕裂标语
	draw_string(font, Vector2(1120.0, CEIL_Y + 210.0), "剪断动脉 · 保留选择", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.55))

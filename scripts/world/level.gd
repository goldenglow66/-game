class_name Level
extends Node2D
## 一个扇区（floor）的程序化横板关卡：房间序列 + 平台几何 + 闸门。
##
## 绘制全部用 _draw() 完成（无贴图资源），碰撞体用静态箱体拼出。
## 视觉主题按扇区轮换，对齐设定文档的四层结构。

const FLOOR_THICK := 260.0
const CEIL_THICK := 220.0
const GATE_W := 26.0

## 扇区主题（名字取自设定文档的世界结构）
const THEMES := [
	{
		"name": "铁笼", "sub": "监狱层 · B-07 封锁区",
		"bg": Color("0a0d13"), "far": Color("111721"), "mid": Color("1a2130"),
		"floor": Color("222b3a"), "top": Color("3a4759"),
		"accent": Color("4fd6c8"), "glow": Color("2a6f74"),
	},
	{
		"name": "霓虹残骸", "sub": "旧城区 · 酸雨幕",
		"bg": Color("0b0a14"), "far": Color("15102a"), "mid": Color("221a3d"),
		"floor": Color("2a2440"), "top": Color("4a3d6e"),
		"accent": Color("c46ff0"), "glow": Color("5a2f7a"),
	},
	{
		"name": "铸炉", "sub": "加工层 · 熔渣回廊",
		"bg": Color("120b09"), "far": Color("1e120d"), "mid": Color("2b1a13"),
		"floor": Color("38241b"), "top": Color("5e3a28"),
		"accent": Color("ff8a3d"), "glow": Color("7a3a12"),
	},
	{
		"name": "温室", "sub": "仿生层 · 培育舱群",
		"bg": Color("070f0c"), "far": Color("0d1a14"), "mid": Color("163024"),
		"floor": Color("1c3327"), "top": Color("2f5540"),
		"accent": Color("6fe08a"), "glow": Color("246b3a"),
	},
	{
		"name": "白室", "sub": "根壁核心 · 织网心脏",
		"bg": Color("0d0e12"), "far": Color("171923"), "mid": Color("232635"),
		"floor": Color("2e3242"), "top": Color("545c74"),
		"accent": Color("e8c86a"), "glow": Color("6b5a20"),
	},
]

var floor_index: int = 0
var theme: Dictionary = THEMES[0]
var rooms: Array[Room] = []
var rng := RandomNumberGenerator.new()
var solids: StaticBody2D
var gates_layer: Node2D
var total_width: float = 0.0
var theme_index: int = 0

const KEY_ACCENT := "accent"


func theme_name() -> String:
	return theme.get("name", "")


func accent() -> Color:
	return theme.get("accent", Color.WHITE)


# ================= 生成 =================

func generate(p_floor: int, p_rng: RandomNumberGenerator) -> void:
	floor_index = p_floor
	rng = p_rng
	theme_index = floor_index % THEMES.size()
	theme = THEMES[theme_index]

	for c in get_children():
		c.queue_free()
	rooms.clear()

	solids = StaticBody2D.new()
	solids.name = "Solids"
	solids.collision_layer = 1
	solids.collision_mask = 0
	add_child(solids)

	gates_layer = Node2D.new()
	gates_layer.name = "Gates"
	add_child(gates_layer)

	var kinds := _roll_layout()
	var x := 0.0
	for i in kinds.size():
		var r := Room.new()
		r.index = i
		r.kind = kinds[i]
		r.x_start = x
		r.x_end = x + _room_width(r.kind)
		r.floor_y = 0.0
		r.ceiling_y = -600.0
		_build_platforms(r)
		_build_room_solids(r)
		_build_spawn_points(r)
		rooms.append(r)
		x = r.x_end
	total_width = x
	_fill_room_contents()
	_build_gates()
	queue_redraw()


func _roll_layout() -> Array[int]:
	var kinds: Array[int] = []
	kinds.append(Room.Kind.START)
	var middle := 4 + (floor_index % 2)          # 4~5 个中间房间
	if floor_index >= 4:
		middle = 6
	var pool := [
		Room.Kind.COMBAT, Room.Kind.COMBAT, Room.Kind.COMBAT, Room.Kind.COMBAT,
		Room.Kind.ELITE, Room.Kind.EVENT, Room.Kind.REWARD, Room.Kind.REST, Room.Kind.SHOP,
	]
	var last_kind := -1
	for i in middle:
		var pick: int = pool[rng.randi() % pool.size()]
		# 避免连续出现功能房，保证战斗密度
		if pick != Room.Kind.COMBAT and last_kind != Room.Kind.COMBAT and i > 0:
			pick = Room.Kind.COMBAT
		kinds.append(pick)
		last_kind = pick
	kinds.append(Room.Kind.BOSS)
	return kinds


func _room_width(kind: int) -> float:
	match kind:
		Room.Kind.START: return 900.0
		Room.Kind.BOSS: return 2200.0
		Room.Kind.ELITE: return rng.randf_range(1500.0, 1800.0)
		Room.Kind.REWARD, Room.Kind.SHOP, Room.Kind.REST, Room.Kind.EVENT: return 1100.0
	return rng.randf_range(1400.0, 1950.0)


## 三层平台：低层可直接跳上，中/高层需要踩下层起跳
func _build_platforms(r: Room) -> void:
	var low := int(rng.randi_range(2, 4))
	var mid := int(rng.randi_range(1, 3))
	var high := int(rng.randi_range(0, 2))
	if r.kind == Room.Kind.BOSS:
		low = 2
		mid = 2
		high = 0
	if r.kind == Room.Kind.START:
		low = 1
		mid = 1
		high = 0
	_place_platform_row(r, low, -180.0, -128.0, 200.0, 360.0)
	_place_platform_row(r, mid, -345.0, -285.0, 180.0, 300.0)
	_place_platform_row(r, high, -510.0, -445.0, 160.0, 260.0)


func _place_platform_row(r: Room, count: int, y_min: float, y_max: float, w_min: float, w_max: float) -> void:
	if count <= 0:
		return
	var seg := r.width() / float(count + 1)
	for i in count:
		var cx: float = r.x_start + seg * float(i + 1) + rng.randf_range(-seg * 0.18, seg * 0.18)
		var pw := rng.randf_range(w_min, w_max)
		cx = clampf(cx, r.x_start + pw * 0.5 + 60.0, r.x_end - pw * 0.5 - 60.0)
		var y := rng.randf_range(y_min, y_max)
		r.platforms.append(Rect2(cx - pw * 0.5, y, pw, 28.0))


func _build_room_solids(r: Room) -> void:
	_add_box(Vector2((r.x_start + r.x_end) * 0.5, r.floor_y + FLOOR_THICK * 0.5), Vector2(r.width() + GATE_W, FLOOR_THICK))
	_add_box(Vector2((r.x_start + r.x_end) * 0.5, r.ceiling_y - CEIL_THICK * 0.5), Vector2(r.width() + GATE_W, CEIL_THICK))
	for p in r.platforms:
		_add_box(p.position + p.size * 0.5, p.size)
	# 关卡最左端封口
	if r.kind == Room.Kind.START:
		_add_box(Vector2(r.x_start - GATE_W * 0.5, r.ceiling_y * 0.5), Vector2(GATE_W, absf(r.ceiling_y) + FLOOR_THICK))


func _build_spawn_points(r: Room) -> void:
	var n := int(r.width() / 240.0)
	for i in range(1, n):
		r.spawn_points.append(Vector2(r.x_start + 240.0 * float(i), r.floor_y))
	for p in r.platforms:
		r.spawn_points.append(Vector2(p.position.x + p.size.x * 0.5, p.position.y))


## 按房间类型决定「放几只、放什么怪」。这里只排班，实例化交给 RunWorld。
func _fill_room_contents() -> void:
	for r in rooms:
		match r.kind:
			Room.Kind.COMBAT:
				r.spawn_count = clampi(3 + floori(float(floor_index) * 0.5), 3, 7)
				r.enemy_ids = EnemyDB.roll_pack(rng, floor_index, r.spawn_count, false)
			Room.Kind.ELITE:
				var eids: Array = EnemyDB.roll_pack(rng, floor_index, 1, true)
				eids.append_array(EnemyDB.roll_pack(rng, floor_index, 2, false))
				r.enemy_ids = eids
				r.spawn_count = eids.size()
			Room.Kind.BOSS:
				# 每层一个具名 Boss（设定表 9-1）+ 两个随从；Boss 本体由 RunWorld 单独放大生成
				var boss_def := EnemyDB.boss_for_floor(floor_index)
				var bids: Array = [str(boss_def.get("base", "crown_knight"))]
				bids.append_array(EnemyDB.roll_pack(rng, floor_index, 2, false))
				r.enemy_ids = bids
				r.spawn_count = bids.size()
				r.payload = boss_def
			_:
				r.spawn_count = 0
				r.enemy_ids = []


func _build_gates() -> void:
	for i in rooms.size():
		var r := rooms[i]
		if i < rooms.size() - 1:
			var g := Gate.new()
			g.name = "Gate%d" % i
			g.setup(Vector2(r.x_end, (r.floor_y + r.ceiling_y) * 0.5), absf(r.floor_y - r.ceiling_y), theme["accent"], true)
			gates_layer.add_child(g)
			r.gate_right = g


func _add_box(center: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = center
	solids.add_child(cs)


# ================= 绘制 =================

func _draw() -> void:
	var c_bg: Color = theme["bg"]
	var c_far: Color = theme["far"]
	var c_mid: Color = theme["mid"]
	var c_floor: Color = theme["floor"]
	var c_top: Color = theme["top"]
	var c_accent: Color = theme["accent"]
	var c_glow: Color = theme["glow"]

	draw_rect(Rect2(-800.0, -2000.0, total_width + 1600.0, 4000.0), c_bg)

	for r in rooms:
		# 远景立柱
		var n := int(r.width() / 300.0) + 1
		for i in n:
			var px: float = r.x_start + 150.0 + 300.0 * float(i)
			if px > r.x_end - 60.0:
				continue
			draw_rect(Rect2(px - 40.0, r.ceiling_y - CEIL_THICK, 80.0, absf(r.ceiling_y) + CEIL_THICK), c_far)
			draw_rect(Rect2(px - 4.0, r.ceiling_y - CEIL_THICK, 8.0, absf(r.ceiling_y) + CEIL_THICK), Color(c_mid.r, c_mid.g, c_mid.b, 0.85))

		# 中线发光带
		draw_rect(Rect2(r.x_start, r.ceiling_y + 108.0, r.width(), 3.0), Color(c_glow.r, c_glow.g, c_glow.b, 0.55))
		draw_rect(Rect2(r.x_start, r.ceiling_y + 118.0, r.width(), 1.0), Color(c_accent.r, c_accent.g, c_accent.b, 0.25))

		# 地板
		draw_rect(Rect2(r.x_start, r.floor_y, r.width(), FLOOR_THICK), c_floor)
		draw_rect(Rect2(r.x_start, r.floor_y, r.width(), 6.0), c_top)
		draw_rect(Rect2(r.x_start, r.floor_y + 6.0, r.width(), 2.0), Color(c_accent.r, c_accent.g, c_accent.b, 0.4))

		# 天花板
		draw_rect(Rect2(r.x_start, r.ceiling_y - CEIL_THICK, r.width(), CEIL_THICK), c_floor.darkened(0.3))
		draw_rect(Rect2(r.x_start, r.ceiling_y - 4.0, r.width(), 4.0), c_top.darkened(0.35))

		# 平台
		for p in r.platforms:
			draw_rect(p, c_floor.lightened(0.08))
			draw_rect(Rect2(p.position.x, p.position.y, p.size.x, 5.0), c_top)
			draw_rect(Rect2(p.position.x, p.position.y + p.size.y - 3.0, p.size.x, 3.0), Color(c_glow.r, c_glow.g, c_glow.b, 0.75))
			draw_rect(Rect2(p.position.x, p.position.y, 3.0, p.size.y), Color(c_accent.r, c_accent.g, c_accent.b, 0.18))
			draw_rect(Rect2(p.position.x + p.size.x - 3.0, p.position.y, 3.0, p.size.y), Color(c_accent.r, c_accent.g, c_accent.b, 0.18))

		# 房间立柱
		draw_rect(Rect2(r.x_end - 12.0, r.ceiling_y - CEIL_THICK, 24.0, absf(r.ceiling_y) + CEIL_THICK), c_mid)
		draw_rect(Rect2(r.x_end - 2.0, r.ceiling_y - CEIL_THICK, 4.0, absf(r.ceiling_y) + CEIL_THICK), Color(c_glow.r, c_glow.g, c_glow.b, 0.5))


func room_at(x: float) -> Room:
	for r in rooms:
		if r.contains_x(x):
			return r
	return null

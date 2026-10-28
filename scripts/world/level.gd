class_name Level
extends Node2D
## 一个扇区（floor）的程序化横板关卡：房间序列 + 平台几何 + 闸门。
##
## 绘制全部用 _draw() 完成（无贴图资源），碰撞体用静态箱体拼出。
## 视觉主题按扇区轮换，对齐设定文档的四层结构。

const FLOOR_THICK := 260.0
const CEIL_THICK := 220.0
const GATE_W := 26.0

## 怪物房难度的上限。抛物线从 1 爬到 TIER_MAX 再降回 1。
const TIER_MAX := 5

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
#
# 【一个扇区是怎么长出来的】
#   1. `_roll_layout()`    决定房间序列：固定「入口」开头、「核心（Boss）」结尾，
#                          中间 4~6 间从池子里抽（战斗/精英/事件/奖励/休整/商店）
#   2. 逐间给宽度（`_room_width`，按类型给不同区间），x 坐标首尾相接排成一条长走廊
#   3. 每间房放三层平台、地面/天花板碰撞、敌人生成点
#   4. `_fill_room_contents()` 按房间类型排班「放几只什么怪」
#   5. `_build_gates()`    在房间之间立闸门（清空才开）
#
# 【为什么不用 TileMap】全部几何都是 `_draw()` 画矩形 + 静态箱体碰撞，
# 没有贴图资源 —— 好处是改配色/改尺寸只动代码，坏处是视觉细节做不细。
#
# 【关键约定】所有随机都必须走传进来的 `p_rng`（由 `RunState.rng` 播种），
# 不要用全局 `randi()`，否则同一个种子就复现不出同一张图了。

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
	_assign_tiers()
	_fill_room_contents()
	_build_gates()
	queue_redraw()


## 抽房间序列。返回的类型数组第一个是 START、最后一个是 BOSS。
##
## 【区块】借鉴以撒的房间组织方式，搬到横板线性关卡上：中间的房间按「块」分组，
## **一块里要么全是怪物房、要么全是道具房**，两类不会混在同一块。
## 块的顺序固定为 怪物 → 道具 → 怪物：前后两个怪物块各自邻着起点与 Boss，
## 天然构成「两头简单」区；道具块夹在中间，刚好在玩家打累的时候出现。
##
## 【抛物线难度】怪物房的 `tier` 不在这里定，由 `_assign_tiers()` 按它在整层里的
## 相对位置算：两头 1、中间 5。
func _roll_layout() -> Array[int]:
	var kinds: Array[int] = []
	kinds.append(Room.Kind.START)

	# 固定三块：怪物块 → 道具块 → 怪物块。
	# 这样「两头简单中间难」的抛物线才有落点：前后两个怪物块各自邻着
	# 起点和 Boss，天然是简单区；道具块夹在中间，不打断战斗节奏。
	var blocks := [true, false, true]
	for is_monster: bool in blocks:
		# 怪物块 2 间（凑够抛物线需要的样本），道具块 1 间（商店/维修站各占一间刚好）。
		var n := 2 if is_monster else 1
		for i in n:
			kinds.append(Room.Kind.COMBAT if is_monster else _roll_service_kind())

	kinds.append(Room.Kind.BOSS)
	return kinds


## 道具块里的具体房间类型。怪物块用 COMBAT，这里不会返回战斗类。
func _roll_service_kind() -> int:
	var pool := [Room.Kind.SHOP, Room.Kind.REST, Room.Kind.EVENT, Room.Kind.REWARD]
	return pool[rng.randi() % pool.size()]


## 给战斗房按「抛物线」分配难度等级。
##
## 难度曲线 1 - (2t-1)²：t=0 和 t=1 处为 0，t=0.5 处为 1。
## 于是 tier = 1 + (TIER_MAX-1) × 曲线 —— 开头简单、中段最难、收尾又轻松。
##
## 这里的 t 取房间在【整层】里的相对位置（index / 总房间数-1），而不是
## 在「战斗房序列」里的位置。两种取法在只有 4 个战斗房时差别很大：
## 前者算出 [3,5,5,3]（贴近起点的房间不会突然最难），
## 后者算出 [1,5,5,1]（首尾直接顶到两端，中间一步跳到最高）。
## 关卡只有 4 个战斗房时前者更像真正的抛物线。
##
## 精英房无论如何至少 3 级 —— 它存在的意义就是难。
func _assign_tiers() -> void:
	var total := rooms.size()
	if total <= 1:
		return
	for r in rooms:
		if r.kind != Room.Kind.COMBAT and r.kind != Room.Kind.ELITE:
			r.tier = 1
			continue
		var t := float(r.index) / float(total - 1)
		var curve := 1.0 - pow(2.0 * t - 1.0, 2.0)
		var tier := 1 + roundi(float(TIER_MAX - 1) * curve)
		if r.kind == Room.Kind.ELITE:
			tier = maxi(tier, 3)
		r.tier = clampi(tier, 1, TIER_MAX)


func _room_width(kind: int) -> float:
	match kind:
		Room.Kind.START: return 900.0
		Room.Kind.BOSS: return 2200.0
		Room.Kind.ELITE: return rng.randf_range(1500.0, 1800.0)
		# 道具房只是一间「看一眼就走」的房间，比战斗房短得多。
		Room.Kind.REWARD, Room.Kind.SHOP, Room.Kind.REST, Room.Kind.EVENT: return 820.0
	return rng.randf_range(1400.0, 1950.0)


## 三层平台：低层可直接跳上，中/高层需要踩下层起跳
func _build_platforms(r: Room) -> void:
	# 道具房（商店/恢复/事件/数据舱）不放任何平台：这类房间是「进门-交互-出门」动线，
	# 平台只会挡住视线和路径。战斗类房间才需要垂直结构。
	match r.kind:
		Room.Kind.REWARD, Room.Kind.SHOP, Room.Kind.REST, Room.Kind.EVENT:
			return
	# 每层最多两块。以前 low 层会刷 2~4 块、mid 层 1~3 块，
	# 同层挤成三块几乎连在一起，加上上下两层水平方向也可能重叠，
	# 整片看起来就是「三块板粘在一块」。宁少勿挤。
	var low := int(rng.randi_range(1, 2))
	var mid := int(rng.randi_range(1, 2))
	var high := int(rng.randi_range(0, 1))
	if r.kind == Room.Kind.BOSS:
		low = 2
		mid = 2
		high = 0
	if r.kind == Room.Kind.START:
		low = 1
		mid = 1
		high = 0
	# 三层各自错开相位：相同 count 的两层如果都用同一套槽位，
	# 上层的板会正好压在下层板的正上方，看起来就是「好几块板叠在一起」。
	_place_platform_row(r, low, -180.0, -128.0, 200.0, 360.0, 0.0)
	_place_platform_row(r, mid, -345.0, -285.0, 180.0, 300.0, 0.5)
	_place_platform_row(r, high, -510.0, -445.0, 160.0, 260.0, 0.25)


func _place_platform_row(r: Room, count: int, y_min: float, y_max: float, w_min: float, w_max: float, phase_shift: float = 0.0) -> void:
	if count <= 0:
		return
	# 同一层所有平台共用一个高度，并且对齐到 8 的倍数。
	# 每块平台各自随机浮点高度，会让同层的板子高低不齐、边缘落在亚像素上，
	# 看起来像「两块区域叠在一起又错开」，高低差很小时还会卡脚。
	var y := roundf(rng.randf_range(y_min, y_max) / 8.0) * 8.0
	# 把房间横向切成 count + 1 段，一块平台只在自己那一段里活动。
	var seg := r.width() / float(count + 1)
	var gap := 90.0
	var max_w := maxf(seg - gap * 2.0, 90.0)
	var jitter := seg * 0.10
	for i in count:
		var slot_x := r.x_start + seg * (float(i + 1) + phase_shift)
		var pw := minf(roundf(rng.randf_range(w_min, w_max)), roundf(max_w))
		pw = maxf(pw, 90.0)
		# 试着放 8 次：只要跟「竖直方向靠得近」的已有平台横向撞上，就换个位置再试。
		# 单靠 phase_shift 平移是不够的 —— 上下两层数量不同时，段宽不一样，
		# 一块很容易正好落在下层两块中间，宽度一大就叠在一起。
		var x0 := -1.0
		for attempt in 8:
			var cx := slot_x + rng.randf_range(-jitter, jitter)
			cx = clampf(cx, r.x_start + pw * 0.5 + gap, r.x_end - pw * 0.5 - gap)
			var candidate := roundf(cx - pw * 0.5)
			if _platform_slot_free(r, candidate, pw, y, gap):
				x0 = candidate
				break
		if x0 < 0.0:
			continue  # 实在放不下就少放一块，宁缺勿挤
		r.platforms.append(Rect2(x0, y, pw, 28.0))


## 竖直方向隔得远（超过一层半）的平台互不遮挡，可以随便叠；
## 靠得近的要求横向至少留 gap，否则视觉上就是「几块板粘在一起」。
func _platform_slot_free(r: Room, x0: float, pw: float, y: float, gap: float) -> bool:
	for p in r.platforms:
		if absf(p.position.y - y) > 200.0:
			continue
		if x0 + pw + gap <= p.position.x:
			continue
		if p.position.x + p.size.x + gap <= x0:
			continue
		return false
	return true


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
				# 数量跟着 tier 走：1 级 3 只，5 级 7 只。
				r.spawn_count = clampi(2 + r.tier, 3, 7)
				r.enemy_ids = EnemyDB.roll_pack(rng, floor_index, r.spawn_count, false)
			Room.Kind.ELITE:
				var eids: Array = EnemyDB.roll_pack(rng, floor_index, 1, true)
				eids.append_array(EnemyDB.roll_pack(rng, floor_index, 1 + r.tier / 2, false))
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

		# 房间之间的立柱不再绘制：它从天花板一路贯到地板，中间还有一条发光芯，
		# 每个房间边界都来一根，看起来就像一排光柱把画面切成小格子。
		# 房间的分隔交给 gate（关起来时才有实体感）与地面的几何差异去体现。


func room_at(x: float) -> Room:
	for r in rooms:
		if r.contains_x(x):
			return r
	return null

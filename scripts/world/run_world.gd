class_name RunWorld
extends Node2D
## 一局战斗的运行时世界：生成一个扇区（Level），放入玩家与相机，
## 处理「进门关门 → 清怪开门 → 走到尽头下潜」这条核心循环。

const ROOM_MARGIN := 180.0
# 一局要下潜几层：最后一层的 Boss 倒下就是通关
const MAX_FLOOR := 3

var run: RunState = null
var level: Level = null
var player: Player = null
var camera: GameCamera = null

var _current_room: Room = null
var _sector_count: int = 0
var _transitioning: bool = false
var _enemies_layer: Node2D = null
var _active_enemies: Array = []
var _boss_hint_ms: int = 0

## 首帧构建期间不要自动存档，否则 _build_sector() 里的第一次 _enter_room
## 会立刻把刚读出来的存档覆盖成「第一个房间」。
var _ready_done: bool = false
## 读档后第一次踏进这个房间是恢复本身造成的，跳过那一次自动存档。
var _resume_room_index: int = -1


func _ready() -> void:
	Game.run_world = self
	run = Game.run
	if run == null:
		run = Game.start_run(0)
	_build_sector()
	_apply_resume()
	_ready_done = true
	# 新开局立刻落一个自动记录点；续关（_resume_room_index >= 0）不动存档，
	# 免得刚读出来的精确位置被房间入口覆盖。
	if _resume_room_index < 0:
		Game.save_run("auto")
	Events.banner.emit("织网 · 第 %d 扇区" % (run.floor_index + 1), "%s — 表层接入点" % level.theme_name())
	await get_tree().create_timer(2.2).timeout
	if is_instance_valid(self):
		Events.subtitle.emit("织网在你脚下呼吸。往右走，别停。", "卡斯特")


func _exit_tree() -> void:
	if Game.run_world == self:
		Game.run_world = null


## 读档续关。地图不用存 —— 它由 seed 决定，重建出来跟存档时一模一样。
##
## manual：回到保存时的精确坐标，并恢复房间 payload（商店/事件房保持原状）。
## auto  ：回到保存时所在房间的入口，payload 全部丢掉 ——
##         商店、休整房、事件信号源都会重新生成，等于「房间回到原始状态」。
func _apply_resume() -> void:
	if Game.resume_snapshot.is_empty() or level == null:
		return

	var snap := Game.resume_snapshot
	Game.resume_snapshot = {}

	var cleared = snap.get("cleared", [])
	if typeof(cleared) == TYPE_ARRAY:
		for item in cleared:
			var idx := int(item)
			for room in level.rooms:
				if room.index == idx:
					room.cleared = true
					room.entered = true
					break

	var room_index := int(snap.get("room_index", 0))
	var target: Room = null
	for room in level.rooms:
		if room.index == room_index:
			target = room
			break
	if player == null:
		return

	var mode := str(snap.get("mode", "auto"))
	if mode == "manual":
		var payloads = snap.get("payloads", {})
		if typeof(payloads) == TYPE_DICTIONARY:
			for key in payloads.keys():
				var idx := int(str(key))
				for rm in level.rooms:
					if rm.index != idx:
						continue
					var src = payloads[key]
					if typeof(src) != TYPE_DICTIONARY:
						break
					# 整份拷出来再回写：直接从 JSON 反序列化得到的嵌套字典
					# 就地改键容易踩到只读引用，复制一份最稳。
					var merged: Dictionary = rm.payload.duplicate()
					for k in src.keys():
						merged[str(k)] = src[k]
					rm.payload = merged
					break
		var pos = snap.get("pos", {})
		if typeof(pos) == TYPE_DICTIONARY:
			player.global_position = Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))
			_resume_room_index = room_index
			return

	# auto：从房间入口开始。房间坐标是 level 局部的，必须转成世界坐标再用。
	if target != null:
		player.global_position = level.to_global(Vector2(target.x_start + 180.0, target.floor_y - 40.0))
		_resume_room_index = target.index


# ================= 构建 =================

func _build_sector() -> void:
	level = Level.new()
	level.name = "Level"
	level.generate(run.floor_index, run.rng)
	add_child(level)

	_enemies_layer = Node2D.new()
	_enemies_layer.name = "Enemies"
	add_child(_enemies_layer)
	_active_enemies.clear()

	var first: Room = level.rooms[0] if not level.rooms.is_empty() else null
	var spawn := Vector2(ROOM_MARGIN, -40.0)
	if first != null:
		spawn = Vector2(first.x_start + 320.0, first.floor_y - 40.0)

	player = Player.new()
	player.name = "Player"
	player.position = spawn
	add_child(player)

	camera = GameCamera.new()
	camera.name = "Camera"
	camera.target = player
	camera.look_ahead = 80.0
	camera.set_confines(-80.0, level.total_width + 80.0, -700.0, 120.0)
	add_child(camera)
	camera.make_current()

	_sector_count += 1
	if first != null:
		_enter_room(first)


# ================= 房间推进 =================

## 玩家在 level 坐标系里的位置。
##
## 房间边界（`room.x_start` / `level.total_width`）都是 level 的**局部**坐标，而
## `player.global_position` 是世界坐标；`World` 容器本身带一点偏移，两者直接比会差一段距离。
## 差这几十像素的后果很具体：人还没真正踏进房间，就被判定成「已进入」→ 前后闸门一起关上，
## 而玩家此刻恰好站在门的这一侧，于是被永久挡在房间外，怪打不到、房间清不掉、整局卡死。
func _player_level_pos() -> Vector2:
	return level.to_local(player.global_position)


func _physics_process(_delta: float) -> void:
	if _transitioning or player == null or not is_instance_valid(player) or level == null:
		return

	var lpos := _player_level_pos()
	var r := level.room_at(lpos.x)
	if r != null and r != _current_room:
		_enter_room(r)

	_check_room_cleared()

	# 走到扇区尽头 → 下潜一层。但 Boss 房右边没有闸门，所以必须用「本层 Boss 是否已倒下」把关
	if lpos.x > level.total_width - 90.0:
		var last: Room = null
		if not level.rooms.is_empty():
			last = level.rooms[level.rooms.size() - 1]
		if last == null or last.cleared:
			_advance_sector()
		else:
			_remind_boss_gate()

	# 掉出世界 → 拉回
	if lpos.y > 400.0:
		player.global_position = level.to_global(Vector2(ROOM_MARGIN, -60.0))
		player.velocity = Vector2.ZERO


## 玩家踏进一个房间时的**唯一入口** —— 房间的一切状态变化都从这里发起。
##
## 分两种情况：
## - 有怪且没清过（战斗/精英/Boss）：关前后闸门，刷怪。清完后 `_check_room_cleared()` 会开门。
## - 其他：直接开门，并按类型落地内容（奖励房发三选一、商店/休整落地终端、事件房落信号源）。
##
## 末尾的自动存档是「非正常退出的回退点」：每进一个新房间静默写一次房间入口，
## 玩家直接关窗口后再开，就从这间房的门口开始。
## `_resume_room_index` 那一次必须跳过 —— 那是读档恢复本身触发的，存下去会把
## 刚恢复的精确坐标覆盖成房间入口。
func _enter_room(r: Room) -> void:
	_current_room = r
	r.entered = true
	Events.room_entered.emit(r)
	if r.index > 0:
		Sfx.play("door_open", -10.0)

	if r.spawn_count > 0 and not r.cleared:
		# 战斗房：封锁前后门，放怪
		_set_gate(r, false)
		_set_left_gate(r, false)
		_spawn_room_enemies(r)
	else:
		_set_gate(r, true)
		_set_left_gate(r, true)
		if r.kind == Room.Kind.REWARD and not r.cleared:
			r.cleared = true
			_offer_reward(r)
		elif r.kind == Room.Kind.SHOP or r.kind == Room.Kind.REST:
			_populate_service_room(r)
		elif r.kind == Room.Kind.EVENT:
			_populate_event_room(r)

	# 自动记录点：每踏进一个新房间静默写一次「房间入口」存档。
	# 玩家直接关窗口时，这就是回退点。恢复本身触发的那一次要跳过。
	if r.index == _resume_room_index:
		_resume_room_index = -1
	elif _ready_done:
		Game.save_run("auto")


## 事件房：落地一个「未登记信号源」，玩家可以走过去接入，也可以当没看见
func _populate_event_room(r: Room) -> void:
	if not (r.payload is Dictionary):
		r.payload = {}
	if bool(r.payload.get("event_spawned", false)):
		return
	r.payload["event_spawned"] = true
	if str(r.payload.get("event_id", "")) == "":
		r.payload["event_id"] = EventDB.roll_event(run.rng, run.floor_index)

	var node := Interactable.new()
	node.setup("event_node", "未登记信号源", "接入信号源", Vector2(52.0, 84.0), UITheme.VIOLET)
	node.position = Vector2(r.center().x, r.floor_y)
	node.set_meta("room_ref", r)
	r.payload["event_node"] = node
	_enemies_layer.add_child(node)
	Sfx.play("terminal", -12.0)
	Events.toast.emit("检测到未登记信号源", UITheme.VIOLET)


## 商店房 / 休整房：落地一个服务终端，别让这两类房间空跑
func _populate_service_room(r: Room) -> void:
	if not (r.payload is Dictionary):
		r.payload = {}
	if bool(r.payload.get("service_spawned", false)):
		return
	r.payload["service_spawned"] = true
	var is_shop := r.kind == Room.Kind.SHOP
	var node := Interactable.new()
	var accent: Color = UITheme.GOLD if is_shop else UITheme.GREEN
	node.setup(
		"field_market" if is_shop else "rest_node",
		"自动售货机" if is_shop else "维修节点",
		"接入售货机" if is_shop else "接入维修节点",
		Vector2(56.0, 96.0),
		accent
	)
	node.position = Vector2(r.center().x, r.floor_y)
	node.set_meta("room_ref", r)
	r.payload["service_node"] = node
	_enemies_layer.add_child(node)


func _set_gate(r: Room, open: bool) -> void:
	if r == null or r.gate_right == null or not is_instance_valid(r.gate_right):
		return
	r.gate_right.set_open(open)


func _set_left_gate(r: Room, open: bool) -> void:
	if r == null or r.index <= 0 or level == null:
		return
	if r.index - 1 >= level.rooms.size():
		return
	_set_gate(level.rooms[r.index - 1], open)


# ================= 敌人 =================

func _spawn_boss(r: Room, boss_def: Dictionary, hp_mult: float, dmg_mult: float) -> Enemy:
	var base_id := str(boss_def.get("base", "crown_knight"))
	var d := EnemyDB.get_enemy(base_id)
	if d.is_empty():
		return null
	var e := Enemy.new()
	e.name = "Boss_%s" % base_id
	e.position = Vector2(
		clampf(r.center().x + 340.0, r.x_start + 220.0, r.x_end - 220.0),
		r.floor_y - 120.0)
	e.setup(d, run.floor_index,
		hp_mult * float(boss_def.get("hp_mult", 9.0)),
		dmg_mult * float(boss_def.get("dmg_mult", 1.0)))
	e.become_boss(str(boss_def.get("name", "?")), float(boss_def.get("scale", 1.9)))
	# Boss 用自己的配色，别和杂兵混成一片
	if boss_def.has("accent"):
		var bc: Color = boss_def["accent"]
		e.accent = bc
		e.body_color = bc.darkened(0.58)
	e.target = player
	# Boss 体型大、出手慢，把冷却压一点，免得被玩家绕背绕到毫无威胁
	e.attack_cd *= 0.85
	_enemies_layer.add_child(e)
	_active_enemies.append(e)
	return e


func _spawn_room_enemies(r: Room) -> void:
	if r.enemy_ids.is_empty():
		return
	var hp_mult := Game.enemy_hp_mult()
	var dmg_mult := Game.enemy_damage_mult()

	# Boss 房：enemy_ids[0] 是具名 Boss，单独放大生成；剩下的按普通小兵刷
	var boss_def: Dictionary = {}
	if r.kind == Room.Kind.BOSS and r.payload is Dictionary:
		boss_def = r.payload
	var start_i := 0
	var boss_node: Enemy = null
	if not boss_def.is_empty():
		boss_node = _spawn_boss(r, boss_def, hp_mult, dmg_mult)
		start_i = 1

	var used: Array[Vector2] = []
	for i in range(start_i, r.enemy_ids.size()):
		var eid: String = str(r.enemy_ids[i])
		var d := EnemyDB.get_enemy(eid)
		if d.is_empty():
			continue
		var pos := r.random_spawn(run.rng, 220.0)
		var guard := 0
		while _too_close(used, pos) and guard < 14:
			guard += 1
			pos = r.random_spawn(run.rng, 220.0)
		used.append(pos)

		var e := Enemy.new()
		e.name = "Enemy_%s_%d" % [eid, i]
		e.position = pos
		e.setup(d, run.floor_index, hp_mult, dmg_mult)
		e.target = player
		_enemies_layer.add_child(e)
		_active_enemies.append(e)

	if r.kind == Room.Kind.ELITE or r.kind == Room.Kind.BOSS:
		Sfx.play("alarm", -6.0)
		if not boss_def.is_empty():
			var bname := str(boss_def.get("name", "?"))
			Events.boss_started.emit(boss_node)
			Sfx.play("boss_roar", -2.0)
			Events.banner.emit(str(boss_def.get("title", "Boss")), str(boss_def.get("intro", "")))
			Events.subtitle.emit(str(boss_def.get("intro", "")), bname)
			_announce_boss(bname, str(boss_def.get("title", "")))
		else:
			var title := "精英 · %s" % str(EnemyDB.get_enemy(str(r.enemy_ids[0])).get("name", ""))
			Events.banner.emit(title, "封锁已生效")
	else:
		Sfx.play("alarm", -12.0)


func _announce_boss(boss_name: String, title: String) -> void:
	print("[BOSS] engaged: ", boss_name, " / ", title)


func _too_close(list: Array[Vector2], p: Vector2) -> bool:
	for q in list:
		if q.distance_to(p) < 90.0:
			return true
	return false


## 每次有敌人死亡时调用：清掉已死的引用，若全清空了就结算这间房。
##
## 结算动作按顺序：标记已清 → 累计计数 → 开前后门 → 播音效与提示 → 发奖励。
## 注意 `_active_enemies` 里存的是节点引用，敌人被 `queue_free()` 后要先用
## `is_instance_valid()` 过滤，否则遍历时会访问已释放的对象。
func _check_room_cleared() -> void:
	var r := _current_room
	if r == null or r.cleared or r.spawn_count <= 0:
		return
	for i in range(_active_enemies.size() - 1, -1, -1):
		var e = _active_enemies[i]
		if e == null or not is_instance_valid(e) or not e.is_alive():
			_active_enemies.remove_at(i)
	if not _active_enemies.is_empty():
		return

	r.cleared = true
	run.rooms_cleared += 1
	if r.kind == Room.Kind.ELITE or r.kind == Room.Kind.BOSS:
		run.elites_killed += 1
	_set_gate(r, true)
	_set_left_gate(r, true)
	Sfx.play("door_open", -4.0)
	Events.toast.emit("%s · 已清空" % r.kind_name(), UITheme.CYAN)
	Events.room_cleared.emit(r)
	_grant_room_reward(r)


func _grant_room_reward(r: Room) -> void:
	var heal := run.stat("room_clear_heal")
	if heal > 0.0:
		run.heal(heal)
	var ge := run.stat("room_clear_ge")
	if ge > 0.0:
		run.ge = minf(run.max_ge, run.ge + ge)

	# 清空奖励：碎片直接进包
	var bonus := 6 + run.floor_index * 3
	if r.kind == Room.Kind.ELITE:
		bonus *= 2
	if r.kind == Room.Kind.BOSS:
		bonus *= 4
	var extra := run.stat("bonus_cache")
	if extra > 0.0:
		bonus = int(round(float(bonus) * (1.0 + extra)))
	run.add_shards(bonus)
	Events.toast.emit("回收织网碎片 ×%d" % bonus, UITheme.CYAN)

	# Boss 不给普通词条：它给权限和模块（设定表 9-1 的设计原则）
	if r.kind == Room.Kind.BOSS:
		_finish_boss_room(r)
		return

	# 每打下一个房间都给一次改写机会 —— 这是这一局的成长曲线，不是数据舱专属
	_offer_reward(r)


func _remind_boss_gate() -> void:
	var now := Time.get_ticks_msec()
	if now - _boss_hint_ms < 4000:
		return
	_boss_hint_ms = now
	Events.toast.emit("本层尚未肃清 —— 出口锁死", UITheme.RED)
	Sfx.play("ui_deny", -6.0)


func _finish_boss_room(r: Room) -> void:
	run.bosses_killed += 1
	Events.boss_defeated.emit(r)
	Sfx.play("boss_phase", -3.0)

	# 设定表 9-1：Boss 奖励优先给能力锁 / 权限 / 元素模块，而不是纯数值
	var elem := run.grant_random_element()
	if elem != "":
		var ed: Dictionary = UpgradeDB.ELEMENTS.get(elem, {})
		var ename := str(ed.get("name", elem))
		Events.banner.emit("模块已装载 · %s" % ename, "铳械元素模块")
		Events.toast.emit("解锁铳元素：%s" % ename, UITheme.VIOLET)

	if run.floor_index >= MAX_FLOOR - 1:
		_finish_run_victory()
	else:
		Events.banner.emit("扇区肃清", "出口已解锁 —— 继续向下")


func _finish_run_victory() -> void:
	if _transitioning:
		return
	_transitioning = true
	var banked := Game.end_run(true)
	Events.run_ended.emit(true)
	Game.main.call("goto_gameover", true, banked)


func _offer_reward(r: Room) -> void:
	var choices := UpgradeDB.roll_choices(run.rng, 3, run.stacks, run.floor_index)
	if choices.is_empty():
		return
	run.pending_choice = choices
	Events.reward_choices_offered.emit(choices)


# ================= 扇区切换 =================

func _advance_sector() -> void:
	_transitioning = true
	run.floor_index += 1
	run.room_index = 0
	Game.save_meta()

	Events.room_cleared.emit(_current_room)
	Sfx.play("door_open")

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	await tw.finished

	if level != null and is_instance_valid(level):
		level.queue_free()
		level = null

	_build_sector()
	Events.banner.emit("扇区 %d" % (run.floor_index + 1), "%s" % level.theme_name())
	Events.toast.emit("已下潜至第 %d 扇区" % (run.floor_index + 1), UITheme.CYAN)

	var tw2 := create_tween()
	tw2.tween_property(self, "modulate:a", 1.0, 0.4)
	await tw2.finished
	_transitioning = false


func set_controls_enabled(v: bool) -> void:
	if player != null and is_instance_valid(player):
		player.set_physics_process(v)
		player.set_process(v)


func current_room() -> Room:
	return _current_room

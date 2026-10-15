class_name Player
extends CharacterBody2D
## 玩家：Scheris（外壳 + 幽灵锚定核）。
##
## 三位一体操作（对齐设定文档）：剑（近战三段/蓄力）、盾（格挡/完美格挡/盾击）、
## 铳（热量管理/元素模块），外加幽灵形态的相位移动。
## 所有命中判定用手动 shape 查询，不铺 Area2D。

# ---------------- 物理 ----------------
const GRAVITY := 2400.0
const MAX_FALL := 1500.0
const MOVE_SPEED := 300.0
const ACCEL := 2800.0
const AIR_ACCEL := 1900.0
const FRICTION := 3200.0
const AIR_FRICTION := 900.0
const JUMP_VELOCITY := -1030.0
const JUMP_CUT := 0.42
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

const DASH_SPEED := 880.0
const DASH_TIME := 0.15
const DASH_IFRAMES := 0.20
const DASH_COOLDOWN := 0.40

# ---------------- 战斗 ----------------
const COMBO_WINDOW := 0.46
const CHARGE_TIME := 0.38
const CHARGE_MAX := 1.2
const GUARD_SLOW := 0.42
const BASH_COST := 22.0
const GUARD_ST_DRAIN := 12.0
const ST_REGEN := 26.0
const ST_REGEN_DELAY := 0.5

## 三段轻击：(伤害倍率, 前摇, 判定时长, 后摇, 击退, 范围矩形 x 偏移/宽高)
const COMBO := [
	{"mult": 1.00, "startup": 0.07, "active": 0.07, "recover": 0.13, "kb": 200.0, "reach": 46.0, "h": 46.0, "poise": 8.0},
	{"mult": 1.10, "startup": 0.07, "active": 0.07, "recover": 0.14, "kb": 220.0, "reach": 48.0, "h": 50.0, "poise": 9.0},
	{"mult": 1.65, "startup": 0.11, "active": 0.09, "recover": 0.24, "kb": 380.0, "reach": 60.0, "h": 58.0, "poise": 18.0},
]
const SWORD_BASE_DAMAGE := 28.0
const CHARGE_DAMAGE := 62.0
const BASH_DAMAGE := 18.0

const LAYER_WORLD := 1
const LAYER_ENEMY := 4
const LAYER_INTERACT := 128

# 幽灵骇入：幽灵形态下按 E 对敌人建立连接，持续到进度满或中断
const HACK_RANGE := 230.0        # 建立连接的极限距离
const HACK_BREAK_RANGE := 322.0  # 超出这个距离连接断裂（约 1.4 倍）
const HACK_COST := 18.0          # 起手消耗的幽灵能量
const HACK_DRAIN := 5.0          # 骇入期间每秒额外消耗
const HACK_BASE_TIME := 1.5      # 基准耗时，再乘以目标的骇入抗性

signal ghost_form_changed(active: bool)

# ---------------- 状态 ----------------
var facing: int = 1
var action: String = ""          # "", "attack", "dash", "bash", "hurt"
var action_t: float = 0.0
var action_total: float = 0.0
var combo_index: int = -1
var combo_timer: float = 0.0
var current_swing: Dictionary = {}
var swing_hit: bool = false
var dash_ready: float = 0.0
var dash_air_used: bool = false
var iframe_t: float = 0.0
var coyote_t: float = 0.0
var jump_buffer_t: float = 0.0
var st_delay_t: float = 0.0
var charging: bool = false
var charge_t: float = 0.0
var is_guarding: bool = false
var guard_t: float = 0.0
var parry_used: bool = false
var ghost_form: bool = false
var ghost_lean: float = 0.0
var heat_locked: bool = false
var shoot_cd: float = 0.0
var probe_cd: float = 0.0

var hack_target: Enemy = null
var hack_t: float = 0.0
var hack_need: float = 1.5
var hack_tick_t: float = 0.0

var anim_t: float = 0.0
var flash_t: float = 0.0
var _leg_phase: float = 0.0
var _was_on_floor: bool = true
var _step_t: float = 0.0
var _nearby_interactable: Node = null

const MAX_HP := 999.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = LAYER_WORLD | LAYER_INTERACT
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26.0, 46.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -23.0)
	add_child(shape)
	z_index = 20
	Events.player_spawned.emit(self)
	emit_vitals()


func emit_vitals() -> void:
	var run := Game.run
	if run == null:
		return
	Events.player_hp_changed.emit(run.hp, run.max_hp)
	Events.player_ge_changed.emit(run.ge, run.max_ge)
	Events.player_st_changed.emit(run.st, run.max_st)
	Events.player_heat_changed.emit(run.heat, run.max_heat)
	Events.pollution_changed.emit(run.pollution)


# ================= 主循环 =================

func _physics_process(delta: float) -> void:
	anim_t += delta
	flash_t = maxf(0.0, flash_t - delta * 5.0)
	iframe_t = maxf(0.0, iframe_t - delta)
	shoot_cd = maxf(0.0, shoot_cd - delta)
	probe_cd = maxf(0.0, probe_cd - delta)
	dash_ready = maxf(0.0, dash_ready - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	_leg_phase += absf(velocity.x) * delta * 0.035

	if Game.run != null and Game.run.hp <= 0.0:
		return

	_tick_action(delta)
	_tick_timers(delta)
	_read_input(delta)
	_apply_physics(delta)
	_update_vitals(delta)
	_update_interactable()
	_update_hack(delta)

	move_and_slide()

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_on_land()
	_was_on_floor = on_floor
	if on_floor:
		dash_air_used = false
	queue_redraw()


func _tick_action(delta: float) -> void:
	if action == "":
		return
	action_t += delta
	match action:
		"attack":
			var win: float = float(current_swing.get("startup", 0.08))
			if not swing_hit and action_t >= win and action_t <= win + float(current_swing.get("active", 0.07)):
				swing_hit = true
				_perform_swing()
			if action_t >= action_total:
				action = ""
				action_t = 0.0
		"dash":
			if action_t >= DASH_TIME:
				action = ""
				action_t = 0.0
		"bash":
			if action_t >= action_total:
				action = ""
				action_t = 0.0
		"hurt":
			if action_t >= action_total:
				action = ""
				action_t = 0.0


func _tick_timers(delta: float) -> void:
	var run := Game.run
	if is_on_floor():
		coyote_t = COYOTE_TIME
	else:
		coyote_t = maxf(0.0, coyote_t - delta)
	jump_buffer_t = maxf(0.0, jump_buffer_t - delta)
	st_delay_t = maxf(0.0, st_delay_t - delta)
	guard_t += delta
	if st_delay_t <= 0.0 and run != null:
		run.st = minf(run.max_st, run.st + ST_REGEN * delta)


func _read_input(delta: float) -> void:
	var run := Game.run
	if run == null:
		return

	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.15 and action != "dash" and action != "attack" and action != "hurt":
		facing = 1 if dir > 0.0 else -1

	# ---- 跳跃 ----
	if Input.is_action_just_pressed("jump"):
		jump_buffer_t = JUMP_BUFFER
	if jump_buffer_t > 0.0 and coyote_t > 0.0 and action != "dash" and action != "hurt":
		_do_jump()
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and not ghost_form:
		velocity.y *= JUMP_CUT

	# ---- 冲刺 ----
	if Input.is_action_just_pressed("dash") and action != "hurt" and dash_ready <= 0.0:
		var air_ok := is_on_floor() or not dash_air_used
		if air_ok:
			_do_dash()

	# ---- 剑 ----
	if action == "" and not ghost_form:
		if Input.is_action_just_pressed("attack"):
			if is_guarding:
				_do_bash()
			else:
				_do_attack()
		# 蓄力：按住不放
		if Input.is_action_pressed("attack") and not charging and combo_timer <= 0.0 and combo_index < 0:
			charging = true
			charge_t = 0.0
		if charging:
			if Input.is_action_pressed("attack") and not is_guarding:
				charge_t = minf(CHARGE_MAX, charge_t + delta)
			else:
				if charge_t >= CHARGE_TIME:
					_do_charged_attack(charge_t)
				charging = false
				charge_t = 0.0

	# ---- 盾 ----
	var want_guard := Input.is_action_pressed("guard") and action == "" and not ghost_form and not charging
	if want_guard != is_guarding:
		if want_guard:
			guard_t = 0.0
			parry_used = false
		is_guarding = want_guard
		Events.player_guard_changed.emit(is_guarding)

	# ---- 铳 ----
	if Input.is_action_just_pressed("gun") and action == "" and not ghost_form:
		_do_shoot()

	# ---- 幽灵形态 ----
	if Input.is_action_just_pressed("ghost"):
		_toggle_ghost()

	# ---- 探测回波 ----
	if Input.is_action_just_pressed("cycle_weapon") and action == "" and not ghost_form:
		_cycle_element()

	if Input.is_action_just_pressed("probe"):
		_do_probe()

	# ---- 交互 ----
	if Input.is_action_just_pressed("interact"):
		_try_interact()


func _apply_physics(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	if ghost_form:
		# 相位滑行：无重力，八向自由移动，速度更高
		ghost_lean = move_toward(ghost_lean, 1.0, delta * 6.0)
		var v := Vector2(dir, Input.get_axis("move_up", "move_down"))
		if v.length() > 1.0:
			v = v.normalized()
		velocity = velocity.move_toward(v * MOVE_SPEED * 1.28, ACCEL * 0.9 * delta)
		return
	ghost_lean = move_toward(ghost_lean, 0.0, delta * 6.0)

	if action == "dash":
		velocity.x = float(facing) * DASH_SPEED
		velocity.y = 0.0
		return

	var speed_cap := MOVE_SPEED
	if is_guarding:
		speed_cap *= GUARD_SLOW
	if action == "attack" or action == "bash":
		speed_cap *= 0.28 if is_on_floor() else 0.7
	if charging:
		speed_cap *= 0.30

	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	if action == "hurt":
		accel *= 0.3
	if absf(dir) > 0.15:
		velocity.x = move_toward(velocity.x, dir * speed_cap, accel * delta)
	else:
		var fric := FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	if not is_on_floor():
		velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
	elif velocity.y > 0.0 and action != "dash":
		velocity.y = minf(velocity.y, 0.0)


func _update_vitals(delta: float) -> void:
	var run := Game.run
	if run == null:
		return
	# 姿态：格挡持续消耗（完美格挡瞬间除外）
	if is_guarding and action == "":
		var drain := GUARD_ST_DRAIN * Game.run.mult("guard_cost_mult")
		run.st = maxf(0.0, run.st - drain * delta)
		st_delay_t = ST_REGEN_DELAY
		if run.st <= 0.0:
			_guard_break()
	# 铳热量冷却
	if run.heat > 0.0 and shoot_cd <= 0.0:
		var cool := 26.0 * Game.run.mult("heat_recovery_mult") * delta
		if is_guarding:
			cool *= 0.5
		run.heat = maxf(0.0, run.heat - cool)
		if heat_locked and run.heat <= run.max_heat * 0.25:
			heat_locked = false
			Sfx.play("gun_ready", -6.0)
	# 幽灵形态消耗
	if ghost_form:
		run.ge -= 12.0 * Game.run.mult("ghost_cost_mult") * delta
		if run.ge <= 0.0:
			run.ge = 0.0
			_set_ghost(false)
			Events.toast.emit("幽灵能量耗尽", UITheme.VIOLET)
	# 污染缓慢回落
	run.pollution = maxf(0.0, run.pollution - 0.6 * delta)
	Events.player_st_changed.emit(run.st, run.max_st)
	Events.player_heat_changed.emit(run.heat, run.max_heat)
	Events.player_ge_changed.emit(run.ge, run.max_ge)


# ================= 动作 =================

func _do_jump() -> void:
	jump_buffer_t = 0.0
	coyote_t = 0.0
	velocity.y = JUMP_VELOCITY
	Sfx.play_varied("jump", -8.0, 0.08)


func _do_dash() -> void:
	action = "dash"
	action_t = 0.0
	dash_ready = DASH_COOLDOWN
	if not is_on_floor():
		dash_air_used = true
	iframe_t = maxf(iframe_t, DASH_IFRAMES + Game.run.stat("dash_iframe_bonus") / 60.0)
	velocity = Vector2(float(facing) * DASH_SPEED, 0.0)
	Sfx.play_varied("dash", -6.0)
	_spawn_dash_afterimage()


func _do_attack() -> void:
	var next := 0
	if combo_index >= 0 and combo_timer > 0.0:
		next = mini(combo_index + 1, COMBO.size() - 1)
	combo_index = next
	combo_timer = COMBO_WINDOW
	current_swing = COMBO[next]
	swing_hit = false
	action = "attack"
	action_t = 0.0
	action_total = float(current_swing["startup"]) + float(current_swing["active"]) + float(current_swing["recover"])
	charging = false
	Sfx.play_varied("dash", -18.0, 0.2)


func _do_charged_attack(held: float) -> void:
	var ratio := clampf((held - CHARGE_TIME) / (CHARGE_MAX - CHARGE_TIME), 0.0, 1.0)
	current_swing = {
		"mult": CHARGE_DAMAGE / SWORD_BASE_DAMAGE * (1.0 + ratio * 0.6),
		"startup": 0.14, "active": 0.12, "recover": 0.30,
		"kb": 520.0 + 260.0 * ratio, "reach": 78.0, "h": 74.0, "poise": 40.0, "heavy": true,
	}
	combo_index = -1
	combo_timer = 0.0
	swing_hit = false
	action = "attack"
	action_t = 0.0
	action_total = 0.56


func _do_bash() -> void:
	action = "bash"
	action_t = 0.0
	action_total = 0.30
	var run := Game.run
	if run == null:
		return
	if run.st < BASH_COST * 0.5:
		Sfx.play("ui_deny", -10.0)
		action = ""
		return
	run.st = maxf(0.0, run.st - BASH_COST)
	st_delay_t = ST_REGEN_DELAY
	Sfx.play_varied("guard", -4.0)
	_schedule_bash_hit()


func _schedule_bash_hit() -> void:
	await get_tree().create_timer(0.08).timeout
	if not is_instance_valid(self):
		return
	var info := {
		"amount": BASH_DAMAGE * Game.run.mult("bash_damage_mult"),
		"poise": 26.0 * Game.run.mult("bash_poise_mult"),
		"kind": "bash",
		"crit": false,
		"position": global_position,
		"source": self,
		"knockback": Vector2(float(facing) * 320.0, -120.0),
	}
	_shape_query(info, 60.0, 56.0)


func _perform_swing() -> void:
	var run := Game.run
	if run == null:
		return
	var base := SWORD_BASE_DAMAGE * run.mult("sword_damage_mult") * run.mult("all_damage_mult")
	var dmg := base * float(current_swing.get("mult", 1.0))
	var crit := run.rng.randf() < run.stat("crit_chance")
	if crit:
		dmg *= 1.0 + run.stat("crit_mult")
	var info := {
		"amount": dmg,
		"poise": float(current_swing.get("poise", 8.0)),
		"kind": "sword",
		"crit": crit,
		"position": global_position + Vector2(float(facing) * 28.0, -26.0),
		"source": self,
		"knockback": Vector2(float(facing) * float(current_swing.get("kb", 200.0)), -60.0),
	}
	var hits := _shape_query(info, float(current_swing.get("reach", 46.0)), float(current_swing.get("h", 46.0)))
	if hits > 0:
		var heavy := bool(current_swing.get("heavy", false))
		Game.do_hitstop(0.10 if heavy else 0.045)
		Game.shake(5.0 if heavy else 2.4, 0.18)
		Sfx.play_varied("hit_heavy" if heavy else "hit_light", -3.0)


## 手动 shape 查询命中敌人
func _shape_query(info: Dictionary, reach: float, height: float) -> int:
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(reach, height)
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + Vector2(float(facing) * (reach * 0.5 + 6.0), -height * 0.5 - 6.0))
	q.collision_mask = LAYER_ENEMY
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var results := space.intersect_shape(q, 16)
	var count := 0
	var seen := {}
	for r in results:
		var target = r.get("collider")
		if target == null or not is_instance_valid(target):
			continue
		if seen.has(target):
			continue
		seen[target] = true
		if target.has_method("take_hit"):
			var hit_info := info.duplicate()
			hit_info["position"] = target.global_position if target is Node2D else info["position"]
			target.take_hit(hit_info)
			count += 1
	return count


## Tab：在已解锁的铳械模块之间轮换（设定表 6-1 的六种模块）
func _cycle_element() -> void:
	var run := Game.run
	if run == null:
		return
	var owned: Array = run.weapon.get("elements_owned", ["basic"])
	if owned.size() <= 1:
		Sfx.play("ui_deny", -10.0)
		Events.toast.emit("还没装载别的铳械模块 —— 打倒 Boss 才会解锁", UITheme.TEXT_DIM)
		return
	var cur := str(run.weapon.get("gun_element", "basic"))
	var i := owned.find(cur)
	var nxt := str(owned[(i + 1) % owned.size()])
	run.set_element(nxt)
	var ed := run.current_element()
	Sfx.play("ui_move", -3.0)
	Events.toast.emit("铳械模块 ▸ %s" % str(ed.get("name", nxt)), UITheme.VIOLET)


func _do_shoot() -> void:
	var run := Game.run
	if run == null or shoot_cd > 0.0 or heat_locked:
		return
	var element := run.current_element()
	var heat_cost := float(element.get("heat", 18.0))
	if run.heat + heat_cost > run.max_heat:
		heat_locked = true
		Sfx.play("gun_overheat", -4.0)
		Events.toast.emit("铳管过热", UITheme.AMBER)
		return
	run.heat = minf(run.max_heat, run.heat + heat_cost)
	shoot_cd = float(element.get("cooldown", 0.75))
	action = "attack"
	action_t = 0.0
	current_swing = {"startup": 0.06, "active": 0.02, "recover": 0.14, "reach": 0.0, "h": 0.0, "mult": 0.0, "poise": 0.0, "kb": 0.0}
	action_total = 0.22
	swing_hit = true
	_fire_projectiles(element)
	Sfx.play_varied("gun_fire", -4.0)
	Game.shake(2.0, 0.1)


func _fire_projectiles(element: Dictionary) -> void:
	var run := Game.run
	var shots := int(element.get("shots", 3))
	var dmg := float(element.get("damage", 18.0)) * run.mult("gun_damage_mult") * run.mult("all_damage_mult")
	var proj_script := preload("res://scripts/units/projectile.gd")
	for i in shots:
		var p = proj_script.new()
		p.setup({
			"position": global_position + Vector2(float(facing) * 22.0, -28.0),
			"direction": Vector2(float(facing), 0.0),
			"speed": 1150.0,
			"damage": dmg,
			"poise": 4.0,
			"color": element.get("color", UITheme.CYAN),
			"range": 420.0 * run.mult("gun_range_mult"),
			"slow": float(element.get("slow", 0.0)),
			"slow_time": float(element.get("slow_time", 0.0)),
			"dot": float(element.get("dot", 0.0)),
			"dot_time": float(element.get("dot_time", 0.0)),
			# 元素 id 一路透传到 take_hit，敌人的五类克制（表 8-1）全靠它
			"element": str(element.get("id", "basic")),
			"source": self,
			"team": "player",
		})
		get_parent().add_child(p)


## 探测回波：标记范围内的敌人（幽灵体必须被标记才能打出伤害）
func _do_probe() -> void:
	var run := Game.run
	if run == null or probe_cd > 0.0:
		return
	var cost := 6.0 * run.mult("ghost_cost_mult")
	if run.ge < cost:
		Sfx.play("ui_deny", -8.0)
		Events.toast.emit("幽灵能量不足", UITheme.VIOLET)
		return
	run.ge = maxf(0.0, run.ge - cost)
	probe_cd = 2.4
	Events.player_ge_changed.emit(run.ge, run.max_ge)
	Sfx.play("probe", -5.0)

	var origin := global_position + Vector2(0.0, -24.0)
	FXLite.spawn_ring(get_parent(), origin, UITheme.CYAN, 44.0, 3.0)
	FXLite.spawn_float_text(get_parent(), origin + Vector2(0.0, -42.0), "回波", UITheme.CYAN)

	var radius := 420.0 * (1.0 + run.stat("probe_radius_mult"))
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	q.shape = shape
	q.transform = Transform2D(0.0, global_position - Vector2(0.0, 24.0))
	q.collision_mask = LAYER_ENEMY
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var found := 0
	var seen := {}
	for r in space.intersect_shape(q, 32):
		var t = r.get("collider")
		if t == null or not is_instance_valid(t) or seen.has(t):
			continue
		seen[t] = true
		if t.has_method("probe_mark"):
			t.probe_mark(6.0)
			found += 1
	if found > 0:
		Events.toast.emit("回波命中 %d 个信号" % found, UITheme.CYAN)


# ================= 幽灵骇入 =================
#
# 幽灵形态下按 E 对最近的敌人建立连接：进度条走满即生效，中途退出幽灵形态、
# 拉太远、被打中、或能量耗尽都会断线。抗性由目标类别决定（智能体最好骇，异常生物最难）。

func _nearest_hackable() -> Enemy:
	var best: Enemy = null
	var best_d := HACK_RANGE
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or not e.can_be_hacked():
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _begin_hack() -> void:
	var run := Game.run
	if run == null:
		return
	var e := _nearest_hackable()
	if e == null:
		Sfx.play("ui_deny", -8.0)
		Events.toast.emit("附近没有可骇入的信号", UITheme.TEXT_DIM)
		return
	if run.ge < HACK_COST:
		Sfx.play("ui_deny", -8.0)
		Events.toast.emit("幽灵能量不足（需要 %d）" % int(HACK_COST), UITheme.RED)
		return
	run.ge = maxf(0.0, run.ge - HACK_COST)
	Events.player_ge_changed.emit(run.ge, run.max_ge)
	hack_target = e
	hack_t = 0.0
	hack_need = HACK_BASE_TIME * e.hack_resist()
	hack_tick_t = 0.0
	Sfx.play("hack_tick", -6.0)
	Events.hack_progress.emit(e, 0.0)


func _update_hack(delta: float) -> void:
	if hack_target == null:
		return
	if not is_instance_valid(hack_target) or not hack_target.can_be_hacked():
		_cancel_hack("连接对象已损毁")
		return
	if not ghost_form:
		_cancel_hack("脱离幽灵形态")
		return
	if global_position.distance_to(hack_target.global_position) > HACK_BREAK_RANGE:
		_cancel_hack("超出连接距离")
		return
	var run := Game.run
	if run == null:
		return

	run.ge -= HACK_DRAIN * run.mult("ghost_cost_mult") * delta
	if run.ge <= 0.0:
		run.ge = 0.0
		Events.player_ge_changed.emit(run.ge, run.max_ge)
		_cancel_hack("幽灵能量耗尽")
		_set_ghost(false)
		return
	Events.player_ge_changed.emit(run.ge, run.max_ge)

	hack_t += delta / maxf(0.25, hack_need)
	hack_tick_t -= delta
	if hack_tick_t <= 0.0:
		hack_tick_t = 0.14
		Sfx.play_varied("hack_tick", -12.0, 0.20)
	Events.hack_progress.emit(hack_target, clampf(hack_t, 0.0, 1.0))

	if hack_t >= 1.0:
		var victim := hack_target
		hack_target = null
		hack_t = 0.0
		Events.hack_progress.emit(null, 0.0)
		victim.apply_hack_result()
		Events.toast.emit("骇入完成 · %s" % victim.label(), UITheme.CYAN)


func _cancel_hack(reason: String) -> void:
	if hack_target == null:
		return
	hack_target = null
	hack_t = 0.0
	Events.hack_progress.emit(null, 0.0)
	Sfx.play("hack_fail", -8.0)
	if reason != "":
		Events.toast.emit("骇入中断 · %s" % reason, UITheme.RED)


func is_hacking() -> bool:
	return hack_target != null and is_instance_valid(hack_target)


func _toggle_ghost() -> void:
	_set_ghost(not ghost_form)


func _set_ghost(active: bool) -> void:
	if active == ghost_form:
		return
	var run := Game.run
	if active and (run == null or run.ge < 10.0):
		Sfx.play("ui_deny", -8.0)
		Events.toast.emit("幽灵能量不足", UITheme.VIOLET)
		return
	ghost_form = active
	if active:
		is_guarding = false
		charging = false
		combo_index = -1
		action = ""
		collision_mask = LAYER_WORLD | LAYER_INTERACT
		Sfx.play("ghost_enter", -4.0)
	else:
		collision_mask = LAYER_WORLD | LAYER_INTERACT
		velocity = Vector2.ZERO
		Sfx.play("ghost_exit", -4.0)
		# 退出相位时连接必然断开（_update_hack 也会兜底，这里保证同一帧就断）
		if hack_target != null:
			_cancel_hack("脱离幽灵形态")
	ghost_form_changed.emit(active)
	Events.ghost_form_changed.emit(active)


# ================= 受击 / 资源 =================

func take_hit(info: Dictionary) -> void:
	var run := Game.run
	if run == null or run.hp <= 0.0:
		return
	var kind: String = info.get("kind", "melee")
	if iframe_t > 0.0:
		return
	# 挨打会打断骇入连接
	if hack_target != null:
		_cancel_hack("遭受攻击")
	if ghost_form:
		# 相位态只受能量伤害
		run.ge = maxf(0.0, run.ge - 6.0)
		Events.player_ge_changed.emit(run.ge, run.max_ge)
		return

	var amount: float = float(info.get("amount", 10.0))
	var from_dir: int = 1
	if info.has("source_position"):
		from_dir = -1 if float(info["source_position"].x) > global_position.x else 1

	# 完美格挡判定
	if is_guarding and action == "" and facing == from_dir:
		if guard_t <= run.stat("parry_window") and not parry_used:
			_perfect_guard(info)
			return
		# 普通格挡
		var reduction: float = clampf(run.stat("guard_reduction"), 0.0, 0.95)
		if run.hp < run.max_hp * 0.3:
			reduction += run.stat("low_hp_guard_bonus")
		amount *= (1.0 - clampf(reduction, 0.0, 0.95))
		var st_cost: float = amount * 1.2 * run.mult("guard_cost_mult")
		run.st = maxf(0.0, run.st - st_cost)
		st_delay_t = ST_REGEN_DELAY
		_apply_damage(amount, from_dir, 0.10)
		Sfx.play("guard", -3.0)
		if run.st <= 0.0:
			_guard_break()
		Events.player_st_changed.emit(run.st, run.max_st)
		return

	if kind == "projectile":
		amount *= 1.0
	_apply_damage(amount, from_dir, 0.22)


func _perfect_guard(info: Dictionary) -> void:
	parry_used = true
	var run := Game.run
	run.st = minf(run.max_st, run.st + 30.0)
	run.ge = minf(run.max_ge, run.ge + 12.0)
	iframe_t = 0.35
	Game.do_hitstop(0.13)
	Game.shake(8.0, 0.25)
	Sfx.play("parry", 2.0)
	Events.perfect_guard.emit(global_position + Vector2(float(facing) * 20.0, -26.0))
	var src = info.get("source")
	if src != null and is_instance_valid(src) and src.has_method("on_parried"):
		src.on_parried(self)


func _apply_damage(amount: float, from_dir: int, stun: float) -> void:
	var run := Game.run
	var taken: float = amount * (1.0 + run.stat("damage_taken_mult")) * Game.enemy_damage_mult()
	taken = maxf(1.0, taken)
	run.hp = maxf(0.0, run.hp - taken)
	Events.player_hp_changed.emit(run.hp, run.max_hp)
	Events.damage_taken.emit({"amount": taken, "kind": "hit", "position": global_position, "source": null})
	Events.shake_requested.emit(6.0, 0.2)
	flash_t = 1.0
	iframe_t = maxf(iframe_t, 0.55)
	velocity = Vector2(float(from_dir) * 220.0, -260.0)
	is_guarding = false
	action = "hurt"
	action_t = 0.0
	action_total = stun
	Sfx.play("player_hurt", -2.0)
	Game.do_hitstop(0.07)
	if run.hp <= 0.0:
		_die()


func _guard_break() -> void:
	is_guarding = false
	Events.player_guard_changed.emit(false)
	Events.toast.emit("姿态崩溃", UITheme.RED)
	Sfx.play("guard_break", -2.0)
	Game.do_hitstop(0.12)
	Game.shake(7.0, 0.3)
	var run := Game.run
	run.st = 0.0
	action = "hurt"
	action_t = 0.0
	action_total = 0.6


func _die() -> void:
	var run := Game.run
	# 重启协议 / 空壳核心
	if not run.revive_used and (Game.meta_upgrades.get("revive_protocol", 0) > 0 or run.stat("revive_once") > 0.0):
		run.revive_used = true
		run.hp = run.max_hp * 0.4
		iframe_t = 2.0
		Events.player_hp_changed.emit(run.hp, run.max_hp)
		Sfx.play("revive", 0.0)
		Events.banner.emit("重启协议", "外壳就地重启")
		return
	Sfx.play("player_die", 0.0)
	Events.player_died.emit()


func _on_land() -> void:
	if absf(velocity.y) > 200.0 or true:
		Sfx.play_varied("land", -14.0, 0.1)


# ================= 交互 =================

func _update_interactable() -> void:
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 68.0
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + Vector2(0.0, -26.0))
	q.collision_mask = LAYER_INTERACT
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var results := space.intersect_shape(q, 8)
	var best: Node = null
	var best_d := INF
	for r in results:
		var target = r.get("collider")
		if target == null or not is_instance_valid(target):
			continue
		if target.has_method("interact"):
			var d: float = (target.global_position - global_position).length()
			if d < best_d:
				best_d = d
				best = target
	_nearby_interactable = best


func _try_interact() -> void:
	# 幽灵形态下 E 不再「使用东西」，而是「骇进去」：没在骇就起手，正在骇就主动断开
	if ghost_form:
		if hack_target != null:
			_cancel_hack("主动断开")
		else:
			_begin_hack()
		return
	if _nearby_interactable != null and is_instance_valid(_nearby_interactable):
		_nearby_interactable.interact(self)


func has_interactable() -> bool:
	return _nearby_interactable != null and is_instance_valid(_nearby_interactable)


func current_interactable() -> Node:
	return _nearby_interactable if has_interactable() else null


func interact_prompt() -> String:
	if not has_interactable():
		return ""
	return _nearby_interactable.call("prompt") if _nearby_interactable.has_method("prompt") else "交互"


# ================= 表现 =================

func _spawn_dash_afterimage() -> void:
	Events.shake_requested.emit(1.5, 0.08)
	FXLite.spawn_afterimage(get_parent(), global_position + Vector2(0, -24), Color(0.31, 0.84, 0.78, 0.5), 26.0, 46.0)


func _draw() -> void:
	var run := Game.run
	var t := anim_t
	var body := Color("242b38")
	var edge := Color("59657a")
	var glow := UITheme.CYAN
	if ghost_form:
		body = Color(0.24, 0.45, 0.62, 0.42)
		edge = Color(0.55, 0.85, 0.95, 0.55)
		glow = UITheme.VIOLET

	# 无敌帧闪烁
	var alpha := 1.0
	if iframe_t > 0.0 and not ghost_form:
		alpha = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 40.0))
	if flash_t > 0.0:
		body = body.lerp(Color(2.2, 2.2, 2.4), flash_t * 0.85)
		edge = edge.lerp(Color(2.4, 2.4, 2.6), flash_t)

	var f := float(facing)
	var crouch := 3.0 if is_guarding else 0.0
	var bob := sin(_leg_phase * 2.0) * 1.2 if is_on_floor() and absf(velocity.x) > 20.0 else 0.0

	# 影子
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 腿
	var swing := sin(_leg_phase) * 7.0 if is_on_floor() else 5.0
	var leg_y := -18.0 + crouch
	var legs := [
		Rect2(-9.0 + swing * 0.6, leg_y, 7.0, 18.0 - crouch),
		Rect2(2.0 - swing * 0.6, leg_y, 7.0, 18.0 - crouch),
	]
	for r in legs:
		draw_rect(r, Color(body.r, body.g, body.b, alpha))
		draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), Color(edge.r, edge.g, edge.b, alpha))

	# 躯干
	var torso := Rect2(-11.0, -42.0 + crouch + bob, 22.0, 26.0 - crouch)
	draw_rect(torso, Color(body.r, body.g, body.b, alpha))
	draw_rect(Rect2(torso.position.x, torso.position.y, torso.size.x, 3.0), Color(edge.r, edge.g, edge.b, alpha * 0.9))
	draw_rect(Rect2(torso.position.x, torso.end.y - 2.0, torso.size.x, 2.0), Color(glow.r, glow.g, glow.b, alpha * 0.35))

	# 胸口锚定核
	var core_pos := Vector2(0.0, -31.0 + crouch + bob)
	var core_col := glow if not ghost_form else UITheme.VIOLET
	var pulse := 0.6 + 0.4 * sin(t * 5.0)
	draw_circle(core_pos, 5.5, Color(core_col.r, core_col.g, core_col.b, 0.22 * alpha * pulse))
	draw_circle(core_pos, 2.6, Color(core_col.r, core_col.g, core_col.b, 0.95 * alpha))

	# 头 + 面甲
	var head := Rect2(-8.0, -56.0 + crouch + bob, 16.0, 14.0)
	draw_rect(head, Color(body.r, body.g, body.b, alpha))
	draw_rect(Rect2(head.position.x, head.position.y, head.size.x, 2.0), Color(edge.r, edge.g, edge.b, alpha))
	draw_rect(Rect2(head.position.x + (5.0 if facing > 0 else -7.0), head.position.y + 6.0, 11.0, 2.4), Color(glow.r, glow.g, glow.b, alpha))

	# 盾（格挡姿态）
	if is_guarding:
		var sc := glow if guard_t <= (run.stat("parry_window") if run != null else 0.22) else edge
		var sx := 13.0 * f
		draw_rect(Rect2(sx - 3.0, -44.0 + crouch, 6.0, 30.0), Color(sc.r, sc.g, sc.b, alpha * 0.9))
		draw_rect(Rect2(sx - 6.0, -46.0 + crouch, 12.0, 4.0), Color(sc.r, sc.g, sc.b, alpha * 0.6))

	# 剑
	var swing_angle := _sword_angle()
	var hand := Vector2(6.0 * f, -30.0 + crouch + bob)
	if charging:
		draw_circle(hand + Vector2(8.0 * f, 6.0), 8.0 + charge_t * 10.0, Color(UITheme.AMBER.r, UITheme.AMBER.g, UITheme.AMBER.b, 0.12 + 0.2 * (charge_t / CHARGE_MAX)))
	var blade_len := 40.0
	if bool(current_swing.get("heavy", false)) and action == "attack":
		blade_len = 54.0
	var tip := hand + Vector2(cos(swing_angle), sin(swing_angle)) * blade_len * f
	var blade_col := UITheme.AMBER if charging else glow
	draw_line(hand, tip, Color(edge.r, edge.g, edge.b, alpha * 0.8), 3.0)
	draw_line(hand, tip, Color(blade_col.r, blade_col.g, blade_col.b, alpha * 0.85), 1.4)

	# 挥砍残影
	if action == "attack" and not swing_hit and float(current_swing.get("reach", 0.0)) > 0.0:
		var w: float = float(current_swing.get("h", 46.0))
		var r: float = float(current_swing.get("reach", 46.0))
		draw_rect(Rect2(6.0 * f - (0.0 if f > 0 else r), -w - 6.0, r, w), Color(blade_col.r, blade_col.g, blade_col.b, 0.10))

	# 蓄力光环
	if charging and charge_t >= CHARGE_TIME:
		var p := 0.5 + 0.5 * sin(t * 18.0)
		draw_arc(Vector2(0, -26), 26.0, 0.0, TAU, 24, Color(UITheme.AMBER.r, UITheme.AMBER.g, UITheme.AMBER.b, 0.20 + 0.25 * p), 2.0)

	# 骇入连接线 + 进度环（画在自身局部坐标里，用 to_local 换算目标位置）
	if hack_target != null and is_instance_valid(hack_target):
		var origin := Vector2(0.0, -26.0)
		var lp := to_local(hack_target.global_position + Vector2(0.0, -18.0))
		var hack_pulse := 0.5 + 0.5 * sin(t * 22.0)
		draw_line(origin, lp, Color(UITheme.CYAN.r, UITheme.CYAN.g, UITheme.CYAN.b, 0.30 + 0.45 * hack_pulse), 2.0)
		var k: float = clampf(hack_t, 0.0, 1.0)
		draw_arc(origin, 17.0, -PI * 0.5, -PI * 0.5 + TAU * k, 28, UITheme.CYAN, 2.6)
		draw_arc(origin, 17.0, 0.0, TAU, 28, Color(UITheme.CYAN.r, UITheme.CYAN.g, UITheme.CYAN.b, 0.18), 1.0)


func _sword_angle() -> float:
	match action:
		"attack":
			var win: float = float(current_swing.get("startup", 0.07))
			var span: float = float(current_swing.get("active", 0.07)) + float(current_swing.get("recover", 0.13))
			var k: float = clampf((action_t - win * 0.6) / maxf(span, 0.01), 0.0, 1.0)
			if bool(current_swing.get("heavy", false)):
				return lerpf(-2.2, 1.1, k)
			return lerpf(-1.9, 0.8, k)
		"bash":
			return lerpf(0.2, -0.4, clampf(action_t / 0.3, 0.0, 1.0))
	if is_guarding:
		return -0.35
	if charging:
		return -2.4
	return -0.9

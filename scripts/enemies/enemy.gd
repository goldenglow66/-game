class_name Enemy
extends CharacterBody2D
## 敌人实体：一个带 AI 状态机的横板单位。
##
## 与玩家/弹道的接口约定（改这里前先确认三处调用方）：
##   - collision_layer 固定为 4（玩家挥剑的 shape 查询、玩家弹道的 ray 都按 4 找目标）
##   - collision_mask 固定为 1（只与世界碰撞，敌人之间不互相推挤）
##   - 必须提供 take_hit(info: Dictionary)，字段见 _apply_hit
##   - 必须提供 on_parried(by: Node)，供玩家完美格挡后回调

const GRAVITY := 1900.0
const MAX_FALL := 1250.0
const HURT_TIME := 0.26
const RECOVER_TIME := 0.30

enum State { IDLE, PATROL, CHASE, WINDUP, RECOVER, HURT, DEAD }

var id: String = ""
var def: Dictionary = {}

var category: int = EnemyDB.Cat.MACHINE
var behavior: String = EnemyDB.WALKER

var max_hp: float = 70.0
var hp: float = 70.0
var damage: float = 12.0
var base_speed: float = 100.0
var poise_max: float = 14.0
var poise: float = 14.0
var reach: float = 46.0
var attack_cd: float = 1.4
var windup: float = 0.34
var aggro: float = 430.0
var keep_dist: float = 200.0
var burst: int = 1
var combo: int = 1
var is_ranged: bool = false
var is_ghost: bool = false
var is_elite: bool = false
var shard_value: int = 3
var coin_value: int = 2

var body_color: Color = Color("6d7c8c")
var accent: Color = Color("ffd166")

var target: Node2D = null
var state: int = State.IDLE
var state_t: float = 0.0
var facing: int = -1
var attack_timer: float = 0.6
var flash_t: float = 0.0
var hp_bar_t: float = 0.0
var slow_t: float = 0.0
var slow_amt: float = 0.0
var dot_t: float = 0.0
var dot_dps: float = 0.0
var probe_mark_t: float = 0.0
var spawn_t: float = 0.0

# 骇入：幽灵形态下的核心交互。敌方只负责「被骇」的进度与后果，发起方在 player.gd。
var hack_stun_t: float = 0.0

var _combo_left: int = 0
var _home_x: float = 0.0
var _patrol_dir: int = 1
var _leg_phase: float = 0.0
var _anim_t: float = 0.0
var _dead: bool = false
var _collision: CollisionShape2D

# Boss 专用：Boss 不是新写一个单位类型，而是被放大、改名、加阶段的精英。
var display_name: String = ""
var is_boss: bool = false
var scale_mult: float = 1.0


func setup(p_def: Dictionary, floor_index: int, hp_mult: float, dmg_mult: float) -> void:
	def = p_def
	id = str(p_def.get("id", ""))
	category = int(p_def.get("category", EnemyDB.Cat.MACHINE))
	behavior = str(p_def.get("behavior", EnemyDB.WALKER))

	var scale := EnemyDB.floor_scale(floor_index)
	max_hp = float(p_def.get("hp", 70.0)) * scale["hp"] * hp_mult
	hp = max_hp
	damage = float(p_def.get("damage", 12.0)) * scale["damage"] * dmg_mult
	base_speed = float(p_def.get("speed", 100.0))
	poise_max = float(p_def.get("poise", 14.0))
	poise = poise_max
	reach = float(p_def.get("reach", 46.0))
	attack_cd = float(p_def.get("attack_cd", 1.4))
	windup = float(p_def.get("windup", 0.34))
	aggro = float(p_def.get("aggro", 430.0))
	keep_dist = float(p_def.get("keep_dist", 200.0))
	burst = int(p_def.get("burst", 1))
	combo = int(p_def.get("combo", 1))
	is_ranged = bool(p_def.get("ranged", false))
	is_ghost = bool(p_def.get("ghost", false))
	is_elite = bool(p_def.get("elite", false))
	shard_value = int(round(float(p_def.get("shards", 3)) * scale["shards"]))
	coin_value = int(p_def.get("coins", 2))
	body_color = p_def.get("color", Color("6d7c8c"))
	accent = p_def.get("accent", Color("ffd166"))


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 16
	add_to_group("enemies")
	_home_x = global_position.x
	_patrol_dir = 1 if randf() < 0.5 else -1
	facing = _patrol_dir

	var w := float(def.get("w", 34.0))
	var h := float(def.get("h", 46.0))
	_collision = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	_collision.shape = rect
	_collision.position = Vector2(0.0, -h * 0.5)
	add_child(_collision)

	spawn_t = 0.0
	modulate.a = 0.0
	state = State.PATROL
	if is_ranged and behavior == EnemyDB.TURRET:
		state = State.IDLE


func size() -> Vector2:
	return Vector2(float(def.get("w", 34.0)), float(def.get("h", 46.0)))


## Boss 化：放大体型，同步碰撞盒 / 攻击距离 / 姿态上限，并挂上专属名字。
## 必须在 add_child() 之前调用，好让 _ready() 建的碰撞盒一次就位。
func become_boss(p_name: String, mult: float) -> void:
	is_boss = true
	is_elite = true
	display_name = p_name
	scale_mult = maxf(1.0, mult)
	self.scale = Vector2(scale_mult, scale_mult)
	reach *= scale_mult
	poise_max *= 1.6
	poise = poise_max


func is_alive() -> bool:
	return not _dead and hp > 0.0


func probe_mark(duration: float = 6.0) -> void:
	probe_mark_t = maxf(probe_mark_t, duration)


# ================= 骇入（幽灵形态的核心交互） =================

## 骇入抗性：系数越大耗时越久。对应设定文档的类别克制——智能体最好骇，异常生物几乎骇不动。
func hack_resist() -> float:
	var base := 1.0
	match category:
		EnemyDB.Cat.AI_CORE:
			base = 0.55
		EnemyDB.Cat.MACHINE:
			base = 0.85
		EnemyDB.Cat.HUMAN:
			base = 1.25
		EnemyDB.Cat.GHOST:
			base = 1.55
		EnemyDB.Cat.BIO:
			base = 2.30
	if is_elite:
		base *= 1.7
	return base


func can_be_hacked() -> bool:
	return not _dead and hp > 0.0


func is_hack_stunned() -> bool:
	return hack_stun_t > 0.0


## 显示名：Boss 用 become_boss() 挂的名字，其余用档案里的中文名。
func label() -> String:
	if display_name != "":
		return display_name
	return str(def.get("name", id))


## 骇入完成：按类别给出不同后果，并附带一次不能格挡的真实伤害。
func apply_hack_result() -> void:
	if not can_be_hacked():
		return
	var pos: Vector2 = global_position + Vector2(0.0, -float(def.get("h", 46.0)) * 0.55)
	var popup := "瘫痪"
	var col := Color("6fe0ff")
	var element := "emp"
	match category:
		EnemyDB.Cat.HUMAN:
			popup = "神经过载"
			col = Color("ffb347")
			poise = 0.0
		EnemyDB.Cat.GHOST:
			popup = "回响撕裂"
			col = Color("a98bf0")
			probe_mark(4.0)
		EnemyDB.Cat.BIO:
			popup = "痛觉过载"
			col = Color("e0554f")
			element = "burn"
		_:
			hack_stun_t = 3.6
	FXLite.spawn_ring(get_parent(), pos, col, 120.0, 3.5)
	FXLite.spawn_float_text(get_parent(), pos, popup, col)
	Sfx.play("hack_done", -3.0)
	Game.do_hitstop(0.09)
	Events.hack_completed.emit(self)
	take_hit({
		"amount": max_hp * 0.18 + 14.0,
		"kind": "hack",
		"element": element,
		"poise": 9999.0,
		"crit": true,
		"position": pos,
		"source_position": pos,
		"knockback": Vector2.ZERO,
	})


# ================= 主循环 =================

func _physics_process(delta: float) -> void:
	_anim_t += delta
	flash_t = maxf(0.0, flash_t - delta * 5.5)
	hp_bar_t = maxf(0.0, hp_bar_t - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	probe_mark_t = maxf(0.0, probe_mark_t - delta)

	if _dead:
		return

	if spawn_t < 1.0:
		spawn_t = minf(1.0, spawn_t + delta * 3.2)
		modulate.a = spawn_t

	_tick_status(delta)

	if hp <= 0.0:
		return

	if hack_stun_t > 0.0:
		# 被骇入瘫痪：整机停机，只保留重力与地面摩擦，不思考也不出手
		hack_stun_t = maxf(0.0, hack_stun_t - delta)
		state = State.HURT
		state_t = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
		if behavior != EnemyDB.FLYER:
			velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
		move_and_slide()
		queue_redraw()
		return

	state_t += delta
	_leg_phase += absf(velocity.x) * delta * 0.05

	_think(delta)

	if behavior != EnemyDB.FLYER:
		velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)

	move_and_slide()
	queue_redraw()


func _speed_now() -> float:
	return base_speed * clampf(1.0 - slow_amt, 0.25, 1.0)


func _tick_status(delta: float) -> void:
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_amt = 0.0
	if dot_t > 0.0:
		dot_t -= delta
		hp -= dot_dps * delta
		hp_bar_t = maxf(hp_bar_t, 0.6)
		if hp <= 0.0:
			_die()
			return
	if is_ghost and probe_mark_t > 0.0:
		# 被探测标记的幽灵体显形：额外承受伤害并常亮血条
		hp_bar_t = maxf(hp_bar_t, 0.4)


func _think(delta: float) -> void:
	# ---- 硬直 / 攻击收招 ----
	if state == State.HURT:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if state_t >= HURT_TIME:
			state = State.CHASE
			state_t = 0.0
		return

	if state == State.WINDUP:
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
		if state_t >= windup:
			_release_attack()
		return

	if state == State.RECOVER:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		if state_t >= RECOVER_TIME:
			if _combo_left > 0:
				_combo_left -= 1
				_enter_windup(0.55)
			else:
				state = State.CHASE
				state_t = 0.0
		return

	# ---- 索敌 ----
	var dist := 99999.0
	var dir := facing
	var has_target := target != null and is_instance_valid(target)
	if has_target:
		var d: Vector2 = target.global_position - global_position
		dist = absf(d.x)
		if d.x != 0.0:
			dir = 1 if d.x > 0.0 else -1
	var engaged := has_target and dist <= aggro and absf(target.global_position.y - global_position.y) < 260.0

	# ---- 炮塔：原地转向射击 ----
	if behavior == EnemyDB.TURRET:
		velocity.x = 0.0
		if engaged:
			facing = dir
			if attack_timer <= 0.0:
				_enter_windup(1.0)
		return

	# ---- 飞行单位：悬停 + 贴脸 ----
	if behavior == EnemyDB.FLYER:
		if engaged:
			facing = dir
			var desired_y: float = target.global_position.y - 96.0
			velocity.y = clampf((desired_y - global_position.y) * 2.6, -190.0, 170.0)
			var want := 0.0
			if is_ranged:
				if dist > keep_dist:
					want = _speed_now()
				elif dist < keep_dist * 0.6:
					want = -_speed_now() * 0.8
			elif dist > reach * 0.6:
				want = _speed_now()
			# 同一处陷阱：want 是大小，方向要乘 dir，否则「后撤」会变成永远向左
			velocity.x = want * float(dir)
			if dist <= reach and attack_timer <= 0.0:
				_enter_windup(1.0)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			velocity.y = clampf((_home_x * 0.0 - global_position.y - 120.0) * 1.2, -80.0, 80.0)
		return

	# ---- 地面单位 ----
	if not engaged:
		state = State.PATROL
		velocity.x = float(_patrol_dir) * _speed_now() * 0.40
		facing = _patrol_dir
		if absf(global_position.x - _home_x) > 240.0:
			_patrol_dir = -_patrol_dir
		if is_on_wall():
			_patrol_dir = -_patrol_dir
		return

	state = State.CHASE
	facing = dir
	var want2 := 0.0
	if is_ranged:
		if dist > keep_dist:
			want2 = _speed_now()
		elif dist < keep_dist * 0.55:
			want2 = -_speed_now()
	else:
		if dist > reach * 0.62:
			want2 = _speed_now()
	# want2 只是速度「大小」，方向必须再乘一次 dir。
	# 漏掉这一步地面单位会永远朝右跑，站在它左边的玩家就永远打不到、也永远打不着它。
	velocity.x = move_toward(velocity.x, want2 * float(dir), 2200.0 * delta)
	if dist <= reach and attack_timer <= 0.0:
		_enter_windup(1.0)


func _enter_windup(mult: float) -> void:
	state = State.WINDUP
	state_t = 0.0
	windup = float(def.get("windup", 0.34)) * mult
	_combo_left = maxi(0, combo - 1)
	Sfx.play_varied("enemy_alert", -14.0, 0.08)


func _release_attack() -> void:
	state = State.RECOVER
	state_t = 0.0
	attack_timer = attack_cd
	if is_ranged:
		_fire_volley()
	else:
		_melee_strike()


func _melee_strike() -> void:
	Sfx.play_varied("enemy_attack", -8.0, 0.10)
	if target == null or not is_instance_valid(target):
		return
	var d: Vector2 = target.global_position - global_position
	if absf(d.x) > reach + 20.0 or absf(d.y) > 70.0:
		return
	if not target.has_method("take_hit"):
		return
	target.take_hit({
		"amount": damage,
		"poise": 8.0,
		"kind": "melee",
		"crit": false,
		"position": target.global_position,
		"source": self,
		"source_position": global_position,
		"knockback": Vector2(float(facing) * 200.0, -90.0),
	})
	FXLite.spawn_hit_spark(get_parent(), target.global_position + Vector2(0.0, -24.0), accent, 5)


func _fire_volley() -> void:
	if target == null or not is_instance_valid(target):
		return
	Sfx.play_varied("enemy_attack", -10.0, 0.12)
	var h := float(def.get("h", 46.0))
	var origin := global_position + Vector2(float(facing) * 18.0, -h * 0.62)
	var proj_script := preload("res://scripts/units/projectile.gd")
	for i in maxi(1, burst):
		var p = proj_script.new()
		var aim: Vector2 = (target.global_position + Vector2(0.0, -22.0) - origin)
		if bool(def.get("arc", false)):
			aim += Vector2(0.0, -140.0)
		p.setup({
			"position": origin,
			"direction": aim.normalized(),
			"speed": 430.0 if not bool(def.get("arc", false)) else 520.0,
			"damage": damage,
			"poise": 5.0,
			"color": accent,
			"range": maxf(120.0, reach),
			"source": self,
			"source_position": global_position,
			"team": "enemy",
		})
		get_parent().add_child(p)


# ================= 受击 =================

## info 字段：amount / poise / kind / crit / source / source_position /
##            knockback(Vector2) / element / slow / slow_time / dot / dot_time
func take_hit(info: Dictionary) -> void:
	if _dead or hp <= 0.0:
		return

	var amount := float(info.get("amount", 10.0)) * _category_multiplier(info)
	var weak := _is_weak_spot(info)
	if weak:
		amount *= 1.5

	hp -= amount
	hp_bar_t = 3.2
	flash_t = 1.0

	var pos: Vector2 = global_position + Vector2(0.0, -float(def.get("h", 46.0)) * 0.55)
	FXLite.spawn_hit_spark(get_parent(), pos, accent, 5 if amount < 30.0 else 9)
	if bool(info.get("crit", false)) or weak:
		FXLite.spawn_damage_number(get_parent(), pos, amount, true, Color("ffe08a"))
		Sfx.play_varied("hit_crit", -4.0)
	else:
		Sfx.play_varied("hit_light" if amount < 30.0 else "hit_heavy", -8.0)

	# 姿态：剑对人形额外破姿态，姿态归零 → 硬直
	var poise_dmg := float(info.get("poise", 6.0))
	if str(info.get("kind", "")) == "sword" and category == EnemyDB.Cat.HUMAN:
		poise_dmg *= 1.5
	poise -= poise_dmg

	# 击退既可能传 Vector2，也可能被调用方写成标量；两者都要吃得下
	var kb_raw = info.get("knockback", Vector2.ZERO)
	var kb: Vector2 = kb_raw if kb_raw is Vector2 else Vector2(float(kb_raw), 0.0)
	if poise <= 0.0:
		poise = poise_max
		state = State.HURT
		state_t = 0.0
		velocity = kb
		Sfx.play_varied("hit_blocked", -6.0)
		Game.do_hitstop(0.05)
	elif is_elite:
		velocity += kb * 0.08
	else:
		velocity += kb * 0.30

	var slow := float(info.get("slow", 0.0))
	if slow > 0.0:
		slow_amt = maxf(slow_amt, slow)
		slow_t = maxf(slow_t, float(info.get("slow_time", 1.5)))
	var dot := float(info.get("dot", 0.0))
	if dot > 0.0:
		dot_dps = maxf(dot_dps, dot)
		dot_t = maxf(dot_t, float(info.get("dot_time", 3.0)))

	Events.damage_dealt.emit({
		"amount": amount,
		"position": pos,
		"target": self,
		"crit": bool(info.get("crit", false)),
		"weak": weak,
	})

	if hp <= 0.0:
		_die()


## 五类克制（对照 EnemyDB.Cat）。返回伤害倍率。
func _category_multiplier(info: Dictionary) -> float:
	var el := str(info.get("element", ""))
	var kind := str(info.get("kind", ""))
	match category:
		EnemyDB.Cat.MACHINE:
			if el == "emp":
				return 1.35
			if el == "slow":
				return 1.15
		EnemyDB.Cat.HUMAN:
			if el == "poison":
				return 1.30
			if kind == "sword":
				return 1.10
		EnemyDB.Cat.BIO:
			if el == "burn":
				return 1.30
		EnemyDB.Cat.AI_CORE:
			if el == "shock" or kind == "hack":
				return 1.40
		EnemyDB.Cat.GHOST:
			if probe_mark_t > 0.0:
				return 1.35
			return 0.35
	return 1.0


## 幽灵体在未显形时几乎打不中；显形后打中要害
func _is_weak_spot(info: Dictionary) -> bool:
	if category != EnemyDB.Cat.GHOST:
		return false
	return probe_mark_t > 0.0


func on_parried(_by: Node) -> void:
	poise = 0.0
	state = State.HURT
	state_t = 0.0
	velocity = Vector2(float(-facing) * 260.0, -120.0)
	flash_t = 1.0
	hp -= maxf(4.0, damage * 0.35)


# ================= 死亡 =================

func _die() -> void:
	if _dead:
		return
	_dead = true
	hp = 0.0
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	set_physics_process(false)

	var p := global_position + Vector2(0.0, -float(def.get("h", 46.0)) * 0.5)
	FXLite.spawn_ring(get_parent(), p, accent, 34.0 if is_elite else 22.0, 3.0)
	FXLite.spawn_hit_spark(get_parent(), p, body_color, 12 if is_elite else 7)
	Sfx.play_varied("elite_die" if is_elite else "enemy_die", -4.0)
	Game.shake(6.0 if is_elite else 2.0, 0.22)

	Events.enemy_killed.emit(self, global_position)
	_drop_loot()

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.32)
	tw.tween_callback(queue_free)


func _drop_loot() -> void:
	# 击杀回复类词条
	var run := Game.run
	if run != null:
		var kh := run.stat("kill_heal")
		if kh > 0.0:
			run.heal(kh)

	var parent := get_parent()
	if parent == null:
		return
	var pickup_script := preload("res://scripts/world/pickup.gd")
	var n := 1 if shard_value <= 4 else 2
	for i in n:
		var p = pickup_script.new()
		p.setup("shard", maxi(1, int(round(float(shard_value) / float(n)))), accent,
			global_position + Vector2(randf_range(-24.0, 24.0), -30.0))
		parent.add_child(p)
	if coin_value > 0 and randf() < 0.55:
		var c = pickup_script.new()
		c.setup("coin", coin_value, Color("e8c86a"), global_position + Vector2(randf_range(-20.0, 20.0), -34.0))
		parent.add_child(c)
	if randf() < 0.06:
		var h = pickup_script.new()
		h.setup("hp", 18, Color("e0554f"), global_position + Vector2(randf_range(-20.0, 20.0), -38.0))
		parent.add_child(h)


# ================= 绘制 =================

func _draw() -> void:
	var w := float(def.get("w", 34.0))
	var h := float(def.get("h", 46.0))
	var body := body_color
	if flash_t > 0.0:
		body = body.lerp(Color(1, 1, 1), clampf(flash_t, 0.0, 0.9))
	var dim := 1.0
	# 幽灵体未显形时半透明
	if is_ghost:
		dim = 0.92 if probe_mark_t > 0.0 else 0.34

	# 地面阴影
	if behavior != EnemyDB.FLYER:
		draw_set_transform(Vector2(0.0, 0.0), 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2(0.0, 2.0), w * 0.52, Color(0, 0, 0, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 精英光环
	if is_elite:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 3.0)
		draw_arc(Vector2(0.0, -h * 0.5), w * 0.85 + pulse * 4.0, 0.0, TAU, 28,
			Color(accent.r, accent.g, accent.b, 0.22 + pulse * 0.16), 2.0)

	match behavior:
		EnemyDB.FLYER:
			_draw_flyer(w, h, body, dim)
		EnemyDB.TURRET:
			_draw_turret(w, h, body, dim)
		EnemyDB.SWARM:
			_draw_swarm(w, h, body, dim)
		_:
			_draw_walker(w, h, body, dim)

	# 蓄力提示
	if state == State.WINDUP:
		var k := clampf(state_t / maxf(0.01, windup), 0.0, 1.0)
		draw_arc(Vector2(0.0, -h * 0.5), w * 0.7, -PI * 0.5, -PI * 0.5 + TAU * k, 24,
			Color(1.0, 0.42, 0.32, 0.85), 2.5)

	# 血条
	if (hp_bar_t > 0.0 or is_elite) and not _dead:
		var bw := maxf(40.0, w * 1.25)
		var by := -h - 13.0
		draw_rect(Rect2(-bw * 0.5, by, bw, 4.0), Color(0, 0, 0, 0.68))
		var frac := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
		draw_rect(Rect2(-bw * 0.5, by, bw * frac, 4.0), EnemyDB.category_color(category))
		if is_elite:
			draw_rect(Rect2(-bw * 0.5, by + 5.0, bw * clampf(poise / maxf(1.0, poise_max), 0.0, 1.0), 2.0),
				Color(1, 1, 1, 0.55))


func _draw_walker(w: float, h: float, body: Color, dim: float) -> void:
	var c := Color(body.r, body.g, body.b, dim)
	var leg := sin(_leg_phase * TAU) * 4.0
	# 腿
	draw_line(Vector2(-w * 0.22, -h * 0.36), Vector2(-w * 0.22 + leg, 0.0), c.darkened(0.25), 4.0)
	draw_line(Vector2(w * 0.22, -h * 0.36), Vector2(w * 0.22 - leg, 0.0), c.darkened(0.25), 4.0)
	# 躯干
	draw_rect(Rect2(-w * 0.5, -h, w, h * 0.66), c)
	draw_rect(Rect2(-w * 0.5, -h, w, h * 0.12), c.lightened(0.25))
	# 头 / 传感器
	draw_rect(Rect2(-w * 0.30, -h * 1.26, w * 0.60, h * 0.28), c.darkened(0.12))
	var eye := accent if state != State.PATROL else accent.darkened(0.35)
	draw_rect(Rect2(float(facing) * w * 0.06 - 3.0, -h * 1.17, 6.0, 4.0), eye)
	# 武器
	if not is_ranged:
		var ax := float(facing) * w * 0.52
		draw_line(Vector2(ax, -h * 0.72), Vector2(ax + float(facing) * 20.0, -h * 0.62),
			accent.darkened(0.1), 3.0)
	else:
		var gx := float(facing) * w * 0.42
		draw_line(Vector2(gx, -h * 0.70), Vector2(gx + float(facing) * 24.0, -h * 0.70),
			accent.darkened(0.2), 5.0)


func _draw_flyer(w: float, h: float, body: Color, dim: float) -> void:
	var c := Color(body.r, body.g, body.b, dim)
	var bob := sin(_anim_t * 4.0) * 2.0
	draw_rect(Rect2(-w * 0.5, -h + bob, w, h * 0.62), c)
	draw_rect(Rect2(-w * 0.22, -h - h * 0.22 + bob, w * 0.44, h * 0.24), c.darkened(0.15))
	var spin := _anim_t * 22.0
	draw_line(Vector2(-w * 0.72, -h * 0.95 + bob), Vector2(w * 0.72, -h * 0.95 + bob),
		Color(c.r, c.g, c.b, 0.5 + 0.3 * absf(sin(spin))), 2.0)
	draw_circle(Vector2(float(facing) * w * 0.18, -h * 0.72 + bob), 3.0, accent)


func _draw_turret(w: float, h: float, body: Color, dim: float) -> void:
	var c := Color(body.r, body.g, body.b, dim)
	# 底座
	var base := PackedVector2Array([
		Vector2(-w * 0.62, 0.0), Vector2(w * 0.62, 0.0),
		Vector2(w * 0.34, -h * 0.5), Vector2(-w * 0.34, -h * 0.5),
	])
	draw_colored_polygon(base, c.darkened(0.2))
	# 炮塔壳
	draw_circle(Vector2(0.0, -h * 0.66), w * 0.36, c)
	# 炮管
	var bx := float(facing) * w * 0.3
	draw_line(Vector2(bx, -h * 0.70), Vector2(bx + float(facing) * 30.0, -h * 0.70), c.lightened(0.15), 6.0)
	draw_circle(Vector2(bx + float(facing) * 30.0, -h * 0.70), 2.6,
		accent if state == State.WINDUP else accent.darkened(0.4))


func _draw_swarm(w: float, h: float, body: Color, dim: float) -> void:
	var c := Color(body.r, body.g, body.b, dim)
	var jitter := Vector2(sin(_anim_t * 18.0) * 1.6, cos(_anim_t * 21.0) * 1.6)
	var pts := PackedVector2Array([
		Vector2(0.0, -h) + jitter, Vector2(w * 0.5, 0.0) + jitter,
		Vector2(0.0, -h * 0.18) + jitter, Vector2(-w * 0.5, 0.0) + jitter,
	])
	draw_colored_polygon(pts, c)
	draw_circle(Vector2(0.0, -h * 0.6) + jitter, 2.6, accent)
	draw_line(Vector2(-w * 0.5, -h * 0.5) + jitter, Vector2(w * 0.5, -h * 0.5) + jitter,
		Color(1, 1, 1, 0.25), 1.0)

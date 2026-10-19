extends Node2D
## 游戏主控（Main.tscn 根节点）。
##
## 【它是什么】一个四状态的屏幕管理器：标题 / 安全屋 / 一局战斗 / 结算。
## 切屏时它负责拆掉旧世界、建出新世界、通知 UI 换模式。
##
## 【它不是什么】不参与任何战斗逻辑。玩家、敌人、关卡、UI 都是各自独立的脚本，
## 主控只是把它们拼起来并决定谁在场。
##
## 【三个孩子，各占一层】
## - `BackgroundLayer`（CanvasLayer, layer=-10）：雨幕霓虹氛围背景，不随相机移动
## - `World`（Node2D）：当前世界的实体，暂停时会一起停
## - `UIRoot`（CanvasLayer）：HUD 与所有界面，暂停时仍可交互
##
## 【命令行模式】
## `_ready()` 末尾会检查 `--` 之后的参数，如果带了自检开关就进对应模式并退出。
## 这些模式是**无头验证**用的（`godot --headless --path . --selfcheck`），
## 平时玩不会走这里。每个自检都在自己的区块里说明它验什么。
## 唯一例外是 `--shot`：它用真实渲染器跑一遍并存 PNG，用于确认画面没画崩。

enum Screen { TITLE, HUB, RUN, GAMEOVER }

const HubScript := preload("res://scripts/world/hub.gd")
const RunWorldScript := preload("res://scripts/world/run_world.gd")
const UIRootScript := preload("res://scripts/ui/ui_root.gd")
const AmbientScript := preload("res://scripts/world/ambient_background.gd")

var world_root: Node2D = null
var ui: UIRoot = null
var current_world: Node = null

var screen: int = Screen.TITLE
var last_banked: int = 0


## 独占全屏要主动设一次。项目设置里的 `window/size/mode` 只是窗口初始形态，
## 被外部启动方式（编辑器运行、某些 launcher）接管时可能退化成无边框窗口——
## 那种形态下 Windows 任务栏会浮在游戏画面上面。
func _force_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


## 启动流程：锁全屏 → 注册单例引用 → 建三层 → 进标题页 → 看有没有自检参数。
##
## 注意 `process_mode = PROCESS_MODE_ALWAYS`：主控自身永远运行（否则暂停时切屏代码也停了），
## 而 `world_root` 被单独压成 `PROCESS_MODE_PAUSABLE` —— 这样暂停时世界停、UI 与主控继续跑。
func _ready() -> void:
	_force_fullscreen()
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()

	# 环境背景（不随相机移动）
	var bg_layer := CanvasLayer.new()
	bg_layer.name = "BackgroundLayer"
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := AmbientScript.new()
	bg.name = "Ambient"
	bg_layer.add_child(bg)

	world_root = Node2D.new()
	world_root.name = "World"
	# Main 自己是 PROCESS_MODE_ALWAYS，子节点默认 INHERIT 会跟着永不停 —— 那会让暂停失效。
	# 显式把世界层压成 PAUSABLE：暂停时玩家、敌人、弹道、特效一起停；UI 层自己设了 ALWAYS，不受影响。
	world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_root)

	ui = UIRootScript.new()
	ui.name = "UIRoot"
	add_child(ui)

	Events.player_died.connect(_on_player_died)
	Events.hub_request_run.connect(_on_hub_request_run)

	goto_title()

	if OS.get_cmdline_user_args().has("--selfcheck"):
		_run_selfcheck()
	elif OS.get_cmdline_user_args().has("--combatcheck"):
		_run_combatcheck()
	elif OS.get_cmdline_user_args().has("--mapcheck"):
		_run_mapcheck()
	elif OS.get_cmdline_user_args().has("--bosscheck"):
		_run_bosscheck()
	elif OS.get_cmdline_user_args().has("--elementcheck"):
		_run_elementcheck()
	elif OS.get_cmdline_user_args().has("--servicecheck"):
		_run_servicecheck()
	elif OS.get_cmdline_user_args().has("--pausecheck"):
		_run_pausecheck()
	elif OS.get_cmdline_user_args().has("--hackcheck"):
		_run_hackcheck()
	elif OS.get_cmdline_user_args().has("--eventcheck"):
		_run_eventcheck()
	elif OS.get_cmdline_user_args().has("--shot"):
		_run_shots()


# ================= 截图（--shot） =================
#
# 用真实渲染器跑一遍并把关键画面存成 PNG，用于在没有人工肉眼的情况下确认画面没画崩。
# 用法：godot --path . -- --shot
# 输出目录见 SHOT_DIR。它是唯一一个「会真的渲染」的自检模式，其余都是无头逻辑验证。

const SHOT_DIR := "C:/Users/Lenovo/Desktop/gamemake/_shots"


func _run_shots() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.9).timeout
	await _shot("01_title")

	goto_hub()
	await get_tree().create_timer(1.6).timeout
	await _shot("02_hub")

	ui.open_panel("rig")
	await get_tree().create_timer(0.7).timeout
	await _shot("03_panel_rig")
	ui.close_panel()

	ui.open_panel("market")
	await get_tree().create_timer(0.7).timeout
	await _shot("04_panel_market")
	ui.close_panel()

	ui.open_panel("terminal")
	await get_tree().create_timer(0.7).timeout
	await _shot("05_panel_terminal")
	ui.close_panel()

	begin_run(12345)
	await get_tree().create_timer(1.6).timeout
	await _shot("06_run")

	# 模拟输入，验证物理 / 相机 / 动画 / 战斗是否真的动起来
	Input.action_press("move_right")
	await get_tree().create_timer(2.0).timeout
	await _shot("07_run_walk")
	await get_tree().create_timer(3.0).timeout
	Input.action_release("move_right")
	await get_tree().create_timer(0.6).timeout
	print("[SHOTS] room after walk = ", current_world.get("_current_room"))
	await _shot("08_run_walk2")

	Input.action_press("attack")
	await get_tree().create_timer(0.10).timeout
	Input.action_release("attack")
	await get_tree().create_timer(0.10).timeout
	await _shot("09_attack")

	Input.action_press("ghost")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("ghost")
	await _shot("10_ghost")
	await get_tree().create_timer(0.8).timeout
	Input.action_press("ghost")
	await get_tree().create_timer(0.2).timeout
	Input.action_release("ghost")
	await get_tree().create_timer(0.5).timeout

	Input.action_press("gun")
	await get_tree().create_timer(0.35).timeout
	Input.action_release("gun")
	await get_tree().create_timer(0.10).timeout
	await _shot("11_gun")

	Input.action_press("jump")
	await get_tree().create_timer(0.30).timeout
	Input.action_release("jump")
	await get_tree().create_timer(0.05).timeout
	await _shot("12_jump")

	# 三选一面板：进战斗房 → 清空 → 截图 → 用键盘选卡 → 确认
	print("[SHOTS] reward seq begin")
	var world: Node = current_world
	var lvl = world.get("level")
	var pc: Player = world.get("player")
	print("[SHOTS] world=", world, " lvl=", lvl, " pc=", pc)
	var combat_room: Room = null
	for rr: Room in lvl.rooms:
		if rr.kind == Room.Kind.COMBAT and rr.index > 0:
			combat_room = rr
			break
	if combat_room != null:
		print("[SHOTS] combat_room=", combat_room.index, " teleporting")
		pc.global_position = Vector2(combat_room.center().x, combat_room.floor_y - 60.0)
		pc.velocity = Vector2.ZERO
		await get_tree().create_timer(1.0).timeout
		print("[SHOTS] active_enemies=", world.get("_active_enemies").size())
		_wipe_active(world, pc)
		await get_tree().create_timer(1.3).timeout
		print("[SHOTS] before 13_reward, reward_open=", (ui.reward != null and ui.reward.is_open()))
		await _shot("13_reward")
		if ui.reward != null and ui.reward.is_open():
			ui.reward.index = 1
			await get_tree().create_timer(0.2).timeout
			await _shot("14_reward_sel")
			ui.reward.call("_confirm")
			await get_tree().create_timer(0.6).timeout
		print("[SHOTS] reward flow done: stacks=", Game.run.stacks.size(),
			" paused=", get_tree().paused)
	else:
		print("[SHOTS] WARN no combat room found")

	# Boss 房：验证具名 Boss + 专属血条
	var world3: Node = current_world
	if world3 != null:
		var lvl3 = world3.get("level")
		var p3: Player = world3.get("player")
		var boss_room: Room = null
		for r3: Room in lvl3.rooms:
			if r3.kind == Room.Kind.BOSS:
				boss_room = r3
		if boss_room != null:
			p3.global_position = Vector2(boss_room.center().x, boss_room.floor_y - 60.0)
			p3.velocity = Vector2.ZERO
			await get_tree().create_timer(1.8).timeout
			await _shot("15_boss")
			print("[SHOTS] boss bar node = ", ui.get("_boss"))
		else:
			print("[SHOTS] WARN no boss room")

	# 幽灵骇入：找一间还没打的战斗房 → 幽灵形态 → 起手 → 推进到进度中段截图
	var world4: Node = current_world
	if world4 != null:
		var lvl4 = world4.get("level")
		var p4: Player = world4.get("player")
		var hack_room: Room = null
		for r4: Room in lvl4.rooms:
			if r4.kind == Room.Kind.COMBAT and not r4.cleared:
				hack_room = r4
				break
		if hack_room != null:
			p4.global_position = Vector2(hack_room.x_start + 620.0, hack_room.floor_y - 80.0)
			p4.velocity = Vector2.ZERO
			await get_tree().create_timer(1.0).timeout
			Game.run.ge = Game.run.max_ge
			p4.call("_set_ghost", true)
			await get_tree().create_timer(0.15).timeout
			p4.call("_begin_hack")
			print("[SHOTS] hack started=", p4.call("is_hacking"),
				" need=", p4.get("hack_need"), " target=", p4.get("hack_target"))
			for i: int in 8:
				p4.call("_update_hack", 0.09)
			await _shot("16_hack")
			p4.call("_cancel_hack", "shot")
			p4.call("_set_ghost", false)
		else:
			print("[SHOTS] WARN no uncleared combat room for hack")

	print("[SHOTS] done")
	get_tree().paused = false
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png("%s/%s.png" % [SHOT_DIR, shot_name])
	print("[SHOTS] ", shot_name, " err=", err, " size=", img.get_size())


# ================= 自检（--selfcheck） =================
#
# headless 冒烟测试：把「标题 → 安全屋 → 五个面板 → 出击 → 翻层 → 死亡结算 → 回据点」
# 整条链路跑一遍，用来在没有窗口的环境里抓运行时错误。

func _run_selfcheck() -> void:
	print("[SELFCHECK] start")
	await get_tree().process_frame

	goto_hub()
	await get_tree().create_timer(0.35).timeout
	print("[SELFCHECK] hub screen=", screen, " run=", Game.run != null)

	for k in ["bench", "rig", "market", "terminal", "exit"]:
		ui.open_panel(k)
		await get_tree().process_frame
		await get_tree().process_frame
		print("[SELFCHECK] panel ", k, " rows=", ui.panel_body.get_child_count(), " title=", ui.panel_title.text)
		ui.close_panel()
		await get_tree().process_frame

	Game.coins_bank += 400
	Game.buy_shop_item("repair_kit")
	print("[SELFCHECK] bought, pending=", Game.pending_boons, " coins=", Game.coins_bank)

	begin_run(12345)
	await get_tree().create_timer(0.8).timeout
	print("[SELFCHECK] run started, floor=", Game.run.floor_index, " world=", current_world.get_class())
	print("[SELFCHECK] room=", current_world.get("_current_room"))

	current_world.call("_advance_sector")
	await get_tree().create_timer(1.8).timeout
	print("[SELFCHECK] after advance floor=", Game.run.floor_index)

	Events.player_died.emit()
	await get_tree().create_timer(2.6).timeout
	print("[SELFCHECK] after death screen=", screen, " banked=", last_banked, " shards_bank=", Game.shards_bank)

	goto_hub()
	await get_tree().create_timer(0.4).timeout
	print("[SELFCHECK] back at hub, ok")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


# ================= 战斗自检（--combatcheck） =================
#
# headless 下把战斗闭环跑一遍：进入战斗房 → 关门封锁 → 刷怪 → 双向伤害结算
# → 敌人死亡 → 房间清空 → 开门 → 碎片回收。用来抓只在战斗里才出现的运行时错误。

func _run_combatcheck() -> void:
	print("[COMBAT] start")
	await get_tree().process_frame
	begin_run(4242)
	await get_tree().create_timer(1.0).timeout

	var world := current_world
	if world == null:
		print("[COMBAT] FAIL no world")
		get_tree().quit()
		return
	var lv = world.get("level")
	var p = world.get("player")
	print("[COMBAT] rooms=", lv.rooms.size(), " player_ok=", p != null)

	var target = null
	for r in lv.rooms:
		if r.spawn_count > 0 and r.enemy_ids.size() > 0:
			target = r
			break
	if target == null:
		print("[COMBAT] FAIL no combat room in level")
		get_tree().quit()
		return
	print("[COMBAT] target index=", target.index, " kind=", target.kind_name(), " ids=", target.enemy_ids, " n=", target.spawn_count)

	p.global_position = Vector2((target.x_start + target.x_end) * 0.5, target.floor_y - 60.0)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(0.6).timeout

	var alive: Array = world.get("_active_enemies")
	var cur = world.get("_current_room")
	var cur_index := -1
	if cur != null:
		cur_index = cur.index
	print("[COMBAT] entered room=", cur_index, " spawned=", alive.size())
	if alive.is_empty():
		print("[COMBAT] FAIL no enemies spawned")
		get_tree().quit()
		return

	var e0 = alive[0]
	var nm := str(e0.name)
	var d0 = e0.get("data")
	if d0 is Dictionary:
		nm = str(d0.get("name", nm))
	print("[COMBAT] enemy0=", nm, " hp=", e0.get("hp"), "/", e0.get("max_hp"),
		" layer=", e0.collision_layer, " mask=", e0.collision_mask,
		" behavior=", e0.get("behavior"), " reach=", e0.get("reach"),
		" keep=", e0.get("keep_dist"), " aggro=", e0.get("aggro"), " ranged=", e0.get("is_ranged"))

	# 把玩家摆到第一个敌人面前，让 AI 真的追过来打（暴露寻路 / 攻击 / 投射物上的错误）
	var hp_at_spawn: float = Game.run.hp
	p.global_position = e0.global_position + Vector2(-110.0, -20.0)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(3.0).timeout
	var dvec: Vector2 = p.global_position - e0.global_position
	print("[COMBAT] after 3s face-to-face: player hp=", Game.run.hp, " (was ", hp_at_spawn, ")",
		" st=", Game.run.st, " enemy_state=", e0.get("state"),
		" dist=", dvec.length(), " dy=", dvec.y,
		" player_y=", p.global_position.y, " enemy_y=", e0.global_position.y)

	# 把玩家挪到房间另一头，等受击无敌帧走完，再单独验一次「注入伤害 → 掉血」
	p.global_position = Vector2(target.x_start + 90.0, target.floor_y - 40.0)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(1.5).timeout
	var hp_before: float = Game.run.hp
	var st_before: float = Game.run.st
	p.call("take_hit", {
		"amount": 12.0, "poise": 6.0, "kind": "melee", "crit": false,
		"position": p.global_position, "source": e0, "source_position": e0.global_position,
		"knockback": Vector2.ZERO,
	})
	await get_tree().create_timer(0.3).timeout
	print("[COMBAT] injected hit: hp ", hp_before, " -> ", Game.run.hp, " | st ", st_before, " -> ", Game.run.st)

	# 记录当前敌人，然后全部打死
	var enemies_now: Array = world.get("_active_enemies").duplicate()
	for e in enemies_now:
		if e == null or not is_instance_valid(e):
			continue
		e.call("take_hit", {
			"amount": 99999.0, "poise": 9999.0, "kind": "melee", "crit": true,
			"position": e.global_position, "source": p, "source_position": p.global_position,
			"knockback": Vector2.ZERO,
		})
	print("[COMBAT] issued lethal hits to ", enemies_now.size(), " enemies")
	await get_tree().create_timer(0.9).timeout

	var gate_layer := -1
	if cur.gate_right != null and is_instance_valid(cur.gate_right):
		gate_layer = cur.gate_right.collision_layer
	print("[COMBAT] cleared=", cur.cleared, " alive_now=", world.get("_active_enemies").size(),
		" gate_layer=", gate_layer, " shards=", Game.run.shards, " rooms_cleared=", Game.run.rooms_cleared)

	# 清空房间应该弹出三选一：这里自动选第一张，验证「弹窗 → 选择 → 写回 RunState → 恢复游戏」整条链路
	if ui.reward != null and ui.reward.is_open():
		var n: int = ui.reward.choices.size()
		var id0 := str((ui.reward.choices[0] as Dictionary).get("id", ""))
		var stacks_before: int = Game.run.stacks.size()
		print("[COMBAT] reward opened: ", n, " choices, first=", id0, " paused=", get_tree().paused)
		ui.reward.index = 0
		ui.reward.call("_confirm")
		await get_tree().create_timer(0.25).timeout
		print("[COMBAT] after pick: stacks ", stacks_before, " -> ", Game.run.stacks.size(),
			" has_", id0, "=", Game.run.stacks.has(id0), " paused=", get_tree().paused,
			" panel_open=", ui.reward.is_open())
	else:
		print("[COMBAT] FAIL reward panel did not open after clearing the room")

	# 再推进一个扇区，确认清空后的门真的能走
	var room_before: int = cur.index
	p.global_position = Vector2(cur.x_end + 70.0, cur.floor_y - 60.0)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(1.5).timeout
	var cur2 = world.get("_current_room")
	var cur2_index := -1
	if cur2 != null:
		cur2_index = cur2.index
	print("[COMBAT] walked right: room ", room_before, " -> ", cur2_index)

	await get_tree().create_timer(0.3).timeout
	print("[COMBAT] done")
	get_tree().quit()


# ================= Boss / 通关自检（--bosscheck） =================

func _wipe_active(world: Node, src: Player) -> int:
	var list: Array = world.get("_active_enemies").duplicate()
	for e in list:
		if e == null or not is_instance_valid(e):
			continue
		e.call("take_hit", {
			"amount": 999999.0, "poise": 9999.0, "kind": "melee", "crit": true,
			"position": e.global_position, "source": src, "source_position": src.global_position,
			"knockback": Vector2.ZERO,
		})
	return list.size()


func _run_bosscheck() -> void:
	print("[BOSS] start")
	begin_run(777)
	await get_tree().create_timer(0.6).timeout

	var world := current_world
	if world == null:
		print("[BOSS] FAIL no run world")
		get_tree().quit()
		return
	var lvl = world.get("level")
	var p: Player = world.get("player")
	if lvl == null or p == null:
		print("[BOSS] FAIL level/player missing")
		get_tree().quit()
		return

	var boss_room: Room = null
	for r: Room in lvl.rooms:
		if r.kind == Room.Kind.BOSS:
			boss_room = r
	if boss_room == null:
		print("[BOSS] FAIL no boss room in level")
		get_tree().quit()
		return
	print("[BOSS] room index=", boss_room.index, " ids=", boss_room.enemy_ids,
		" spawn=", boss_room.spawn_count, " floor=", Game.run.floor_index)

	# ---- 第一层：进 Boss 房、杀光，检查「不给普通词条 / 给元素模块 / 不直接通关」----
	p.global_position = Vector2(boss_room.center().x, boss_room.floor_y - 60.0)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(0.9).timeout
	var spawned := _wipe_active(world, p)
	await get_tree().create_timer(1.1).timeout
	print("[BOSS] floor0: wiped ", spawned, " | cleared=", boss_room.cleared,
		" bosses=", Game.run.bosses_killed, " floor=", Game.run.floor_index,
		" elements=", Game.run.weapon.get("elements_owned"),
		" reward_open=", (ui.reward != null and ui.reward.is_open()), " screen=", screen)

	# ---- 出口闸门：Boss 已清，走到扇区尽头应该下潜 ----
	p.global_position = Vector2(lvl.total_width - 60.0, boss_room.floor_y - 60.0)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(1.6).timeout
	print("[BOSS] walked to sector end: floor=", Game.run.floor_index, " screen=", screen)

	# ---- 最后一层：把层数顶到 MAX_FLOOR-1 再打一次，应该直接进胜利结算 ----
	var world2 := current_world
	if world2 == null:
		print("[BOSS] FAIL world gone after advance")
		get_tree().quit()
		return
	Game.run.floor_index = 2
	var lvl2 = world2.get("level")
	var p2: Player = world2.get("player")
	var last_room: Room = lvl2.rooms[lvl2.rooms.size() - 1]
	p2.global_position = Vector2(last_room.center().x, last_room.floor_y - 60.0)
	p2.velocity = Vector2.ZERO
	await get_tree().create_timer(0.9).timeout
	var spawned2 := _wipe_active(world2, p2)
	await get_tree().create_timer(1.6).timeout
	print("[BOSS] final: wiped ", spawned2, " | cleared=", last_room.cleared,
		" bosses=", Game.run.bosses_killed, " screen=", screen,
		" banked=", last_banked, " shards_bank=", Game.shards_bank)
	if screen == Screen.GAMEOVER and last_banked > 0:
		print("[BOSS] victory reached, ok")
	else:
		print("[BOSS] FAIL expected GAMEOVER with banked>0, got screen=", screen, " banked=", last_banked)
	get_tree().quit()


# ================= 事件房自检（--eventcheck） =================

func _run_eventcheck() -> void:
	print("[EVENT] start")
	begin_run(4242)
	await get_tree().create_timer(0.6).timeout

	var w = current_world
	if w == null:
		print("[EVENT] FAIL no world")
		get_tree().quit()
		return
	var lvl = w.get("level")
	var p: Player = w.get("player")
	var run := Game.run

	var kinds: Array[String] = []
	for r: Room in lvl.rooms:
		kinds.append("%d:%s" % [int(r.index), r.kind_name()])
	print("[EVENT] rooms = ", kinds)

	# 事件房不是每层都有：没有就把一间普通战斗房改造成事件房来验证
	var room: Room = null
	for r2: Room in lvl.rooms:
		if r2.kind == Room.Kind.EVENT:
			room = r2
			break
	if room == null:
		for r3: Room in lvl.rooms:
			if r3.kind == Room.Kind.COMBAT and r3.index > 0:
				r3.kind = Room.Kind.EVENT
				r3.spawn_count = 0
				r3.enemy_ids = []
				if not (r3.payload is Dictionary):
					r3.payload = {}
				room = r3
				print("[EVENT] 本层无事件房，强制把房间 %d 改造为事件房" % int(r3.index))
				break
	if room == null:
		print("[EVENT] FAIL 找不到可用房间")
		get_tree().quit()
		return

	# 先走到房间外面，再走进去，让 _enter_room 完整跑一遍
	p.global_position = Vector2(room.x_start - 220.0, room.floor_y - 60.0)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(0.4).timeout
	p.global_position = Vector2(room.center().x, room.floor_y - 60.0)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(0.7).timeout

	print("[EVENT] room=%d kind=%s payload=%s" % [
		int(room.index), room.kind_name(), str(room.payload.keys())])
	var eid := str(room.payload.get("event_id", ""))
	var ev := EventDB.get_event(eid)
	var opts: Array = ev.get("options", [])
	print("[EVENT] event=%s title=%s options=%d" % [eid, str(ev.get("title", "")), opts.size()])
	if ev.is_empty():
		print("[EVENT] FAIL 事件未生成")
		get_tree().quit()
		return

	run.coins = 500
	run.shards = 200
	run.recalc(false)
	ui.open_panel("event_node")
	await get_tree().create_timer(0.25).timeout
	print("[EVENT] panel open=%s title=%s rows=%d footer=%s" % [
		str(ui.panel_open), ui.panel_title.text, ui.panel_body.get_child_count(), ui.panel_footer.text])

	# --- 选项 0：图尔克买坐标（-60 盲区币，换一次额外三选一） ---
	room.payload["event_id"] = "turck_stall"
	room.payload["event_used"] = false
	ui.call("_rebuild_panel")
	await get_tree().create_timer(0.15).timeout
	var coins_before := run.coins
	ui.call("_do_event_option", 0)
	await get_tree().create_timer(0.5).timeout
	var reward_open := ui.reward != null and ui.reward.is_open()
	print("[EVENT] opt0: 盲区币 %d -> %d (cost 60) reward_open=%s paused=%s used=%s" % [
		coins_before, run.coins, str(reward_open), str(get_tree().paused),
		str(room.payload.get("event_used", false))])
	print("[EVENT]   %s" % ("OK 额外三选一已弹出" if (coins_before - run.coins == 60 and reward_open) else "FAIL"))
	if reward_open:
		ui.reward.call("_confirm")
		await get_tree().create_timer(0.5).timeout

	# --- 选项 0：茧化残骸（本局最大耐久 +30） ---
	room.payload["event_id"] = "cocoon_husk"
	room.payload["event_used"] = false
	var hp_before := run.max_hp
	ui.open_panel("event_node")
	await get_tree().create_timer(0.2).timeout
	ui.call("_do_event_option", 0)
	await get_tree().create_timer(0.3).timeout
	run.recalc(false)
	print("[EVENT] cocoon max_hp: %.0f -> %.0f (bonus=%.0f)  %s" % [
		hp_before, run.max_hp, run.bonus_max_hp,
		"OK" if run.max_hp > hp_before else "FAIL"])

	# --- 选项 1：记忆水面取样（+15 碎片） ---
	room.payload["event_id"] = "memory_pool"
	room.payload["event_used"] = false
	var sh_before := run.shards
	ui.open_panel("event_node")
	await get_tree().create_timer(0.2).timeout
	ui.call("_do_event_option", 1)
	await get_tree().create_timer(0.3).timeout
	print("[EVENT] memory_pool shards: %d -> %d  %s" % [
		sh_before, run.shards, "OK" if run.shards > sh_before else "FAIL"])

	# --- 选项 1：裁断信使交碎片换情报（-50 碎片 + 情报 + 额外三选一） ---
	room.payload["event_id"] = "covenant_courier"
	room.payload["event_used"] = false
	var sh2 := run.shards
	ui.open_panel("event_node")
	await get_tree().create_timer(0.2).timeout
	ui.call("_do_event_option", 1)
	await get_tree().create_timer(0.5).timeout
	var has_intel: bool = Game.intel_seen.has("intel_covenant_truth")
	print("[EVENT] courier shards: %d -> %d (cost 50) intel=%s reward_open=%s  %s" % [
		sh2, run.shards, str(has_intel), str(ui.reward != null and ui.reward.is_open()),
		"OK" if (sh2 - run.shards == 50 and has_intel) else "FAIL"])
	if ui.reward != null and ui.reward.is_open():
		ui.reward.call("_confirm")
		await get_tree().create_timer(0.4).timeout

	# --- 余额不足时选项必须被禁用 ---
	room.payload["event_id"] = "turck_stall"
	room.payload["event_used"] = false
	run.coins = 10
	ui.open_panel("event_node")
	await get_tree().create_timer(0.2).timeout
	var affordable := EventDB.can_afford(EventDB.DB["turck_stall"]["options"][0], run)
	var hint := EventDB.afford_hint(EventDB.DB["turck_stall"]["options"][0], run)
	print("[EVENT] 余额 10 时买坐标 can_afford=%s hint=%s  %s" % [
		str(affordable), hint, "OK" if not affordable else "FAIL"])
	ui.close_panel()

	print("[EVENT] done")
	get_tree().quit()


# ================= 幽灵骇入自检（--hackcheck） =================

func _run_hackcheck() -> void:
	print("[HACK] start")
	begin_run(777)
	await get_tree().create_timer(0.6).timeout

	var w = current_world
	if w == null:
		print("[HACK] FAIL no world")
		get_tree().quit()
		return
	var lvl = w.get("level")
	var p: Player = w.get("player")
	var run := Game.run

	var combat = null
	for r in lvl.get("rooms"):
		if int(r.kind) == 1 and int(r.spawn_count) > 0:
			combat = r
			break
	if combat == null:
		print("[HACK] FAIL no combat room")
		get_tree().quit()
		return
	p.global_position = Vector2(combat.x_start + 620.0, combat.floor_y - 80.0)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(1.2).timeout

	var enemies: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		enemies.append(n)
	print("[HACK] combat room=%d enemies=%d" % [int(combat.index), enemies.size()])
	if enemies.is_empty():
		print("[HACK] FAIL no enemies spawned")
		get_tree().quit()
		return
	for e in enemies:
		print("[HACK]   %s  resist=%.2f  hp=%.0f" % [
			str(e.call("label")), float(e.call("hack_resist")), float(e.get("hp"))])

	# ---- 成功路径（挑最容易骇的目标，好走「瘫痪」分支） ----
	var target = enemies[0]
	var best_resist := 999.0
	for e in enemies:
		var rr := float(e.call("hack_resist"))
		if rr < best_resist:
			best_resist = rr
			target = e
	print("[HACK] picked target = %s (resist %.2f)" % [str(target.call("label")), best_resist])
	run.ge = run.max_ge
	p.global_position = target.global_position + Vector2(90.0, -20.0)
	p.call("_set_ghost", true)
	await get_tree().create_timer(0.2).timeout
	print("[HACK] ghost=%s ge=%.0f" % [str(p.ghost_form), run.ge])

	var hp_before: float = float(target.get("hp"))
	p.call("_begin_hack")
	var started := bool(p.call("is_hacking"))
	print("[HACK] begin: hacking=%s need=%.2fs ge=%.0f" % [
		str(started), float(p.get("hack_need")), run.ge])
	if not started:
		print("[HACK] FAIL hack did not start")
		get_tree().quit()
		return

	var ticks := 0
	while bool(p.call("is_hacking")) and ticks < 80:
		p.call("_update_hack", 0.12)
		ticks += 1
	var hp_after: float = float(target.get("hp"))
	print("[HACK] done in %d ticks: stun=%s hp %.0f -> %.0f (dealt %.0f) alive=%s" % [
		ticks, str(target.call("is_hack_stunned")), hp_before, hp_after, hp_before - hp_after,
		str(target.call("is_alive"))])
	print("[HACK] %s" % ("OK damage applied" if hp_after < hp_before else "FAIL no damage"))

	# ---- 中断路径 A：脱离幽灵形态 ----
	var t2 = null
	for e in enemies:
		if is_instance_valid(e) and bool(e.call("can_be_hacked")) and e != target:
			t2 = e
			break
	if t2 == null:
		print("[HACK] (no second target for interrupt test)")
	else:
		run.ge = run.max_ge
		p.call("_set_ghost", true)
		p.global_position = t2.global_position + Vector2(90.0, -20.0)
		p.call("_begin_hack")
		var a_started := bool(p.call("is_hacking"))
		p.call("_set_ghost", false)
		p.call("_update_hack", 0.05)
		var a_broken := not bool(p.call("is_hacking"))
		print("[HACK] break by leaving ghost: started=%s broken=%s  %s" % [
			str(a_started), str(a_broken), "OK" if (a_started and a_broken) else "FAIL"])

		# ---- 中断路径 B：拉开距离 ----
		run.ge = run.max_ge
		p.call("_set_ghost", true)
		p.global_position = t2.global_position + Vector2(90.0, -20.0)
		p.call("_begin_hack")
		var b_started := bool(p.call("is_hacking"))
		p.global_position = t2.global_position + Vector2(900.0, 0.0)
		p.call("_update_hack", 0.05)
		var b_broken := not bool(p.call("is_hacking"))
		print("[HACK] break by distance: started=%s broken=%s  %s" % [
			str(b_started), str(b_broken), "OK" if (b_started and b_broken) else "FAIL"])

		# ---- 中断路径 C：能量耗尽 ----
		p.global_position = t2.global_position + Vector2(90.0, -20.0)
		run.ge = 30.0
		p.call("_begin_hack")
		var c_started := bool(p.call("is_hacking"))
		var guard := 0
		while bool(p.call("is_hacking")) and guard < 80:
			p.call("_update_hack", 0.12)
			guard += 1
		print("[HACK] break by energy: started=%s ge=%.0f ghost=%s  %s" % [
			str(c_started), run.ge, str(p.ghost_form),
			"OK" if (c_started and not bool(p.call("is_hacking"))) else "FAIL"])
		p.call("_set_ghost", false)

	print("[HACK] done")
	get_tree().quit()


# ================= 暂停自检（--pausecheck） =================

func _run_pausecheck() -> void:
	print("[PAUSE] start")
	goto_hub()
	await get_tree().create_timer(0.4).timeout
	var p: Player = null
	var w = current_world
	if w != null:
		p = w.get("player")
	print("[PAUSE] hub: ui.paused=", ui.paused, " tree.paused=", get_tree().paused,
		" player=", (p != null))

	# 暂停中按住右键，玩家不该挪动
	if p != null:
		Input.action_press("move_right")
		ui.call("toggle_pause")
		await get_tree().create_timer(0.05).timeout
		var x0: float = p.global_position.x
		await get_tree().create_timer(0.45).timeout
		var x1: float = p.global_position.x
		Input.action_release("move_right")
		print("[PAUSE] paused: ui.paused=", ui.paused, " tree.paused=", get_tree().paused,
			" layer=", ui.pause_layer.visible, " rows=", ui.pause_box.get_child_count(),
			" | player x ", snappedf(x0, 0.1), " -> ", snappedf(x1, 0.1),
			"  ", ("OK (frozen)" if absf(x1 - x0) < 0.5 else "FAIL (kept moving)"))
	else:
		print("[PAUSE] FAIL no player in hub")

	ui.call("set_paused", false)
	await get_tree().create_timer(0.1).timeout
	print("[PAUSE] resumed: ui.paused=", ui.paused, " tree.paused=", get_tree().paused,
		" layer=", ui.pause_layer.visible)

	# 出击途中同样能暂停，且面板内容不同
	begin_run(31)
	await get_tree().create_timer(0.5).timeout
	ui.call("toggle_pause")
	await get_tree().create_timer(0.1).timeout
	print("[PAUSE] in run: ui.paused=", ui.paused, " tree.paused=", get_tree().paused,
		" rows=", ui.pause_box.get_child_count(), " mode=", ui.mode)
	ui.call("set_paused", false)
	await get_tree().create_timer(0.1).timeout
	print("[PAUSE] in run resumed: ui.paused=", ui.paused, " tree.paused=", get_tree().paused)

	# 切场景会自动解除暂停
	ui.call("toggle_pause")
	await get_tree().create_timer(0.1).timeout
	var was_paused: bool = ui.paused
	goto_hub()
	await get_tree().create_timer(0.3).timeout
	print("[PAUSE] switch screen while paused(", was_paused, ") -> ui.paused=", ui.paused,
		" tree.paused=", get_tree().paused,
		"  ", ("OK" if not get_tree().paused else "FAIL (still frozen)"))

	print("[PAUSE] done")
	get_tree().quit()


# ================= 局内服务房自检（--servicecheck） =================

func _run_servicecheck() -> void:
	print("[SVC] start")
	begin_run(777)
	await get_tree().create_timer(0.4).timeout
	var run := Game.run
	run.coins = 120
	var world := current_world
	if world == null:
		print("[SVC] FAIL no world")
		get_tree().quit()
		return

	for k in [Room.Kind.SHOP, Room.Kind.REST]:
		var r := Room.new()
		r.kind = k
		r.index = 3
		r.x_start = 0.0
		r.x_end = 900.0
		r.floor_y = 0.0
		r.ceiling_y = -560.0
		r.payload = {}
		world.call("_populate_service_room", r)
		var n = r.payload.get("service_node")
		var ok: bool = n != null and is_instance_valid(n)
		print("[SVC] ", r.kind_name(), " room -> node=", ("OK kind=" + str(n.kind)) if ok else "MISSING",
			" at=", (n.position if ok else Vector2.ZERO),
			" prompt=", (n.prompt() if ok else "-"))
		# 重复调用不应该再生成第二个
		world.call("_populate_service_room", r)
		print("[SVC]   idempotent -> ", "OK" if r.payload.get("service_node") == n else "DUPLICATED")

	# 局内商店面板
	ui.open_panel("field_market")
	await get_tree().create_timer(0.15).timeout
	print("[SVC] panel field_market rows=", ui.panel_body.get_child_count(), " title=", ui.panel_title.text)
	var hp_before: float = run.hp
	run.hp = 40.0
	hp_before = run.hp
	var coins_before: int = run.coins
	ui.call("_buy_field_item", "field_kit")
	await get_tree().create_timer(0.1).timeout
	print("[SVC] buy field_kit: hp ", hp_before, " -> ", run.hp,
		" | coins ", coins_before, " -> ", run.coins)
	if run.hp <= hp_before:
		print("[SVC] FAIL heal item did nothing")
	# 余额不足应该拒绝
	run.coins = 5
	var hp2: float = run.hp
	ui.call("_buy_field_item", "field_kit")
	print("[SVC] buy with 5 coins: hp ", hp2, " -> ", run.hp, " coins=", run.coins,
		" | ", "OK (refused)" if run.hp == hp2 else "FAIL (bought anyway)")
	ui.close_panel()

	# 维修节点面板
	ui.open_panel("rest_node")
	await get_tree().create_timer(0.15).timeout
	print("[SVC] panel rest_node rows=", ui.panel_body.get_child_count(), " title=", ui.panel_title.text)
	ui.close_panel()

	print("[SVC] done")
	get_tree().quit()


# ================= 铳械元素自检（--elementcheck） =================

func _hit_amount(enemy_id: String, element: String) -> float:
	var e := Enemy.new()
	e.setup(EnemyDB.get_enemy(enemy_id), 0, 1.0, 1.0)
	var before: float = e.hp
	e.take_hit({
		"amount": 10.0, "poise": 0.0, "kind": "projectile", "crit": false,
		"element": element, "position": Vector2.ZERO, "source": null,
		"source_position": Vector2.ZERO, "knockback": Vector2.ZERO,
	})
	var dealt: float = before - e.hp
	e.free()
	return dealt


func _run_elementcheck() -> void:
	print("[ELEM] start")
	var run := Game.start_run(4242)
	print("[ELEM] initial: element=", run.weapon.get("gun_element"),
		" owned=", run.weapon.get("elements_owned"))
	var cur := run.current_element()
	print("[ELEM] current: id=", cur.get("id", "<MISSING>"), " name=", cur.get("name", "?"),
		" damage=", cur.get("damage"), " shots=", cur.get("shots"), " heat=", cur.get("heat"))

	# 强制解锁多个模块，验证切换链（实际游戏中由 Boss 奖励解锁）
	run.weapon["elements_owned"] = ["basic", "emp", "burn", "slow", "shock"]
	for eid: String in ["emp", "burn", "slow", "shock", "basic"]:
		run.set_element(eid)
		var c := run.current_element()
		var ok: bool = str(c.get("id", "")) == eid
		print("[ELEM] set ", eid, " -> id=", c.get("id", "<MISSING>"),
			" shots=", c.get("shots"), " heat=", c.get("heat"), " ok=", ok)

	# 五类克制（表 8-1）：同一发 10 点伤害，元素不同结果应该不同
	var basic_d := _hit_amount("splitter_drone", "basic")
	var emp_d := _hit_amount("splitter_drone", "emp")
	var burn_d := _hit_amount("splitter_drone", "burn")
	print("[ELEM] vs MACHINE splitter_drone: basic=", basic_d, " emp=", emp_d,
		" (x", snappedf(emp_d / maxf(0.001, basic_d), 0.01), ") burn=", burn_d)

	var human_basic := _hit_amount("offnet_mob", "basic")
	var human_poison := _hit_amount("offnet_mob", "poison")
	print("[ELEM] vs HUMAN offnet_mob: basic=", human_basic, " poison=", human_poison,
		" (x", snappedf(human_poison / maxf(0.001, human_basic), 0.01), ")")

	var bio_basic := _hit_amount("cable_parasite", "basic")
	var bio_burn := _hit_amount("cable_parasite", "burn")
	print("[ELEM] vs BIO cable_parasite: basic=", bio_basic, " burn=", bio_burn,
		" (x", snappedf(bio_burn / maxf(0.001, bio_basic), 0.01), ")")

	# 整条链：玩家真的开一枪，弹道上必须带着 element
	begin_run(99)
	await get_tree().create_timer(0.5).timeout
	var world := current_world
	var p: Player = world.get("player")
	if p != null:
		Game.run.weapon["elements_owned"] = ["basic", "emp"]
		Game.run.set_element("emp")
		var before_n: int = p.get_parent().get_child_count()
		p.call("_fire_projectiles", Game.run.current_element())
		await get_tree().create_timer(0.1).timeout
		var found := 0
		for c in p.get_parent().get_children():
			if c is Projectile and str(c.get("element")) == "emp":
				found += 1
		print("[ELEM] fired with emp: projectiles carrying element=", found,
			" (children before=", before_n, ")")
		if found <= 0:
			print("[ELEM] FAIL projectile did not carry element id")

	print("[ELEM] done")
	get_tree().quit()


# ================= 地图自检（--mapcheck） =================
#
# 证明「每局地图都不一样」确实成立：不同种子各生成一层，对比房间宽度序列 / 房间类型 / 敌人总数。
# 同时验证同一颗种子必定复现同一张图（方便复现 bug 和分享种子）。

func _run_mapcheck() -> void:
	print("[MAP] start")
	await get_tree().process_frame
	var sigs := {}
	var seeds: Array[int] = [11, 22, 33, 44, 55]
	for s: int in seeds:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var lv := Level.new()
		lv.generate(0, rng)
		var widths: Array = []
		var kinds: Array = []
		var enemies := 0
		var plats := 0
		for r in lv.rooms:
			widths.append(int(r.x_end - r.x_start))
			kinds.append(r.kind_name())
			enemies += r.spawn_count
			plats += r.platforms.size()
		sigs["%s|%s|%d" % [str(widths), str(kinds), enemies]] = true
		print("[MAP] seed=", s, " rooms=", lv.rooms.size(), " widths=", widths)
		print("[MAP]      kinds=", kinds, " enemies=", enemies, " platforms=", plats, " theme=", lv.theme_name())
		lv.free()
	print("[MAP] distinct layouts=", sigs.size(), "/", seeds.size())

	# 同一颗种子必须复现同一张图
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 777
	var la := Level.new()
	la.generate(0, rng_a)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 777
	var lb := Level.new()
	lb.generate(0, rng_b)
	var same := la.rooms.size() == lb.rooms.size()
	var mismatch := ""
	if same:
		for i in la.rooms.size():
			var wa := int(la.rooms[i].x_end - la.rooms[i].x_start)
			var wb := int(lb.rooms[i].x_end - lb.rooms[i].x_start)
			if wa != wb:
				same = false
				mismatch = "room %d: %d vs %d" % [i, wa, wb]
				break
	print("[MAP] same seed reproduces layout: ", same, " ", mismatch)
	la.free()
	lb.free()

	await get_tree().create_timer(0.2).timeout
	print("[MAP] done")
	get_tree().quit()


# ================= 屏幕切换 =================
#
# 【统一套路】每个 goto_* 都是同一套三步：
#   1. `_clear_world()` —— 拆掉旧世界（顺便把暂停与 time_scale 复位）
#   2. 设 `screen` 与构建新世界，挂到 `world_root` 下
#   3. 通知 UI 换模式（`ui.show_title()` / `ui.show_hud()` / …）
# 新增一个屏幕时照这个顺序抄，别漏第 3 步 —— 否则 UI 会停在上一屏。
#
# 【run 的所有权】`Game.run` 是单例字段，不归世界所有。
# - `begin_run()`   由 `Game.start_run()` 新建
# - `resume_run()`  由 `Game.prepare_resume()` 从存档重建
# - `goto_hub()`    显式置 null（此时已结算完毕）
# 忘了置 null 的话，据点里会残留上一局的构筑，HUD 也会显示错的数值。

func _clear_world() -> void:
	for child in world_root.get_children():
		child.queue_free()
	current_world = null
	get_tree().paused = false
	Engine.time_scale = 1.0


func goto_title() -> void:
	_clear_world()
	screen = Screen.TITLE
	ui.show_title()


## 放弃本局：不结算本次收益，清掉续关存档后回安全屋。
## 和 goto_hub() 分开，是因为只有这里需要动 run 与存档。
func abandon_run() -> void:
	Game.abandon_run()
	goto_hub()


func goto_hub() -> void:
	_clear_world()
	# 上一局的 run 在这里作废；碎片已在 end_run() 结算入库，不能重复计入
	Game.run = null
	screen = Screen.HUB
	Game.ensure_hub_state()
	var hub := HubScript.new()
	hub.name = "Hub"
	world_root.add_child(hub)
	current_world = hub
	ui.show_hub()


func begin_run(seed_value: int = 0) -> void:
	_clear_world()
	screen = Screen.RUN
	Game.start_run(seed_value)
	var w := RunWorldScript.new()
	w.name = "RunWorld"
	world_root.add_child(w)
	current_world = w
	ui.show_hud()


## 从续关存档继续：重建 RunState 与地图，玩家落回保存时所在房间的入口。
## 不走 start_run()，所以不会清掉刚读出来的存档，也不重复计一次「出击」。
func resume_run() -> void:
	if not Game.prepare_resume():
		Events.toast.emit("没有可继续的存档", UITheme.TEXT_DIM)
		return
	_clear_world()
	screen = Screen.RUN
	var w := RunWorldScript.new()
	w.name = "RunWorld"
	world_root.add_child(w)
	current_world = w
	ui.show_hud()


func goto_gameover(victory: bool, banked: int) -> void:
	_clear_world()
	screen = Screen.GAMEOVER
	last_banked = banked
	ui.show_gameover(victory, banked)


func set_controls_enabled(v: bool) -> void:
	if current_world != null and is_instance_valid(current_world) and current_world.has_method("set_controls_enabled"):
		current_world.set_controls_enabled(v)


# ================= 事件 =================

func _on_hub_request_run() -> void:
	begin_run(randi())


func _on_player_died() -> void:
	if screen != Screen.RUN:
		return
	await get_tree().create_timer(1.5).timeout
	if screen != Screen.RUN:
		return
	var banked := Game.end_run(false)
	Game.run = null
	goto_gameover(false, banked)

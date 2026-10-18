class_name UIRoot
extends CanvasLayer
## 全局 UI：标题 / 据点 HUD / 局内 HUD / 结算，以及据点面板（长椅、改造台、黑市、终端、出击）。
##
## 大部分仍走代码构建（便于 diff 与 headless 校验）；标题页已迁移到
## `ui/scenes/title.tscn`，由 `ui/scripts/title.gd` 驱动，可单独预览。

enum Mode { NONE, TITLE, HUB, RUN, GAMEOVER }

const TITLE_SCENE := preload("res://ui/scenes/title.tscn")
const PAUSE_SCENE := preload("res://ui/scenes/pause_menu.tscn")

const PANEL_W := 880.0
const PANEL_H := 540.0

var mode: int = Mode.NONE
var player: Node = null

var root: Control
var hud: HudLayer
var interact_label: Label

var banner_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var banner_timer: float = 0.0

var subtitle_label: Label
var subtitle_timer: float = 0.0

var toast_box: VBoxContainer

var title_layer: Control
var gameover_layer: Control
var gameover_title: Label
var gameover_body: VBoxContainer

var panel_layer: Control
var panel_title: Label
var panel_body: VBoxContainer
var panel_footer: Label
var panel_kind: String = ""
var panel_open: bool = false
var reward: RewardChoice = null
var _boss: Node = null

var paused: bool = false
var pause_layer: Control

var _t: float = 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Events.banner.connect(_on_banner)
	Events.subtitle.connect(_on_subtitle)
	Events.hack_progress.connect(_on_hack_progress)
	Events.toast.connect(_on_toast)
	Events.player_spawned.connect(_on_player_spawned)
	Events.hub_interact.connect(_on_hub_interact)
	Events.reward_choices_offered.connect(_on_reward_choices)
	Events.boss_started.connect(_on_boss_started)
	Events.boss_defeated.connect(_on_boss_defeated)


# ================= 构建 =================

func _build() -> void:
	root = Control.new()
	root.name = "UIRootControl"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	hud = HudLayer.new()
	hud.name = "Hud"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	root.add_child(hud)

	interact_label = UITheme.label("", 18, UITheme.TEXT_BRIGHT)
	interact_label.name = "InteractHint"
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_label.offset_left = -440.0
	interact_label.offset_right = 440.0
	interact_label.offset_top = -168.0
	interact_label.offset_bottom = -134.0
	interact_label.modulate.a = 0.0
	interact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(interact_label)

	banner_box = VBoxContainer.new()
	banner_box.name = "BannerBox"
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.offset_left = -520.0
	banner_box.offset_right = 520.0
	banner_box.offset_top = 112.0
	banner_box.offset_bottom = 212.0
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.add_theme_constant_override("separation", 2)
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.modulate.a = 0.0
	root.add_child(banner_box)

	banner_title = UITheme.label("", 46, UITheme.TEXT_BRIGHT)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = UITheme.label("", 19, UITheme.TEXT_DIM)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_title)
	banner_box.add_child(banner_sub)

	subtitle_label = UITheme.label("", 19, UITheme.TEXT_BRIGHT)
	subtitle_label.name = "Subtitle"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle_label.offset_left = -500.0
	subtitle_label.offset_right = 500.0
	subtitle_label.offset_top = -110.0
	subtitle_label.offset_bottom = -46.0
	subtitle_label.modulate.a = 0.0
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(subtitle_label)

	toast_box = VBoxContainer.new()
	toast_box.name = "ToastBox"
	toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast_box.offset_left = -430.0
	toast_box.offset_right = -28.0
	toast_box.offset_top = 130.0
	toast_box.offset_bottom = 460.0
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)

	_build_panel()
	_build_title()
	_build_gameover()
	_build_reward()
	_build_pause()


func _build_panel() -> void:
	panel_layer = Control.new()
	panel_layer.name = "PanelLayer"
	panel_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_layer.visible = false
	root.add_child(panel_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.045, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_layer.add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	frame.add_theme_stylebox_override("panel", UITheme.panel_style(Color("10131bf2"), UITheme.PANEL_LINE, 5, 1))
	center.add_child(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	frame.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	panel_title = UITheme.label("", 26, UITheme.TEXT_BRIGHT)
	col.add_child(panel_title)
	col.add_child(UITheme.divider(UITheme.PANEL_LINE, 1))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", 8)
	scroll.add_child(panel_body)

	col.add_child(UITheme.divider(UITheme.PANEL_LINE, 1))
	panel_footer = UITheme.label("", 15, UITheme.TEXT_DIM)
	col.add_child(panel_footer)


func _build_title() -> void:
	var t: Control = TITLE_SCENE.instantiate()
	title_layer = t
	title_layer.name = "TitleLayer"
	root.add_child(title_layer)
	# 标题页只发信号：进安全屋 / 出击 / 清档在这里翻译成动作。
	# 场景本身不认识 Game / Sfx / Events，可以脱离游戏单独预览。
	title_layer.connect("action", _on_title_action)
	title_layer.connect("hover", func(_id: String) -> void: Sfx.play("ui_move", -8.0))


func _on_title_action(id: String) -> void:
	match id:
		"goto_hub":
			Sfx.play("ui_confirm")
			goto_screen("goto_hub")
		"begin_run":
			Sfx.play("ui_confirm")
			goto_screen("begin_run", randi())
		"wipe_save":
			Game.reset_save()
			Events.toast.emit("存档已清除", UITheme.RED)
			Sfx.play("ui_deny")


func _build_gameover() -> void:
	gameover_layer = Control.new()
	gameover_layer.name = "GameoverLayer"
	gameover_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameover_layer.visible = false
	root.add_child(gameover_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameover_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameover_layer.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	gameover_title = UITheme.label("", 60, UITheme.RED)
	gameover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(gameover_title)

	gameover_body = VBoxContainer.new()
	gameover_body.add_theme_constant_override("separation", 6)
	col.add_child(gameover_body)

	col.add_child(UITheme.spacer(20))
	var b := _mk_button("返 回 安 全 屋", UITheme.CYAN, func():
		Sfx.play("ui_confirm")
		goto_screen("goto_hub")
	)
	b.custom_minimum_size = Vector2(260, 42)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)


# ================= 屏幕状态 =================

func show_title() -> void:
	set_paused(false)
	mode = Mode.TITLE
	title_layer.visible = true
	gameover_layer.visible = false
	panel_layer.visible = false
	panel_open = false
	hud.visible = false
	interact_label.modulate.a = 0.0
	title_layer.call("set_info", "已出击 %d 次 · 最长下潜 %d 扇区 · 织网碎片 %d" % [
		int(Game.stats.get("runs", 0)),
		int(Game.stats.get("best_floor", 0)),
		Game.shards_bank,
	])
	_focus_first_button()


func show_hub() -> void:
	set_paused(false)
	mode = Mode.HUB
	title_layer.visible = false
	gameover_layer.visible = false
	hud.visible = true
	_release_ui_focus()


func show_hud() -> void:
	set_paused(false)
	mode = Mode.RUN
	title_layer.visible = false
	gameover_layer.visible = false
	hud.visible = true
	_release_ui_focus()


func show_gameover(victory: bool, banked: int) -> void:
	set_paused(false)
	mode = Mode.GAMEOVER
	title_layer.visible = false
	hud.visible = false
	gameover_layer.visible = true
	gameover_title.text = "断 层 贯 通" if victory else "织 网 中 断"
	gameover_title.add_theme_color_override("font_color", UITheme.CYAN if victory else UITheme.RED)
	for c in gameover_body.get_children():
		c.queue_free()
	gameover_body.add_child(_center_label("带回织网碎片   %d" % banked, 22, UITheme.GOLD))
	gameover_body.add_child(_center_label("本次下潜   %d 扇区" % (int(Game.stats.get("best_floor", 1))), 17, UITheme.TEXT_DIM))
	gameover_body.add_child(_center_label("累计出击   %d 次" % int(Game.stats.get("runs", 0)), 17, UITheme.TEXT_DIM))
	_release_ui_focus()
	_focus_first_button()


func _center_label(text: String, size: int, color: Color) -> Label:
	var l := UITheme.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## 通过 call() 调用主控的屏幕切换（main 的静态类型是 Node，直接调用无法通过解析）
func goto_screen(method: String, arg = null) -> void:
	if Game.main == null or not Game.main.has_method(method):
		return
	if arg == null:
		Game.main.call(method)
	else:
		Game.main.call(method, arg)


# ================= 面板 =================

func _on_hub_interact(kind: String, _source: Node) -> void:
	open_panel(kind)


## 只在出击途中才会出现的面板（局内售货机 / 维修节点）
const RUN_PANELS := ["field_market", "rest_node", "event_node"]


func open_panel(kind: String) -> void:
	# 据点面板只在安全屋开，局内服务面板只在出击途中开
	var is_run_panel := RUN_PANELS.has(kind)
	if is_run_panel and mode != Mode.RUN:
		return
	if not is_run_panel and mode != Mode.HUB:
		return
	panel_kind = kind
	panel_open = true
	panel_layer.visible = true
	_set_player_controls(false)
	Sfx.play("terminal")
	if kind == "exit":
		Sfx.play("door_open")
	_rebuild_panel()


func close_panel() -> void:
	if not panel_open:
		return
	panel_open = false
	panel_layer.visible = false
	Sfx.play("ui_cancel")
	_set_player_controls(true)
	_release_ui_focus()
	Events.hub_panel_closed.emit(panel_kind)
	panel_kind = ""


func _set_player_controls(v: bool) -> void:
	if Game.main != null and Game.main.has_method("set_controls_enabled"):
		Game.main.call("set_controls_enabled", v)


func _clear_body() -> void:
	for c in panel_body.get_children():
		panel_body.remove_child(c)
		c.queue_free()


func _rebuild_panel() -> void:
	_clear_body()
	match panel_kind:
		"bench": _build_bench()
		"rig": _build_rig()
		"market": _build_market()
		"terminal": _build_terminal()
		"exit": _build_exit()
		"field_market": _build_field_market()
		"rest_node": _build_rest_node()
		"event_node": _build_event_node()
		_: _build_unknown()
	_focus_first_button()


# ---------- 事件房：未登记信号源 ----------

func _build_event_node() -> void:
	var run := Game.run
	if run == null:
		_build_unknown()
		return
	var room := _current_service_room()
	var eid := ""
	var used := false
	if room != null and room.payload is Dictionary:
		eid = str(room.payload.get("event_id", ""))
		used = bool(room.payload.get("event_used", false))
	var ev := EventDB.get_event(eid)
	if ev.is_empty():
		_build_unknown()
		return

	panel_title.text = str(ev.get("title", "未登记信号源"))
	panel_body.add_child(UITheme.label(str(ev.get("subtitle", "")), 15, UITheme.VIOLET))
	panel_body.add_child(UITheme.spacer(4))
	panel_body.add_child(UITheme.rich("[color=#a98bf0]%s[/color]：[i]%s[/i]" % [
		str(ev.get("speaker", "")), str(ev.get("line", ""))], 17))
	panel_body.add_child(UITheme.divider(Color("1b2130"), 1))
	panel_body.add_child(UITheme.spacer(2))

	if used:
		panel_body.add_child(UITheme.label("信号已经断开，只剩下载波噪声。", 16, UITheme.TEXT_DIM))
		panel_body.add_child(_mk_button("离开", UITheme.PANEL_LINE, func(): close_panel()))
		panel_footer.text = "信号源已静默"
		return

	var options: Array = ev.get("options", [])
	for i: int in options.size():
		var opt: Dictionary = options[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		info.add_child(UITheme.label("%d. %s" % [i + 1, str(opt.get("label", ""))], 17, UITheme.TEXT_BRIGHT))
		var hint := EventDB.afford_hint(opt, run)
		var desc := str(opt.get("desc", ""))
		if hint != "":
			desc = "%s　（%s）" % [desc, hint]
		info.add_child(UITheme.label(desc, 14, UITheme.RED if hint != "" else UITheme.TEXT_DIM))
		row.add_child(info)
		var idx := i
		var btn := _mk_button("选择", UITheme.VIOLET, func(): _do_event_option(idx))
		btn.disabled = not EventDB.can_afford(opt, run)
		btn.custom_minimum_size = Vector2(96, 0)
		row.add_child(btn)
		panel_body.add_child(row)
		panel_body.add_child(UITheme.divider(Color("1b2130"), 1))

	panel_body.add_child(_mk_button("什么都不做（Esc）", UITheme.PANEL_LINE, func(): close_panel()))
	panel_footer.text = "未登记信号源 · 接入是单向的"


func _do_event_option(idx: int) -> void:
	var run := Game.run
	var room := _current_service_room()
	if run == null or room == null or not (room.payload is Dictionary):
		return
	var ev := EventDB.get_event(str(room.payload.get("event_id", "")))
	if ev.is_empty():
		close_panel()
		return
	var options: Array = ev.get("options", [])
	if idx < 0 or idx >= options.size():
		return
	var opt: Dictionary = options[idx]
	if not EventDB.can_afford(opt, run):
		Sfx.play("ui_deny")
		return

	# 1) 代价
	if opt.has("cost_coins"):
		run.coins = maxi(0, run.coins - int(opt["cost_coins"]))
	if opt.has("cost_shards"):
		run.shards = maxi(0, run.shards - int(opt["cost_shards"]))

	# 2) 附加收益（与主效果独立，可以同时写在一条选项里）
	if opt.has("shards"):
		run.add_shards(int(opt["shards"]))
	if opt.has("coins"):
		run.add_coins(int(opt["coins"]))
	if opt.has("pollution"):
		var pv := float(opt["pollution"])
		if pv >= 0.0:
			run.add_pollution(pv)
		else:
			run.reduce_pollution(-pv)
	if bool(opt.get("heal_full", false)):
		run.heal(run.max_hp)
	if opt.has("consumable"):
		var ck := str(opt["consumable"])
		var held := int(run.consumables.get(ck, 0))
		run.consumables[ck] = mini(RunState.CONSUMABLE_CAP, held + 1)

	# 3) 主效果
	var note := ""
	var effect := str(opt.get("effect", EventDB.OPT_NONE))
	if effect == EventDB.OPT_SHARDS:
		var amt := int(opt.get("amount", 0))
		run.add_shards(amt)
		note = "回收织网碎片 ×%d" % amt
	elif effect == EventDB.OPT_COINS:
		var amt2 := int(opt.get("amount", 0))
		run.add_coins(amt2)
		note = "盲区币 +%d" % amt2
	elif effect == EventDB.OPT_HEAL:
		run.heal(float(opt.get("amount", 20)))
		note = "外壳已修补"
	elif effect == EventDB.OPT_MAX_HP:
		var add := float(opt.get("amount", 0.0))
		run.bonus_max_hp += add
		run.recalc(false)
		Events.player_hp_changed.emit(run.hp, run.max_hp)
		note = "外壳上限 +%d" % int(add)
	elif effect == EventDB.OPT_POLLUTION:
		note = "污染已压制" if float(opt.get("pollution", 0.0)) < 0.0 else "污染上升"
	elif effect == EventDB.OPT_CONSUMABLE:
		note = "补给已入包"
	elif effect == EventDB.OPT_INTEL:
		if Game.add_intel(str(opt.get("intel", ""))):
			note = "新情报已归档"
		else:
			note = "这段情报你已经解码过了"
	elif effect == EventDB.OPT_EXTRA_REWARD:
		note = "改写机会 +1"
	else:
		note = str(opt.get("label", ""))
	if note == "":
		note = str(opt.get("label", ""))

	room.payload["event_used"] = true
	Sfx.play("ui_confirm")
	Events.toast.emit(note, UITheme.VIOLET)

	# 4) 额外一次三选一：把事件面板关掉，走正常的奖励流程
	var wants_extra := effect == EventDB.OPT_EXTRA_REWARD or bool(opt.get("extra_reward", false))
	if wants_extra:
		close_panel()
		var choices := UpgradeDB.roll_choices(run.rng, 3, run.stacks, run.floor_index)
		if not choices.is_empty():
			run.pending_choice = choices
			Events.reward_choices_offered.emit(choices)
		return

	_rebuild_panel()


# ---------- 局内服务房：自动售货机 / 维修节点 ----------

## 局内商店。与据点黑市不同，这里只花本局捡到的 run.coins，买完立刻生效。
const FIELD_ITEMS := {
	"field_kit":   {"name": "现场修理包", "desc": "立刻回复 45 耐久",   "price": 40},
	"field_cell":  {"name": "锚定电池",   "desc": "立刻回满幽灵能量",   "price": 35},
	"field_shard": {"name": "碎片缓存",   "desc": "立刻获得 30 织网碎片", "price": 25},
}


func _current_service_room() -> Room:
	var m := Game.main
	if m == null:
		return null
	var w = m.get("current_world")
	if w == null or not w.has_method("current_room"):
		return null
	var r = w.call("current_room")
	if r is Room:
		return r
	return null


func _build_field_market() -> void:
	var run := Game.run
	if run == null:
		_build_unknown()
		return
	panel_title.text = "自动售货机 · 局内结算"
	panel_body.add_child(UITheme.rich("[color=#7d8899]它还在营业，尽管店主已经很久没来补过货。[/color]", 16))
	panel_body.add_child(UITheme.label("携带盲区币：%d" % run.coins, 18, UITheme.GOLD))
	panel_body.add_child(UITheme.spacer(4))

	for key: String in FIELD_ITEMS.keys():
		var d: Dictionary = FIELD_ITEMS[key]
		var price := int(d["price"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		info.add_child(UITheme.label(str(d["name"]), 17, UITheme.TEXT_BRIGHT))
		info.add_child(UITheme.label("%s（%d 盲区币）" % [str(d["desc"]), price], 14, UITheme.TEXT_DIM))
		row.add_child(info)
		var k := key
		var buy := _mk_button("取货", UITheme.GOLD, func(): _buy_field_item(k))
		buy.disabled = run.coins < price
		buy.custom_minimum_size = Vector2(96, 0)
		row.add_child(buy)
		panel_body.add_child(row)
		panel_body.add_child(UITheme.divider(Color("1b2130"), 1))

	panel_body.add_child(UITheme.rich("[color=#7d8899]这里只收现场捡到的币，带不出织网。[/color]", 15))
	panel_body.add_child(_mk_button("离开", UITheme.PANEL_LINE, func(): close_panel()))
	panel_footer.text = "售货机不找零"


func _buy_field_item(key: String) -> void:
	var run := Game.run
	if run == null:
		return
	var d: Dictionary = FIELD_ITEMS.get(key, {})
	var price := int(d.get("price", 0))
	if run.coins < price:
		Sfx.play("ui_deny", -6.0)
		Events.toast.emit("盲区币不够", UITheme.RED)
		return
	run.coins -= price
	match key:
		"field_kit":
			run.heal(45.0)
			Sfx.play("heal", -4.0)
		"field_cell":
			run.ge = run.max_ge
			Events.player_ge_changed.emit(run.ge, run.max_ge)
			Sfx.play("ghost_enter", -6.0)
		"field_shard":
			run.add_shards(30)
			Sfx.play("shard", -4.0)
	Events.currency_changed.emit(0)
	Events.toast.emit("已取货：%s" % str(d.get("name", key)), UITheme.GOLD)
	_rebuild_panel()


func _build_rest_node() -> void:
	var run := Game.run
	if run == null:
		_build_unknown()
		return
	panel_title.text = "维修节点 · 一次性修复"
	panel_body.add_child(UITheme.rich("[color=#7d8899]一根还通着电的旧线缆。它不认识你，但它愿意再充一次。[/color]", 16))
	panel_body.add_child(UITheme.label("当前耐久：%d / %d" % [ceili(run.hp), ceili(run.max_hp)], 18, UITheme.TEXT_BRIGHT))
	panel_body.add_child(UITheme.spacer(4))

	var room := _current_service_room()
	var used := room != null and room.payload is Dictionary and bool(room.payload.get("rest_used", false))
	if used:
		panel_body.add_child(UITheme.label("这个节点已经烧干了。", 16, UITheme.TEXT_DIM))
	else:
		panel_body.add_child(UITheme.label("回复 40% 最大耐久，清空热量，污染 -10。", 15, UITheme.TEXT_DIM))
		panel_body.add_child(_mk_button("接入", UITheme.GREEN, func(): _do_rest_node(room)))
	panel_body.add_child(_mk_button("离开", UITheme.PANEL_LINE, func(): close_panel()))
	panel_footer.text = "每个维修节点只能用一次"


func _do_rest_node(room: Room) -> void:
	var run := Game.run
	if run == null or room == null:
		return
	if not (room.payload is Dictionary):
		room.payload = {}
	room.payload["rest_used"] = true
	run.heal(run.max_hp * 0.4)
	run.heat = 0.0
	run.reduce_pollution(10.0)
	Sfx.play("heal", -3.0)
	Events.player_heat_changed.emit(run.heat, run.max_heat)
	Events.toast.emit("外壳重新密封", UITheme.GREEN)
	_rebuild_panel()


# ---------- 长椅 ----------

func _build_bench() -> void:
	panel_title.text = "长椅 · 短暂休整"
	var r := Game.ensure_hub_state()
	panel_body.add_child(UITheme.rich("[color=#7d8899]卡斯特在扶手上焊了一只铁杯，里面的合成咖啡还是温的。[/color]", 16))
	panel_body.add_child(UITheme.spacer(6))
	panel_body.add_child(_stat_line("耐久", "%d / %d" % [int(r.hp), int(r.max_hp)], UITheme.RED))
	panel_body.add_child(_stat_line("幽灵能量", "%d / %d" % [int(r.ge), int(r.max_ge)], UITheme.VIOLET))
	panel_body.add_child(_stat_line("体力", "%d / %d" % [int(r.st), int(r.max_st)], UITheme.GREEN))
	panel_body.add_child(_stat_line("污染", "%d%%" % int(r.pollution), UITheme.CYAN))
	panel_body.add_child(UITheme.spacer(8))
	panel_body.add_child(UITheme.rich("[color=#7d8899]休整会回满全部资源并写入存档。织网之外，只有这里能这么做。[/color]", 15))
	panel_body.add_child(UITheme.spacer(6))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_mk_button("休整并保存", UITheme.GREEN, func():
		Game.hub_rest()
		Sfx.play("heal")
		Events.toast.emit("状态已恢复，进度已保存", UITheme.GREEN)
		_rebuild_panel()
	))
	row.add_child(_mk_button("离开", UITheme.PANEL_LINE, func(): close_panel()))
	panel_body.add_child(row)
	panel_footer.text = "ESC / E 离开"


# ---------- 改造台 ----------

func _build_rig() -> void:
	panel_title.text = "外壳改造台 · 永久升级"
	panel_body.add_child(UITheme.rich("[color=#7d8899]消耗织网碎片，改写外壳的底层规格。改完不会退回去。[/color]", 16))
	panel_body.add_child(UITheme.label("可用碎片：%d" % Game.shards_bank, 18, UITheme.GOLD))
	panel_body.add_child(UITheme.spacer(4))

	for key in Game.META_UPGRADES.keys():
		var d: Dictionary = Game.META_UPGRADES[key]
		var lv := int(Game.meta_upgrades.get(key, 0))
		var maxlv := int(d["max"])
		var cost := Game.meta_cost(key)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		info.add_child(UITheme.label("%s  [%d/%d]" % [str(d["name"]), lv, maxlv], 17, UITheme.TEXT_BRIGHT if lv > 0 else UITheme.TEXT))
		info.add_child(UITheme.label(str(d["desc"]), 14, UITheme.TEXT_DIM))
		row.add_child(info)

		var btn: Button
		if cost < 0:
			btn = _mk_button("已满级", UITheme.CYAN, Callable())
			btn.disabled = true
		else:
			var k: String = str(key)
			var dn := str(d["name"])
			btn = _mk_button("升级 %d" % cost, UITheme.CYAN, func():
				if Game.buy_meta(k):
					Events.toast.emit("已改造：%s" % dn, UITheme.CYAN)
					_rebuild_panel()
				else:
					Events.toast.emit("碎片不足", UITheme.RED)
			)
			btn.disabled = Game.shards_bank < cost
		btn.custom_minimum_size = Vector2(124, 0)
		row.add_child(btn)
		panel_body.add_child(row)
		panel_body.add_child(UITheme.divider(Color("1b2130"), 1))

	panel_body.add_child(_mk_button("离开", UITheme.PANEL_LINE, func(): close_panel()))
	panel_footer.text = "碎片在织网中获取，死亡后按难度比例带回"


# ---------- 黑市 ----------

func _build_market() -> void:
	panel_title.text = "黑市终端 · 盲区币结算"
	panel_body.add_child(UITheme.rich("[color=#7d8899]信号对面的人不肯露面。投币，取货，别问货从哪来。[/color]", 16))
	panel_body.add_child(UITheme.label("可用盲区币：%d" % Game.coins_bank, 18, UITheme.GOLD))
	panel_body.add_child(UITheme.spacer(4))

	for key in Game.SHOP_ITEMS.keys():
		var d: Dictionary = Game.SHOP_ITEMS[key]
		var owned := int(Game.pending_boons.get(key, 0))
		var price := Game.shop_price(key)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		info.add_child(UITheme.label("%s   ×%d" % [str(d["name"]), owned], 17, UITheme.TEXT_BRIGHT if owned > 0 else UITheme.TEXT))
		info.add_child(UITheme.label("%s（%d 盲区币）" % [str(d["desc"]), price], 14, UITheme.TEXT_DIM))
		row.add_child(info)

		var k: String = str(key)
		var dn := str(d["name"])
		var buy := _mk_button("买入", UITheme.GOLD, func():
			if Game.buy_shop_item(k):
				Events.toast.emit("已订购：%s（下一局开局生效）" % dn, UITheme.GOLD)
			else:
				Events.toast.emit("盲区币不足", UITheme.RED)
			_rebuild_panel()
		)
		buy.disabled = Game.coins_bank < price
		buy.custom_minimum_size = Vector2(96, 0)
		row.add_child(buy)

		if owned > 0:
			var refund := _mk_button("退货", Color("5a6474"), func():
				Game.refund_shop(k)
				_rebuild_panel()
			)
			refund.custom_minimum_size = Vector2(76, 0)
			row.add_child(refund)

		panel_body.add_child(row)
		panel_body.add_child(UITheme.divider(Color("1b2130"), 1))

	panel_body.add_child(UITheme.rich("[color=#7d8899]订购的补给在下一局开局结算，不会留到更后面。[/color]", 15))
	panel_body.add_child(_mk_button("离开", UITheme.PANEL_LINE, func(): close_panel()))
	panel_footer.text = "盲区币来自自动机残骸与暗格"


# ---------- 离线终端 ----------

const INTEL_PAGES := [
	{"id": "intel_cage", "title": "墟影协议 · 残页 01", "body": "「笼」不是监狱，是保险箱。\n\n它们把整座城市折叠进织网，让时间在里面循环，直到有人替它们做出选择。我们是留在缝隙里的锈。\n\n—— 记录者未署名"},
	{"id": "intel_orders", "title": "三大教团 · 简报", "body": "枢机教团：把人的意识上传圣所，认为肉体是累赘。\n军团：认为意识才是污染，只信钢铁与命令。\n织网：两者都想要，两者都不信。\n\n三方都在找同一件东西：笼的钥匙。"},
	{"id": "intel_self", "title": "卡斯特手记", "body": "剪断动脉，保留选择。\n\n我们不是要逃出笼子。我们要的是——在笼子里，还能自己决定下一步往哪走。\n\n只要你还能挥剑，你就还没被写死。"},
]


func _build_terminal() -> void:
	panel_title.text = "离线终端 · 记忆残页"
	panel_body.add_child(UITheme.rich("[color=#7d8899]这台终端不上网。它只记得一些别人不想让它记得的事。[/color]", 16))
	panel_body.add_child(UITheme.spacer(4))

	for page in INTEL_PAGES:
		var id := str(page["id"])
		var seen := Game.intel_seen.has(id)
		var p: Dictionary = page

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		info.add_child(UITheme.label(str(page["title"]), 17, UITheme.VIOLET if seen else UITheme.TEXT))
		info.add_child(UITheme.label(str(page["body"]).split("\n")[0], 14, UITheme.TEXT_DIM))
		row.add_child(info)

		var read := _mk_button("重读" if seen else "读取", UITheme.VIOLET, func():
			if Game.add_intel(id):
				Sfx.play("intel")
			_show_intel(p)
		)
		read.custom_minimum_size = Vector2(96, 0)
		row.add_child(read)
		panel_body.add_child(row)
		panel_body.add_child(UITheme.divider(Color("1b2130"), 1))

	panel_body.add_child(_mk_button("离开", UITheme.PANEL_LINE, func(): close_panel()))
	panel_footer.text = "已解锁 %d / %d" % [Game.intel_seen.size(), INTEL_PAGES.size()]


func _show_intel(page: Dictionary) -> void:
	_clear_body()
	panel_title.text = str(page["title"])
	panel_body.add_child(UITheme.spacer(10))
	panel_body.add_child(UITheme.rich(str(page["body"]).replace("\n", "\n\n"), 18, UITheme.TEXT))
	panel_body.add_child(UITheme.spacer(14))
	panel_body.add_child(_mk_button("← 返回列表", UITheme.VIOLET, func(): _rebuild_panel()))
	panel_footer.text = "记忆残页 · 已归档"


# ---------- 出击 ----------

func _build_exit() -> void:
	panel_title.text = "出击升降机 · 进入织网"
	panel_body.add_child(UITheme.rich("[color=#7d8899]升降机会把你送到织网的表层。从那里开始，路是自己选的，退出权不在你手上。[/color]", 16))
	panel_body.add_child(UITheme.spacer(6))
	panel_body.add_child(UITheme.label("当前难度：%s" % Game.difficulty_name(), 18, UITheme.GOLD))
	panel_body.add_child(UITheme.spacer(6))

	if not Game.pending_boons.is_empty():
		panel_body.add_child(UITheme.label("已订购补给（开局结算）：", 16, UITheme.GOLD))
		for key in Game.pending_boons.keys():
			var n := int(Game.pending_boons[key])
			var item: Dictionary = Game.SHOP_ITEMS.get(key, {})
			var nm := str(item.get("name", str(key)))
			panel_body.add_child(UITheme.label("   · %s ×%d" % [nm, n], 15, UITheme.TEXT))

	panel_body.add_child(UITheme.spacer(10))
	panel_body.add_child(UITheme.rich("[color=#7d8899]（敌人生成与房间清理仍在施工中；现在出击会进入可自由跑图的程序化扇区。）[/color]", 15))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_mk_button("出击", UITheme.RED, func():
		close_panel()
		Events.hub_request_run.emit()
	))
	row.add_child(_mk_button("再等等", UITheme.PANEL_LINE, func(): close_panel()))
	panel_body.add_child(row)
	panel_footer.text = "ESC / E 取消"


func _build_unknown() -> void:
	panel_title.text = "未知接口"
	panel_body.add_child(UITheme.label("这台机器没有反应。", 17, UITheme.TEXT_DIM))
	panel_body.add_child(_mk_button("离开", UITheme.PANEL_LINE, func(): close_panel()))


# ---------- 小组件 ----------

func _stat_line(name_: String, value: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UITheme.label(name_, 16, UITheme.TEXT_DIM)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	row.add_child(UITheme.label(value, 17, color))
	return row


func _mk_button(text: String, accent: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	# 键盘可达：原来写死 FOCUS_NONE，鼠标能用但键盘完全进不来
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", UITheme.get_font())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", UITheme.accent_style(accent.darkened(0.45), Color(0.06, 0.07, 0.10, 0.92)))
	b.add_theme_stylebox_override("hover", UITheme.accent_style(accent, Color(0.10, 0.12, 0.16, 0.96)))
	b.add_theme_stylebox_override("pressed", UITheme.accent_style(accent.darkened(0.2), Color(0.05, 0.06, 0.09, 0.98)))
	b.add_theme_stylebox_override("disabled", UITheme.accent_style(Color("343b47"), Color(0.05, 0.05, 0.07, 0.85)))
	# 焦点框用白色加粗，跟按钮自己的 accent 色区分开，键盘走到哪一眼能看见
	var focus_box := UITheme.accent_style(Color.WHITE, Color(0.18, 0.21, 0.28, 0.98))
	focus_box.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus_box)
	b.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("5d6673"))
	if cb.is_valid():
		b.pressed.connect(cb)
	b.mouse_entered.connect(func(): Sfx.play("ui_move", -8.0))
	return b


# ================= 键盘可达 =================
# 所有 UI 层打开时聚焦第一个按钮，W/S 在按钮之间环形移动。
# 确认键不用这里管：Button 在 _gui_input 阶段就会消费内置的 ui_accept（Enter / Space）。

## 收集一个节点子树里所有能聚焦的按钮，按视觉位置（先 y 后 x）排序。
func _buttons_in(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if node == null or not is_instance_valid(node):
		return out
	for c in node.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and b.visible and not b.disabled:
			out.append(b)
	out.sort_custom(func(a: Button, b: Button) -> bool:
		var pa := a.get_global_rect().position
		var pb := b.get_global_rect().position
		if absf(pa.y - pb.y) > 6.0:
			return pa.y < pb.y
		return pa.x < pb.x)
	return out


## 当前该接收键盘的 UI 层。null 表示此刻没有键盘可达的 UI（游戏中）。
func _active_ui_layer() -> Control:
	if pause_layer != null and pause_layer.visible:
		return pause_layer
	if panel_layer != null and panel_open and panel_layer.visible:
		return panel_layer
	if gameover_layer != null and gameover_layer.visible:
		return gameover_layer
	if title_layer != null and title_layer.visible:
		return title_layer
	return null


## 聚焦当前层的第一个按钮。延迟一帧，等容器把子节点的位置算出来。
func _focus_first_button() -> void:
	await get_tree().process_frame
	var layer := _active_ui_layer()
	if layer == null:
		return
	var list := _buttons_in(layer)
	if not list.is_empty():
		list[0].grab_focus()


## W/S 移动焦点。返回 true 表示这次输入被 UI 吃掉了。
func _move_focus(dir: int) -> bool:
	var layer := _active_ui_layer()
	if layer == null:
		return false
	var list := _buttons_in(layer)
	if list.is_empty():
		return false
	var cur := get_viewport().gui_get_focus_owner() as Button
	var idx := list.find(cur)
	var next := 0
	if idx >= 0:
		next = (idx + dir + list.size()) % list.size()
	elif dir < 0:
		next = list.size() - 1
	list[next].grab_focus()
	return true


## 收起 UI 时把焦点还回去，免得隐藏的按钮继续吃 Enter / Space。
func _release_ui_focus() -> void:
	var vp := get_viewport()
	if vp != null and vp.gui_get_focus_owner() != null:
		vp.gui_release_focus()


# ================= 数据舱三选一 =================

func _build_reward() -> void:
	reward = RewardChoice.new()
	reward.name = "RewardChoice"
	reward.picked.connect(_on_reward_picked)
	root.add_child(reward)
	reward.visible = false


func _on_reward_choices(choices: Array) -> void:
	if reward == null or choices.is_empty():
		return
	# 三选一期间冻结战斗：房间已经空了，但玩家不该在选卡时被打断，也不该趁机走掉
	_set_player_controls(false)
	get_tree().paused = true
	# 三选一自己用 _unhandled_input 收键，必须先放开焦点，否则 Enter 会被旧按钮吃掉
	_release_ui_focus()
	reward.open(choices, Game.run)


func _on_reward_picked(id: String) -> void:
	if reward != null:
		reward.close()
	get_tree().paused = false
	_set_player_controls(true)
	Events.toast.emit("已获得：%s" % _upgrade_name(id), UITheme.GOLD)


func _upgrade_name(id: String) -> String:
	var d := UpgradeDB.get_upgrade(id)
	if d.is_empty():
		return id
	return str(d.get("name", id))


# ================= 提示 =================

func _on_player_spawned(p: Node2D) -> void:
	player = p


func _on_banner(title: String, sub: String) -> void:
	banner_title.text = title
	banner_sub.text = sub
	banner_timer = 3.6


func _on_subtitle(text: String, speaker: String) -> void:
	subtitle_label.text = text if speaker.is_empty() else "%s：%s" % [speaker, text]
	subtitle_timer = 4.4


func _on_hack_progress(target: Node, ratio: float) -> void:
	if hud == null:
		return
	hud.hack_ratio = ratio
	hud.hack_label = ""
	if target != null and is_instance_valid(target) and target.has_method("label"):
		hud.hack_label = str(target.call("label"))
	hud.queue_redraw()


func _on_toast(text: String, color: Color) -> void:
	var l := UITheme.label(text, 16, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_box.add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	while toast_box.get_child_count() > 6:
		toast_box.get_child(0).queue_free()


# ================= 每帧 =================

func _process(delta: float) -> void:
	_t += delta
	hud.run_ref = Game.run
	hud.in_run = (mode == Mode.RUN)
	# Boss 血条只挂在还活着的 Boss 身上；它一死就撤掉
	if _boss != null and (not is_instance_valid(_boss) or not bool(_boss.call("is_alive"))):
		_boss = null
	hud.boss_ref = _boss
	hud.tick(delta)

	if banner_timer > 0.0:
		banner_timer -= delta
		var a := 1.0
		if banner_timer > 2.9:
			a = clampf((3.6 - banner_timer) / 0.7, 0.0, 1.0)
		elif banner_timer < 0.7:
			a = clampf(banner_timer / 0.7, 0.0, 1.0)
		banner_box.modulate.a = a
	else:
		banner_box.modulate.a = maxf(0.0, banner_box.modulate.a - delta * 2.5)

	if subtitle_timer > 0.0:
		subtitle_timer -= delta
		subtitle_label.modulate.a = clampf(subtitle_timer / 0.8, 0.0, 1.0)
	else:
		subtitle_label.modulate.a = maxf(0.0, subtitle_label.modulate.a - delta * 2.5)

	_update_interact_hint()


func _on_boss_started(boss: Node) -> void:
	_boss = boss


func _on_boss_defeated(_boss_ref) -> void:
	_boss = null


func _update_interact_hint() -> void:
	var d := get_process_delta_time()
	var target_alpha := 0.0
	var text := ""
	if not panel_open and (mode == Mode.HUB or mode == Mode.RUN) \
			and player != null and is_instance_valid(player) and player.has_method("current_interactable"):
		var it = player.current_interactable()
		if it != null and is_instance_valid(it):
			var label := str(it.get("label_text"))
			if label == "":
				label = "交互"
			text = "[E]  %s — %s" % [label, str(it.get("prompt_text"))]
			target_alpha = 1.0
	if text != "":
		interact_label.text = text
	interact_label.modulate.a = move_toward(interact_label.modulate.a, target_alpha, 7.0 * d)


func _unhandled_input(event: InputEvent) -> void:
	# 三选一优先级最高：它自己处理键盘，这里不要抢
	if reward != null and reward.is_open():
		return

	# Esc：面板打开时先关面板，否则开关暂停
	if event.is_action_pressed("pause"):
		if panel_open:
			close_panel()
		elif paused:
			set_paused(false)
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return

	# W/S 移动焦点。放在 `if paused` 之前，暂停菜单也要吃这套。
	# 没有可见 UI 层时 _move_focus 返回 false，不消费输入，玩家移动不受影响。
	if event.is_action_pressed("move_up") and _move_focus(-1):
		Sfx.play("ui_move", -8.0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_down") and _move_focus(1):
		Sfx.play("ui_move", -8.0)
		get_viewport().set_input_as_handled()
		return

	if paused:
		return

	if not panel_open:
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("interact"):
		close_panel()
		get_viewport().set_input_as_handled()


# ================= 暂停 =================

func _build_pause() -> void:
	var p: Control = PAUSE_SCENE.instantiate()
	pause_layer = p
	pause_layer.name = "PauseLayer"
	pause_layer.visible = false
	root.add_child(pause_layer)
	# 暂停页只发信号：「继续 / 放弃本局 / 返回标题」在这里翻译成动作。
	pause_layer.connect("action", _on_pause_action)
	pause_layer.connect("hover", func(_id: String) -> void: Sfx.play("ui_move", -8.0))


func _on_pause_action(id: String) -> void:
	match id:
		"resume":
			Sfx.play("ui_confirm")
			set_paused(false)
		"abandon_run":
			Sfx.play("ui_confirm")
			_pause_leave("goto_hub")
		"goto_title":
			Sfx.play("ui_confirm")
			_pause_leave("goto_title")


func toggle_pause() -> void:
	if mode != Mode.RUN and mode != Mode.HUB:
		return
	set_paused(not paused)


func set_paused(v: bool) -> void:
	if paused == v:
		return
	paused = v
	if pause_layer != null:
		pause_layer.visible = v
	get_tree().paused = v
	if v:
		Sfx.play("ui_confirm", -6.0)
		# 焦点交给暂停容器自己 —— 它要让箭头先获得焦点，而不是设置面板里的隐藏按钮。
		_rebuild_pause()
	else:
		_release_ui_focus()


func _rebuild_pause() -> void:
	if pause_layer == null:
		return
	var run := Game.run
	if mode == Mode.RUN and run != null:
		pause_layer.call("setup", true,
			"已暂停 · 织网 第 %d 扇区 · 难度 %s · 已清房间 %d · 本局碎片 %d · 盲区币 %d" % [
				run.floor_index + 1, Game.difficulty_name(), run.rooms_cleared, run.shards, run.coins
			])
	else:
		pause_layer.call("setup", false, "已暂停 · 这里是安全屋，不会丢东西。")


func _pause_leave(method: String) -> void:
	set_paused(false)
	if Game.main != null:
		Game.main.call(method)


# ================= HUD 自绘 =================

class HudLayer extends Control:
	var run_ref: RunState = null
	var in_run: bool = false
	var boss_ref: Node = null
	var hack_ratio: float = 0.0
	var hack_label: String = ""
	var _t: float = 0.0

	func tick(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if run_ref == null:
			return
		var f := UITheme.get_font()
		var r := run_ref
		var x := 26.0
		var y := 24.0
		var w := 300.0

		_bar(Rect2(x, y, w, 18.0), r.hp / maxf(1.0, r.max_hp), UITheme.RED)
		_text(f, Vector2(x + 8.0, y + 14.5), "耐久 %d / %d" % [ceili(r.hp), int(r.max_hp)], 13, Color(1, 1, 1, 0.94))
		y += 23.0

		_bar(Rect2(x, y, w, 13.0), r.ge / maxf(1.0, r.max_ge), UITheme.VIOLET)
		_text(f, Vector2(x + 8.0, y + 11.0), "幽灵能量 %d / %d" % [int(r.ge), int(r.max_ge)], 11, Color(1, 1, 1, 0.9))
		y += 17.0

		_bar(Rect2(x, y, w, 9.0), r.st / maxf(1.0, r.max_st), UITheme.GREEN)
		_text(f, Vector2(x + w + 10.0, y + 8.5), "姿态 %d" % int(r.st), 11, Color(0.62, 0.82, 0.62, 0.9))
		y += 13.0

		_bar(Rect2(x, y, w, 7.0), r.heat / maxf(1.0, r.max_heat), UITheme.AMBER)
		if r.heat > 1.0:
			_text(f, Vector2(x + w + 10.0, y + 7.5), "热量 %d" % int(r.heat), 11, UITheme.AMBER)
		y += 12.0

		var pol := clampf(r.pollution / 100.0, 0.0, 1.0)
		_bar(Rect2(x, y, w, 6.0), pol, UITheme.CYAN)
		if pol > 0.001:
			_text(f, Vector2(x + w + 10.0, y + 7.0), "污染 %d%%" % int(r.pollution), 12, UITheme.CYAN)
		y += 14.0

		var where := "织网 · 第 %d 扇区" % (r.floor_index + 1)
		if not in_run:
			where = "B2 裁断安全屋"
		_text(f, Vector2(x, y + 12.0), "%s · 难度 %s" % [where, Game.difficulty_name()], 13, UITheme.TEXT_DIM)
		if in_run:
			var el := r.current_element()
			var owned_arr: Array = r.weapon.get("elements_owned", [])
			var el_line := "铳械模块  %s" % str(el.get("name", el.get("id", "?")))
			if owned_arr.size() > 1:
				el_line += "   [Tab 切换]"
			_text(f, Vector2(x, y + 30.0), el_line, 13, UITheme.VIOLET)

		var rx := size.x - 28.0
		_text_r(f, Vector2(rx, 40.0), "织网碎片  %d" % Game.shards_bank, 18, UITheme.CYAN)
		_text_r(f, Vector2(rx, 64.0), "盲区币  %d" % Game.coins_bank, 18, UITheme.GOLD)
		if r.shards > 0:
			_text_r(f, Vector2(rx, 88.0), "局内碎片  %d" % r.shards, 15, UITheme.TEXT_DIM)

		var by := size.y - 44.0
		var count := r.acquired_order.size()
		_text(f, Vector2(28.0, by), "词条 ×%d" % count, 14, UITheme.TEXT_DIM)
		if count > 0:
			var ids := ""
			for i in mini(count, 6):
				var uid: String = str(r.acquired_order[i])
				var up := UpgradeDB.get_upgrade(uid)
				ids += "%s  " % str(up.get("name", uid))
			_text(f, Vector2(28.0, by + 20.0), ids.strip_edges(), 13, Color(0.55, 0.6, 0.68, 0.9))

		var consum := ""
		for k in r.consumables.keys():
			consum += "%s×%d  " % [str(k), int(r.consumables[k])]
		if consum != "":
			_text_r(f, Vector2(rx, by), consum.strip_edges(), 14, UITheme.TEXT_DIM)

		# Boss 血条：屏幕下方居中，只在 Boss 还活着的时候出现
		if boss_ref != null and is_instance_valid(boss_ref) and bool(boss_ref.call("is_alive")):
			_draw_boss_bar(f, boss_ref)

		# 骇入进度条：屏幕中下偏上，与 Boss 血条分开
		if hack_ratio > 0.0:
			_draw_hack_bar(f)

	func _draw_hack_bar(f: Font) -> void:
		var hw := 300.0
		var hx := (size.x - hw) * 0.5
		var hy := size.y - 232.0
		_bar(Rect2(hx, hy, hw, 10.0), hack_ratio, UITheme.CYAN)
		_text_r(f, Vector2(hx + hw + 12.0, hy + 9.5), "%d%%" % int(hack_ratio * 100.0), 12, UITheme.CYAN)
		var title := "骇入中"
		if hack_label != "":
			title = "骇入中 · %s" % hack_label
		_text(f, Vector2(hx, hy - 5.0), title, 13, Color(UITheme.CYAN.r, UITheme.CYAN.g, UITheme.CYAN.b, 0.92))

	func _draw_boss_bar(f: Font, b: Node) -> void:
		var bw := 640.0
		var bx := (size.x - bw) * 0.5
		var by2 := size.y - 150.0
		var mhp := maxf(1.0, float(b.get("max_hp")))
		var chp := clampf(float(b.get("hp")), 0.0, mhp)
		var frac := chp / mhp

		var nm := str(b.get("display_name"))
		if nm == "":
			nm = "BOSS"
		_text_c(f, Vector2(size.x * 0.5, by2 - 14.0), nm, 24, Color(0.94, 0.95, 0.98, 0.96))

		draw_rect(Rect2(bx - 3.0, by2 - 3.0, bw + 6.0, 16.0), Color(0.02, 0.03, 0.05, 0.88))
		draw_rect(Rect2(bx, by2, bw, 10.0), Color(0.11, 0.12, 0.15, 0.95))
		if frac > 0.0:
			draw_rect(Rect2(bx, by2, bw * frac, 10.0), Color("e0554f"))
			draw_rect(Rect2(bx, by2, bw * frac, 3.0), Color("ff8a80"))
		draw_rect(Rect2(bx, by2, bw, 10.0), Color(0.42, 0.46, 0.54, 0.9), false, 1.0)
		_text_c(f, Vector2(size.x * 0.5, by2 + 28.0), "%d / %d" % [ceili(chp), int(mhp)], 13, Color(0.78, 0.81, 0.87, 0.9))

	func _text_c(f: Font, pos: Vector2, s: String, sz: int, c: Color) -> void:
		var wdt := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		_text(f, Vector2(pos.x - wdt * 0.5, pos.y), s, sz, c)

	func _bar(rect: Rect2, ratio: float, color: Color) -> void:
		ratio = clampf(ratio, 0.0, 1.0)
		draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.55))
		draw_rect(rect, Color(0.10, 0.11, 0.14, 0.92))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, 2.0)), color.lightened(0.35))
		draw_rect(rect, Color(0.30, 0.34, 0.42, 0.9), false, 1.0)

	func _text(f: Font, pos: Vector2, s: String, sz: int, c: Color) -> void:
		draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 3, Color(0, 0, 0, 0.7))
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

	func _text_r(f: Font, pos: Vector2, s: String, sz: int, c: Color) -> void:
		var wdt := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		_text(f, Vector2(pos.x - wdt, pos.y), s, sz, c)

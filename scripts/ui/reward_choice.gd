extends Control
class_name RewardChoice
## 数据舱三选一：清空房间后的一次性局内成长。
##
## 全部界面在代码里搭，不依赖场景文件。打开 / 关闭由 UIRoot 负责，
## 游戏暂停也由 UIRoot 控制 —— 这里只管「画卡片、收输入、写回 RunState」。

signal picked(id: String)

const CARD_W := 272.0
const CARD_H := 320.0

const RARITY_NAME := {
	"common": "常  规",
	"rare": "稀  有",
	"epic": "史  诗",
	"legend": "传  说",
}

const TAG_NAME := {
	"sword": "剑术",
	"shield": "盾术",
	"gun": "铳械",
	"ghost": "幽灵",
	"shell": "外壳",
	"util": "通用",
}

var choices: Array = []
# 带 setter：外部（自检、鼠标）改 index 也必须立刻重画选中态，否则高亮会停在旧卡片上
var index: int = 0:
	set(value):
		index = value
		if _frames.size() > 0:
			_refresh()

var _run: RunState = null
var _row: HBoxContainer
var _frames: Array[PanelContainer] = []
var _accents: Array[Color] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.032, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	center.add_child(col)

	var t := UITheme.label("数 据 舱", 36, UITheme.TEXT_BRIGHT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)

	var sub := UITheme.label("织网在你身上留下一段可以选择的代码 —— 选完它就不再问了", 16, UITheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	col.add_child(_gap(12))

	_row = HBoxContainer.new()
	_row.name = "Cards"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 18)
	col.add_child(_row)

	col.add_child(_gap(10))

	var hint := UITheme.label("← →  切换        Enter / 1 2 3  确认", 16, UITheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


# ================= 开关 =================

func open(p_choices: Array, p_run: RunState) -> void:
	choices = p_choices
	_run = p_run
	index = 0

	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	_frames.clear()
	_accents.clear()

	for i in choices.size():
		var d: Dictionary = choices[i]
		var card := _make_card(i, d)
		_row.add_child(card)

	_refresh()
	visible = true
	Sfx.play("reward_appear", -3.0)


func close() -> void:
	visible = false
	choices = []
	_frames.clear()
	_accents.clear()
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	if _run != null:
		_run.pending_choice = []


func is_open() -> bool:
	return visible


# ================= 卡片 =================

func _make_card(i: int, d: Dictionary) -> PanelContainer:
	var rarity := str(d.get("rarity", "common"))
	var accent := UITheme.rarity_color(rarity)
	_accents.append(accent)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(CARD_W, CARD_H)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			index = i
			_confirm()
	)
	frame.mouse_entered.connect(func() -> void:
		if index != i:
			index = i
			_refresh()
			Sfx.play("ui_move", -10.0)
	)
	_frames.append(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	frame.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var rar := UITheme.label(str(RARITY_NAME.get(rarity, rarity)), 14, accent)
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rar)

	var nm := UITheme.label(str(d.get("name", "?")), 24, UITheme.TEXT_BRIGHT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(nm)

	var rule := ColorRect.new()
	rule.color = accent.darkened(0.35)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)

	var desc := UITheme.label(str(d.get("desc", "")), 16, Color(0.72, 0.76, 0.84))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD_W - 40.0, 104.0)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	col.add_child(desc)

	col.add_child(_gap(4))

	var id := str(d.get("id", ""))
	var stacks := 0
	if _run != null:
		stacks = int(_run.stacks.get(id, 0))
	var maxs := int(d.get("max_stacks", 1))
	var stack_line := UITheme.label("已叠 %d / %d" % [stacks, maxs], 15, UITheme.TEXT_DIM)
	stack_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(stack_line)

	var tag_text := _tags_text(d.get("tags", []))
	if tag_text != "":
		var tl := UITheme.label(tag_text, 14, Color(0.5, 0.56, 0.66))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tl)

	return frame


func _tags_text(tags_raw) -> String:
	if not (tags_raw is Array):
		return ""
	var out: Array[String] = []
	for t in tags_raw:
		var key := str(t)
		out.append(str(TAG_NAME.get(key, key)))
	return " · ".join(out)


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _refresh() -> void:
	for i in _frames.size():
		var accent: Color = _accents[i]
		var sel := i == index
		var border := accent if sel else accent.darkened(0.55)
		var bg := Color(0.085, 0.10, 0.145, 0.98) if sel else Color(0.05, 0.058, 0.086, 0.94)
		_frames[i].add_theme_stylebox_override("panel", UITheme.accent_style(border, bg))
		_frames[i].modulate = Color.WHITE if sel else Color(0.76, 0.79, 0.85)


# ================= 输入 =================

func _unhandled_input(event: InputEvent) -> void:
	if not visible or choices.is_empty():
		return

	if event.is_action_pressed("move_left"):
		index = (index - 1 + choices.size()) % choices.size()
		_refresh()
		Sfx.play("ui_move", -8.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		index = (index + 1) % choices.size()
		_refresh()
		Sfx.play("ui_move", -8.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).keycode
		if kc == KEY_1 or kc == KEY_2 or kc == KEY_3:
			var want := kc - KEY_1
			if want < choices.size():
				index = want
				_refresh()
				_confirm()
			get_viewport().set_input_as_handled()
		elif kc == KEY_ESCAPE:
			# 三选一不能跳过：这是这一局的成长，不给「以后再说」
			Sfx.play("ui_deny", -8.0)
			get_viewport().set_input_as_handled()


func _confirm() -> void:
	if choices.is_empty() or index < 0 or index >= choices.size():
		return
	var d: Dictionary = choices[index]
	var id := str(d.get("id", ""))
	if id == "":
		return

	Sfx.play("ui_confirm", -2.0)
	if _run != null:
		_run.add_upgrade(id)
		_run.pending_choice = []
	Events.upgrade_taken.emit(d)
	picked.emit(id)

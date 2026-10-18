class_name UIPauseScreen
extends Control
## 暂停界面：左栏是当前装备的核心与效果，右栏是背包里拥有的核心（可滚动）。
##
## 独立场景：可在编辑器里单独打开 `ui/scenes/pause.tscn` 编辑布局，
## 也可 F6 运行 `ui/scenes/preview/pause_preview.tscn` 用假数据预览。
##
## 本脚本不引用 Game / Sfx / RunState —— 按钮只发 `action(id)` 信号，
## 由宿主（ui_root.gd 或预览脚本）决定这几个 id 该干什么。
##
## 核心系统尚未实现（见设定文档第 6 章「核心系统」），
## 左栏此刻是三个圆形凹槽的空占位；数据层补齐后填 set_effect_text / set_bag_empty_text。

signal action(id: String)
signal hover(id: String)

const BTN_IDS: Array[String] = ["resume", "abandon_run", "goto_title"]

@onready var _status: Label = $BottomBar/Status
@onready var _abandon: Button = $BottomBar/Buttons/BtnAbandon
@onready var _slot_row: HBoxContainer = $LeftCard/LeftMargin/LeftVBox/SlotArea/SlotFrame/SlotCenter/SlotRow
@onready var _effect_text: Label = $LeftCard/LeftMargin/LeftVBox/EffectCard/EffectMargin/EffectVBox/EffectText
@onready var _bag_empty: Label = $RightPanel/RightMargin/RightVBox/BagScroll/BagList/BagEmpty


func _ready() -> void:
	_dress()
	_apply_fonts()
	_wire($BottomBar/Buttons/BtnResume, "resume", UITheme.CYAN)
	_wire($BottomBar/Buttons/BtnAbandon, "abandon_run", UITheme.AMBER)
	_wire($BottomBar/Buttons/BtnTitle, "goto_title", UITheme.PANEL_LINE)


## 宿主在打开暂停界面之前调用。
## is_run 为 false（据点）时隐藏「放弃本局」，状态行换成据点提示。
func setup(is_run: bool, status_text: String) -> void:
	_abandon.visible = is_run
	_status.text = status_text


## 聚焦第一个可用按钮（键盘可达）。
func focus_first() -> void:
	$BottomBar/Buttons/BtnResume.grab_focus()


## 核心数据层补齐后，用这两个接口填文案（布局不用动）。
func set_effect_text(text: String) -> void:
	_effect_text.text = text


func set_bag_empty_text(text: String) -> void:
	_bag_empty.text = text


func _dress() -> void:
	$Dim.color = Color(0.02, 0.03, 0.05, 0.76)
	$LeftCard.add_theme_stylebox_override("panel", _card(Color("12141cf2"), UITheme.PANEL_LINE, 18))
	$RightPanel.add_theme_stylebox_override("panel", _card(Color("12141cf2"), UITheme.PANEL_LINE, 2))
	$LeftCard/LeftMargin/LeftVBox/EffectCard.add_theme_stylebox_override(
		"panel", _card(Color("0d0f16f0"), Color("39424f"), 2))

	var left := $LeftCard/LeftMargin/LeftVBox
	left.get_node("LeftHead/LeftBar").color = UITheme.CYAN
	_set_label(left.get_node("LeftHead/LeftTitle"), 18, UITheme.TEXT_BRIGHT)
	left.get_node("LeftDivider").color = UITheme.PANEL_LINE
	_dress_slots()
	_set_label(left.get_node("EffectCard/EffectMargin/EffectVBox/EffectHead"), 13, UITheme.CYAN_DIM)
	_set_label(_effect_text, 14, UITheme.TEXT_DIM)

	var right := $RightPanel/RightMargin/RightVBox
	right.get_node("RightHead/RightBar").color = UITheme.CYAN
	_set_label(right.get_node("RightHead/RightTitle"), 18, UITheme.TEXT_BRIGHT)
	right.get_node("RightDivider").color = UITheme.PANEL_LINE
	_set_label(_bag_empty, 15, UITheme.TEXT_DIM)

	_set_label(_status, 14, UITheme.TEXT_DIM)


## 左栏三个圆形凹槽：第一个可装备（青色细边框），后两个锁定（暗边框）。
## 槽位总数与解锁规则等核心概念定稿后再接 RunState。
func _dress_slots() -> void:
	var frame := $LeftCard/LeftMargin/LeftVBox/SlotArea/SlotFrame
	frame.add_theme_stylebox_override("panel", _card(Color(0, 0, 0, 0), Color("39424f"), 2))

	var i := 0
	for n in _slot_row.get_children():
		var p := n as PanelContainer
		if p == null:
			continue
		var usable := i == 0
		var bg := Color("0d0f16f0") if usable else Color("090b10f0")
		var border := UITheme.CYAN_DIM if usable else Color("2e3644")
		p.add_theme_stylebox_override("panel", _card(bg, border, 48))
		i += 1


## 中文字形只能在运行时挂载 —— Label 不设字体就是豆腐块。
func _apply_fonts() -> void:
	var f := UITheme.get_font()
	for n in find_children("*", "Label", true, false):
		(n as Label).add_theme_font_override("font", f)


func _wire(b: Button, id: String, accent: Color) -> void:
	UITheme.style_button(b, accent)
	b.custom_minimum_size = Vector2(128, 38)
	b.pressed.connect(func() -> void: action.emit(id))
	b.mouse_entered.connect(func() -> void: hover.emit(id))
	b.focus_entered.connect(func() -> void: hover.emit(id))


func _set_label(l: Label, size: int, color: Color) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)


func _card(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb

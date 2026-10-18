class_name UIPauseCorePage
extends Control
## 暂停一级界面的「核心页」：左栏核心样式（三个圆形槽位占位 + 效果），右栏背包列表。
##
## 这一页只负责显示 —— 翻页、退出、设置面板都由上层
## `ui/scenes/pause_menu.tscn`（UIPauseMenu）处理，本脚本不发动作也不读存档。
##
## 独立预览：F6 运行 `ui/scenes/preview/pause_preview.tscn`。
##
## 核心系统尚未实现（见设定文档第 6 章「核心系统」），
## 左栏此刻是三个圆形凹槽的空占位；数据层补齐后填 set_effect_text / set_bag_empty_text。

@onready var _slot_row: HBoxContainer = $LeftCard/LeftMargin/LeftVBox/SlotArea/SlotFrame/SlotCenter/SlotRow
@onready var _effect_text: Label = $LeftCard/LeftMargin/LeftVBox/EffectCard/EffectMargin/EffectVBox/EffectText
@onready var _bag_empty: Label = $RightPanel/RightMargin/RightVBox/BagScroll/BagList/BagEmpty


func _ready() -> void:
	_dress()
	_apply_fonts()


## 核心数据层补齐后，用这两个接口填文案（布局不用动）。
func set_effect_text(text: String) -> void:
	_effect_text.text = text


func set_bag_empty_text(text: String) -> void:
	_bag_empty.text = text


func _dress() -> void:
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

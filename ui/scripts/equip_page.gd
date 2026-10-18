class_name UIPauseEquipPage
extends Control
## 暂停一级界面的「装备总览页」。
##
## 网格：当前剑 / 当前弓 / 当前buff / 当前盾 / 当前核心效果 / 元素克制。
## 前五格目前只有标题占位 —— 武器与核心的数据层还没实现；
## 第六格用 UpgradeDB.ELEMENTS 生成元素克制速查。
##
## 这页不含任何退出按钮，底部那排菜单由上层 `ui/scenes/pause_menu.tscn` 负责。
## 独立预览：F6 运行 `ui/scenes/preview/equip_preview.tscn`。

signal action(id: String)
signal hover(id: String)

## 元素克制速查的短句 —— UpgradeDB.ELEMENTS 的 desc 太长，格子里放不下。
const ELEMENT_TIPS := {
	"basic": "通用，无特殊克制",
	"burn": "对有机与布甲强，可点燃油污",
	"slow": "命中降低移动与攻速",
	"poison": "对装甲弱，对高血人形强",
	"emp": "对机械 +35%，可短路炮塔",
	"shock": "高姿态伤害，可打断蓄力",
}

@onready var _elem_list: VBoxContainer = $PageMargin/PageVBox/Row2/CellElements/ElemMargin/ElemVBox/ElemList


func _ready() -> void:
	# 本页作为场景实例被父场景挂载时，根锚点不一定被保留，这里显式拉满。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$PageMargin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dress()
	_build_elements()
	_apply_fonts()


func _dress() -> void:
	for n in find_children("*", "PanelContainer", true, false):
		var p := n as PanelContainer
		p.add_theme_stylebox_override("panel", _card(Color("12141cf2"), Color("2a3040"), 4))

	for path in ["CellSword/SwordTitle", "CellBow/BowTitle", "CellBuff/BuffTitle",
			"CellShield/ShieldTitle", "CellCore/CoreTitle"]:
		var l := $PageMargin/PageVBox/Row1.get_node_or_null(path)
		if l == null:
			l = $PageMargin/PageVBox/Row2.get_node_or_null(path)
		if l is Label:
			_set_label(l as Label, 18, UITheme.TEXT_DIM)

	_set_label($PageMargin/PageVBox/Row2/CellElements/ElemMargin/ElemVBox/ElemTitle, 14, UITheme.CYAN_DIM)


## 六行速查：色点 + 模块名 + 克制关系。
func _build_elements() -> void:
	for id in UpgradeDB.ELEMENTS.keys():
		var d: Dictionary = UpgradeDB.ELEMENTS[id]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = d.get("color", UITheme.TEXT_DIM)
		var dot_center := CenterContainer.new()
		dot_center.add_child(dot)
		row.add_child(dot_center)

		var name_label := Label.new()
		name_label.text = str(d.get("name", id))
		name_label.custom_minimum_size = Vector2(78, 0)
		row.add_child(name_label)

		var tip_label := Label.new()
		tip_label.text = str(ELEMENT_TIPS.get(id, ""))
		tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tip_label)

		_elem_list.add_child(row)
		_set_label(name_label, 13, UITheme.TEXT_BRIGHT)
		_set_label(tip_label, 11, UITheme.TEXT_DIM)


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

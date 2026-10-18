class_name UIPauseMenu
extends Control
## 暂停一级界面容器：装备总览页 ↔ 核心页，左右切换。
##
## 两页都是独立场景（`pause_equip.tscn` / `pause.tscn`），可以各自 F6 单独预览；
## 本容器只负责翻页、页签圆点，以及底部那排菜单按钮。
##
## 底部菜单从左至右：继续游戏 / 放弃本局 / 游戏设置 / 保存游戏 / 返回标题。
## 「放弃本局」只在局内显示；「游戏设置」「保存游戏」对应的系统还没做，暂时是灰的。
## 独立预览：F6 运行 `ui/scenes/preview/pause_menu_preview.tscn`。

signal action(id: String)
signal hover(id: String)

const PAGE_EQUIP := 0
const PAGE_CORE := 1
const PAGE_COUNT := 2

## 底部菜单：节点名 → 动作 id 与强调色。disabled 由场景里决定，这里不覆盖。
const MENU_ITEMS := [
	{"node": "BtnResume", "id": "resume", "accent": UITheme.CYAN},
	{"node": "BtnAbandon", "id": "abandon_run", "accent": UITheme.AMBER},
	{"node": "BtnSettings", "id": "game_settings", "accent": UITheme.PANEL_LINE},
	{"node": "BtnSave", "id": "save_game", "accent": UITheme.PANEL_LINE},
	{"node": "BtnQuit", "id": "goto_title", "accent": Color("5a6474")},
]

@onready var _equip: Control = $EquipPage
@onready var _core: Control = $CorePage
@onready var _status: Label = $Controls/StatusLine
@onready var _left: Button = $Controls/ArrowLeft
@onready var _right: Button = $Controls/ArrowRight
@onready var _dots: HBoxContainer = $Controls/Dots
@onready var _menu: HBoxContainer = $Controls/MenuBar
@onready var _abandon: Button = $Controls/MenuBar/BtnAbandon

var page: int = PAGE_EQUIP


func _ready() -> void:
	# 场景实例的根节点锚点不会被父场景保存，这里显式拉满，否则子页会缩成 0 尺寸。
	_equip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_core.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dress()
	_apply_fonts()

	# Controls 是铺满全屏的浮层，默认 MOUSE_FILTER_STOP 会挡住下层页面的点击，
	# 设成 IGNORE 让点击穿透；它自己的子节点（箭头、菜单按钮）照旧能收到事件。
	($Controls as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 状态行贴左上角、页签圆点贴右上角，避免压在最上排格子上。
	_status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status.offset_left = 44.0
	_status.offset_top = 14.0
	_status.offset_right = 640.0
	_status.offset_bottom = 36.0
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dots.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_dots.offset_left = -132.0
	_dots.offset_top = 14.0
	_dots.offset_right = -44.0
	_dots.offset_bottom = 38.0

	_left.pressed.connect(func() -> void: turn(-1))
	_right.pressed.connect(func() -> void: turn(1))

	_wire_menu()
	_show_page(PAGE_EQUIP)


## 宿主打开暂停界面之前调用。
## is_run 为 false（据点）时隐藏「放弃本局」，状态行换成据点提示。
func setup(is_run: bool, status_text: String) -> void:
	_abandon.visible = is_run
	_status.text = status_text
	_show_page(PAGE_EQUIP)
	focus_first()


func focus_first() -> void:
	_left.grab_focus()


## 左右翻页。dir = -1 上一页 / 1 下一页，循环。
func turn(dir: int) -> void:
	_show_page(posmod(page + dir, PAGE_COUNT))


func _show_page(i: int) -> void:
	page = i
	_equip.visible = i == PAGE_EQUIP
	_core.visible = i == PAGE_CORE

	for k in _dots.get_child_count():
		var d := _dots.get_child(k) as Label
		if d == null:
			continue
		d.add_theme_color_override("font_color", UITheme.CYAN if k == i else Color("39424f"))


func _wire_menu() -> void:
	for item in MENU_ITEMS:
		var b := _menu.get_node(item["node"]) as Button
		UITheme.style_button(b, item["accent"])
		b.custom_minimum_size = Vector2(0, b.size.y if b.size.y > 0.0 else 56.0)
		if b.disabled:
			continue
		var id: String = item["id"]
		b.pressed.connect(func() -> void: action.emit(id))
		b.mouse_entered.connect(func() -> void: hover.emit(id))
		b.focus_entered.connect(func() -> void: hover.emit(id))


## 用 `_input` 而不是 `_unhandled_input`：焦点在 Button 上时，方向键会被 GUI
## 的焦点导航吃掉，根本到不了 `_unhandled_input`，翻页就永远失效。
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("move_left"):
		turn(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		turn(1)
		get_viewport().set_input_as_handled()


func _dress() -> void:
	for b in [_left, _right]:
		var btn := b as Button
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 30)
		btn.add_theme_color_override("font_color", Color("7d8899"))
		btn.add_theme_color_override("font_hover_color", UITheme.CYAN)
		btn.add_theme_color_override("font_focus_color", UITheme.CYAN)
		btn.add_theme_color_override("font_pressed_color", UITheme.TEXT_BRIGHT)

	_set_label(_status, 13, UITheme.TEXT_DIM)


## 中文字形只能在运行时挂载 —— Label 不设字体就是豆腐块。
func _apply_fonts() -> void:
	var f := UITheme.get_font()
	for n in find_children("*", "Label", true, false):
		(n as Label).add_theme_font_override("font", f)


func _set_label(l: Label, size: int, color: Color) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)

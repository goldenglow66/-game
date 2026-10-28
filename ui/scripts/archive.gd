class_name UIArchiveScreen
extends Control
## 存档栏位界面（标题页「游戏存档」）。
##
## 独立场景：可单独打开 `ui/scenes/archive.tscn` 编辑布局，
## 也可 F6 运行 `ui/scenes/preview/archive_preview.tscn` 用假数据预览。
##
## 本脚本不引用 Game / Sfx —— 只发信号，存取行为由宿主决定。
## 五个栏位的内容由宿主通过 `refresh()` 填进来。

signal action(id: String)                   ## "back"
signal hover(id: String)
signal slot_action(id: String, index: int)  ## "save" / "load" / "delete"

const SLOT_COUNT := 5

@onready var _list: VBoxContainer = $Center/Panel/PanelMargin/PanelVBox/SlotList
@onready var _status: Label = $Center/Panel/PanelMargin/PanelVBox/Foot/Status
@onready var _back: Button = $Center/Panel/PanelMargin/PanelVBox/Foot/BtnBack

@onready var _confirm: Control = $ConfirmLayer
@onready var _confirm_panel: PanelContainer = $ConfirmLayer/ConfirmCenter/ConfirmPanel
@onready var _confirm_title: Label = $ConfirmLayer/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmTitle
@onready var _confirm_body: Label = $ConfirmLayer/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmBody
@onready var _btn_confirm: Button = $ConfirmLayer/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmRow/BtnConfirm
@onready var _btn_cancel: Button = $ConfirmLayer/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmRow/BtnCancel

var _slots: Array[PanelContainer] = []
## 待确认删除的栏位下标；-1 表示当前没有挂起的删除。
var _pending_delete: int = -1
## true = 「挑一个存档开玩」模式：每行只留一个「开始」主按钮，
## 存档管理用的「存入 / 删除」收起来。
var play_mode: bool = false


func _ready() -> void:
	_apply_fonts()
	_dress()
	for i in SLOT_COUNT:
		var row := _list.get_node("Slot%d" % (i + 1)) as PanelContainer
		_slots.append(row)
		_dress_row(row)

		var btn_save := _btn(row, "save")
		var btn_load := _btn(row, "load")
		var btn_del := _btn(row, "delete")
		UITheme.style_button(btn_save, UITheme.CYAN)
		UITheme.style_button(btn_load, UITheme.AMBER)
		UITheme.style_button(btn_del, UITheme.RED)

		var idx := i
		btn_save.pressed.connect(func() -> void: slot_action.emit("save", idx))
		# 同一个按钮两种语义：管理模式是「读取」，开玩模式是「开始」。
		btn_load.pressed.connect(func() -> void: slot_action.emit("play" if play_mode else "load", idx))
		btn_del.pressed.connect(func() -> void: _ask_delete(idx))
		btn_save.mouse_entered.connect(func() -> void: hover.emit("slot_save"))
		btn_load.mouse_entered.connect(func() -> void: hover.emit("slot_load"))
		btn_del.mouse_entered.connect(func() -> void: hover.emit("slot_delete"))

	UITheme.style_button(_back, Color("5a6474"))
	_back.pressed.connect(func() -> void: action.emit("back"))
	_back.mouse_entered.connect(func() -> void: hover.emit("back"))

	_dress_confirm()
	_confirm.visible = false
	_btn_confirm.pressed.connect(_confirm_delete)
	_btn_cancel.pressed.connect(func() -> void: _hide_confirm())
	for b in [_btn_confirm, _btn_cancel]:
		(b as Button).mouse_entered.connect(func() -> void: hover.emit("confirm"))


## 切换用法。
## play = true 时这个界面变成「选一本存档开玩」：隐藏存入与删除，
## 「读取」改名「开始」，标题与底栏文案也跟着换。
func set_mode(play: bool) -> void:
	play_mode = play
	var head := $Center/Panel/PanelMargin/PanelVBox/Head/HeadTitle as Label
	if head != null:
		head.text = "选 择 存 档" if play else "存 档 栏 位"
	_back.text = "返 回" if play else "返回标题"
	_status.text = "选一本存档继续本场下潜" if play else ""
	for i in _slots.size():
		var row := _slots[i]
		_btn(row, "save").visible = not play
		_btn(row, "delete").visible = not play
		_btn(row, "load").text = "开 始" if play else "读 取"


## 删除是不可逆的，先问一句。
func _ask_delete(index: int) -> void:
	_pending_delete = index
	_confirm_title.text = "删 除 栏 位 %02d？" % (index + 1)
	_confirm_body.text = "该栏位的内容会被永久删除，无法恢复。"
	_confirm.visible = true
	_btn_cancel.grab_focus()


func _confirm_delete() -> void:
	var idx := _pending_delete
	_hide_confirm()
	if idx >= 0:
		slot_action.emit("delete", idx)


func _hide_confirm() -> void:
	_confirm.visible = false
	_pending_delete = -1
	focus_first()


## 确认弹窗开着时，Esc 只关弹窗。
func _input(event: InputEvent) -> void:
	if not visible or not _confirm.visible:
		return
	if event.is_action_pressed("cancel"):
		_hide_confirm()
		get_viewport().set_input_as_handled()


func _dress_confirm() -> void:
	_confirm_panel.add_theme_stylebox_override("panel", _card(Color("12141cf4"), UITheme.RED.darkened(0.35), 4))
	_confirm_title.add_theme_font_size_override("font_size", 22)
	_confirm_title.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	_confirm_body.add_theme_font_size_override("font_size", 14)
	_confirm_body.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	UITheme.style_button(_btn_confirm, UITheme.RED)
	UITheme.style_button(_btn_cancel, UITheme.CYAN)
	for b in [_btn_confirm, _btn_cancel]:
		(b as Button).add_theme_font_size_override("font_size", 15)


func _btn(row: PanelContainer, name: String) -> Button:
	return row.get_node("RowMargin/RowHBox/Actions/Btn%s" % name.capitalize()) as Button


## rows: SLOT_COUNT 个字典 {title, desc, has_data, can_save}。
func refresh(rows: Array) -> void:
	# 刷新时顺手收起确认弹窗：删除成功后本来就该关掉。
	_confirm.visible = false
	_pending_delete = -1
	for i in _slots.size():
		var r: Dictionary = rows[i] if i < rows.size() else {}
		var row := _slots[i]
		var info_title := row.get_node("RowMargin/RowHBox/Info/InfoTitle") as Label
		var info_desc := row.get_node("RowMargin/RowHBox/Info/InfoDesc") as Label
		info_title.text = str(r.get("title", "空 栏 位"))
		info_desc.text = str(r.get("desc", "—"))
		_btn(row, "save").disabled = not bool(r.get("can_save", false))
		var has_data := bool(r.get("has_data", false))
		_btn(row, "load").disabled = not has_data
		_btn(row, "delete").disabled = not has_data

func set_status(text: String) -> void:
	_status.text = text


## 聚焦第一个可用按钮（键盘可达）。
func focus_first() -> bool:
	for b in find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.visible and not btn.disabled:
			btn.grab_focus()
			return true
	return false


func _apply_fonts() -> void:
	var f := UITheme.get_font()
	for n in find_children("*", "Label", true, false):
		(n as Label).add_theme_font_override("font", f)


func _card(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	return sb


func _dress() -> void:
	var panel := $Center/Panel as PanelContainer
	panel.add_theme_stylebox_override("panel", _card(Color("10131bf2"), UITheme.PANEL_LINE, 6))


func _dress_row(row: PanelContainer) -> void:
	row.add_theme_stylebox_override("panel", _card(Color(0.07, 0.08, 0.11, 0.9), Color("2a3040"), 3))

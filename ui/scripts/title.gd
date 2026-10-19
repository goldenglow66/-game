class_name UITitleScreen
extends Control
## 开始界面（标题页）。
##
## 独立场景：可在编辑器里单独打开 `ui/scenes/title.tscn` 编辑布局，
## 也可 F6 运行 `ui/scenes/preview/title_preview.tscn` 用假数据预览。
##
## 本脚本不引用 Game / Sfx / RunState —— 按钮只发 `action(id)` 信号，
## 由宿主（ui_root.gd 或预览脚本）决定这几个 id 该干什么。
## 「继续本局」是否出现也由宿主调 `set_resume_visible()` 决定。

signal action(id: String)
signal hover(id: String)

const BTN_IDS: Array[String] = [
	"resume_run",
	"abandon_run",
	"open_archive",
	"open_settings",
	"quit_game",
]
## 「游戏设置」当前只是摆位（场景里 disabled），给灰色点缀即可。
const ACCENTS: Array[Color] = [
	UITheme.GOLD,
	UITheme.AMBER,
	UITheme.CYAN,
	Color("5a6474"),
	Color("5a6474"),
]

@onready var _info: Label = $TitleInfo
@onready var _resume: Button = $MenuPanel/MenuMargin/MenuVBox/BtnResume
@onready var _abandon: Button = $MenuPanel/MenuMargin/MenuVBox/BtnHub

@onready var _confirm: Control = $ConfirmLayer
@onready var _confirm_panel: PanelContainer = $ConfirmLayer/ConfirmCenter/ConfirmPanel
@onready var _confirm_title: Label = $ConfirmLayer/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmTitle
@onready var _confirm_body: Label = $ConfirmLayer/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmBody
@onready var _btn_confirm: Button = $ConfirmLayer/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmRow/BtnConfirm
@onready var _btn_cancel: Button = $ConfirmLayer/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmRow/BtnCancel

var _buttons: Array[Button] = []


func _ready() -> void:
	_apply_fonts()
	_buttons = [
		_resume,
		_abandon,
		$MenuPanel/MenuMargin/MenuVBox/BtnArchive,
		$MenuPanel/MenuMargin/MenuVBox/BtnSettings,
		$MenuPanel/MenuMargin/MenuVBox/BtnWipe,
	]
	for i in _buttons.size():
		UITheme.style_button(_buttons[i], ACCENTS[i])
		_wire(_buttons[i], BTN_IDS[i])
	_dress_confirm()
	_confirm.visible = false


## 中文字形只能在运行时挂载 —— Label 不设字体就是豆腐块。
func _apply_fonts() -> void:
	var f := UITheme.get_font()
	for n in find_children("*", "Label", true, false):
		(n as Label).add_theme_font_override("font", f)


func _wire(b: Button, id: String) -> void:
	# 「放弃本局游戏」不可逆，先过一道确认再发信号。
	if id == "abandon_run":
		b.pressed.connect(_show_confirm)
	else:
		b.pressed.connect(func() -> void: action.emit(id))
	b.mouse_entered.connect(func() -> void: hover.emit(id))
	b.focus_entered.connect(func() -> void: hover.emit(id))


## 「放弃本局游戏」的二次确认框样式（标题页最危险的那个按钮）。
func _dress_confirm() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("12141cf4")
	sb.border_color = UITheme.RED.darkened(0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	_confirm_panel.add_theme_stylebox_override("panel", sb)

	_confirm_title.add_theme_font_size_override("font_size", 22)
	_confirm_title.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	_confirm_body.add_theme_font_size_override("font_size", 14)
	_confirm_body.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	UITheme.style_button(_btn_confirm, UITheme.RED)
	UITheme.style_button(_btn_cancel, UITheme.CYAN)
	for b in [_btn_confirm, _btn_cancel]:
		(b as Button).add_theme_font_size_override("font_size", 15)
		(b as Button).mouse_entered.connect(func() -> void: hover.emit("confirm"))

	_btn_confirm.pressed.connect(func() -> void: action.emit("abandon_run"))
	_btn_cancel.pressed.connect(_hide_confirm)


func _show_confirm() -> void:
	_confirm.visible = true
	# 默认焦点给「取消」，误按两下 Enter 不会丢进度。
	_btn_cancel.grab_focus()


func _hide_confirm() -> void:
	_confirm.visible = false
	_abandon.grab_focus()


## 确认弹窗开着时，Esc 只关弹窗。
func _input(event: InputEvent) -> void:
	if not _confirm.visible:
		return
	if event.is_action_pressed("cancel"):
		_hide_confirm()
		get_viewport().set_input_as_handled()


## 右下角的进度统计。宿主在显示标题页前调用。
func set_info(text: String) -> void:
	_info.text = text


## 「继续本局」只在存在续关存档时露出来。
func set_resume_visible(v: bool) -> void:
	_resume.visible = v


## 第一个按钮兼作入口：有存档时是「继续本局」，没有时是「进入安全屋」。
func set_resume_text(t: String) -> void:
	_resume.text = t


## 没有进行中的局时，「放弃本局游戏」无事可做，灰掉。
func set_abandon_enabled(v: bool) -> void:
	_abandon.disabled = not v
	if not v:
		_confirm.visible = false


## 聚焦第一个可用按钮（键盘可达）。
func focus_first() -> bool:
	for b in _buttons:
		if is_instance_valid(b) and b.visible and not b.disabled:
			b.grab_focus()
			return true
	return false

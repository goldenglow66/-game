class_name UITitleScreen
extends Control
## 开始界面（标题页）。
##
## 独立场景：可在编辑器里单独打开 `ui/scenes/title.tscn` 编辑布局，
## 也可 F6 运行 `ui/scenes/preview/title_preview.tscn` 用假数据预览。
##
## 本脚本不引用 Game / Sfx / RunState —— 按钮只发 `action(id)` 信号，
## 由宿主（ui_root.gd 或预览脚本）决定这几个 id 该干什么。

signal action(id: String)
signal hover(id: String)

const BTN_IDS: Array[String] = ["goto_hub", "begin_run", "wipe_save"]
const ACCENTS: Array[Color] = [UITheme.CYAN, UITheme.RED, Color("5a6474")]

@onready var _info: Label = $TitleInfo
var _buttons: Array[Button] = []


func _ready() -> void:
	_apply_fonts()
	_buttons = [
		$MenuPanel/MenuMargin/MenuVBox/BtnHub,
		$MenuPanel/MenuMargin/MenuVBox/BtnRun,
		$MenuPanel/MenuMargin/MenuVBox/BtnWipe,
	]
	for i in _buttons.size():
		UITheme.style_button(_buttons[i], ACCENTS[i])
		_wire(_buttons[i], BTN_IDS[i])


## 中文字形只能在运行时挂载 —— Label 不设字体就是豆腐块。
func _apply_fonts() -> void:
	var f := UITheme.get_font()
	for n in find_children("*", "Label", true, false):
		(n as Label).add_theme_font_override("font", f)


func _wire(b: Button, id: String) -> void:
	b.pressed.connect(func() -> void: action.emit(id))
	b.mouse_entered.connect(func() -> void: hover.emit(id))
	b.focus_entered.connect(func() -> void: hover.emit(id))


## 右下角的进度统计。宿主在显示标题页前调用。
func set_info(text: String) -> void:
	_info.text = text


## 聚焦第一个可用按钮（键盘可达）。
func focus_first() -> bool:
	for b in _buttons:
		if is_instance_valid(b) and b.visible and not b.disabled:
			b.grab_focus()
			return true
	return false

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
var _buttons: Array[Button] = []


func _ready() -> void:
	_apply_fonts()
	_buttons = [
		_resume,
		$MenuPanel/MenuMargin/MenuVBox/BtnHub,
		$MenuPanel/MenuMargin/MenuVBox/BtnArchive,
		$MenuPanel/MenuMargin/MenuVBox/BtnSettings,
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


## 「继续本局」只在存在续关存档时露出来。
func set_resume_visible(v: bool) -> void:
	_resume.visible = v


## 第一个按钮兼作入口：有存档时是「继续本局」，没有时是「进入安全屋」。
func set_resume_text(t: String) -> void:
	_resume.text = t


## 没有进行中的局时，「放弃本局游戏」无事可做，灰掉。
func set_abandon_enabled(v: bool) -> void:
	($MenuPanel/MenuMargin/MenuVBox/BtnHub as Button).disabled = not v


## 聚焦第一个可用按钮（键盘可达）。
func focus_first() -> bool:
	for b in _buttons:
		if is_instance_valid(b) and b.visible and not b.disabled:
			b.grab_focus()
			return true
	return false

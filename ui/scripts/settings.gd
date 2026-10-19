class_name UISettingsScreen
extends Control
## 游戏设置界面：上方内容区 + 底部四个页签。
##
## 独立场景：可在编辑器里单独打开 `ui/scenes/settings.tscn` 编辑布局，
## 也可 F6 运行 `ui/scenes/preview/settings_preview.tscn` 预览。
##
## 【按键页是本类唯一「有内容」的页签】每行一个动作，右侧「修改」按钮点下去
## 进入捕获状态，按下任意键/鼠标键即完成绑定。捕获逻辑纯 UI，不碰 InputMap ——
## 抓到键之后发 `keybind_changed` 给宿主，由 `ui_root` 调 `Game.set_keybind()` 落地。
##
## 【为什么按键页要读 InputActions】显示「当前绑定」需要知道实际生效的键，
## 而 InputActions 是纯静态工具类，读它没有副作用，预览场景自己 `register_all()` 就行。
##
## 音量与画面两页仍是占位文本。
signal action(id: String)
signal hover(id: String)
## 玩家按下了新键：`kb` 是键码、`mouse` 是鼠标键，两者只会有一个非零。
signal keybind_changed(action_id: String, kb: int, mouse: int)
## 玩家点了「恢复默认」。
signal keybind_reset()

const TAB_IDS: Array[String] = ["keys", "audio", "video", "quit"]
const TAB_TITLES: Array[String] = ["按 键 设 置", "音 量 设 置", "画 面 设 置", "退 出 设 置"]
## 音量 / 画面的占位内容；按键页是动态生成的，不走这里。
const PLACEHOLDERS := [
	[],
	["主音量　　待接入", "音乐　　　待接入", "音效　　　待接入"],
	["分辨率　　跟随显示器（独占全屏）", "全屏模式　锁定", "画质　　　低（GL 兼容渲染器）"],
	[],
]

## 行高与列宽。内容区已经套了 ScrollContainer，行数再多也只是滚动。
const ROW_H := 28
const NAME_W := 130.0
const BTN_W := 74.0

var page: int = 0

## 正在等待玩家按键的动作；空串表示当前没在捕获。
var _capture_action: String = ""
var _capture_label: Label = null
var _capture_btn: Button = null

@onready var _body: Control = $SettingsBody
@onready var _title: Label = $SettingsBody/ContentPanel/ContentMargin/ContentVBox/ContentHead/ContentTitle
@onready var _bar: ColorRect = $SettingsBody/ContentPanel/ContentMargin/ContentVBox/ContentHead/HeadBar
@onready var _list: VBoxContainer = $SettingsBody/ContentPanel/ContentMargin/ContentVBox/ContentBody/BodyVBox
@onready var _tabbar: HBoxContainer = $SettingsBody/TabBar

var _tabs: Array[Button] = []


func _ready() -> void:
	_wrap_body_in_scroll()
	_apply_fonts()
	_dress()
	_tabs = [
		$SettingsBody/TabBar/BtnKeys,
		$SettingsBody/TabBar/BtnAudio,
		$SettingsBody/TabBar/BtnVideo,
		$SettingsBody/TabBar/BtnQuit,
	]
	for i in _tabs.size():
		UITheme.style_button(_tabs[i], UITheme.CYAN if i < 3 else Color("5a6474"))
		var idx := i
		_tabs[i].pressed.connect(func() -> void: _on_tab(idx))
		_tabs[i].mouse_entered.connect(func() -> void: hover.emit(TAB_IDS[idx]))
		_tabs[i].focus_entered.connect(func() -> void: hover.emit(TAB_IDS[idx]))
	show_page(0)


## 宿主打开设置界面时调用。
func open_page(index: int = 0) -> void:
	_body.visible = true
	_cancel_capture()
	show_page(index)
	focus_first()


func close() -> void:
	_cancel_capture()
	_body.visible = false


func show_page(index: int) -> void:
	page = clampi(index, 0, TAB_IDS.size() - 1)
	_title.text = TAB_TITLES[page]
	_bar.color = UITheme.CYAN if page < 3 else Color("5a6474")
	for i in _tabs.size():
		_tabs[i].button_pressed = false
	if TAB_IDS[page] == "keys":
		_show_keys()
		return
	var lines: Array = PLACEHOLDERS[page] if page < PLACEHOLDERS.size() else []
	set_page_body(lines)


## 内容区按行填充纯文本；空数组时显示一句提示。
func set_page_body(lines: Array) -> void:
	_clear_list()
	if lines.is_empty():
		_list.add_child(UITheme.label("这里还没有可调的项目。", 15, UITheme.TEXT_DIM))
		return
	for i in lines.size():
		_list.add_child(UITheme.label(str(lines[i]), 16, UITheme.TEXT))


## 重建按键页的每一行。绑定变了（改键/恢复默认）之后由宿主调用。
func refresh_keys() -> void:
	if TAB_IDS[page] == "keys":
		_show_keys()


func _show_keys() -> void:
	_clear_list()
	_cancel_capture()
	for action in InputActions.REBINDABLE:
		_list.add_child(_make_key_row(action))
	_list.add_child(UITheme.spacer(6))
	# 「恢复默认」按钮撑不起来，用一行容器包住让它右对齐
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 0)
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(filler)
	var btn := Button.new()
	btn.text = "恢 复 默 认"
	btn.custom_minimum_size = Vector2(148.0, 34.0)
	UITheme.style_button(btn, UITheme.AMBER)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(func() -> void: keybind_reset.emit())
	btn.mouse_entered.connect(func() -> void: hover.emit("reset"))
	btn.focus_entered.connect(func() -> void: hover.emit("reset"))
	foot.add_child(btn)
	_list.add_child(foot)


func _make_key_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_H)
	row.add_theme_constant_override("separation", 12)

	var name_label := UITheme.label(InputActions.display_name(action), 15, UITheme.TEXT)
	name_label.custom_minimum_size = Vector2(NAME_W, 0.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var value_label := UITheme.label(InputActions.binding_text(action), 15, UITheme.CYAN)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)

	var btn := Button.new()
	btn.text = "修 改"
	btn.custom_minimum_size = Vector2(BTN_W, 24.0)
	UITheme.style_button(btn, UITheme.CYAN_DIM)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(func() -> void: _begin_capture(action, value_label, btn))
	btn.mouse_entered.connect(func() -> void: hover.emit("key_" + action))
	btn.focus_entered.connect(func() -> void: hover.emit("key_" + action))
	row.add_child(btn)
	return row


# ---------------- 按键捕获 ----------------

func _begin_capture(action: String, value_label: Label, btn: Button) -> void:
	_cancel_capture()
	_capture_action = action
	_capture_label = value_label
	_capture_btn = btn
	value_label.text = "按任意键…（Esc 取消）"
	value_label.add_theme_color_override("font_color", UITheme.AMBER)
	btn.disabled = true


func _cancel_capture() -> void:
	if _capture_action == "":
		return
	if is_instance_valid(_capture_label):
		_capture_label.text = InputActions.binding_text(_capture_action)
		_capture_label.add_theme_color_override("font_color", UITheme.CYAN)
	if is_instance_valid(_capture_btn):
		_capture_btn.disabled = false
	_capture_action = ""
	_capture_label = null
	_capture_btn = null


## 捕获用 `_input` 而不是 `_unhandled_input`：按钮有焦点时方向键、空格这些
## 会被 GUI 的焦点导航先吃掉，根本到不了 unhandled 阶段。
func _input(event: InputEvent) -> void:
	if _capture_action == "":
		return

	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		get_viewport().set_input_as_handled()
		var action := _capture_action
		if k.physical_keycode == KEY_ESCAPE:
			_cancel_capture()
			return
		_cancel_capture()
		keybind_changed.emit(action, int(k.physical_keycode), 0)
		return

	if event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if not m.pressed:
			return
		# 滚轮按下也当成普通键处理；但滚轮上下滚动不拦，否则界面滚不动
		if m.button_index == MOUSE_BUTTON_WHEEL_UP or m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return
		get_viewport().set_input_as_handled()
		var action2 := _capture_action
		_cancel_capture()
		keybind_changed.emit(action2, 0, int(m.button_index))
		return


func _clear_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()


func focus_first() -> bool:
	for b in _tabs:
		if is_instance_valid(b) and b.visible and not b.disabled:
			b.grab_focus()
			return true
	return false


func _on_tab(index: int) -> void:
	if index == TAB_IDS.size() - 1:
		# 最后一个页签是「退出设置」，发信号给宿主关窗。
		action.emit("close")
		return
	show_page(index)


## ContentBody 原本是 MarginContainer，内容一多就直接画到容器外面去（既不会滚动
## 也不会裁剪），14 行按键会压到页签栏上。这里在运行时套一层 ScrollContainer：
## 行数再多也只是滚动条出现，版面不会被撑破。
func _wrap_body_in_scroll() -> void:
	var body := $SettingsBody/ContentPanel/ContentMargin/ContentVBox/ContentBody as MarginContainer
	var vbox := body.get_node("BodyVBox") as VBoxContainer
	body.remove_child(vbox)
	# 换了子节点之后 ContentBody 的最小高度会变成 0（ScrollContainer 不按内容撑开），
	# 必须显式要求它吃掉 VBox 里的剩余空间，否则内容区高度是 0、看起来一片空白。
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	scroll.add_child(vbox)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _dress() -> void:
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	_bar.color = UITheme.CYAN
	var panel := $SettingsBody/ContentPanel as PanelContainer
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("12141cf2"), UITheme.PANEL_LINE, 6, 1))


## 中文字形只能在运行时挂载 —— Label 不设字体就是豆腐块。
func _apply_fonts() -> void:
	var f := UITheme.get_font()
	for n in find_children("*", "Label", true, false):
		(n as Label).add_theme_font_override("font", f)

extends Control
## 设置界面独立预览。
##
## 打开 `ui/scenes/preview/settings_preview.tscn` 按 F6 即可看到设置界面，
## 不需要启动游戏、不依赖 Game / Sfx / RunState 任何一个单例。
##
## 按键页会真的重绑 InputMap（仅限本次预览进程），但不会写存档 ——
## 所以可以放心在这儿试手感。点「退出设置」会把界面收起来。

@onready var _settings: Control = $SettingsLayer


func _ready() -> void:
	# 预览环境没有 Game 单例，InputMap 还是空的，得自己铺一遍默认绑定，
	# 否则按键页每一行都会显示 "—"。
	InputActions.register_all()
	_settings.visible = true
	_settings.call("open_page", 0)
	_settings.connect("action", _on_action)
	_settings.connect("hover", _on_hover)
	_settings.connect("keybind_changed", _on_keybind_changed)
	_settings.connect("keybind_reset", _on_keybind_reset)


func _on_action(id: String) -> void:
	print("[settings preview] action: ", id)
	if id == "close":
		_settings.visible = false


func _on_hover(id: String) -> void:
	print("[settings preview] hover: ", id)


func _on_keybind_changed(action_id: String, kb: int, mouse: int) -> void:
	var kicked := InputActions.find_conflict(action_id, kb, mouse)
	var note := "" if kicked == "" else "  (与「%s」冲突，主场景里会把它踢掉)" % InputActions.display_name(kicked)
	print("[settings preview] keybind %s -> kb=%d mouse=%d%s" % [action_id, kb, mouse, note])
	# 预览里不模拟「把键从冲突动作身上摘掉」那一步 —— 那是 Game.set_keybind() 的活，
	# 主场景里会真的踢掉并弹提示。这里只管把新绑定画出来。
	var binds := Game_binds()
	binds[action_id] = {"kb": [kb] if kb != 0 else [], "mouse": [mouse] if mouse != 0 else []}
	InputActions.apply_custom(binds)
	_settings.call("refresh_keys")


func _on_keybind_reset() -> void:
	print("[settings preview] reset keybinds")
	InputActions.apply_custom({})
	_settings.call("refresh_keys")


## 预览里临时攒一份「改过的动作表」，供 apply_custom 重铺。
func Game_binds() -> Dictionary:
	if not has_meta("preview_binds"):
		set_meta("preview_binds", {})
	return get_meta("preview_binds")

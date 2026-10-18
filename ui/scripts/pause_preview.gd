extends Control
## 暂停界面独立预览。
##
## 打开 `ui/scenes/preview/pause_preview.tscn` 按 F6 即可看到暂停界面，
## 不需要启动游戏、不需要存档、不依赖 Game / Sfx / RunState 任何一个单例。
## 按钮点击只会打印到输出面板，不会真的继续或退出。

const PREVIEW_STATUS := "已暂停 · 织网 第 2 扇区 · 难度 普通 · 已清房间 5"

@onready var _pause: Control = $PauseLayer


func _ready() -> void:
	_pause.visible = true
	_pause.call("setup", true, PREVIEW_STATUS)
	_pause.connect("action", _on_action)
	_pause.connect("hover", _on_hover)
	_pause.call("focus_first")


func _on_action(id: String) -> void:
	print("[pause preview] action: ", id)


func _on_hover(id: String) -> void:
	print("[pause preview] hover: ", id)

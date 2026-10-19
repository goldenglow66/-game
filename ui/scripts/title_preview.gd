extends Control
## 标题页独立预览。
##
## 打开 `ui/scenes/preview/title_preview.tscn` 按 F6 即可看到开始界面，
## 不需要启动游戏、不需要存档、不依赖 Game / Sfx / RunState 任何一个单例。
## 按钮点击只会打印到输出面板，不会真的进游戏。

const PREVIEW_INFO := "已出击 5 次 · 最长下潜 3 扇区 · 织网碎片 72"

@onready var _title: Control = $TitleLayer


func _ready() -> void:
	_title.visible = true
	_title.call("set_info", PREVIEW_INFO)
	_title.call("set_resume_visible", true)
	_title.connect("action", _on_action)
	_title.connect("hover", _on_hover)
	_title.call("focus_first")


func _on_action(id: String) -> void:
	print("[title preview] action: ", id)


func _on_hover(id: String) -> void:
	print("[title preview] hover: ", id)

extends Control
## 暂停一级界面的完整预览：装备总览页 ↔ 核心页，可左右切换。
##
## 打开 `ui/scenes/preview/pause_menu_preview.tscn` 按 F6，
## 用 ←/→ 或点击两侧箭头翻页，点底部「设置」看退出项。
## 这里的按钮只打印到输出面板，不会真的继续或退出。

const PREVIEW_STATUS := "已暂停 · 织网 第 2 扇区 · 难度 普通 · 已清房间 5"

@onready var _menu: Control = $PauseMenu


func _ready() -> void:
	_menu.call("setup", false, PREVIEW_STATUS)
	_menu.connect("action", func(id: String) -> void: print("[pause menu preview] action: ", id))
	_menu.connect("hover", func(id: String) -> void: print("[pause menu preview] hover: ", id))

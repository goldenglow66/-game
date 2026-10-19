extends Control
## 存档栏位界面的独立预览。
##
## 打开 `ui/scenes/preview/archive_preview.tscn` 按 F6 即可看到界面，
## 用假数据填满五个栏位，点按钮只会打印到输出面板，不碰任何存档文件。

const MOCK: Array[Dictionary] = [
	{
		"title": "织网 第 2 扇区 · 房间 3",
		"desc": "血量 96/120 · 已清房间 5 · 2026-10-16 14:03",
		"has_data": true,
	},
	{
		"title": "织网 第 1 扇区 · 房间 7",
		"desc": "血量 120/120 · 已清房间 2 · 2026-10-15 22:41",
		"has_data": true,
	},
	{"title": "空 栏 位", "desc": "—", "has_data": false},
	{"title": "空 栏 位", "desc": "—", "has_data": false},
	{"title": "空 栏 位", "desc": "—", "has_data": false},
]

@onready var _archive: Control = $ArchiveLayer


func _ready() -> void:
	_archive.connect("action", _on_action)
	_archive.connect("slot_action", _on_slot_action)

	var rows: Array = []
	for m in MOCK:
		var r := (m as Dictionary).duplicate()
		r["can_save"] = true
		rows.append(r)
	_archive.call("refresh", rows)
	_archive.call("set_status", "当前进度可存入任意栏位")
	_archive.call("focus_first")


func _on_action(id: String) -> void:
	print("[archive preview] action: ", id)


func _on_slot_action(id: String, index: int) -> void:
	print("[archive preview] slot_action: ", id, " #", index)

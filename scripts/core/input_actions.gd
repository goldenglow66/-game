class_name InputActions
extends RefCounted
## 运行时注册输入映射。
##
## 为什么不写在 project.godot 里：手写 InputEvent 的序列化文本极易出错且无法阅读。
## 这里用代码声明，同时天然支持后续做「重绑按键」界面。

## 动作 -> { keyboard: Array[int], mouse: Array[int], joy_buttons: Array[int] }
const BINDINGS := {
	"move_left":        {"kb": [KEY_A, KEY_LEFT],  "mouse": [], "joy": [JOY_BUTTON_DPAD_LEFT]},
	"move_right":       {"kb": [KEY_D, KEY_RIGHT], "mouse": [], "joy": [JOY_BUTTON_DPAD_RIGHT]},
	"move_up":          {"kb": [KEY_W, KEY_UP],    "mouse": [], "joy": [JOY_BUTTON_DPAD_UP]},
	"move_down":        {"kb": [KEY_S, KEY_DOWN],  "mouse": [], "joy": [JOY_BUTTON_DPAD_DOWN]},
	"jump":             {"kb": [KEY_SPACE],        "mouse": [], "joy": [JOY_BUTTON_A]},
	"dash":             {"kb": [KEY_SHIFT],        "mouse": [], "joy": [JOY_BUTTON_RIGHT_SHOULDER]},
	"attack":           {"kb": [KEY_J],            "mouse": [MOUSE_BUTTON_LEFT], "joy": [JOY_BUTTON_X]},
	"guard":            {"kb": [KEY_K],            "mouse": [MOUSE_BUTTON_RIGHT], "joy": [JOY_BUTTON_LEFT_SHOULDER]},
	"gun":              {"kb": [KEY_L],            "mouse": [MOUSE_BUTTON_MIDDLE], "joy": [JOY_BUTTON_RIGHT_SHOULDER]},
	"ghost":            {"kb": [KEY_I],            "mouse": [], "joy": [JOY_BUTTON_Y]},
	"interact":         {"kb": [KEY_E],            "mouse": [], "joy": [JOY_BUTTON_B]},
	"probe":            {"kb": [KEY_Q],            "mouse": [], "joy": [JOY_BUTTON_LEFT_STICK]},
	"pause":            {"kb": [KEY_ESCAPE],       "mouse": [], "joy": [JOY_BUTTON_START]},
	"confirm":          {"kb": [KEY_ENTER, KEY_SPACE], "mouse": [], "joy": [JOY_BUTTON_A]},
	"cancel":           {"kb": [KEY_ESCAPE],       "mouse": [], "joy": [JOY_BUTTON_B]},
	"cycle_weapon":     {"kb": [KEY_TAB],          "mouse": [], "joy": [JOY_BUTTON_DPAD_UP]},
	"map":              {"kb": [KEY_M],            "mouse": [], "joy": [JOY_BUTTON_BACK]},
	"debug_toggle":     {"kb": [KEY_F3],           "mouse": [], "joy": []},
}

## 需要摇杆模拟轴的动作
const AXIS_BINDINGS := {
	"move_left":  [{"axis": JOY_AXIS_LEFT_X, "value": -1.0}],
	"move_right": [{"axis": JOY_AXIS_LEFT_X, "value": 1.0}],
	"move_up":    [{"axis": JOY_AXIS_LEFT_Y, "value": -1.0}],
	"move_down":  [{"axis": JOY_AXIS_LEFT_Y, "value": 1.0}],
}


static func register_all() -> void:
	for action in BINDINGS.keys():
		var data: Dictionary = BINDINGS[action]
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)

		for code in data.get("kb", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)

		for button in data.get("mouse", []):
			var mb := InputEventMouseButton.new()
			mb.button_index = button
			InputMap.action_add_event(action, mb)

		for jb in data.get("joy", []):
			var jbe := InputEventJoypadButton.new()
			jbe.button_index = jb
			InputMap.action_add_event(action, jbe)

		for axis_data in AXIS_BINDINGS.get(action, []):
			var jm := InputEventJoypadMotion.new()
			jm.axis = axis_data["axis"]
			jm.axis_value = axis_data["value"]
			InputMap.action_add_event(action, jm)


## 返回供 UI 显示的按键提示文本
static func hint(action: String) -> String:
	if not BINDINGS.has(action):
		return "?"
	var data: Dictionary = BINDINGS[action]
	var kb: Array = data.get("kb", [])
	if kb.is_empty():
		return "?"
	var names: Array[String] = []
	for code in kb:
		names.append(OS.get_keycode_string(code))
	return "/".join(names)

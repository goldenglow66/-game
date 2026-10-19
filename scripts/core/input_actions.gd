class_name InputActions
extends RefCounted
## 运行时注册输入映射，并支持玩家自定义按键。
##
## 【为什么不写在 project.godot 里】
## 手写 InputEvent 的序列化文本极易出错且无法阅读。这里用代码声明，
## 同时天然支持「重绑按键」：默认表是 `BINDINGS`，玩家改动另存一份覆盖上去。
##
## 【三层结构】
## - `BINDINGS`        ：出厂默认绑定（只读常量）
## - `Game.settings["keybinds"]` ：玩家改动过的动作，只存改过的那些
## - 实际生效的 InputMap ：`register_all()` 先铺默认，`apply_custom()` 再盖自定义
## 所以「恢复默认」= 把 settings["keybinds"] 清空后重新 apply。

## 动作 -> { kb: Array[int] 键码, mouse: Array[int] 鼠标键, joy: Array[int] 手柄键 }
## 键码用 `physical_keycode`（按物理位置，不随输入法/键盘布局变）。
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

## 允许玩家重绑的动作，同时也是设置界面的显示顺序。
##
## 刻意排除的四个：
## - `confirm` / `cancel` / `pause`：界面通用键，改了可能把自己锁在菜单里出不来
## - `debug_toggle`：开发用，不该出现在玩家界面
const REBINDABLE: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "dash", "attack", "guard", "gun",
	"ghost", "interact", "probe", "cycle_weapon", "map",
]

## 动作 -> 界面上显示的中文名。
const DISPLAY := {
	"move_left": "左移",
	"move_right": "右移",
	"move_up": "上移",
	"move_down": "下移",
	"jump": "跳跃",
	"dash": "冲刺",
	"attack": "挥剑",
	"guard": "格挡",
	"gun": "铳击",
	"ghost": "幽灵形态",
	"interact": "交互",
	"probe": "探测",
	"cycle_weapon": "切换铳元素",
	"map": "地图",
	"pause": "暂停",
	"confirm": "确认",
	"cancel": "取消",
}


## 按出厂默认铺一遍 InputMap。启动时先调它，再用 apply_custom() 盖上玩家改动。
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


## 把玩家自定义覆盖到默认绑定上。
##
## `custom` 形如 `{"attack": {"kb": [KEY_J], "mouse": [MOUSE_BUTTON_LEFT]}}`，
## 只含玩家改过的动作。**只替换键鼠，手柄事件保持默认**——
## 玩家改键主要在键鼠上，重绑手柄需要另一套界面，本版不做。
static func apply_custom(custom: Dictionary) -> void:
	register_all()
	if custom.is_empty():
		return
	for key in custom.keys():
		var action := str(key)
		if not InputMap.has_action(action) or not BINDINGS.has(action):
			continue
		var d = custom[key]
		if typeof(d) != TYPE_DICTIONARY:
			continue

		# 先把手柄与轴事件挑出来留着，再清空重加键鼠
		var kept: Array = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventMouseButton:
				continue
			kept.append(ev)
		InputMap.action_erase_events(action)
		for ev in kept:
			InputMap.action_add_event(action, ev)

		for code in d.get("kb", []):
			var k := InputEventKey.new()
			k.physical_keycode = int(code)
			InputMap.action_add_event(action, k)
		for btn in d.get("mouse", []):
			var m := InputEventMouseButton.new()
			m.button_index = int(btn)
			InputMap.action_add_event(action, m)


## 动作当前的键鼠绑定文本，形如 "J / 鼠标左键"。没有键鼠绑定时返回 "—"。
static func binding_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var parts: Array[String] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			parts.append(key_name(ev.physical_keycode))
		elif ev is InputEventMouseButton:
			parts.append(mouse_name(ev.button_index))
	if parts.is_empty():
		return "—"
	return " / ".join(parts)


## 键码 → 可读名字。个别键 OS 给的英文名不直观，这里补中文。
static func key_name(code: int) -> String:
	match code:
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_ESCAPE: return "Esc"
		KEY_SPACE: return "空格"
		KEY_ENTER: return "回车"
		KEY_TAB: return "Tab"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
	var s := OS.get_keycode_string(code)
	return s if s != "" else "键%d" % code


static func mouse_name(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT: return "鼠标左键"
		MOUSE_BUTTON_RIGHT: return "鼠标右键"
		MOUSE_BUTTON_MIDDLE: return "鼠标中键"
		MOUSE_BUTTON_WHEEL_UP: return "滚轮上"
		MOUSE_BUTTON_WHEEL_DOWN: return "滚轮下"
		MOUSE_BUTTON_XBUTTON1: return "鼠标侧键1"
		MOUSE_BUTTON_XBUTTON2: return "鼠标侧键2"
	return "鼠标%d" % button


## 查这个键是否已经被别的**可重绑**动作占用，返回那个动作的 id（没占用返回空串）。
##
## 只查 REBINDABLE 里的动作：`confirm` / `pause` 这些通用键和移动键撞车是正常的
## （空格既是跳跃也是确认），不该被当成冲突清掉。
static func find_conflict(action: String, kb: int, mouse: int) -> String:
	for other in REBINDABLE:
		if other == action:
			continue
		for ev in InputMap.action_get_events(other):
			if kb != 0 and ev is InputEventKey and int(ev.physical_keycode) == kb:
				return other
			if mouse != 0 and ev is InputEventMouseButton and int(ev.button_index) == mouse:
				return other
	return ""


## 供界面显示的文本；玩家改过的动作会在末尾标注一下。
static func display_name(action: String) -> String:
	return str(DISPLAY.get(action, action))

class_name UITheme
extends RefCounted
## 统一视觉风格：《笼中墟影》的「冷峻、潮湿、低饱和霓虹」。
## 同时负责中文字体加载 —— Godot 默认字体不含 CJK 字形，必须在运行时挂载系统中文字体。

# ---------------- 配色 ----------------
const BG          := Color("0a0b10")
const BG_DEEP     := Color("06070b")
const PANEL       := Color("12141cf2")
const PANEL_LINE  := Color("2a3040")
const TEXT        := Color("c6d0dc")
const TEXT_DIM    := Color("7d8899")
const TEXT_BRIGHT := Color("eef3f8")

const CYAN        := Color("4fd6c8")   # 织网 / 幽灵
const CYAN_DIM    := Color("2b7d78")
const VIOLET      := Color("a98bf0")   # 幽灵能量
const AMBER       := Color("ffb347")   # 铳 / 热量
const RED         := Color("e0554f")   # 危险 / 污染
const GREEN       := Color("7fd97f")   # 回复
const GOLD        := Color("e8c86a")   # 传说 / 盲区币

const RARITY := {
	"common": Color("9aa6b4"),
	"rare":   Color("4fa8e0"),
	"epic":   Color("a98bf0"),
	"legend": Color("e8c86a"),
}

static var _font: Font = null
static var _font_path: String = ""


# ---------------- 字体 ----------------

static func get_font() -> Font:
	if _font != null:
		return _font
	# 1) 工程自带字体优先
	for p in ["res://assets/fonts/main.ttf", "res://assets/fonts/main.otf", "res://assets/fonts/main.ttc"]:
		if ResourceLoader.exists(p):
			var r = load(p)
			if r is Font:
				_font = r
				_font_path = p
				return _font
	# 2) 系统中文字体
	var candidates := [
		"Microsoft YaHei", "微软雅黑", "SimHei", "黑体",
		"Noto Sans CJK SC", "Source Han Sans SC", "PingFang SC",
		"WenQuanYi Micro Hei", "SimSun", "DengXian",
	]
	for fname in candidates:
		var path := OS.get_system_font_path(fname, 400, 100, false)
		if path != "" and FileAccess.file_exists(path):
			var f := FontFile.new()
			if f.load_dynamic_font(path) == OK:
				_font = f
				_font_path = path
				return _font
	# 3) 兜底：遍历系统字体表里第一个能加载的
	for fname in OS.get_system_fonts():
		var path := OS.get_system_font_path(fname, 400, 100, false)
		if path == "" or not FileAccess.file_exists(path):
			continue
		var f := FontFile.new()
		if f.load_dynamic_font(path) == OK:
			_font = f
			_font_path = path
			return _font
	_font = ThemeDB.fallback_font
	_font_path = "<fallback>"
	return _font


static func font_source() -> String:
	if _font == null:
		get_font()
	return _font_path


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = get_font()
	t.default_font_size = 17
	return t


# ---------------- 样式盒 ----------------

static func panel_style(bg: Color = PANEL, border: Color = PANEL_LINE, radius: int = 4, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func accent_style(accent: Color, bg: Color = Color(0.07, 0.08, 0.11, 0.95)) -> StyleBoxFlat:
	var sb := panel_style(bg, accent, 3, 2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb


static func rarity_color(rarity: String) -> Color:
	return RARITY.get(rarity, TEXT)


# ---------------- 常用控件工厂 ----------------

static func label(text: String, size: int = 17, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", get_font())
	return l


static func rich(text: String, size: int = 17, color: Color = TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.add_theme_font_override("normal_font", get_font())
	return r


## 一根横向发光分隔线
static func divider(color: Color = PANEL_LINE, height: int = 1) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(0, height)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func spacer(h: float = 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## 科幻风标题：左侧色块 + 大写感文字
static func title_row(text: String, accent: Color = CYAN, size: int = 22) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(4, float(size) + 6.0)
	box.add_child(bar)
	box.add_child(label(text, size, TEXT_BRIGHT))
	return box

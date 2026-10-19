class_name UITheme
extends RefCounted
## 统一视觉风格：《笼中墟影》的「冷峻、潮湿、低饱和霓虹」。
##
## 【怎么用】所有界面脚本都从这里取颜色和样式，**不要在界面里写死颜色值** ——
## 想整体调色调，只改这一个文件就够了。
##
## 【它还负责中文字体】Godot 内置字体不含 CJK 字形，不挂字体的话中文全是方块。
## 所以每个 Label / Button 都要在运行时 `add_theme_font_override("font", UITheme.get_font())`。
## `get_font()` 带三级降级：工程自带字体 → 系统中文字体候选表 → ThemeDB 兜底。
##
## 【配色语义】
## - CYAN  织网 / 幽灵 / 中性强调（绝大多数可点击元素）
## - VIOLET 幽灵能量
## - AMBER 铳 / 热量 / 需要警惕但不算危险的操作
## - RED   危险 / 污染 / 不可逆操作（删除、放弃本局）
## - GREEN 回复
## - GOLD  传说品质 / 盲区币

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

## 词条品质 → 颜色。三选一卡片、背包列表都用它。
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


## 统一的菜单按钮外观（标题页 / 暂停页共用）。
## 从 title.gd 的就地配置搬来，逐值一致，避免两个界面以后分叉。
static func style_button(b: Button, accent: Color) -> void:
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", get_font())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", accent_style(accent.darkened(0.45), Color(0.06, 0.07, 0.10, 0.92)))
	b.add_theme_stylebox_override("hover", accent_style(accent, Color(0.10, 0.12, 0.16, 0.96)))
	b.add_theme_stylebox_override("pressed", accent_style(accent.darkened(0.2), Color(0.05, 0.06, 0.09, 0.98)))
	b.add_theme_stylebox_override("disabled", accent_style(Color("343b47"), Color(0.05, 0.05, 0.07, 0.85)))
	var focus_box := accent_style(Color.WHITE, Color(0.18, 0.21, 0.28, 0.98))
	focus_box.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus_box)
	b.add_theme_color_override("font_color", TEXT_BRIGHT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("5d6673"))


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

# 画面の共通部品(色・字体・ラベル・ボタン・置き場所・角を切った板)。画面設計書 §8・§10 の色はここに置く。
# 見た目の既定は ui/theme.tres(tools/make_theme.gd が作る。project の gui/theme/custom で全部の Control に付く)。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。
extends RefCounted

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"
const DISPLAY := "res://assets/fonts/ChakraPetch-Subset.ttf"  # 題字・数字・盤の刻印(ASCII だけ。日本語は Noto へ落とす)

# 盤の意味の色(仕様の色。枠や飾りには使わない)
const C_BUG := Color("FF4D4D")
const C_NEST := Color("B3122E")
const C_JUMPER := Color("E04BD6")
const C_WARN := Color("FFB84D")
const C_GOOD := Color("7EE787")
const C_WHITE := Color("FFFFFF")
# 検疫の検査室の板(v0.3.0)。墨の青緑・板・罫・検査光の青緑・字
const C_BG := Color("091317")
const C_SHEET := Color("0F2026")
const C_RULE := Color("23414A")
const C_KEY := Color("172A31")
const C_KEY_TEXT := Color("D2E5E9")
const C_ACCENT := Color("45E0EE")
const C_TEXT := Color("E3F1F3")
const C_DIM := Color("8EA9B1")
# 昔の名前(画面のコードが使う)
const C_PANEL := C_SHEET
const C_EDGE := C_RULE
const C_SEL := C_ACCENT

const CUT := 12  # 板とボタンの角の切れ込み

static var _fonts := {}
static var _num: Font = null


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


# 数字と題字の字体。ASCII に無い字(点・つなぎ など)は Noto Sans JP の 700 で描く。
static func num_font() -> Font:
	if _num == null:
		var fv := FontVariation.new()
		fv.base_font = load(DISPLAY)
		fv.fallbacks = [font(700)]
		_num = fv
	return _num


static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# 角を切った箱(corner_detail 1 で丸めの代わりに斜めに切る)。both: 4 隅とも切る。偽なら左上と右下だけ(検査票の札の形)。
static func cut_box(bg: Color, border: Color, width: int, cut: int = CUT, both: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.corner_detail = 1
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_radius_top_right = cut if both else 0
	s.corner_radius_bottom_left = cut if both else 0
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.anti_aliasing = true
	return s


static func box(bg: Color, border: Color, width: int, radius: int = 6) -> StyleBoxFlat:
	return cut_box(bg, border, width, radius, true)


# ボタン。見た目(5 つの状態)は theme.tres。node_name は自動の確認が押す時の目印。
# キーボードの選択は ui/menu.gd が set_selected で型の変種(SelButton)に替える。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # Tab・矢印を Godot のフォーカスの移動に使わせない(選択は menu が持つ)
	b.add_theme_font_size_override("font_size", size)
	return b


static func set_selected(b: Button, on: bool) -> void:
	b.theme_type_variation = &"SelButton" if on else &""


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


# 角を切った板を描く(_draw の中から)。左上と右下を切る。edge が透明なら縁なし。
static func draw_plate(ci: CanvasItem, r: Rect2, fill: Color, edge: Color, cut: float = CUT, width: float = 2.0) -> void:
	var p := PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - cut),
		r.end - Vector2(cut, 0), Vector2(r.position.x, r.end.y), r.position + Vector2(0, cut)])
	if fill.a > 0.0:
		ci.draw_colored_polygon(p, fill)
	if edge.a > 0.0:
		p.append(p[0])
		ci.draw_polyline(p, edge, width, true)


# 数字を 1 字ずつ同じ幅の升に置いて描く(数字が変わっても横に揺れない)。x は align に合わせた基準(左・中・右)。描いた幅を返す。
static func draw_digits(ci: CanvasItem, f: Font, x: float, baseline: float, text: String, size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, outline: int = 0, outline_color: Color = C_BG) -> float:
	var total := digits_width(f, text, size)
	var cell := f.get_char_size("0".unicode_at(0), size).x
	var px := x - (total / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else total if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
	for c in text:
		var cw := f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var w := cell if _is_digit(c) else cw
		var at := Vector2(px + (w - cw) / 2.0, baseline)
		if outline > 0:
			ci.draw_string_outline(f, at, c, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
		ci.draw_string(f, at, c, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		px += w
	return total


static func digits_width(f: Font, text: String, size: int) -> float:
	var cell := f.get_char_size("0".unicode_at(0), size).x
	var total := 0.0
	for c in text:
		total += cell if _is_digit(c) else f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return total


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


# 0→1 を減速で(入りの動き)。
static func ease_out(k: float) -> float:
	var t := clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)


# 相対輝度のコントラスト比(WCAG 2)。色の板のテストが使う。
static func contrast(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

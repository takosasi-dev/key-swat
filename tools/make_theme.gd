# ui/theme.tres を作る(v0.3.0 の見た目。project の gui/theme/custom で全部の Control に付く)。色を変えたら回し直してコミットする。
#     python tools/gd.py run res://tools/make_theme.gd
# ボタンは normal / hover / focus / pressed / disabled と、キーボードで選んだ時の型の変種 SelButton。入力欄・メニュー・スクロールバー・つまみ・チェックも作る。
extends SceneTree

const Kit := preload("res://ui/kit.gd")
const OUT := "res://ui/theme.tres"


func _initialize() -> void:
	var t := build()
	var err := ResourceSaver.save(t, OUT)
	print("theme: %s -> %s" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


static func _sb(bg: Color, edge: Color, w: int, cut: int = Kit.CUT) -> StyleBoxFlat:
	var s := Kit.cut_box(bg, edge, w, cut)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# 角を切った小さな四角の絵(チェックとつまみ用)。
static func _icon(size: int, fill: Color, edge: Color, inner: Color = Color(0, 0, 0, 0)) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cut := size / 4
	for y in size:
		for x in size:
			var corner := (x + y < cut) or ((size - 1 - x) + (size - 1 - y) < cut)
			if corner:
				continue
			var on_edge := x < 2 or y < 2 or x >= size - 2 or y >= size - 2 or (x + y < cut + 2) or ((size - 1 - x) + (size - 1 - y) < cut + 2)
			var c := edge if on_edge else fill
			if inner.a > 0.0 and x >= 5 and y >= 5 and x < size - 5 and y < size - 5:
				c = inner
			img.set_pixel(x, y, c)
	# PortableCompressedTexture2D(可逆の圧縮)は Web の書き出しで「texture is null」を出したので、生の画素の ImageTexture で持つ
	return ImageTexture.create_from_image(img)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = Kit.font(500)
	t.default_font_size = 22
	var ink := Kit.C_BG
	var sheet := Kit.C_SHEET
	var acc := Kit.C_ACCENT

	# ボタン: 札の形(左上と右下を切る)。選ぶと左に太い検査光の帯
	t.set_font("font", "Button", Kit.font(700))
	t.set_font_size("font_size", "Button", 26)
	t.set_stylebox("normal", "Button", _sb(sheet, Kit.C_RULE.lightened(0.15), 2))
	t.set_stylebox("hover", "Button", _sb(sheet.lerp(acc, 0.1), acc.lerp(Kit.C_RULE, 0.35), 2))
	var focus := _sb(Color(0, 0, 0, 0), acc, 3)
	focus.border_width_left = 10
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("pressed", "Button", _sb(acc, acc, 2))
	t.set_stylebox("disabled", "Button", _sb(ink, Color(Kit.C_RULE, 0.7), 2))
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "Button", Kit.C_TEXT)
	t.set_color("font_pressed_color", "Button", ink)
	t.set_color("font_hover_pressed_color", "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(Kit.C_DIM, 0.55))
	t.set_constant("outline_size", "Button", 0)
	t.set_type_variation("SelButton", "Button")
	var sel := _sb(sheet.lerp(acc, 0.18), acc, 3)
	sel.border_width_left = 10
	sel.content_margin_left = 28
	t.set_stylebox("normal", "SelButton", sel)
	t.set_stylebox("hover", "SelButton", sel)
	t.set_color("font_color", "SelButton", Kit.C_WHITE)
	t.set_color("font_hover_color", "SelButton", Kit.C_WHITE)
	var sel_off := _sb(sheet.lerp(acc, 0.08), Color(acc, 0.6), 3)  # 選んであるがまだ押せない(結果の「もう1回」の最初の 300 ms)
	sel_off.border_width_left = 10
	sel_off.content_margin_left = 28
	t.set_stylebox("disabled", "SelButton", sel_off)
	t.set_color("font_disabled_color", "SelButton", Color(Kit.C_TEXT, 0.6))

	# 字
	t.set_color("font_color", "Label", Kit.C_TEXT)

	# 板
	t.set_stylebox("panel", "Panel", _sb(sheet, Kit.C_RULE, 2))
	t.set_stylebox("panel", "PanelContainer", _sb(sheet, Kit.C_RULE, 2))

	# 入力欄(結果の共有する文字の枠)
	for type: String in ["TextEdit", "LineEdit"]:
		var n := _sb(Color("0B1A1F"), Kit.C_RULE, 2, 8)
		n.content_margin_left = 14
		n.content_margin_right = 14
		var f := n.duplicate() as StyleBoxFlat
		f.border_color = acc
		t.set_stylebox("normal", type, n)
		t.set_stylebox("read_only", type, n)
		t.set_stylebox("focus", type, f)
		t.set_font("font", type, Kit.font(500))
		t.set_font_size("font_size", type, 18)
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_readonly_color", type, Kit.C_KEY_TEXT)
		t.set_color("font_selected_color", type, Kit.C_WHITE)
		t.set_color("selection_color", type, Color(acc, 0.35))
		t.set_color("caret_color", type, acc)
		t.set_color("font_placeholder_color", type, Kit.C_DIM)

	# 右クリックのメニュー・ツールチップ
	var pop := _sb(sheet, acc, 2, 8)
	pop.content_margin_left = 6
	pop.content_margin_right = 6
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", _sb(Color(acc, 0.22), Color(0, 0, 0, 0), 0, 6))
	t.set_font("font", "PopupMenu", Kit.font(500))
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_color("font_color", "PopupMenu", Kit.C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Kit.C_WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Kit.C_DIM)
	t.set_color("font_separator_color", "PopupMenu", Kit.C_DIM)
	var line := StyleBoxLine.new()
	line.color = Kit.C_RULE
	line.thickness = 2
	t.set_stylebox("separator", "PopupMenu", line)
	t.set_stylebox("panel", "TooltipPanel", _sb(sheet, acc, 2, 6))
	t.set_color("font_color", "TooltipLabel", Kit.C_TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	# スクロールバー
	for type: String in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("0B1A1F")
		var grab := StyleBoxFlat.new()
		grab.bg_color = Kit.C_RULE.lightened(0.2)
		var grab_hi := grab.duplicate() as StyleBoxFlat
		grab_hi.bg_color = Color(acc, 0.7)
		var grab_on := grab.duplicate() as StyleBoxFlat
		grab_on.bg_color = acc
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, grab)
		t.set_stylebox("grabber_highlight", type, grab_hi)
		t.set_stylebox("grabber_pressed", type, grab_on)

	# つまみ(今は画面で使っていないが、後から足した時に既定の見た目に戻らないように)
	var rail := StyleBoxFlat.new()
	rail.bg_color = Kit.C_RULE
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	var rail_on := rail.duplicate() as StyleBoxFlat
	rail_on.bg_color = acc
	var grab_n := _icon(18, Kit.C_TEXT, Kit.C_TEXT)  # 絵は 1 枚ずつ作って使い回す(書き出しを重くしない)
	var grab_h := _icon(18, acc, acc)
	var grab_d := _icon(18, Kit.C_DIM, Kit.C_DIM)
	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, rail)
		t.set_stylebox("grabber_area", type, rail_on)
		t.set_stylebox("grabber_area_highlight", type, rail_on)
		t.set_icon("grabber", type, grab_n)
		t.set_icon("grabber_highlight", type, grab_h)
		t.set_icon("grabber_disabled", type, grab_d)

	# チェック
	var off := _icon(20, Color(0, 0, 0, 0), Kit.C_DIM)
	var on := _icon(20, Color(0, 0, 0, 0), acc, acc)
	for type: String in ["CheckBox", "CheckButton"]:
		t.set_icon("unchecked", type, off)
		t.set_icon("checked", type, on)
		t.set_icon("unchecked_disabled", type, off)
		t.set_icon("checked_disabled", type, on)
		t.set_font("font", type, Kit.font(700))
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_hover_color", type, Kit.C_WHITE)
		t.set_color("font_pressed_color", type, Kit.C_TEXT)
		t.set_color("font_focus_color", type, Kit.C_TEXT)
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, StyleBoxEmpty.new())
		t.set_stylebox("focus", type, _sb(Color(0, 0, 0, 0), acc, 2, 6))
	return t

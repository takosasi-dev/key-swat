# 画面の下のキーの案内(v0.3.0): 小さなキーの形(矢印は絵で描く)と、その横の動きの言葉を並べる。例: [↑][↓] 選ぶ  [Enter] 決める
# items は [[キーの名前, ...], 言葉] の並び。キーの名前の up / down / left / right は矢印の絵、ほかは字(Esc・Enter・R)。
extends Control

const Kit := preload("res://ui/kit.gd")

const H := 32.0
const ARROWS := ["up", "down", "left", "right"]

var items: Array = []
var align := HORIZONTAL_ALIGNMENT_CENTER


func _init(p_items: Array = [], p_align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	items = p_items
	align = p_align
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _cap_w(k: String) -> float:
	if k in ARROWS:
		return H
	return maxf(H, Kit.num_font().get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 20.0)


func _text_w(t: String) -> float:
	return Kit.font(500).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x


func total_width() -> float:
	var w := 0.0
	for n in items.size():
		var it: Array = items[n]
		for k: String in it[0]:
			w += _cap_w(k) + 6.0
		w += 4.0 + _text_w(it[1]) + (28.0 if n < items.size() - 1 else 0.0)
	return w


func _draw() -> void:
	var w := total_width()
	var x := (size.x - w) / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else (size.x - w if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
	var top := (size.y - H) / 2.0
	for n in items.size():
		var it: Array = items[n]
		for k: String in it[0]:
			var cw := _cap_w(k)
			var r := Rect2(x, top, cw, H)
			Kit.draw_plate(self, r, Kit.C_SHEET, Kit.C_DIM, 6, 1.5)
			if k in ARROWS:
				var c := r.get_center()
				var d: Vector2 = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[k]
				var n2 := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([c + d * 7, c - d * 5 + n2 * 7, c - d * 5 - n2 * 7]), Kit.C_TEXT)
			else:
				draw_string(Kit.num_font(), Vector2(x, top + H * 0.7), k, HORIZONTAL_ALIGNMENT_CENTER, cw, 18, Kit.C_TEXT)
			x += cw + 6.0
		x += 4.0
		draw_string(Kit.font(500), Vector2(x, top + H * 0.72), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Kit.C_DIM)
		x += _text_w(it[1]) + 28.0

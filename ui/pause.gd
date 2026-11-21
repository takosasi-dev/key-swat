# S5 一時停止(共通 §6)。プレイ画面を暗くした上に板を重ねる。続ける・やり直す・設定・タイトルへ。Esc で続ける、R でやり直す。
# v0.3.0: 暗幕は窓に見えている範囲全体。板は角を切った形で、下にキーの案内。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const SHEET := Rect2(420, 84, 440, 528)

var menu: Menu
var _view := Rect2(0, 0, 1280, 720)


func build() -> void:
	size = Vector2(1280, 720)
	var title := Kit.label(S.PAUSE, 36, Kit.C_TEXT, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(title, 470, 104, 300, 56))
	var list: Array[Button] = []
	var y := 188.0
	for pair: Array in [["resume", S.B_RESUME], ["restart", S.B_RESTART], ["settings", S.B_SETTINGS], ["title", S.B_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 24), 470, y, 340, 64)
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		list.append(b)
		y += 78
	add_child(Kit.place(KeyHint.new([[["Esc"], S.B_RESUME], [["R"], S.B_RESTART]]), 420, 520, 440, 40))
	menu = Menu.new(list, 0)


func set_view(v: Rect2) -> void:
	_view = v
	queue_redraw()


func _draw() -> void:
	draw_rect(_view, Color(Kit.C_BG, 0.78))
	Kit.draw_plate(self, SHEET, Color(Kit.C_SHEET, 0.98), Kit.C_ACCENT.lerp(Kit.C_RULE, 0.5), 16)
	for k in 6:
		var x := 700.0 + k * 18.0
		draw_line(Vector2(x, 146), Vector2(x + 14, 118), Color(Kit.C_ACCENT, 0.35), 3.0)
	draw_line(Vector2(470, 166), Vector2(810, 166), Kit.C_RULE, 2.0)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		picked.emit("resume")
	elif ev.pressed and not ev.echo and ev.physical_keycode == KEY_R:
		picked.emit("restart")
	else:
		menu.key(ev)

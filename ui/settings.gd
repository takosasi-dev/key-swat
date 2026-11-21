# S4 設定(共通 §6)。音量(5 段)・画面の揺れ・点滅を弱める。変えたらすぐ保存し、音量はその音量で 1 回鳴らす。
# ← → でも値を変えられる。Esc か「戻る」で来た画面へ。v0.3.0: 板の上に項目を並べ、今の値を右に絵で出す(音量は 4 本の棒、入/切は 2 つの札)。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const SHEET := Rect2(340, 64, 600, 560)

var menu: Menu
var store: RefCounted
var opaque := false  # 一時停止から開いた時は、見えている範囲全体を地の色で隠す
var _view := Rect2(0, 0, 1280, 720)
var _vol: Button
var _shake: Button
var _flash: Button
var _values: Control


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(1280, 720)
	var title := Kit.label(S.SETTINGS, 36, Kit.C_TEXT, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(title, 380, 84, 400, 56))
	_vol = Kit.place(Kit.button("volume", S.SET_VOLUME, 24), 380, 168, 520, 68)
	_shake = Kit.place(Kit.button("shake", S.SET_SHAKE, 24), 380, 248, 520, 68)
	_flash = Kit.place(Kit.button("reduce_flash", S.SET_FLASH, 24), 380, 328, 520, 68)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 24), 380, 432, 200, 60)
	for b: Button in [_vol, _shake, _flash, ret]:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(b)
	ret.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_values = Control.new()  # 値の絵はボタンより上に描く
	_values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_values.draw.connect(_draw_values)
	add_child(Kit.place(_values, 0, 0, 1280, 720))
	add_child(Kit.place(KeyHint.new([[["up", "down"], S.HINT_PICK], [["left", "right"], S.HINT_CHANGE], [["Esc"], S.B_BACK]]), 360, 556, 560, 40))
	_vol.pressed.connect(func() -> void: _step_volume(1))
	_shake.pressed.connect(func() -> void: _toggle("shake"))
	_flash.pressed.connect(func() -> void: _toggle("reduce_flash"))
	ret.pressed.connect(func() -> void: back.emit())
	menu = Menu.new([_vol, _shake, _flash, ret] as Array[Button], 0)
	_paint()


func set_view(v: Rect2) -> void:
	_view = v
	queue_redraw()


func _paint() -> void:
	_values.queue_redraw()


func _draw() -> void:
	if opaque:
		draw_rect(_view, Color(Kit.C_BG, 0.97))
	Kit.draw_plate(self, SHEET, Color(Kit.C_SHEET, 0.96), Kit.C_RULE, 16)
	# 題の右の斜線(検査票の欄の飾り)
	for k in 8:
		var x := 760.0 + k * 18.0
		draw_line(Vector2(x, 128), Vector2(x + 14, 100), Color(Kit.C_ACCENT, 0.35), 3.0)
	draw_line(Vector2(380, 148), Vector2(900, 148), Kit.C_RULE, 2.0)


func _draw_values() -> void:
	var st: Dictionary = store.settings()
	var num := Kit.num_font()
	# 音量: 4 本の棒(25・50・75・100)を高さ順に、今の音量まで塗る。右に数
	var vol := int(st["volume"])
	var r := _vol.get_rect()
	for k in 4:
		var h := 12.0 + k * 8.0
		var bar := Rect2(r.end.x - 196 + k * 22, r.get_center().y + 18 - h, 16, h)
		_values.draw_rect(bar, Kit.C_ACCENT if vol >= (k + 1) * 25 else Kit.C_RULE)
	Kit.draw_digits(_values, num, r.end.x - 24, r.get_center().y + 11, str(vol), 30, Kit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_switch(_shake.get_rect(), bool(st["shake"]))
	_switch(_flash.get_rect(), bool(st["reduce_flash"]))


# 入/切の 2 つの札。今の方は塗り(字は地の色)、もう一方は縁だけ。
func _switch(r: Rect2, on: bool) -> void:
	var jp := Kit.font(700)
	for k in 2:
		var is_on := k == 0
		var cell := Rect2(r.end.x - 152 + k * 66, r.get_center().y - 20, 60, 40)
		var chosen := is_on == on
		Kit.draw_plate(_values, cell, Kit.C_ACCENT if chosen else Color(0, 0, 0, 0), Kit.C_ACCENT if chosen else Color(Kit.C_DIM, 0.7), 8, 2.0)
		_values.draw_string(jp, Vector2(cell.position.x, cell.position.y + 29), S.ON if is_on else S.OFF, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 22,
			Kit.C_BG if chosen else Kit.C_DIM)


func _step_volume(d: int) -> void:
	var i: int = B.VOLUMES.find(int(store.settings()["volume"]))
	var v: int = B.VOLUMES[(i + d + B.VOLUMES.size()) % B.VOLUMES.size()]
	store.set_setting("volume", v)
	Sfx.set_volume(v)
	Sfx.play("squash")
	_paint()


func _toggle(k: String) -> void:
	store.set_setting(k, not store.settings()[k])
	_paint()


func key(ev: InputEventKey) -> void:
	if not ev.pressed or ev.echo:
		return
	if ev.physical_keycode == KEY_ESCAPE:
		back.emit()
	elif menu.sel == 0 and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_step_volume(-1 if ev.physical_keycode == KEY_LEFT else 1)
	elif menu.sel in [1, 2] and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_toggle(["", "shake", "reduce_flash"][menu.sel])
	else:
		menu.key(ev)

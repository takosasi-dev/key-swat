# S3 結果(画面設計書 §4・§10)。終わった理由、点を 600 ms で数え上げ、最高との差と最高までの物差し、4 つの数の升、共有する文字を出す。
# 新しい記録の時は、数え上がった所で「新しい記録」の印が押される(点滅を弱める 入なら最初から押してある)。
# もう1回は 300 ms 後から押せる(Enter・R でも)。コピーは clipboard_set を試し、選べる枠も出す(E-13)。作りは RootCall の ui/result.gd。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

var menu: Menu
var share := ""
var new_best := false
var reduce := false
var _points := 0
var _best := -1  # 前の最高(無ければ -1)
var _stats: Array = []  # [名前, 数の文字]
var _shown_at := 0
var _reason := ""
var _retry: Button
var _copied: Label


# rec は save_store.record() の戻り値。
func build(result: Dictionary, rec: Dictionary, share_text: String, p_reduce: bool = false) -> void:
	size = Vector2(1280, 720)
	share = share_text
	reduce = p_reduce
	_points = int(result["score"])
	_shown_at = Time.get_ticks_msec()
	new_best = bool(rec["new_best"]) and rec["prev_best"] != null
	_reason = S.REASONS[maxi(int(result["reason"]), 0)]
	add_child(Kit.place(Kit.label(_reason, 30, Kit.C_WARN, 700), 0, 20, 1280, 46))  # 何で終わったかを最初に読ませる
	if rec["prev_best"] != null:
		_best = int(rec["prev_best"]["score"])
		var diff := _points - _best
		var text: String = S.RES_NEW_BEST % Score.comma(diff) if rec["new_best"] else S.RES_TO_BEST % Score.comma(-diff)
		add_child(Kit.place(Kit.label(text, 24, Kit.C_GOOD if rec["new_best"] else Kit.C_DIM, 700), 0, 196, 1280, 36))
	_stats = [[S.RES_TIME, Score.clock_text(int(result["ticks"]))], [S.RES_SQUASHED, str(int(result["squashed"]))],
		[S.RES_MAX_CHAIN, str(int(result["max_chain"]))], [S.RES_MISSES, str(int(result["misses"]))]]
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 30), 490, 356, 300, 72)
	_retry.disabled = true
	add_child(_retry)
	var box := TextEdit.new()
	box.name = "share"
	box.text = share
	box.editable = false
	box.context_menu_enabled = false  # Godot の右クリックのメニューは英語の項目で、画面の言葉と合わない。選んで Ctrl+C で写せる
	box.focus_mode = Control.FOCUS_CLICK
	add_child(Kit.place(box, 290, 448, 700, 100))
	var copy := Kit.place(Kit.button("copy", S.B_COPY, 22), 420, 562, 200, 56)
	var title := Kit.place(Kit.button("title", S.B_TITLE, 22), 660, 562, 200, 56)
	add_child(copy)
	add_child(title)
	_copied = Kit.label("", 18, Kit.C_DIM, 500)
	add_child(Kit.place(_copied, 0, 622, 1280, 28))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 20, Kit.C_WARN, 500), 0, 642, 1280, 32))
	add_child(Kit.place(KeyHint.new([[["Enter", "R"], S.B_RETRY]], HORIZONTAL_ALIGNMENT_RIGHT), 640, 670, 592, 36))
	_retry.pressed.connect(func() -> void: retry.emit())
	copy.pressed.connect(_copy)
	title.pressed.connect(func() -> void: to_title.emit())
	menu = Menu.new([_retry, copy, title] as Array[Button], 0)


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


# 画面に入ってからの時間で、数え上げた点。
@warning_ignore("integer_division")
static func shown_points(points: int, t: int, reduce: bool) -> int:
	return points if reduce or t >= B.COUNT_MS else points * maxi(t, 0) / B.COUNT_MS


# 新しい記録の印の濃さと大きさ: 数え上げが終わってから STAMP_MS で 1.6 倍 → 1 倍に押される。押す前は -1。
static func stamp_k(t: int, reduce: bool) -> float:
	if reduce:
		return 1.0
	var s := t - B.COUNT_MS
	return -1.0 if s < 0 else clampf(float(s) / B.STAMP_MS, 0.0, 1.0)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() - _shown_at
	if _retry.disabled and t >= B.RETRY_LOCK_MS:
		_retry.disabled = false
	if t < B.COUNT_MS + B.STAMP_MS + 50:
		queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() - _shown_at
	var num := Kit.num_font()
	var jp := Kit.font(700)
	# 理由の両側の短い罫
	var half := jp.get_string_size(_reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x / 2.0
	for sx: float in [-1.0, 1.0]:
		draw_line(Vector2(640 + sx * (half + 24), 43), Vector2(640 + sx * (half + 104), 43), Color(Kit.C_WARN, 0.6), 2.0)
	# 点(数え上げ)
	var pts := Score.comma(shown_points(_points, t, reduce))
	var w := Kit.digits_width(num, pts, 112)
	var unit := jp.get_string_size(S.RES_POINTS % "", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var x0 := 640.0 - (w + 10.0 + unit) / 2.0
	Kit.draw_digits(self, num, x0, 178, pts, 112, Kit.C_WHITE)
	draw_string(jp, Vector2(x0 + w + 10.0, 176), S.RES_POINTS % "", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Kit.C_DIM)
	# 最高までの物差し(前の最高がある時): 今回の点と前の最高を同じ物差しに置く
	if _best >= 0:
		var top := maxi(maxi(_points, _best), 1)
		var bar := Rect2(440, 238, 400, 8)
		draw_rect(bar, Kit.C_KEY)
		var shown := shown_points(_points, t, reduce)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown / top, bar.size.y)), Kit.C_GOOD if new_best else Kit.C_TEXT)
		var bx := bar.position.x + bar.size.x * _best / top
		draw_line(Vector2(bx, bar.position.y - 6), Vector2(bx, bar.end.y + 6), Kit.C_ACCENT, 3.0)
	# 4 つの数の升
	for k in _stats.size():
		var r := Rect2(176 + k * 236, 262, 220, 76)
		Kit.draw_plate(self, r, Color(Kit.C_SHEET, 0.95), Kit.C_RULE, 10)
		draw_string(Kit.font(500), Vector2(r.position.x, r.position.y + 26), _stats[k][0], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Kit.C_DIM)
		Kit.draw_digits(self, num, r.get_center().x, r.position.y + 64, _stats[k][1], 34, Kit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	# 新しい記録の印
	if new_best:
		var k := stamp_k(t, reduce)
		if k >= 0.0:
			var sc := 1.0 + 0.6 * (1.0 - Kit.ease_out(k))
			draw_set_transform(Vector2(1010, 118), -0.16, Vector2(sc, sc))
			var tw := jp.get_string_size(S.STAMP_NEW, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 36.0
			var r := Rect2(-tw / 2.0, -30, tw, 60)
			var a := Kit.ease_out(k * 1.5)
			Kit.draw_plate(self, r, Color(Kit.C_GOOD, 0.12 * a), Color(Kit.C_GOOD, a), 10, 4.0)
			Kit.draw_plate(self, r.grow(-7), Color(0, 0, 0, 0), Color(Kit.C_GOOD, 0.5 * a), 6, 1.5)
			draw_string(jp, Vector2(r.position.x, 11), S.STAMP_NEW, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color(Kit.C_GOOD, a))
			draw_set_transform(Vector2.ZERO)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_R and not _retry.disabled:
		Sfx.play("confirm")
		retry.emit()
		return
	menu.key(ev)

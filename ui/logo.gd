# 題字(v0.3.0): KeySwat の 7 字を 1 字ずつキーの形に載せ、S だけ叩かれた虫のキー(赤・左上の丸・少し傾く・飛び散り)にする。
# 下に検査票の物差しの罫。入った時はキーが 1 つずつ落ちて来て、最後に S が叩かれて光る(点滅を弱める 入なら止まった絵のまま)。
# 大きさ 660×116(舞台の座標)。_draw だけで描く。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

const CAP := 84.0
const GAP := 12.0
const SWAT := 3  # 叩かれたキー(S)
const TILT := -0.12  # S の傾き(ラジアン)

var start_ms := 0  # 入りの動きの始まり(0 なら動かさない)
var reduce := false
var now_ms := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(CAP * 7 + GAP * 6, 116)


func play_intro() -> void:
	start_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if start_ms > 0 and _now() - start_ms < intro_ms() + 100:
		queue_redraw()


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


static func intro_ms() -> int:
	return B.LOGO_STAGGER_MS * 7 + B.LOGO_DROP_MS + B.LOGO_SWAT_MS


# k 番目のキーの入り(0→1)。動かさない時は 1。
func drop(k: int) -> float:
	if reduce or start_ms <= 0:
		return 1.0
	return Kit.ease_out(float(_now() - start_ms - k * B.LOGO_STAGGER_MS) / B.LOGO_DROP_MS)


# S が叩かれてからの割合(0→1)。叩かれる前は -1。
func swat() -> float:
	if reduce or start_ms <= 0:
		return 1.0
	var t := _now() - start_ms - B.LOGO_STAGGER_MS * 7 - B.LOGO_DROP_MS
	return -1.0 if t < 0 else clampf(float(t) / B.LOGO_SWAT_MS, 0.0, 1.0)


func _draw() -> void:
	var f := Kit.num_font()
	var word := S.NAME
	var hit := swat()
	for k in word.length():
		var d := drop(k)
		if d <= 0.0:
			continue
		var r := Rect2(k * (CAP + GAP), -40.0 * (1.0 - d), CAP, CAP)
		var swatted := k == SWAT and hit >= 0.0
		if swatted:
			var c := r.get_center() + Vector2(0, 6)
			draw_set_transform(c, TILT * Kit.ease_out(hit * 3.0), Vector2.ONE)
			r = Rect2(-CAP / 2.0, -CAP / 2.0, CAP, CAP)
			for n in 4:  # 飛び散り: 短い線が 4 本、斜めの隙間へ
				var a := TAU * n / 4.0 + PI / 4.0
				var dir := Vector2(cos(a), sin(a))
				var len := 6.0 + 6.0 * Kit.ease_out(hit * 2.0)
				draw_line(dir * (CAP * 0.70), dir * (CAP * 0.70 + len), Color(Kit.C_BUG, 0.9), 4.0, true)
			Kit.draw_plate(self, r, Kit.C_BUG, Color(0, 0, 0, 0), 12)
			draw_circle(r.position + Vector2(17, 17), 7, Kit.C_BG, true, -1.0, true)
			draw_string(f, Vector2(r.position.x, r.position.y + CAP * 0.72), word[k], HORIZONTAL_ALIGNMENT_CENTER, CAP, 58, Kit.C_BG)
			if hit < 1.0:
				Kit.draw_plate(self, r.grow(10.0 * hit), Color(Kit.C_WHITE, 0.55 * (1.0 - hit)), Color(Kit.C_WHITE, 0.8 * (1.0 - hit)), 14, 3.0)
			draw_set_transform(Vector2.ZERO)
		else:
			var a := d
			Kit.draw_plate(self, r, Color(Kit.C_KEY, a), Color(Kit.C_ACCENT, 0.5 * a), 12)
			draw_line(r.position + Vector2(14, 6), Vector2(r.end.x - 6, r.position.y + 6), Color(Kit.C_ACCENT, 0.18 * a), 2.0)
			draw_string(f, Vector2(r.position.x, r.position.y + CAP * 0.72), word[k], HORIZONTAL_ALIGNMENT_CENTER, CAP, 58, Color(Kit.C_KEY_TEXT, a))
	# 物差しの罫: 12 px ごとに短い目盛り、60 px ごとに長い目盛り
	var y := CAP + 20.0
	var w := size.x
	var line_a := 0.55 * drop(6)
	draw_line(Vector2(0, y), Vector2(w, y), Color(Kit.C_ACCENT, line_a), 2.0)
	var x := 0.0
	var i := 0
	while x <= w + 0.5:
		draw_line(Vector2(x, y), Vector2(x, y + (10.0 if i % 5 == 0 else 5.0)), Color(Kit.C_ACCENT, line_a * (1.0 if i % 5 == 0 else 0.6)), 1.5)
		x += 12.0
		i += 1

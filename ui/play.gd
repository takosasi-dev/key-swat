# S2 プレイ(画面設計書 §3)。sim をたまった時間ぶん進め(1 フレーム 8 tick まで)、events で演出と音を出し、snapshot を盤に渡す。
# ゲームの決まりは持たない(INV-1)。押したキーは ui/keymap で盤の番号にして sim.queue_press に渡すだけ。
# 上の帯(守った時間・点・つなぎ)と 2 段目(耐久・感染の計器)は _draw で描く(v0.3.0: 角を切った板の上。点が一番大きく、増えると数え上がってはねる)。
extends Control

signal finished(result: Dictionary)
signal pause_requested

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Score := preload("res://core/score.gd")
const Layout := preload("res://core/layout.gd")
const Bots := preload("res://core/bots.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")
const Board := preload("res://ui/board.gd")
const Fx := preload("res://ui/fx.gd")

var sim: Sim = null
var mode := 0
var seed_value := 1
var paused := false
var shake_on := true
var reduce_flash := false
var bot: Bots.Driver = null  # 自動の確かめ(smoke)だけで使う
var load_test := false  # NFR-1 の負荷の場面(main の ?debug=1&load=1)。破片と浮かぶ数字を上限まで出し続ける
var board: Board
var fx: Fx
var key_at := 0  # 最後に盤のキーを押した時刻(usec)
var stepped_key_at := 0  # その押下を step に渡した時の key_at
var _acc := 0.0
var _over_at := -1
var _shake_until := 0
var _shake_px := 0.0
var _ime_until := 0
var _shown_score := 0.0  # 上の帯に出している点(本当の点へ数え上がる)
var _bump_at := -100000
var _hint: Label
var _tip: Label  # 盤の下の 1 行(数字の段が加わった・新しい物が初めて出た時の案内)
var _tip_until := 0
var _tips_seen := {}
var _ime: Label
var _snap: Dictionary = {}


func _ready() -> void:
	size = Vector2(1280, 720)
	var esc := Kit.place(Kit.button("Esc", S.ESC, 20), 28, 24, 76, 54)
	esc.add_theme_font_override("font", Kit.num_font())
	esc.pressed.connect(func() -> void: pause_requested.emit())
	add_child(esc)
	board = Board.new()
	Kit.place(board, 0, 0, 1280, 720)
	add_child(board)
	fx = Fx.new()
	Kit.place(fx, 0, 0, 1280, 720)
	add_child(fx)
	_hint = Kit.label(S.HINT, 28, Kit.C_TEXT, 700)
	add_child(Kit.place(_hint, 0, 612, 1280, 48))
	_tip = Kit.label("", 28, Kit.C_WARN, 700)
	add_child(Kit.place(_tip, 0, 612, 1280, 48))
	_ime = Kit.label(S.IME, 24, Kit.C_WARN, 700)
	add_child(Kit.place(_ime, 0, 660, 1280, 40))


func start(p_mode: int, p_seed: int) -> void:
	mode = p_mode
	seed_value = p_seed
	sim = Sim.new(p_seed, p_mode)
	paused = false
	_acc = 0.0
	_over_at = -1
	_shown_score = 0.0
	board.reduce_flash = reduce_flash
	_refresh()


func set_view(v: Rect2) -> void:
	fx.view = v


func is_playing() -> bool:
	return sim != null and not sim.is_over()


# S2 のキー。Esc は一時停止、盤のキーは sim へ。ほかは何もしない(画面設計書 §7)。
func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		pause_requested.emit()
		return
	if ev.pressed and ev.physical_keycode == KEY_NONE:
		_ime_until = Time.get_ticks_msec() + B.IME_NOTE_MS  # 共通 §3 の 9: 日本語入力で物理キーが取れない
	if sim == null or sim.is_over() or paused:
		return
	var i := Keymap.index_of(ev)
	if i >= 0:
		sim.queue_press(i)
		key_at = Time.get_ticks_usec()


func _process(delta: float) -> void:
	if sim == null:
		return
	var now := Time.get_ticks_msec()
	position = Vector2.ZERO
	if shake_on and now < _shake_until:
		position = Vector2(randf_range(-_shake_px, _shake_px), randf_range(-_shake_px, _shake_px))
	_tip.visible = now < _tip_until
	_ime.visible = now < _ime_until
	if not _snap.is_empty():
		fx.edge_alpha = 0.0 if _over_at != -1 else edge_alpha(int(_snap["infected"]), int(_snap["active_count"]), now, reduce_flash)
	if _over_at >= 0:
		fx.veil_alpha = veil_alpha(now - _over_at, reduce_flash)
	if load_test:
		for k in 3:
			var i := (Engine.get_process_frames() * 3 + k) % 15 + 10
			fx.burst(board.center(i), Kit.C_BUG)
			fx.float_text(board.center(i), S.FLOAT % ["1,200", "x4.0"], k == 0)
	fx.tick()
	board.queue_redraw()
	if not _snap.is_empty() and absf(_shown_score - float(_snap["score"])) > 0.0:
		_shown_score = count_up(_shown_score, int(_snap["score"]), delta, reduce_flash)
		queue_redraw()
	elif now - _bump_at < B.BUMP_MS + 20:
		queue_redraw()
	if _over_at >= 0:
		if now - _over_at >= B.OVER_MS:
			_over_at = -2
			finished.emit(sim.result())
		return
	if paused or _over_at == -2:
		return  # 一時停止の間は step を呼ばず、たまった時間も持たない(FR-23)
	_acc += delta * B.TICK_HZ
	var n := int(_acc)
	_acc -= n
	if n > B.MAX_STEPS_PER_FRAME:
		n = B.MAX_STEPS_PER_FRAME  # E-9: 超えた分は捨てる
		_acc = 0.0
	var heard := {}
	if n > 0 and key_at > stepped_key_at:
		stepped_key_at = key_at  # この後の step で押下が sim に入る(main が描き終わりまでの時間を測る)
	for k in n:
		if bot != null:
			bot.feed(sim)
		sim.step()
		for e: Dictionary in sim.events():
			_on_event(e, heard)
	_refresh()


# 演出の表(§9.8)。同じ音は 1 フレーム 1 回。
func _on_event(e: Dictionary, heard: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	var t: String = e["type"]
	if bot != null and (t == "unlock" or (t == "spawn" and int(e["kind"]) == Sim.JUMPER)):
		print("SMOKE event=%s clock=%d" % [t, sim.clock])  # smoke で 80 秒・120 秒の先まで描いたかを見る
	match t:
		"squash":
			var i: int = e["key"]
			var big: bool = int(e["kind"]) == Sim.NEST or int(e["chain"]) % B.BIG_CHAIN_EVERY == 0
			fx.burst(board.center(i), [Kit.C_BUG, Kit.C_BUG, Kit.C_NEST, Kit.C_JUMPER][int(e["kind"])])
			fx.pop(Layout.key_rect(i))
			fx.float_text(board.center(i) - Vector2(0, 30), S.FLOAT % [Score.comma(int(e["points"])), Score.mult_text(int(e["mult10"]))], big)
			if big:
				_shake(B.SHAKE_BIG_PX, B.SHAKE_BIG_MS)
			if not heard.has(t):
				Sfx.play("squash", mini(int(e["chain"]) - 1, B.PITCH_STEPS_MAX))
		"nest_hit":
			board.hit_at[int(e["key"])] = now
		"miss":
			board.miss_at[int(e["key"])] = now
			_shake(B.SHAKE_MISS_PX, B.SHAKE_MISS_MS)
		"spread":
			fx.ripple(board.center(int(e["to"])))
		"warn":
			_tip_once("warn", S.TIP_WARN)
		"warn_cancel":
			if sim.state[int(e["from"])] == Sim.CLEAN:  # 元を潰して止めた(巣・跳ぶ虫への置き直しで消えた時は出さない)
				fx.saved(board.center(int(e["to"])))
		"spawn":
			board.spawn_at[int(e["key"])] = now
			if int(e["kind"]) == Sim.NEST:
				_tip_once("nest", S.TIP_NEST)
			elif int(e["kind"]) == Sim.JUMPER:
				_tip_once("jumper", S.TIP_JUMPER)
		"unlock":
			board.unlock_at = now
			_show_tip(S.UNLOCK, B.UNLOCK_NOTE_MS)
		"over":
			_over_at = now
	if t in ["nest_hit", "miss", "warn", "spread", "unlock", "over"] and not heard.has(t):
		Sfx.play(t)
	heard[t] = true


func _show_tip(text: String, ms: int) -> void:
	_tip.text = text
	_tip_until = Time.get_ticks_msec() + ms


# 新しい物(予兆・巣・跳ぶ虫)が、この回で初めて出た時だけ 1 行の案内を出す。
func _tip_once(what: String, text: String) -> void:
	if not _tips_seen.has(what):
		_tips_seen[what] = true
		_show_tip(text, B.TIP_MS)


# 感染が DANGER_EDGE_PCT を超えたら画面の縁を赤く脈打たせる。点滅を弱めると脈打たず REDUCED_FLASH_ALPHA のまま。
static func edge_alpha(infected: int, active: int, now: int, reduce: bool) -> float:
	if infected * 100 <= active * B.DANGER_EDGE_PCT:
		return 0.0
	if reduce:
		return B.REDUCED_FLASH_ALPHA
	return lerpf(B.DANGER_ALPHA_LO, B.DANGER_ALPHA_HI, absf(fmod(float(now) / B.DANGER_PULSE_MS, 2.0) - 1.0))


# 終わってから結果へ移るまでの OVER_MS で、赤い幕を濃くする。
static func veil_alpha(since_ms: int, reduce: bool) -> float:
	return (B.REDUCED_FLASH_ALPHA if reduce else B.OVER_VEIL_ALPHA) * clampf(float(since_ms) / B.OVER_MS, 0.0, 1.0)


func _shake(px: float, ms: int) -> void:
	if not shake_on:
		return
	_shake_px = maxf(_shake_px if Time.get_ticks_msec() < _shake_until else 0.0, px)
	_shake_until = maxi(_shake_until, Time.get_ticks_msec() + ms)


func _refresh() -> void:
	var before := int(_snap["score"]) if not _snap.is_empty() else 0
	_snap = sim.snapshot()
	board.snap = _snap
	if int(_snap["score"]) > before and not reduce_flash:
		_bump_at = Time.get_ticks_msec()
	_hint.visible = not bool(_snap["clock_running"])
	queue_redraw()


# 上の帯の点を本当の点へ寄せる(1 秒に COUNT_UP_RATE の割合。最後は 1 点ずつ)。点滅を弱める 入ならすぐ本当の点。
static func count_up(shown: float, target: int, delta: float, reduce: bool) -> float:
	if reduce or shown > target:
		return float(target)
	var next := shown + maxf((target - shown) * minf(delta * B.COUNT_UP_RATE, 1.0), 1.0)
	return minf(next, float(target))


# 点が増えた時のはねの大きさ(1 → 1 + BUMP_SCALE → 1)。
static func bump_scale(since_ms: int) -> float:
	if since_ms < 0 or since_ms >= B.BUMP_MS:
		return 1.0
	var k := 1.0 - float(since_ms) / B.BUMP_MS
	return 1.0 + B.BUMP_SCALE * k * k


# 上の帯: 守った時間(左)・点(真ん中で一番大きい)・つなぎと倍率(右)。2 段目: 耐久の 10 区切り・感染の計器と終わりの線。
# 盤の下の 1 行(手がかり・案内・日本語入力)には帯を敷いて、どの背景の上でも読めるようにする。
@warning_ignore("integer_division")
func _draw() -> void:
	if _snap.is_empty():
		return
	var num := Kit.num_font()
	var jp := Kit.font(700)
	var now := Time.get_ticks_msec()
	Kit.draw_plate(self, Rect2(16, 12, 1248, 78), Color(Kit.C_SHEET, 0.95), Kit.C_RULE, 14)
	# 守った時間
	var running: bool = _snap["clock_running"]
	draw_string(jp, Vector2(126, 40), S.BAR_TIME, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Kit.C_DIM)
	Kit.draw_digits(self, num, 126, 79, Score.clock_text(int(_snap["clock"])), 34, Color(Kit.C_TEXT, 1.0 if running else 0.45))
	# 点
	var pts := Score.comma(int(_shown_score))
	var s := bump_scale(now - _bump_at)
	var w := Kit.digits_width(num, pts, 56)
	var unit := jp.get_string_size(S.BAR_POINTS, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var x0 := -(w + 8.0 + unit) / 2.0
	draw_set_transform(Vector2(640, 60), 0.0, Vector2(s, s))
	Kit.draw_digits(self, num, x0, 20, pts, 56, Kit.C_WHITE)
	draw_string(jp, Vector2(x0 + w + 8.0, 20), S.BAR_POINTS, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Kit.C_DIM)
	draw_set_transform(Vector2.ZERO)
	# つなぎと倍率(つなぎ 0 の時は出さない)
	var chain: int = _snap["chain"]
	if chain > 0:
		var mult := Score.mult_text(int(_snap["mult10"]))
		var bw := num.get_string_size(mult, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 22.0
		var badge := Rect2(1240 - bw, 34, bw, 40)
		Kit.draw_plate(self, badge, Kit.C_KEY_TEXT, Color(0, 0, 0, 0), 8)
		draw_string(num, Vector2(badge.position.x, 64), mult, HORIZONTAL_ALIGNMENT_CENTER, bw, 26, Kit.C_BG)
		var cx := badge.position.x - 14.0
		Kit.draw_digits(self, num, cx, 79, str(chain), 34, Kit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		draw_string(jp, Vector2(cx - 120, 40), S.BAR_CHAIN, HORIZONTAL_ALIGNMENT_RIGHT, 120, 18, Kit.C_DIM)
	# 2 段目の板
	Kit.draw_plate(self, Rect2(16, 98, 560, 56), Color(Kit.C_SHEET, 0.95), Kit.C_RULE, 10)
	Kit.draw_plate(self, Rect2(592, 98, 672, 56), Color(Kit.C_SHEET, 0.95), Kit.C_RULE, 10)
	# 耐久: 10 区切り。30 以下で赤(数も赤)。区切りの数で残りが分かる
	var integ: int = _snap["integrity"]
	draw_string(jp, Vector2(38, 135), S.BAR_INTEGRITY, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Kit.C_DIM)
	var ic := Kit.C_BUG if integ <= B.INTEGRITY_LOW else Kit.C_GOOD
	for k in 10:
		var r := Rect2(96 + k * 36, 112, 31, 28)
		Kit.draw_plate(self, r, Kit.C_KEY, Color(0, 0, 0, 0), 6)
		if integ >= (k + 1) * 10:
			Kit.draw_plate(self, r, ic, Color(0, 0, 0, 0), 6)
		elif integ > k * 10:
			draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(r.size.x * (integ - k * 10) / 10.0, r.size.y - 6)), ic)
	Kit.draw_digits(self, num, 554, 139, str(integ), 30, ic if integ <= B.INTEGRITY_LOW else Kit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	# 感染: 計器の棒・終わりの線(上に小さな三角)・数
	var inf: int = _snap["infected"]
	var act: int = _snap["active_count"]
	draw_string(jp, Vector2(612, 135), S.BAR_INFECT, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Kit.C_DIM)
	var bar := Rect2(674, 112, 300, 28)
	Kit.draw_plate(self, bar, Kit.C_KEY, Color(0, 0, 0, 0), 6)
	var over_warn := inf * 100 > act * B.INFECT_WARN_PCT
	var fill := bar.size.x * mini(inf * 100 / maxi(act, 1), 100) / 100.0
	if fill > 0.0:
		draw_rect(Rect2(bar.position + Vector2(0, 6), Vector2(fill, bar.size.y - 6)), Kit.C_WARN if over_warn else Kit.C_BUG)
	for k in range(1, 10):  # 1 割ごとの目盛り
		var gx := bar.position.x + bar.size.x * k / 10.0
		draw_line(Vector2(gx, bar.end.y - 6), Vector2(gx, bar.end.y), Color(Kit.C_DIM, 0.6), 1.0)
	var lx := bar.position.x + bar.size.x * B.LOSE_PERCENT / 100.0
	draw_line(Vector2(lx, bar.position.y - 2), Vector2(lx, bar.end.y + 4), Kit.C_TEXT, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(lx - 7, bar.position.y - 10), Vector2(lx + 7, bar.position.y - 10), Vector2(lx, bar.position.y - 2)]), Kit.C_TEXT)
	draw_string(num, Vector2(992, 136), S.BAR_INFECT_COUNT % [inf, act, lose_at(act)], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Kit.C_TEXT)
	# 盤の下の 1 行の帯
	for l: Label in [_hint, _tip, _ime]:
		if l.visible and l.text != "":
			var tw := jp.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x + 56.0
			var edge := Kit.C_WARN if l != _hint else Kit.C_BUG
			Kit.draw_plate(self, Rect2(640 - tw / 2.0, l.position.y + 2, tw, l.size.y - 4), Color(Kit.C_BG, 0.92), edge, 10)


# 何匹で終わるか(表示用。core の「感染数 × 100 ≥ active × LOSE_PERCENT」と同じ線。30 キーで 12、40 キーで 16)。
static func lose_at(active: int) -> int:
	return ceili(active * B.LOSE_PERCENT / 100.0)

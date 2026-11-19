# S2 プレイ(画面設計書 §3)。sim をたまった時間ぶん進め(1 フレーム 8 tick まで)、events で演出と音を出し、snapshot を盤に渡す。
# ゲームの決まりは持たない(INV-1)。押したキーは ui/keymap で盤の番号にして sim.queue_press に渡すだけ。
# 上の帯(守った時間・点・つなぎ)と 2 段目(耐久・感染の棒)は _draw で描く。
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
var board: Board
var fx: Fx
var _acc := 0.0
var _over_at := -1
var _shake_until := 0
var _shake_px := 0.0
var _unlock_until := 0
var _ime_until := 0
var _bar: Dictionary = {}
var _hint: Label
var _note: Label
var _ime: Label
var _snap: Dictionary = {}


func _ready() -> void:
	size = Vector2(1280, 720)
	var esc := Kit.place(Kit.button("Esc", S.ESC, 20), 24, 24, 72, 48)
	esc.pressed.connect(func() -> void: pause_requested.emit())
	add_child(esc)
	for k: String in ["time", "points", "chain"]:
		var l := Kit.label("", 30, Kit.C_TEXT, 700)
		add_child(l)
		_bar[k] = l
	_bar["time"].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bar["chain"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Kit.place(_bar["time"], 120, 20, 300, 56)
	Kit.place(_bar["points"], 440, 20, 400, 56)
	Kit.place(_bar["chain"], 860, 20, 396, 56)
	board = Board.new()
	Kit.place(board, 0, 0, 1280, 720)
	add_child(board)
	fx = Fx.new()
	Kit.place(fx, 0, 0, 1280, 720)
	add_child(fx)
	_hint = Kit.label(S.HINT, 28, Kit.C_TEXT, 700)
	add_child(Kit.place(_hint, 0, 612, 1280, 48))
	_note = Kit.label(S.UNLOCK, 30, Kit.C_TEXT, 800)
	add_child(Kit.place(_note, 0, 160, 1280, 48))
	_ime = Kit.label(S.IME, 24, Kit.C_WARN, 700)
	add_child(Kit.place(_ime, 0, 660, 1280, 40))


func start(p_mode: int, p_seed: int) -> void:
	mode = p_mode
	seed_value = p_seed
	sim = Sim.new(p_seed, p_mode)
	paused = false
	_acc = 0.0
	_over_at = -1
	board.reduce_flash = reduce_flash
	_refresh()


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


func _process(delta: float) -> void:
	if sim == null:
		return
	var now := Time.get_ticks_msec()
	position = Vector2.ZERO
	if shake_on and now < _shake_until:
		position = Vector2(randf_range(-_shake_px, _shake_px), randf_range(-_shake_px, _shake_px))
	_note.visible = now < _unlock_until
	_ime.visible = now < _ime_until
	fx.tick()
	board.queue_redraw()
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
	match t:
		"squash":
			var i: int = e["key"]
			var big: bool = int(e["kind"]) == Sim.NEST or int(e["chain"]) % B.BIG_CHAIN_EVERY == 0
			fx.burst(board.center(i), [Kit.C_BUG, Kit.C_BUG, Kit.C_NEST, Kit.C_JUMPER][int(e["kind"])])
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
		"spawn":
			board.spawn_at[int(e["key"])] = now
		"unlock":
			board.unlock_at = now
			_unlock_until = now + B.UNLOCK_NOTE_MS
		"over":
			_over_at = now
	if t in ["nest_hit", "miss", "warn", "spread", "unlock", "over"] and not heard.has(t):
		Sfx.play(t)
	heard[t] = true


func _shake(px: float, ms: int) -> void:
	if not shake_on:
		return
	_shake_px = maxf(_shake_px if Time.get_ticks_msec() < _shake_until else 0.0, px)
	_shake_until = maxi(_shake_until, Time.get_ticks_msec() + ms)


func _refresh() -> void:
	_snap = sim.snapshot()
	board.snap = _snap
	var running: bool = _snap["clock_running"]
	_bar["time"].text = S.BAR_TIME % Score.clock_text(int(_snap["clock"]))
	_bar["time"].modulate.a = 1.0 if running else 0.45
	_bar["points"].text = S.BAR_POINTS % Score.comma(int(_snap["score"]))
	var chain: int = _snap["chain"]
	_bar["chain"].text = S.BAR_CHAIN % [chain, Score.mult_text(int(_snap["mult10"]))] if chain > 0 else ""
	_hint.visible = not running
	queue_redraw()


# 2 段目: 耐久の 10 区切りの棒と数、感染の棒と「9 / 30」、40% の縦線。
@warning_ignore("integer_division")
func _draw() -> void:
	if _snap.is_empty():
		return
	var f := Kit.font(700)
	var integ: int = _snap["integrity"]
	draw_string(f, Vector2(120, 140), S.BAR_INTEGRITY, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Kit.C_DIM)
	var ic := Kit.C_BUG if integ <= B.INTEGRITY_LOW else Kit.C_GOOD
	for k in 10:
		var r := Rect2(184 + k * 26, 116, 22, 30)
		draw_rect(r, ic if integ >= (k + 1) * 10 else Color(Kit.C_KEY, 1.0))
		if integ > k * 10 and integ < (k + 1) * 10:
			draw_rect(Rect2(r.position, Vector2(r.size.x * (integ - k * 10) / 10.0, r.size.y)), ic)
	draw_string(f, Vector2(456, 140), str(integ), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Kit.C_TEXT)
	var inf: int = _snap["infected"]
	var act: int = _snap["active_count"]
	draw_string(f, Vector2(620, 140), S.BAR_INFECT, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Kit.C_DIM)
	var bar := Rect2(684, 116, 260, 30)
	draw_rect(bar, Kit.C_KEY)
	var over_warn := inf * 100 > act * B.INFECT_WARN_PCT
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * mini(inf * 100 / maxi(act, 1), 100) / 100.0, bar.size.y)),
		Kit.C_WARN if over_warn else Kit.C_BUG)
	var lx := bar.position.x + bar.size.x * B.LOSE_PERCENT / 100.0
	draw_line(Vector2(lx, bar.position.y - 6), Vector2(lx, bar.end.y + 6), Kit.C_TEXT, 2.0)
	draw_string(f, Vector2(960, 140), S.BAR_INFECT_COUNT % [inf, act, B.LOSE_PERCENT], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Kit.C_TEXT)

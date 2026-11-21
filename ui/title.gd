# S1 タイトル(画面設計書 §2・§10)。題字(キーの形の KeySwat)・一言・入口 2 つ(今日の盤・練習)と設定・記録・キーの案内。
# 下に 30 キーの盤を薄く出し、見本が遊ぶ(本物の sim を、ゆっくり潰す見本で回す。点滅を弱める 入なら F だけ赤い止まった盤)。
extends Control

signal chosen(what: String)  # "daily" / "practice" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Bots := preload("res://core/bots.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const Board := preload("res://ui/board.gd")
const Fx := preload("res://ui/fx.gd")
const Logo := preload("res://ui/logo.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const DEMO_SCALE := 0.42
const DEMO_CAP := 120 * 150  # 見本の回をこの時計で打ち切って新しい盤にする

var menu: Menu
var logo: Logo
var faint: Board
var faint_fx: Fx
var demo: Sim = null  # 見本の回(点滅を弱める 入なら null のまま)
var reduce := false
var _acc := 0.0
var _n := 0


# store は save_store、day は通し日数、date は "2026-11-19"。sel は選んでおくボタン(0 今日の盤・1 練習・2 設定)。
func build(store: RefCounted, day: int, date: String, sel: int = 0) -> void:
	size = Vector2(1280, 720)
	reduce = bool(store.settings()["reduce_flash"])
	var demo_box := Control.new()  # 薄い盤と破片を 1 つの縮めた箱に入れる
	demo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo_box.scale = Vector2(DEMO_SCALE, DEMO_SCALE)
	demo_box.position = Vector2(640 - 640 * DEMO_SCALE, 548 - 312 * DEMO_SCALE)
	demo_box.modulate.a = 0.5
	add_child(demo_box)
	faint = Board.new()
	faint.snap = Board.title_snap()
	faint.show_locked = false
	demo_box.add_child(Kit.place(faint, 0, 0, 1280, 720))
	faint_fx = Fx.new()
	demo_box.add_child(Kit.place(faint_fx, 0, 0, 1280, 720))
	logo = Logo.new()
	logo.reduce = reduce
	logo.position = Vector2((1280 - logo.size.x) / 2.0, 36)
	add_child(logo)
	logo.play_intro()
	add_child(Kit.place(Kit.label(S.TAGLINE, 26, Kit.C_DIM, 500), 0, 166, 1280, 40))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 18, Kit.C_WARN, 500), 0, 204, 1280, 28))
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.B_DAILY, date], 30), 310, 236, 480, 84)
	var practice := Kit.place(Kit.button("practice", S.B_PRACTICE, 28), 310, 334, 480, 84)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 24), 310, 432, 240, 64)
	for b: Button in [daily, practice, settings]:
		add_child(b)
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
	var d: Dictionary = store.daily(day)
	var pb: Variant = store.practice_best()
	if d["first"] != null:
		_note((S.REC_FIRST % Score.comma(d["first"]["score"])) + "\n" + (S.REC_TODAY_BEST % Score.comma(d["best"]["score"])), daily)
	elif pb != null or store.data["daily"] != null:
		_note(S.REC_NONE, daily)  # 初めての起動(記録が何も無い)では記録の行を出さない
	if pb != null:
		_note(S.REC_BEST % Score.comma(pb["score"]), practice)
	if d["first"] == null and pb == null and store.data["daily"] == null:
		for btn: Button in [daily, practice, settings]:  # 記録の行が無い時(初めての起動)は、ボタンを真ん中に寄せる
			btn.position.x += 90
	var ver := Kit.label(S.VERSION, 18, Kit.C_DIM, 500)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 48, 672, 200, 32))
	add_child(Kit.place(KeyHint.new([[["up", "down"], S.HINT_PICK], [["Enter"], S.HINT_OK]], HORIZONTAL_ALIGNMENT_RIGHT), 640, 670, 592, 36))
	menu = Menu.new([daily, practice, settings] as Array[Button], sel)


# 記録はボタンの右に、ボタンの左の縁と同じ印(短い縦の罫)を付けて並べる。
func _note(text: String, by: Button) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Kit.num_font())
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", Kit.C_KEY_TEXT)
	l.add_theme_constant_override("line_spacing", -2)
	add_child(Kit.place(l, by.position.x + by.size.x + 36, by.position.y, 440, by.size.y))
	var rule := ColorRect.new()
	rule.color = Color(Kit.C_ACCENT, 0.5)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(rule, by.position.x + by.size.x + 20, by.position.y + 14, 3, by.size.y - 28))


func key(ev: InputEventKey) -> void:
	menu.key(ev)


# 見本の回を進める(遊びの画面と同じ 120 tick/秒)。DEMO_PRESS_TICKS ごとに、正しい bot と同じ選び方で 1 匹潰す。
func _process(delta: float) -> void:
	if reduce:
		return
	if demo == null or demo.is_over() or demo.clock >= DEMO_CAP:
		demo = Sim.new(int(Time.get_ticks_usec() & 0x7FFFFFFF) | 1, Sim.MODE_PRACTICE)
		demo.queue_press(Sim.K_F)
		_n = 0
	_acc += delta * B.TICK_HZ
	var n := mini(int(_acc), B.MAX_STEPS_PER_FRAME)
	_acc = clampf(_acc - n, 0.0, 1.0)
	for k in n:
		_n += 1
		if _n % B.DEMO_PRESS_TICKS == 0:
			var i := Bots.Driver.pick_good(demo)
			if i >= 0:
				demo.queue_press(i)
		demo.step()
		for e: Dictionary in demo.events():
			match String(e["type"]):
				"squash":
					faint_fx.burst(faint.center(int(e["key"])), Kit.C_BUG)
				"spawn":
					faint.spawn_at[int(e["key"])] = Time.get_ticks_msec()
				"nest_hit":
					faint.hit_at[int(e["key"])] = Time.get_ticks_msec()
	if n > 0:
		var snap := demo.snapshot()
		var act: Array = snap["active"]
		for i in act.size():  # 数字の段は見せない(盤の箱の上に出てしまう)
			if i < 10:
				act[i] = false
		faint.snap = snap
		faint.queue_redraw()
	faint_fx.tick()

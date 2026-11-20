# S1 タイトル(画面設計書 §2)。入口 2 つ(今日の盤・練習)と設定、記録、下に 30 キーの盤を薄く(F だけ赤い)。
extends Control

signal chosen(what: String)  # "daily" / "practice" / "settings"

const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const Board := preload("res://ui/board.gd")

var menu: Menu


# store は save_store、day は通し日数、date は "2026-11-19"。sel は選んでおくボタン(0 今日の盤・1 練習・2 設定)。
func build(store: RefCounted, day: int, date: String, sel: int = 0) -> void:
	size = Vector2(1280, 720)
	var faint := Board.new()
	faint.snap = Board.title_snap()
	faint.show_locked = false
	faint.modulate.a = 0.35
	faint.scale = Vector2(0.45, 0.45)
	Kit.place(faint, 341, 400, 1280, 720)
	add_child(faint)
	add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 800), 0, 30, 1280, 100))
	add_child(Kit.place(Kit.label(S.TAGLINE, 28, Kit.C_DIM, 500), 0, 128, 1280, 44))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 18, Kit.C_WARN), 0, 172, 1280, 28))
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.B_DAILY, date], 30), 260, 210, 480, 88)
	var practice := Kit.place(Kit.button("practice", S.B_PRACTICE, 28), 260, 312, 480, 88)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 24), 260, 414, 240, 72)
	for b: Button in [daily, practice, settings]:
		add_child(b)
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
	var d: Dictionary = store.daily(day)
	var pb: Variant = store.practice_best()
	if d["first"] != null:
		_note((S.REC_FIRST % Score.comma(d["first"]["score"])) + " / " + (S.REC_TODAY_BEST % Score.comma(d["best"]["score"])), daily)
	elif pb != null or store.data["daily"] != null:
		_note(S.REC_NONE, daily)  # 初めての起動(記録が何も無い)では記録の行を出さない
	if pb != null:
		_note(S.REC_BEST % Score.comma(pb["score"]), practice)
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 676, 200, 32))
	menu = Menu.new([daily, practice, settings] as Array[Button], sel)


func _note(text: String, by: Button) -> void:
	var l := Kit.label(text, 20, Kit.C_DIM, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(l, by.position.x + by.size.x + 24, by.position.y, 480, by.size.y))


func key(ev: InputEventKey) -> void:
	menu.key(ev)

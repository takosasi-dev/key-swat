# v0.3.0 の UI の作り直しのテスト: theme.tres が全部の Control に付く・5 つの状態・色の板のコントラスト・表示用の字体の字・
# 画面の切り替わりは見た目だけ(入力を飲まない・もう1回は動かない・点滅を弱める 入なら動かない)・時刻で決まる動きの関数。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Play := preload("res://ui/play.gd")
const Result := preload("res://ui/result.gd")
const Logo := preload("res://ui/logo.gd")
const Wipe := preload("res://ui/wipe.gd")
const TestUi := preload("res://tests/test_ui.gd")


func _main(reduce: bool = false) -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	if reduce:
		var s := Store.new()
		s.set_setting("reduce_flash", true)
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


func test_theme_is_project_wide_and_complete() -> bool:
	eq(ProjectSettings.get_setting("gui/theme/custom"), "res://ui/theme.tres", "theme は project の設定で付ける")
	var t := load("res://ui/theme.tres") as Theme
	ok(t != null, "theme.tres を読める")
	if t == null:
		return true
	for st: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		ok(t.has_stylebox(st, "Button"), "Button の %s" % st)
	ok(t.has_stylebox("normal", "SelButton") and t.get_type_variation_base("SelButton") == &"Button", "選んだボタンの型の変種")
	for pair: Array in [["read_only", "TextEdit"], ["focus", "TextEdit"], ["panel", "PopupMenu"], ["hover", "PopupMenu"], ["grabber", "VScrollBar"],
			["scroll", "HScrollBar"], ["slider", "HSlider"], ["panel", "TooltipPanel"], ["panel", "Panel"]]:
		ok(t.has_stylebox(pair[0], pair[1]), "%s の %s" % [pair[1], pair[0]])
	ok(t.has_icon("checked", "CheckBox") and t.has_icon("grabber", "HSlider"), "チェックとつまみの絵")
	ok(t.get_icon("checked", "CheckBox") is ImageTexture and t.get_icon("grabber", "HSlider") is ImageTexture,
		"絵は ImageTexture(PortableCompressedTexture2D は Web で texture is null を出した)")
	eq((t.get_stylebox("normal", "Button") as StyleBoxFlat).bg_color, Kit.C_SHEET, "theme.tres は今の色で作り直してある(tools/make_theme.gd)")
	# 舞台に置いたボタンは theme を通る(既定の見た目に戻らない)
	var m := _main()
	TestUi.kp(m, KEY_X)
	var b: Button = m.current.menu.buttons[1]
	eq((b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Kit.C_SHEET, "タイトルのボタンは theme の板")
	eq(b.theme_type_variation, &"", "選んでいないボタンは素の型")
	eq(m.current.menu.buttons[0].theme_type_variation, &"SelButton", "選んだボタンは SelButton")
	_done(m)
	return true


func test_palette_contrast() -> bool:
	# 字と地: 4.5:1 以上(大きな字 3:1 は使わず全部 4.5 で見る)
	for pair: Array in [[Kit.C_TEXT, Kit.C_BG], [Kit.C_DIM, Kit.C_BG], [Kit.C_DIM, Kit.C_SHEET], [Kit.C_KEY_TEXT, Kit.C_KEY], [Kit.C_TEXT, Kit.C_SHEET],
			[Kit.C_WARN, Kit.C_BG], [Kit.C_GOOD, Kit.C_BG], [Kit.C_BG, Kit.C_ACCENT], [Kit.C_BG, Kit.C_BUG], [Kit.C_BG, Kit.C_KEY_TEXT],
			[Kit.C_WHITE, Kit.C_NEST], [Kit.C_BG, Kit.C_JUMPER], [Kit.C_KEY_TEXT, Kit.C_SHEET], [Kit.C_WHITE, Kit.C_SHEET.lerp(Kit.C_ACCENT, 0.18)]]:
		var c := Kit.contrast(pair[0], pair[1])
		ok(c >= 4.5, "%s と %s のコントラスト %.2f" % [pair[0].to_html(false), pair[1].to_html(false), c])
	return true


func test_display_font_has_its_glyphs() -> bool:
	var f := load(Kit.DISPLAY) as FontFile
	ok(f != null, "Chakra Petch を読める")
	if f == null:
		return true
	var text := "KeySwatEscEnterRv0123456789,:+x./; "
	for l: String in Layout.LABELS:
		text += l
	var missing := ""
	for c in text:
		if c != " " and not f.has_char(c.unicode_at(0)):
			missing += c
	eq(missing, "", "Chakra Petch に無い字")
	ok(FileAccess.file_exists("res://assets/fonts/OFL_ChakraPetch.txt"), "OFL を同梱")
	return true


func test_no_symbol_glyphs_in_strings() -> bool:
	var text := FileAccess.get_file_as_string("res://core/strings.gd")
	var found := ""
	for c in "★☆✓✔✗▶◀▲▼→←↑↓×●○◆◇■□♪":
		if text.contains(c):
			found += c
	eq(found, "", "画面の文字に記号の字(印は _draw で描く)")
	return true


func test_transition_is_visual_only_and_keeps_input() -> bool:
	var m := _main()
	TestUi.kp(m, KEY_X)
	eq(m.screen, "title", "S0 のキーでその場で S1")
	ok(not m.entering.is_empty() and m.wipe.progress() < 1.0, "タイトルは入りの動きと検査光の線")
	TestUi.kp(m, KEY_ENTER)  # 動いている間の Enter もそのまま届く
	eq(m.screen, "play", "動いている間の Enter で今日の盤(飲まない)")
	var p: Node = m.play
	TestUi.kp(m, KEY_ENTER)
	ok(m.play == p, "遊びの画面の Enter で 2 回目は始まらない")
	TestUi.kp(m, KEY_F)
	TestUi.frames(m, 2)
	ok(m.play.sim.clock_running, "入りの動きの間も F が効く")
	TestUi.finish_now(m)
	eq(m.screen, "result", "結果")
	m.current._shown_at -= 1000
	TestUi.frames(m, 1)
	TestUi.kp(m, KEY_R)
	eq(m.screen, "play", "もう1回")
	ok(m.entering.is_empty() and m.play.modulate.a == 1.0, "もう1回からは動きを付けない(すぐ遊べる)")
	TestUi.kp(m, KEY_ESCAPE)
	ok(m.pause_view != null and m.entering.size() == 1, "一時停止の板は少し上がりながら出る")
	_done(m)
	return true


func test_reduce_flash_stops_motion() -> bool:
	var m := _main(true)
	ok(m.reduce_motion(), "点滅を弱める 入")
	TestUi.kp(m, KEY_X)
	ok(m.entering.is_empty() and m.wipe.progress() >= 1.0, "切り替わりの動きなし")
	ok(not m.backdrop.animate, "背景の走査線も止まる")
	eq(m.current.demo, null, "タイトルの見本も回さない")
	TestUi.frames(m, 3)
	eq(m.current.demo, null, "フレームを進めても見本は無い")
	eq(m.current.logo.drop(0), 1.0, "題字は落ちて来ない")
	_done(m)
	var n := _main()
	TestUi.kp(n, KEY_X)
	ok(n.backdrop.animate, "ふだんはタイトルの走査線が流れる")
	TestUi.frames(n, 3)
	ok(n.current.demo != null and n.current.demo.clock_running, "ふだんはタイトルの薄い盤で見本が遊ぶ")
	_done(n)
	return true


func test_motion_curves() -> bool:
	eq(Play.count_up(0.0, 100, 1.0 / 60.0, true), 100.0, "点滅を弱めるとすぐ本当の点")
	var s := Play.count_up(0.0, 1000, 1.0 / 60.0, false)
	ok(s > 0.0 and s < 1000.0, "ふだんは数え上がる(%s)" % s)
	eq(Play.count_up(999.5, 1000, 1.0 / 60.0, false), 1000.0, "最後は本当の点に揃う")
	eq(Play.count_up(500.0, 100, 0.016, false), 100.0, "新しい回で点が減ったらすぐ合わせる")
	ok(Play.bump_scale(0) > 1.0 and is_equal_approx(Play.bump_scale(B.BUMP_MS), 1.0), "はねは BUMP_MS で戻る")
	eq(Result.shown_points(1000, 0, false), 0, "結果の点は 0 から")
	eq(Result.shown_points(1000, B.COUNT_MS, false), 1000, "COUNT_MS で数え上がる")
	eq(Result.shown_points(1000, 0, true), 1000, "点滅を弱めると数え上げない")
	eq(Result.stamp_k(B.COUNT_MS - 1, false), -1.0, "新しい記録の印は数え上げの後")
	eq(Result.stamp_k(B.COUNT_MS + B.STAMP_MS, false), 1.0, "STAMP_MS で押し終わる")
	eq(Result.stamp_k(0, true), 1.0, "点滅を弱めると最初から押してある")
	var logo := Logo.new()
	logo.start_ms = 1000
	logo.now_ms = 1000
	eq(logo.drop(0), 0.0, "題字の 1 つ目は上から")
	eq(logo.swat(), -1.0, "S はまだ叩かれていない")
	logo.now_ms = 1000 + Logo.intro_ms()
	eq(logo.drop(6), 1.0, "最後のキーまで落ちた")
	eq(logo.swat(), 1.0, "S が叩かれた")
	logo.free()
	var w := Wipe.new()
	w.start_ms = 1000
	w.now_ms = 1000 + B.WIPE_MS / 2
	ok(w.progress() > 0.0 and w.progress() < 1.0, "検査光の線は途中")
	w.now_ms = 1000 + B.WIPE_MS
	eq(w.progress(), 1.0, "WIPE_MS で終わる")
	w.free()
	return true


func test_new_best_result_has_stamp() -> bool:
	var r := Result.new()
	r.build({"score": 500, "ticks": 1200, "squashed": 5, "max_chain": 5, "misses": 0, "reason": 0},
		{"prev_best": {"score": 300}, "new_best": true, "first_today": false}, "KeySwat x")
	ok(r.new_best, "前の最高を超えたら印を押す")
	r.free()
	var q := Result.new()
	q.build({"score": 500, "ticks": 1200, "squashed": 5, "max_chain": 5, "misses": 0, "reason": 0},
		{"prev_best": null, "new_best": true, "first_today": true}, "KeySwat x")
	ok(not q.new_best, "初めての回(比べる最高が無い)には印を押さない")
	q.free()
	return true

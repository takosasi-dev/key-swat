# 画面の流れのテスト(AC-14・AC-18〜AC-20・FR-3・FR-18・FR-23・FR-26・E-9)。main.tscn を木に置き、キーのイベントを直接渡し、
# フレームは _process を呼んで進める。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")


static func kev(pk: int, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	e.echo = echo
	return e


func _main() -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


static func kp(m: Node, pk: int) -> void:
	m._input(kev(pk))


static func frames(m: Node, n: int, dt: float = 1.0 / 60.0) -> void:
	for k in n:
		if m.play != null:
			m.play._process(dt)
		if m.current != null and m.current.has_method("_process") and m.current != m.play:
			m.current._process(dt)


static func finish_now(m: Node) -> void:
	m.play.sim.integrity = 0
	m.play.sim.clock_running = true
	m.play.sim.queue_press(idx("G"))
	frames(m, 1)
	m.play.finished.emit(m.play.sim.result())  # 終わった後の 400 ms を待たない


func test_ac18_flow_keyboard_only() -> bool:
	var m := _main()
	eq(m.screen, "gate", "S0 から始まる")
	kp(m, KEY_X)
	eq(m.screen, "title", "どれかのキーで S1")
	ok(m.play == null, "S0 のキーはゲームの操作に数えない")
	eq(String(m.current.menu.buttons[0].name), "daily", "一番上は今日の盤")
	kp(m, KEY_ENTER)
	eq(m.screen, "play", "Enter で今日の盤")
	eq(int(m.run["mode"]), Sim.MODE_DAILY, "今日の盤")
	kp(m, KEY_F)
	frames(m, 2)
	ok(m.play.sim.clock_running, "F のキーで F の虫が潰れ、時計が動く(FR-3)")
	eq(m.play.sim.squashed, 1, "潰した数")
	finish_now(m)
	eq(m.screen, "result", "終わると S3")
	ok(m.current.share.begins_with("KeySwat ") and m.current.share.contains("今日の盤・1回目"), "共有する文字")
	var seed_before: int = m.run["seed"]
	kp(m, KEY_ENTER)
	eq(m.screen, "result", "300 ms の前は押せない")
	m.current._shown_at -= 1000
	frames(m, 1)
	kp(m, KEY_ENTER)
	eq(m.screen, "play", "もう1回(Enter)")
	eq(int(m.run["seed"]), seed_before, "今日の盤は同じ種(FR-18)")
	eq(m.play.sim.clock, 0, "新しい回")
	finish_now(m)
	ok(m.current.share.contains("(今日の盤)"), "2 回目は「今日の盤」")
	m.current._shown_at -= 1000
	frames(m, 1)
	kp(m, KEY_R)
	eq(m.screen, "play", "R でももう1回")
	_done(m)
	return true


func test_practice_and_records() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(int(m.run["mode"]), Sim.MODE_PRACTICE, "練習")
	kp(m, KEY_F)
	frames(m, 2)
	finish_now(m)
	ok(m.current.share.contains("(練習)"), "練習の共有する文字")
	ok(m.store.practice_best() != null and int(m.store.practice_best()["score"]) == 100, "練習の最高を保存")
	m.current._shown_at -= 1000
	frames(m, 1)
	kp(m, KEY_DOWN)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.screen, "title", "タイトルへ")
	_done(m)
	return true


func test_ac14_echo_and_modifiers_do_not_reach_sim() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	var e := kev(KEY_F)
	e.ctrl_pressed = true
	m._input(e)
	e = kev(KEY_F)
	e.alt_pressed = true
	m._input(e)
	e = kev(KEY_F)
	e.meta_pressed = true
	m._input(e)
	m._input(kev(KEY_F, true))
	m._input(kev(KEY_SPACE))
	m._input(kev(KEY_ENTER))
	frames(m, 2)
	eq(m.play.sim.squashed, 0, "押しっぱなし・Ctrl・Alt・Meta 付き・盤に無いキーは届かない")
	eq(m.play.sim.step_no > 0, true, "進んではいる")
	kp(m, KEY_F)
	frames(m, 2)
	eq(m.play.sim.squashed, 1, "Shift なしの F は届く")
	_done(m)
	return true


func test_ac20_pause_freezes() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	kp(m, KEY_F)
	frames(m, 30)
	kp(m, KEY_ESCAPE)
	ok(m.pause_view != null, "Esc で一時停止")
	var t: int = m.play.sim.clock
	kp(m, KEY_J)
	frames(m, 120)
	eq(m.play.sim.clock, t, "時計が止まる")
	eq(m.play.sim.state[Sim.K_J], Sim.BUG, "一時停止の間のキーは盤に届かない")
	kp(m, KEY_ESCAPE)
	ok(m.pause_view == null, "Esc で続ける")
	frames(m, 2)
	ok(m.play.sim.clock > t, "続けると進む")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.pause_view != null, "フォーカスが外れると一時停止(E-10)")
	var t2: int = m.play.sim.clock
	frames(m, 60)
	eq(m.play.sim.clock, t2, "戻っても自動では再開しない")
	_done(m)
	return true


func test_pause_settings_back_and_restart() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	kp(m, KEY_ESCAPE)
	kp(m, KEY_DOWN)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.screen, "settings", "一時停止から設定")
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)  # 上から 音量・揺れ
	eq(m.store.settings()["shake"], false, "揺れを切って保存")
	kp(m, KEY_ESCAPE)
	eq(m.screen, "play", "戻ると一時停止へ")
	ok(m.pause_view != null and m.pause_view.visible, "一時停止の画面")
	eq(m.play.shake_on, false, "設定がプレイに届く")
	kp(m, KEY_R)
	eq(m.screen, "play", "R でやり直す")
	ok(m.pause_view == null and m.play.sim.step_no == 0, "新しい回")
	_done(m)
	return true


func test_ac19_no_shake_when_off() -> bool:
	var m := _main()
	m.store.set_setting("shake", false)
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	m.play._on_event({"type": "squash", "key": 23, "points": 300, "mult10": 10, "kind": Sim.NEST, "chain": 1}, {})
	frames(m, 3)
	eq(m.play.position, Vector2.ZERO, "揺れを切ると巣を潰しても動かない")
	m.play.shake_on = true
	m.play._on_event({"type": "squash", "key": 23, "points": 300, "mult10": 10, "kind": Sim.NEST, "chain": 1}, {})
	var moved := false
	for k in 5:
		frames(m, 1, 0.0)
		moved = moved or m.play.position != Vector2.ZERO
	ok(moved, "入なら揺れる")
	_done(m)
	return true


func test_e9_at_most_8_ticks_per_frame() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	kp(m, KEY_F)
	frames(m, 1)
	var t: int = m.play.sim.clock
	frames(m, 1, 1.0)
	eq(m.play.sim.clock - t, B.MAX_STEPS_PER_FRAME, "1 フレーム 8 tick まで")
	_done(m)
	return true


func test_gate_touch_note() -> bool:
	var m := _main()
	var t := InputEventScreenTouch.new()
	t.pressed = true
	m._input(t)
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.device = InputEvent.DEVICE_ID_EMULATION
	m._input(mb)
	eq(m.screen, "gate", "タッチと、そこから作られたマウスでは進まない(FR-26)")
	ok(m._touch_note.visible, "キーボードで遊ぶ案内が出る")
	_done(m)
	return true


func test_locked_digit_keys_from_keyboard() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	kp(m, KEY_F)
	frames(m, 2)
	var integ: int = m.play.sim.integrity
	kp(m, KEY_5)
	frames(m, 2)
	eq(m.play.sim.integrity, integ, "解放前の数字のキーは外れにしない")
	kp(m, KEY_G)
	frames(m, 2)
	eq(m.play.sim.integrity, integ - B.MISS_DAMAGE, "clean の G は外れ")
	_done(m)
	return true


func test_ime_note_on_zero_keycode() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	m._input(kev(KEY_NONE))
	frames(m, 1)
	ok(m.play._ime.visible, "physical_keycode が 0 のキーで日本語入力の案内(共通 §3 の 9)")
	_done(m)
	return true


# --- 磨き(v0.2.0)で足した演出と見た目 ---

func _playing(m: Node) -> void:
	kp(m, KEY_X)
	kp(m, KEY_ENTER)


func test_polish_saved_ring_only_when_source_squashed() -> bool:
	var m := _main()
	_playing(m)
	m.play.sim = empty_board()
	m.play.sim.put(idx("D"), Sim.BUG, true)
	for k in 200:
		if m.play.sim.target[idx("D")] >= 0:
			break
		frames(m, 1, 8.0 / B.TICK_HZ)
	ok(m.play.sim.target[idx("D")] >= 0, "D の予兆が出る")
	eq(m.play._tip.text, S.TIP_WARN, "初めての予兆で 1 行の案内")
	ok(m.play._tip_until > Time.get_ticks_msec(), "案内が出ている")
	kp(m, KEY_D)
	frames(m, 1)
	eq(m.play.fx.saves.size(), 1, "予兆の間に元を潰すと、止めた先に緑の輪")
	eq(m.play.fx.pops.size(), 1, "潰したキーの縁が弾ける")
	m.play.sim.put(idx("G"), Sim.BUG, true)
	m.play.sim.target[idx("G")] = idx("H")
	m.play.sim._events = []  # 直前の step の出来事はもう演出した
	m.play.sim.put(idx("G"), Sim.NEST, true)  # 教える順の置き直し(E-20)でも warn_cancel が出る
	for e: Dictionary in m.play.sim.events():
		m.play._on_event(e, {})
	eq(m.play.fx.saves.size(), 1, "置き直しで消えた予兆には輪を出さない")
	eq(m.play._tip.text, S.TIP_NEST, "巣が初めて出た時の案内")
	m.play._tip_until = 0
	m.play._on_event({"type": "warn", "from": idx("G"), "to": idx("H")}, {})
	eq(m.play._tip_until, 0, "同じ案内は 1 回の中で 1 度だけ")
	_done(m)
	return true


func test_polish_unlock_note_and_slide_clear_the_bars() -> bool:
	var m := _main()
	_playing(m)
	m.play._on_event({"type": "unlock"}, {})
	eq(m.play._tip.text, S.UNLOCK, "数字の段の知らせは盤の下の 1 行")
	ok(m.play._tip.position.y > Layout.key_rect(39).end.y, "盤より下に出る")
	ok(Layout.key_rect(0).position.y - B.UNLOCK_SLIDE_PX > 116 + 30 + 6, "上から入る数字の段が、上の棒(y 116〜146 と縦線 6 px)に重ならない")
	_done(m)
	return true


func test_polish_float_text_fits_and_stays_on_screen() -> bool:
	const Fx := preload("res://ui/fx.gd")
	const Kit := preload("res://ui/kit.gd")
	var widest := S.FLOAT % ["1,200", "x4.0"]
	var w := Kit.num_font().get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * B.BIG_SCALE)).x
	ok(w + B.FLOAT_OUTLINE * 2 <= B.FLOAT_W, "巣の大きい数字が枠に収まる(%d px)" % int(w))
	var fx := Fx.new()
	fx.now_ms = 1000
	fx.float_text(Layout.key_rect(idx("/")).get_center(), widest, true)
	fx.float_text(Layout.key_rect(idx("1")).get_center() - Vector2(200, 0), widest, true)
	ok(fx.floats[0][1].x + B.FLOAT_W / 2.0 <= 1280.0, "右端の / でも画面の外へ出ない")
	ok(fx.floats[1][1].x - B.FLOAT_W / 2.0 >= 0.0, "左へも出ない")
	fx.free()
	return true


func test_polish_danger_edge_and_over_veil_follow_reduce_flash() -> bool:
	const Play := preload("res://ui/play.gd")
	eq(Play.edge_alpha(9, 30, 0, false), 0.0, "感染 30% 以下は縁を出さない")
	eq(Play.edge_alpha(12, 40, 0, false), 0.0, "40 キーなら 12 まで出さない")
	var a0 := Play.edge_alpha(10, 30, 0, false)
	var a1 := Play.edge_alpha(10, 30, B.DANGER_PULSE_MS, false)
	ok(a0 >= B.DANGER_ALPHA_LO and a0 <= B.DANGER_ALPHA_HI and a0 != a1, "30% を超えたら縁が脈打つ")
	ok(Play.edge_alpha(Play.lose_at(30) - 2, 30, 0, false) > 0.0 and Play.edge_alpha(Play.lose_at(40) - 3, 40, 0, false) > 0.0, "負けの線の 2〜3 匹手前から出る")
	for now in [0, 100, 200, 300, 400]:
		ok(Play.edge_alpha(15, 40, now, true) <= B.REDUCED_FLASH_ALPHA, "点滅を弱めると縁は 20% 以下")
	eq(Play.veil_alpha(0, false), 0.0, "終わった瞬間は幕なし")
	ok(is_equal_approx(Play.veil_alpha(B.OVER_MS, false), B.OVER_VEIL_ALPHA), "400 ms で幕が一番濃い")
	ok(Play.veil_alpha(B.OVER_MS * 2, true) <= B.REDUCED_FLASH_ALPHA, "点滅を弱めると幕は 20% 以下")
	var m := _main()
	_playing(m)
	m.play.sim.queue_press(idx("F"))
	frames(m, 1)
	m.play.sim.over = true
	m.play._on_event({"type": "over", "reason": 0}, {})
	frames(m, 1)
	eq(m.play.fx.edge_alpha, 0.0, "終わったら縁は消して幕だけ")
	_done(m)
	return true


func test_load_scene_for_nfr1() -> bool:
	var m := _main()
	kp(m, KEY_X)
	m._load_test()
	for k in 60:
		frames(m, 1)
	eq(m.screen, "play", "負荷の場面は終わらない")
	ok(not m.play.sim.over, "15 匹は 40 キーの 40% に届かない")
	eq(m.play.sim.infected(), 15, "虫 15 匹")
	eq(m.play.sim.layout.active_count(), 40, "40 キー")
	eq(m.play.fx.shards.size(), B.SHARDS_MAX, "破片が上限(240)")
	eq(m.play.fx.floats.size(), B.FLOATS_MAX, "浮かぶ数字が上限(20)")
	_done(m)
	return true


func test_polish_lose_at_matches_core_line() -> bool:
	const Play := preload("res://ui/play.gd")
	eq(Play.lose_at(30), 12, "30 キーは 12 で終わり")
	eq(Play.lose_at(40), 16, "40 キーは 16 で終わり")
	for act in [30, 40]:
		var n := Play.lose_at(act)
		ok(n * 100 >= act * B.LOSE_PERCENT and (n - 1) * 100 < act * B.LOSE_PERCENT, "core の負けの線と同じ(%d)" % act)
	return true


func test_polish_buttons_are_opaque_and_title_keeps_settings() -> bool:
	const Kit := preload("res://ui/kit.gd")
	var b := Kit.button("x", "x")
	for on in [false, true]:
		Kit.set_selected(b, on)
		eq((b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a, 1.0, "ボタンの中は不透明(一時停止で盤が透けない)")
	b.free()
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_DOWN)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.screen, "settings", "設定")
	kp(m, KEY_ESCAPE)
	eq(m.current.menu.sel, 2, "設定から戻ると設定のボタンが選ばれたまま")
	_done(m)
	return true

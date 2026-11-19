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

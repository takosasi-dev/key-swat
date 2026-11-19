# sim の決まりのテスト(仕様書 §9.3〜§9.6・AC-4〜AC-10・AC-13・E-2〜E-8・E-16・E-20)。
extends "res://tests/suite.gd"

const Score := preload("res://core/score.gd")
const Schedule := preload("res://core/schedule.gd")


func test_ac4_squash_and_miss() -> bool:
	var sim := empty_board()
	var d := idx("D")
	sim.put(d, Sim.BUG, true)
	var ev := press(sim, d)
	eq(sim.state[d], Sim.CLEAN, "虫を押すと潰れる")
	eq(of_type(ev, "squash").size(), 1, "squash が出る")
	eq(sim.chain, 1, "つなぎ +1")
	ev = press(sim, idx("G"))
	eq(sim.integrity, 100 - B.MISS_DAMAGE, "clean を押すと耐久が 8 減る")
	eq(sim.chain, 0, "つなぎが 0")
	eq(sim.misses, 1, "外れの数")
	eq(of_type(ev, "miss")[0]["key"], idx("G"), "miss(キー)")
	return true


func test_squash_heals_up_to_max() -> bool:
	var sim := empty_board()
	sim.integrity = 99
	sim.put(idx("D"), Sim.BUG, true)
	sim.put(idx("K"), Sim.BUG, true)
	press(sim, idx("D"))
	eq(sim.integrity, 100, "潰すと +2、上限 100")
	sim.integrity = 50
	press(sim, idx("K"))
	eq(sim.integrity, 52, "+2")
	return true


func test_points_and_chain() -> bool:
	eq(Score.points(0, false), 100, "つなぎ 0 で ふつう = 100 点")
	eq(Score.points(30, true), 1200, "つなぎ 30 で巣 = 1,200 点")
	eq(Score.points(99, true), 1200, "つなぎ 30 以上は同じ")
	eq(Score.mult_text(Score.mult10(14)), "x2.4", "倍率の文字")
	var sim := empty_board()
	for k in 3:
		sim.put(20 + k, Sim.BUG, true)
	var ev := run_presses(sim, [20, 21, 22])
	eq(of_type(ev, "squash").map(func(e: Dictionary) -> int: return e["points"]), [100, 110, 120], "つなぎで点が伸びる")
	eq(sim.score, 330, "点の合計")
	eq(sim.max_chain, 3, "最大つなぎ")
	return true


func run_presses(sim: Sim, keys: Array) -> Array:
	var ev: Array = []
	for k: int in keys:
		ev.append_array(press(sim, k))
	return ev


func test_ac5_warn_exactly_60_before_spread() -> bool:
	var sim := empty_board(7)
	var d := idx("D")
	sim.put(d, Sim.BUG, true)
	var warn_at := -1
	var spread_at := -1
	var to := -1
	for t in 2000:
		sim.step()
		for e: Dictionary in sim.events():
			if e["type"] == "warn" and warn_at < 0:
				warn_at = t
				to = e["to"]
				ok(to in sim.layout.neighbors(d), "予兆の先は隣")
			elif e["type"] == "spread" and spread_at < 0:
				spread_at = t
				eq(e["to"], to, "予兆の先へ広がる")
		if spread_at >= 0:
			break
	ok(warn_at >= 0, "予兆が出る")
	eq(spread_at - warn_at, B.WARN_TICKS, "予兆はちょうど 60 tick 前")
	eq(warn_at + 1 + B.WARN_TICKS, B.SPREAD_START, "最初の広がりは置いてから間隔ぶん後")
	return true


func test_ac5_squash_during_warn_cancels() -> bool:
	var sim := empty_board(7)
	var d := idx("D")
	sim.put(d, Sim.BUG, true)
	var ev := run(sim, B.SPREAD_START - B.WARN_TICKS)
	eq(of_type(ev, "warn").size(), 1, "予兆が出た")
	var to: int = of_type(ev, "warn")[0]["to"]
	ev = press(sim, d)
	eq(of_type(ev, "warn_cancel").size(), 1, "元を潰すと warn_cancel")
	ev = run(sim, 200)
	eq(of_type(ev, "spread").size(), 0, "その広がりは起きない")
	eq(sim.state[to], Sim.CLEAN, "先は clean のまま")
	return true


func test_e5_pressing_warn_target_is_miss() -> bool:
	var sim := empty_board(7)
	var d := idx("D")
	sim.put(d, Sim.BUG, true)
	var ev := run(sim, B.SPREAD_START - B.WARN_TICKS)
	var to: int = of_type(ev, "warn")[0]["to"]
	ev = press(sim, to)
	eq(of_type(ev, "miss").size(), 1, "予兆の先を押すと外れ")
	eq(sim.target[d], to, "予兆は消えない")
	ev = run(sim, B.WARN_TICKS)
	eq(sim.state[to], Sim.BUG, "広がる")
	return true


func test_e7_target_already_bug() -> bool:
	var sim := empty_board(7)
	var d := idx("D")
	sim.put(d, Sim.BUG, true)
	var ev := run(sim, B.SPREAD_START - B.WARN_TICKS)
	var to: int = of_type(ev, "warn")[0]["to"]
	sim.put(to, Sim.BUG, false)
	ev = run(sim, B.WARN_TICKS)
	eq(of_type(ev, "spread").size(), 0, "先が既に虫なら何も置かない")
	eq(sim.target[d], -1, "予兆は消える")
	eq(sim.spread_left[d], sim.interval(Sim.BUG), "間隔を戻す")
	return true


func test_e8_no_candidates() -> bool:
	var sim := empty_board(7)
	var a := idx("A")
	sim.put(a, Sim.BUG, true)
	for j: int in sim.layout.neighbors(a):
		sim.put(j, Sim.BUG, false)
	var ev := run(sim, B.SPREAD_START)
	eq(of_type(ev, "warn").size(), 0, "候補が無ければ予兆を出さない")
	ok(sim.spread_left[a] > B.WARN_TICKS, "間隔を戻す")
	return true


func test_ac6_nest_three_presses() -> bool:
	var sim := empty_board()
	var n := idx("H")
	sim.put(n, Sim.NEST, true)
	var ev := press(sim, n)
	eq(types(ev), ["nest_hit"], "1 回目は nest_hit だけ")
	eq(ev[0]["hp"], 2, "残り 2")
	ev = press(sim, n)
	eq(types(ev), ["nest_hit"], "2 回目も nest_hit だけ")
	ev = press(sim, n)
	eq(types(ev), ["squash"], "3 回目で潰れる")
	eq(ev[0]["points"], 10 * (10 + 2) * 3, "巣は × 3、途中の押下もつなぎ +1")
	eq(sim.state[n], Sim.CLEAN, "clean に戻る")
	return true


func test_nest_spreads_faster() -> bool:
	var sim := empty_board()
	eq(sim.interval(Sim.NEST), B.SPREAD_START * 7 / 10, "巣は 0.7 倍")
	var n := idx("H")
	sim.put(n, Sim.NEST, true)
	var ev := run(sim, sim.interval(Sim.NEST))
	eq(of_type(ev, "spread").size(), 1, "巣の間隔で広がる")
	eq(sim.state[of_type(ev, "spread")[0]["to"]], Sim.BUG, "巣の子は ふつう")
	return true


func test_ac7_jumper_targets_second_ring() -> bool:
	for s in range(1, 21):
		var sim := empty_board(s)
		sim.layout.rebuild(true)
		var j := 10 + (s * 7) % 30
		sim.put(j, Sim.JUMPER, true)
		var ev := run(sim, B.SPREAD_START)
		var w := of_type(ev, "warn")
		ok(w.size() == 1 and int(w[0]["to"]) in sim.layout.second_ring(j), "跳ぶ虫の先は second_ring(種 %d)" % s)
		var sp := of_type(ev, "spread")
		ok(sp.size() == 1 and sim.state[sp[0]["to"]] == Sim.JUMPER, "跳ぶ虫の子は跳ぶ虫(種 %d)" % s)
	return true


func test_ac8_clock_waits_for_f() -> bool:
	var sim := Sim.new(5, Sim.MODE_DAILY)
	eq(sim.state[Sim.K_F], Sim.BUG, "初めは F に虫")
	eq(sim.spread_on[Sim.K_F], false, "F は広がらない")
	press(sim, idx("G"))
	press(sim, idx("A"))
	run(sim, 3000)
	eq(sim.clock, 0, "F を潰すまで時計は 0")
	eq(sim.integrity, 100, "その間の外れで耐久が減らない")
	eq(sim.misses, 0, "外れにも数えない")
	eq(sim.state[Sim.K_F], Sim.BUG, "F は広がらずに残る")
	eq(sim.infected(), 1, "虫は F だけ")
	var ev := press(sim, Sim.K_F)
	ok(sim.clock_running, "F を潰した step で時計が動く")
	eq(sim.clock, 1, "その step から進む")
	ok(ev.any(func(e: Dictionary) -> bool: return e["type"] == "spawn" and e["key"] == Sim.K_J), "同じ step で J に虫(教える順の 2)")
	eq(sim.spread_on[Sim.K_J], false, "J は広がらない")
	return true


func test_ac9_teach_order_by_time() -> bool:
	var sim := Sim.new(3, Sim.MODE_DAILY)
	sim.sched.plan.clear()  # 湧く予定は別に見る。ここでは教える順だけ
	press(sim, Sim.K_F)
	var spawns: Array = []  # [その step の前の時計, キー, 種類]
	var unlock_at := -1
	while sim.clock < B.TEACH_JUMPER_TICKS + 2:
		var c := sim.clock
		sim.step()
		for e: Dictionary in sim.events():
			if e["type"] == "spawn":
				spawns.append([c, e["key"], e["kind"]])
			elif e["type"] == "unlock":
				unlock_at = sim.clock
		# 広がりを止めて、感染で終わらせない
		for i in Layout.COUNT:
			if sim.state[i] != Sim.CLEAN and sim.spread_on[i]:
				sim.target[i] = -1
				sim.spread_left[i] = 9999
	ok([B.TEACH_DK_TICKS, Sim.K_D, Sim.BUG] in spawns, "D は時計 480 で(J を潰さない時)")
	ok([B.TEACH_DK_TICKS, Sim.K_K, Sim.BUG] in spawns, "K も時計 480 で")
	ok([B.TEACH_NEST_TICKS, sim.sched.nest_key, Sim.NEST] in spawns, "巣は時計 4800 で選んだキーに")
	ok(sim.sched.nest_key >= 20 and sim.sched.nest_key <= 29, "巣のキーは中の段")
	eq(unlock_at, B.UNLOCK_TICKS, "数字の段は時計 9600 で")
	ok([B.TEACH_JUMPER_TICKS, sim.sched.jumper_key, Sim.JUMPER] in spawns, "跳ぶ虫は時計 14400 で選んだキーに")
	eq(spawns.size(), 4, "F の後に出る教える順の虫は D・K・巣・跳ぶ虫の 4 つ(J は F を潰した step)")
	return true


func test_ac9_dk_when_j_squashed() -> bool:
	var sim := Sim.new(3, Sim.MODE_DAILY)
	press(sim, Sim.K_F)
	run(sim, 100)
	var ev := press(sim, Sim.K_J)
	var keys := of_type(ev, "spawn").map(func(e: Dictionary) -> int: return e["key"])
	eq(keys, [Sim.K_D, Sim.K_K], "J を潰した step で D と K")
	ok(sim.clock < B.TEACH_DK_TICKS, "480 より前")
	ok(sim.spread_on[Sim.K_D] and sim.spread_on[Sim.K_K], "D と K は広がる")
	return true


func test_e20_teach_converts_existing_bug() -> bool:
	var sim := Sim.new(3, Sim.MODE_DAILY)
	press(sim, Sim.K_F)
	var nk: int = sim.sched.nest_key
	sim.clock = B.TEACH_NEST_TICKS - 1
	sim.taught_dk = true
	sim.sched.plan.clear()
	sim.put(nk, Sim.BUG, false)
	run(sim, 2)
	eq(sim.state[nk], Sim.NEST, "既に虫なら巣に変える")
	eq(sim.hp[nk], B.NEST_HP, "hp は 3 に")
	ok(sim.spread_on[nk], "巣は広がる")
	return true


func test_ac10_infection_line() -> bool:
	var sim := empty_board()
	for k in 11:
		sim.put(10 + k, Sim.BUG, false)
	run(sim, 1)
	ok(not sim.is_over(), "30 キーで感染 11 なら続く")
	sim.put(30, Sim.BUG, false)
	var ev := run(sim, 1)
	ok(sim.is_over(), "30 キーで感染 12 で終わる")
	eq(sim.result()["reason"], Sim.OVER_INFECTION, "理由は感染")
	eq(of_type(ev, "over").size(), 1, "over が出る")
	sim = empty_board()
	sim.layout.rebuild(true)
	for k in 15:
		sim.put(k, Sim.BUG, false)
	run(sim, 1)
	ok(not sim.is_over(), "40 キーで感染 15 なら続く")
	sim.put(30, Sim.BUG, false)
	run(sim, 1)
	ok(sim.is_over(), "40 キーで感染 16 で終わる")
	return true


func test_integrity_zero_and_e16() -> bool:
	var sim := empty_board()
	sim.integrity = B.MISS_DAMAGE
	press(sim, idx("G"))
	ok(sim.is_over(), "耐久 0 で終わる")
	eq(sim.result()["reason"], Sim.OVER_INTEGRITY, "理由は耐久")
	sim = empty_board()
	for k in 12:
		sim.put(10 + k, Sim.BUG, false)
	sim.integrity = B.MISS_DAMAGE
	sim.queue_press(idx("/"))
	sim.step()
	eq(sim.result()["reason"], Sim.OVER_INFECTION, "同じ step で両方なら感染(E-16)")
	return true


func test_over_stops_everything() -> bool:
	var sim := empty_board()
	sim.integrity = B.MISS_DAMAGE
	press(sim, idx("G"))
	var r := sim.result()
	var ev := run(sim, 100)
	eq(ev.size(), 0, "終わった後は何も起きない")
	eq(sim.result(), r, "結果は変わらない")
	return true


func test_ac13_locked_digits_do_nothing() -> bool:
	var sim := empty_board()
	sim.put(idx("D"), Sim.BUG, true)
	press(sim, idx("D"))
	var before := [sim.integrity, sim.chain, sim.state.duplicate(), sim.misses]
	var ev := press(sim, 0)
	ev.append_array(press(sim, 9))
	eq(ev.filter(func(e: Dictionary) -> bool: return e["type"] in ["miss", "squash", "nest_hit"]).size(), 0, "解放前の数字は何も出さない")
	eq([sim.integrity, sim.chain, sim.state.duplicate(), sim.misses], before, "耐久・つなぎ・盤が変わらない")
	return true


func test_e4_same_key_twice_in_one_step() -> bool:
	var sim := empty_board()
	var d := idx("D")
	sim.put(d, Sim.BUG, true)
	sim.queue_press(d)
	sim.queue_press(d)
	sim.step()
	eq(types(sim.events()), ["squash", "miss"], "来た順。2 回目は外れ")
	return true


func test_unlock_event_and_digits_join() -> bool:
	var sim := empty_board()
	sim.clock = B.UNLOCK_TICKS - 1
	var ev := run(sim, 1)
	eq(of_type(ev, "unlock").size(), 1, "unlock が出る")
	eq(sim.layout.active_count(), 40, "40 キー")
	press(sim, 0)
	eq(sim.misses, 1, "解放後の数字は外れになる")
	return true


func test_interval_curve() -> bool:
	eq(Schedule.curve(B.SPREAD_START, B.SPREAD_END, 0), B.SPREAD_START, "始めは START")
	eq(Schedule.curve(B.SPREAD_START, B.SPREAD_END, B.CURVE_FROM), B.SPREAD_START, "CURVE_FROM までは START")
	eq(Schedule.curve(B.SPREAD_START, B.SPREAD_END, B.CURVE_FROM + B.CURVE_SPAN), B.SPREAD_END, "上がりきると END")
	eq(Schedule.curve(B.SPREAD_START, B.SPREAD_END, 999999), B.SPREAD_END, "その後も END")
	eq(Schedule.curve(600, 144, B.CURVE_FROM + B.CURVE_SPAN / 2), 372, "半分で真ん中")
	return true


func test_balance_min_interval_above_warn() -> bool:
	ok(B.SPREAD_END * B.NEST_RATE_NUM / B.NEST_RATE_DEN >= B.WARN_TICKS + 1, "巣の最小の間隔も WARN_TICKS + 1 以上(§9.7)")
	ok(B.SPREAD_END >= B.WARN_TICKS + 1, "ふつうの最小の間隔")
	ok(B.SPAWN_END > 0, "湧く間隔は正")
	return true

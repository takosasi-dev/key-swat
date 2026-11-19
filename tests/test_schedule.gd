# 湧く予定・決定性・bot のテスト(仕様書 §9.5・§9.10・AC-2・AC-11・AC-12・INV-3)。
extends "res://tests/suite.gd"

const Schedule := preload("res://core/schedule.gd")
const Bots := preload("res://core/bots.gd")


func test_ac12_plan_depends_only_on_seed() -> bool:
	var a := Sim.new(42)
	var b := Sim.new(42)
	Bots.play(a, Bots.GOOD, 3000)
	Bots.play(b, Bots.MASH, 3000)
	eq(a.sched.plan, b.sched.plan, "操作が違っても湧く予定の列が同じ")
	eq(a.sched.plan, Schedule.new(42).plan, "遊んでも予定は変わらない")
	eq([a.sched.nest_key, a.sched.jumper_key], [b.sched.nest_key, b.sched.jumper_key], "教える順のキーも同じ")
	ok(Schedule.new(43).plan != a.sched.plan, "種が違えば予定も違う")
	return true


func test_plan_shape() -> bool:
	var s := Schedule.new(9)
	var last := 0
	for p: Array in s.plan:
		ok(int(p[0]) > last, "時刻は増える")
		last = p[0]
		ok(int(p[1]) >= 0 and int(p[1]) < 40, "キーは 0〜39")
		if int(p[0]) < B.SPAWN_NORMAL_ONLY:
			eq(p[2], Schedule.KIND_BUG, "時計 60 秒までは ふつう だけ")
		if int(p[2]) == Schedule.KIND_JUMPER:
			ok(int(p[0]) > B.TEACH_JUMPER_TICKS, "跳ぶ虫は 120 秒の後")
	ok(int(s.plan[0][0]) > B.SPAWN_FIRST, "時計 10 秒の後から")
	ok(int(s.plan[-1][0]) > B.SPAWN_UNTIL and int(s.plan[-2][0]) <= B.SPAWN_UNTIL, "60 分ぶん")
	ok(s.plan.size() <= 4500, "最大 4,500 件(非機能 §2)")
	ok(s.plan.any(func(p: Array) -> bool: return p[2] == Schedule.KIND_NEST), "巣も湧く")
	ok(s.plan.any(func(p: Array) -> bool: return p[2] == Schedule.KIND_JUMPER), "跳ぶ虫も湧く")
	return true


func test_spread_seed_never_zero() -> bool:
	eq(Schedule.new(B.SPREAD_RNG_XOR).spread_seed, 1, "seed ^ 0x9E3779B9 が 0 なら 1")
	eq(Schedule.new(1).spread_seed, 1 ^ B.SPREAD_RNG_XOR, "ふつうは seed ^ 0x9E3779B9")
	return true


func test_spawns_skip_busy_and_locked_keys() -> bool:
	var sim := empty_board(11)
	sim.sched.plan = [[5, 3, Schedule.KIND_BUG], [6, idx("D"), Schedule.KIND_NEST], [7, idx("D"), Schedule.KIND_BUG]]
	var ev := run(sim, 10)
	eq(sim.state[3], Sim.CLEAN, "解放前の数字の段は飛ばす")
	eq(sim.state[idx("D")], Sim.NEST, "湧く")
	eq(of_type(ev, "spawn").size(), 1, "既に虫なら飛ばす")
	eq(sim.hp[idx("D")], B.NEST_HP, "巣は hp 3 のまま")
	return true


# 固定の入力の記録(正しい bot が押した列)を、同じ種で 100 回流す。
func test_ac2_determinism_100_runs() -> bool:
	var rec: Array = []  # [step_no, キー]
	var sim := Sim.new(77)
	var d := Bots.Driver.new(Bots.GOOD, 77)
	while sim.clock < 3000:
		var before := sim._queue.size()
		d.feed(sim)
		for k in range(before, sim._queue.size()):
			rec.append([sim.step_no, sim._queue[k]])
		sim.step()
	var want := [sim.score, sim.clock, sim.squashed]
	ok(sim.squashed > 5, "記録に潰す押下がある")
	var same := 0
	for n in 100:
		var s := Sim.new(77)
		var r := 0
		while s.step_no < sim.step_no:
			while r < rec.size() and int(rec[r][0]) == s.step_no:
				s.queue_press(rec[r][1])
				r += 1
			s.step()
		if [s.score, s.clock, s.squashed] == want:
			same += 1
	eq(same, 100, "100 回とも点・守った tick・潰した数が同じ")
	return true


func test_fixed_input_golden() -> bool:
	# Windows と CI(Linux)で同じ値になるかを見る固定値(NFR-4)。値を変える時は理由を CHANGELOG に書く
	var r := Bots.play(Sim.new(2026), Bots.GOOD, 6000)
	var g := Bots.play(Sim.new(2026), Bots.IDLE, 60000)
	print("      固定値: 正しい bot 6000 tick ", r, " / 何もしない bot ", g)
	eq([r["score"], r["squashed"], r["max_chain"]], GOLDEN_GOOD, "正しい bot の固定値")
	eq([g["ticks"], g["score"]], GOLDEN_IDLE, "何もしない bot の固定値")
	return true


const GOLDEN_GOOD := [2830, 14, 16]
const GOLDEN_IDLE := [2160, 100]


func test_ac11_masher_dies_before_good_bot() -> bool:
	for s in range(1, 11):
		var good := Bots.play(Sim.new(s), Bots.GOOD, 12000)
		var mash := Bots.play(Sim.new(s), Bots.MASH, 12000)
		ok(not mash["capped"], "連打 bot は負ける(種 %d)" % s)
		ok(int(mash["ticks"]) < int(good["ticks"]), "連打 bot が正しい bot より短い時間で負ける(種 %d: 連打 %d / 正しい %d)" % [s, mash["ticks"], good["ticks"]])
	return true


func test_idle_bot_loses_by_infection() -> bool:
	var r := Bots.play(Sim.new(5), Bots.IDLE, 60000)
	ok(not r["capped"], "何もしない bot は負ける")
	eq(r["reason"], Sim.OVER_INFECTION, "感染で")
	eq(r["misses"], 0, "外れなし")
	return true


func test_good_bot_never_misses() -> bool:
	var r := Bots.play(Sim.new(8), Bots.GOOD, 6000)
	eq(r["misses"], 0, "正しい bot は外さない")
	ok(r["squashed"] > 10, "潰す")
	return true

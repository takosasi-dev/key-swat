# 1 回のプレイの全状態と step()(仕様書 §9.3〜§9.5)。湧く・広がる・潰す・外れ・点・負けはここにだけ書く(INV-1)。
# 入力は盤の番号(0〜39)だけ(INV-5)。1 step = 1/120 秒。ui は events() と snapshot() を読んで描くだけ。
extends RefCounted

const B := preload("res://core/balance.gd")
const Layout := preload("res://core/layout.gd")
const Schedule := preload("res://core/schedule.gd")
const Rng := preload("res://core/rng.gd")
const Score := preload("res://core/score.gd")

const MODE_DAILY := 0
const MODE_PRACTICE := 1
# キーの状態。種類の番号は schedule の KIND_* と同じ
const CLEAN := 0
const BUG := 1
const NEST := 2
const JUMPER := 3
const OVER_INFECTION := 0
const OVER_INTEGRITY := 1
# 教える順のキー(§9.5)
const K_F := 23
const K_J := 26
const K_D := 22
const K_K := 27

var mode := MODE_DAILY
var seed_value := 1
var layout: Layout
var sched: Schedule
var spread_rng: Rng
var state: Array[int] = []
var hp: Array[int] = []
var spread_left: Array[int] = []
var spread_on: Array[bool] = []
var target: Array[int] = []
var step_no := 0  # 進めた step の数(時計が止まっている間も数える)
var clock := 0  # 守った時間(tick)。F を潰した step から進む(D-6)
var clock_running := false
var integrity := B.INTEGRITY_MAX
var chain := 0
var max_chain := 0
var score := 0
var squashed := 0
var misses := 0
var over := false
var reason := -1
var taught_j := false
var taught_dk := false
var taught_nest := false
var taught_jumper := false
var unlocked := false
var _j_gone := false
var _plan_i := 0
var _placed_at: Array[int] = []  # その虫を置いた step(置いた step では広がりの時計を減らさない)
var _queue: Array[int] = []
var _events: Array = []


# p_mode: 0 = 今日の盤、1 = 練習。first_bug を偽にすると教える順の 1(F の虫)を置かない(テスト用)。
func _init(p_seed: int = 1, p_mode: int = MODE_DAILY, first_bug: bool = true) -> void:
	seed_value = p_seed
	mode = p_mode
	layout = Layout.new(false)
	sched = Schedule.new(p_seed)
	spread_rng = Rng.new(sched.spread_seed)
	for i in Layout.COUNT:
		state.append(CLEAN)
		hp.append(0)
		spread_left.append(0)
		spread_on.append(false)
		target.append(-1)
		_placed_at.append(-1)
	if first_bug:
		put(K_F, BUG, false)
		_events.clear()


func queue_press(i: int) -> void:
	if not over:
		_queue.append(i)


func events() -> Array:
	return _events


func is_over() -> bool:
	return over


# 今の広がりの間隔(§9.4)。巣は × 7 ÷ 10。
@warning_ignore("integer_division")
func interval(kind: int) -> int:
	var base := Schedule.curve(B.SPREAD_START, B.SPREAD_END, clock)
	return base * B.NEST_RATE_NUM / B.NEST_RATE_DEN if kind == NEST else base


# キー i に虫を置く(既に虫なら置き直す。E-20)。教える順・湧く予定・テストが使う。
func put(i: int, kind: int, spreading: bool, emit_spawn: bool = true) -> void:
	if target[i] >= 0:
		_events.append({"type": "warn_cancel", "from": i, "to": target[i]})
	state[i] = kind
	hp[i] = B.NEST_HP if kind == NEST else 1
	spread_on[i] = spreading
	spread_left[i] = interval(kind)
	target[i] = -1
	_placed_at[i] = step_no
	if emit_spawn:
		_events.append({"type": "spawn", "key": i, "kind": kind})


func infected() -> int:
	var n := 0
	for i in Layout.COUNT:
		if state[i] != CLEAN and layout.active[i]:
			n += 1
	return n


func step() -> void:
	_events = []
	if over:
		_queue.clear()
		return
	step_no += 1
	# 2. 押下を来た順に
	for i in _queue:
		_press(i)
	_queue.clear()
	# 3. 教える順と湧く予定
	if clock_running:
		_teach_and_spawn()
	# 4. 広がり
	for i in Layout.COUNT:
		if state[i] == CLEAN or not spread_on[i] or _placed_at[i] == step_no:
			continue
		spread_left[i] -= 1
		if spread_left[i] == B.WARN_TICKS:
			_choose_target(i)
		elif spread_left[i] <= 0:
			_spread(i)
	# 5. 終わり(同じ step で両方なら感染。E-16)
	if infected() * 100 >= layout.active_count() * B.LOSE_PERCENT:
		_finish(OVER_INFECTION)
		return
	if integrity <= 0:
		_finish(OVER_INTEGRITY)
		return
	# 6. 時計
	if clock_running:
		clock += 1
		if clock == B.UNLOCK_TICKS and not unlocked:
			unlocked = true
			layout.rebuild(true)
			_events.append({"type": "unlock"})


func _press(i: int) -> void:
	if i < 0 or i >= Layout.COUNT or not layout.active[i]:
		return  # 解放前の数字の段は何もしない(E-2)
	if state[i] == CLEAN:
		chain = 0
		if clock_running:  # 時計が動く前の外れは数えない(D-6)
			integrity = maxi(integrity - B.MISS_DAMAGE, 0)
			misses += 1
		_events.append({"type": "miss", "key": i})
		return
	var before := chain
	chain += 1
	max_chain = maxi(max_chain, chain)
	hp[i] -= 1
	if hp[i] > 0:
		_events.append({"type": "nest_hit", "key": i, "hp": hp[i]})
		return
	var kind := state[i]
	var pts := Score.points(before, kind == NEST)
	score += pts
	squashed += 1
	integrity = mini(integrity + B.SQUASH_HEAL, B.INTEGRITY_MAX)
	if target[i] >= 0:
		_events.append({"type": "warn_cancel", "from": i, "to": target[i]})
	state[i] = CLEAN
	target[i] = -1
	_events.append({"type": "squash", "key": i, "points": pts, "mult10": Score.mult10(before), "kind": kind, "chain": chain})
	if not clock_running:
		clock_running = true  # F を潰した step から時計が動く(FR-11)
	elif i == K_J and taught_j and not taught_dk:
		_j_gone = true


func _teach_and_spawn() -> void:
	if not taught_j:
		taught_j = true
		put(K_J, BUG, false)
	if not taught_dk and (_j_gone or clock >= B.TEACH_DK_TICKS):
		taught_dk = true
		for k: int in [K_D, K_K]:
			if state[k] == CLEAN:
				put(k, BUG, true)
	if not taught_nest and clock >= B.TEACH_NEST_TICKS:
		taught_nest = true
		put(sched.nest_key, NEST, true)
	if not taught_jumper and clock >= B.TEACH_JUMPER_TICKS:
		taught_jumper = true
		put(sched.jumper_key, JUMPER, true)
	while _plan_i < sched.plan.size() and int(sched.plan[_plan_i][0]) <= clock:
		var p: Array = sched.plan[_plan_i]
		_plan_i += 1
		var k: int = p[1]
		if layout.active[k] and state[k] == CLEAN:  # 解放前・既に虫なら飛ばす
			put(k, p[2], true)


func _choose_target(i: int) -> void:
	var src: Array[int] = layout.second_ring(i) if state[i] == JUMPER else layout.neighbors(i)
	var cand: Array[int] = []
	for j in src:
		if state[j] == CLEAN:
			cand.append(j)
	if cand.is_empty():
		spread_left[i] = interval(state[i])  # 候補が無ければ予兆を出さず、間隔を戻す(E-8)
		return
	target[i] = cand[spread_rng.next_int(cand.size())]
	_events.append({"type": "warn", "from": i, "to": target[i]})


func _spread(i: int) -> void:
	var t := target[i]
	if t >= 0 and state[t] == CLEAN:
		put(t, JUMPER if state[i] == JUMPER else BUG, true, false)
		_events.append({"type": "spread", "from": i, "to": t})
	spread_left[i] = interval(state[i])
	target[i] = -1


func _finish(why: int) -> void:
	over = true
	reason = why
	_events.append({"type": "over", "reason": why})


func snapshot() -> Dictionary:
	return {"state": state.duplicate(), "hp": hp.duplicate(), "target": target.duplicate(), "spread_left": spread_left.duplicate(),
		"spread_on": spread_on.duplicate(), "active": layout.active.duplicate(), "integrity": integrity, "infected": infected(),
		"active_count": layout.active_count(), "clock": clock, "clock_running": clock_running, "score": score, "chain": chain,
		"mult10": Score.mult10(chain), "max_chain": max_chain, "squashed": squashed, "misses": misses, "over": over, "reason": reason}


func result() -> Dictionary:
	return {"ticks": clock, "score": score, "squashed": squashed, "max_chain": max_chain, "misses": misses, "reason": reason}

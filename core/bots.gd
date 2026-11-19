# テスト用の bot 3 種(仕様書 §9.10): 正しい bot・連打 bot・何もしない bot。AC-11 と撤退基準 R-3 の判定に使う。
# Driver.feed(sim) を sim.step() の前に毎回呼ぶと、その tick の押下を queue_press する。
extends RefCounted

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")
const Sim := preload("res://core/sim.gd")
const Layout := preload("res://core/layout.gd")

const GOOD := 0
const MASH := 1
const IDLE := 2
const NAMES := ["正しい", "連打", "何もしない"]


class Driver:
	var kind := 0
	var rng: Rng
	var n := 0

	func _init(p_kind: int, p_seed: int) -> void:
		kind = p_kind
		var s := (p_seed ^ B.BOT_RNG_XOR) & Rng.MASK
		rng = Rng.new(s if s != 0 else 1)

	func feed(sim: Sim) -> void:
		match kind:
			GOOD:
				if n % B.BOT_GOOD_EVERY == 0:
					var i := pick_good(sim)
					if i >= 0:
						sim.queue_press(i)
			MASH:
				if n % B.BOT_MASH_EVERY == 0:
					var pool: Array[int] = []
					for k in Layout.COUNT:
						if sim.layout.active[k]:
							pool.append(k)
					for m in B.BOT_MASH_KEYS:  # 重ならない 4 つ(手のひら)
						sim.queue_press(pool.pop_at(rng.next_int(pool.size())))
			IDLE:
				if n == 0:
					sim.queue_press(Sim.K_F)
		n += 1

	# 正しい bot の次の 1 つ: 巣 → 予兆中の元 → ほかの虫。それぞれ spread_left の小さい順、同じなら番号の小さい順。無ければ -1。
	static func pick_good(sim: Sim) -> int:
		var best := -1
		var best_key := 0
		for i in Layout.COUNT:
			var st: int = sim.state[i]
			if st == Sim.CLEAN:
				continue
			var group := 0 if st == Sim.NEST else (1 if sim.target[i] >= 0 else 2)
			var key: int = (group * 100000 + sim.spread_left[i]) * 64 + i
			if best < 0 or key < best_key:
				best = i
				best_key = key
		return best


# 負けるか、時計が cap に届くまで遊ばせる。result に capped(上限まで生き残った)を足して返す。
static func play(sim: Sim, kind: int, cap: int = B.BOT_TICK_CAP) -> Dictionary:
	var d := Driver.new(kind, sim.seed_value)
	var guard := cap + 100000  # 時計が動かないまま終わらない時の止め
	while not sim.is_over() and sim.clock < cap and sim.step_no < guard:
		d.feed(sim)
		sim.step()
	var r := sim.result()
	r["capped"] = not sim.is_over()
	return r

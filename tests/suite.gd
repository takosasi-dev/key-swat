# テストの土台。ok / eq で確かめ、失敗は errors にたまる。盤を組み立てて進める道具も持つ。
# 各テストは最後に true を返す(途中で止まったことを見分けるため)。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Layout := preload("res://core/layout.gd")

var errors: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if typeof(got) != typeof(want) or got != want:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


# 時計が動いている、虫の無い盤(教える順は済ませ、湧く予定も出さない)。
static func empty_board(p_seed: int = 1) -> Sim:
	var sim := Sim.new(p_seed, Sim.MODE_PRACTICE, false)
	sim.clock_running = true
	sim.taught_j = true
	sim.taught_dk = true
	sim.taught_nest = true
	sim.taught_jumper = true
	sim.sched.plan.clear()
	return sim


static func run(sim: Sim, ticks: int) -> Array:
	var ev: Array = []
	for k in ticks:
		sim.step()
		ev.append_array(sim.events())
	return ev


static func press(sim: Sim, i: int) -> Array:
	sim.queue_press(i)
	return run(sim, 1)


static func types(ev: Array) -> Array:
	return ev.map(func(e: Dictionary) -> String: return e["type"])


static func of_type(ev: Array, t: String) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return e["type"] == t)


static func idx(label: String) -> int:
	return Layout.LABELS.find(label)


static func labels(list: Array) -> Array:
	var out := list.map(func(i: int) -> String: return Layout.LABELS[i])
	out.sort()
	return out

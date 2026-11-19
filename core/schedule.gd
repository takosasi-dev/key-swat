# 湧く予定を種から作る(仕様書 §9.5・D-5・INV-3)。予定は種だけで決まり、操作では変わらない。
# 巣と跳ぶ虫の教える順のキーもここで先に引く。広がり先の乱数の種もここで決める。
extends RefCounted

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")

const KIND_BUG := 1
const KIND_NEST := 2
const KIND_JUMPER := 3

var nest_key := 20
var jumper_key := 0
var spread_seed := 1
var plan: Array = []  # [t, キー, 種類] の列。t は小さい順


# 時計 clock の時の間隔。start から end へ、CURVE_FROM から CURVE_SPAN かけて縮める(§9.4 と同じ式)。
@warning_ignore("integer_division")
static func curve(start: int, end: int, clock: int) -> int:
	return start - (start - end) * mini(maxi(clock - B.CURVE_FROM, 0), B.CURVE_SPAN) / B.CURVE_SPAN


# 仕様書の schedule.build(seed) にあたる(Schedule.new(seed) で作る)。
func _init(p_seed: int = 1) -> void:
	var s := self
	var rng := Rng.new(p_seed)
	var sp := (p_seed ^ B.SPREAD_RNG_XOR) & Rng.MASK
	s.spread_seed = sp if sp != 0 else 1
	s.nest_key = 20 + rng.next_int(10)
	s.jumper_key = rng.next_int(40)
	var t := B.SPAWN_FIRST
	while t <= B.SPAWN_UNTIL:
		t += curve(B.SPAWN_START, B.SPAWN_END, t)
		var key := rng.next_int(40)
		var kind := KIND_BUG
		if t >= B.SPAWN_NORMAL_ONLY:
			var r := rng.next_int(100)
			if r < B.SPAWN_NEST_PCT:
				kind = KIND_NEST
			elif t > B.TEACH_JUMPER_TICKS and r < B.SPAWN_JUMPER_PCT:
				kind = KIND_JUMPER
		s.plan.append([t, key, kind])

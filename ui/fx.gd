# 盤の上の演出(仕様書 §9.8): 潰した時の破片 6 個(250 ms)と縁の弾け、上へ流れる「+100 x1.0」(600 ms)、広がりの波紋(200 ms)、
# 広がりを止めた先の緑の輪、感染が終わりに近い時の画面の縁の赤、終わった瞬間の赤い幕。見た目だけで、ゲームの決まりは持たない。
# 時刻(ms)で描き、終わった物は捨てる。破片は 240 個、数字は 20 個まで。縁と幕の濃さは play が決めて書き込む。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

var shards: Array = []  # [at, 中心, 向き, 色]
var floats: Array = []  # [at, 位置, 文字, 大きいか]
var ripples: Array = []  # [at, 中心]
var pops: Array = []  # [at, キーの四角]
var saves: Array = []  # [at, 中心]
var edge_alpha := 0.0  # 画面の縁の赤(感染が終わりに近い)
var veil_alpha := 0.0  # 画面全体の赤い幕(終わった瞬間)
var now_ms := 0
var view := Rect2(0, 0, 1280, 720)  # 窓に見えている範囲(縁と幕はここ全体に描く。main が入れる)
var draws := 0  # 描いた回数(smoke が読む)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


func burst(at: Vector2, color: Color) -> void:
	var t := _now()
	for k in B.SHARDS:
		var ang := TAU * k / B.SHARDS + 0.3
		shards.append([t, at, Vector2(cos(ang), sin(ang)), color])
	while shards.size() > B.SHARDS_MAX:
		shards.pop_front()


# 浮かぶ数字。画面の外へはみ出さないように、中心を左右の端から幅の半分だけ内側に寄せる。
func float_text(at: Vector2, text: String, big: bool) -> void:
	var half := B.FLOAT_W / 2.0
	floats.append([_now(), Vector2(clampf(at.x, half, 1280.0 - half), at.y), text, big])
	while floats.size() > B.FLOATS_MAX:
		floats.pop_front()


func ripple(at: Vector2) -> void:
	ripples.append([_now(), at])


# 潰したキーの縁が外へ弾ける。
func pop(rect: Rect2) -> void:
	pops.append([_now(), rect])


# 予兆の間に元を潰して、広がりを止めた先のキー。緑の輪が縮んで消える。
func saved(at: Vector2) -> void:
	saves.append([_now(), at])


func tick() -> void:
	var t := _now()
	shards = shards.filter(func(s: Array) -> bool: return t - int(s[0]) < B.SHARD_MS)
	floats = floats.filter(func(f: Array) -> bool: return t - int(f[0]) < B.FLOAT_MS)
	ripples = ripples.filter(func(r: Array) -> bool: return t - int(r[0]) < B.RIPPLE_MS)
	pops = pops.filter(func(p: Array) -> bool: return t - int(p[0]) < B.POP_MS)
	saves = saves.filter(func(s: Array) -> bool: return t - int(s[0]) < B.SAVED_MS)
	queue_redraw()


func _draw() -> void:
	draws += 1
	var t := _now()
	if edge_alpha > 0.0:
		draw_rect(view.grow(-B.DANGER_EDGE_PX / 2.0), Color(Kit.C_BUG, edge_alpha), false, B.DANGER_EDGE_PX)
	for p: Array in pops:
		var k := float(t - int(p[0])) / B.POP_MS
		draw_rect((p[1] as Rect2).grow(B.POP_GROW_PX * k), Color(Kit.C_WHITE, 0.9 * (1.0 - k)), false, 3.0, true)
	for s: Array in shards:
		var k := float(t - int(s[0])) / B.SHARD_MS
		var p: Vector2 = s[1] + s[2] * (20.0 + 90.0 * k)
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(s[3], 1.0 - k))
	for r: Array in ripples:
		var k := float(t - int(r[0])) / B.RIPPLE_MS
		draw_arc(r[1], 44.0 + 40.0 * k, 0.0, TAU, 40, Color(Kit.C_BUG, 1.0 - k), 3.0, true)
	for s: Array in saves:
		var k := float(t - int(s[0])) / B.SAVED_MS
		draw_arc(s[1], 62.0 - 24.0 * k, 0.0, TAU, 40, Color(Kit.C_GOOD, 1.0 - k), 5.0, true)
	for f: Array in floats:
		var k := float(t - int(f[0])) / B.FLOAT_MS
		var size := int(28 * (B.BIG_SCALE if f[3] else 1.0))
		var p: Vector2 = f[1] - Vector2(B.FLOAT_W / 2.0, B.FLOAT_RISE_PX * k)
		var a := 1.0 - k * k
		draw_string_outline(Kit.num_font(), p, f[2], HORIZONTAL_ALIGNMENT_CENTER, B.FLOAT_W, size, B.FLOAT_OUTLINE, Color(Kit.C_BG, a))
		draw_string(Kit.num_font(), p, f[2], HORIZONTAL_ALIGNMENT_CENTER, B.FLOAT_W, size, Color(Kit.C_GOOD if f[3] else Kit.C_TEXT, a))
	if veil_alpha > 0.0:
		draw_rect(view, Color(Kit.C_BUG, veil_alpha))

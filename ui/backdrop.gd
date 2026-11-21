# 全部の画面の後ろ(v0.3.0): 墨の青緑の地に、検査票の方眼(細い罫 32 px・太い罫 128 px)と、舞台の四隅の見当の印。
# animate の間は、薄い走査線がゆっくり上から下へ流れる(タイトル・S0。点滅を弱める 入なら止める)。窓の見えている範囲(view)全体に描く。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

var view := Rect2(0, 0, 1280, 720)  # 舞台の座標で見えている範囲(main が入れる)
var animate := false
var now_ms := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if animate:
		queue_redraw()


# 走査線の y(舞台の座標)。時刻だけで決まる。
static func scan_y(now: int, top: float, height: float) -> float:
	return top + height * fmod(float(now), B.SCAN_PERIOD_MS) / B.SCAN_PERIOD_MS


func _draw() -> void:
	draw_rect(view, Kit.C_BG)
	var minor := Color(Kit.C_RULE, 0.22)
	var major := Color(Kit.C_RULE, 0.5)
	var x0 := floorf(view.position.x / 32.0) * 32.0
	var y0 := floorf(view.position.y / 32.0) * 32.0
	var x := x0
	while x <= view.end.x:
		draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), major if int(x) % 128 == 0 else minor, 1.0)
		x += 32.0
	var y := y0
	while y <= view.end.y:
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), major if int(y) % 128 == 0 else minor, 1.0)
		y += 32.0
	# 舞台の四隅の見当(十字)
	for c: Vector2 in [Vector2(14, 14), Vector2(1266, 14), Vector2(14, 706), Vector2(1266, 706)]:
		draw_line(c - Vector2(10, 0), c + Vector2(10, 0), Color(Kit.C_ACCENT, 0.35), 2.0)
		draw_line(c - Vector2(0, 10), c + Vector2(0, 10), Color(Kit.C_ACCENT, 0.35), 2.0)
	if animate:
		var now := now_ms if now_ms > 0 else Time.get_ticks_msec()
		var sy := scan_y(now, view.position.y, view.size.y)
		draw_rect(Rect2(view.position.x, sy - 90, view.size.x, 90), Color(Kit.C_ACCENT, 0.025))
		draw_line(Vector2(view.position.x, sy), Vector2(view.end.x, sy), Color(Kit.C_ACCENT, 0.09), 2.0)

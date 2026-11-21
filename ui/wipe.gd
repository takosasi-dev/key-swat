# 画面の切り替わり(v0.3.0): 検査光の線が見えている範囲を上から下へ走り、線より下はまだ前の地(墨)で隠す。WIPE_MS で終わる。
# 見た目だけで入力は飲まない(新しい画面は最初から押せる。マウスも通す)。点滅を弱める 入なら main が呼ばない。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

var view := Rect2(0, 0, 1280, 720)
var start_ms := -100000
var now_ms := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func run() -> void:
	start_ms = Time.get_ticks_msec()
	queue_redraw()


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


# 走り終わるまでの割合(0→1)。走っていなければ 1。
func progress() -> float:
	return clampf(float(_now() - start_ms) / B.WIPE_MS, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _now() - start_ms <= B.WIPE_MS + 50:
		queue_redraw()


func _draw() -> void:
	var k := progress()
	if k >= 1.0:
		return
	var y := view.position.y + view.size.y * Kit.ease_out(k)
	draw_rect(Rect2(view.position.x, y, view.size.x, view.end.y - y), Color(Kit.C_BG, 0.94))
	draw_rect(Rect2(view.position.x, y - 48, view.size.x, 48), Color(Kit.C_ACCENT, 0.05))
	draw_rect(Rect2(view.position.x, y - 12, view.size.x, 12), Color(Kit.C_ACCENT, 0.08))
	draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), Kit.C_ACCENT, 3.0)

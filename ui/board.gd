# 盤の描画(仕様書 §9.1・画面設計書 §3・§8)。sim.snapshot() の中身を、キーごとの形で描くだけ(INV-1)。
# 虫の種類は形で分ける(ふつう = 丸、巣 = 白い点と太い縁、跳ぶ虫 = ひし形、予兆の先 = 橙の縁と切り欠き。NFR-11)。
# 外れの光・巣の震え・湧いた時の膨らみ・数字の段の入り方は、play が時刻(ms)を書き込み、ここで時刻から描く。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Layout := preload("res://core/layout.gd")
const Kit := preload("res://ui/kit.gd")

var snap: Dictionary = {}
var reduce_flash := false
var show_locked := true  # 解放前の数字の段を枠で出すか(タイトルの薄い盤は出さない)
var miss_at: Array[int] = []
var hit_at: Array[int] = []
var spawn_at: Array[int] = []
var unlock_at := -100000
var now_ms := 0  # 描く時刻(テストが固定できるように持つ)
var draws := 0  # 描いた回数(smoke が読む)

var _sb := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Layout.COUNT:
		miss_at.append(-100000)
		hit_at.append(-100000)
		spawn_at.append(-100000)
	_sb["clean"] = Kit.box(Kit.C_KEY, Kit.C_KEY, 0, 8)
	_sb["bug"] = Kit.box(Kit.C_BUG, Kit.C_BUG, 0, 8)
	_sb["nest"] = Kit.box(Kit.C_NEST, Kit.C_WHITE, 4, 8)
	_sb["jumper"] = Kit.box(Kit.C_JUMPER, Kit.C_JUMPER, 0, 8)
	_sb["locked"] = Kit.box(Color(0, 0, 0, 0), Kit.C_EDGE, 2, 8)


# タイトルに薄く出す盤(段 1〜3、F だけ赤い)。
static func title_snap() -> Dictionary:
	var st: Array[int] = []
	var act: Array[bool] = []
	var tg: Array[int] = []
	var hp: Array[int] = []
	for i in Layout.COUNT:
		st.append(Sim.BUG if i == Sim.K_F else Sim.CLEAN)
		act.append(Layout.row_of(i) != Layout.DIGIT_ROW)
		tg.append(-1)
		hp.append(1 if i == Sim.K_F else 0)
	return {"state": st, "active": act, "target": tg, "hp": hp, "spread_left": tg.duplicate()}


func center(i: int) -> Vector2:
	return Layout.key_rect(i).get_center()


@warning_ignore("integer_division")
func _draw() -> void:
	draws += 1
	if snap.is_empty():
		return
	var now := now_ms if now_ms > 0 else Time.get_ticks_msec()
	var states: Array = snap["state"]
	var active: Array = snap["active"]
	var targets: Array = snap["target"]
	var warned := {}
	for i in Layout.COUNT:
		if int(targets[i]) >= 0:
			warned[int(targets[i])] = i
	for i in Layout.COUNT:
		var r := Layout.key_rect(i)
		if Layout.row_of(i) == Layout.DIGIT_ROW:
			var t := float(now - unlock_at) / B.UNLOCK_SLIDE_MS
			if t >= 0.0 and t < 1.0:
				r.position.y -= (1.0 - t) * B.UNLOCK_SLIDE_PX  # 上から入る(上の棒には重ならない幅だけ)
		if not active[i]:
			if not show_locked:
				continue
			_sb["locked"].draw(get_canvas_item(), r)
			_label(i, r, Color(Kit.C_KEY_TEXT, 0.3), 30)
			continue
		var st: int = states[i]
		var hit := now - hit_at[i]
		if st == Sim.NEST and hit >= 0 and hit < B.NEST_HIT_MS:
			r.position.x += 4.0 if (hit / 20) % 2 == 0 else -4.0  # 巣が震える
		var sp := now - spawn_at[i]
		if st != Sim.CLEAN and sp >= 0 and sp < B.SPAWN_MS:
			r = r.grow(-B.CAP_PX * 0.2 * (1.0 - float(sp) / B.SPAWN_MS))  # 湧くと膨らむ
		match st:
			Sim.CLEAN:
				_sb["clean"].draw(get_canvas_item(), r)
				_label(i, r, Kit.C_KEY_TEXT, 34)
			# 虫のキーも刻印は clean と同じ大きさ・位置(押すキーを探す字なので一番読めるように)。種類の印は左上と上の縁に小さく
			Sim.BUG:
				_sb["bug"].draw(get_canvas_item(), r)
				draw_circle(r.position + Vector2(17, 17), 8, Kit.C_BG, true, -1.0, true)
				_label(i, r, Kit.C_BG, 34)
			Sim.NEST:
				_sb["nest"].draw(get_canvas_item(), r)
				var n := int(snap["hp"][i])
				for k in n:
					draw_circle(Vector2(r.get_center().x + (k - (n - 1) / 2.0) * 16, r.position.y + 16), 5, Kit.C_WHITE, true, -1.0, true)
				_label(i, r, Kit.C_WHITE, 34)
			Sim.JUMPER:
				_sb["jumper"].draw(get_canvas_item(), r)
				var c := r.position + Vector2(18, 18)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(9, 0), c + Vector2(0, 10), c + Vector2(-9, 0)]), Kit.C_BG)
				_label(i, r, Kit.C_BG, 34)
		if warned.has(i):
			_warn_target(r, now)
		var m := now - miss_at[i]
		if m >= 0 and m < B.MISS_MS:
			var a := (B.REDUCED_FLASH_ALPHA if reduce_flash else 0.85) * (1.0 - float(m) / B.MISS_MS)
			draw_rect(r, Color(Kit.C_WHITE, a))
			draw_string(Kit.font(800), Vector2(r.position.x, r.get_center().y + 22), S.MISS_MARK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 64,
				Kit.C_TEXT if reduce_flash else Color(Kit.C_BG, 0.9))  # 点滅を弱めると光が薄いので、×は明るい字で
	for t: int in warned.keys():
		_arrow(warned[t], t)


func _label(i: int, r: Rect2, color: Color, size: int) -> void:
	draw_string(Kit.font(700), Vector2(r.position.x, r.get_center().y + size * 0.36), Layout.LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, color)


# 予兆の先: 橙の縁が脈打ち(60 tick = 500 ms で 1 回)、上の縁の真ん中に三角の切り欠き。
func _warn_target(r: Rect2, now: int) -> void:
	var pulse := 0.55 + 0.45 * absf(fmod(now / 250.0, 2.0) - 1.0)
	var c := Color(Kit.C_WARN, pulse)
	draw_rect(r, Color(Kit.C_WARN, B.WARN_FILL_ALPHA * pulse))  # 中も薄く橙にして、どのキーが危ないかを遠目でも分かるように
	draw_rect(r.grow(-1.5), c, false, 3.0, true)
	var top := Vector2(r.get_center().x, r.position.y)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-9, -1), top + Vector2(9, -1), top + Vector2(0, 10)]), c)


# 元から先への矢印(四角の縁から縁まで)。
func _arrow(from: int, to: int) -> void:
	var a := center(from)
	var b := center(to)
	var d := (b - a).normalized()
	var p0 := a + d * 30
	var p1 := b - d * 40
	draw_line(p0, p1, Kit.C_WARN, 4.0, true)
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([p1 + d * 14, p1 + n * 9, p1 - n * 9]), Kit.C_WARN)

# 配置と隣のテスト(仕様書 §9.1・§9.2・AC-3・INV-4)。
extends "res://tests/suite.gd"


static func _sorted(a: Array) -> Array:
	var c := a.duplicate()
	c.sort()
	return c


func test_ac3_neighbors_before_unlock() -> bool:
	var l := Layout.new(false)
	eq(labels(l.neighbors(idx("D"))), _sorted(["S", "F", "E", "R", "X", "C"]), "D の隣")
	eq(labels(l.neighbors(idx("A"))), _sorted(["Q", "W", "S", "Z"]), "A の隣")
	eq(labels(l.neighbors(idx("P"))), _sorted(["O", "L", ";"]), "P の隣")
	eq(labels(l.neighbors(idx("/"))), _sorted([".", ";"]), "/ の隣")
	return true


func test_ac3_neighbors_after_unlock() -> bool:
	var l := Layout.new(true)
	eq(labels(l.neighbors(idx("E"))), _sorted(["W", "R", "S", "D", "3", "4"]), "E の隣")
	eq(labels(l.neighbors(idx("Q"))), _sorted(["W", "A", "1", "2"]), "Q の隣")
	return true


func test_neighbors_symmetric_and_at_most_six() -> bool:
	var l := Layout.new(true)
	for i in Layout.COUNT:
		ok(l.neighbors(i).size() <= 6, "%s の隣は 6 以下" % Layout.LABELS[i])
		for j: int in l.neighbors(i):
			ok(i in l.neighbors(j), "%s と %s の隣は対称" % [Layout.LABELS[i], Layout.LABELS[j]])
	return true


func test_inactive_digits_have_no_neighbors() -> bool:
	var l := Layout.new(false)
	eq(l.active_count(), 30, "初めは 30 キー")
	for i in 10:
		eq(l.neighbors(i).size(), 0, "解放前の数字は隣を持たない")
	for i in range(10, 40):
		for j: int in l.neighbors(i) + l.second_ring(i):
			ok(j >= 10, "隣と隣の隣は active だけ")
	l.rebuild(true)
	eq(l.active_count(), 40, "解放後は 40 キー")
	return true


func test_second_ring_is_two_steps_away() -> bool:
	var l := Layout.new(true)
	for i in Layout.COUNT:
		for k: int in l.second_ring(i):
			ok(k != i and not (k in l.neighbors(i)), "隣の隣は自分でも隣でもない")
			ok(l.neighbors(i).any(func(j: int) -> bool: return k in l.neighbors(j)), "隣の隣は隣の隣")
	ok(idx("G") in l.second_ring(idx("D")), "D の隣の隣に G")
	return true


func test_key_rects_inside_board() -> bool:
	eq(Layout.key_rect(0), Rect2(104, 216, 88, 88), "1 の四角(x0 1.0)")
	eq(Layout.key_rect(idx("Q")), Rect2(152, 312, 88, 88), "Q の四角(x0 1.5)")
	eq(Layout.key_rect(idx("A")), Rect2(176, 408, 88, 88), "A の四角(x0 1.75)")
	eq(Layout.key_rect(idx("Z")), Rect2(224, 504, 88, 88), "Z の四角(x0 2.25)")
	for i in Layout.COUNT:
		var r := Layout.key_rect(i)
		ok(r.position.x >= 104 and r.end.x <= 1184 and r.position.y >= 216 and r.end.y <= 592, "%s は盤の中" % Layout.LABELS[i])
	return true


func test_physical_keys_unique() -> bool:
	eq(Layout.PHYSICAL.size(), 40, "物理キー 40")
	eq(Layout.LABELS.size(), 40, "刻印 40")
	for i in Layout.COUNT:
		eq(Layout.PHYSICAL.find(Layout.PHYSICAL[i]), i, "物理キーが重ならない")
	eq(Layout.index_of_physical(KEY_F), 23, "F は 23")
	eq(Layout.index_of_physical(KEY_SEMICOLON), 29, "; は 29")
	eq(Layout.index_of_physical(KEY_SLASH), 39, "/ は 39")
	eq(Layout.index_of_physical(KEY_SPACE), -1, "Space は盤に無い")
	return true

# 40 キーの配置の表(仕様書 §9.2): 段・列・刻印・物理キー(physical_keycode)・画面の位置と、隣の表。
# 位置は 1/4 キー幅の整数で持ち、隣は中心の距離の 2 乗で決める(平方根を使わない)。sim・予兆・テスト・ui がこの 1 か所を使う(INV-4)。
# KeyBlink もこの表を写す(段 1〜3 だけ使うなら ROWS の 1〜3 を引く)。
extends RefCounted

const B := preload("res://core/balance.gd")

const COUNT := 40
const PER_ROW := 10
# 段ごとの始まり x0(1/4 キー幅)。数字 1.0・上 1.5・中 1.75・下 2.25
const ROW_X0_Q := [4, 6, 7, 9]
const ROWS := [[0, 9], [10, 19], [20, 29], [30, 39]]  # 段ごとの盤の番号(始め・終わり)
const DIGIT_ROW := 0
const LABELS := [
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
	"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
	"A", "S", "D", "F", "G", "H", "J", "K", "L", ";",
	"Z", "X", "C", "V", "B", "N", "M", ",", ".", "/",
]
# 盤の番号 → physical_keycode(US 配列の上の位置。共通 §3 の 2)
const PHYSICAL := [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
	KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P,
	KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON,
	KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M, KEY_COMMA, KEY_PERIOD, KEY_SLASH,
]

var active: Array[bool] = []
var _near: Array = []  # 盤の番号 → 隣の番号の配列(active だけ)
var _ring: Array = []  # 盤の番号 → 隣の隣の番号の配列(active だけ)


# digits: 数字の段を active にするか。
func _init(digits: bool = false) -> void:
	rebuild(digits)


@warning_ignore("integer_division")
static func row_of(i: int) -> int:
	return i / PER_ROW


static func col_of(i: int) -> int:
	return i % PER_ROW


# 中心(1/4 キー幅)。キー i の中心 = (x0 + 列 + 0.5, 段 + 0.5)
static func center_q(i: int) -> Vector2i:
	return Vector2i(int(ROW_X0_Q[row_of(i)]) + 4 * col_of(i) + 2, 4 * row_of(i) + 2)


static func is_near(a: int, b: int) -> bool:
	var d: Vector2i = center_q(a) - center_q(b)
	# (d / 4)^2 <= 1.69  ⇔  d^2 * 100 <= 169 * 16
	return a != b and (d.x * d.x + d.y * d.y) * 100 <= B.NEIGHBOR_D2_X100 * 16


# キー i の四角(画面の px。§9.1)。左上 = (8 + (x0 + 列) × 96, 216 + 段 × 96)、大きさ 88×88
@warning_ignore("integer_division")
static func key_rect(i: int) -> Rect2:
	var x: int = B.BOARD_LEFT + (ROW_X0_Q[row_of(i)] + 4 * col_of(i)) * B.KEY_PX / 4
	var y: int = B.BOARD_TOP + row_of(i) * B.KEY_PX
	return Rect2(x, y, B.CAP_PX, B.CAP_PX)


static func index_of_physical(code: int) -> int:
	return PHYSICAL.find(code)


func rebuild(digits: bool) -> void:
	active.clear()
	for i in COUNT:
		active.append(digits or row_of(i) != DIGIT_ROW)
	_near.clear()
	for i in COUNT:
		var list: Array[int] = []
		if active[i]:
			for j in COUNT:
				if active[j] and is_near(i, j):
					list.append(j)
		_near.append(list)
	_ring.clear()
	for i in COUNT:
		var list: Array[int] = []
		for j: int in _near[i]:
			for k: int in _near[j]:
				if k != i and not (k in _near[i]) and not (k in list):
					list.append(k)
		list.sort()
		_ring.append(list)


func neighbors(i: int) -> Array[int]:
	return _near[i]


func second_ring(i: int) -> Array[int]:
	return _ring[i]


func active_count() -> int:
	return active.count(true)

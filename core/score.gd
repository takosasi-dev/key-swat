# 点数と、点・時間の文字の形(仕様書 §9.6・§9.9)。整数だけで計算する。
extends RefCounted

const B := preload("res://core/balance.gd")


# 潰した時の点。chain_before はこの押下の前までのつなぎ。巣は × 3。
static func points(chain_before: int, nest: bool) -> int:
	var p := B.POINT_UNIT * mult10(chain_before)
	return p * B.NEST_POINT_MUL if nest else p


# 倍率 × 10 の整数(つなぎ 14 → 24 = x2.4)。
static func mult10(chain_before: int) -> int:
	return 10 + mini(chain_before, B.CHAIN_CAP)


# 倍率の文字。24 → "x2.4"
@warning_ignore("integer_division")
static func mult_text(m10: int) -> String:
	return "x%d.%d" % [m10 / 10, m10 % 10]


# 守った時間「分:秒」(秒は 2 桁、小数は切り捨て)。19320 tick → "2:41"
@warning_ignore("integer_division")
static func clock_text(ticks: int) -> String:
	var sec := maxi(ticks, 0) / B.TICK_HZ
	return "%d:%02d" % [sec / 60, sec % 60]


# 3 桁ごとにコンマ。12400 → "12,400"
static func comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

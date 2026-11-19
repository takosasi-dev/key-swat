# 日付・共有する文字・点の文字のテスト(AC-15・AC-17・§9.9・共通 §3 の 13)。
extends "res://tests/suite.gd"

const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Score := preload("res://core/score.gd")


func test_ac15_day_index() -> bool:
	eq(Day.day_index(2026, 1, 1), 0, "2026-01-01 → 0")
	eq(Day.day_index(2026, 11, 19), 322, "2026-11-19 → 322")
	eq(Day.day_index(2027, 1, 1), 365, "2027-01-01 → 365")
	eq(Day.day_index(2025, 12, 31), 0, "2025-12-31 → 0")
	return true


func test_day_seed() -> bool:
	eq(Day.day_seed(322), (323 * 2654435761 + 0x5157) & 0xFFFFFFFF, "共通 §3 の 13 の式(SALT 0x5157)")
	ok(Day.day_seed(0) != Day.day_seed(1), "日で違う")
	return true


func test_ac17_share_text_exact() -> bool:
	var r := {"ticks": 19320, "score": 12400, "squashed": 96, "max_chain": 38, "misses": 3, "reason": 0}
	eq(Share.make("2026-11-19", 0, true, r),
		"KeySwat 2026-11-19(今日の盤・1回目)\n守った 2:41 / 12,400点 / 最大つなぎ 38 / 外れ 3\nhttps://takosasi-dev.github.io/key-swat/", "§9.9 の形")
	ok(Share.make("2026-11-19", 0, false, r).begins_with("KeySwat 2026-11-19(今日の盤)\n"), "2 回目以降は「今日の盤」")
	ok(Share.make("2026-11-19", 1, false, r).begins_with("KeySwat 2026-11-19(練習)\n"), "練習")
	return true


func test_clock_and_comma() -> bool:
	eq(Score.clock_text(0), "0:00", "0 tick")
	eq(Score.clock_text(119), "0:00", "小数は切り捨て")
	eq(Score.clock_text(120 * 61), "1:01", "秒は 2 桁")
	eq(Score.clock_text(120 * 3600), "60:00", "分は桁を足す")
	eq(Score.comma(0), "0", "0")
	eq(Score.comma(999), "999", "3 桁")
	eq(Score.comma(1234567), "1,234,567", "3 桁ごと")
	return true

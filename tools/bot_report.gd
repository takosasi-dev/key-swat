# bot 3 種を種 1〜10 で回し、守った時間(時計の tick)・点・潰した数・外れ・終わった理由を印字する(§8.2・AC-11・R-3 を見る道具)。
# 実行: python tools/gd.py run res://tools/bot_report.gd [上限の tick(既定 36000 = 5 分)]
extends SceneTree

const Sim := preload("res://core/sim.gd")
const Bots := preload("res://core/bots.gd")
const Score := preload("res://core/score.gd")
const B := preload("res://core/balance.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var cap := int(args[0]) if not args.is_empty() else B.BOT_TICK_CAP
	print("上限 %d tick(%s)。守った時間は時計の tick(F を潰してから)" % [cap, Score.clock_text(cap)])
	var r3 := 0
	for s in range(1, 11):
		var row := "種 %2d:" % s
		var ticks := []
		for k in 3:
			var r: Dictionary = Bots.play(Sim.new(s, Sim.MODE_PRACTICE), k, cap)
			ticks.append(int(r["ticks"]))
			var why: String = "上限" if r["capped"] else ["感染", "耐久"][int(r["reason"])]
			row += "  %s %6d tick(%s) 点 %7d 潰 %4d 外 %3d %s" % [Bots.NAMES[k], r["ticks"], Score.clock_text(r["ticks"]), r["score"], r["squashed"], r["misses"], why]
		if ticks[1] >= ticks[0]:
			r3 += 1
		print(row)
	print("R-3(連打 bot が正しい bot と同じか長く生き残る種): %d 個" % r3)
	quit()

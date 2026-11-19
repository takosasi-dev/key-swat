# 保存のテスト(仕様書 §9.11・AC-16・E-11・E-14・NFR-9)。テストでは user:// の別のファイルを使う。
extends "res://tests/suite.gd"

const Store := preload("res://save/save_store.gd")
const P := "user://test_save.json"


func _fresh(text: Variant = null) -> Store:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
	if text != null:
		var f := FileAccess.open(P, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	return Store.new(P)


func test_ac16_empty_broken_version() -> bool:
	var st := _fresh()
	eq(st.data, Store.defaults(), "空")
	ok(not st.load_failed, "空は失敗ではない")
	st = _fresh("{not json")
	eq(st.data, Store.defaults(), "壊れた JSON")
	ok(st.load_failed, "壊れた時は知らせる(E-11)")
	st = _fresh('{"version": 2, "practice_best": {"score": 5, "ticks": 5}}')
	eq(st.data, Store.defaults(), "version が 2")
	ok(st.load_failed, "知らない version も知らせる")
	eq(Store.default_settings(), {"volume": 75, "shake": true, "reduce_flash": false}, "既定値: 音量 75・揺れ 入・点滅を弱める 切")
	return true


func test_practice_best() -> bool:
	var st := _fresh()
	var r1 := st.record(1, 322, {"score": 18200, "ticks": 21300})
	ok(r1["new_best"] and r1["prev_best"] == null, "初めての最高")
	var r2 := st.record(1, 322, {"score": 7000, "ticks": 99999})
	ok(not r2["new_best"], "低い点は最高にしない(時間が長くても)")
	eq(Store.new(P).practice_best(), {"score": 18200, "ticks": 21300}, "読み直しても残る")
	return true


func test_daily_first_and_best() -> bool:
	var st := _fresh()
	var a := st.record(0, 322, {"score": 12400, "ticks": 19320})
	ok(a["first_today"], "1 回目")
	st.record(0, 322, {"score": 15100, "ticks": 20500})
	var d := Store.new(P).daily(322)
	eq(d["first"], {"score": 12400, "ticks": 19320}, "1 回目は残る")
	eq(d["best"], {"score": 15100, "ticks": 20500}, "最高")
	var b := st.record(0, 323, {"score": 5000, "ticks": 99})
	ok(b["first_today"], "日付が変われば作り直す")
	eq(Store.new(P).daily(322)["first"], null, "前の日の記録は消える")
	return true


func test_e14_old_day_does_not_overwrite() -> bool:
	var st := _fresh()
	st.record(0, 323, {"score": 5000, "ticks": 99})
	var r := st.record(0, 322, {"score": 9999, "ticks": 1})
	ok(not r["first_today"] and not r["new_best"], "古い日の回は記録しない")
	eq(Store.new(P).daily(323)["best"], {"score": 5000, "ticks": 99}, "新しい日のまま")
	return true


func test_settings_persist_and_bad_values() -> bool:
	var st := _fresh()
	st.set_setting("volume", 25)
	st.set_setting("shake", false)
	eq(Store.new(P).settings(), {"volume": 25, "shake": false, "reduce_flash": false}, "設定が残る")
	st = _fresh('{"version": 1, "settings": {"volume": 33, "shake": "yes"}, "practice_best": {"score": "x"}}')
	eq(st.settings(), Store.default_settings(), "おかしな値は既定値")
	eq(st.practice_best(), null, "おかしな記録は無し")
	ok(not st.load_failed, "形は読めた")
	return true


func test_save_shape_matches_spec() -> bool:
	var st := _fresh()
	st.record(0, 322, {"score": 12400, "ticks": 19320})
	var j := JSON.new()
	eq(j.parse(FileAccess.get_file_as_string(P)), OK, "JSON で書く")
	var keys: Array = j.data.keys()
	keys.sort()
	eq(keys, ["daily", "practice_best", "settings", "version"], "§9.11 の形")
	ok(FileAccess.get_file_as_string(P).length() <= 2048, "2 KB 以下")
	eq(Store.WEB_KEY, "key-swat/save", "localStorage のキー名(INV-8)")
	return true

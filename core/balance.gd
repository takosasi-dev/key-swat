# 調整値(仕様書 §9.7・INV-7)。時間は tick(1/120 秒)の整数で持つ。
# 演出の時間(ms)・設定の段・日替わりの種の値もここに置く。ほかのファイルに数値の調整値を書かない。
extends RefCounted

const TICK_HZ := 120
const MAX_STEPS_PER_FRAME := 8

# 盤(§9.1・§9.2)
const KEY_PX := 96
const CAP_PX := 88
const BOARD_LEFT := 8
const BOARD_TOP := 216
const NEIGHBOR_D2_X100 := 169  # 隣とみなす中心の距離の 2 乗(1.69)を 100 倍した整数

# 広がり・湧き(§9.4・§9.5)
const WARN_TICKS := 60
const SPREAD_START := 600
const SPREAD_END := 144
const SPAWN_START := 360
const SPAWN_END := 96
const CURVE_FROM := 2400
const CURVE_SPAN := 24000
const NEST_HP := 3
const NEST_RATE_NUM := 7
const NEST_RATE_DEN := 10
const SPAWN_FIRST := 1200  # 湧く予定の始まり(時計 10 秒)
const SPAWN_UNTIL := 432000  # 湧く予定を作る長さ(60 分)
const SPAWN_NORMAL_ONLY := 7200  # これより前の湧きは ふつう だけ
const SPAWN_NEST_PCT := 8
const SPAWN_JUMPER_PCT := 20
const SPREAD_RNG_XOR := 0x9E3779B9

# 教える順(§9.5。INV-6: 中身と時刻を変えない)
const TEACH_DK_TICKS := 480
const TEACH_NEST_TICKS := 4800
const UNLOCK_TICKS := 9600
const TEACH_JUMPER_TICKS := 14400

# 耐久・負け(§9.4・FR-12・FR-13)
const INTEGRITY_MAX := 100
const MISS_DAMAGE := 8
const SQUASH_HEAL := 2
const LOSE_PERCENT := 40

# 点(§9.6)
const CHAIN_CAP := 30
const POINT_UNIT := 10
const NEST_POINT_MUL := 3

# 日替わりの種(共通 §3 の 13)
const DAY_SEED_MUL := 2654435761
const DAY_SALT := 0x5157
const EPOCH_YEAR := 2026

# テスト用の bot(§9.10)
const BOT_GOOD_EVERY := 6
const BOT_MASH_EVERY := 12
const BOT_MASH_KEYS := 4
const BOT_RNG_XOR := 0x6B657973
const BOT_TICK_CAP := 36000  # bot に遊ばせる時計の上限(5 分)。正しい bot は負けないので、ここで打ち切る

# 設定(共通 §3 の 17)
const VOLUMES := [0, 25, 50, 75, 100]
const DEFAULT_VOLUME := 75

# 演出(§9.8・画面設計書 §8)。ms と px
const SHARD_MS := 250
const SHARDS := 6
const SHARDS_MAX := 240
const FLOAT_MS := 600
const FLOATS_MAX := 20
const FLOAT_RISE_PX := 70
const BIG_SCALE := 1.6
const BIG_CHAIN_EVERY := 10
const SHAKE_BIG_PX := 6.0
const SHAKE_BIG_MS := 120
const SHAKE_MISS_PX := 3.0
const SHAKE_MISS_MS := 80
const MISS_MS := 120
const NEST_HIT_MS := 80
const RIPPLE_MS := 200
const SPAWN_MS := 150
const UNLOCK_SLIDE_MS := 300
const UNLOCK_NOTE_MS := 1500
const OVER_MS := 400
const COUNT_MS := 600
const RETRY_LOCK_MS := 300
const IME_NOTE_MS := 3000
const REDUCED_FLASH_ALPHA := 0.2
const PITCH_STEPS_MAX := 12  # 潰す音を半音ずつ上げる上限
const INTEGRITY_LOW := 30  # 耐久の棒を赤くする線
const INFECT_WARN_PCT := 35  # 感染の棒を橙にする線

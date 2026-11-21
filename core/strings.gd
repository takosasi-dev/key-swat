# 画面に出す文言(INV-7・画面設計書 §6)。文言はここだけに置く。
# 文言を足したら tools/subset_font.py を回し直す(同梱の字体はここの文字に絞ってある)。
extends RefCounted

const NAME := "KeySwat"
const VERSION := "v0.3.0"
const URL := "https://takosasi-dev.github.io/key-swat/"

# S0(共通 §6)
const S0_START := "クリックかキーで始める"
const S0_KEYBOARD := "キーボードで遊ぶゲーム"
const TOUCH := "このゲームはキーボードで遊ぶ。PC で開いてほしい"
const IME := "日本語入力を切って(半角英数で)遊んでほしい"

# S1 タイトル
const TAGLINE := "広がる前に、そのキーを押して潰す"
const B_DAILY := "今日の盤"
const B_PRACTICE := "練習(毎回ちがう盤)"
const B_SETTINGS := "設定"
const REC_FIRST := "1回目 %s点"
const REC_TODAY_BEST := "今日の最高 %s点"
const REC_BEST := "最高 %s点"
const REC_NONE := "まだ遊んでいない"
const LOAD_FAILED := "保存を読めなかったので、記録を初めからにした"

# S2 プレイ
const ESC := "Esc"
const HINT := "赤いキーを押す"
# 上の帯は名前と数を分けて描く(v0.3.0。数は Chakra Petch で同じ幅の升に置く)
const BAR_TIME := "守った"
const BAR_POINTS := "点"
const BAR_CHAIN := "つなぎ"
const BAR_INTEGRITY := "耐久"
const BAR_INFECT := "感染"
const BAR_INFECT_COUNT := "%d / %d(%d で終わり)"
const UNLOCK := "数字の段が加わった"
# 新しい物が初めて出た時の 1 行(磨きで足した。画面設計書 §6)
const TIP_WARN := "橙の先へ広がる。赤い元を押せば止まる"
const TIP_NEST := "巣は 3 回押すと潰れる"
const TIP_JUMPER := "跳ぶ虫は 1 つ飛ばした先へ広がる"
const FLOAT := "+%s %s"

# S3 結果
const REASONS := ["感染が広がりきった", "耐久が尽きた"]
const RES_POINTS := "%s点"
const RES_NEW_BEST := "最高 +%s(新しい記録)"
const RES_TO_BEST := "最高まで −%s"
# 4 つの数は名前と数を分けて升に置く(v0.3.0)
const RES_TIME := "守った"
const RES_SQUASHED := "潰した数"
const RES_MAX_CHAIN := "最大つなぎ"
const RES_MISSES := "外れ"
const STAMP_NEW := "新しい記録"
const B_RETRY := "もう1回"
const B_COPY := "コピー"
const B_TITLE := "タイトルへ"
const COPIED := "コピーを試した。貼れない時は枠から写す"
const SAVE_FAILED := "このブラウザでは記録を残せない"

# 共有する文字(§9.9)
const SHARE_HEAD := "%s %s(%s)"
const SHARE_BODY := "守った %s / %s点 / 最大つなぎ %d / 外れ %d"
const MODE_DAILY_FIRST := "今日の盤・1回目"
const MODE_LABEL := ["今日の盤", "練習"]

# S4 設定・S5 一時停止(共通 §6)
const SETTINGS := "設定"
const SET_VOLUME := "音量"
const SET_SHAKE := "画面の揺れ"
const SET_FLASH := "点滅を弱める"
const ON := "入"
const OFF := "切"
const B_BACK := "戻る"
const PAUSE := "一時停止"
const B_RESUME := "続ける"
const B_RESTART := "やり直す"

# 画面の下のキーの案内(v0.3.0。キーの形は絵で描き、その横に動きを書く)
const HINT_PICK := "選ぶ"
const HINT_OK := "決める"
const HINT_CHANGE := "変える"

# キーの確かめ(共通 §3 の 22)
const KEYS_TITLE := "キーの確かめ(押したキーを下に出す。Esc 2 回でタイトルへ)"

"""効果音 8 個(仕様書 §9.8)を合成して assets/sfx/<名前>.wav に書く。標準ライブラリだけ・乱数は使わない(何度回しても同じバイト列)。
16bit PCM・モノラル・22050 Hz。合計 300 KB 以下(非機能 NFR-7)。

    python tools/gen_sfx.py
"""

import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"
RATE = 22050
TAU = 2 * math.pi


def tone(buf, at, dur, f0, f1=None, gain=1.0, decay=0.0, square=False):
    """音 1 本を buf に足す。f0→f1 へ直線で動き、exp(-decay*t) で消える。square なら矩形に近い音(奇数倍音 3 本)。"""
    f1 = f1 or f0
    start = int(at * RATE)
    n = int(dur * RATE)
    while len(buf) < start + n:
        buf.append(0.0)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        e = gain * math.exp(-decay * t) * min(1.0, (n - i) / (0.004 * RATE), i / (0.001 * RATE))
        s = math.sin(phase)
        if square:
            s += math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5
        buf[start + i] += e * s
        phase += TAU * (f0 + (f1 - f0) * i / n) / RATE


def write(name, buf, peak):
    top = max(abs(x) for x in buf) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / top * peak * 32767)) for x in buf))


def main():
    b = []
    tone(b, 0, 0.07, 1320, 1760, decay=40)
    tone(b, 0, 0.02, 3000, 2000, gain=0.4, decay=150)  # 潰す: 短い高い音(つなぎで pitch_scale を上げる)
    write("squash", b, 0.5)
    b = []
    tone(b, 0, 0.09, 260, 200, square=True, decay=25)  # 巣を叩く: 鈍い音
    write("nest_hit", b, 0.5)
    b = []
    tone(b, 0, 0.14, 140, square=True, decay=10)  # 外れ: 低いブザー
    write("miss", b, 0.45)
    b = []
    tone(b, 0, 0.025, 2600, 2200, decay=90)  # 予兆: 小さい「チッ」
    write("warn", b, 0.22)
    b = []
    for k in range(4):
        tone(b, k * 0.04, 0.05, 420 - k * 30, 360 - k * 30, square=True, decay=30)  # 広がる: 這う音
    write("spread", b, 0.3)
    b = []
    for k, f in enumerate([660, 880, 1320]):
        tone(b, k * 0.08, 0.2, f, decay=9)  # 数字の段が加わった: 明るい音
    write("unlock", b, 0.5)
    b = []
    for k, f in enumerate([660, 520, 392, 262]):
        tone(b, k * 0.13, 0.32, f, square=True, decay=6)  # 終わり
    write("over", b, 0.55)
    b = []
    tone(b, 0, 0.04, 1200, 1400, decay=30)  # メニューの選択
    write("select", b, 0.35)
    total = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"{len(list(OUT.glob('*.wav')))} 個、合計 {total:,} バイト")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Synthesize the Flipperbrott sound effects and the music loop into assets/sfx/*.wav (numpy only)."""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
rng = np.random.default_rng(7)


def save(name, x, vol=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = np.clip(x / (np.max(np.abs(x)) or 1.0) * vol, -1, 1)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def tl(d):
    return np.arange(int(SR * d)) / SR


def env(n, attack=0.002, decay=0.1):
    t = np.arange(n) / SR
    return np.clip(t / attack, 0, 1) * np.exp(-t / decay)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, k):
    return np.convolve(x, np.ones(k) / k, mode="same")


def sweep(f0, f1, d, wave_="sin"):
    f = np.geomspace(f0, f1, int(SR * d))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_ == "sq":
        return np.sign(np.sin(ph)) * 0.6
    if wave_ == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)


def note(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def tone(freq, d, kind="sq", decay=0.2, attack=0.003):
    t = tl(d)
    ph = 2 * np.pi * freq * t
    if kind == "sq":
        x = np.sign(np.sin(ph)) * 0.5 + 0.5 * np.sin(ph)
    elif kind == "saw":
        x = sum(((freq * k * t) % 1.0) * 2 - 1 for k in (1.0, 1.007)) * 0.5
    elif kind == "tri":
        x = 2 / np.pi * np.arcsin(np.sin(ph))
    else:
        x = np.sin(ph)
    return x * env(len(t), attack, decay)


def seq(notes, step, kind="sq", decay=0.08):
    """Play a list of midi notes one after another."""
    out = np.zeros(int(SR * step * len(notes)) + int(SR * 0.3))
    for i, m in enumerate(notes):
        if m is None:
            continue
        x = tone(note(m), step + 0.25, kind, decay)
        k = int(i * step * SR)
        out[k:k + len(x)] += x
    return out


os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- effects
save("flip", lowpass(noise(0.06), 3) * env(int(SR * 0.06), 0.001, 0.015) + 0.5 * sweep(300, 120, 0.06) * env(int(SR * 0.06), 0.001, 0.03), 0.5)
bump = tone(520, 0.25, "sq", 0.08) + tone(780, 0.25, "sin", 0.1) + lowpass(noise(0.25), 4) * env(int(SR * 0.25), 0.001, 0.02)
save("bumper", bump, 0.6)
save("sling", sweep(900, 300, 0.09, "sq") * env(int(SR * 0.09), 0.001, 0.04), 0.45)
save("brick", tone(988, 0.12, "sq", 0.04) + 0.5 * tone(1976, 0.12, "sin", 0.03), 0.4)
metal = sum(np.sin(2 * np.pi * f * tl(0.35)) * np.exp(-tl(0.35) * k) for f, k in ((1400, 10), (2210, 14), (3170, 20)))
save("metal", metal, 0.45)
save("gold", metal * 0.6 + tone(2600, 0.35, "sin", 0.1), 0.4)
save("paddle", tone(440, 0.1, "sq", 0.04) + 0.5 * sweep(300, 600, 0.1, "tri") * env(int(SR * 0.1), 0.001, 0.05), 0.45)
save("wall", lowpass(noise(0.03), 6) * env(int(SR * 0.03), 0.001, 0.008), 0.25)
save("power", seq([72, 79, 84, 91], 0.05, "tri", 0.1), 0.55)
save("laser", sweep(2400, 500, 0.12, "sq") * env(int(SR * 0.12), 0.001, 0.05), 0.3)
launch = lowpass(noise(0.4), 8) * env(int(SR * 0.4), 0.01, 0.15) + sweep(120, 700, 0.4, "tri") * env(int(SR * 0.4), 0.01, 0.25)
save("launch", launch, 0.6)
save("drain", seq([67, 62, 58, 55], 0.12, "saw", 0.2), 0.55)
save("save", seq([72, 76, 72, 76], 0.07, "sq", 0.08), 0.5)
save("rollover", tone(1320, 0.08, "tri", 0.04), 0.35)
save("lights", seq([76, 79, 83, 88, 91], 0.06, "sq", 0.12), 0.55)
save("clear", seq([60, 64, 67, 72, 67, 72, 76, 79, 84], 0.08, "sq", 0.2), 0.65)
save("multi", seq([60, 67, 72, 79, 84], 0.04, "saw", 0.12), 0.55)
save("extra", seq([72, 76, 79, 84, 88, 91, 96], 0.06, "tri", 0.18), 0.6)
save("over", seq([67, 63, 60, 55, None, 48], 0.16, "saw", 0.3), 0.6)
save("start", seq([60, 64, 67, 72, 76, 79], 0.05, "sq", 0.1), 0.55)

# ---------------------------------------------------------------- music: an original funky arcade loop
BPM = 118
beat = 60 / BPM
s16 = beat / 4
bars = 8
total = int(SR * beat * 4 * bars)
mix = np.zeros(total + SR)
prog = [(50, [0, 3, 7, 10]), (55, [0, 4, 7, 10]), (50, [0, 3, 7, 10]), (57, [0, 4, 7, 10]),
        (50, [0, 3, 7, 10]), (55, [0, 4, 7, 10]), (53, [0, 4, 7, 11]), (57, [0, 4, 7, 10])]
bass_pat = [0, None, 12, 0, None, 0, 10, None, 0, None, 12, None, 7, None, 10, 12]
for b, (root, iv) in enumerate(prog):
    base = b * beat * 4
    for i, o in enumerate(bass_pat):
        if o is None:
            continue
        x = tone(note(root - 12 + o), s16 * 1.4, "sq", 0.06) * 0.45
        x = lowpass(x, 6)
        k = int((base + i * s16) * SR)
        mix[k:k + len(x)] += x
    # offbeat chord stabs
    for i in (2, 6, 10, 14):
        st = sum(tone(note(root + 12 + v), s16 * 1.2, "saw", 0.05) for v in iv) * 0.06
        k = int((base + i * s16) * SR)
        mix[k:k + len(st)] += lowpass(st, 4)
    for i in range(4):
        kk = int((base + i * beat) * SR)
        kick = sweep(160, 45, 0.15) * env(int(SR * 0.15), 0.001, 0.07) * 0.7
        mix[kk:kk + len(kick)] += kick
        for j in range(4):
            hh = noise(0.03) * env(int(SR * 0.03), 0.001, 0.008) * (0.12 if j % 2 else 0.06)
            kh = int((base + i * beat + j * s16) * SR)
            mix[kh:kh + len(hh)] += hh
        if i % 2 == 1:
            sn = lowpass(noise(0.14), 2) * env(int(SR * 0.14), 0.001, 0.06) * 0.32
            mix[kk:kk + len(sn)] += sn
lead = [(74, 0.5), (77, 0.5), (79, 1), (77, 0.5), (74, 0.5), (72, 1), (74, 2), (None, 2),
        (81, 0.5), (79, 0.5), (77, 1), (79, 0.5), (77, 0.5), (74, 1), (72, 1), (74, 3), (None, 1),
        (74, 0.5), (77, 0.5), (79, 1), (81, 1), (84, 1), (81, 0.5), (79, 0.5), (77, 2),
        (79, 1), (77, 1), (76, 1), (73, 1), (74, 4)]
pos = beat * 4 * 2
for m, d in lead:
    if m is not None and pos < beat * 4 * bars:
        x = tone(note(m), beat * d, "sq", beat * d * 0.6, 0.005) * 0.16
        x *= 1 + 0.1 * np.sin(2 * np.pi * 6 * tl(beat * d))
        k = int(pos * SR)
        mix[k:k + len(x)] += lowpass(x, 3)
    pos += beat * d
tail = mix[total:]
mix = mix[:total]
mix[: len(tail)] += tail
save("music", mix, 0.6)
print("ok")

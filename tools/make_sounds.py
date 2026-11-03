"""Synthesize all game sounds (no third-party audio, no licensing issues)."""
import sys, wave
import numpy as np

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.1):
    e = np.ones(n)
    na, nr = int(SR * a), int(SR * r)
    if na: e[:na] = np.linspace(0, 1, na)
    if nr: e[-nr:] *= np.linspace(1, 0, nr)
    return e


def lowpass(x, k=8):
    return np.convolve(x, np.ones(k) / k, mode="same")


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=float)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def tone(f, d, shape="sine"):
    x = t(d)
    if shape == "sine":
        return np.sin(2 * np.pi * f * x)
    if shape == "tri":
        return 2 * np.abs(2 * ((f * x) % 1) - 1) - 1
    if shape == "square":
        return np.sign(np.sin(2 * np.pi * f * x)) * 0.6


# tap: tiny glassy tick
x = tone(2400, 0.05) * np.exp(-t(0.05) * 90) + rng.normal(0, 0.15, len(t(0.05))) * np.exp(-t(0.05) * 200)
save("tap", x, 0.45)

# message: radio squelch + two-tone chirp
sq = lowpass(rng.normal(0, 1, len(t(0.08))), 3) * env(len(t(0.08)), 0.002, 0.03) * 0.5
ch = np.concatenate([tone(1320, 0.07) * env(len(t(0.07)), 0.003, 0.02), tone(1760, 0.09) * env(len(t(0.09)), 0.003, 0.05)])
save("message", np.concatenate([sq, np.zeros(int(SR * 0.02)), ch]), 0.55)

# alert: amber double beep
b = tone(880, 0.12, "tri") * env(len(t(0.12)), 0.004, 0.03)
save("alert", np.concatenate([b, np.zeros(int(SR * 0.07)), b, np.zeros(int(SR * 0.1))]), 0.6)

# alarm: klaxon sweep, loopable 1.2 s
x = t(1.2)
f = 520 + 260 * (np.sin(2 * np.pi * x / 1.2) * 0.5 + 0.5)
ph = 2 * np.pi * np.cumsum(f) / SR
save("alarm", (np.sign(np.sin(ph)) * 0.5 + np.sin(ph * 2) * 0.3) * 0.9, 0.5)

# success: rising arpeggio with soft tail
notes = [523.25, 659.25, 783.99, 1046.5]
parts = []
for i, n in enumerate(notes):
    d = 0.16 if i < 3 else 0.9
    parts.append((tone(n, d) + 0.3 * tone(n * 2, d)) * env(len(t(d)), 0.005, d * 0.8))
save("success", np.concatenate(parts), 0.6)

# fail: low descending
x = t(1.1)
f = 330 * np.exp(-x * 0.9)
ph = 2 * np.pi * np.cumsum(f) / SR
save("fail", (np.sin(ph) + 0.4 * np.sin(ph * 1.5)) * env(len(x), 0.01, 0.5), 0.55)

# star: sparkle
x = t(0.5)
y = sum(np.sin(2 * np.pi * fr * x) * np.exp(-x * (8 + k * 3)) for k, fr in enumerate([1568, 2093, 2637, 3136]))
save("star", y, 0.45)

# storm: rumble + crackle, 2.5 s
x = t(2.5)
rumble = lowpass(rng.normal(0, 1, len(x)), 120) * 6
crackle = (rng.random(len(x)) < 0.004) * rng.normal(0, 1, len(x))
save("storm", (rumble + crackle * 0.8) * env(len(x), 0.3, 1.2), 0.7)

# hum: seamless 4 s base ambience loop
x = t(4.0)
hum = 0.35 * np.sin(2 * np.pi * 60 * x) + 0.18 * np.sin(2 * np.pi * 120 * x) + 0.08 * np.sin(2 * np.pi * 180 * x)
air = lowpass(rng.normal(0, 1, len(x)), 40) * 1.8
loop = hum + air
fadeN = int(SR * 0.3)
loop[:fadeN] = loop[:fadeN] * np.linspace(0, 1, fadeN) + loop[-fadeN:] * np.linspace(1, 0, fadeN)
save("hum", loop[: len(x) - fadeN], 0.22)

# music: slow ambient pad, 16 s loop (Am - F - C - G)
x = t(4.0)
chords = [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
pad = []
for ch in chords:
    y = sum(np.sin(2 * np.pi * f * x) * 0.6 + np.sin(2 * np.pi * f * 2.003 * x) * 0.15 for f in ch)
    y += np.sin(2 * np.pi * ch[0] / 2 * x) * 0.5
    trem = 0.85 + 0.15 * np.sin(2 * np.pi * 0.25 * x)
    pad.append(y * trem * env(len(x), 0.8, 0.9))
music = lowpass(np.concatenate(pad), 6)
sparkle = np.zeros_like(music)
for i in range(18):
    p = int(rng.integers(0, len(music) - SR))
    fr = rng.choice([880, 1046.5, 1318.5, 1568])
    seg = np.sin(2 * np.pi * fr * t(1.0)) * np.exp(-t(1.0) * 4) * 0.35
    sparkle[p:p + len(seg)] += seg
save("music", music + sparkle, 0.35)
# typing: a soft, short terminal click (one sound for every character)
x = t(0.028)
click = (np.sin(2 * np.pi * 1850 * x) * 0.55 + rng.normal(0, 1, len(x)) * 0.45) * np.exp(-x * 190)
save("type", lowpass(click, 3), 0.42)

# footsteps heard through the suit: a dull, low thud (no air outside, so only the body carries it)
x = t(0.11)
thud = (np.sin(2 * np.pi * 95 * x) + 0.4 * np.sin(2 * np.pi * 180 * x)) * np.exp(-x * 38) + rng.normal(0, 0.15, len(x)) * np.exp(-x * 60)
save("step", lowpass(thud, 10), 0.5)

# breathing in the helmet while sprinting
x = t(0.9)
breath = rng.normal(0, 1, len(x))
breath = lowpass(lowpass(breath, 30), 30) * np.sin(np.pi * x / 0.9) ** 2
save("breath", breath, 0.4)
# radio: a short burst of static and a squelch beep before someone on the radio talks
x = t(0.22)
hiss = lowpass(rng.normal(0, 1, len(x)), 2) * (0.6 + 0.4 * np.sin(2 * np.pi * 37 * x)) * env(len(x), 0.005, 0.12)
beep = np.sin(2 * np.pi * 1320 * t(0.06)) * env(int(SR * 0.06), 0.003, 0.03)
save("radio", np.concatenate([hiss, beep * 0.5]), 0.32)

# sparkle: a quick rising chime when gear is picked up
parts = []
for f in [1318.5, 1568, 2093]:
    y = t(0.07)
    parts.append(np.sin(2 * np.pi * f * y) * np.exp(-y * 30))
save("sparkle", np.concatenate(parts + [np.zeros(int(SR * 0.05))]), 0.4)

# boop: tapping a rock or the ground
x = t(0.09)
save("boop", np.sin(2 * np.pi * (520 - 1800 * x) * x) * np.exp(-x * 40), 0.3)
print("ok")

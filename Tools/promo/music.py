"""Soundtrack for the BRBuddy promo film, synthesised from scratch (no samples, nothing licensed).

A light, bouncy I-V-vi-IV loop in C: marimba-ish arpeggios, a soft bass, a bell melody, little drums, then a held
C chord under the end card. Mixes in the boop sounds the app rendered (cues.txt) and an unlock chime.

Usage: python3 Tools/promo/music.py <render dir>    (writes <render dir>/soundtrack.wav)
Needs numpy.
"""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44_100
LENGTH = 30.0
BAR = 26.6 / 12          # 12 bars end exactly when the end card starts
BEAT = BAR / 4
END = 12 * BAR

out = np.zeros(int(RATE * LENGTH) + RATE)


def note_hz(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semis = names[name[0]] + (1 if "#" in name else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((semis - 9) / 12 + (octave - 4))


def add(start, samples, gain=1.0):
    i = int(start * RATE)
    if i >= len(out):
        return
    n = min(len(samples), len(out) - i)
    out[i:i + n] += samples[:n] * gain


def env(n, attack=0.004, decay=6.0):
    t = np.arange(n) / RATE
    a = np.minimum(t / attack, 1.0)
    return a * np.exp(-decay * t)


def marimba(hz, length=0.6):
    n = int(length * RATE)
    t = np.arange(n) / RATE
    tone = np.sin(2 * np.pi * hz * t) + 0.35 * np.sin(2 * np.pi * hz * 4 * t) * np.exp(-30 * t)
    return tone * env(n, decay=7.0)


def bell(hz, length=1.2):
    n = int(length * RATE)
    t = np.arange(n) / RATE
    tone = (np.sin(2 * np.pi * hz * t) + 0.4 * np.sin(2 * np.pi * hz * 2.76 * t) * np.exp(-6 * t)
            + 0.2 * np.sin(2 * np.pi * hz * 5.4 * t) * np.exp(-12 * t))
    return tone * env(n, attack=0.002, decay=3.2)


def bass(hz, length):
    n = int(length * RATE)
    t = np.arange(n) / RATE
    tone = np.sin(2 * np.pi * hz * t) + 0.25 * np.sin(2 * np.pi * hz * 2 * t)
    return tone * env(n, attack=0.01, decay=2.5)


def pad(freqs, length):
    n = int(length * RATE)
    t = np.arange(n) / RATE
    tone = sum(np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 1.003 * t) for f in freqs) / len(freqs)
    shape = np.minimum(t / 0.8, 1.0) * np.minimum((length - t) / 1.2, 1.0)
    return tone * np.clip(shape, 0, 1)


def kick():
    n = int(0.25 * RATE)
    t = np.arange(n) / RATE
    hz = 50 + 90 * np.exp(-25 * t)
    return np.sin(2 * np.pi * np.cumsum(hz) / RATE) * np.exp(-14 * t)


def hat(seed):
    n = int(0.05 * RATE)
    noise = np.random.default_rng(seed).uniform(-1, 1, n)
    noise = np.diff(noise, prepend=0)   # brighter
    return noise * np.exp(-90 * np.arange(n) / RATE)


def chime(length=1.4):
    gap = np.zeros(int(0.09 * RATE))
    first = np.concatenate([bell(note_hz("G5"), length), gap])
    return 0.6 * first + 0.6 * np.concatenate([gap, bell(note_hz("C6"), length)])


chords = [  # I V vi IV
    ["C4", "E4", "G4", "C5"], ["G3", "B3", "D4", "G4"], ["A3", "C4", "E4", "A4"], ["F3", "A3", "C4", "F4"],
]
roots = ["C2", "G2", "A2", "F2"]
melody = [  # (bar offset in beats, note, beats) over each 4-bar loop
    (0, "E5", 1), (1, "G5", 1), (2, "C6", 1.5), (3.5, "B5", 0.5),
    (4, "D5", 1), (5, "G5", 1), (6, "B5", 2),
    (8, "C5", 1), (9, "E5", 1), (10, "A5", 1.5), (11.5, "G5", 0.5),
    (12, "F5", 1), (13, "A5", 1), (14, "C6", 1), (15, "A5", 1),
]

for bar in range(12):
    start = bar * BAR
    chord = chords[bar % 4]
    # Arpeggio in eighths: sparse in the two intro bars.
    pattern = [0, 2, 1, 3, 2, 1, 3, 2]
    for step, idx in enumerate(pattern):
        if bar < 2 and step % 2:
            continue
        add(start + step * BEAT / 2, marimba(note_hz(chord[idx])), 0.22)
    add(start, pad([note_hz(n) for n in chord[:3]], BAR + 0.4), 0.05)
    if bar >= 2:
        add(start, bass(note_hz(roots[bar % 4]), BEAT * 1.8), 0.32)
        add(start + 2 * BEAT, bass(note_hz(roots[bar % 4]), BEAT * 1.8), 0.26)
        for beat in range(4):
            if beat % 2 == 0:
                add(start + beat * BEAT, kick(), 0.35)
            add(start + beat * BEAT + BEAT / 2, hat(bar * 4 + beat), 0.06)
    if 4 <= bar < 12:
        loop_bar = (bar - 4) % 4
        for at, name, beats in melody:
            if loop_bar * 4 <= at < loop_bar * 4 + 4:
                add(start + (at - loop_bar * 4) * BEAT, bell(note_hz(name), max(beats * BEAT * 1.6, 0.6)), 0.16)

# End card: a bright C chord that rings out.
for i, name in enumerate(["C3", "G3", "C4", "E4", "G4", "C5", "E5"]):
    add(END + i * 0.035, bell(note_hz(name), 3.6), 0.13)
add(END, pad([note_hz(n) for n in ["C4", "E4", "G4"]], 3.4), 0.08)
add(END, kick(), 0.3)

# Sound effects.
render = Path(sys.argv[1])
for line in (render / "cues.txt").read_text().split("\n"):
    if not line.strip():
        continue
    at, name = line.split()
    with wave.open(str(render / name)) as w:
        assert w.getframerate() == RATE and w.getsampwidth() == 2 and w.getnchannels() == 1
        boop = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2") / 32768.0
    add(float(at), boop, 0.9)
add(23.2 + 1.9, chime(), 0.35)   # Touch ID unlock in "Back already?"

audio = out[:int(RATE * LENGTH)]
fade = int(0.6 * RATE)
audio[-fade:] *= np.linspace(1, 0, fade)
audio *= 0.89 / np.max(np.abs(audio))
with wave.open(str(render / "soundtrack.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes((audio * 32767).astype("<i2").tobytes())
print("wrote", render / "soundtrack.wav")

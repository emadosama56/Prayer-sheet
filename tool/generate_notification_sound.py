#!/usr/bin/env python3
"""Generates the app's notification sound.

A soft two-note chime, deliberately gentler and lower than Android's default
notification tones. Kept as a script so the asset can be regenerated and
tweaked rather than living in the repo as an unexplained binary.

    python3 tool/generate_notification_sound.py

Writes android/app/src/main/res/raw/soft_chime.wav
"""

import math
import os
import struct
import wave

RATE = 44_100
OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "android", "app", "src", "main", "res", "raw", "soft_chime.wav",
)

# Two notes a perfect fourth apart (G5 -> C6): calm and resolved, not an alert.
NOTES = [
    # (frequency Hz, start second, length second, peak amplitude)
    (783.99, 0.00, 1.05, 0.30),
    (1046.50, 0.16, 1.10, 0.26),
]

ATTACK = 0.012   # short fade-in, so the tone never clicks
DECAY_TAU = 0.30  # exponential fall-off


def envelope(t: float, length: float) -> float:
    if t < 0 or t > length:
        return 0.0
    attack = min(1.0, t / ATTACK)
    decay = math.exp(-t / DECAY_TAU)
    # Fade the tail fully to zero so notes do not end abruptly.
    tail = min(1.0, (length - t) / 0.08)
    return attack * decay * tail


def main() -> None:
    total = max(start + length for _, start, length, _ in NOTES)
    frames = int(total * RATE)
    samples = [0.0] * frames

    for freq, start, length, peak in NOTES:
        offset = int(start * RATE)
        for i in range(int(length * RATE)):
            if offset + i >= frames:
                break
            t = i / RATE
            env = envelope(t, length)
            # A quiet octave above adds warmth without making it brighter.
            tone = math.sin(2 * math.pi * freq * t) + 0.18 * math.sin(
                2 * math.pi * freq * 2 * t
            )
            samples[offset + i] += peak * env * tone / 1.18

    peak = max(abs(s) for s in samples) or 1.0
    # Leave real headroom: this should read as soft next to other apps' sounds.
    gain = 0.45 / peak

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "w") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767))
                for s in samples
            )
        )
    print(f"wrote {OUT} ({os.path.getsize(OUT) / 1024:.0f} KB, {total:.2f}s)")


if __name__ == "__main__":
    main()

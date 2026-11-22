"""Rebuild the two original menu sounds using Python's standard library."""
import math
import random
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).parent


def render(name, duration, tone, end_tone, noise=0.0, decay=2.0, harmonics=0.0):
    rng = random.Random(193 + len(name))
    samples = bytearray()
    phase = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        u = t / duration
        phase += 2 * math.pi * (tone + (end_tone - tone) * u) / RATE
        envelope = (1 - u) ** decay * min(1.0, t * 150)
        wave_value = math.sin(phase) + harmonics * math.sin(2 * phase)
        value = envelope * (wave_value * (1 - noise) + rng.uniform(-1, 1) * noise)
        samples.extend(int(max(-1, min(1, value * 0.46)) * 32767).to_bytes(2, "little", signed=True))
    with wave.open(str(OUT / (name + ".wav")), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(samples)


render("ui_select", .075, 390, 350, .025, 2.1, .04)
render("ui_confirm", .14, 480, 410, .02, 1.9, .06)

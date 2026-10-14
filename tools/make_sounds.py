#!/usr/bin/env python3
"""Synthesize Warfront Mandate's sound effects and music from scratch (owner request 2026-10-12).

Nothing here is sampled or downloaded: every sound is built from noise, oscillators, filters and
a synthetic reverb, so the owner holds all rights to the output.

Usage:  python3 tools/make_sounds.py game/assets/audio
Writes: sfx/*.ogg (weapons, explosions, aircraft, events, UI) and music/*.ogg (menu, battle).
Needs numpy, scipy and ffmpeg (libvorbis).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(1942)


# ---- building blocks --------------------------------------------------------------------------
def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def noise(seconds):
    return RNG.standard_normal(int(SR * seconds))


def filt(x, kind, freq, order=2):
    """Butterworth filter; freq in Hz (pair for bandpass)."""
    wn = np.asarray(freq, dtype=float) / (SR / 2)
    b, a = signal.butter(order, np.clip(wn, 1e-4, 0.999), btype=kind)
    return signal.lfilter(b, a, x)


def env(seconds, attack, decay_time, curve=1.0):
    """Fast attack, exponential decay (decay_time = time to ~-60 dB)."""
    t = t_axis(seconds)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-6.9 * (t / decay_time) ** curve)
    return a * d


def sweep(seconds, f0, f1, shape="exp"):
    t = t_axis(seconds)
    if shape == "exp":
        f = f0 * (f1 / f0) ** (t / seconds)
    else:
        f = f0 + (f1 - f0) * t / seconds
    return 2 * np.pi * np.cumsum(f) / SR


def pad(x, seconds):
    out = np.zeros(int(SR * seconds))
    out[: min(len(x), len(out))] = x[: len(out)]
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, start, total):
    out = np.zeros(int(SR * total))
    i = int(SR * start)
    n = min(len(x), len(out) - i)
    out[i: i + n] += x[:n]
    return out


def reverb(x, seconds=1.2, wet=0.3, tone=4000):
    ir = filt(noise(seconds), "low", tone) * np.exp(-6.9 * t_axis(seconds) / seconds)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet_sig = signal.fftconvolve(x, ir)[: len(x) + int(SR * seconds)]
    dry = np.concatenate([x, np.zeros(len(wet_sig) - len(x))])
    return dry * (1 - wet) + wet_sig * wet


def normalize(x, peak_db=-1.0):
    peak = np.max(np.abs(x)) + 1e-9
    return x / peak * 10 ** (peak_db / 20)


def fade_out(x, seconds):
    n = min(len(x), int(SR * seconds))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n) ** 2
    return x


def write_ogg(x, path, quality=4):
    x = np.clip(x, -1, 1)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp.name, "-c:a", "libvorbis",
                        "-q:a", str(quality), path], check=True)
    os.unlink(tmp.name)


# ---- weapons ----------------------------------------------------------------------------------
def boom(seconds, f0, f1, decay, crack=0.5, rumble=0.6):
    """Shared core of guns and explosions: crack transient, falling low thump, rumble tail."""
    t = t_axis(seconds)
    thump = np.sin(sweep(seconds, f0, f1)) * env(seconds, 0.002, decay * 0.6)
    crack_sig = filt(noise(seconds), "high", 1800) * env(seconds, 0.0005, 0.06) * crack
    body = filt(noise(seconds), "low", 900) * env(seconds, 0.003, decay * 0.5) * 0.8
    tail = filt(noise(seconds), "low", 220) * env(seconds, 0.02, decay, 0.8) * rumble
    return thump * 1.2 + crack_sig + body + tail


def tank_cannon():
    x = boom(2.2, 90, 38, 1.6, crack=0.9, rumble=0.7)
    return normalize(fade_out(reverb(x, 1.4, 0.25, 2500), 0.4))


def autocannon():
    """Short burst of an IFV autocannon / heavy machine gun."""
    shots = []
    total = 1.1
    for i in range(6):
        s = filt(noise(0.12), "band", (500, 4500)) * env(0.12, 0.0005, 0.05) * 0.9
        s += np.sin(sweep(0.12, 160, 70)) * env(0.12, 0.001, 0.07) * 0.7
        shots.append(at(s, i * 0.11 + RNG.uniform(0, 0.012), total))
    return normalize(fade_out(reverb(mix(*shots), 0.6, 0.2, 5000), 0.2))


def artillery():
    x = boom(3.2, 70, 28, 2.6, crack=1.0, rumble=1.0)
    return normalize(fade_out(reverb(x, 2.2, 0.35, 1800), 0.6))


def naval_gun():
    x = boom(3.0, 80, 32, 2.2, crack=0.9, rumble=0.8)
    ring = np.sin(sweep(3.0, 410, 395)) * env(3.0, 0.001, 0.9) * 0.08  # steel deck ring
    return normalize(fade_out(reverb(x + ring, 2.6, 0.4, 2200), 0.6))


def rocket(seconds, low, high, ignition=1.0, rise=0.35):
    """Ignition pop then a roaring, receding rocket motor."""
    t = t_axis(seconds)
    roar = filt(noise(seconds), "band", (low, high))
    roar += 0.5 * filt(noise(seconds), "low", low)
    shape = np.clip(t / rise, 0, 1) ** 0.6 * np.exp(-2.2 * np.clip(t - rise, 0, None) / seconds * 2)
    crackle = (RNG.random(len(t)) < 0.004) * RNG.standard_normal(len(t)) * 2.0
    crackle = filt(crackle, "high", 2000) * shape
    pop = boom(seconds, 120, 50, 0.6, crack=0.7, rumble=0.2) * ignition
    return roar * shape + crackle * 0.4 + pop * 0.8


def missile_launch():
    x = rocket(3.0, 300, 3000, rise=0.4)
    return normalize(fade_out(reverb(x, 1.6, 0.3, 3500), 0.8))


def interceptor():
    """Air-defence missile: sharper, faster, higher whoosh."""
    x = rocket(2.0, 700, 6000, ignition=0.6, rise=0.12)
    t = t_axis(2.0)
    hiss = filt(noise(2.0), "high", 3000) * np.exp(-3 * t) * 0.6
    return normalize(fade_out(reverb(x + hiss, 1.2, 0.25, 5000), 0.5))


def flyover(seconds, speed=260.0, altitude=180.0, whine=1150.0, rumble=1.0, bright=1.0, centre=0.45):
    """Physically modelled aircraft pass (owner: the old jet sounds were poor).
    Distance r(t) from a listener under the flight path gives: loudness ~1/r, air absorption
    (duller far away), the true Doppler shift of the turbine whine, and the ground-reflection
    comb filter that makes the classic 'flanging' roar as a jet passes overhead."""
    t = t_axis(seconds)
    c = 343.0
    x_pos = (t - seconds * centre) * speed                  # metres along track, 0 = overhead
    r = np.sqrt(x_pos ** 2 + altitude ** 2)
    approach = -x_pos / r                                    # +1 coming, -1 going
    doppler = c / (c - speed * approach)
    loud = (altitude / r) ** 1.15
    # Broadband jet roar: brown + pink-ish noise, brightness follows distance.
    n = noise(seconds)
    brown = np.cumsum(n)
    brown = filt(brown - np.convolve(brown, np.ones(2205) / 2205, mode="same"), "high", 25)
    brown /= np.max(np.abs(brown)) + 1e-9
    near = filt(n, "band", (180, 6500 * bright)) * 0.8
    far = filt(n, "band", (90, 1400 * bright))
    closeness = np.clip(altitude / r, 0, 1) ** 1.5
    roar = near * closeness + far * (1 - closeness) * 0.9 + brown * 0.9 * rumble
    # Turbine whine with harmonics, Doppler shifted.
    phase = 2 * np.pi * np.cumsum(whine * doppler) / SR
    turbine = 0.10 * np.sin(phase) + 0.05 * np.sin(2 * phase + 0.4) + 0.025 * np.sin(3.01 * phase)
    turbine = filt(turbine, "low", 5000 * bright) * closeness ** 0.5
    body = roar + turbine
    # Ground reflection: a delayed copy whose delay changes as the plane passes (flanging).
    ear = 1.7
    delay = 2 * altitude * ear / (c * r)                    # seconds, path difference
    idx = np.arange(len(t)) - delay * SR
    reflected = np.interp(idx, np.arange(len(t)), body, left=0.0)
    body = body + 0.75 * reflected
    # Low engine rumble felt near the pass.
    thump = filt(n, "low", 120) * 1.4 * rumble * closeness
    out = (body + thump) * loud
    edge = np.clip(t / 0.25, 0, 1) * np.clip((seconds - t) / 0.4, 0, 1)
    return out * edge


def jet_flyby(seconds=3.2):
    """Fast jet pass (fighters)."""
    return flyover(seconds, speed=280.0, altitude=150.0, whine=1250.0, rumble=0.8, bright=1.0)


def air_strike():
    """Strike aircraft passing over; the bomb blast is the impact explosion played in game."""
    return normalize(fade_out(reverb(jet_flyby(3.4), 1.5, 0.3, 2800), 0.6))


def drone_buzz(seconds=2.4):
    t = t_axis(seconds)
    prop = signal.sawtooth(sweep(seconds, 118, 112, "lin")) * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t))
    prop = filt(prop, "band", (90, 2200))
    loud = np.clip(t / 0.4, 0, 1) * np.clip((seconds - t) / 0.6, 0, 1)
    return prop * loud * 0.5


def drone_strike():
    """Attack drone buzzing in; the impact explosion is played in game."""
    return normalize(fade_out(reverb(drone_buzz(2.4), 1.0, 0.25, 3500), 0.5))


def explosion_small():
    x = boom(1.8, 100, 40, 1.2, crack=1.0, rumble=0.6)
    return normalize(fade_out(reverb(x, 1.0, 0.25, 3000), 0.3))


def explosion_large():
    x = boom(3.6, 70, 25, 3.0, crack=1.0, rumble=1.2)
    t = t_axis(3.6)
    debris = (RNG.random(len(t)) < 0.002 * np.exp(-1.5 * t)) * RNG.standard_normal(len(t)) * 3
    debris = filt(debris, "band", (800, 6000))
    return normalize(fade_out(reverb(x + debris * 0.5, 2.4, 0.35, 2000), 0.8))


def helicopter(seconds=2.5):
    t = t_axis(seconds)
    blades = (np.sin(2 * np.pi * 9.5 * t) > 0.6).astype(float)
    blades = filt(blades, "low", 300) * filt(noise(seconds), "low", 600)
    loud = np.clip(t / 0.5, 0, 1) * np.clip((seconds - t) / 0.8, 0, 1)
    return normalize(blades * loud)


# ---- events and interface ---------------------------------------------------------------------
def tone(freq, seconds, kind="sine", decay=None, vibrato=0.0):
    t = t_axis(seconds)
    phase = 2 * np.pi * freq * t + vibrato * np.sin(2 * np.pi * 5.5 * t)
    w = {"sine": np.sin(phase), "saw": signal.sawtooth(phase), "square": signal.square(phase)}[kind]
    return w * (env(seconds, 0.01, decay) if decay else 1)


def brass(freq, seconds, bright=2500):
    t = t_axis(seconds)
    x = sum(tone(freq * d, seconds, "saw", vibrato=0.6) for d in (1.0, 1.004, 0.996))
    x = filt(x, "low", bright)
    a = np.clip(t / 0.06, 0, 1) * np.clip((seconds - t) / 0.15, 0, 1)
    return x * a / 3


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    step = names[name[0]] + (1 if "#" in name else -1 if "b" in name[1:-1] else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((step + 12 * (octave - 4)) / 12)


def ui_click():
    x = filt(noise(0.05), "band", (1500, 6000)) * env(0.05, 0.0005, 0.02)
    x += tone(1900, 0.05, decay=0.03) * 0.3
    return normalize(x, -6)


def war_declared():
    """Air-raid siren (owner 2026-10-13: "make a different air raid siren, like a normal one you
    hear"): the familiar single-tone civil-defence wail - a slow rise, a short hold and a slow
    fall, twice - with the volume swell of a rotating siren head, heard across a town."""
    seconds = 14.0
    t = t_axis(seconds)
    cycle = 7.0
    phase = np.mod(t, cycle)
    # 0-3 s rise, 3-4 s hold, 4-7 s fall (smooth, like a motor spinning up and down).
    rise = 0.5 - 0.5 * np.cos(np.pi * np.clip(phase / 3.0, 0, 1))
    fall = 0.5 + 0.5 * np.cos(np.pi * np.clip((phase - 4.0) / 3.0, 0, 1))
    shape = np.where(phase < 4.0, rise, fall)
    pitch = 160 + 380 * shape
    angle = 2 * np.pi * np.cumsum(pitch) / SR
    # A siren's chopped air gives a buzzy, horn-like tone: strong odd harmonics.
    tone = (np.sin(angle) + 0.55 * np.sin(3 * angle) + 0.3 * np.sin(5 * angle)
            + 0.18 * np.sin(2 * angle) + 0.12 * np.sin(7 * angle))
    tone = filt(tone, "low", 2200)
    swell = 0.72 + 0.28 * np.sin(2 * np.pi * t / 2.6)  # rotating head
    level = (0.3 + 0.7 * shape) * swell
    fade = np.clip(t / 0.5, 0, 1) * np.clip((seconds - t) / 1.2, 0, 1)
    return normalize(reverb(tone * level * fade, 2.8, 0.45, 2600))



def jet_flyby():
    """Fast jet passing overhead (owner 2026-10-13: "there's no sound with the planes"): a
    roaring turbine that swells, peaks and fades, with the Doppler drop of the whine."""
    seconds = 4.5
    t = t_axis(seconds)
    approach = np.exp(-((t - 2.0) / 0.9) ** 2)
    roar = filt(noise(seconds), "band", (120, 1800)) * (0.15 + approach)
    hiss = filt(noise(seconds), "high", 2500) * approach * 0.35
    whine_f = 2600 - 1300 * (0.5 + 0.5 * np.tanh((t - 2.0) * 3.0))
    whine = np.sin(2 * np.pi * np.cumsum(whine_f) / SR) * approach * 0.12
    rumble = filt(noise(seconds), "low", 90) * approach * 0.8
    x = roar + hiss + whine + rumble
    return normalize(fade_out(reverb(x, 1.6, 0.3, 3000), 0.6))


def bomb_whistle():
    """Falling bomb: a descending whistle, then the impact."""
    fall = 1.3
    t = t_axis(fall)
    f = 1500 - 900 * (t / fall) ** 1.4
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.15 + 0.5 * t / fall)
    whistle += filt(noise(fall), "band", (900, 2400)) * 0.08 * t / fall
    hit = boom(2.4, 70, 30, 1.8, crack=0.9, rumble=0.9)
    total = fall + 2.4
    return normalize(reverb(mix(at(whistle, 0, total), at(hit, fall, total) * 1.3), 1.8, 0.35, 2800))


def nuclear_blast():
    """Nuclear detonation (owner: "make that amazing"): a sharp blinding crack, a long earth-
    shaking roar that rolls on, the shock wave arriving, and the wind of the rising cloud."""
    seconds = 12.0
    t = t_axis(seconds)
    crack = filt(noise(seconds), "high", 1200) * env(seconds, 0.0005, 0.12) * 1.4
    thump = np.sin(sweep(seconds, 55, 18)) * env(seconds, 0.01, 4.0) * 1.6
    roar = filt(noise(seconds), "low", 160) * env(seconds, 0.3, 7.0, 0.9) * 1.4
    rolling = filt(noise(seconds), "band", (40, 400)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * t)) * env(seconds, 1.0, 8.0) * 0.8
    shock = at(boom(3.0, 60, 25, 2.5, crack=1.0, rumble=1.0), 1.4, seconds) * 1.1
    wind = filt(noise(seconds), "band", (200, 1400)) * np.clip((t - 2.5) / 3.0, 0, 1) * np.clip((seconds - t) / 4.0, 0, 1) * 0.35
    return normalize(fade_out(reverb(crack + thump + roar + rolling + shock + wind, 3.5, 0.5, 2000), 2.0))



def tracks_moving():
    """Tanks and tracked armour moving off (owner 2026-10-13: "nothing else makes noise"):
    a revving diesel and the clank-squeal of tracks."""
    seconds = 4.0
    t = t_axis(seconds)
    rev = np.clip(t / 0.8, 0, 1)
    engine_f = 38 + 22 * rev
    engine = np.sin(2 * np.pi * np.cumsum(engine_f) / SR) + 0.5 * np.sin(4 * np.pi * np.cumsum(engine_f) / SR)
    engine = filt(engine + filt(noise(seconds), "low", 260) * 0.8, "low", 500) * (0.4 + 0.6 * rev)
    clank = np.zeros_like(t)
    rate = 7.0
    for k in range(int(seconds * rate)):
        start = int(SR * (k / rate + 0.02 * np.sin(k)))
        if start >= len(t): break
        hit = filt(noise(0.05), "band", (900, 3200)) * env(0.05, 0.001, 0.03)
        clank[start:start + len(hit)] += hit[: len(t) - start] * (0.5 + 0.3 * rev[start])
    squeal = np.sin(2 * np.pi * np.cumsum(1800 + 200 * np.sin(2 * np.pi * 0.7 * t)) / SR) * 0.04 * rev
    x = engine * 1.2 + clank + squeal
    return normalize(fade_out(reverb(x, 1.2, 0.25, 3000), 0.8))


def wheels_moving():
    """Wheeled armour (APCs, trucks, launchers) driving off: a turbo-diesel and road rumble."""
    seconds = 3.5
    t = t_axis(seconds)
    rev = np.clip(t / 0.6, 0, 1)
    f = 55 + 45 * rev
    engine = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.6 * np.sin(4 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(6 * np.pi * np.cumsum(f) / SR)
    engine = filt(engine, "low", 700) * (0.4 + 0.6 * rev)
    road = filt(noise(seconds), "band", (60, 500)) * 0.5 * rev
    turbo = np.sin(2 * np.pi * np.cumsum(2400 * (0.6 + 0.4 * rev)) / SR) * 0.03 * rev
    return normalize(fade_out(reverb(engine + road + turbo, 1.0, 0.2, 3000), 0.7))


def march():
    """Infantry moving out: boots in step and rattling gear."""
    seconds = 3.5
    t = t_axis(seconds)
    x = np.zeros_like(t)
    for k in range(int(seconds * 4)):
        for offset in (0.0, 0.035, 0.07):
            start = int(SR * (k * 0.25 + offset + RNG.uniform(0, 0.02)))
            if start >= len(t): continue
            step = filt(noise(0.07), "band", (120, 1400)) * env(0.07, 0.002, 0.05) * 0.6
            x[start:start + len(step)] += step[: len(t) - start]
    gear = filt(noise(seconds), "band", (2500, 6000)) * 0.05 * (0.5 + 0.5 * np.sin(2 * np.pi * 4 * t))
    return normalize(fade_out(reverb(x + gear, 0.8, 0.2, 4000), 0.6))



def nuclear_alarm():
    """Nuclear launch klaxon under the siren: a harsh two-tone alarm pulsing fast."""
    seconds = 5.0
    t = t_axis(seconds)
    high = (np.mod(t, 0.5) < 0.25)
    f = np.where(high, 880.0, 660.0)
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.5 + np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.5
    gate = 0.6 + 0.4 * (np.mod(t, 0.25) < 0.2)
    return normalize(fade_out(reverb(filt(tone, "low", 3000) * gate * 0.7, 0.8, 0.25, 3500), 0.4))


def fanfare(notes, beat=0.32, minor=False):
    total = beat * (len(notes) + 4)
    parts = []
    for i, (n, length) in enumerate(notes):
        parts.append(at(brass(note(n), beat * length * 0.95), i * beat, total))
    x = mix(*parts)
    drum = sum(at(boom(0.8, 110, 50, 0.5, 0.4, 0.2), i * beat * 2, total) for i in range(len(notes) // 2 + 1))
    return normalize(fade_out(reverb(x + drum * 0.5, 2.0, 0.35, 4000), 0.8))


def victory():
    return fanfare([("D4", 1), ("A4", 1), ("D5", 1), ("F#5", 1), ("A5", 3)])


def defeat():
    return fanfare([("A4", 1), ("F4", 1), ("D4", 1), ("C#4", 1), ("D3", 3)])


def chime(freqs, step=0.12):
    total = step * len(freqs) + 1.4
    x = mix(*[at(mix(tone(f, 1.4, decay=1.2), 0.3 * tone(f * 2.01, 1.0, decay=0.6)), i * step, total)
              for i, f in enumerate(freqs)])
    return normalize(reverb(x, 1.2, 0.3, 6000), -4)


def build_complete():
    hammer = mix(*[at(filt(noise(0.08), "band", (600, 3000)) * env(0.08, 0.0005, 0.04), i * 0.16, 0.6)
                   for i in range(3)])
    return normalize(mix(hammer * 0.8, at(chime([note("D5"), note("A5")]), 0.5, 2.6)), -4)


def research_complete():
    return chime([note("D5"), note("F#5"), note("A5"), note("D6")], 0.1)


def city_captured():
    return fanfare([("A4", 1), ("D5", 1), ("A5", 2)], beat=0.26)


# ---- music ------------------------------------------------------------------------------------
def frame_drum(seconds=1.2, f=62, accent=1.0):
    x = np.sin(sweep(seconds, f * 1.8, f)) * env(seconds, 0.002, 0.9) * accent
    x += filt(noise(seconds), "band", (80, 900)) * env(seconds, 0.001, 0.12) * 0.5 * accent
    return x


def low_drone(freq, seconds):
    t = t_axis(seconds)
    x = sum(signal.sawtooth(2 * np.pi * freq * d * t) for d in (1.0, 1.003, 0.997, 2.0))
    x = filt(x, "low", 500) * (0.85 + 0.15 * np.sin(2 * np.pi * 0.11 * t))
    return x / 4


def choir(freq, seconds):
    """Low male 'aah' pad: detuned saws through vowel formants."""
    t = t_axis(seconds)
    x = sum(signal.sawtooth(2 * np.pi * freq * d * t + 0.3 * np.sin(2 * np.pi * 4.8 * t + d)) for d in (1, 1.006, 0.994))
    x = filt(x, "band", (500, 1000)) * 0.9 + filt(x, "band", (1000, 1300)) * 0.5 + filt(x, "low", 400) * 0.6
    a = np.clip(t / 1.2, 0, 1) * np.clip((seconds - t) / 1.2, 0, 1)
    return x * a / 3


def horn_line(melody, beat, total):
    parts = []
    pos = 0.0
    for n, length in melody:
        if n != "-":
            parts.append(at(brass(note(n), beat * length * 0.98, bright=1600), pos, total))
        pos += beat * length
    return mix(*parts) if parts else np.zeros(int(SR * total))


def loopable(x, total, tail):
    """Fold the reverb tail back onto the start so the loop is seamless."""
    n = int(SR * total)
    out = x[:n].copy()
    extra = x[n:n + int(SR * tail)]
    out[: len(extra)] += extra
    return out


def menu_theme():
    """Dark Nordic war march in D minor, 72 bpm, 32 bars (~107 s), seamless loop."""
    bpm = 72
    beat = 60 / bpm
    bars = 32
    total = bars * 4 * beat
    tail = 3.0
    length = total + tail
    drums = []
    for bar in range(bars):
        for b, acc in ((0, 1.0), (1.5, 0.5), (2, 0.8), (3, 0.45), (3.5, 0.6)):
            if bar < 2 and b != 0:
                continue
            drums.append(at(frame_drum(1.4, 58, acc), (bar * 4 + b) * beat, length))
    drums = mix(*drums)
    chords = ["D2", "D2", "Bb1", "C2", "D2", "D2", "F2", "A1"]
    drone = mix(*[at(low_drone(note(c), 4 * beat * 4 + 1.0), i * 4 * 4 * beat, length) for i, c in enumerate(chords)])
    voices = ["D3", "D3", "F3", "E3", "D3", "D3", "C3", "C#3"]
    pad_voice = mix(*[at(choir(note(v), 4 * beat * 4 + 1.2), i * 4 * 4 * beat, length) for i, v in enumerate(voices)])
    phrase = [("D4", 2), ("A3", 1), ("D4", 1), ("F4", 2), ("E4", 1), ("D4", 1), ("C4", 2), ("D4", 2), ("A3", 4),
              ("D4", 2), ("F4", 1), ("G4", 1), ("A4", 3), ("G4", 1), ("F4", 2), ("E4", 2), ("D4", 4)]
    horn = horn_line([("-", 32)] + phrase + [("-", 16)] + phrase, beat, length)
    music = drums * 0.9 + drone * 0.45 + pad_voice * 0.55 + horn * 0.5
    music = reverb(music, 3.0, 0.32, 3200)
    return normalize(loopable(music, total, tail), -3)


def battle_theme():
    """Tense driving loop in D minor, 104 bpm, 24 bars (~55 s): pulsing low strings and drums."""
    bpm = 104
    beat = 60 / bpm
    bars = 24
    total = bars * 4 * beat
    tail = 2.0
    length = total + tail
    roots = ["D2", "D2", "Bb1", "Bb1", "C2", "C2", "A1", "A1"] * 3
    pulses = []
    for bar, r in enumerate(roots):
        for e in range(8):
            accent = 1.0 if e % 4 == 0 else 0.6
            s = filt(tone(note(r), beat * 0.45, "saw") + 0.5 * tone(note(r) * 2, beat * 0.45, "saw"), "low", 900)
            s *= env(beat * 0.45, 0.005, beat * 0.5) * accent
            pulses.append(at(s, (bar * 4 + e * 0.5) * beat, length))
    strings = mix(*pulses)
    drums = []
    for bar in range(bars):
        for b, acc in ((0, 1.0), (0.75, 0.4), (1.5, 0.7), (2, 0.9), (2.5, 0.5), (3, 0.8), (3.5, 0.6)):
            drums.append(at(frame_drum(1.0, 64, acc), (bar * 4 + b) * beat, length))
        if bar % 4 == 3:
            drums.append(at(boom(1.6, 80, 35, 1.2, 0.3, 0.4) * 0.6, (bar * 4 + 3.5) * beat, length))
    drums = mix(*drums)
    pad_voice = mix(*[at(choir(note(v), 8 * beat + 1.0), i * 8 * beat, length)
                      for i, v in enumerate(["D3", "F3", "E3", "C#3"] * 3)])
    music = strings * 0.5 + drums * 0.8 + pad_voice * 0.35
    music = reverb(music, 2.0, 0.25, 3500)
    return normalize(loopable(music, total, tail), -4)


def strings(freq, seconds, bright=1800, swell=1.5):
    """Section strings: many detuned saws with slow vibrato, soft attack (an ensemble, not a synth)."""
    t = t_axis(seconds)
    x = sum(signal.sawtooth(2 * np.pi * freq * d * t + 0.25 * np.sin(2 * np.pi * (5.0 + k * 0.3) * t + k))
            for k, d in enumerate((1.0, 1.0035, 0.9965, 1.007, 0.993)))
    x = filt(x, "low", bright) * 0.8 + filt(x, "band", (250, 900)) * 0.4
    a = np.clip(t / swell, 0, 1) * np.clip((seconds - t) / 1.2, 0, 1)
    return x * a / 5


def timpani(f=55, accent=1.0, seconds=2.2):
    x = np.sin(sweep(seconds, f * 1.25, f)) * env(seconds, 0.002, 1.4) * accent
    x += 0.4 * np.sin(sweep(seconds, f * 2.5, f * 2)) * env(seconds, 0.002, 0.6) * accent
    x += filt(noise(seconds), "band", (60, 500)) * env(seconds, 0.001, 0.08) * 0.6 * accent
    return x


def cymbal_swell(seconds=4.0):
    t = t_axis(seconds)
    return filt(noise(seconds), "high", 5000) * (t / seconds) ** 3 * 0.35


def campaign_theme():
    """In-game music (owner: the RAVNIR song is for the start screen only; make another one
    for the game). Cinematic strategy theme, D minor, 84 bpm, ~2 min seamless loop:
    A (calm map ambience) -> B (low string ostinato + timpani) -> C (full: horns, choir) -> back to A."""
    bpm = 84
    beat = 60 / bpm
    bar = 4 * beat
    sections = [("A", 12), ("B", 12), ("C", 16)]
    bars = sum(n for _, n in sections)
    total = bars * bar
    tail = 3.0
    length = total + tail
    chords = [("D2", ["D3", "F3", "A3"]), ("Bb1", ["Bb2", "D3", "F3"]), ("G1", ["G2", "Bb2", "D3"]), ("A1", ["A2", "C#3", "E3"])]
    layers = {k: [] for k in ("pad", "bass", "ostinato", "drums", "horn", "choir", "fx")}
    b0 = 0
    for name, n in sections:
        for k in range(n):
            pos = (b0 + k) * bar
            root, triad = chords[(b0 + k) % 4]
            # Strings pad holds each chord for a bar (always on, quiet in A).
            level = {"A": 0.55, "B": 0.75, "C": 1.0}[name]
            pad = mix(*[strings(note(v), bar + 0.8, 1500 if name == "A" else 2200) for v in triad])
            layers["pad"].append(at(pad * level, pos, length))
            layers["bass"].append(at(low_drone(note(root), bar + 0.5) * (0.6 if name == "A" else 0.9), pos, length))
            if name in ("B", "C"):
                # Driving eighth-note ostinato on the root, accented on 1 and the "and" of 2.
                for e in range(8):
                    acc = 1.0 if e in (0, 3) else 0.55
                    o = filt(tone(note(root) * 2, beat * 0.42, "saw") + 0.4 * tone(note(root) * 4, beat * 0.42, "saw"), "low", 1100)
                    layers["ostinato"].append(at(o * env(beat * 0.42, 0.004, beat * 0.4) * acc, pos + e * beat * 0.5, length))
                layers["drums"].append(at(timpani(note(root) * 2 if note(root) < 50 else note(root), 1.0), pos, length))
                if name == "C" or k % 2 == 1:
                    layers["drums"].append(at(timpani(note(root) * 2 if note(root) < 50 else note(root), 0.6), pos + 2.5 * beat, length))
                if name == "C":
                    layers["drums"].append(at(frame_drum(0.8, 70, 0.5), pos + beat, length))
                    layers["drums"].append(at(frame_drum(0.8, 70, 0.7), pos + 3 * beat, length))
            if name == "A" and k % 4 == 0:
                layers["fx"].append(at(timpani(46, 0.7, 3.0), pos, length))
        if name == "C":
            melody = [("D4", 3), ("F4", 1), ("A4", 4), ("G4", 2), ("F4", 2), ("E4", 4),
                      ("D4", 3), ("E4", 1), ("F4", 2), ("G4", 2), ("A4", 6), ("-", 2),
                      ("Bb4", 3), ("A4", 1), ("G4", 4), ("F4", 2), ("E4", 2), ("D4", 4),
                      ("C#4", 4), ("E4", 4), ("D4", 8)]
            layers["horn"].append(at(horn_line(melody, beat, sum(l for _, l in melody) * beat + 1), b0 * bar, length))
            for k in range(0, n, 2):
                layers["choir"].append(at(choir(note(["D3", "Bb2", "G2", "A2"][(k // 2) % 4]), 2 * bar + 1.0), (b0 + k) * bar, length))
        # Cymbal swell into each new section.
        layers["fx"].append(at(cymbal_swell(4 * beat), (b0 + n) * bar - 4 * beat, length))
        b0 += n
    m = {k: (mix(*v) if v else np.zeros(int(SR * length))) for k, v in layers.items()}
    music = (m["pad"] * 0.55 + m["bass"] * 0.35 + m["ostinato"] * 0.32 + m["drums"] * 0.7
             + m["horn"] * 0.45 + m["choir"] * 0.3 + m["fx"] * 0.6)
    music = reverb(music, 2.6, 0.3, 4200)
    return normalize(loopable(music, total, tail), -5)


# ---- every weapon type (owner: "make sound for all weapons") ----------------------------------
def gunshot(seconds=0.35, low=900, high=7000, thump=180, decay=0.12, crack=1.0):
    x = filt(noise(seconds), "band", (low, high)) * env(seconds, 0.0003, decay * 0.5) * crack
    x += np.sin(sweep(seconds, thump, thump * 0.45)) * env(seconds, 0.001, decay) * 0.6
    return x


def burst(shot, count, gap, jitter=0.01, total=None):
    total = total or count * gap + len(shot) / SR + 0.1
    return mix(*[at(shot * RNG.uniform(0.8, 1.0), i * gap + RNG.uniform(0, jitter), total) for i in range(count)])


def rifle_fire():
    """Infantry squad: several rifles firing short bursts out of step."""
    total = 2.2
    parts = []
    for rifle in range(4):
        start = RNG.uniform(0, 0.8)
        shot = gunshot(0.25, 1200, 8000, 260, 0.09, 0.9)
        parts.append(at(burst(shot, RNG.integers(2, 5), 0.085, 0.01), start, total))
    return normalize(fade_out(reverb(mix(*parts), 0.9, 0.25, 6000), 0.3))


def sniper_shot():
    x = gunshot(1.4, 1500, 9000, 140, 0.35, 1.2)
    return normalize(fade_out(reverb(x, 1.6, 0.35, 5000), 0.4))


def mortar_fire():
    thunk = np.sin(sweep(0.5, 140, 60)) * env(0.5, 0.001, 0.3) + filt(noise(0.5), "low", 700) * env(0.5, 0.001, 0.12)
    whistle = np.sin(sweep(1.6, 1900, 900, "lin")) * env(1.6, 0.4, 2.0, 0.5) * 0.12
    return normalize(fade_out(reverb(mix(thunk, at(whistle, 0.5, 2.1)), 1.2, 0.3, 4000), 0.4))


def atgm_launch():
    """Anti-tank guided missile: pop, then a short hissing flight."""
    pop = boom(1.6, 160, 70, 0.4, 1.0, 0.1)
    hiss = filt(noise(1.6), "band", (1500, 7000)) * env(1.6, 0.03, 1.3) * 0.7
    return normalize(fade_out(reverb(pop + hiss, 0.9, 0.25, 5000), 0.3))


def heavy_machine_gun():
    """12.7 mm on an APC: slower, deeper thumps than the autocannon."""
    shot = gunshot(0.18, 400, 4000, 120, 0.1, 0.8)
    return normalize(fade_out(reverb(burst(shot, 7, 0.13, 0.008), 0.7, 0.2, 4000), 0.2))


def mlrs_salvo():
    """Rocket artillery: a ripple of rockets, each with its own whoosh."""
    total = 4.5
    parts = []
    for i in range(10):
        r = rocket(1.8, 400, 4000, ignition=0.7, rise=0.08) * 0.6
        parts.append(at(r, i * 0.22 + RNG.uniform(0, 0.04), total))
    return normalize(fade_out(reverb(mix(*parts), 1.8, 0.3, 3500), 0.8))


def ballistic_missile():
    """Heavy ballistic missile: deep ignition and a long thundering climb."""
    seconds = 6.0
    t = t_axis(seconds)
    roar = filt(noise(seconds), "low", 260) * 1.4 + filt(noise(seconds), "band", (260, 1800)) * 0.6
    shape = np.clip(t / 0.8, 0, 1) * np.exp(-0.45 * np.clip(t - 0.8, 0, None))
    crackle = filt((RNG.random(len(t)) < 0.006) * RNG.standard_normal(len(t)) * 2.5, "band", (300, 3000))
    ignition = boom(seconds, 60, 25, 2.0, 0.6, 0.8)
    return normalize(fade_out(reverb(roar * shape + crackle * shape * 0.5 + ignition, 2.5, 0.3, 2000), 1.5))


def cruise_missile():
    """Booster kick, then a jet-engine whine flying away."""
    seconds = 4.5
    t = t_axis(seconds)
    booster = rocket(1.4, 300, 3500, ignition=0.9, rise=0.1)
    whine = (np.sin(sweep(seconds, 2400, 1600)) * 0.15 + filt(noise(seconds), "band", (500, 3000)) * 0.4)
    whine *= np.clip((t - 0.9) / 0.4, 0, 1) * np.exp(-0.6 * np.clip(t - 1.3, 0, None))
    return normalize(fade_out(reverb(mix(booster, whine), 1.4, 0.25, 4000), 1.0))


def aa_gun():
    """Anti-aircraft cannon (Shilka/Gepard/Tunguska): fast rattling bursts."""
    shot = gunshot(0.12, 700, 6000, 200, 0.06, 0.9)
    x = mix(burst(shot, 10, 0.055, 0.004), at(burst(shot, 10, 0.055, 0.004), 0.75, 1.6))
    return normalize(fade_out(reverb(x, 0.9, 0.25, 5000), 0.3))


def ciws():
    """Naval close-in weapon: one long tearing burst."""
    t = t_axis(1.6)
    x = filt(noise(1.6), "band", (300, 5000)) * (0.6 + 0.4 * signal.square(2 * np.pi * 70 * t))
    x *= np.clip(t / 0.02, 0, 1) * np.clip((1.2 - t) / 0.05, 0, 1)
    x += boom(1.6, 120, 60, 0.5, 0.4, 0.1)
    return normalize(fade_out(reverb(x, 1.2, 0.3, 4500), 0.3))


def jet_cannon():
    """Fighter gun pass: jet roar with a short 'brrrt'."""
    t = t_axis(1.0)
    gun = filt(noise(1.0), "band", (200, 4000)) * (0.5 + 0.5 * signal.square(2 * np.pi * 55 * t))
    gun *= np.clip(t / 0.01, 0, 1) * np.clip((0.7 - t) / 0.03, 0, 1)
    return normalize(fade_out(reverb(mix(jet_flyby(3.0) * 0.7, at(gun, 0.9, 3.0)), 1.2, 0.25, 3500), 0.5))


def bomber_strike():
    """Heavy bomber high overhead (slow, deep, four engines), then falling-bomb whistles."""
    seconds = 6.0
    t = t_axis(seconds)
    pass_ = flyover(seconds, speed=190.0, altitude=420.0, whine=620.0, rumble=1.6, bright=0.55, centre=0.4)
    # Four-engine beat: slightly detuned low harmonics give the throbbing drone.
    engines = sum(np.sin(2 * np.pi * f * t) for f in (58.0, 58.7, 87.0, 88.1)) * 0.06
    engines *= 1 / (1 + ((t - seconds * 0.4) / 1.8) ** 2)
    whistles = mix(*[at(np.sin(sweep(1.5, 2300 - i * 120, 700, "lin")) * env(1.5, 0.2, 2.0, 0.5) * 0.08, 2.6 + i * 0.35, seconds)
                     for i in range(4)])
    return normalize(fade_out(reverb(pass_ + engines + whistles, 1.8, 0.3, 3000), 0.8))


def helicopter_rockets():
    rotor = helicopter(3.0) * 0.6
    rockets = mix(*[at(rocket(1.0, 600, 5000, ignition=0.5, rise=0.05) * 0.5, 0.6 + i * 0.12, 3.0) for i in range(6)])
    return normalize(fade_out(reverb(mix(rotor, rockets), 1.2, 0.25, 4000), 0.5))


def kamikaze_drone():
    """Loitering munition: two-stroke 'moped' buzz growing louder (impact plays in game)."""
    seconds = 3.0
    t = t_axis(seconds)
    engine = signal.square(sweep(seconds, 95, 108, "lin")) * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * t))
    engine = filt(engine, "band", (80, 2500)) * np.clip(t / seconds, 0, 1) ** 1.5
    return normalize(fade_out(engine, 0.15))


def ship_missile():
    """Vertical launch from a ship: hatch thump, steam blast, missile roaring away."""
    hatch = boom(4.0, 110, 50, 0.6, 0.5, 0.2)
    steam = filt(noise(4.0), "high", 2500) * env(4.0, 0.01, 0.6) * 0.5
    motor = at(rocket(3.4, 350, 3500, ignition=0.6, rise=0.3), 0.15, 4.0)
    return normalize(fade_out(reverb(mix(hatch, steam, motor), 2.0, 0.3, 3500), 0.9))


def torpedo_launch():
    """Compressed-air launch, bubbles, then a fading propeller whine."""
    seconds = 4.0
    t = t_axis(seconds)
    thump = filt(boom(seconds, 70, 35, 0.8, 0.0, 0.4), "low", 400)
    bubbles = mix(*[at(np.sin(sweep(0.06, f, f * 1.6)) * env(0.06, 0.002, 0.05) * 0.2, RNG.uniform(0.1, 1.6), seconds)
                    for f in RNG.uniform(250, 900, 60)])
    whine = np.sin(sweep(seconds, 780, 760, "lin")) * 0.08 * np.clip((t - 0.5) / 0.5, 0, 1) * np.exp(-0.6 * t)
    return normalize(fade_out(mix(thump, bubbles, whine), 0.6))


def sonar_ping():
    x = mix(tone(1150, 2.8, decay=2.6) * 0.8, tone(2300, 1.0, decay=0.8) * 0.15)
    return normalize(reverb(x, 2.5, 0.5, 3000), -3)


def depth_explosion():
    """Underwater blast: muffled thud and a rush of bubbles."""
    x = filt(boom(4.0, 50, 22, 3.0, 0.0, 1.2), "low", 350)
    bubbles = filt(noise(4.0), "band", (200, 1200)) * env(4.0, 0.3, 3.5) * 0.4
    return normalize(fade_out(reverb(x + bubbles, 2.0, 0.3, 1500), 0.8))


def carrier_launch():
    """Catapult shot: steam hiss, jet at full power racing off the deck."""
    seconds = 4.0
    t = t_axis(seconds)
    steam = filt(noise(seconds), "high", 2000) * env(seconds, 0.005, 0.8) * 0.6
    jet = jet_flyby(seconds) * np.clip(t / 0.3, 0, 1)
    slam = boom(seconds, 120, 60, 0.6, 0.7, 0.2) * 0.6
    return normalize(fade_out(reverb(mix(steam, jet, slam), 1.4, 0.25, 3500), 0.8))


SFX = {
    "nuclear_alarm": nuclear_alarm,
    "tracks_moving": tracks_moving, "wheels_moving": wheels_moving, "march": march,
    "jet_flyby": jet_flyby, "bomb_whistle": bomb_whistle, "nuclear_blast": nuclear_blast,
    "tank_cannon": tank_cannon, "autocannon": autocannon, "artillery": artillery, "naval_gun": naval_gun,
    "missile_launch": missile_launch, "interceptor": interceptor, "air_strike": air_strike,
    "drone_strike": drone_strike,
    "helicopter": helicopter, "explosion_small": explosion_small, "explosion_large": explosion_large,
    "ui_click": ui_click, "war_declared": war_declared, "victory": victory, "defeat": defeat,
    "build_complete": build_complete, "research_complete": research_complete, "city_captured": city_captured,
    "rifle_fire": rifle_fire, "sniper_shot": sniper_shot, "mortar_fire": mortar_fire, "atgm_launch": atgm_launch,
    "heavy_machine_gun": heavy_machine_gun, "mlrs_salvo": mlrs_salvo, "ballistic_missile": ballistic_missile,
    "cruise_missile": cruise_missile, "aa_gun": aa_gun, "ciws": ciws, "jet_cannon": jet_cannon,
    "bomber_strike": bomber_strike, "helicopter_rockets": helicopter_rockets, "kamikaze_drone": kamikaze_drone,
    "ship_missile": ship_missile, "torpedo_launch": torpedo_launch, "sonar_ping": sonar_ping,
    "depth_explosion": depth_explosion, "carrier_launch": carrier_launch,
}
MUSIC = {"menu_theme": menu_theme, "battle_theme": campaign_theme}


def main():
    out = sys.argv[1]
    os.makedirs(os.path.join(out, "sfx"), exist_ok=True)
    os.makedirs(os.path.join(out, "music"), exist_ok=True)
    for name, make in SFX.items():
        write_ogg(make(), os.path.join(out, "sfx", name + ".ogg"))
        print("sfx", name)
    for name, make in MUSIC.items():
        write_ogg(make(), os.path.join(out, "music", name + ".ogg"), quality=3)
        print("music", name)


if __name__ == "__main__":
    main()

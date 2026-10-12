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


def jet_flyby(seconds=3.2):
    """Jet passing over: filtered roar with a doppler sweep, loud in the middle."""
    t = t_axis(seconds)
    center = seconds * 0.45
    loud = 1 / (1 + ((t - center) / (seconds * 0.16)) ** 2)
    base = noise(seconds)
    # Doppler: the whine falls as the jet passes.
    whine = np.sin(sweep(seconds, 1400, 700, "lin")) * 0.12
    roar = filt(base, "band", (150, 2500)) + 0.6 * filt(base, "low", 160)
    return roar * loud + whine * loud


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
    """Air-raid siren rising and falling twice, with a drum hit."""
    seconds = 3.6
    t = t_axis(seconds)
    f = 300 + 380 * (0.5 - 0.5 * np.cos(2 * np.pi * t / 1.8))
    siren = signal.square(2 * np.pi * np.cumsum(f) / SR) * 0.25 + np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4
    siren = filt(siren, "low", 2400) * np.clip(t / 0.2, 0, 1) * np.clip((seconds - t) / 0.6, 0, 1)
    hit = boom(seconds, 90, 40, 1.4, 0.6, 0.5)
    return normalize(reverb(siren + hit, 1.6, 0.3, 3000))


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
    """Heavy bomber drone overhead, then falling-bomb whistles (impacts play in game)."""
    seconds = 5.0
    t = t_axis(seconds)
    engines = sum(signal.sawtooth(2 * np.pi * f * t) for f in (61, 62.3, 91.5))
    engines = filt(engines, "low", 700) * 0.25 + filt(noise(seconds), "low", 300) * 0.5
    loud = 1 / (1 + ((t - 2.0) / 1.4) ** 2)
    whistles = mix(*[at(np.sin(sweep(1.5, 2300 - i * 120, 700, "lin")) * env(1.5, 0.2, 2.0, 0.5) * 0.1, 2.0 + i * 0.35, seconds)
                     for i in range(4)])
    return normalize(fade_out(reverb(engines * loud + whistles, 1.6, 0.3, 3000), 0.8))


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
MUSIC = {"menu_theme": menu_theme, "battle_theme": battle_theme}


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

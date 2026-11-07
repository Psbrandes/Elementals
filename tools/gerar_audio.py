#!/usr/bin/env python3
"""Gera a música e os efeitos sonoros originais do Elementals (chiptune sintetizado).

Tudo aqui é composto e sintetizado do zero por este script, sem amostras de terceiros,
então os arquivos gerados são originais do projeto (CC0).

Uso: python3 tools/gerar_audio.py <pasta assets/audio>
Precisa de numpy e do ffmpeg (com libvorbis) no PATH.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
RNG = np.random.default_rng(7)
NOTE_INDEX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """'C#4' -> número MIDI. '-' é pausa (None)."""
    if name in ("-", "", None):
        return None
    letter = name[0]
    rest = name[1:]
    shift = 0
    while rest and rest[0] in "#b":
        shift += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + NOTE_INDEX[letter] + shift


def freq(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# --- Osciladores --------------------------------------------------------------

def osc(kind, f, n, duty=0.5, phase0=0.0):
    t = np.arange(n) / SR
    if np.ndim(f) == 0:
        phase = phase0 + f * t
    else:
        phase = phase0 + np.cumsum(f) / SR
    p = phase % 1.0
    if kind == "square":
        return np.where(p < duty, 1.0, -1.0)
    if kind == "tri":
        # Triângulo em 16 degraus, como nos consoles de 8 bits.
        tri = 4.0 * np.abs(p - 0.5) - 1.0
        return np.round(tri * 7.5) / 7.5
    if kind == "saw":
        return 2.0 * p - 1.0
    if kind == "sine":
        return np.sin(2 * np.pi * p)
    raise ValueError(kind)


def noise(n, period=1):
    """Ruído com 'tom': repete cada amostra `period` vezes (mais grave quanto maior)."""
    base = RNG.uniform(-1, 1, n // period + 2)
    return np.repeat(base, period)[:n]


def env(n, a=0.005, d=0.05, s=0.6, r=0.05, gate=None):
    """ADSR em segundos. `gate` é a duração segurada (padrão: tudo menos o release)."""
    a_n = max(int(a * SR), 1)
    d_n = max(int(d * SR), 1)
    r_n = max(int(r * SR), 1)
    gate_n = n - r_n if gate is None else min(int(gate * SR), n)
    e = np.full(n, s, dtype=float)
    e[: min(a_n, n)] = np.linspace(0, 1, a_n)[: min(a_n, n)]
    if a_n < n:
        end = min(a_n + d_n, n)
        e[a_n:end] = np.linspace(1, s, d_n)[: end - a_n]
    if gate_n < n:
        level = e[max(gate_n - 1, 0)]
        e[gate_n:] = level * np.linspace(1, 0, n - gate_n)
    return e


def exp_decay(n, seconds):
    return np.exp(-np.arange(n) / (seconds * SR))


# --- Instrumentos -------------------------------------------------------------

def inst_note(inst, m, dur, vol):
    """Uma nota de `dur` segundos. Devolve o som com um release curto depois de dur."""
    f = freq(m)
    if inst == "lead":
        n = int((dur + 0.08) * SR)
        t = np.arange(n) / SR
        vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
        w = osc("square", f * vib, n, 0.25)
        return w * env(n, 0.004, 0.08, 0.7, 0.08, gate=dur) * vol
    if inst == "lead2":
        n = int((dur + 0.08) * SR)
        w = osc("square", f, n, 0.5)
        return w * env(n, 0.004, 0.1, 0.55, 0.08, gate=dur) * vol
    if inst == "pluck":
        n = int((dur + 0.05) * SR)
        w = osc("square", f, n, 0.125)
        return w * env(n, 0.002, 0.0, 1.0, 0.05, gate=dur) * exp_decay(n, 0.12) * vol
    if inst == "bass":
        n = int((dur + 0.03) * SR)
        w = osc("tri", f, n)
        return w * env(n, 0.002, 0.03, 0.9, 0.03, gate=dur) * vol
    if inst == "brass":
        # Duas quadradas levemente desafinadas: soa mais cheio na fanfarra.
        n = int((dur + 0.12) * SR)
        w = 0.5 * osc("square", f * 1.003, n, 0.5) + 0.5 * osc("square", f * 0.997, n, 0.25)
        return w * env(n, 0.01, 0.1, 0.75, 0.12, gate=dur) * vol
    if inst == "bell":
        n = int((dur + 0.6) * SR)
        w = osc("sine", f, n) + 0.4 * osc("sine", f * 2.0, n) + 0.15 * osc("sine", f * 3.01, n)
        return w * exp_decay(n, 0.35 + dur * 0.4) * env(n, 0.002, 0, 1, 0.05) * vol
    raise ValueError(inst)


def drum(kind, vol=1.0):
    if kind == "kick":
        n = int(0.18 * SR)
        f = 150 * np.exp(-np.arange(n) / (0.03 * SR)) + 45
        return osc("sine", f, n) * exp_decay(n, 0.07) * vol
    if kind == "snare":
        n = int(0.16 * SR)
        body = osc("tri", 190, n) * exp_decay(n, 0.03)
        return (0.8 * noise(n, 2) * exp_decay(n, 0.05) + 0.5 * body) * vol
    if kind == "hat":
        n = int(0.05 * SR)
        return noise(n, 1) * exp_decay(n, 0.012) * vol
    if kind == "ohat":
        n = int(0.2 * SR)
        return noise(n, 1) * exp_decay(n, 0.06) * vol
    if kind == "crash":
        n = int(1.4 * SR)
        return noise(n, 1) * exp_decay(n, 0.45) * vol
    if kind == "tom":
        n = int(0.2 * SR)
        f = 220 * np.exp(-np.arange(n) / (0.08 * SR)) + 90
        return osc("tri", f, n) * exp_decay(n, 0.08) * vol
    raise ValueError(kind)


# --- Mixagem ------------------------------------------------------------------

class Track:
    def __init__(self, bpm, beats, tail=1.0):
        self.spb = 60.0 / bpm
        self.length = int(round(beats * self.spb * SR))
        self.buf = np.zeros(self.length + int(tail * SR))

    def add(self, wave_, at_beat):
        start = int(round(at_beat * self.spb * SR))
        end = min(start + len(wave_), len(self.buf))
        if start < len(self.buf):
            self.buf[start:end] += wave_[: end - start]

    def seq(self, inst, notes, start=0.0, vol=0.3, gap=0.9):
        """`notes`: lista de (nome, batidas). Nome '-' é pausa; 'C4+E4' toca as duas juntas."""
        beat = start
        for name, beats in notes:
            for part in name.split("+"):
                m = midi(part)
                if m is not None:
                    self.add(inst_note(inst, m, beats * self.spb * gap, vol), beat)
            beat += beats
        return beat

    def drums(self, pattern, start, bars, step=0.25, vols=None):
        """`pattern`: dict tipo -> string de 16 passos ('x' toca)."""
        vols = vols or {}
        for bar in range(bars):
            for kind, steps in pattern.items():
                for i, ch in enumerate(steps):
                    if ch == "x":
                        self.add(drum(kind, vols.get(kind, 0.5)), start + bar * len(steps) * step + i * step)

    def echo(self, delay_beats=0.75, feedback=0.25, mix=0.22):
        d = int(delay_beats * self.spb * SR)
        out = self.buf.copy()
        tap = self.buf.copy()
        for _ in range(4):
            tap = np.concatenate([np.zeros(d), tap[:-d]]) * feedback
            out += tap * (mix / feedback)
        self.buf = out

    def render(self, loop):
        out = self.buf
        if loop:
            # O rabo depois do fim volta para o começo: o loop emenda sem corte.
            body = out[: self.length].copy()
            tail = out[self.length:]
            body[: len(tail)] += tail[: self.length]
            out = body
        return out


def finish(x, peak=0.89):
    x = np.tanh(x * 1.1)
    x = x - np.mean(x)
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def write_ogg(path, x, quality=5):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a",
                    str(quality), path], check=True)
    os.unlink(wav_path)


# --- Músicas ------------------------------------------------------------------

def chord_tones(root, kind):
    r = midi(root)
    third = 3 if kind == "m" else 4
    return [r, r + third, r + 7]


def name_of(m):
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return f"{names[m % 12]}{m // 12 - 1}"


def music_vitoria():
    """Fanfarra de vitória (~7 s, sem loop), em dó maior."""
    t = Track(bpm=144, beats=16, tail=2.0)
    third = 1.0 / 3.0
    lead = [("G4", third), ("A4", third), ("B4", third), ("C5", 1), ("E5", 0.5), ("G5", 0.5),
            ("C6", 1.5), ("-", 0.5), ("A5", 0.5), ("G5", 0.5), ("F5", 0.5), ("A5", 0.5),
            ("G5", 1), ("E5", 0.5), ("C5", 0.5), ("D5", 0.5), ("E5", 0.5), ("F5", 0.5), ("D5", 0.5),
            ("C5+E5+G5+C6", 5)]
    harm = [("-", 1), ("E4", 1), ("G4", 1), ("E5", 1.5), ("-", 0.5), ("F5", 1), ("C5", 1),
            ("E5", 1), ("G4", 1), ("B4", 1), ("G4", 1)]
    t.seq("brass", lead, 0, 0.32)
    t.seq("lead2", harm, 0, 0.13)
    bass = [("-", 1), ("C3", 1), ("C3", 1), ("C3", 1), ("C2", 1), ("F2", 1), ("F2", 1), ("A2", 1),
            ("C3", 1), ("G2", 1), ("G2", 1), ("B2", 1), ("C3", 4)]
    t.seq("bass", bass, 0, 0.5, gap=0.8)
    for b in (1, 3, 5, 7, 9, 11):
        t.add(drum("kick", 0.7), b)
    for b in (2, 4, 6, 8, 10):
        t.add(drum("snare", 0.45), b)
    # Rufo antes do acorde final.
    for i in range(8):
        t.add(drum("snare", 0.18 + 0.04 * i), 11 + i * 0.125)
    t.add(drum("kick", 0.9), 12)
    t.add(drum("crash", 0.35), 12)
    t.echo(0.75, 0.3, 0.18)
    return finish(t.render(loop=False)[: int(10 * SR)])


def music_resultado():
    """Loop calmo para a tela de vitória, em dó maior, 8 compassos."""
    t = Track(bpm=104, beats=32, tail=1.5)
    prog = [("C3", "M"), ("A2", "m"), ("F2", "M"), ("G2", "M"), ("C3", "M"), ("E2", "m"), ("F2", "M"), ("G2", "M")]
    for bar, (root, kind) in enumerate(prog):
        tones = chord_tones(root, kind)
        t.seq("bass", [(name_of(tones[0]), 1.5), (name_of(tones[0] + 12), 0.5), (name_of(tones[2]), 1),
                       (name_of(tones[0] + 12), 1)], bar * 4, 0.45, gap=0.8)
        arp = [tones[0] + 24, tones[1] + 24, tones[2] + 24, tones[1] + 24] * 4
        t.seq("pluck", [(name_of(m), 0.25) for m in arp], bar * 4, 0.12)
    melody = [("E5", 1.5), ("G5", 0.5), ("C6", 1), ("B5", 1), ("A5", 1.5), ("G5", 0.5), ("E5", 2),
              ("F5", 1), ("A5", 1), ("C6", 1), ("A5", 1), ("G5", 3), ("-", 1),
              ("E5", 1.5), ("G5", 0.5), ("C6", 1), ("D6", 1), ("B5", 1.5), ("G5", 0.5), ("E5", 2),
              ("F5", 1), ("E5", 1), ("D5", 1), ("F5", 1), ("C5+E5", 3), ("-", 1)]
    t.seq("lead", melody, 0, 0.2)
    t.drums({"kick": "x-------x-------", "snare": "----x-------x---", "hat": "x-x-x-x-x-x-x-x-"}, 0, 8,
            vols={"kick": 0.5, "snare": 0.25, "hat": 0.12})
    t.echo(0.75, 0.3, 0.2)
    return finish(t.render(loop=True), 0.85)


def music_selecao():
    """Loop animado para a escolha de herói, em lá menor, 16 compassos."""
    t = Track(bpm=132, beats=64, tail=1.5)
    prog = [("A2", "m"), ("F2", "M"), ("C3", "M"), ("G2", "M"), ("A2", "m"), ("F2", "M"), ("G2", "M"), ("E2", "M")]
    for half in range(2):
        for bar, (root, kind) in enumerate(prog):
            at = (half * 8 + bar) * 4
            tones = chord_tones(root, kind)
            r = tones[0]
            line = [r, r + 12, r, r + 12, r, r + 12, tones[2], r + 12]
            t.seq("bass", [(name_of(m), 0.5) for m in line], at, 0.5, gap=0.7)
            arp = [tones[0] + 24, tones[2] + 24, tones[1] + 24, tones[2] + 24] * 4
            t.seq("pluck", [(name_of(m), 0.25) for m in arp], at, 0.1)
    a = [("A4", 0.5), ("C5", 0.5), ("E5", 1), ("D5", 0.5), ("C5", 0.5), ("D5", 1),
         ("C5", 0.5), ("A4", 0.5), ("F5", 1.5), ("E5", 0.5), ("C5", 1),
         ("E5", 0.5), ("G5", 0.5), ("E5", 1), ("C5", 0.5), ("E5", 0.5), ("G5", 1),
         ("D5", 0.5), ("B4", 0.5), ("D5", 1), ("G4", 2)]
    b = [("A4", 0.5), ("C5", 0.5), ("E5", 1), ("A5", 1), ("G5", 1),
         ("F5", 0.5), ("E5", 0.5), ("C5", 1), ("A4", 1), ("C5", 1),
         ("D5", 0.5), ("E5", 0.5), ("F5", 1), ("G5", 1), ("D5", 1),
         ("E5", 1), ("G#5", 1), ("B5", 2)]
    end = t.seq("lead", a, 0, 0.19)
    end = t.seq("lead", b, end, 0.19)
    end = t.seq("lead", a, end, 0.19)
    b2 = b[:-3] + [("E5", 1), ("G#5", 0.5), ("B5", 0.5), ("A5", 2)]
    t.seq("lead", b2, end, 0.19)
    t.drums({"kick": "x-----x-x-------", "snare": "----x-------x---", "hat": "x-x-x-x-x-x-x-xx"}, 0, 16,
            vols={"kick": 0.6, "snare": 0.35, "hat": 0.12})
    t.add(drum("crash", 0.25), 0)
    t.add(drum("crash", 0.25), 32)
    t.echo(0.5, 0.25, 0.15)
    return finish(t.render(loop=True), 0.85)


# --- Efeitos ------------------------------------------------------------------

def sweep(kind, f0, f1, seconds, duty=0.5, curve="exp"):
    n = int(seconds * SR)
    x = np.linspace(0, 1, n)
    f = f0 * (f1 / f0) ** x if curve == "exp" else f0 + (f1 - f0) * x
    return osc(kind, f, n, duty)


def notes_fx(seq, inst="pluck", vol=0.5, step=0.06, ring=0.12):
    n = int((len(seq) * step + ring + 0.3) * SR)
    out = np.zeros(n)
    for i, name in enumerate(seq):
        w = inst_note(inst, midi(name), ring, vol)
        s = int(i * step * SR)
        out[s: s + len(w)] += w[: n - s]
    return out


def trim(x):
    idx = np.where(np.abs(x) > 0.002)[0]
    return x[: idx[-1] + 1] if len(idx) else x


def sfx_all():
    fx = {}
    # Esquiva: sopro de ar que desce.
    n = int(0.22 * SR)
    hp = noise(n, 1) - 0.6 * noise(n, 3)
    fx["dodge"] = hp * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.6 + 0.15 * sweep("tri", 900, 300, 0.22) * exp_decay(n, 0.08)
    # Agarrão: dois baques curtos de pano.
    n = int(0.12 * SR)
    grab = noise(n, 6) * exp_decay(n, 0.02) * 0.7 + osc("tri", 120, n) * exp_decay(n, 0.03) * 0.5
    fx["grab"] = np.concatenate([grab, np.zeros(int(0.03 * SR)), grab * 0.6])
    # Arremesso: subida rápida de ar e tom.
    n = int(0.28 * SR)
    fx["throw"] = (noise(n, 2) * np.linspace(0.1, 1, n) * exp_decay(n, 0.2) * 0.5
                   + sweep("square", 200, 700, 0.28, 0.25) * exp_decay(n, 0.12) * 0.25)
    # Pouso: baque grave com poeira.
    n = int(0.14 * SR)
    fx["land"] = osc("sine", 70 * np.exp(-np.arange(n) / (0.05 * SR)) + 40, n) * exp_decay(n, 0.05) * 0.8 + noise(n, 4) * exp_decay(n, 0.02) * 0.25
    # Nota de estilo subindo: arpejo brilhante.
    fx["rank_up"] = notes_fx(["E5", "G5", "C6", "E6"], "pluck", 0.5, 0.045, 0.15)
    # Aviso "!" do inimigo: dois bipes agudos.
    n = int(0.06 * SR)
    beep = osc("square", 1568, n, 0.5) * env(n, 0.002, 0.01, 0.8, 0.01)
    fx["alert"] = np.concatenate([beep, np.zeros(int(0.03 * SR)), beep]) * 0.35
    # Chefe chegando: sirene grave que sobe e desce com rufo.
    n = int(1.6 * SR)
    tt = np.arange(n) / SR
    f = 110 + 50 * np.sin(2 * np.pi * 1.25 * tt)
    siren = 0.5 * osc("saw", f, n) + 0.4 * osc("square", f * 1.5, n, 0.5)
    rumble = noise(n, 30) * 0.6
    fx["boss_intro"] = (siren * 0.45 + rumble * 0.4) * env(n, 0.05, 0.1, 0.9, 0.5) * 0.9
    # Vida extra: escala ascendente de 1-UP.
    fx["extra_life"] = notes_fx(["E5", "G5", "E6", "C6", "D6", "G6"], "lead2", 0.35, 0.07, 0.1)
    # "GO!": dois tons subindo.
    fx["go"] = notes_fx(["G5", "D6"], "lead2", 0.3, 0.09, 0.12)
    # Bloqueio: tinido metálico.
    n = int(0.3 * SR)
    clink = sum(osc("sine", f, n) * exp_decay(n, d) for f, d in ((2200, 0.08), (3170, 0.05), (4630, 0.03)))
    fx["block"] = (clink * 0.3 + noise(n, 1) * exp_decay(n, 0.006) * 0.4) * 0.8
    # Contra-ataque: estalo seco e tom agudo descendo.
    n = int(0.25 * SR)
    fx["counter"] = noise(n, 1) * exp_decay(n, 0.015) * 0.6 + sweep("square", 1400, 500, 0.25, 0.25) * exp_decay(n, 0.07) * 0.3
    # Golpe carregado pronto: brilho que sobe.
    n = int(0.3 * SR)
    fx["charge_ready"] = sweep("sine", 600, 1800, 0.3) * env(n, 0.01, 0.05, 0.7, 0.12) * 0.4 + sweep("square", 1200, 3600, 0.3, 0.125) * env(n, 0.01, 0.05, 0.5, 0.12) * 0.1
    # Contagem da tela de vitória: tique curto, e o fim da contagem.
    n = int(0.035 * SR)
    fx["tally"] = osc("square", 1760, n, 0.25) * exp_decay(n, 0.01) * 0.3
    fx["tally_end"] = notes_fx(["C6", "G6"], "bell", 0.45, 0.06, 0.2)
    # Nota final da fase: carimbo grave com prato.
    n = int(0.8 * SR)
    stamp = osc("sine", 90 * np.exp(-np.arange(n) / (0.08 * SR)) + 50, n) * exp_decay(n, 0.12)
    fx["stamp"] = stamp * 0.9 + noise(n, 1) * exp_decay(n, 0.25) * 0.2 + notes_fx(["C5"], "bell", 0.3, 0.1, 0.5)[:n]
    # Menu: abrir e fechar a pausa / opções.
    fx["menu_open"] = notes_fx(["C5", "G5"], "pluck", 0.4, 0.04, 0.08)
    fx["menu_close"] = notes_fx(["G5", "C5"], "pluck", 0.4, 0.04, 0.08)
    return {k: finish(trim(v), 0.8) for k, v in fx.items()}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
    music_dir = os.path.join(out, "music")
    sfx_dir = os.path.join(out, "sfx")
    os.makedirs(music_dir, exist_ok=True)
    os.makedirs(sfx_dir, exist_ok=True)
    write_ogg(os.path.join(music_dir, "vitoria.ogg"), music_vitoria())
    write_ogg(os.path.join(music_dir, "resultado.ogg"), music_resultado())
    write_ogg(os.path.join(music_dir, "selecao.ogg"), music_selecao())
    for name, x in sfx_all().items():
        write_ogg(os.path.join(sfx_dir, name + ".ogg"), x, 4)
    print("ok")


if __name__ == "__main__":
    main()

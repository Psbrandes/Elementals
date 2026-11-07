"""Gera a arte dos 4 cenários elementais (Terra, Deserto, Natureza, Vulcão).

Arte original, toda feita em código (sem pacote de terceiros):
    python3 tools/gerar_cenarios.py            # gera assets/scenery/biomas/<bioma>/
    python3 tools/gerar_cenarios.py vulcao     # só um bioma

Cada bioma tem:
    bg_1.png  céu (opaco)            bg_2..bg_4.png  camadas de fundo, da mais longe à mais perto
    chao.png  textura do chão (emenda nos 4 lados)
    props/*.png  objetos em pé no chão (fileira de trás, fileira funda, frente)
    barril.png / caixa.png  os quebráveis da fase com a cara do bioma

As sementes são fixas: rodar de novo gera exatamente as mesmas imagens.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from pixel import (Mask, bayer, clumps, col, dome, fbm, flat, lathe, mix, noise, outline, over, pad, pal, ramp,
                   save, shade, specks, trim, voronoi_edges, wave)

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "scenery", "biomas")
BG_W, BG_H = 960, 360
FLOOR = 256


def rng_for(name):
    return np.random.default_rng(abs(hash_str(name)) % (2 ** 32))


def hash_str(s):
    h = 2166136261
    for ch in s.encode():
        h = ((h ^ ch) * 16777619) % (2 ** 32)
    return h


def finish(rgba, line):
    return outline(pad(rgba, 1), col(line))


# =============================================================================
# Peças genéricas (formas que vários biomas reaproveitam com outra paleta)
# =============================================================================

def rock(w, h, palette, line, rng, jag=0.18, bump=0.6, cracks=None):
    m = Mask(w, h)
    n = rng.integers(7, 11)
    pts = []
    for i in range(n):
        a = math.pi + i / (n - 1) * math.pi  # de 180 a 360 graus: só a metade de cima
        r = 1 - rng.random() * jag
        pts.append(((w - 1) / 2 + math.cos(a) * (w - 1) / 2 * r,
                    (h - 1) - math.sin(-a) * (h - 1) * r * (0.85 + 0.15 * rng.random())))
    pts = [(0, h - 1)] + pts + [(w - 1, h - 1)]
    m.poly(pts)
    mask = m.get()
    b = fbm(w, h, max(2, w // 8), max(2, h // 8), rng, 3)
    rgba = shade(mask, palette, bump=b, bump_amt=bump, ambient=0.2)
    if cracks is not None:
        _cracks(rgba, mask, cracks, rng, 2)
    return finish(rgba, line)


def _cracks(rgba, mask, color, rng, count, length=None, glow=None):
    h, w = mask.shape
    for _ in range(count):
        ys, xs = np.where(mask)
        if len(xs) == 0:
            return
        k = rng.integers(len(xs))
        x, y = xs[k], ys[k]
        steps = length or int(rng.integers(max(3, h // 4), max(5, h // 2)))
        dx = rng.choice([-1, 1])
        for _ in range(steps):
            if 0 <= x < w and 0 <= y < h and mask[y, x]:
                rgba[y, x] = color
                if glow is not None:
                    for nx, ny in ((x + 1, y), (x - 1, y)):
                        if 0 <= nx < w and mask[y, nx] and rng.random() < 0.5:
                            rgba[y, nx] = glow
            y += 1 if rng.random() < 0.7 else 0
            x += dx if rng.random() < 0.6 else 0
            if rng.random() < 0.15:
                dx = -dx


def blob(w, h, palette, line, rng, lumps=7, bump=1.2, base_w=0.9, specks_col=None, density=0.0):
    """Moita/arbusto/copa: união de círculos com folhagem em relevo."""
    m = Mask(w, h)
    m.ellipse((1 - base_w) * w / 2, h * 0.35, w - (1 - base_w) * w / 2, h - 1)
    for _ in range(lumps):
        r = rng.uniform(0.18, 0.32) * min(w, h * 1.6)
        cx = rng.uniform(r, w - r)
        cy = rng.uniform(r, h - r * 0.6)
        m.circle(cx, cy, r)
    mask = m.get()
    leaf = clumps(w, h, rng, r=max(2.5, min(w, h) / 9))
    rgba = shade(mask, palette, bump=leaf, bump_amt=bump * 0.3, ambient=0.15, soft=0.4)
    if specks_col is not None:
        top = dome(mask) > 0.35
        specks(rgba, mask & top, specks_col, density, rng)
    return finish(rgba, line)


def crystal_cluster(w, h, faces, line, rng, count=5, glow=None):
    """Prismas pontudos em leque; cada um com face clara (esq.) e escura (dir.)."""
    out = np.zeros((h, w, 4), np.uint8)
    order = sorted(range(count), key=lambda i: abs(i - (count - 1) / 2), reverse=True)
    for i in order:
        u = (i + 0.5) / count
        lean = (u - 0.5) * 1.1
        width = w * rng.uniform(0.18, 0.28)
        tall = h * (1 - abs(u - 0.5) * 1.1) * rng.uniform(0.75, 1.0)
        bx = w * (0.15 + 0.7 * u)
        by = h - 1
        tx = bx + lean * tall * 0.6
        ty = by - tall
        perp = (width / 2, 0)
        mid = ((bx + tx) / 2, (by + ty) / 2 + tall * 0.12)
        left = [(bx - perp[0], by), (tx - perp[0] * 0.55, ty + tall * 0.22), (tx, ty), (mid[0], by)]
        right = [(mid[0], by), (tx, ty), (tx + perp[0] * 0.55, ty + tall * 0.22), (bx + perp[0], by)]
        ml = Mask(w, h).poly(left).get()
        mr = Mask(w, h).poly(right).get()
        t = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
        cl = ramp(0.55 + 0.45 * t, faces)
        cr = ramp(0.1 + 0.4 * t, faces)
        layer = np.zeros_like(out)
        layer[ml] = cl[ml]
        layer[mr] = cr[mr]
        # Brilho na aresta.
        edge = Mask(w, h).line([(tx, ty), (mid[0] - 1, by - 2)], 1).get() & ml
        layer[edge] = faces[-1]
        over(out, layer)
    if glow is not None:
        base = Mask(w, h).ellipse(w * 0.1, h - 4, w * 0.9, h + 3).get()
        out[base & (out[..., 3] == 0)] = glow
    return finish(out, line)


def column(w, h, palette, line, rng, broken=True, flutes=True):
    m = Mask(w, h)
    cap = max(3, h // 12)
    m.rect(0, h - cap, w - 1, h - 1)                       # base
    m.rect(w * 0.12, cap, w * 0.88 - 1, h - cap)           # fuste
    top = cap
    if broken:
        pts = [(w * 0.12, h * 0.25)]
        for i in range(6):
            pts.append((w * 0.12 + (i + 1) * w * 0.76 / 6, h * rng.uniform(0.05, 0.3)))
        pts += [(w * 0.88, h - cap), (w * 0.12, h - cap)]
        m.img.paste(0, (0, 0, w, int(h * 0.3)))
        m.poly(pts)
    else:
        m.rect(0, 0, w - 1, top)
    mask = m.get()
    rgba = shade(mask, palette, cyl=True, ambient=0.25)
    if flutes:
        for x in range(int(w * 0.12) + 3, int(w * 0.88) - 2, 3):
            stripe = np.zeros_like(mask)
            stripe[int(h * 0.15):h - cap - 1, x] = True
            rgba[stripe & mask] = palette[max(0, 1)]
    _cracks(rgba, mask, palette[0], rng, 2)
    return finish(rgba, line)


def amphora(neck, belly):
    """Perfil de jarro: boca com aba, pescoço, barriga e base."""
    def prof(t):
        if t < 0.08:
            return neck + 1.5
        s_ = (t - 0.08) / 0.92
        return neck + (belly - neck) * math.sin(math.pi * min(1.0, s_ * 0.85 + 0.04)) ** 0.7
    return prof


def lathe_obj(w, h, profile, palette, line, bands=(), band_col=None, cracks=None, rng=None):
    mask = lathe(w, h, profile)
    rgba = shade(mask, palette, cyl=True, ambient=0.2)
    for y0, y1 in bands:
        for y in range(int(y0 * h), int(y1 * h) + 1):
            row = mask[y]
            rgba[y][row] = band_col if not callable(band_col) else band_col(y)
    if cracks is not None:
        _cracks(rgba, mask, cracks, rng, 2)
    return finish(rgba, line)


def crate(w, h, wood, line, rng, metal=None, brace=True, planks=3):
    """Caixa de frente com um pouco do tampo aparecendo."""
    top = max(3, h // 6)
    out = np.zeros((h, w, 4), np.uint8)
    face = np.zeros((h, w), bool)
    face[top:, :] = True
    lid = Mask(w, h).poly([(2, top), (w - 1, top), (w - 3, 0), (4, 0)]).get() & ~face
    t = np.ones((h, w)) * 0.55
    xs = np.arange(w)[None, :] / w
    t = t + 0.15 * (1 - xs)
    gr = noise(w, h, 2, max(2, h // 2), rng) * 0.25
    out[face] = ramp(np.clip(t + gr - 0.1, 0, 1), wood)[face]
    out[lid] = ramp(np.full((h, w), 0.85), wood)[lid]
    ph = (h - top) / planks
    for i in range(1, planks):
        out[int(top + i * ph), :] = wood[0]
    frame = np.zeros((h, w), bool)
    frame[top:, :2] = frame[top:, -2:] = True
    frame[top:top + 2, :] = frame[-2:, :] = True
    out[frame] = metal if metal is not None else wood[1]
    if brace:
        b = Mask(w, h).line([(2, h - 3), (w - 3, top + 2)], 2).get()
        out[b] = metal if metal is not None else wood[2]
    return finish(out, line)


def dead_tree(w, h, palette, line, rng, trunk_w=None, embers=None):
    m = Mask(w, h)
    tw = trunk_w or max(4, w // 7)
    base_x = w / 2

    def branch(x, y, ang, length, width, depth):
        if depth == 0 or length < 3:
            return
        x2 = x + math.cos(ang) * length
        y2 = y - math.sin(ang) * length
        m.line([(x, y), (x2, y2)], max(1, int(width)))
        for s in (-1, 1):
            if rng.random() < 0.85:
                branch(x2, y2, ang + s * rng.uniform(0.35, 0.8), length * rng.uniform(0.55, 0.75),
                       width * 0.62, depth - 1)

    m.poly([(base_x - tw * 1.2, h - 1), (base_x + tw * 1.2, h - 1), (base_x + tw / 2, h * 0.55),
            (base_x - tw / 2, h * 0.55)])
    branch(base_x, h * 0.56, math.pi / 2 + rng.uniform(-0.15, 0.15), h * 0.3, tw, 5)
    mask = m.get()
    rgba = shade(mask, palette, cyl=False, ambient=0.25, radius=3, soft=0.5)
    if embers is not None:
        _cracks(rgba, mask, embers[0], rng, 3, glow=embers[1])
    return finish(rgba, line)


def tuft(w, h, palette, line, rng, blades=7, flowers=None):
    m = Mask(w, h)
    for i in range(blades):
        x = rng.uniform(1, w - 2)
        lean = rng.uniform(-w * 0.3, w * 0.3)
        tip = (x + lean, rng.uniform(0, h * 0.4))
        m.poly([(x - 1.5, h - 1), (x + 1.5, h - 1), tip])
    mask = m.get()
    t = np.linspace(1, 0.2, h)[:, None] * np.ones((1, w))
    rgba = ramp(t, palette)
    rgba[~mask] = 0
    rgba = rgba.copy()
    if flowers is not None:
        for _ in range(rng.integers(2, 4)):
            ys, xs = np.where(mask[: h // 2])
            if len(xs):
                k = rng.integers(len(xs))
                y, x = ys[k], xs[k]
                rgba[max(0, y - 1):y + 1, max(0, x - 1):x + 1] = flowers
    return finish(rgba, line)


def pebbles(w, h, palette, line, rng, count=4):
    out = np.zeros((h, w, 4), np.uint8)
    for _ in range(count):
        pw = rng.integers(3, max(4, w // 2))
        ph = rng.integers(2, max(3, h - 1))
        m = Mask(pw, ph).ellipse(0, 0, pw - 1, ph - 1).get()
        s = shade(m, palette, ambient=0.25, soft=0.3)
        over(out, s, int(rng.integers(0, max(1, w - pw))), h - ph)
    return finish(out, line)


def bones(w, h, bone, line, rng):
    out = np.zeros((h, w, 4), np.uint8)
    for _ in range(2):
        m = Mask(w, h)
        y = rng.uniform(h * 0.4, h - 3)
        x0, x1 = rng.uniform(2, w * 0.3), rng.uniform(w * 0.7, w - 3)
        y2 = y + rng.uniform(-h * 0.3, h * 0.3)
        y2 = min(max(2, y2), h - 3)
        m.line([(x0, y), (x1, y2)], 2)
        for (px, py) in ((x0, y), (x1, y2)):
            m.circle(px - 1, py - 1, 1.6)
            m.circle(px + 1, py + 1, 1.6)
        over(out, shade(m.get(), bone, ambient=0.4, soft=0.3))
    return finish(out, line)


def skull(w, h, bone, line, rng, horns=True):
    m = Mask(w, h)
    m.ellipse(w * 0.22, h * 0.2, w * 0.78, h * 0.8)
    m.poly([(w * 0.3, h * 0.6), (w * 0.7, h * 0.6), (w * 0.6, h - 1), (w * 0.4, h - 1)])
    if horns:
        m.line([(w * 0.28, h * 0.32), (w * 0.08, h * 0.2), (w * 0.02, h * 0.02)], 3)
        m.line([(w * 0.72, h * 0.32), (w * 0.92, h * 0.2), (w * 0.98, h * 0.02)], 3)
    mask = m.get()
    rgba = shade(mask, bone, ambient=0.35, soft=0.6)
    dark = bone[0]
    for ex in (0.38, 0.62):
        e = Mask(w, h).ellipse(w * ex - w * 0.08, h * 0.42, w * ex + w * 0.08, h * 0.56).get()
        rgba[e & mask] = dark
    nose = Mask(w, h).poly([(w * 0.47, h * 0.66), (w * 0.53, h * 0.66), (w * 0.5, h * 0.74)]).get()
    rgba[nose & mask] = dark
    return finish(rgba, line)


# =============================================================================
# Fundos (céu + 3 camadas). Todos emendam na horizontal.
# =============================================================================

def sky(top, bottom, stops=None, w=BG_W, h=BG_H, span=(170, 312)):
    """Gradiente vertical com faixas pontilhadas. A câmera só vê o céu perto do
    horizonte (linhas ~270-300 da camada 1), então o degradê fica em `span`."""
    colors = stops or [top, bottom]
    palette = pal(*colors)
    t = np.clip((np.arange(h) - span[0]) / (span[1] - span[0]), 0, 1)[:, None] * np.ones((1, w))
    return ramp(t, palette).copy()


def clouds(img, rng, color_light, color_shade, count, y_range, size=(40, 90), flat_bottom=True):
    h, w = img.shape[:2]
    for _ in range(count):
        cw = int(rng.uniform(*size))
        ch = int(cw * rng.uniform(0.3, 0.45))
        m = Mask(cw, ch)
        for _ in range(6):
            r = min(rng.uniform(0.18, 0.3) * cw, ch * 0.6)
            m.circle(rng.uniform(r, cw - r), rng.uniform(min(r * 0.6, ch * 0.5), ch * 0.6), r * 0.75)
        m.ellipse(0, ch * 0.45, cw - 1, ch - 1)
        mask = m.get()
        if flat_bottom:
            mask[int(ch * 0.85):] = False
        c = shade(mask, pal(color_shade, color_light), ambient=0.45, soft=1.0)
        x = int(rng.uniform(0, w))
        y = int(rng.uniform(*y_range))
        for dx in (0, -w):   # emenda: desenha também do outro lado
            over(img, c, x + dx, y)
    return img


def ridge(w, h, heights, palette, lit=None, rng=None, strata=None, haze=0.0, ox=0):
    """Silhueta preenchida abaixo de heights(x); luz nas encostas que sobem."""
    img = np.zeros((h, w, 4), np.uint8)
    yy = np.arange(h)[:, None]
    top = heights[None, :]
    mask = yy >= top
    depth = np.clip((yy - top) / (h - top + 1e-6), 0, 1)
    t = 1 - depth * 0.7
    if strata is not None:
        t = t + 0.18 * np.sin(yy / strata[0] * 2 * math.pi + strata[1] * noise(w, h, 6, 4, rng) * 6) * strata[2]
    slope = np.roll(heights, -2) - np.roll(heights, 2)
    face = np.clip(-slope / 6, -1, 1)[None, :]     # >0 quando a encosta "olha" para a esquerda (luz)
    near_top = np.clip(1 - (yy - top) / 40, 0, 1)
    t = t * 0.75 + face * 0.25 * (0.4 + 0.6 * near_top)
    if lit is not None:
        t = t + lit
    t = np.clip(t - haze, 0, 1)
    img[mask] = ramp(t, palette, ox)[mask]
    return img


def layer_trees(w, h, base_y, palette, line, rng, count, r_range, trunk=None):
    """Linha de copas redondas (floresta vista de longe)."""
    m = Mask(w, h)
    heights = []
    for i in range(count):
        x = (i + rng.uniform(0, 0.8)) * w / count
        r = rng.uniform(*r_range)
        y = base_y - rng.uniform(0, r * 1.2)
        for dx in (0, w, -w):
            m.circle(x + dx, y, r)
            m.circle(x + dx - r * 0.6, y + r * 0.4, r * 0.75)
            m.circle(x + dx + r * 0.6, y + r * 0.35, r * 0.7)
        heights.append((x, y, r))
    m.rect(0, base_y, w, h)
    mask = m.get()
    leaf = clumps(w, h, rng, r=4.5)
    rgba = shade(mask, palette, bump=leaf, bump_amt=0.45, ambient=0.2, radius=14, soft=0.4)
    return outline(rgba, col(line))


# =============================================================================
# NATUREZA: floresta antiga, musgo, cogumelos e flores
# =============================================================================

def natureza(out, rng):
    LINE = "1b2a1a"
    leaf = pal("1f4d2b", "2e6b34", "4a8f3a", "79b84a", "b8de6a")
    leaf_dark = pal("173a26", "22512e", "356f35", "52923f", "7fb655")
    bark = pal("3a2618", "553624", "74503a", "9a7050", "c0946a")
    moss_rock = pal("2f3a3a", "4a5752", "6b7a6c", "8fa07f", "b4c88f")
    red_cap = pal("6e1f22", "a8322e", "d6513f", "f08a62")
    cream = pal("8c7a62", "c2ae8e", "e8d8b8", "fff4dc")

    # --- Céu
    s = sky(None, None, ["3d7fd0", "5a98dd", "7cb2e6", "a5cdee", "d2e9f4"])
    clouds(s, rng, "ffffff", "c8dcef", 9, (238, 282), (40, 90))
    save(s, f"{out}/bg_1.png")
    # --- Morros azulados ao longe
    hgt = 150 + wave(BG_W, [(1, 30), (2, 18), (5, 8), (11, 3)], rng)
    save(ridge(BG_W, BG_H, hgt, pal("4d7e8e", "5f93a0", "77a8ae", "94bfbc"), rng=rng), f"{out}/bg_2.png")
    # --- Floresta média
    save(layer_trees(BG_W, BG_H, 170, pal("1d4a3a", "2a5e40", "3b7546", "56904e"), "163828", rng, 26, (14, 26)),
         f"{out}/bg_3.png")
    # --- Bosque perto: troncos grossos e copas
    w, h = BG_W, BG_H
    img = np.zeros((h, w, 4), np.uint8)
    for i in range(7):
        x = int((i + rng.uniform(0.1, 0.6)) * w / 7)
        tw = int(rng.uniform(14, 24))
        m = Mask(w, h).poly([(x - tw * 0.8, h), (x + tw * 0.8, h), (x + tw / 2, 60), (x - tw / 2, 60)]).get()
        over(img, shade(m, pal("24170f", "3a2618", "553624", "74503a"), cyl=True, ambient=0.2))
    canopy = layer_trees(w, h, 120, leaf_dark, "112a1c", rng, 10, (26, 40))
    canopy[200:] = 0
    over(img, canopy)
    bush = layer_trees(w, h, 300, leaf, "17331e", rng, 22, (10, 18))
    over(img, bush)
    save(img, f"{out}/bg_4.png")

    # --- Chão: grama com trilha de terra
    r2 = np.random.default_rng(11)
    g = fbm(FLOOR, FLOOR, 4, 4, r2, 4)
    blades = r2.random((FLOOR, FLOOR))
    t = 0.35 + (g - 0.5) * 0.9 + (blades > 0.8) * 0.18 - (blades < 0.12) * 0.15
    grass = pal("2c5a26", "3b7430", "4e8c38", "68a443", "8bbd52")
    img = ramp(np.clip(t, 0, 1), grass).copy()
    dirt = fbm(FLOOR, FLOOR, 8, 8, r2, 3) > 0.64
    dirt_c = ramp(np.clip(0.4 + (g - 0.5), 0, 1), pal("5a4030", "74563f", "8e6e50", "a88a68"))
    img[dirt] = dirt_c[dirt]
    for c in ("f4f0e0", "f0c94a", "e86a8a"):
        f = (r2.random((FLOOR, FLOOR)) < 0.0025) & ~dirt
        img[f] = col(c)
    save(img, f"{out}/chao.png")

    # --- Objetos
    P = f"{out}/props"
    for i, (w_, h_) in enumerate([(44, 34), (38, 30), (54, 40)], 1):
        save(blob(w_, h_, leaf, LINE, rng, specks_col=col("f6e7a0"), density=0.0), f"{P}/moita{i}.png")
    save(blob(46, 34, leaf, LINE, rng, specks_col=col("f27a9a"), density=0.06), f"{P}/moita_flor1.png")
    save(blob(40, 30, leaf, LINE, rng, specks_col=col("fff2b0"), density=0.07), f"{P}/moita_flor2.png")
    for i, (w_, h_) in enumerate([(40, 28), (52, 34)], 1):
        save(rock(w_, h_, moss_rock, "1f2626", rng, bump=0.8), f"{P}/pedra_musgo{i}.png")
    save(_mushroom(22, 26, red_cap, cream, LINE, rng), f"{P}/cogumelo1.png")
    save(_mushroom(30, 22, pal("6a4a2a", "8e6838", "b48c4c", "d8b46c"), cream, LINE, rng), f"{P}/cogumelo2.png")
    save(_stump(36, 26, bark, pal("8e6a46", "b48a5e", "d6ae7c"), LINE, rng), f"{P}/toco.png")
    save(_log(60, 22, bark, pal("8e6a46", "b48a5e", "d6ae7c"), leaf, LINE, rng), f"{P}/tronco_caido.png")
    save(_fern(40, 34, leaf, LINE, rng), f"{P}/samambaia.png")
    for i, (w_, h_) in enumerate([(96, 140), (84, 120), (110, 150)], 1):
        save(_tree(w_, h_, bark, leaf, LINE, rng), f"{P}/arvore{i}.png")
    save(rock(90, 56, moss_rock, "1f2626", rng, bump=0.9), f"{P}/rochedo_musgo.png")
    save(blob(80, 54, leaf_dark, LINE, rng, lumps=10, specks_col=col("f27a9a"), density=0.02), f"{P}/moita_grande.png")
    for i in range(1, 4):
        save(tuft(18, 14, grass, LINE, rng, flowers=col(["f4f0e0", "f0c94a", "e86a8a"][i - 1])), f"{P}/grama{i}.png")
    save(pebbles(22, 8, moss_rock, "1f2626", rng), f"{P}/pedrinhas.png")
    save(_mushroom(12, 13, red_cap, cream, LINE, rng), f"{P}/cogumelo_peq.png")
    # Quebráveis: barril de madeira com cipó e caixa de madeira.
    save(_barrel(29, 41, bark, pal("3a4040", "5f6a6a", "8c9a96"), LINE, rng, vine=leaf), f"{out}/barril.png")
    save(crate(32, 26, pal("4a3020", "6e4a30", "93683f", "b88a58", "d8ad78"), LINE, rng), f"{out}/caixa.png")


def _mushroom(w, h, cap_pal, stem_pal, line, rng):
    out = np.zeros((h, w, 4), np.uint8)
    stem = Mask(w, h).poly([(w * 0.38, h - 1), (w * 0.62, h - 1), (w * 0.58, h * 0.45), (w * 0.42, h * 0.45)]).get()
    over(out, shade(stem, stem_pal, cyl=True, ambient=0.3))
    cap = Mask(w, h).ellipse(0, 0, w - 1, h * 0.95).get()
    cap[int(h * 0.52):] = False
    c = shade(cap, cap_pal, ambient=0.25)
    for _ in range(4):
        ys, xs = np.where(cap)
        k = rng.integers(len(xs))
        y, x = ys[k], xs[k]
        c[max(0, y - 1):y + 1, max(0, x - 1):x + 1][cap[max(0, y - 1):y + 1, max(0, x - 1):x + 1]] = stem_pal[-1]
    over(out, c)
    return finish(out, line)


def _stump(w, h, bark, wood, line, rng):
    body = Mask(w, h).poly([(0, h - 1), (w - 1, h - 1), (w * 0.85, h * 0.25), (w * 0.15, h * 0.25)]).get()
    out = shade(body, bark, cyl=True, ambient=0.2)
    for x in range(3, w - 3, 4):
        out[int(h * 0.35):h - 2, x][body[int(h * 0.35):h - 2, x]] = bark[0]
    top = Mask(w, h).ellipse(w * 0.15, h * 0.12, w * 0.85, h * 0.4).get()
    out[top] = wood[1]
    ring = Mask(w, h).ellipse(w * 0.3, h * 0.19, w * 0.7, h * 0.33).get() & ~Mask(w, h).ellipse(
        w * 0.36, h * 0.22, w * 0.64, h * 0.3).get()
    out[ring] = wood[0]
    return finish(out, line)


def _log(w, h, bark, wood, leaf, line, rng):
    body = Mask(w, h).rect(4, 2, w - 6, h - 1).get()
    t = np.zeros((h, w))
    for x in range(w):
        t[:, x] = np.sqrt(np.clip(1 - ((np.arange(h) - h / 2) / (h / 2)) ** 2, 0, 1))
    t = 0.25 + 0.75 * t * np.linspace(1, 0.6, h)[:, None]
    out = ramp(t, bark).copy()
    out[~body] = 0
    for y in range(4, h - 2, 4):
        out[y, 6:w - 8][body[y, 6:w - 8]] = bark[0]
    end = Mask(w, h).ellipse(w - 12, 1, w - 1, h - 1).get()
    out[end] = wood[1]
    out[Mask(w, h).ellipse(w - 9, 5, w - 4, h - 5).get()] = wood[0]
    out[Mask(w, h).ellipse(w - 8, 7, w - 5, h - 7).get()] = wood[2]
    moss = Mask(w, h).ellipse(8, 0, w * 0.6, 6).get()
    out[moss & body] = leaf[3]
    return finish(out, line)


def _fern(w, h, leaf, line, rng):
    m = Mask(w, h)
    for i in range(7):
        ang = math.pi * (0.12 + 0.76 * i / 6)
        length = h * rng.uniform(0.75, 1.0)
        pts = []
        for k in range(8):
            u = k / 7
            a = ang - (ang - math.pi / 2) * 0 + (0.5 if ang > math.pi / 2 else -0.5) * u * u
            pts.append((w / 2 + math.cos(a) * length * u, h - 1 - math.sin(a) * length * u))
        m.line(pts, 3)
        for k in range(1, 7):
            px, py = pts[k]
            m.line([(px, py), (px + rng.uniform(-3, 3), py - 3)], 1)
    mask = m.get()
    t = 0.3 + 0.7 * np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    out = ramp(t, leaf).copy()
    out[~mask] = 0
    return finish(out, line)


def _tree(w, h, bark, leaf, line, rng):
    out = np.zeros((h, w, 4), np.uint8)
    tw = w * 0.13
    trunk = Mask(w, h).poly([(w / 2 - tw * 1.6, h - 1), (w / 2 + tw * 1.6, h - 1), (w / 2 + tw * 0.8, h * 0.35),
                             (w / 2 - tw * 0.8, h * 0.35)])
    trunk.line([(w / 2, h * 0.5), (w * 0.25, h * 0.32)], int(tw * 0.7))
    trunk.line([(w / 2, h * 0.45), (w * 0.75, h * 0.28)], int(tw * 0.6))
    tm = trunk.get()
    tr = shade(tm, bark, cyl=True, ambient=0.2)
    for x in range(int(w / 2 - tw), int(w / 2 + tw), 3):
        col_ = tr[int(h * 0.55):h - 3, x]
        col_[tm[int(h * 0.55):h - 3, x]] = bark[1]
    over(out, tr)
    canopy = blob(w - 2, int(h * 0.62) - 2, leaf, "000000", rng, lumps=14, bump=1.6, base_w=1.0)
    canopy = canopy[1:-1, 1:-1]
    canopy[canopy[..., 0:3].sum(-1) == 0] = 0
    over(out, canopy, 1, 0)
    return finish(out, line)


def _barrel(w, h, wood, metal, line, rng, vine=None):
    def prof(t):
        return (w / 2 - 1) * (0.82 + 0.18 * math.sin(math.pi * t))
    mask = lathe(w, h, prof)
    out = shade(mask, wood, cyl=True, ambient=0.2)
    for x in range(2, w - 2, 5):
        out[:, x][mask[:, x]] = wood[1]
    for y0 in (3, h // 2 - 1, h - 6):
        for y in (y0, y0 + 1, y0 + 2):
            out[y][mask[y]] = ramp(np.linspace(1, 0.2, w)[None, :], metal)[0][mask[y]]
    if vine is not None:
        v = Mask(w, h).line([(w * 0.1, h * 0.1), (w * 0.4, h * 0.4), (w * 0.2, h * 0.7), (w * 0.5, h - 2)], 2).get()
        out[v & mask] = vine[2]
        specks(out, v & mask, vine[4], 0.3, rng)
    return finish(out, line)


# =============================================================================
# DESERTO: dunas, mesas, cactos, ossos e ruínas
# =============================================================================

def deserto(out, rng):
    LINE = "3a2216"
    sand = pal("9c6a3a", "c08a4a", "dcaa62", "ecc882", "f8e2a8")
    sandstone = pal("6e3a28", "945036", "b86c44", "d48e5a", "eab47a")
    cactus = pal("1f4a32", "2f6a3e", "4a8a46", "74ac58", "a4cc72")
    bone = pal("8a7a64", "b8a688", "dcceb0", "f6eedc")
    clay = pal("6a2e1e", "93432a", "b8613a", "d68650", "eeb07a")

    s = sky(None, None, ["3a7ccf", "5d9ad8", "8bb8dd", "c4d4c8", "f0dca6"])
    # Sol grande e baixo, com halo em faixas.
    yy, xx = np.mgrid[0:BG_H, 0:BG_W]
    for x0 in (700, 700 - BG_W):
        d = np.hypot(xx - x0, yy - 262)
        halo = (d < 30) & (d >= 18)
        s[halo & (bayer(BG_H, BG_W) < 0.5)] = col("f8ecc0")
        s[d < 18] = col("fff6d8")
        s[d < 14] = col("ffffff")
    clouds(s, rng, "fff4e0", "e8c8a8", 3, (240, 270), (50, 90))
    save(s, f"{out}/bg_1.png")
    # Mesas ao longe: alturas em degraus (topo reto, paredes íngremes).
    raw = 170 + wave(BG_W, [(2, 30), (3, 22), (7, 10)], rng)
    hgt = np.where(raw < 165, np.round(raw / 18) * 18 - 10, 205.0)
    hgt = np.minimum(hgt, 205)
    save(ridge(BG_W, BG_H, hgt, pal("b0705a", "c4876a", "d6a07e", "e6b994"), rng=rng,
               strata=(14, 0.3, 0.5)), f"{out}/bg_2.png")
    # Dunas do meio com ruínas.
    w, h = BG_W, BG_H
    hgt = 205 + wave(w, [(3, 16), (5, 9), (9, 4)], rng)
    img = ridge(w, h, hgt, pal("b47a46", "cc9656", "e0b26a", "f0cc88"), rng=rng)
    for i in range(3):
        x = int((i + rng.uniform(0.2, 0.6)) * w / 3)
        base = int(hgt[x % w])
        for k in range(rng.integers(2, 5)):
            pw, ph = 12, int(rng.uniform(30, 70))
            c = column(pw, ph, pal("8a5a3e", "a87250", "c48e66", "dcaa80"), "5a3424", rng, broken=rng.random() < 0.6)
            over(img, c, x + k * 22, base - ph + 6)
        lint = Mask(70, 8).rect(0, 0, 69, 7).get()
        if rng.random() < 0.6:
            over(img, outline(pad(shade(lint, pal("8a5a3e", "a87250", "c48e66")), 1), col("5a3424")), x - 4,
                 base - 70)
    save(img, f"{out}/bg_3.png")
    # Dunas perto com cactos em silhueta.
    hgt = 268 + wave(w, [(2, 14), (4, 8), (9, 3)], rng)
    img = ridge(w, h, hgt, pal("a46a3a", "c08446", "d8a05a", "eabd76"), rng=rng)
    for i in range(9):
        x = int((i + rng.uniform(0, 0.8)) * w / 9)
        c = _cactus(int(rng.uniform(22, 34)), int(rng.uniform(48, 74)), cactus, LINE, rng)
        over(img, c, x - c.shape[1] // 2, int(hgt[x % w]) - c.shape[0] + 8)
    save(img, f"{out}/bg_4.png")

    # Chão: areia com ondulações.
    r2 = np.random.default_rng(12)
    g = fbm(FLOOR, FLOOR, 4, 4, r2, 4)
    yy, xx = np.mgrid[0:FLOOR, 0:FLOOR]
    rip = np.sin((yy + g * 40 + xx * 0.0) / FLOOR * 2 * math.pi * 16)
    t = 0.55 + (g - 0.5) * 0.6 + rip * 0.12
    img = ramp(np.clip(t, 0, 1), sand).copy()
    for c in ("8a5a32", "b07a48"):
        f = r2.random((FLOOR, FLOOR)) < 0.002
        img[f] = col(c)
    save(img, f"{out}/chao.png")

    P = f"{out}/props"
    save(_cactus(30, 58, cactus, LINE, rng), f"{P}/cacto1.png")
    save(_cactus(26, 46, cactus, LINE, rng), f"{P}/cacto2.png")
    save(_barrel_cactus(26, 22, cactus, LINE, rng), f"{P}/cacto_bola.png")
    for i, (w_, h_) in enumerate([(44, 28), (34, 24), (56, 36)], 1):
        save(rock(w_, h_, sandstone, LINE, rng, bump=0.5, cracks=sandstone[0]), f"{P}/arenito{i}.png")
    save(skull(30, 24, bone, LINE, rng), f"{P}/cranio.png")
    save(bones(34, 14, bone, LINE, rng), f"{P}/ossos.png")
    save(_tumbleweed(26, 24, pal("6a4a2a", "8e6a3e", "b08c58"), LINE, rng), f"{P}/arbusto_seco.png")
    save(lathe_obj(22, 30, amphora(4, 10),
                   clay, LINE, bands=((0.35, 0.4),), band_col=col("f0dca0"), cracks=clay[0], rng=rng),
         f"{P}/jarro.png")
    save(column(16, 50, pal("8a5a3e", "b07a56", "d09a72", "e8be96"), LINE, rng), f"{P}/coluna_quebrada.png")
    save(column(18, 70, pal("8a5a3e", "b07a56", "d09a72", "e8be96"), LINE, rng, broken=False), f"{P}/coluna.png")
    # Fileira funda.
    save(rock(110, 70, sandstone, LINE, rng, jag=0.08, bump=0.4, cracks=sandstone[0]), f"{P}/rochedo.png")
    save(_palm(70, 120, pal("4a3020", "6e4a2e", "93683f", "b8905a"), cactus, LINE, rng), f"{P}/palmeira.png")
    save(_arch(96, 80, pal("7a4a32", "a06646", "c4865a", "e0aa7a"), LINE, rng), f"{P}/arco_ruina.png")
    save(_cactus(44, 96, cactus, LINE, rng), f"{P}/cacto_grande.png")
    # Frente.
    save(pebbles(20, 8, sandstone, LINE, rng), f"{P}/pedrinhas.png")
    save(tuft(16, 12, pal("6a5a2a", "8e7a3a", "b8a056", "dcc47a"), LINE, rng), f"{P}/capim_seco.png")
    save(bones(22, 10, bone, LINE, rng), f"{P}/ossinho.png")
    save(_barrel_cactus(14, 12, cactus, LINE, rng), f"{P}/cacto_peq.png")
    # Quebráveis: ânfora de barro e cesto de palha.
    save(lathe_obj(29, 41, amphora(6, 13.5),
                   clay, LINE, bands=((0.3, 0.34), (0.6, 0.64)), band_col=col("3a1a12"), cracks=clay[1], rng=rng),
         f"{out}/barril.png")
    save(_basket(32, 26, pal("6a4a22", "8e6a32", "b48e4a", "d6b06a", "eed08e"), LINE, rng), f"{out}/caixa.png")


def _cactus(w, h, palette, line, rng):
    m = Mask(w, h)
    bw = max(6, int(w * 0.32))
    cx = w / 2
    m.rect(cx - bw / 2, bw / 2, cx + bw / 2, h - 1).circle(cx, bw / 2, bw / 2)
    aw = max(4, int(bw * 0.7))
    for side in (-1, 1):
        if rng.random() < 0.85:
            ay = rng.uniform(h * 0.35, h * 0.6)
            ax = cx + side * (w / 2 - aw / 2 - 1)
            top = ay - rng.uniform(h * 0.15, h * 0.3)
            m.rect(min(cx, ax), ay - aw / 2, max(cx, ax), ay + aw / 2)
            m.rect(ax - aw / 2, top, ax + aw / 2, ay)
            m.circle(ax, top, aw / 2)
    mask = m.get()
    out = shade(mask, palette, ambient=0.2, radius=bw / 2, soft=0.7)
    for x in range(int(cx - bw / 2) + 2, int(cx + bw / 2) - 1, 3):
        out[bw // 2:h - 2, x][mask[bw // 2:h - 2, x]] = palette[1]
    specks(out, mask, col("f4ecc8"), 0.03, rng)
    return finish(out, line)


def _barrel_cactus(w, h, palette, line, rng):
    m = Mask(w, h).ellipse(0, 1, w - 1, h - 1).get()
    m[h - 1] = m[h - 2]
    out = shade(m, palette, ambient=0.2)
    for x in range(3, w - 2, 3):
        out[:, x][m[:, x]] = palette[1]
    fl = Mask(w, h).ellipse(w / 2 - 3, 0, w / 2 + 3, 4).get()
    out[fl] = col("e85a6a")
    specks(out, m, col("f4ecc8"), 0.05, rng)
    return finish(out, line)


def _tumbleweed(w, h, palette, line, rng):
    m = Mask(w, h)
    for _ in range(26):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.2, 0.5)
        pts = [(w / 2 + math.cos(a + k * 0.4) * w * r, h / 2 + math.sin(a + k * 0.4) * h * r) for k in range(4)]
        m.line(pts, 1)
    mask = m.get()
    t = 0.3 + 0.7 * np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    out = ramp(t, palette).copy()
    out[~mask] = 0
    return finish(out, line)


def _palm(w, h, trunk_pal, leaf, line, rng):
    out = np.zeros((h, w, 4), np.uint8)
    m = Mask(w, h)
    pts = [(w * 0.5 + math.sin(u * 1.6) * w * 0.12, h - 1 - u * h * 0.78) for u in np.linspace(0, 1, 12)]
    for i in range(len(pts) - 1):
        m.line([pts[i], pts[i + 1]], int(7 - i * 0.3))
    tm = m.get()
    tr = shade(tm, trunk_pal, ambient=0.25, radius=3)
    for y in range(int(h * 0.25), h, 4):
        tr[y][tm[y]] = trunk_pal[0]
    over(out, tr)
    top = pts[-1]
    f = Mask(w, h)
    for k in range(8):
        a = math.pi * (k / 7) * 1.1 - 0.05
        length = w * rng.uniform(0.4, 0.5)
        frond = []
        for u in np.linspace(0, 1, 8):
            frond.append((top[0] + math.cos(a) * length * u, top[1] - math.sin(a) * length * u * 0.6 + u * u * 26))
        f.line(frond, 4)
        for j in range(1, 8):
            px, py = frond[j]
            f.line([(px, py), (px + rng.uniform(-2, 2), py + 5)], 1)
    fm = f.get()
    fr = shade(fm, leaf, ambient=0.25, radius=2, soft=0.5)
    over(out, fr)
    return finish(out, line)


def _arch(w, h, palette, line, rng):
    m = Mask(w, h)
    pw = w * 0.2
    m.rect(0, h * 0.2, pw, h - 1).rect(w - pw, h * 0.32, w - 1, h - 1)
    m.ellipse(0, 0, w - 1, h * 0.75)
    m.ellipse(pw, h * 0.18, w - pw, h * 1.35, v=0)
    m.rect(pw + 1, h * 0.55, w - pw - 1, h, v=0)
    m.poly([(w * 0.55, 0), (w, 0), (w, h * 0.36), (w * 0.8, h * 0.3), (w * 0.7, h * 0.1)], v=0)
    mask = m.get()
    out = shade(mask, palette, ambient=0.25, radius=8, bump=fbm(w, h, 8, 8, rng, 3), bump_amt=0.4)
    for y in range(6, h, 9):
        out[y][mask[y]] = palette[1]
    _cracks(out, mask, palette[0], rng, 4)
    return finish(out, line)


def _basket(w, h, palette, line, rng):
    m = Mask(w, h).poly([(2, 3), (w - 3, 3), (w - 5, h - 1), (4, h - 1)]).get()
    yy, xx = np.mgrid[0:h, 0:w]
    weave = ((xx // 3 + yy // 2) % 2) * 0.2
    t = 0.35 + weave + (1 - xx / w) * 0.25
    out = ramp(np.clip(t, 0, 1), palette).copy()
    out[~m] = 0
    rim = Mask(w, h).ellipse(1, 0, w - 2, 6).get()
    out[rim] = palette[3]
    out[Mask(w, h).ellipse(4, 1, w - 5, 4).get()] = palette[0]
    for y in (h // 2, h - 4):
        out[y][m[y]] = palette[1]
    return finish(out, line)


# =============================================================================
# TERRA: cânion de pedra, estratos, cristais de âmbar e mina
# =============================================================================

def terra(out, rng):
    LINE = "2a1a12"
    stone = pal("3e2e26", "5a4436", "7a5e48", "9a7c5e", "bea07a")
    gray = pal("2e2c2e", "45423f", "5e5a54", "7a746a", "99907f")
    amber = pal("4a1a06", "7a3410", "b85a14", "e89a30", "ffd878")
    wood = pal("3a2616", "5a3c22", "7a5632", "9e7646", "c49a62")
    iron = pal("2a2a30", "44444c", "666670", "8c8c96")

    s = sky(None, None, ["5a6ea0", "7d8fb4", "a8a8bc", "d4b8a8", "eec8a0"])
    clouds(s, rng, "f4e0d0", "c8a8a8", 7, (240, 280), (50, 100))
    save(s, f"{out}/bg_1.png")
    hgt = 140 + wave(BG_W, [(1, 26), (3, 22), (7, 12), (17, 5), (31, 2)], rng)
    save(ridge(BG_W, BG_H, hgt, pal("6e6070", "857282", "9e8a92", "b8a4a4"), rng=rng), f"{out}/bg_2.png")
    # Paredões do cânion com estratos.
    raw = 185 + wave(BG_W, [(2, 26), (5, 16), (11, 6)], rng)
    hgt = np.round(raw / 10) * 10
    save(ridge(BG_W, BG_H, hgt, pal("6a3e2e", "8a5038", "a86a44", "c48a58", "dca878"), rng=rng,
               strata=(9, 0.4, 1.0)), f"{out}/bg_3.png")
    # Perto: pilares de pedra (chaminés) e morros com pedras.
    w, h = BG_W, BG_H
    hgt = 296 + wave(w, [(3, 12), (7, 7), (13, 4), (29, 2)], rng)
    img = ridge(w, h, hgt, pal("5a4030", "74543e", "8e6a4e", "a8845e", "c09c72"), rng=rng, strata=(6, 0.3, 0.8))
    for i in range(5):
        x = int((i + rng.uniform(0.1, 0.7)) * w / 5)
        c = _hoodoo(int(rng.uniform(26, 38)), int(rng.uniform(90, 140)), stone, LINE, rng)
        over(img, c, x - c.shape[1] // 2, int(hgt[x % w]) - c.shape[0] + 10)
    for i in range(26):
        x = int(rng.uniform(0, w))
        c = rock(int(rng.uniform(20, 46)), int(rng.uniform(14, 30)), stone, LINE, rng)
        over(img, c, x - c.shape[1] // 2, int(hgt[x % w]) - c.shape[0] + 6)
    save(img, f"{out}/bg_4.png")

    # Chão: terra batida com rachaduras.
    r2 = np.random.default_rng(13)
    g = fbm(FLOOR, FLOOR, 4, 4, r2, 4)
    edge, f1 = voronoi_edges(FLOOR, FLOOR, 22, r2)
    t = 0.55 + (g - 0.5) * 0.7 - np.clip(f1 / 40, 0, 0.15)
    img = ramp(np.clip(t, 0, 1), pal("5a3e2c", "74523a", "8e6a4a", "a8845e", "c09c72")).copy()
    img[edge < 1.4] = col("3e2a1e")
    img[(edge >= 1.4) & (edge < 2.4)] = col("a8845e")
    for c in ("bea07a", "5a4436", "e08a2a"):
        f = r2.random((FLOOR, FLOOR)) < (0.002 if c != "e08a2a" else 0.0006)
        img[f] = col(c)
    save(img, f"{out}/chao.png")

    P = f"{out}/props"
    for i, (w_, h_) in enumerate([(40, 30), (52, 38), (32, 24), (46, 42)], 1):
        save(rock(w_, h_, stone if i % 2 else gray, LINE, rng, jag=0.25, cracks=stone[0]), f"{P}/pedra{i}.png")
    save(_cairn(28, 44, gray, LINE, rng), f"{P}/pilha_pedras.png")
    save(crystal_cluster(30, 34, amber, "4a1e08", rng, 4), f"{P}/ambar1.png")
    save(crystal_cluster(22, 26, amber, "4a1e08", rng, 3), f"{P}/ambar2.png")
    save(_stalagmite(18, 46, stone, LINE, rng), f"{P}/estalagmite1.png")
    save(_stalagmite(14, 34, gray, LINE, rng), f"{P}/estalagmite2.png")
    save(_minecart(44, 34, iron, stone, amber, LINE, rng), f"{P}/carrinho_mina.png")
    save(_support(46, 56, wood, LINE, rng), f"{P}/escora.png")
    # Fileira funda.
    save(_hoodoo(40, 120, stone, LINE, rng), f"{P}/chamine1.png")
    save(_hoodoo(34, 96, gray, LINE, rng), f"{P}/chamine2.png")
    save(_menhir(30, 84, gray, LINE, rng), f"{P}/menir.png")
    save(rock(100, 64, stone, LINE, rng, jag=0.2, cracks=stone[0]), f"{P}/rochedo.png")
    save(crystal_cluster(50, 64, amber, "4a1e08", rng, 5), f"{P}/ambar_grande.png")
    # Frente.
    save(pebbles(22, 8, stone, LINE, rng), f"{P}/pedrinhas1.png")
    save(pebbles(18, 7, gray, LINE, rng), f"{P}/pedrinhas2.png")
    save(crystal_cluster(12, 14, amber, "4a1e08", rng, 3), f"{P}/ambar_peq.png")
    save(_root(30, 10, wood, LINE, rng), f"{P}/raiz.png")
    # Quebráveis: urna de pedra e caixa de mina.
    save(lathe_obj(29, 41, amphora(8, 13.5),
                   gray, LINE, bands=((0.25, 0.3), (0.7, 0.74)), band_col=col("e08a2a"), cracks=gray[0], rng=rng),
         f"{out}/barril.png")
    save(crate(32, 26, wood, LINE, rng, metal=iron[2]), f"{out}/caixa.png")


def _hoodoo(w, h, palette, line, rng):
    m = Mask(w, h)
    segs = rng.integers(3, 5)
    y = h - 1
    for i in range(segs):
        sh = (h - w * 0.5) / segs
        bw = w * (0.85 - 0.5 * i / segs) * rng.uniform(0.85, 1.0)
        tw = bw * rng.uniform(0.6, 0.85)
        m.poly([(w / 2 - bw / 2, y), (w / 2 + bw / 2, y), (w / 2 + tw / 2, y - sh), (w / 2 - tw / 2, y - sh)])
        m.ellipse(w / 2 - tw / 2 - 2, y - sh - 3, w / 2 + tw / 2 + 2, y - sh + 3)
        y -= sh
    m.ellipse(0, y - w * 0.3, w - 1, y + w * 0.12)   # pedra-chapéu
    mask = m.get()
    out = shade(mask, palette, cyl=True, ambient=0.2)
    for yy in range(4, h, 6):
        out[yy][mask[yy]] = mix(out[yy][mask[yy]], palette[0], 0.5)
    _cracks(out, mask, palette[0], rng, 3)
    return finish(out, line)


def _cairn(w, h, palette, line, rng):
    out = np.zeros((h, w, 4), np.uint8)
    y = h
    sizes = [(w, 12), (w * 0.8, 10), (w * 0.62, 9), (w * 0.48, 8), (w * 0.34, 7)]
    for sw, sh in sizes:
        m = Mask(int(sw), sh).ellipse(0, 0, int(sw) - 1, sh - 1).get()
        s = shade(m, palette, ambient=0.25, soft=0.5)
        s = outline(pad(s, 1), col(line))
        y -= sh - 1
        over(out, s, int((w - sw) / 2) - 1 + int(rng.integers(-1, 2)), y - 1)
    return finish(out, line)


def _stalagmite(w, h, palette, line, rng):
    m = Mask(w, h).poly([(0, h - 1), (w - 1, h - 1), (w * 0.62, h * 0.3), (w * 0.52, 0), (w * 0.4, h * 0.35)]).get()
    out = shade(m, palette, cyl=True, ambient=0.2)
    for y in range(3, h, 5):
        out[y][m[y]] = mix(out[y][m[y]], palette[0], 0.4)
    return finish(out, line)


def _minecart(w, h, iron, stone, amber, line, rng):
    out = np.zeros((h, w, 4), np.uint8)
    ore = np.zeros((h, w, 4), np.uint8)
    for _ in range(7):
        r = rng.uniform(4, 7)
        x = rng.uniform(w * 0.2, w * 0.8)
        m = Mask(w, h).circle(x, h * 0.3, r).get()
        over(ore, shade(m, stone if rng.random() < 0.7 else amber, ambient=0.3, soft=0.4))
    over(out, ore)
    body = Mask(w, h).poly([(0, h * 0.3), (w - 1, h * 0.3), (w * 0.88, h * 0.82), (w * 0.12, h * 0.82)]).get()
    b = shade(body, iron, ambient=0.25, radius=4)
    for x in (int(w * 0.33), int(w * 0.66)):
        b[:, x][body[:, x]] = iron[0]
    b[int(h * 0.3):int(h * 0.3) + 2][body[int(h * 0.3):int(h * 0.3) + 2]] = iron[3]
    over(out, b)
    for wx in (w * 0.26, w * 0.74):
        wm = Mask(w, h).circle(wx, h * 0.84, h * 0.15).get()
        over(out, shade(wm, iron, ambient=0.25, soft=0.3))
        out[int(h * 0.84), int(wx)] = iron[3]
    return finish(out, line)


def _support(w, h, wood, line, rng):
    m = Mask(w, h)
    m.rect(3, 6, 9, h - 1).rect(w - 10, 6, w - 4, h - 1).rect(0, 0, w - 1, 7)
    m.line([(9, 18), (18, 7)], 3).line([(w - 10, 18), (w - 19, 7)], 3)
    mask = m.get()
    out = shade(mask, wood, ambient=0.25, radius=3)
    noise_ = noise(w, h, 2, 12, rng)
    out[(noise_ > 0.75) & mask] = wood[1]
    return finish(out, line)


def _menhir(w, h, palette, line, rng):
    m = Mask(w, h).poly([(w * 0.1, h - 1), (w * 0.9, h - 1), (w * 0.85, h * 0.2), (w * 0.6, 0), (w * 0.25, h * 0.08),
                         (w * 0.15, h * 0.3)]).get()
    out = shade(m, palette, ambient=0.2, bump=fbm(w, h, 4, 8, rng, 3), bump_amt=0.5)
    # Espiral gravada (símbolo da terra).
    cx, cy = w * 0.5, h * 0.45
    pts = [(cx + math.cos(a) * a * 1.1, cy + math.sin(a) * a * 1.1) for a in np.linspace(0, 4 * math.pi, 40)]
    sp = Mask(w, h).line(pts, 1).get() & m
    out[sp] = col("e08a2a")
    return finish(out, line)


def _root(w, h, wood, line, rng):
    m = Mask(w, h)
    m.line([(0, h - 2), (w * 0.3, h * 0.4), (w * 0.6, h * 0.6), (w - 1, h - 2)], 3)
    m.line([(w * 0.3, h * 0.4), (w * 0.4, 0)], 2)
    mask = m.get()
    return finish(shade(mask, wood, ambient=0.3, radius=2, soft=0.4), line)


# =============================================================================
# VULCÃO: céu de cinzas, vulcão em erupção, basalto, obsidiana e lava
# =============================================================================

def vulcao(out, rng):
    LINE = "120808"
    basalt = pal("141016", "221c22", "342a2e", "4a3c3c", "64504a")
    obsidian = pal("0e0a16", "1e1430", "35224e", "5a3c7a", "a07ac8")
    lava = pal("6a0e08", "b8220e", "ee5a14", "ffa424", "ffe68a")
    char = pal("0e0a0a", "1e1614", "302420", "463630")
    ash = pal("2a2224", "3e3436", "564a4a", "746664")

    s = sky(None, None, ["120a12", "24101a", "40141a", "6a1e16", "a8381a", "d8622a"])
    clouds(s, rng, "4a2a2a", "2a1818", 12, (236, 286), (50, 110))
    sp = np.random.default_rng(5).random((BG_H, BG_W))
    s[sp < 0.002] = col("ffb050")
    s[(sp > 0.996)] = col("ff7a30")
    save(s, f"{out}/bg_1.png")
    w, h = BG_W, BG_H
    x = np.arange(w)
    # Cordilheira ao longe com dois vulcões pequenos de ponta acesa.
    hgt = 282 + wave(w, [(3, 8), (7, 4), (19, 2)], rng)
    for cx in (200, 690):
        d = np.minimum(np.abs(x - cx), w - np.abs(x - cx))
        hgt = np.minimum(hgt, 244 + np.maximum(d, 6) * 0.9)
    img = ridge(w, h, hgt, pal("2a1620", "3a1c24", "4c2428", "62302c"), rng=rng)
    for cx in (200, 690):
        img[Mask(w, h).ellipse(cx - 6, 247, cx + 6, 251).get()] = lava[3]
        for k in range(30):
            yy = 250 + k
            img[yy, cx + int(math.sin(k * 0.5) * 2 + k * 0.4)] = lava[2] if k < 18 else lava[1]
    save(img, f"{out}/bg_2.png")
    # O vulcão grande (um por painel), com lava descendo e a boca acesa.
    hgt = 300 + wave(w, [(4, 6), (9, 4), (21, 2)], rng)
    cx = 480
    d = np.abs(x - cx)
    cone = 206 + np.maximum(d - 14, 0) * 0.85 + np.where(d < 14, -2 + (d / 14) ** 2 * 2, 0)
    cone = cone + wave(w, [(40, 1.5), (73, 1)], rng)
    hgt = np.minimum(hgt, cone)
    img = ridge(w, h, hgt, pal("140c10", "201418", "2e1c1e", "422626", "583430"), rng=rng)
    img[Mask(w, h).ellipse(cx - 13, 202, cx + 13, 209).get()] = lava[3]
    img[Mask(w, h).ellipse(cx - 8, 203, cx + 8, 207).get()] = lava[4]
    for side, start in ((-1, -6), (1, 5), (1, -1)):
        px, py = cx + start, 208.0
        for k in range(110):
            if py >= h:
                break
            c = lava[4] if k < 15 else lava[3] if k < 50 else lava[2]
            img[int(py), int(px)] = c
            img[int(py), int(px) + 1] = lava[2]
            if k > 40:
                img[int(py), int(px) - 1] = lava[1]
            py += 1
            px += side * (0.45 + 0.6 * rng.random()) + (rng.random() - 0.5) * 0.8
    # Fagulhas saindo da boca.
    for k in range(40):
        ex = int(cx + rng.normal(0, 9))
        ey = int(rng.uniform(190, 204))
        img[ey, ex] = lava[4] if k % 3 else lava[3]
    # Cachoeiras de lava em penhascos baixos dos lados.
    for fx in (120, 830):
        top = int(hgt[fx]) + 2
        for y in range(top, h):
            wv = 1 + (y - top) // 14
            for dx in range(-wv, wv + 1):
                t = abs(dx) / (wv + 1)
                img[y, (fx + dx) % w] = lava[4] if t < 0.3 else lava[3] if t < 0.6 else lava[2]
    save(img, f"{out}/bg_3.png")
    # Perto: espinhos de obsidiana, chão escuro e poças de lava.
    hgt = 304 + wave(w, [(3, 8), (8, 5), (17, 3)], rng)
    img = ridge(w, h, hgt, pal("100a0e", "1c1216", "2a1c1e", "3a2826"), rng=rng)
    for i in range(9):
        x0 = int((i + rng.uniform(0, 0.9)) * w / 9)
        c = _spire(int(rng.uniform(16, 28)), int(rng.uniform(40, 120)), obsidian, LINE, rng)
        over(img, c, x0 - c.shape[1] // 2, int(hgt[x0 % w]) - c.shape[0] + 10)
    for i in range(12):
        x0 = int(rng.uniform(0, w))
        c = _lava_rock(int(rng.uniform(20, 40)), int(rng.uniform(14, 24)), basalt, lava, LINE, rng)
        over(img, c, x0 - c.shape[1] // 2, int(hgt[x0 % w]) - c.shape[0] + 6)
    for i in range(7):
        px = rng.uniform(0, w)
        pw = rng.uniform(30, 70)
        py = rng.uniform(326, 340)
        for dx in (0, -w, w):
            outer = Mask(w, h).ellipse(px + dx - pw / 2, py - 4, px + dx + pw / 2, py + 4).get() & (img[..., 3] > 0)
            inner = Mask(w, h).ellipse(px + dx - pw / 2 + 4, py - 2, px + dx + pw / 2 - 4, py + 2).get()
            img[outer] = lava[1]
            img[outer & inner] = lava[3]
    save(img, f"{out}/bg_4.png")

    # Chão: basalto com veios de lava.
    r2 = np.random.default_rng(14)
    g = fbm(FLOOR, FLOOR, 4, 4, r2, 4)
    edge, f1 = voronoi_edges(FLOOR, FLOOR, 16, r2)
    t = 0.45 + (g - 0.5) * 0.8 - np.clip(f1 / 60, 0, 0.2)
    img = ramp(np.clip(t, 0, 1), pal("161014", "221a1e", "30262a", "403234", "524240")).copy()
    hot = fbm(FLOOR, FLOOR, 3, 3, r2, 2) > 0.47
    img[edge < 1.2] = col("120c0c")
    img[(edge < 1.6) & hot] = lava[2]
    img[(edge < 0.8) & hot] = lava[4]
    img[(edge >= 1.6) & (edge < 2.6) & hot] = lava[0]
    f = r2.random((FLOOR, FLOOR)) < 0.0015
    img[f] = lava[3]
    save(img, f"{out}/chao.png")

    P = f"{out}/props"
    for i, (w_, h_) in enumerate([(40, 30), (50, 36), (32, 24)], 1):
        save(_lava_rock(w_, h_, basalt, lava, LINE, rng), f"{P}/pedra_lava{i}.png")
    save(crystal_cluster(30, 40, obsidian, "08060e", rng, 4), f"{P}/obsidiana1.png")
    save(crystal_cluster(24, 30, obsidian, "08060e", rng, 3), f"{P}/obsidiana2.png")
    save(crystal_cluster(26, 32, lava, "3a0604", rng, 4, glow=lava[1]), f"{P}/cristal_magma.png")
    save(dead_tree(40, 60, char, LINE, rng, embers=(lava[2], lava[3])), f"{P}/arvore_queimada.png")
    save(_vent(40, 40, basalt, lava, ash, LINE, rng), f"{P}/fumarola.png")
    save(skull(26, 22, pal("4a3a34", "746058", "a08a7a", "c8b4a0"), LINE, rng), f"{P}/cranio.png")
    # Fileira funda.
    save(_basalt_columns(80, 100, basalt, LINE, rng), f"{P}/colunas_basalto.png")
    save(_spire(36, 120, obsidian, LINE, rng), f"{P}/espinho_obsidiana.png")
    save(dead_tree(90, 130, char, LINE, rng, trunk_w=10, embers=(lava[2], lava[3])), f"{P}/arvore_morta_grande.png")
    save(_vent(80, 70, basalt, lava, ash, LINE, rng), f"{P}/fumarola_grande.png")
    save(_lava_rock(96, 58, basalt, lava, LINE, rng), f"{P}/rochedo_lava.png")
    # Frente.
    save(pebbles(20, 8, basalt, LINE, rng), f"{P}/pedrinhas.png")
    save(crystal_cluster(12, 14, obsidian, "08060e", rng, 3), f"{P}/obsidiana_peq.png")
    save(_ember_pile(20, 9, char, lava, LINE, rng), f"{P}/brasas.png")
    save(_ember_pile(28, 10, ash, lava, LINE, rng), f"{P}/cinzas.png")
    # Quebráveis: caldeirão de magma e caixa de ferro queimado.
    save(_magma_pot(29, 41, pal("1a1418", "2e2628", "463a3a", "605050"), lava, LINE, rng), f"{out}/barril.png")
    save(crate(32, 26, pal("3a2a24", "543c32", "6e5042", "8a6a56", "a8826a"), LINE, rng, metal=lava[2]),
         f"{out}/caixa.png")


def _lava_rock(w, h, basalt, lava, line, rng):
    r = rock(w - 2, h - 2, basalt, line, rng, jag=0.25, bump=0.7)
    r = r[1:-1, 1:-1].copy()
    mask = r[..., 3] > 0
    _cracks(r, mask, lava[3], rng, max(2, w // 14), glow=lava[2])
    return finish(r, line)


def _spire(w, h, palette, line, rng):
    m = Mask(w, h).poly([(0, h - 1), (w - 1, h - 1), (w * 0.7, h * 0.45), (w * 0.58, 0), (w * 0.35, h * 0.4)]).get()
    out = np.zeros((h, w, 4), np.uint8)
    xs = np.arange(w)[None, :]
    split = (w * 0.55 + (np.arange(h)[:, None] - h) * 0.0)
    t = np.where(xs < split, 0.75, 0.3) + np.linspace(0.15, -0.1, h)[:, None]
    out[m] = ramp(np.clip(t, 0, 1), palette)[m]
    edge = Mask(w, h).line([(w * 0.58, 0), (w * 0.52, h - 2)], 1).get() & m
    out[edge] = palette[-1]
    return finish(out, line)


def _vent(w, h, basalt, lava, ash, line, rng):
    out = np.zeros((h, w, 4), np.uint8)
    smoke = np.zeros((h, w, 4), np.uint8)
    m = Mask(w, h)
    for k in range(7):
        r = w * (0.09 + k * 0.025)
        m.circle(w * 0.5 + k * w * 0.035 + math.sin(k * 1.3) * 2, h * 0.5 - k * h * 0.075, r)
    m.img.paste(0, (0, int(h * 0.55), w, h))
    sm = m.get()
    over(smoke, shade(sm, ash, ambient=0.35, bump=clumps(w, h, rng, r=3), bump_amt=0.3, soft=0.6))
    over(out, smoke)
    mound = Mask(w, h).poly([(0, h - 1), (w - 1, h - 1), (w * 0.66, h * 0.52), (w * 0.34, h * 0.52)]).get()
    over(out, shade(mound, basalt, ambient=0.2, bump=fbm(w, h, 4, 4, rng, 2), bump_amt=0.5))
    mouth = Mask(w, h).ellipse(w * 0.34, h * 0.48, w * 0.66, h * 0.58).get()
    out[mouth] = lava[3]
    out[Mask(w, h).ellipse(w * 0.42, h * 0.5, w * 0.58, h * 0.56).get()] = lava[4]
    _cracks(out, mound, lava[2], rng, 2)
    return finish(out, line)


def _basalt_columns(w, h, palette, line, rng):
    out = np.zeros((h, w, 4), np.uint8)
    n = 6
    cw = w / n
    order = list(range(n))
    rng.shuffle(order)
    for i in order:
        x0 = i * cw
        top = h * rng.uniform(0.05, 0.6)
        body = Mask(w, h).rect(x0, top + 4, x0 + cw - 1, h - 1).get()
        sh = shade(body, palette, cyl=True, ambient=0.2)
        cap = Mask(w, h).poly([(x0, top + 4), (x0 + cw * 0.25, top), (x0 + cw * 0.75, top), (x0 + cw - 1, top + 4),
                               (x0 + cw * 0.75, top + 7), (x0 + cw * 0.25, top + 7)]).get()
        sh[cap] = palette[3]
        over(out, outline(sh, col(line)))
    return finish(out, line)


def _ember_pile(w, h, palette, lava, line, rng):
    m = Mask(w, h).ellipse(0, 0, w - 1, h * 2).get()
    out = shade(m, palette, ambient=0.3)
    specks(out, m, lava[3], 0.12, rng)
    specks(out, m, lava[4], 0.04, rng)
    return finish(out, line)


def _magma_pot(w, h, iron, lava, line, rng):
    def prof(t):
        return (w / 2 - 1) * (0.78 + 0.22 * math.sin(math.pi * t))
    mask = lathe(w, h, prof)
    out = shade(mask, iron, cyl=True, ambient=0.2)
    for y0 in (h // 3, 2 * h // 3):
        for y in (y0, y0 + 1, y0 + 2):
            out[y][mask[y]] = lava[2] if y == y0 + 1 else lava[1]
    _cracks(out, mask, lava[3], rng, 3, glow=lava[2])
    top = Mask(w, h).ellipse(2, 0, w - 3, 5).get()
    out[top] = lava[4]
    return finish(out, line)


BIOMES = {"terra": terra, "deserto": deserto, "natureza": natureza, "vulcao": vulcao}


def main():
    wanted = sys.argv[1:] or list(BIOMES)
    for name in wanted:
        out = os.path.join(ROOT, name)
        os.makedirs(os.path.join(out, "props"), exist_ok=True)
        for f in os.listdir(os.path.join(out, "props")):
            os.remove(os.path.join(out, "props", f))
        BIOMES[name](out, np.random.default_rng(hash_str(name)))
        print(name, "ok:", len(os.listdir(os.path.join(out, "props"))), "objetos")


if __name__ == "__main__":
    main()

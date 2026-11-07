"""Pequena biblioteca de pixel art procedural usada por gerar_cenarios.py.

Tudo trabalha com arrays numpy RGBA (uint8). Formas são máscaras booleanas
desenhadas com PIL; o sombreado usa uma "cúpula" feita da distância até a
borda da máscara, iluminada de cima à esquerda e quantizada numa paleta com
pontilhado Bayer, para ficar com cara de pixel art feita à mão.
"""
import math

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0
LIGHT = np.array([-0.55, -0.75, 0.6])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def col(h, a=255):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)] + [a], np.uint8)


def pal(*hexes):
    return np.array([col(h) for h in hexes], np.uint8)


def mix(c1, c2, t):
    a = np.asarray(c1, float)
    b = np.asarray(c2, float)
    return np.clip(a + (b - a) * t, 0, 255).astype(np.uint8)


def bayer(h, w, ox=0, oy=0):
    big = np.tile(BAYER, (h // 4 + 2, w // 4 + 2))
    return big[oy % 4:oy % 4 + h, ox % 4:ox % 4 + w]


def ramp(t, palette, ox=0, oy=0, dither=True):
    """t em [0,1] (array HxW) -> cores da paleta, com pontilhado entre faixas."""
    n = len(palette)
    v = np.clip(t, 0.0, 0.9999) * (n - 1)
    i = np.floor(v).astype(int)
    if dither:
        f = v - i
        i = i + (f > bayer(*t.shape, ox, oy))
    i = np.clip(i, 0, n - 1)
    return palette[i]


# --- Ruído que emenda nas bordas -----------------------------------------------

def noise(w, h, cx, cy, rng):
    grid = rng.random((cy, cx))
    xs = np.arange(w) * cx / w
    ys = np.arange(h) * cy / h
    x0 = np.floor(xs).astype(int)
    y0 = np.floor(ys).astype(int)
    tx = xs - x0
    ty = ys - y0
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    x1 = (x0 + 1) % cx
    y1 = (y0 + 1) % cy
    a = grid[np.ix_(y0, x0)]
    b = grid[np.ix_(y0, x1)]
    c = grid[np.ix_(y1, x0)]
    d = grid[np.ix_(y1, x1)]
    top = a + (b - a) * tx[None, :]
    bot = c + (d - c) * tx[None, :]
    return top + (bot - top) * ty[:, None]


def fbm(w, h, cx, cy, rng, octaves=4):
    out = np.zeros((h, w))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        out += noise(w, h, cx * 2 ** o, cy * 2 ** o, rng) * amp
        total += amp
        amp *= 0.5
    return out / total


def wave(w, terms, rng):
    """Altura 1D que emenda: soma de senos com frequência inteira. terms=[(k, amp)]."""
    x = np.arange(w) / w
    out = np.zeros(w)
    for k, a in terms:
        out += a * np.sin(2 * math.pi * (k * x + rng.random()))
    return out


def voronoi_edges(w, h, n, rng):
    """Distância F2-F1 de pontos aleatórios, emendando nas bordas (rachaduras)."""
    pts = rng.random((n, 2)) * [w, h]
    tiles = np.concatenate([pts + [dx * w, dy * h] for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    yy, xx = np.mgrid[0:h, 0:w]
    f1 = np.full((h, w), 1e9)
    f2 = np.full((h, w), 1e9)
    for px, py in tiles:
        d = np.hypot(xx - px, yy - py)
        f2 = np.where(d < f1, f1, np.minimum(f2, d))
        f1 = np.minimum(f1, d)
    return f2 - f1, f1


# --- Máscaras ----------------------------------------------------------------

class Mask:
    def __init__(self, w, h):
        self.img = Image.new("L", (w, h), 0)
        self.d = ImageDraw.Draw(self.img)

    def ellipse(self, x0, y0, x1, y1, v=255):
        self.d.ellipse([x0, y0, x1, y1], fill=v)
        return self

    def poly(self, pts, v=255):
        self.d.polygon([tuple(p) for p in pts], fill=v)
        return self

    def rect(self, x0, y0, x1, y1, v=255):
        self.d.rectangle([x0, y0, x1, y1], fill=v)
        return self

    def line(self, pts, width, v=255):
        self.d.line([tuple(p) for p in pts], fill=v, width=width)
        return self

    def circle(self, x, y, r, v=255):
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=v)
        return self

    def get(self):
        return np.array(self.img) > 127


def lathe(w, h, profile):
    """Máscara de um objeto de revolução: profile(t) = meia-largura em px, t=0 topo."""
    m = np.zeros((h, w), bool)
    cx = (w - 1) / 2
    for y in range(h):
        r = profile(y / max(1, h - 1))
        x = np.arange(w)
        m[y] = np.abs(x - cx) <= r
    return m


# --- Sombreado ---------------------------------------------------------------

def dome(mask, radius=None, power=0.5):
    d = ndi.distance_transform_edt(np.pad(mask, 1))[1:-1, 1:-1]
    r = radius or max(1.0, d.max() * 0.8)
    return np.power(np.clip(d / r, 0, 1), power)


def shade(mask, palette, bump=None, bump_amt=0.0, ambient=0.25, radius=None, light=LIGHT, height=None,
          ox=0, oy=0, soft=1.0, cyl=False):
    """Cor RGBA de uma forma iluminada de cima à esquerda."""
    h, w = mask.shape
    if height is None:
        if cyl:
            # Cilindro vertical: a luz depende só do x dentro de cada linha.
            height = np.zeros((h, w))
            for y in range(h):
                xs = np.where(mask[y])[0]
                if len(xs) == 0:
                    continue
                c = (xs[0] + xs[-1]) / 2
                r = max(1.0, (xs[-1] - xs[0]) / 2 + 0.5)
                u = np.clip((np.arange(w) - c) / r, -1, 1)
                height[y] = np.sqrt(1 - u * u)
            height *= mask
        else:
            height = dome(mask, radius)
    hh = height.astype(float)
    if bump is not None:
        hh = hh + bump * bump_amt
    if soft:
        hh = ndi.gaussian_filter(hh, soft)
    gy, gx = np.gradient(hh)
    scale = 0.12
    n = np.stack([-gx, -gy, np.full_like(gx, scale)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    lam = np.clip((n * light).sum(-1), 0, 1)
    t = ambient + (1 - ambient) * lam
    rgba = ramp(t, palette, ox, oy)
    rgba = rgba.copy()
    rgba[~mask] = 0
    return rgba


def flat(mask, color):
    out = np.zeros(mask.shape + (4,), np.uint8)
    out[mask] = color
    return out


def over(dst, src, x=0, y=0):
    """Cola src (RGBA) sobre dst na posição x,y, cortando o que sai da borda."""
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return dst
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    a = s[..., 3:4] > 0
    dst[y0:y1, x0:x1] = np.where(a, s, dst[y0:y1, x0:x1])
    return dst


def outline(rgba, color, inner=None):
    """Contorno de 1 px por fora da silhueta (e, opcional, linha interna escura)."""
    a = rgba[..., 3] > 0
    grown = ndi.binary_dilation(a, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
    out = rgba.copy()
    out[grown & ~a] = color
    return out


def pad(rgba, n=1):
    return np.pad(rgba, ((n, n), (n, n), (0, 0)))


def trim(rgba):
    a = rgba[..., 3] > 0
    ys, xs = np.where(a)
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def save(rgba, path):
    Image.fromarray(rgba, "RGBA").save(path)


def specks(rgba, mask, color, density, rng, size=1):
    h, w = mask.shape
    r = rng.random((h, w)) < density
    r &= mask
    if size > 1:
        r = ndi.binary_dilation(r, iterations=size - 1) & mask
    rgba[r] = color
    return rgba


def clumps(w, h, rng, r=4.0, density=0.06):
    """Relevo de folhagem: muitas bolinhas sobrepostas (cachos de folhas)."""
    out = np.zeros((h, w))
    n = int(w * h * density / (r * r) * 3) + 1
    ri = int(math.ceil(r))
    yy, xx = np.mgrid[-ri:ri + 1, -ri:ri + 1]
    for _ in range(n):
        cx, cy = int(rng.integers(0, w)), int(rng.integers(0, h))
        rr = r * rng.uniform(0.7, 1.2)
        d = np.sqrt(np.clip(1 - (xx * xx + yy * yy) / (rr * rr), 0, 1))
        x0, y0 = cx - ri, cy - ri
        xs = slice(max(0, x0), min(w, x0 + 2 * ri + 1))
        ys = slice(max(0, y0), min(h, y0 + 2 * ri + 1))
        sub = d[ys.start - y0:ys.stop - y0, xs.start - x0:xs.stop - x0]
        out[ys, xs] = np.maximum(out[ys, xs], sub)
    return out

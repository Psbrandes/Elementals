"""Gera assets/props/lamina.png: a lâmina giratória enferrujada do chefe Corrosão
(fase 2). Arte original do projeto (CC0), 18x18, desenhada pixel a pixel.

Uso: python3 tools/gerar_lamina.py assets/props/lamina.png
"""
import math
import sys

from PIL import Image

SIZE = 18
OUTLINE = (40, 22, 18, 255)
RUST_DARK = (120, 52, 28, 255)
RUST = (178, 86, 40, 255)
STEEL = (196, 204, 214, 255)
STEEL_LIGHT = (240, 244, 250, 255)
HUB = (70, 60, 58, 255)


def main(path: str) -> None:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    c = (SIZE - 1) / 2.0
    # Quatro lâminas curvas (espiral): o ângulo do gume cresce com o raio.
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            if r > c + 0.2:
                continue
            a = (math.atan2(dy, dx) - r * 0.18) % (math.pi / 2)
            width = 0.95 - r * 0.045
            if r < 3.2:
                px[x, y] = HUB if r > 1.5 else STEEL
            elif a < width:
                edge = a > width - 0.28
                px[x, y] = STEEL_LIGHT if edge and r > 6 else STEEL if edge else (RUST if (x + y) % 3 else RUST_DARK)
    # Contorno escuro de 1 px em volta do que foi desenhado.
    solid = {(x, y) for y in range(SIZE) for x in range(SIZE) if px[x, y][3] > 0}
    for x, y in [(x, y) for y in range(SIZE) for x in range(SIZE) if (x, y) not in solid]:
        if any((x + ox, y + oy) in solid for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            px[x, y] = OUTLINE
    img.save(path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/props/lamina.png")

"""Copia os efeitos usados do PVFX Foundry (CC0) para assets/vfx e gera vfx.json.

Uso: python3 tools/pack_vfx.py <pasta extraída do pvfx-foundry-thirteen-spritesheets.zip>
Cada efeito vira <nome>.png (folha em grade, tier "lit") e uma entrada no vfx.json
com tamanho do quadro, pivô, colunas, quantidade de quadros e ms por quadro.
"""
import json
import shutil
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "vfx"

# nome no jogo -> efeito do pacote
EFFECTS = {
    "hit": "impacts/hit-spark",
    "hit_heavy": "impacts/crit-hit",
    "dust": "smoke/dust-puff",
    "stomp": "impacts/ground-slam",
    "break": "impacts/rock-shatter",
    "arrow_hit": "projectiles/arrow-impact",
    "coin": "ui/coin-pickup",
    "heal": "ui/heart-pickup",
    "phase": "shadow/void-implosion",
    "special_fogo": "explosions/fire-nova",
    "special_agua": "water/water-splash",
    "special_gelo": "ice/frost-nova",
    "special_vento": "wind/whirlwind",
    "special_folha": "nature/vine-snare",
    "special_terra": "nature/earth-spike",
    "special_cristal": "ice/ice-spike",
    "special_metal": "impacts/shockwave-ring",
}


def png_size(path: Path) -> tuple[int, int]:
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def main() -> None:
    src = Path(sys.argv[1])
    pack = {e["id"]: e for e in json.load(open(src / "pack.json"))["effects"]}
    OUT.mkdir(parents=True, exist_ok=True)
    meta = {}
    for name, effect_id in EFFECTS.items():
        e = pack[effect_id]
        sheet = src / e["artifacts"]["lit"]["grid"]["sheet"]
        manifest = json.load(open(src / e["artifacts"]["lit"]["grid"]["manifest"]))
        durations = [f["duration"]["numerator_ms"] / f["duration"]["denominator"] for f in manifest["frames"]]
        w, h = e["size"]
        sheet_w, _ = png_size(sheet)
        shutil.copyfile(sheet, OUT / f"{name}.png")
        meta[name] = {"source": effect_id, "size": [w, h], "pivot": e["pivot"], "columns": sheet_w // w,
                      "frames": e["frames"], "durations_ms": durations}
    with open(OUT / "vfx.json", "w") as f:
        json.dump(meta, f, indent=1)
    print(f"{len(meta)} efeitos em {OUT}")


if __name__ == "__main__":
    main()

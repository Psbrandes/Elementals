"""Empacota os PNGs soltos dos pacotes Elementals (chierit, CC-BY 4.0) e as tiras
dos inimigos da CraftPix (licença CraftPix) em uma folha por animação (grade de no máximo 2048 px de largura, limite seguro de
textura em celular), recortada à área usada pelo personagem.

Uso: python tools/pack_sprites.py <pasta com os zips extraídos, um por subpasta>
Pacotes que não estiverem na pasta são pulados e mantêm o que já está no JSON.

Gera assets/characters/<id>/<anim>.png e assets/characters/characters.json com
quantidade de quadros, tamanho do quadro, ponto dos pés (âncora), altura do
corpo parado, colunas da grade e, em cada golpe, o quadro de maior alcance
(alinhado com o quadro ativo) e até onde a arte chega à frente dos pés.
"""
import glob
import json
import os
import re
import statistics
import sys

from PIL import Image, ImageOps

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "characters")

# id -> (padrão da pasta do pacote, {animação do jogo: pasta da animação})
PACKS = {
    "fire_knight": ("Elementals_fire_knight_*/*/png/fire_knight", {
        "idle": "01_idle", "run": "02_run", "j_up": "03_jump_up", "j_down": "03_jump_down",
        "roll": "04_roll", "atk1": "05_1_atk", "atk2": "06_2_atk", "atk3": "07_3_atk",
        "sp_atk": "08_sp_atk", "defend": "09_defend", "take_hit": "10_take_hit",
        "death": "11_death", "air_atk": "air_atk"}),
    "wind_hashashin": ("elementals_wind_hashashin_*/*/PNG", {
        "idle": "idle", "run": "run", "j_up": "j_up", "j_down": "j_down", "roll": "roll",
        "atk1": "1_atk", "atk2": "2_atk", "atk3": "3_atk", "sp_atk": "sp_atk",
        "defend": "defend", "take_hit": "take_hit", "death": "death", "air_atk": "air_atk"}),
    "leaf_ranger": ("Elementals_Leaf_ranger_*/*/animations/PNG", {
        "idle": "idle", "run": "run", "j_up": "jump_up", "j_down": "jump_down", "roll": "roll",
        "atk1": "1_atk", "atk2": "2_atk", "atk3": "3_atk", "sp_atk": "sp_atk",
        "defend": "defend", "take_hit": "take_hit", "death": "death", "air_atk": "air_atk"}),
    "ground_monk": ("Elementals_ground_monk_*/*/png", {
        "idle": "idle", "run": "run", "j_up": "j_up", "j_down": "j_down", "roll": "roll",
        "atk1": "1_atk", "atk2": "2_atk", "atk3": "3_atk", "sp_atk": "sp_atk",
        "defend": "defend", "take_hit": "take_hit", "death": "death", "air_atk": "air_atk"}),
    "frost_guardian": ("Frost_Guardian_*/*/PNG files", {
        "idle": "idle", "run": "walk", "atk1": "1_atk", "take_hit": "take_hit", "death": "death"}),
    "metal_bladekeeper": ("Elementals_metal_bladekeeper_*/*/PNG animations", {
        "idle": "01_idle", "run": "02_run", "j_up": "03_jump_up", "j_down": "03_jump_down",
        "roll": "04_roll", "atk1": "07_1_atk", "atk2": "08_2_atk", "atk3": "09_3_atk",
        "sp_atk": "10_sp_atk", "defend": "11_defend", "take_hit": "12_take_hit",
        "death": "13_death", "air_atk": "air_atk"}),
    "crystal_mauler": ("Elementals_Crystal_Mauler_*/*/animations/PNG", {
        "idle": "idle", "run": "run", "j_up": "j_up", "j_down": "j_down", "roll": "roll",
        "atk1": "1_atk", "atk2": "2_atk", "atk3": "3_atk", "sp_atk": "sp_atk",
        "defend": "defend", "take_hit": "take_hit", "death": "death", "air_atk": "air_atk"}),
    "water_priestess": ("Elementals_water_priestess_*/*/png", {
        "idle": "01_idle", "run": "02_walk", "j_up": "04_j_up", "j_down": "05_j_down",
        "roll": "06_tumble", "atk1": "07_1_atk", "atk2": "08_2_atk", "atk3": "09_3_atk",
        "sp_atk": "10_sp_atk", "defend": "12_defend", "take_hit": "13_take_hit",
        "death": "14_death", "air_atk": "air_atk"}),
}
# Inimigos da CraftPix: cada animação é uma tira horizontal de quadros 128x128.
# id -> (padrão da pasta do personagem, {animação do jogo: arquivo})
STRIPS = {
    "samurai": ("free-samurai-pixel-art-sprite-sheets/Samurai", {
        "idle": "Idle", "run": "Walk", "atk1": "Attack_1", "atk2": "Attack_2", "atk3": "Attack_3",
        "defend": "Protection", "take_hit": "Hurt", "death": "Dead"}),
    "samurai_commander": ("free-samurai-pixel-art-sprite-sheets/Samurai_Commander", {
        "idle": "Idle", "run": "Walk", "dash": "Run", "atk1": "Attack_1", "atk2": "Attack_3",
        "defend": "Protect", "take_hit": "Hurt", "death": "Dead"}),
    "samurai_archer": ("free-samurai-pixel-art-sprite-sheets/Samurai_Archer", {
        "idle": "Idle", "run": "Walk", "atk1": "Attack_1", "shot": "Shot", "take_hit": "Hurt",
        "death": "Dead"}),
    "demon": ("anime-demon-sprite-sheet-pixel-art-pack/Demon_1", {
        "idle": "Idle", "run": "Walk", "atk1": "Attack", "take_hit": "Hurt", "death": "Dead"}),
    "witch": ("witch-pixel-character-sprite-sheets-pack/Witch_2", {
        "idle": "Idle", "run": "Walk", "atk1": "Spear", "sp_atk": "Special", "take_hit": "Hurt",
        "death": "Dead"}),
}
STRIP_FRAME = 128
ATTACKS = {"atk1", "atk2", "atk3", "air_atk", "sp_atk", "shot"}
MAX_SHEET_WIDTH = 2048


def natural(name):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", name)]


def load_frames(folder):
    files = sorted(glob.glob(os.path.join(folder, "*.png")), key=lambda p: natural(os.path.basename(p)))
    return [Image.open(f).convert("RGBA") for f in files]


def load_strip(path):
    sheet = Image.open(path).convert("RGBA")
    return [sheet.crop((i * STRIP_FRAME, 0, (i + 1) * STRIP_FRAME, STRIP_FRAME))
            for i in range(sheet.width // STRIP_FRAME)]


def union_bbox(frames):
    box = None
    for im in frames:
        b = im.getchannel("A").getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return box


def feet(frames):
    """Pés: base da animação parada e mediana das colunas opacas perto do chão."""
    bottom = union_bbox(frames)[3]
    xs = []
    for im in frames:
        alpha = im.getchannel("A")
        for y in range(max(bottom - 14, 0), bottom):
            xs += [x for x in range(im.width) if alpha.getpixel((x, y)) > 0]
    return round(statistics.median(xs)), bottom


def reach_frame(frames, foot_x):
    """Quadro em que a arte vai mais longe para frente (o golpe "acerta") e o alcance."""
    best, best_x = 0, -1
    for i, im in enumerate(frames):
        b = im.getchannel("A").getbbox()
        if b and b[2] > best_x:
            best, best_x = i, b[2]
    return best, best_x - foot_x


## Pacotes desenhados olhando para a esquerda: espelhados aqui para todos olharem para a direita
## (o jogo vira o desenho com scale.x = facing, contando que a arte olhe para a direita).
FACES_LEFT = {"frost_guardian"}


def pack(cid, frames, meta):
    if cid in FACES_LEFT:
        frames = {name: [ImageOps.mirror(im) for im in fs] for name, fs in frames.items()}
    box = union_bbox([im for fs in frames.values() for im in fs])
    foot_x, foot_y = feet(frames["idle"])
    size = (box[2] - box[0], box[3] - box[1])
    os.makedirs(os.path.join(OUT, cid), exist_ok=True)
    idle_box = union_bbox(frames["idle"])
    info = {"frame_size": list(size), "anchor": [foot_x - box[0], foot_y - box[1]],
            "height": idle_box[3] - idle_box[1], "anims": {}}
    columns = max(1, MAX_SHEET_WIDTH // size[0])
    info["columns"] = columns
    for name, fs in frames.items():
        cols = min(columns, len(fs))
        rows = (len(fs) + columns - 1) // columns
        sheet = Image.new("RGBA", (size[0] * cols, size[1] * rows))
        for i, im in enumerate(fs):
            sheet.alpha_composite(im.crop(box), ((i % columns) * size[0], (i // columns) * size[1]))
        sheet.save(os.path.join(OUT, cid, name + ".png"), optimize=True)
        anim = {"frames": len(fs)}
        if name in ATTACKS:
            anim["hit"], anim["reach"] = reach_frame(fs, foot_x)
        info["anims"][name] = anim
    meta[cid] = info
    print(cid, size, info["anchor"])


def main(src):
    path = os.path.join(OUT, "characters.json")
    meta = json.load(open(path)) if os.path.exists(path) else {}
    for cid, (pattern, anims) in PACKS.items():
        base = glob.glob(os.path.join(src, pattern))
        if not base:
            print("pulado (não está na pasta):", cid)
            continue
        pack(cid, {name: load_frames(os.path.join(base[0], folder)) for name, folder in anims.items()}, meta)
    for cid, (pattern, anims) in STRIPS.items():
        base = glob.glob(os.path.join(src, pattern))
        if not base:
            print("pulado (não está na pasta):", cid)
            continue
        pack(cid, {name: load_strip(os.path.join(base[0], f + ".png")) for name, f in anims.items()}, meta)
    with open(path, "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)


if __name__ == "__main__":
    main(sys.argv[1])

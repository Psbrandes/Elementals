class_name Characters
## Elenco jogável: os 7 heróis dos pacotes Elementals (arte de chierit, CC-BY 4.0).
## O Guardião de Gelo (pacote Boss: Frost Guardian) é inimigo, não herói: ver
## data/enemies/guardiao_gelo.tres.
## Os números de jogo ficam aqui; a arte e as medidas dos quadros vêm de
## assets/characters, geradas por tools/pack_sprites.py.
##
## hp: vida. speed: multiplica a velocidade de andar. power: multiplica o dano.
## scale: tamanho do desenho.
## body: caixa de corpo, quando foge do padrão (20x48).
## down: quadro da animação de morte usado como "caído" (os pacotes não têm queda;
## quem vira pó ou água na morte usa um quadro ajoelhado ou afundando).
## color: cor do elemento no medidor, no especial e na tela de seleção.

const LIST := [
	{"id": "fire_knight", "name": "Brasa", "title": "Cavaleiro de Fogo", "element": "Fogo",
		"color": Color("ff7a1a"), "hp": 100, "speed": 1.0, "power": 1.0, "scale": 1.0, "down": 9},
	{"id": "wind_hashashin", "name": "Vento", "title": "Assassino do Vento", "element": "Vento",
		"color": Color("9be0c8"), "hp": 85, "speed": 1.2, "power": 0.9, "scale": 1.0, "down": 7},
	{"id": "leaf_ranger", "name": "Folha", "title": "Arqueira da Folha", "element": "Folha",
		"color": Color("6cc04a"), "hp": 90, "speed": 1.1, "power": 0.95, "scale": 1.0, "down": 13},
	{"id": "ground_monk", "name": "Terra", "title": "Monge da Terra", "element": "Terra",
		"color": Color("c98b4b"), "hp": 110, "speed": 1.0, "power": 1.05, "scale": 1.0, "down": 7},
	{"id": "metal_bladekeeper", "name": "Metal", "title": "Guardiã das Lâminas", "element": "Metal",
		"color": Color("c0c8d8"), "hp": 95, "speed": 1.05, "power": 1.0, "scale": 1.0, "down": 6},
	{"id": "crystal_mauler", "name": "Cristal", "title": "Esmagador de Cristal", "element": "Cristal",
		"color": Color("d58cff"), "hp": 120, "speed": 0.9, "power": 1.15, "scale": 1.0, "down": 10},
	{"id": "water_priestess", "name": "Água", "title": "Sacerdotisa da Água", "element": "Água",
		"color": Color("4aa8ff"), "hp": 90, "speed": 1.0, "power": 0.95, "scale": 1.0, "down": 5},
]
const DEFAULT_ID := "fire_knight"
const META_PATH := "res://assets/characters/characters.json"
## Animação que falta em algum pacote (o Guardião de Gelo, inimigo, só tem 5) usa outra.
const FALLBACK := {"atk2": "atk1", "atk3": "atk1", "air_atk": "atk1", "sp_atk": "atk1",
	"j_up": "idle", "j_down": "idle", "defend": "idle", "roll": "run", "shot": "atk1", "dash": "run"}

## Escolhido na tela de seleção; a fase cria o jogador com ele.
static var selected := DEFAULT_ID

static var _meta: Dictionary = {}
static var _textures: Dictionary = {}


static func get_data(id: String) -> Dictionary:
	for c: Dictionary in LIST:
		if c["id"] == id:
			return c
	return LIST[0]


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return 0


## Tamanho do quadro, âncora dos pés e as animações (quadros e quadro do golpe).
static func meta(id: String) -> Dictionary:
	if _meta.is_empty():
		var file := FileAccess.open(META_PATH, FileAccess.READ)
		_meta = JSON.parse_string(file.get_as_text())
	return _meta[id]


## Nome da animação que existe para este personagem.
static func resolve_anim(id: String, anim: String) -> String:
	var anims: Dictionary = meta(id)["anims"]
	while not anims.has(anim) and FALLBACK.has(anim):
		anim = FALLBACK[anim]
	return anim if anims.has(anim) else "idle"


static func texture(id: String, anim: String) -> Texture2D:
	var path := "res://assets/characters/%s/%s.png" % [id, anim]
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]

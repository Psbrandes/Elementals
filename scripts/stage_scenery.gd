class_name StageScenery
## Cenário 3D da fase, montado em código a partir de Stage.SECTIONS. A fase pode
## ser jogada no ferro-velho original (pacote "Dump Vector Tileset" da CraftPix, o padrão)
## ou em 4 cenários elementais (Terra, Deserto, Natureza e Vulcão) com arte gerada por
## tools/gerar_cenarios.py. Cada um fica em assets/scenery/biomas/<id>/.
## Para trocar a arte de um cenário: bg_1..4.png, chao.png, barril.png, caixa.png e props/.
##
## - Fundo: 4 camadas (céu + 3) em painéis cada vez mais longe da câmera, então
##   a perspectiva já dá o parallax (o céu quase parado, as silhuetas perto andando).
## - Chão com a textura do bioma, do fundo até a frente da câmera.
## - Objetos em pé no chão, virados para a câmera: uma fileira atrás da área de
##   luta, uma mais funda com os objetos grandes e uns detalhes pequenos perto da câmera.
##
## Medidas em pixels da arte (1 unidade 3D = 1 px). O chão jogável vai de
## FLOOR_BACK (fundo) a FLOOR_FRONT (perto da câmera).

const FLOOR_BACK := (Stage.FLOOR_TOP - View3D.FLOOR_MID) * View3D.DEPTH_SCALE
const FLOOR_FRONT := (Stage.FLOOR_BOTTOM - View3D.FLOOR_MID) * View3D.DEPTH_SCALE
const MARGIN := 400.0
const DIR := "res://assets/scenery/biomas/"
## Tamanho de um ladrilho do chão no 3D (a textura tem 4x4 ladrilhos).
const FLOOR_TILE := 32.0
const FLOOR_DEEP := -950.0
## Camadas do fundo, da mais longe (céu) à mais perto: z, base e altura do painel.
const BACKGROUND := [
	{"z": -900.0, "bottom": -120.0, "height": 720.0},
	{"z": -680.0, "bottom": -70.0, "height": 440.0},
	{"z": -500.0, "bottom": -40.0, "height": 340.0},
	{"z": -340.0, "bottom": -10.0, "height": 250.0},
]

## Ordem em que a tela de seleção oferece os cenários.
const ORDER := ["ferro_velho", "terra", "deserto", "natureza", "vulcao"]
## Cada bioma: nome, cor do céu (alto da camada 1, para o fundo da câmera emendar),
## luzes, nomes das seções da fase e os objetos de cada fileira
## ([arquivo, escala mínima, escala máxima]; a frente só tem o arquivo).
const BIOMES := {
	"ferro_velho": {
		"name": "Ferro-velho", "element": "Metal", "color": Color("b0b4c8"),
		"sky": Color("b2afba"), "ambient": Color("8a8fb8"), "sun": Color("ffe2c0"), "floor": Color(0.85, 0.85, 0.9),
		"floor_shaded": true, "deep_gap": [110.0, 180.0],
		"barrel_tint": Color(1.0, 0.55, 0.45),
		"sections": ["Rua do cais", "Armazém", "Pátio do porto"],
		"back": [["tire2", 0.9, 1.1], ["tire3", 0.8, 1.0], ["tire4", 0.7, 0.9], ["barrel1", 0.8, 1.0],
			["barrel2", 0.8, 1.0], ["barrel3", 0.8, 1.0], ["barrel6", 0.9, 1.1], ["garbage_bag1", 0.8, 1.0],
			["garbage_bag2", 0.8, 1.0], ["garbage_bag4", 1.0, 1.2], ["bin1", 0.8, 1.0], ["bin3", 0.8, 1.0],
			["box3", 0.8, 1.0], ["box4", 0.8, 1.0], ["shield1", 0.8, 1.0], ["shield3", 0.9, 1.1]],
		"deep": [["car1", 0.8, 1.0], ["car2", 0.8, 1.0], ["car3", 0.8, 1.0], ["car4", 0.7, 0.8],
			["truck", 0.6, 0.7], ["tire3", 1.0, 1.2], ["shield2", 1.0, 1.2], ["shield4", 1.0, 1.2],
			["bin2", 1.0, 1.2], ["bin4", 1.0, 1.2]],
		"front": ["bottle1", "bottle3", "trash1", "trash3", "trash5", "trash7", "stick2", "stick5",
			"garbage_bag6", "garbage_bag8", "box1"],
	},
	"terra": {
		"name": "Cânion de Terra", "element": "Terra", "color": Color("e08a2a"),
		"sky": Color("5a6ea0"), "ambient": Color("9a8a8a"), "sun": Color("ffd8b0"), "floor": Color(0.9, 0.88, 0.86),
		"barrel_tint": Color(1.0, 1.0, 1.0),
		"sections": ["Trilha do cânion", "Mina de âmbar", "Círculo de pedras"],
		"back": [["pedra1", 0.8, 1.0], ["pedra2", 0.8, 1.0], ["pedra3", 0.8, 1.0], ["pedra4", 0.8, 1.0],
			["pilha_pedras", 0.8, 1.0], ["ambar1", 0.8, 1.0], ["ambar2", 0.8, 1.0], ["estalagmite1", 0.9, 1.1],
			["estalagmite2", 0.9, 1.1], ["carrinho_mina", 0.9, 1.0], ["escora", 0.9, 1.0]],
		"deep": [["chamine1", 0.9, 1.1], ["chamine2", 0.9, 1.1], ["menir", 0.9, 1.1], ["rochedo", 0.8, 1.0],
			["ambar_grande", 0.9, 1.1], ["pedra4", 1.2, 1.4]],
		"front": ["pedrinhas1", "pedrinhas2", "ambar_peq", "raiz", "pedra3"],
	},
	"deserto": {
		"name": "Deserto Escaldante", "element": "Areia", "color": Color("f0c060"),
		"sky": Color("3a7ccf"), "ambient": Color("b8a890"), "sun": Color("fff0c8"), "floor": Color(0.95, 0.93, 0.9),
		"barrel_tint": Color(1.0, 0.85, 0.8),
		"sections": ["Mar de dunas", "Ruínas do oásis", "Templo soterrado"],
		"back": [["cacto1", 0.8, 1.0], ["cacto2", 0.8, 1.0], ["cacto_bola", 0.8, 1.0], ["arenito1", 0.8, 1.0],
			["arenito2", 0.8, 1.0], ["arenito3", 0.8, 1.0], ["cranio", 0.8, 1.0], ["ossos", 0.9, 1.0],
			["arbusto_seco", 0.8, 1.0], ["jarro", 0.9, 1.0], ["coluna_quebrada", 0.9, 1.1]],
		"deep": [["rochedo", 0.8, 1.0], ["palmeira", 0.9, 1.1], ["arco_ruina", 0.9, 1.0], ["cacto_grande", 0.9, 1.1],
			["coluna", 1.0, 1.2], ["coluna_quebrada", 1.4, 1.6]],
		"front": ["pedrinhas", "capim_seco", "ossinho", "cacto_peq"],
	},
	"natureza": {
		"name": "Floresta Antiga", "element": "Natureza", "color": Color("79b84a"),
		"sky": Color("3d7fd0"), "ambient": Color("8aa0a8"), "sun": Color("fff2d0"), "floor": Color(0.88, 0.9, 0.88),
		"barrel_tint": Color(1.0, 0.8, 0.75),
		"sections": ["Trilha da mata", "Bosque antigo", "Clareira do santuário"],
		"back": [["moita1", 0.8, 1.0], ["moita2", 0.8, 1.0], ["moita3", 0.8, 1.0], ["moita_flor1", 0.8, 1.0],
			["moita_flor2", 0.8, 1.0], ["pedra_musgo1", 0.8, 1.0], ["pedra_musgo2", 0.8, 1.0], ["cogumelo1", 0.9, 1.1],
			["cogumelo2", 0.9, 1.1], ["toco", 0.9, 1.0], ["tronco_caido", 0.9, 1.0], ["samambaia", 0.9, 1.1]],
		"deep": [["arvore1", 0.9, 1.1], ["arvore2", 0.9, 1.1], ["arvore3", 0.9, 1.1], ["rochedo_musgo", 0.8, 1.0],
			["moita_grande", 1.0, 1.2]],
		"front": ["grama1", "grama2", "grama3", "pedrinhas", "cogumelo_peq"],
	},
	"vulcao": {
		"name": "Vulcão em Fúria", "element": "Fogo", "color": Color("ff5a1e"),
		"sky": Color("120a12"), "ambient": Color("a07070"), "sun": Color("ff9a60"), "floor": Color(1.0, 0.95, 0.92),
		"barrel_tint": Color(1.0, 1.0, 1.0),
		"sections": ["Encosta de cinzas", "Rio de lava", "Cratera do vulcão"],
		"back": [["pedra_lava1", 0.8, 1.0], ["pedra_lava2", 0.8, 1.0], ["pedra_lava3", 0.8, 1.0],
			["obsidiana1", 0.8, 1.0], ["obsidiana2", 0.8, 1.0], ["cristal_magma", 0.8, 1.0],
			["arvore_queimada", 0.8, 1.0], ["fumarola", 0.8, 1.0], ["cranio", 0.8, 1.0]],
		"deep": [["colunas_basalto", 0.9, 1.1], ["espinho_obsidiana", 0.9, 1.1], ["arvore_morta_grande", 0.9, 1.0],
			["fumarola_grande", 0.9, 1.0], ["rochedo_lava", 0.8, 1.0]],
		"front": ["pedrinhas", "obsidiana_peq", "brasas", "cinzas"],
	},
}

## Cenário da próxima fase (escolhido na tela de seleção; no online vem do host).
static var biome := "ferro_velho"


static func data(id := "") -> Dictionary:
	return BIOMES.get(id if id != "" else biome, BIOMES[ORDER[0]])


## Nome da seção da fase no cenário atual (o HUD mostra ao entrar nela).
static func section_title(index: int) -> String:
	var titles: Array = data()["sections"]
	return titles[clampi(index, 0, titles.size() - 1)]


## Arte do barril e da caixa quebráveis com a cara do cenário.
static func breakable_art(kind: String) -> Texture2D:
	return _texture("caixa.png" if kind == "caixa" else "barril.png")


static var _textures := {}


static func build(view: Node3D) -> void:
	_textures.clear()
	var root := Node3D.new()
	root.name = "Scenery"
	view.add_child(root)
	var left := -MARGIN
	var right := Stage.STAGE_LENGTH + MARGIN
	_floor(root, left, right)
	_background(root, left, right)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var info := data()
	_row(root, rng, info["back"], left, right, 34.0, 70.0, FLOOR_BACK - 26.0, FLOOR_BACK - 70.0)
	var deep_gap: Array = info.get("deep_gap", [70.0, 140.0])
	_row(root, rng, info["deep"], left, right, deep_gap[0], deep_gap[1], FLOOR_BACK - 120.0, FLOOR_BACK - 210.0)
	_front(root, rng, left, right)


# --- Partes -----------------------------------------------------------------------

## Terra do fundo até a frente da câmera, num plano só.
static func _floor(root: Node3D, left: float, right: float) -> void:
	var width := right - left
	var near := FLOOR_FRONT + 300.0
	var depth := near - FLOOR_DEEP
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, depth)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.position = Vector3(left + width / 2.0, 0.0, FLOOR_DEEP + depth / 2.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _texture("chao.png")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_color = data()["floor"]
	if not data().get("floor_shaded", false):
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.uv1_scale = Vector3(width / (FLOOR_TILE * 4.0), depth / (FLOOR_TILE * 4.0), 1.0)
	mesh.material_override = material
	root.add_child(mesh)


## As 4 camadas do bioma, repetidas na largura (as bordas das imagens emendam).
static func _background(root: Node3D, left: float, right: float) -> void:
	for i in BACKGROUND.size():
		var layer: Dictionary = BACKGROUND[i]
		var texture := _texture("bg_%d.png" % (i + 1))
		var height: float = layer["height"]
		var tile_width := height * texture.get_width() / texture.get_height()
		# Painel mais longe aparece mais largo na tela: sobra dos dois lados.
		var extra: float = -float(layer["z"]) * 1.2
		var width := right - left + extra * 2.0
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		var mesh := MeshInstance3D.new()
		mesh.mesh = quad
		mesh.position = Vector3((left + right) / 2.0, float(layer["bottom"]) + height / 2.0, layer["z"])
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.texture_repeat = true
		material.uv1_scale = Vector3(width / tile_width, 1.0, 1.0)
		mesh.material_override = material
		root.add_child(mesh)


## Fileira de objetos em pé, com espaçamento e profundidade sorteados.
static func _row(root: Node3D, rng: RandomNumberGenerator, pieces: Array, left: float, right: float,
		gap_min: float, gap_max: float, z_near: float, z_far: float) -> void:
	var x := left + rng.randf_range(0.0, gap_max)
	while x < right:
		var piece: Array = pieces[rng.randi() % pieces.size()]
		_prop(root, piece[0], Vector3(x, 0.0, rng.randf_range(z_far, z_near)), rng.randf_range(piece[1], piece[2]),
			rng.randf() < 0.5)
		x += rng.randf_range(gap_min, gap_max)


## Detalhes pequenos perto da câmera, espaçados para não esconder a luta.
static func _front(root: Node3D, rng: RandomNumberGenerator, left: float, right: float) -> void:
	var front: Array = data()["front"]
	var x := left + 90.0
	while x < right:
		_prop(root, front[rng.randi() % front.size()], Vector3(x, 0.0, FLOOR_FRONT + rng.randf_range(30.0, 60.0)),
			rng.randf_range(0.6, 0.8), rng.randf() < 0.5)
		x += rng.randf_range(160.0, 260.0)


static func _prop(root: Node3D, name: String, feet: Vector3, scale: float, flip: bool) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = _texture("props/%s.png" % name)
	sprite.pixel_size = scale
	sprite.flip_h = flip
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = feet + Vector3(0.0, sprite.texture.get_height() * scale / 2.0 - 1.0, 0.0)
	root.add_child(sprite)


static func _texture(file: String) -> Texture2D:
	var path := DIR + biome + "/" + file
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]

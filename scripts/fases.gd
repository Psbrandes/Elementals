class_name Fases
## As fases do jogo. Cada fase é uma linha de dados: nome, músicas, seções (ondas,
## travas, emboscadas e objetos, no mesmo formato de Stage.SECTIONS) e o cenário.
##
## A fase 1 (Bairro do Porto) continua em Stage.SECTIONS. A fase 2 (Cemitério de
## Ferro) fica aqui.
##
## TROCAR O CENÁRIO DE UMA FASE: a chave "scenery" diz de onde vem a arte do 3D
## quando o cenário escolhido na seleção é o padrão (ferro-velho). Nos biomas
## elementais (Shift/I na seleção) vale a arte do bioma em todas as fases.
## Hoje a fase 2 usa o ferro-velho do pacote atual na versão noturna, como
## provisório. Para usar outra arte:
##   1. Copie as imagens para uma pasta, por exemplo assets/scenery/fase2/:
##      4 camadas de fundo (a 1ª é a mais longe), o chão (ladrilho que repete) e os
##      objetos soltos em props/.
##   2. Troque "dir", "bg" (nome das camadas, com %d no número), "floor" e as
##      listas de objetos ("back_row", "deep_row", "front_row") abaixo.
##   3. Ajuste "sky" (cor do céu atrás de tudo), "ambient" e "sun" (luzes) para
##      combinar com a arte nova.
## Qualquer chave que faltar usa o ferro-velho (StageScenery.config()).

## Fase que está sendo jogada (1 = Bairro do Porto). A seleção e o "Próxima fase"
## da vitória mudam este número antes de abrir a cena da fase.
static var current := 1
## Pontos e vidas que passam de uma fase para a outra (vazio = começo novo).
static var carry := {}

const FASE_2_SECTIONS := [
	{
		"title": "Portão do ferro-velho", "start": 0.0,
		"locks": [
			# A Sombra aparece sozinha logo depois do aquecimento.
			{"x": 288.0, "waves": [["capanga", "brigao", "capanga"], ["sombra"]]},
			{"x": 800.0, "overlap": 1, "waves": [["sombra", "capanga", "faca"], ["escudeiro", "fundeiro", "brigao"]]},
		],
		"ambushes": [
			{"x": 560.0, "enemies": ["faca", "capanga"]},
		],
		"props": [
			{"kind": "lixeira", "x": 470.0, "y": 140.0, "item": "maca"},
			{"kind": "barril", "x": 660.0, "y": 186.0, "item": ""},
			{"kind": "caixa", "x": 1000.0, "y": 150.0, "item": "frango"},
			{"kind": "lixeira", "x": 1090.0, "y": 190.0, "item": "moedas"},
		],
	},
	{
		"title": "Pilhas de sucata", "start": 1152.0,
		"locks": [
			# A Curandeira entra atrás de um Brutamontes: a lição é derrubar ela primeiro.
			{"x": 1344.0, "overlap": 1, "waves": [["brutamontes", "curandeira"], ["capanga", "brigao", "faca"]]},
			{"x": 1700.0, "overlap": 1, "waves": [["piromante", "sombra", "capanga"],
				["curandeira", "escudeiro", "brigao", "capanga"]]},
			{"x": 1980.0, "overlap": 1, "waves": [["guardiao_gelo", "curandeira"], ["sombra", "faca", "brutamontes"]]},
		],
		"ambushes": [
			{"x": 1530.0, "enemies": ["sombra", "fundeiro"]},
		],
		"props": [
			{"kind": "barril", "x": 1450.0, "y": 140.0, "item": ""},
			{"kind": "caixa", "x": 1600.0, "y": 184.0, "item": "maca"},
			{"kind": "caixa", "x": 1880.0, "y": 140.0, "item": "orbe"},
			{"kind": "barril", "x": 2060.0, "y": 176.0, "item": ""},
			{"kind": "lixeira", "x": 2250.0, "y": 150.0, "item": "frango"},
		],
	},
	{
		"title": "Prensa enferrujada", "start": 2304.0,
		"locks": [
			{"x": 2400.0, "overlap": 1, "waves": [["sombra", "sombra", "brigao"],
				["curandeira", "brutamontes", "piromante"]]},
			{"x": 2688.0, "waves": [["corrosao"]], "boss": true},
		],
		"ambushes": [],
		"props": [
			{"kind": "barril", "x": 2520.0, "y": 140.0, "item": ""},
			{"kind": "caixa", "x": 2620.0, "y": 186.0, "item": "frango"},
			{"kind": "lixeira", "x": 2660.0, "y": 140.0, "item": "orbe"},
		],
	},
]

## Uma entrada por fase. "music" e "boss_music" são nomes em assets/audio/music.
const LIST := [
	{"name": "Bairro do Porto", "music": "fase", "boss_music": "chefe", "sections": "stage",
		"scenery": {}},
	{"name": "Cemitério de Ferro", "music": "fase", "boss_music": "chefe", "sections": FASE_2_SECTIONS,
		# Provisório: o mesmo ferro-velho, à noite. Troque aqui pelos assets novos.
		"scenery": {
			"dir": "res://assets/scenery/biomas/ferro_velho/",
			"bg": "bg_noite_%d.png",
			"floor": "chao.png",
			"floor_tint": Color(0.55, 0.52, 0.62),
			"sky": Color("282642"),
			"ambient": Color("6a6aa8"),
			"ambient_energy": 0.7,
			"sun": Color("ffb27a"),
			"sun_energy": 0.75,
			"seed": 4242,
		}},
]


static var _args_read := false


## "-- --fase=2" na linha de comando abre direto na fase 2 (testes e vídeos).
static func read_args() -> void:
	if _args_read:
		return
	_args_read = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fase="):
			current = clampi(int(arg.trim_prefix("--fase=")), 1, LIST.size())


## Troca a fase escolhida no título (setas para os lados).
static func cycle(step: int) -> void:
	current = posmod(current - 1 + step, LIST.size()) + 1


static func count() -> int:
	return LIST.size()


static func info(n := 0) -> Dictionary:
	return LIST[clampi((n if n > 0 else current) - 1, 0, LIST.size() - 1)]


static func display_name(n := 0) -> String:
	return info(n)["name"]


## Seções (ondas, travas, objetos) da fase atual.
static func sections() -> Array:
	var s: Variant = info()["sections"]
	return Stage.SECTIONS if s is String else s


static func scenery() -> Dictionary:
	return info()["scenery"]


static func has_next() -> bool:
	return current < LIST.size()


## Vai para a próxima fase guardando pontos e vidas.
static func advance(score: int, lives: int) -> void:
	carry = {"score": score, "lives": lives}
	current = mini(current + 1, LIST.size())


## Começo novo (título, seleção, jogar de novo): sem pontos nem vidas guardados.
static func reset_carry() -> void:
	carry = {}

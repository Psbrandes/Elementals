class_name Difficulty
extends RefCounted
## Nível de dificuldade da partida. Escolhido na seleção de personagem (L troca)
## ou na linha de comando (`-- --dificuldade=facil|normal|dificil`).
## Tudo o que muda está em LEVELS: dá para afinar sem mexer no resto do código.
## No co-op online vale o nível do host (só ele simula a luta).

enum Level { FACIL, NORMAL, DIFICIL }

## enemy_hp:   multiplica a vida dos inimigos e do chefe.
## damage:     multiplica todo dano que o herói recebe (golpes, projéteis, explosões).
## cooldown:   multiplica a espera dos inimigos entre um ataque e outro.
## attackers:  somado ao número de inimigos que atacam ao mesmo tempo (normal = 2).
## lives:      vidas no começo da fase.
## drop:       multiplica a chance de inimigos deixarem comida.
const LEVELS := {
	Level.FACIL: {"name": "Fácil", "enemy_hp": 0.8, "damage": 0.65, "cooldown": 1.35, "attackers": -1,
		"lives": 5, "drop": 1.5, "color": Color("6cc04a")},
	Level.NORMAL: {"name": "Normal", "enemy_hp": 1.0, "damage": 1.0, "cooldown": 1.0, "attackers": 0,
		"lives": 3, "drop": 1.0, "color": Color("ffcc33")},
	Level.DIFICIL: {"name": "Difícil", "enemy_hp": 1.25, "damage": 1.2, "cooldown": 0.8, "attackers": 1,
		"lives": 3, "drop": 0.6, "color": Color("ff5a3a")},
}
const ARG_NAMES := {"facil": Level.FACIL, "normal": Level.NORMAL, "dificil": Level.DIFICIL}

static var level := Level.NORMAL
static var _read_args := false


static func current() -> Dictionary:
	if not _read_args:
		_read_args = true
		for a: String in OS.get_cmdline_user_args():
			if a.begins_with("--dificuldade="):
				level = ARG_NAMES.get(a.substr(14), level)
	return LEVELS[level]


static func cycle() -> void:
	current()
	level = ((level + 1) % LEVELS.size()) as Level


static func display_name() -> String:
	return current()["name"]


static func enemy_hp(base: int) -> int:
	return maxi(1, roundi(base * float(current()["enemy_hp"])))


static func damage(base: int) -> int:
	if base <= 0:
		return base
	return maxi(1, roundi(base * float(current()["damage"])))


static func cooldown(base: int) -> int:
	return roundi(base * float(current()["cooldown"]))


static func extra_attackers() -> int:
	return int(current()["attackers"])


static func start_lives() -> int:
	return int(current()["lives"])


static func drop_chance(base: float) -> float:
	return clampf(base * float(current()["drop"]), 0.0, 1.0)

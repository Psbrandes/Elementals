class_name Sombra
extends Enemy
## Sombra (fase 2): guerreiro do Vento corrompido pela ferrugem. Luta como o Faca
## (espera o jogador se ocupar, bate e recua) e tem o Passo Sombrio:
##   1. some num piscar (SUMIR_STARTUP quadros: dá para acertar e cancelar);
##   2. fica invisível e intocável por SUMIR_FRAMES quadros;
##   3. reaparece nas COSTAS do herói e corta com "!" (CORTE_STARTUP quadros de
##      aviso, mais que o tempo de reação: dá para virar e bater primeiro, esquivar
##      ou pular).
## Fraca contra Fogo e Cristal (a luz espanta a sombra), resiste a Vento.

const SUMIR_STARTUP := 16
const SUMIR_FRAMES := 26
const SUMIR_MIN_DISTANCE := 50.0
const SUMIR_MAX_DISTANCE := 220.0
## Espera entre um Passo Sombrio e outro.
const SUMIR_COOLDOWN := 220
## Distância atrás do herói onde reaparece.
const BEHIND_DISTANCE := 26.0
const CORTE_STARTUP := 16
const CORTE_DAMAGE := 10

const SUMIR := {"name": "sumir", "startup": SUMIR_STARTUP, "active": SUMIR_FRAMES, "recovery": 0, "damage": 0,
	"near": 999.0, "far": -999.0, "telegraph": false}
const CORTE := {"name": "corte_sombrio", "startup": CORTE_STARTUP, "active": 4, "recovery": 26,
	"damage": CORTE_DAMAGE, "near": 0.0, "far": 36.0, "telegraph": true, "push": 120.0}

var _sumir_cooldown := 90


func _think(player: Player) -> void:
	_sumir_cooldown = maxi(_sumir_cooldown - 1, 0)
	var dx := absf(player.position.x - position.x)
	if _sumir_cooldown == 0 and _cooldown == 0 and player.height < 24.0 \
			and dx >= SUMIR_MIN_DISTANCE and dx <= SUMIR_MAX_DISTANCE:
		if not _has_slot:
			_has_slot = stage.request_attack_slot(self)
		if _has_slot or enraged:
			_sumir_cooldown = SUMIR_COOLDOWN
			start_attack(SUMIR)
			Sound.play("dodge", -4.0, 0.15)
			return
	super(player)


func _update_attack() -> void:
	if current_attack.get("name") == "sumir":
		var startup := int(current_attack["startup"])
		if state_frame == startup + 1:
			stage.fx("dust", position, 10.0)
		if state_frame == startup + int(current_attack["active"]):
			_reappear()
	super()


## Reaparece nas costas do herói (ou na frente, se as costas dão na parede).
func _reappear() -> void:
	var player := _target()
	if player == null:
		return
	var behind := Vector2(player.position.x - player.facing * BEHIND_DISTANCE, player.position.y)
	var r := stage.floor_rect
	if behind.x < r.position.x + 8.0 or behind.x > r.end.x - 8.0:
		behind.x = player.position.x + player.facing * BEHIND_DISTANCE
	position = stage.clamp_to_floor(behind)
	_entered = true
	facing = 1 if player.position.x >= position.x else -1
	stage.fx("dust", position, 10.0)
	Sound.play("whiff", -6.0, 0.2)


func _on_attack_finished() -> void:
	if current_attack.get("name") == "sumir":
		start_attack(CORTE)
		return
	super()


## Sumida: ninguém acerta.
func can_be_hit() -> bool:
	if _vanished():
		return false
	return super()


func _vanished() -> bool:
	if state != State.ATTACK or current_attack.get("name") != "sumir":
		return false
	return state_frame > int(current_attack["startup"])


func _is_visible_this_frame() -> bool:
	if state == State.ATTACK and current_attack.get("name") == "sumir":
		if _vanished():
			return false
		# Some piscando cada vez mais rápido.
		return state_frame % maxi(6 - state_frame / 4, 2) != 0
	return super()


func _attack_anim() -> String:
	match current_attack.get("name", ""):
		"sumir":
			return "roll"
		"corte_sombrio":
			return "atk2"
	return super()

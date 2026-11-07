class_name Curandeira
extends Enemy
## Curandeira (fase 2): sacerdotisa da Água corrompida. Fica atrás do bando, longe
## do herói, e cura os aliados feridos em volta:
##   - Reza por CURA_STARTUP quadros brilhando em verde ("CURA..." sobe dela).
##     Qualquer golpe nesse tempo interrompe a cura.
##   - No fim, todo inimigo ferido a até CURA_RADIUS px recupera CURA_AMOUNT de
##     vida (ela também). Chefes não são curados.
##   - Encurralada, dá um jato d'água que empurra o herói para longe (sem derrubar).
## A lição da onda é derrubar a Curandeira primeiro. Fraca contra Folha e Terra.

const CURA_STARTUP := 44
const CURA_RECOVERY := 24
const CURA_RADIUS := 150.0
const CURA_AMOUNT := 20
## Só reza quando algum aliado perdeu pelo menos isso de vida.
const CURA_MIN_MISSING := 10
const CURA_COOLDOWN := 210
const CURA_COLOR := Color("7dffa0")
## Jato d'água: empurra o herói para longe.
const JATO_PUSH := 200.0

const CURA := {"name": "cura", "startup": CURA_STARTUP, "active": 1, "recovery": CURA_RECOVERY, "damage": 0,
	"near": 999.0, "far": -999.0, "telegraph": false}

var _cura_cooldown := 120
var _glowing := false


func _ready() -> void:
	super()
	if not _melee.is_empty():
		_melee["name"] = "jato"
		_melee["push"] = JATO_PUSH


func _think(player: Player) -> void:
	_cura_cooldown = maxi(_cura_cooldown - 1, 0)
	if _cura_cooldown == 0 and _cooldown == 0 and _wounded_allies().size() > 0:
		_cura_cooldown = CURA_COOLDOWN
		start_attack(CURA)
		stage.popup("CURA...", position, body_size.y + 8.0, CURA_COLOR)
		Sound.play("menu_open", -8.0, 0.0)
		return
	# Encurralada: jato d'água para abrir espaço.
	if _cooldown == 0 and _can_reach(player, data.attack_reach + 4.0):
		start_attack(_melee)
		return
	# Longe do herói, de preferência atrás de um aliado.
	_avoid_wall(player, data.keep_distance)
	var goal := Vector2(player.position.x + side * data.keep_distance, player.position.y + _hold.y)
	var dx := absf(player.position.x - position.x)
	if dx < data.flee_distance:
		goal.x = player.position.x + side * (data.keep_distance + 30.0)
	_walk_to(goal, player)


## Inimigos feridos ao alcance da cura (chefes ficam de fora).
func _wounded_allies() -> Array:
	var list := []
	for other: Enemy in stage.enemies():
		if other is Boss or other.hp <= 0 or other.max_hp - other.hp < CURA_MIN_MISSING:
			continue
		var d := (other.position - position).abs()
		if d.x <= CURA_RADIUS and d.y <= CURA_RADIUS * 0.4:
			list.append(other)
	return list


func _update_attack() -> void:
	if current_attack.get("name") == "cura" and state_frame == int(current_attack["startup"]) + 1:
		_heal_allies()
	super()


func _heal_allies() -> void:
	var healed := false
	for other: Enemy in _wounded_allies():
		var amount := mini(CURA_AMOUNT, other.max_hp - other.hp)
		other.hp += amount
		other.health_changed.emit(other.hp, other.max_hp)
		stage.popup("+%d" % amount, other.position, other.body_size.y + 4.0, CURA_COLOR)
		stage.fx("heal", other.position, other.body_size.y * 0.5)
		healed = true
	if healed:
		Sound.play("food", -4.0, 0.0)


func _on_attack_finished() -> void:
	if current_attack.get("name") == "cura":
		_cooldown = Difficulty.cooldown(randi_range(40, 70))
		_drop_slot()
		enter_state(State.IDLE)
		return
	super()


## Verde pulsando enquanto reza (o HUD do cliente online recebe a cor pela foto).
func _update_sprite() -> void:
	super()
	if sprite == null:
		return
	if stage and stage.puppet:
		return
	if state == State.ATTACK and current_attack.get("name") == "cura" \
			and state_frame <= int(current_attack["startup"]):
		var pulse := 0.5 + 0.5 * sin(state_frame * 0.5)
		sprite.modulate = data.sprite_tint.lerp(CURA_COLOR, 0.35 + 0.45 * pulse)
		_glowing = true
	elif _glowing:
		_glowing = false
		sprite.modulate = data.sprite_tint


func _attack_anim() -> String:
	match current_attack.get("name", ""):
		"cura":
			return "sp_atk"
		"jato":
			return "atk1"
	return super()

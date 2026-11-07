class_name Boss
extends Enemy
## Ferrugem, o tenente de Terra (GDD seção 5). Três fases:
##   1  armadura corrompida: soco de pedra, pisada (abalo na faixa) e, de longe,
##      arremessa uma pedra em arco no ponto onde o jogador está.
##   2  com 50% a armadura quebra: mais rápido, os golpes saem mesmo apanhando na
##      antecipação, e ganha o salto: pula no jogador (círculo no chão) e cai com
##      abalo para os dois lados. No ar não pode ser atingido.
##   3  com 25%, fúria: chama reforços, fica ainda mais rápido e emenda a pisada
##      logo depois do soco.
## Cada golpe tem antecipação com brilho e "!", para o jogador aprender o padrão.
## Fraco contra Água e Folha: golpe que derruba desses elementos quebra a armadura.

signal phase_changed(phase: int)

const PHASE_TWO_RATIO := 0.5
const SUMMON_RATIO := 0.25
const PHASE_TWO_SPEED := 1.4
const PUNCH_REACH := 34.0
const STOMP_MIN_DISTANCE := 60.0
const SHOCKWAVE_DAMAGE := 15
const SHOCKWAVE_SPEED := 140.0
const SUMMON_COUNT := 2
const SUMMON_DATA := preload("res://data/enemies/capanga.tres")
const SUMMON_DATA_FURY := preload("res://data/enemies/capanga_brigao.tres")
const PHASE_THREE_SPEED := 1.65
const THROW_MIN_DISTANCE := 90.0
const ROCK_DAMAGE := 14
const ROCK_RADIUS := 18.0
const ROCK_FLIGHT := 44
const LEAP_MIN_DISTANCE := 70.0
const LEAP_PEAK := 90.0
const LEAP_DAMAGE := 18
const LEAP_RADIUS := 30.0
const FURY_COLOR := Color("ff5a3a")
const GLOW_COLOR := Color("ffcc33")

const STONE_PUNCH := {"name": "soco_de_pedra", "startup": 20, "active": 4, "recovery": 26,
	"damage": 16, "knockdown": true, "near": 0.0, "far": PUNCH_REACH, "y_lo": 30.0, "y_hi": 70.0,
	"telegraph": true}
const STOMP := {"name": "pisada", "startup": 20, "active": 1, "recovery": 30, "damage": 0,
	"near": 0.0, "far": 0.0, "telegraph": true, "shockwave": true}
## Pisada emendada no soco, na fúria: antecipação mais curta.
const FURY_STOMP := {"name": "pisada", "startup": 12, "active": 1, "recovery": 26, "damage": 0,
	"near": 0.0, "far": 0.0, "telegraph": true, "shockwave": true}
const ROCK_THROW := {"name": "arremesso_de_pedra", "startup": 22, "active": 1, "recovery": 26, "damage": 0,
	"near": 999.0, "far": -999.0, "telegraph": true}
## O "ativo" do salto é o voo: near > far, então não acerta ninguém no caminho.
const LEAP := {"name": "salto", "startup": 18, "active": 44, "recovery": 30, "damage": 0,
	"near": 999.0, "far": -999.0, "telegraph": true}

var phase := 1
var _summoned := false
var _leap_from := Vector2.ZERO
var _leap_to := Vector2.ZERO


func _ready() -> void:
	super()
	_cooldown = 60


func _think(player: Player) -> void:
	var speed: float = [1.0, PHASE_TWO_SPEED, PHASE_THREE_SPEED][phase - 1]
	_walk_to(_engage_goal(player, PUNCH_REACH - 6.0), player, speed)
	if _cooldown > 0 or player.height >= 24.0:
		return
	var dx := absf(player.position.x - position.x)
	var dy := absf(player.position.y - position.y)
	if dy <= ALIGN_DEPTH and dx <= PUNCH_REACH + 6.0:
		start_attack(STONE_PUNCH)
		return
	# De longe escolhe um dos golpes à distância que valem agora.
	var options := []
	if dy <= ALIGN_DEPTH * 2.0 and dx >= STOMP_MIN_DISTANCE:
		options.append(STOMP)
	if dx >= THROW_MIN_DISTANCE:
		options.append(ROCK_THROW)
	if phase >= 2 and dx >= LEAP_MIN_DISTANCE:
		options.append(LEAP)
		options.append(LEAP)
	if not options.is_empty():
		start_attack(options.pick_random())


func can_be_hit() -> bool:
	# No ar, durante o salto, ninguém alcança.
	if state == State.ATTACK and current_attack.get("name") == "salto" \
			and state_frame > int(current_attack["startup"]) \
			and state_frame <= int(current_attack["startup"]) + int(current_attack["active"]):
		return false
	return super()


## Círculo no chão onde o salto vai cair (o View3D desenha).
func ground_marker() -> Dictionary:
	if state != State.ATTACK or current_attack.get("name") != "salto":
		return {}
	var startup := int(current_attack["startup"])
	var active := int(current_attack["active"])
	if state_frame <= startup or state_frame > startup + active:
		return {}
	return {"at": _leap_to, "radius": LEAP_RADIUS, "progress": float(state_frame - startup) / active}


## Na fase 2 a armadura some, mas os golpes dele saem mesmo apanhando: durante a
## antecipação (o brilho) ele leva o dano sem ser interrompido.
func _resists_stagger() -> bool:
	if super():
		return true
	return phase >= 2 and state == State.ATTACK and state_frame <= int(current_attack.get("startup", 0))


func _update_attack() -> void:
	var startup := int(current_attack.get("startup", 0))
	match current_attack.get("name", ""):
		"arremesso_de_pedra":
			if state_frame == startup + 1 and _target():
				stage.spawn_lob(self, position + Vector2(facing * 14.0, 0.0), _target().position,
					ROCK_DAMAGE, ROCK_RADIUS, ROCK_FLIGHT, "pedra")
				Sound.play("whiff", -2.0)
		"salto":
			_update_leap(startup, int(current_attack["active"]))
	if current_attack.get("shockwave", false) and state_frame == int(current_attack["startup"]) + 1:
		# Abalo em linha na profundidade dele, para os dois lados.
		for dir in [-1, 1]:
			stage.spawn_projectile(self, Vector2(position.x + dir * 16.0, position.y), dir,
				SHOCKWAVE_DAMAGE, SHOCKWAVE_SPEED, true)
		stage.shake(3.0)
		Sound.play("stomp", -3.0)
		stage.fx("stomp", position)
	super()


func _update_leap(startup: int, active: int) -> void:
	if state_frame == startup + 1:
		_leap_from = position
		var player := _target()
		_leap_to = stage.clamp_to_floor(player.position if player else position)
		Sound.play("jump", -2.0)
	if state_frame <= startup or state_frame > startup + active:
		return
	var t := float(state_frame - startup) / active
	position = _leap_from.lerp(_leap_to, t)
	facing = 1 if _leap_to.x >= _leap_from.x else -1
	height = 4.0 * LEAP_PEAK * t * (1.0 - t)
	if state_frame == startup + active:
		height = 0.0
		stage.explode(position, LEAP_RADIUS, LEAP_DAMAGE, self, false, "pedra")
		for dir in [-1, 1]:
			stage.spawn_projectile(self, Vector2(position.x + dir * 20.0, position.y), dir,
				SHOCKWAVE_DAMAGE, SHOCKWAVE_SPEED, true)


func _on_attack_finished() -> void:
	# Fúria: o soco emenda numa pisada rápida.
	if phase == 3 and current_attack.get("name") == "soco_de_pedra":
		start_attack(FURY_STOMP)
		return
	height = 0.0
	match phase:
		1:
			_cooldown = Difficulty.cooldown(randi_range(50, 80))
		2:
			_cooldown = Difficulty.cooldown(randi_range(25, 50))
		_:
			_cooldown = Difficulty.cooldown(randi_range(15, 35))
	enter_state(State.IDLE)


## O chefe não usa as vagas de ataque e não perde o ritmo quando a armadura segura o golpe.
func _on_damaged(_damage: int, _heavy: bool) -> void:
	if phase == 1 and hp <= max_hp * PHASE_TWO_RATIO:
		phase = 2
		armor_hits = 0
		_armor_left = 0
		body_color = data.phase_two_color
		if sprite:
			sprite.modulate = data.phase_two_color.lightened(0.45)
		flash = 30
		stage.shake(4.0)
		Sound.play("phase", -2.0, 0.0)
		stage.fx("phase", position, body_size.y * 0.6)
		phase_changed.emit(phase)
	if not _summoned and hp > 0 and hp <= max_hp * SUMMON_RATIO:
		_summoned = true
		phase = 3
		if sprite:
			sprite.modulate = FURY_COLOR.lightened(0.35)
		flash = 30
		stage.shake(5.0)
		Sound.play("phase", -2.0, 0.0)
		stage.fx("phase", position, body_size.y * 0.6)
		stage.popup("FÚRIA!", position, body_size.y + 10.0, FURY_COLOR)
		stage.spawn_reinforcements(SUMMON_DATA, SUMMON_COUNT - 1)
		stage.spawn_reinforcements(SUMMON_DATA_FURY, 1)
		phase_changed.emit(phase)


func _draw_details(body: Rect2) -> void:
	super(body)
	if phase == 1:
		# Placas da armadura corrompida.
		draw_rect(Rect2(body.position + Vector2(-3.0, 16.0), Vector2(body_size.x + 6.0, 8.0)), Color("5b4a3f"))
		draw_rect(Rect2(body.position + Vector2(-2.0, 44.0), Vector2(body_size.x + 4.0, 6.0)), Color("5b4a3f"))
	if state != State.ATTACK or state_frame > int(current_attack.get("startup", 0)):
		return
	if _frame_glow():
		var center_x := body.position.x + body_size.x / 2.0
		if current_attack.get("shockwave", false):
			draw_rect(Rect2(Vector2(center_x - 10.0, body.end.y - 8.0), Vector2(20.0, 8.0)), GLOW_COLOR)
		else:
			_draw_reach(center_x, body.position.y + 30.0, 8.0, 10.0)
			draw_rect(Rect2(Vector2(center_x + facing * (body_size.x / 2.0) - 5.0, body.position.y + 28.0), Vector2(10.0, 14.0)), GLOW_COLOR)


func _frame_glow() -> bool:
	return state_frame % 6 < 4

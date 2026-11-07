class_name PlayerInput
extends RefCounted
## Lê os comandos do jogador num formato único. Tudo passa pelo Input Map, então
## teclado, gamepad e (no futuro) os botões de toque chegam aqui do mesmo jeito,
## e a lógica do combate não sabe de onde veio o comando.
##
## Com `scripted = true` os testes injetam comandos sem tocar no Input.

const AXIS_THRESHOLD := 0.4

## Direção em 8 direções: cada eixo vale -1, 0 ou 1.
var move := Vector2.ZERO
## "Acabou de apertar" neste quadro.
var attack := false
## Ataque seguro (para o golpe carregado). Nos testes, ligue e desligue à mão.
var attack_held := false
var jump := false
var special := false
var dodge := false
## Pulo ainda segurado (soltar cedo faz o pulo mais baixo). Nos testes fica
## segurado, a não ser que o teste mude.
var jump_held := true
var scripted := false

var _queued: Array[StringName] = []


func poll() -> void:
	if scripted:
		attack = &"attack" in _queued
		jump = &"jump" in _queued
		special = &"special" in _queued
		dodge = &"dodge" in _queued
		_queued.clear()
		return
	attack_held = Input.is_action_pressed(&"attack")
	var raw := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	move = Vector2(_snap(raw.x), _snap(raw.y))
	attack = Input.is_action_just_pressed(&"attack")
	jump = Input.is_action_just_pressed(&"jump")
	special = Input.is_action_just_pressed(&"special")
	dodge = Input.is_action_just_pressed(&"dodge")
	jump_held = Input.is_action_pressed(&"jump")


## Para os testes: aperta a ação no próximo quadro.
func press(action: StringName) -> void:
	_queued.append(action)


func _snap(value: float) -> float:
	if value > AXIS_THRESHOLD:
		return 1.0
	if value < -AXIS_THRESHOLD:
		return -1.0
	return 0.0

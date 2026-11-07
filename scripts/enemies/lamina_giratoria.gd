class_name LaminaGiratoria
extends Projectile
## Lâmina giratória do chefe Corrosão (fase 2): sai reta na faixa de quem lançou,
## freia, volta como bumerangue e some quando chega de novo na mão dele. Acerta na
## ida e na volta (uma vez por trecho). Mudar de faixa ou pular por cima desvia.

const ART := "res://assets/props/lamina.png"
## Quadros indo; depois freia e volta.
const OUT_FRAMES := 44
const TURN_FRAMES := 14
const MAX_FRAMES := 220
const CATCH_DISTANCE := 16.0

var thrower: Node2D
var _returning := false
var _base_speed := 0.0
var _hit_this_pass: Array = []


func _ready() -> void:
	art = ART
	_base_speed = speed


func _physics_process(_delta: float) -> void:
	_frame += 1
	# Ida, freada, virada e volta acelerando.
	if _frame <= OUT_FRAMES:
		speed = _base_speed
	elif _frame <= OUT_FRAMES + TURN_FRAMES:
		speed = _base_speed * (1.0 - float(_frame - OUT_FRAMES) / TURN_FRAMES)
	else:
		if not _returning:
			_returning = true
			direction = -direction
			_hit_this_pass.clear()
		speed = minf(speed + _base_speed * 0.08, _base_speed * 1.15)
		if is_instance_valid(thrower):
			# Volta para a mão: corrige a faixa devagar.
			position.y = move_toward(position.y, thrower.position.y, 0.6)
			if absf(thrower.position.x - position.x) <= CATCH_DISTANCE and thrower.state != Fighter.State.DEAD:
				queue_free()
				return
	position.x += direction * speed * Fighter.DT
	for player: Player in stage.players:
		if not is_instance_valid(player) or player in _hit_this_pass or not player.can_be_hit():
			continue
		if absf(player.position.y - position.y) <= Fighter.DEPTH_TOLERANCE \
				and absf(player.position.x - position.x) <= HIT_HALF_WIDTH + player.body_size.x / 2.0 \
				and _reaches_height(player):
			_hit_this_pass.append(player)
			if player.take_hit(damage, false, self):
				stage.fx("hit", player.position, 22.0, direction < 0)
	var r := stage.floor_rect
	if _frame > MAX_FRAMES or position.x < r.position.x - OFFSCREEN_MARGIN * 2.0 \
			or position.x > r.end.x + OFFSCREEN_MARGIN * 2.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# Placeholder 2D (o jogo mostra a arte no 3D).
	draw_circle(Vector2(0.0, -STONE_HEIGHT), 5.0, Color("b25628"))
	draw_circle(Vector2(0.0, -STONE_HEIGHT), 2.0, Color("c4ccd6"))

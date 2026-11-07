class_name HeroProjectile
extends Projectile
## Projétil de um herói (bola de fogo, flecha, corte de vento, estilhaço, onda,
## tremor de terra). Anda reto na faixa de profundidade em que saiu e acerta os
## inimigos e as lixeiras, não o jogador. Os dados vêm do golpe (HeroMoves):
##   speed, damage, knockdown, launch, pierce (atravessa), ground (corre pelo chão),
##   carry (leva os inimigos junto), burn, freeze, art (arte em assets/heroes_fx).

const SHOT_HEIGHT := 26.0
const MAX_LIFE_FRAMES := 150
const CARRY_STEP := 1.6

var owner_player: Player
var data: Dictionary = {}

var _hits: Array = []
var _carried: Array = []


func _physics_process(_delta: float) -> void:
	_frame += 1
	position.x += direction * speed * Fighter.DT
	if not is_instance_valid(owner_player):
		queue_free()
		return
	for target: Fighter in _carried.duplicate():
		if is_instance_valid(target) and target.state == Fighter.State.KNOCKDOWN and target.height > 0.0:
			target.position.x += direction * CARRY_STEP
		else:
			_carried.erase(target)
	for target: Fighter in owner_player._opponents():
		if target in _hits or not target.can_be_hit():
			continue
		if absf(target.position.y - position.y) > Fighter.DEPTH_TOLERANCE:
			continue
		if absf(target.position.x - position.x) > HIT_HALF_WIDTH + target.body_size.x / 2.0:
			continue
		if not _reaches(target):
			continue
		_hits.append(target)
		var hit_damage := owner_player._attack_damage(data)
		if target.take_hit(hit_damage, data.get("knockdown", false), self, float(data.get("launch", 0.0))):
			owner_player._on_projectile_hit(target, data, direction, hit_damage)
			if data.get("carry", false):
				_carried.append(target)
			if not data.get("pierce", false) and not ground:
				queue_free()
				return
	var r := stage.floor_rect
	if _frame > MAX_LIFE_FRAMES or position.x < r.position.x - OFFSCREEN_MARGIN \
			or position.x > r.end.x + OFFSCREEN_MARGIN:
		queue_free()
	queue_redraw()


func _reaches(target: Fighter) -> bool:
	if ground:
		return target.height < 6.0
	return target.height <= SHOT_HEIGHT and target.height + target.body_size.y >= SHOT_HEIGHT - 10.0


func _draw() -> void:
	if ground:
		super()
		return
	var color: Color = owner_player.element_color() if is_instance_valid(owner_player) else Color.WHITE
	draw_rect(Rect2(Vector2(-5.0, -SHOT_HEIGHT - 3.0), Vector2(10.0, 6.0)), color)

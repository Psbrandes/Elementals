class_name Projectile
extends Node2D
## Pedra do Fundeiro ou abalo da pisada do Ferrugem. Anda em linha reta na
## profundidade de quem lançou: mudar de faixa desvia dos dois, e pular também
## desvia do abalo, que corre pelo chão.

const HIT_HALF_WIDTH := 6.0
const STONE_HEIGHT := 30.0
const OFFSCREEN_MARGIN := 60.0

var stage: Stage
var direction := 1
var speed := 150.0
var damage := 6
## true = abalo no chão; false = pedra na altura do peito.
var ground := false
## Arte do projétil no 3D (vazio = pedra).
var art := ""

var _frame := 0


func _physics_process(_delta: float) -> void:
	_frame += 1
	position.x += direction * speed * Fighter.DT
	for player: Player in stage.players:
		if is_instance_valid(player) and player.can_be_hit() \
				and absf(player.position.y - position.y) <= Fighter.DEPTH_TOLERANCE \
				and absf(player.position.x - position.x) <= HIT_HALF_WIDTH + player.body_size.x / 2.0 \
				and _reaches_height(player):
			if player.take_hit(damage, false, self):
				if art != "":
					stage.fx("arrow_hit", player.position, 18.0, direction < 0)
				queue_free()
				return
	var r := stage.floor_rect
	if position.x < r.position.x - OFFSCREEN_MARGIN or position.x > r.end.x + OFFSCREEN_MARGIN:
		queue_free()
	queue_redraw()


func _reaches_height(target: Fighter) -> bool:
	if ground:
		return target.height < 6.0
	return target.height <= STONE_HEIGHT and target.height + target.body_size.y >= STONE_HEIGHT


func _draw() -> void:
	if ground:
		for i in 4:
			var h := 10.0 - i * 2.0 + float((_frame + i * 3) % 4)
			var x := -direction * i * 7.0 - 3.0
			draw_rect(Rect2(Vector2(x, -h), Vector2(6.0, h)), Color("8c5a3c") if i % 2 else Color("c97b3a"))
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(Vector2(-2.0, -STONE_HEIGHT - 2.0), Vector2(5.0, 4.0)), Color("b0a89a"))

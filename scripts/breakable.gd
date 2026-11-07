class_name Breakable
extends Fighter
## Objetos do cenário:
##   lixeira  quebra com um golpe e solta o item de dentro (se houver).
##   caixa    aguenta 2 golpes (balança no primeiro) e solta o item.
##   barril   barril de combustível: o golpe acende o pavio e, depois de
##            FUSE_FRAMES piscando, ele explode e derruba todo mundo por perto,
##            inimigos e jogador. Explosão de outro barril ou bomba também acende.

const BREAK_FRAMES := 20
const CRATE_HITS := 2
const FUSE_FRAMES := 45
const BARREL_RADIUS := 36.0
const BARREL_DAMAGE := 20
const WOBBLE_FRAMES := 10

## "lixeira", "caixa" ou "barril".
var kind := "lixeira"
## Item que sai de dentro ("" para nenhum).
var item := ""

## Quadros até explodir (0 = pavio apagado).
var fuse := 0
var wobble := 0


func _ready() -> void:
	max_hp = CRATE_HITS if kind == "caixa" else 1
	match kind:
		"lixeira":
			body_size = Vector2(16.0, 22.0)
		"barril":
			body_size = Vector2(18.0, 26.0)
		_:
			body_size = Vector2(26.0, 24.0)
	super()


func _physics_process(delta: float) -> void:
	wobble = maxi(wobble - 1, 0)
	if fuse > 0 and state != State.DEAD:
		fuse -= 1
		flash = 2 if fuse % 8 < 4 else 0
		if fuse == 0:
			_break()
			stage.explode(position, BARREL_RADIUS, BARREL_DAMAGE, self, true, "bomba")
	super(delta)


func can_be_hit() -> bool:
	return state != State.DEAD and fuse == 0


func can_be_grabbed() -> bool:
	return false


func is_lit() -> bool:
	return fuse > 0


func take_hit(_damage: int, _knockdown: bool, from: Node2D, _launch := 0.0) -> bool:
	if not can_be_hit():
		return false
	if from is Fighter:
		from.hitstop = maxi(from.hitstop, HITSTOP_FRAMES)
	if kind == "barril":
		fuse = FUSE_FRAMES
		Sound.play("hit", -4.0)
		if stage:
			stage.popup("CUIDADO!", position, body_size.y + 8.0, Color("ff7a1a"))
		return true
	hp -= 1
	if hp > 0:
		wobble = WOBBLE_FRAMES
		Sound.play("hit", -6.0)
		if stage:
			stage.fx("hit", position, body_size.y * 0.5)
		return true
	_break()
	return true


func _break() -> void:
	hp = 0
	fuse = 0
	enter_state(State.DEAD)
	Sound.play("break")
	if stage:
		stage.fx("break", position)
		stage.on_breakable_broken(self)


func _update_dead() -> void:
	if state_frame >= BREAK_FRAMES:
		queue_free()


func _clamps_x() -> bool:
	return false


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, body_size.x / 2.0 + 2.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	var color := Color("5f7a6a")
	if kind == "caixa":
		color = Color("8c6a3e")
	elif kind == "barril":
		color = Color("b03a2e") if flash == 0 else Color.WHITE
	if state == State.DEAD:
		# Pedaços voando.
		var t := float(state_frame)
		for i in 5:
			var dir := float(i - 2)
			var pos := Vector2(dir * t * 0.8, -10.0 - t * 1.5 + t * t * 0.08 + i * 2.0)
			draw_rect(Rect2(pos, Vector2(4.0, 4.0)), color)
		return
	var shift := 1.0 if wobble % 4 < 2 and wobble > 0 else 0.0
	var body := Rect2(Vector2(-body_size.x / 2.0 + shift, -body_size.y), body_size)
	draw_rect(body, color)
	if kind == "lixeira":
		draw_rect(Rect2(body.position + Vector2(-1.0, 0.0), Vector2(body_size.x + 2.0, 4.0)), color.darkened(0.3))
		for i in 3:
			draw_rect(Rect2(body.position + Vector2(3.0 + i * 4.0, 7.0), Vector2(1.0, body_size.y - 10.0)), color.darkened(0.2))
	elif kind == "barril":
		draw_rect(Rect2(body.position + Vector2(0.0, 5.0), Vector2(body_size.x, 2.0)), color.darkened(0.4))
		draw_rect(Rect2(body.position + Vector2(0.0, body_size.y - 7.0), Vector2(body_size.x, 2.0)), color.darkened(0.4))
	else:
		draw_line(body.position, body.end, color.darkened(0.35), 2.0)
		draw_line(Vector2(body.position.x, body.end.y), Vector2(body.end.x, body.position.y), color.darkened(0.35), 2.0)
		draw_rect(body, color.darkened(0.35), false, 1.0)

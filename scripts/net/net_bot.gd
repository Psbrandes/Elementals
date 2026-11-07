extends RefCounted
## Robô para testar o co-op sem ninguém no teclado (--bot na linha de comando):
## anda até o inimigo ou objeto mais perto, soca e solta o especial quando está
## cercado. Funciona no host e no cliente, porque só mexe nos comandos (PlayerInput).

var stage: Stage
var _frame := 0


func _init(owner_stage: Stage) -> void:
	stage = owner_stage


func drive(p: Player, input: PlayerInput, is_host: bool) -> void:
	_frame += 1
	input.scripted = true
	if is_host:
		# O robô do host não deixa a partida acabar no meio do teste.
		for other: Player in stage.players:
			other.lives = maxi(other.lives, 9)
	if p.state == Fighter.State.DEAD or stage.cleared:
		input.move = Vector2.ZERO
		return
	var target: Node2D = null
	for e: Node2D in stage.enemies() + stage.breakables():
		if not stage.floor_rect.grow(2.0).has_point(e.position):
			continue
		if target == null or e.position.distance_to(p.position) < target.position.distance_to(p.position):
			target = e
	if target == null:
		input.move = Vector2(1, 0)
		return
	var d := target.position - p.position
	var dir := signf(d.x) if d.x != 0.0 else 1.0
	if absf(d.y) > 3.0:
		input.move = Vector2(0, signf(d.y))
	elif absf(d.x) > 26.0:
		input.move = Vector2(dir, 0)
	elif absf(d.x) < 6.0:
		input.move = Vector2(-dir, 0)
	elif p.facing != int(dir):
		input.move = Vector2(dir, 0)
	else:
		input.move = Vector2.ZERO
		if _frame % 6 == 0:
			input.press(&"attack")
	var near := 0
	for e: Node2D in stage.enemies():
		if e.position.distance_to(p.position) < 50.0:
			near += 1
	var partner := _partner_near(p)
	if is_host:
		if p.meter >= 50 and partner != null:
			# Ataque em dupla: guarda o especial e solta junto com o do parceiro.
			if partner.state == Fighter.State.ATTACK and partner.current_attack.get("special", false) \
					and partner.state_frame <= 3:
				input.press(&"special")
		elif p.meter >= 50 and near >= 2 and _frame % 30 == 0:
			input.press(&"special")
	elif p.meter >= 50 and (near >= 2 or (near >= 1 and partner != null)) and _frame % 30 == 0:
		input.press(&"special")


## Parceiro perto o bastante para o ataque em dupla.
func _partner_near(p: Player) -> Player:
	for other: Player in stage.players:
		if other == p or not is_instance_valid(other) or other.state == Fighter.State.DEAD:
			continue
		var gap := (other.position - p.position).abs()
		if gap.x <= HeroMoves.TEAM_RANGE.x and gap.y <= HeroMoves.TEAM_RANGE.y:
			return other
	return null

extends SceneTree
## Vitrine do sistema de combos, para gravar vídeo:
##   godot --path . --fixed-fps 60 --write-movie /tmp/combos.avi --script res://tests/combo_showcase.gd
## Mostra: combo no chão com cancelamento, lançador + pulo cancelado + combo
## aéreo com pisão e quique, contra-ataque e câmera lenta no último inimigo.

const MAIN := preload("res://scenes/main.tscn")
const CAPANGA := preload("res://data/enemies/capanga.tres")

var stage: Stage
var p: Player
var hud: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(7)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1152, 648))
	await process_frame
	print("janela ", DisplayServer.window_get_size(), " viewport ", root.get_visible_rect().size)
	var main := MAIN.instantiate()
	main.get_node("Stage").auto_spawn = false
	root.add_child(main)
	stage = main.get_node("Stage")
	hud = main.get_node("HUD/HUDView")
	p = stage.player
	p.input.scripted = true
	p.position = Vector2(150, 168)
	await _wait(60)

	# 1. Combo no chão: J J J com o próximo golpe saindo logo depois do acerto.
	_caption("J J J: CANCELA NO ACERTO")
	var e := _enemy(Vector2(24, 0), 200)
	await _wait(30)
	for i in 3:
		p.input.press(&"attack")
		await _wait(7)
	await _wait(90)

	# 2. Lançador, pulo cancelado e combo aéreo com pisão.
	_caption("LANÇA + K + J J J NO AR")
	await _until(func() -> bool: return e.state == Fighter.State.IDLE, 120)
	await _approach(e)
	await _launcher()
	p.input.press(&"jump")
	await _wait(6)
	for i in 3:
		p.input.press(&"attack")
		await _wait(10)
	# Quicou: no chão, lança de novo.
	await _until(func() -> bool: return p.state != Fighter.State.JUMP, 60)
	await _wait(2)
	p.input.press(&"attack")
	await _wait(9)
	p.input.press(&"attack")
	await _wait(80)

	# 3. Contra-ataque: golpe na antecipação do inimigo.
	_caption("CONTRA-ATAQUE NO \"!\"")
	e.queue_free()
	await _wait(20)
	var c := _enemy(Vector2(26, 0), 30)
	c.ai_enabled = true
	await _until(func() -> bool: return c.is_in_startup(), 300)
	p.facing = 1 if c.position.x > p.position.x else -1
	p.input.press(&"attack")
	await _wait(8)
	p.input.press(&"attack")
	await _wait(8)
	p.input.move = Vector2(1, 0) if p.facing > 0 else Vector2(-1, 0)
	p.input.press(&"attack")
	await _wait(1)
	p.input.move = Vector2.ZERO
	await _wait(90)

	# 4. Uma onda inteira, terminando em câmera lenta.
	_caption("ÚLTIMO INIMIGO: CÂMERA LENTA")
	for offset in [Vector2(70, -10), Vector2(-70, 8), Vector2(110, 12)]:
		var foe := _enemy(offset, 30)
		foe.ai_enabled = true
	var f := 0
	while not stage.enemies().is_empty() and f < 60 * 25:
		f += 1
		await physics_frame
		_fight_step(f)
	await _wait(150)
	quit()


func _fight_step(f: int) -> void:
	var target: Fighter = null
	for foe: Fighter in stage.enemies():
		if foe.hp <= 0:
			continue
		if target == null or foe.position.distance_to(p.position) < target.position.distance_to(p.position):
			target = foe
	if target == null:
		p.input.move = Vector2.ZERO
		return
	var d := target.position - p.position
	if absf(d.y) > 3:
		p.input.move = Vector2(0, signf(d.y))
	elif absf(d.x) > 26:
		p.input.move = Vector2(signf(d.x), 0)
	else:
		p.input.move = Vector2.ZERO
		if p.state in [Fighter.State.IDLE, Fighter.State.WALK]:
			p.facing = int(signf(d.x)) if d.x != 0 else p.facing
		if f % 7 == 0:
			# Varia o 3º golpe: lança de vez em quando.
			if p._combo_step == 2 and f % 21 == 0:
				p.input.move = Vector2(0, -1)
			p.input.press(&"attack")
	if p.state == Fighter.State.ATTACK and p.current_attack.get("name") == "lancador" and p._combo_connected:
		p.input.press(&"jump")
	if p.state == Fighter.State.JUMP and f % 9 == 0:
		p.input.press(&"attack")


func _enemy(offset: Vector2, hp: int) -> Enemy:
	var foe := stage.spawn_enemy(CAPANGA, p.position + offset)
	foe.ai_enabled = false
	foe.max_hp = hp
	foe.hp = hp
	return foe


func _approach(target: Fighter) -> void:
	for i in 120:
		var d := target.position - p.position
		if absf(d.y) > 2:
			p.input.move = Vector2(0, signf(d.y))
		elif absf(d.x) > 24:
			p.input.move = Vector2(signf(d.x), 0)
		elif absf(d.x) < 16:
			p.input.move = Vector2(-signf(d.x), 0)
		else:
			break
		await physics_frame
	p.input.move = Vector2.ZERO
	p.facing = 1 if target.position.x > p.position.x else -1
	await _wait(10)


func _launcher() -> void:
	p.input.press(&"attack")
	await _wait(8)
	p.input.press(&"attack")
	await _wait(8)
	p.input.move = Vector2(0, -1)
	p.input.press(&"attack")
	await _wait(1)
	p.input.move = Vector2.ZERO
	await _until(func() -> bool: return p._combo_connected and p.current_attack.get("name") == "lancador", 30)


func _caption(text: String) -> void:
	hud._show_banner(text)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _until(condition: Callable, limit: int) -> void:
	for i in limit:
		if condition.call():
			return
		await physics_frame

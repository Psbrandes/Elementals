extends SceneTree
## Vitrine para vídeo das novidades de inimigos, ritmo e chefe. Monta cada
## situação, joga com o mesmo robô do playthrough e escreve o nome na tela.
##   godot --path . --fixed-fps 60 --write-movie /tmp/v.avi --script res://tests/vitrine_inimigos.gd

const MAIN := preload("res://scenes/main.tscn")

var stage: Stage
var hud: Control
var p: Player
var _main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(7)
	await _scene("fire_knight")
	await _title("ESCUDEIRO BLOQUEIA DE FRENTE")
	var guard := _enemy("escudeiro", Vector2(50, 0))
	guard._cooldown = 999
	for i in 4:
		p.facing = 1
		p.input.press(&"attack")
		await _frames(16)
	await _frames(70)
	await _title("PULO OU AGARRÃO QUEBRAM A GUARDA")
	await _jump_kick_at(guard)
	await _fight(240)

	await _scene("fire_knight")
	await _title("PIROMANTE: BOMBA NO CÍRCULO")
	_enemy("piromante", Vector2(120, 20))
	_enemy("capanga", Vector2(-60, 0))
	_enemy("capanga", Vector2(-80, -20))
	await _dodge_around(360)
	await _fight(300)

	await _scene("fire_knight")
	await _title("BARRIL EXPLOSIVO")
	stage._spawn_breakable({"kind": "barril", "x": p.position.x + 24.0, "y": p.position.y, "item": ""})
	stage._spawn_breakable({"kind": "barril", "x": p.position.x + 64.0, "y": p.position.y + 6.0, "item": ""})
	for i in 3:
		var e := _enemy("capanga", Vector2(70 + i * 14, -12 + i * 12))
		e._cooldown = 200
	await _frames(20)
	p.facing = 1
	p.input.press(&"attack")
	await _frames(6)
	p.input.move = Vector2(-1, 0)
	await _frames(40)
	p.input.move = Vector2.ZERO
	await _frames(120)
	await _fight(200)

	await _scene("water_priestess")
	await _title("FRAQUEZA: ÁGUA x FOGO")
	_enemy("brigao", Vector2(40, 0))
	_enemy("brutamontes", Vector2(-60, 10))
	await _fight(420)

	await _scene("fire_knight")
	await _title("FERRUGEM: PEDRA EM ARCO")
	p.max_hp = 9999
	p.hp = 9999
	var boss: Boss = stage.spawn_enemy(Stage.ENEMIES["ferrugem"], p.position + Vector2(150, 20))
	Sound.music("chefe")
	await _dodge_around(240)
	boss.take_hit(160, false, p)
	await _title("FASE 2: SALTO")
	await _frames(30)
	boss.position = p.position + Vector2(120, 0)
	boss.enter_state(Fighter.State.IDLE)
	boss.start_attack(Boss.LEAP)
	await _dodge_around(150)
	await _fight(200)
	boss.take_hit(maxi(boss.hp - 70, 1), false, p)
	await _frames(20)
	await _title("FASE 3: FÚRIA")
	await _fight(480)
	quit()


func _scene(hero: String) -> void:
	if _main:
		_main.queue_free()
		await _frames(2)
	Characters.selected = hero
	_main = MAIN.instantiate()
	stage = _main.get_node("Stage")
	stage.auto_spawn = false
	root.add_child(_main)
	hud = _main.get_node("HUD/HUDView")
	p = stage.player
	p.input.scripted = true
	p.position = Vector2(150, 168)
	hud._frame = 99999
	await _frames(2)


func _title(text: String) -> void:
	hud._show_banner(text)
	await _frames(10)


func _enemy(name: String, offset: Vector2) -> Enemy:
	return stage.spawn_enemy(Stage.ENEMIES[name], stage.clamp_to_floor(p.position + offset))


func _jump_kick_at(target: Enemy) -> void:
	for i in 120:
		var d := target.position - p.position
		if absf(d.y) > 2.0:
			p.input.move = Vector2(0, signf(d.y))
		elif absf(d.x) > 55.0 or absf(d.x) < 34.0:
			p.input.move = Vector2(signf(d.x) if absf(d.x) > 55.0 else -signf(d.x), 0)
		else:
			break
		await physics_frame
	p.facing = int(signf(target.position.x - p.position.x))
	p.input.move = Vector2(p.facing, 0)
	p.input.press(&"jump")
	await _frames(1)
	p.input.move = Vector2.ZERO
	await _frames(5)
	p.input.press(&"attack")
	await _frames(60)


## Anda de um lado para o outro, desviando dos círculos (para mostrar bomba e salto).
func _dodge_around(frames: int) -> void:
	for f in frames:
		p.input.move = Vector2(0, -1 if (f / 50) % 2 == 0 else 1)
		await physics_frame
	p.input.move = Vector2.ZERO


## O robô do playthrough: mira no mais perto, soca e usa o especial cercado.
func _fight(frames: int) -> void:
	for f in frames:
		await physics_frame
		if p.state == Fighter.State.DEAD:
			continue
		var target = null
		for e in stage.enemies() + stage.breakables():
			if not stage.floor_rect.grow(2).has_point(e.position):
				continue
			if target == null or e.position.distance_to(p.position) < target.position.distance_to(p.position):
				target = e
		if target == null:
			p.input.move = Vector2.ZERO
			continue
		var d: Vector2 = target.position - p.position
		if absf(d.y) > 3:
			p.input.move = Vector2(0, signf(d.y))
		elif absf(d.x) > 26:
			p.input.move = Vector2(signf(d.x), 0)
		elif absf(d.x) < 4:
			p.input.move = Vector2(signf(stage.floor_rect.get_center().x - p.position.x), 0)
		else:
			p.input.move = Vector2.ZERO
			if p.state in [Fighter.State.IDLE, Fighter.State.WALK]:
				p.facing = int(signf(d.x))
			if f % 6 == 0:
				p.input.press(&"attack")
		if f % 240 == 0:
			p.add_meter(60)
		var near := 0
		for e in stage.enemies():
			if e.position.distance_to(p.position) < 50:
				near += 1
		if p.meter >= 50 and near >= 2:
			p.input.press(&"special")


func _frames(count: int) -> void:
	for i in count:
		await physics_frame

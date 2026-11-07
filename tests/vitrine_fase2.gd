extends SceneTree
## Vídeo da fase 2 (Cemitério de Ferro), com som:
##   godot --path . --fixed-fps 60 --write-movie fase2.avi --script res://tests/vitrine_fase2.gd
## 1. Título: a linha "Fase" troca para a 2.
## 2. Vitória da fase 1 com o "Próxima fase" (pontos e vidas passam para a fase 2).
## 3. Começo da fase 2 de verdade (ondas, Sombra apresentada sozinha).
## 4. Curandeira curando um Brutamontes; derrubar ela primeiro.
## 5. Corrosão: guarda e contragolpe, lâmina giratória, investida (fase 2) e fúria com
##    Sombras e chuva de lâminas (fase 3) até a derrota.

const HERO := "crystal_mauler"

var stage: Stage
var p: Player
var hud: Control


func _initialize() -> void:
	_run.call_deferred()
	# Segurança: se algo travar o roteiro, a gravação para sozinha (máx. 4 min).
	var frames := [0]
	process_frame.connect(func() -> void:
		frames[0] += 1
		if frames[0] > 60 * 240:
			quit())


func _run() -> void:
	seed(5)
	Characters.selected = HERO
	# 1. Título.
	Fases.current = 1
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(100)
	await _press("move_down", 40)
	await _press("move_right", 50)
	await _press("move_left", 40)
	await _press("move_right", 60)
	Fases.current = 1
	# 2. Fim da fase 1 com "Próxima fase".
	change_scene_to_file("res://scenes/main.tscn")
	await _stage_ready()
	stage.score = 18450
	await _wait(30)
	stage._clear_stage()
	await _wait(200)
	await _press("attack", 140)
	await _press("attack", 30)
	# 3. Fase 2 de verdade.
	await _stage_ready()
	p.lives = 99
	await _robot(60 * 32, true)
	# 4. Curandeira.
	await _arena()
	_banner("CURANDEIRA: CURA OS ALIADOS")
	var bruto := _enemy("brutamontes", Vector2(60, 0))
	var cura := _enemy("curandeira", Vector2(170, 6))
	cura._cura_cooldown = 60
	await _robot(60 * 7, false, bruto)
	_banner("DERRUBE A CURANDEIRA PRIMEIRO")
	await _robot(60 * 7, false, cura)
	await _robot(60 * 5)
	# 5. Chefe.
	await _arena()
	_banner("CORROSÃO, A LÂMINA ENFERRUJADA")
	var boss: Corrosao = _enemy("corrosao", Vector2(150, 0))
	await _wait(90)
	_banner("GUARDA: SEGURA GOLPES DE FRENTE")
	boss.ai_enabled = false
	await _walk_to(boss.position + Vector2(-34, 0), 120)
	p.facing = 1
	boss.facing = -1
	boss.start_attack(Corrosao.GUARDA)
	for i in 4:
		p.input.press(&"attack")
		await _wait(14)
	await _wait(80)
	_banner("LÂMINA GIRATÓRIA: SAIA DA FAIXA")
	await _walk_to(Vector2(boss.position.x - 130.0, boss.position.y), 120)
	boss.facing = -1
	boss.start_attack(Corrosao.LANCAR)
	await _wait(40)
	for i in 30:
		p.input.move = Vector2(0, 1)
		await physics_frame
	p.input.move = Vector2.ZERO
	await _wait(90)
	boss.ai_enabled = true
	await _robot(60 * 6, false, boss, 0.56)
	_banner("FASE 2: INVESTIDA CORTANTE")
	_hurt_boss(boss, 0.48)
	await _wait(40)
	if is_instance_valid(boss):
		await _walk_to(Vector2(boss.position.x - 120.0, boss.position.y), 60)
		boss.start_attack(Corrosao.INVESTIDA)
	await _wait(90)
	await _robot(60 * 8, false, boss, 0.3)
	_banner("FÚRIA: SOMBRAS E CHUVA DE LÂMINAS")
	_hurt_boss(boss, 0.24)
	await _wait(30)
	if is_instance_valid(boss):
		boss.start_attack(Corrosao.CHUVA)
	await _robot(60 * 10, false, boss, 0.12)
	if is_instance_valid(boss):
		boss.start_attack(Corrosao.CHUVA)
	await _robot(60 * 8, false, boss, 0.05)
	# Termina a luta se o robô não terminou.
	if is_instance_valid(boss) and boss.hp > 0:
		boss.hp = 8
	await _robot(60 * 8, false, boss)
	await _wait(120)
	quit()


# --- Cenas --------------------------------------------------------------------------

func _stage_ready() -> void:
	var old := stage
	await process_frame
	while current_scene == null or not current_scene.has_node("Stage") or current_scene.is_queued_for_deletion() \
			or (is_instance_valid(old) and current_scene.get_node("Stage") == old):
		await process_frame
	await _wait(2)
	stage = current_scene.get_node("Stage")
	p = stage.player
	hud = current_scene.get_node("HUD/HUDView")
	p.input.scripted = true


## Fase 2 sem ondas automáticas, para mostrar um inimigo de cada vez.
func _arena() -> void:
	Fases.current = 2
	Stage.continue_section = 1
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main := scene.instantiate()
	main.get_node("Stage").auto_spawn = false
	var old := current_scene
	root.add_child(main)
	current_scene = main
	if old:
		old.queue_free()
	await _wait(2)
	stage = main.get_node("Stage")
	p = stage.player
	hud = main.get_node("HUD/HUDView")
	hud._frame = 99999
	p.input.scripted = true
	p.lives = 99
	p.position = Vector2(stage.cam_left + 120.0, 168)
	await _wait(30)


func _banner(text: String) -> void:
	hud._show_banner(text)


func _enemy(name: String, offset: Vector2) -> Enemy:
	return stage.spawn_enemy(Stage.ENEMIES[name], stage.clamp_to_floor(p.position + offset))


## Tira vida do chefe sem herói (dano neutro), para chegar na fase seguinte.
func _hurt_boss(boss, ratio: float) -> void:
	if not is_instance_valid(boss):
		return
	var hit := Node2D.new()
	hit.position = boss.position
	var target := int(boss.max_hp * ratio)
	if boss.hp > target:
		boss.take_hit(boss.hp - target, false, hit)
	hit.free()


# --- Robô ---------------------------------------------------------------------------

## O robô do playthrough: mira no mais perto (ou em `focus`), soca, usa o especial
## cercado e esquiva no "!" de vez em quando. `walk`: sem inimigo, anda para a direita.
func _robot(frames: int, walk := false, focus: Enemy = null, floor_ratio := 0.0) -> void:
	for f in frames:
		await physics_frame
		# O chefe não cai antes da hora: o vídeo mostra cada fase.
		if floor_ratio > 0.0 and is_instance_valid(focus) and focus.hp < focus.max_hp * floor_ratio:
			focus.hp = int(focus.max_hp * floor_ratio)
		if not is_instance_valid(p) or p.state == Fighter.State.DEAD:
			continue
		var target = null
		if is_instance_valid(focus) and focus.state != Fighter.State.DEAD and focus.can_be_hit():
			target = focus
		else:
			for e in stage.enemies() + stage.breakables():
				if not stage.floor_rect.grow(2).has_point(e.position):
					continue
				if target == null or e.position.distance_to(p.position) < target.position.distance_to(p.position):
					target = e
		if target == null:
			p.input.move = Vector2(1, 0) if walk else Vector2.ZERO
			continue
		var d: Vector2 = target.position - p.position
		if absf(d.y) > 3:
			p.input.move = Vector2(0, signf(d.y))
		elif absf(d.x) > 28:
			p.input.move = Vector2(signf(d.x), 0)
		elif absf(d.x) < 4:
			p.input.move = Vector2(signf(stage.floor_rect.get_center().x - p.position.x), 0)
		else:
			p.input.move = Vector2.ZERO
			if p.state in [Fighter.State.IDLE, Fighter.State.WALK]:
				p.facing = int(signf(d.x))
			if f % 6 == 0:
				p.input.press(&"attack")
		if f % 300 == 0:
			p.add_meter(50)
		var near := 0
		for e in stage.enemies():
			if e.position.distance_to(p.position) < 50:
				near += 1
		if p.meter >= 50 and near >= 2:
			p.input.press(&"special")
	p.input.move = Vector2.ZERO


func _walk_to(goal: Vector2, limit: int) -> void:
	goal = stage.clamp_to_floor(goal)
	for i in limit:
		var d := goal - p.position
		if d.length() < 3.0:
			break
		p.input.move = Vector2(signf(d.x) if absf(d.x) > 2.0 else 0.0, signf(d.y) if absf(d.y) > 2.0 else 0.0)
		await physics_frame
	p.input.move = Vector2.ZERO


# --- Entrada como jogador (menus) -----------------------------------------------------

func _press(action: String, wait: int) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _wait(3)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(wait)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

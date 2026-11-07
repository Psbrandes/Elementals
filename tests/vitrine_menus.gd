extends SceneTree
## Vídeo do menu, das opções, da pausa e da tela de vitória (com som):
##   godot --path . --fixed-fps 60 --write-movie menus.avi --script res://tests/vitrine_menus.gd
## Navega pelos menus com eventos de ação, como se fosse o jogador, e força a vitória da fase
## com números de exemplo para mostrar a contagem inteira.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(150)
	# Jogar, Fase, Co-op online, Opções...
	for action in ["move_down", "move_down", "move_down"]:
		await _press(action, 20)
	await _press("attack", 30)
	await _press("move_right", 18)
	await _press("move_left", 18)
	await _press("move_down", 18)
	await _press("move_left", 18)
	await _press("move_right", 30)
	await _press("jump", 30)
	await _press("move_down", 20)
	await _press("attack", 150)
	await _press("jump", 25)
	await _press("move_down", 20)
	await _press("attack", 150)
	await _press("jump", 25)
	for action in ["move_up", "move_up", "move_up", "move_up", "move_up"]:
		await _press(action, 12)
	await _press("attack", 70)
	# Seleção: anda dois heróis e confirma.
	await _press("move_right", 30)
	await _press("move_right", 40)
	await _press("attack", 120)
	while current_scene == null or not current_scene.has_node("Stage"):
		await process_frame
	var stage: Stage = current_scene.get_node("Stage")
	await _wait(120)
	await _press("pause", 50)
	await _press("move_down", 20)
	await _press("move_down", 20)
	await _press("attack", 40)
	await _press("move_down", 20)
	await _press("move_left", 30)
	await _press("jump", 30)
	await _press("pause", 60)
	# Fim de jogo: perde a última vida, mostra o menu e continua da seção.
	stage.player.lives = 1
	stage.player.hp = 0
	stage.player.health_changed.emit(0, stage.player.max_hp)
	stage.player._die()
	await _wait(240)
	await _press("move_down", 30)
	await _press("move_up", 30)
	await _press("attack", 10)
	while current_scene == null or not current_scene.has_node("Stage") or current_scene.get_node("Stage") == stage:
		await process_frame
	stage = current_scene.get_node("Stage")
	await _wait(90)
	# Vitória com números de exemplo.
	for enemy in stage.actors.get_children():
		if enemy is Enemy:
			enemy.queue_free()
	stage.kills = 41
	stage.best_combo = 23
	stage.player.deaths = 1
	stage._frames = 60 * 251
	stage._clear_stage()
	await _wait(560)
	await _press("move_down", 30)
	await _press("move_down", 30)
	await _press("move_up", 60)
	quit()


func _press(action: String, then_wait: int) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _wait(4)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(then_wait)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

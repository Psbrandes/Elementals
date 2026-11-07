extends SceneTree
## Robô que joga a fase inteira: anda, mira no inimigo mais perto, soca e usa o
## especial quando está cercado. Serve para achar travas (fase que não termina)
## e erros de execução. Com janela (sem --headless), salva screenshots em
## user://shots ou na pasta passada depois de "--".
##   godot --headless --path . --fixed-fps 60 --script res://tests/playthrough.gd
##   godot --path . --fixed-fps 60 --script res://tests/playthrough.gd -- /tmp/shots
## Modo vitrine (para vídeo de um herói): -- <pasta> <id do herói> <segundos>.
## Joga só esses segundos e enche a barra de vez em quando para mostrar o especial.

const MAIN := preload("res://scenes/main.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _shots_dir() -> String:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if not args.is_empty() else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


func _run() -> void:
	seed(42)
	var args := OS.get_cmdline_user_args()
	var showcase := args.size() >= 3
	var limit := 60 * 60 * 8
	if showcase:
		Characters.selected = args[1]
		limit = int(args[2]) * 60
	var main := MAIN.instantiate()
	root.add_child(main)
	var stage: Stage = main.get_node("Stage")
	var p: Player = stage.player
	p.input.scripted = true
	p.lives = 99
	var deaths := 0
	var was_dead := false
	var shot_at := {}
	var f := 0
	while f < limit and not stage.cleared:
		f += 1
		await physics_frame
		if p.state == Fighter.State.DEAD:
			if not was_dead: deaths += 1
			was_dead = true
			continue
		was_dead = false
		var targets: Array = stage.enemies() + stage.breakables()
		var target = null
		for e in targets:
			if not stage.floor_rect.grow(2).has_point(e.position): continue
			if target == null or e.position.distance_to(p.position) < target.position.distance_to(p.position): target = e
		if target == null:
			p.input.move = Vector2(1, 0)
		else:
			var d: Vector2 = target.position - p.position
			if absf(d.y) > 3: p.input.move = Vector2(0, signf(d.y))
			elif absf(d.x) > 26: p.input.move = Vector2(signf(d.x), 0)
			elif absf(d.x) < 4: p.input.move = Vector2(signf(stage.floor_rect.get_center().x - p.position.x), 0)
			else:
				p.input.move = Vector2.ZERO
				if p.state in [Fighter.State.IDLE, Fighter.State.WALK]: p.facing = int(signf(d.x))
				if f % 6 == 0: p.input.press(&"attack")
			var near := 0
			for e in stage.enemies(): if e.position.distance_to(p.position) < 50: near += 1
			if showcase and f % 360 == 0: p.add_meter(100)
			if p.meter >= 50 and near >= (1 if showcase else 2): p.input.press(&"special")
		if f % 600 == 0:
			print("t=%ds cam=%d sec=%d wave=%d hp=%d lives=%d score=%d enemies=%d" % [f/60, stage.cam_left, stage.section, stage.wave, p.hp, p.lives, stage.score, stage.enemies().size()])
		var key := ""
		if stage.section == 1 and stage.locked and not shot_at.has("s2") and stage.enemies().size() >= 3: key = "s2"
		elif stage.section == 0 and stage.locked and not shot_at.has("s1") and stage.enemies().size() >= 3: key = "s1"
		elif is_instance_valid(stage.boss) and stage.boss.phase == 2 and not shot_at.has("boss"): key = "boss"
		elif stage.section == 2 and stage.locked and not shot_at.has("s3") and stage.enemies().size() >= 3 and not is_instance_valid(stage.boss): key = "s3"
		if key != "" and not showcase and DisplayServer.get_name() != "headless":
			shot_at[key] = f
			await process_frame
			root.get_texture().get_image().save_png(_shots_dir().path_join("fase_%s.png" % key))
		elif key != "": shot_at[key] = f
	print("FIM t=%ds cleared=%s deaths=%d score=%d" % [f/60, stage.cleared, deaths, stage.score])
	if DisplayServer.get_name() != "headless" and not showcase:
		for i in 30: await physics_frame
		await process_frame
		root.get_texture().get_image().save_png(_shots_dir().path_join("fase_resultado.png"))
	quit()

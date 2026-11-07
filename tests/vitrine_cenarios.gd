extends SceneTree
## Fotos dos 5 cenários (ferro-velho e os 4 elementais): para cada bioma, abre a fase com um herói e
## alguns inimigos e tira foto em 3 pontos (começo, meio e arena do chefe).
##   godot --path . --script res://tests/vitrine_cenarios.gd -- /tmp/fotos [bioma...]

const MAIN := preload("res://scenes/main.tscn")
const SPOTS := [150.0, 1500.0, 2700.0]
const HEROES := {"ferro_velho": "metal_bladekeeper", "terra": "ground_monk", "deserto": "wind_hashashin", "natureza": "leaf_ranger", "vulcao": "fire_knight"}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/fotos"
	var biomes: Array = args.slice(1) if args.size() > 1 else StageScenery.ORDER
	DirAccess.make_dir_recursive_absolute(out)
	for id: String in biomes:
		StageScenery.biome = id
		Characters.selected = HEROES[id]
		var main := MAIN.instantiate()
		var stage: Stage = main.get_node("Stage")
		stage.auto_spawn = false
		root.add_child(main)
		main.get_node("HUD").visible = false
		for prop in [{"kind": "barril", "x": 250.0, "y": 140.0, "item": ""}, {"kind": "caixa", "x": 1580.0, "y": 140.0, "item": ""},
				{"kind": "barril", "x": 2790.0, "y": 140.0, "item": ""}, {"kind": "caixa", "x": 2830.0, "y": 145.0, "item": ""}]:
			stage._spawn_breakable(prop)
		var p := stage.player
		p.input.scripted = true
		for i in SPOTS.size():
			stage.cam_left = SPOTS[i]
			p.position = Vector2(SPOTS[i] + 150.0, 172.0)
			p.facing = 1
			for e in stage.enemies():
				e.queue_free()
			stage.spawn_enemy(Stage.ENEMIES["capanga"], Vector2(SPOTS[i] + 250.0, 150.0))
			stage.spawn_enemy(Stage.ENEMIES["brigao" if i != 2 else "ferrugem"], Vector2(SPOTS[i] + 300.0, 185.0))
			for f in 40:
				await process_frame
			var img := root.get_texture().get_image()
			img.save_png("%s/%s_%d.png" % [out, id, i + 1])
			print("foto ", id, " ", i + 1)
		main.queue_free()
		for f in 3:
			await process_frame
	quit()

extends SceneTree
## Vitrine dos especiais (antes/depois), um herói por vez, com um inimigo na frente:
##   godot --path . --resolution 1152x648 --fixed-fps 60 --write-movie /tmp/e/f.png \
##     --script res://tests/especiais_showcase.gd -- DEPOIS [id_do_heroi]
## Mostra o especial (L) e o especial secundário (baixo + L).

const MAIN := preload("res://scenes/main.tscn")
const CAPANGA := preload("res://data/enemies/capanga.tres")

var stage: Stage
var p: Player
var tag := ""
var only := ""
var label: Label


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	tag = args[0] if args.size() > 0 else ""
	only = args[1] if args.size() > 1 else ""
	_run.call_deferred()


func _run() -> void:
	seed(7)
	await process_frame
	for c: Dictionary in Characters.LIST:
		var id: String = c["id"]
		if only != "" and id != only:
			continue
		Characters.selected = id
		var main := MAIN.instantiate()
		main.get_node("Stage").auto_spawn = false
		root.add_child(main)
		stage = main.get_node("Stage")
		_add_label(main)
		p = stage.player
		p.input.scripted = true
		p.position = Vector2(150, 168)
		var e := _enemy(Vector2(40, 0), 9000)
		await _wait(30)
		print("SEG ", id, " ", Engine.get_frames_drawn())
		label.text = "%s   %s\nespecial (L)" % [tag, c["name"]]
		p.add_meter(Player.METER_MAX)
		p.input.press(&"special")
		await _wait(150)
		await _reset_enemy(e)
		label.text = "%s   %s\nespecial 2 (baixo + L)" % [tag, c["name"]]
		p.add_meter(Player.METER_MAX)
		p.input.move = Vector2(0, 1)
		p.input.press(&"special")
		await _wait(2)
		p.input.move = Vector2.ZERO
		await _wait(120)
		main.queue_free()
		await _wait(2)
	quit()


func _add_label(main: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	label = Label.new()
	label.position = Vector2(6, 148)
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(label)
	main.add_child(layer)


func _reset_enemy(e: Enemy) -> void:
	await _until(func() -> bool: return e.state == Fighter.State.IDLE and p.state == Fighter.State.IDLE, 240)
	p.position = Vector2(150, 168)
	p.facing = 1
	e.position = p.position + Vector2(40, 0)
	e.hp = e.max_hp
	await _wait(20)


func _enemy(offset: Vector2, hp: int) -> Enemy:
	var foe := stage.spawn_enemy(CAPANGA, p.position + offset)
	foe.ai_enabled = false
	foe.max_hp = hp
	foe.hp = hp
	return foe


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _until(condition: Callable, limit: int) -> void:
	for i in limit:
		if condition.call():
			return
		await physics_frame

extends SceneTree
## Vitrine do ritmo dos golpes (antes/depois):
##   godot --path . --fixed-fps 60 --write-movie /tmp/r/f.png --script res://tests/ritmo_showcase.gd -- ANTES
## Para cada herói: combo J J J no ritmo, J J J apertando rápido e o especial.

const MAIN := preload("res://scenes/main.tscn")
const CAPANGA := preload("res://data/enemies/capanga.tres")
const HEROES := ["fire_knight", "crystal_mauler", "ground_monk", "water_priestess"]

var stage: Stage
var p: Player
var hud: Control
var tag := ""
var label: Label


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	tag = args[0] if args.size() > 0 else ""
	_run.call_deferred()


func _run() -> void:
	seed(7)
	await process_frame
	for id in HEROES:
		Characters.selected = id
		var main := MAIN.instantiate()
		main.get_node("Stage").auto_spawn = false
		root.add_child(main)
		stage = main.get_node("Stage")
		hud = main.get_node("HUD/HUDView")
		_add_label(main)
		p = stage.player
		p.input.scripted = true
		p.position = Vector2(150, 168)
		p.add_meter(Player.METER_MAX)
		var e := _enemy(Vector2(26, 0), 900)
		await _wait(30)
		print("SEG ", Engine.get_frames_drawn())
		label.text = "%s   %s\nJ J J no ritmo" % [tag, Characters.get_data(id)["name"]]
		for i in 3:
			p.input.press(&"attack")
			await _wait(16)
		await _wait(70)
		await _reset_enemy(e)
		print("SEG ", Engine.get_frames_drawn())
		label.text = "%s   %s\nJ J J apertando rápido" % [tag, Characters.get_data(id)["name"]]
		for i in 9:
			p.input.press(&"attack")
			await _wait(4)
		await _wait(70)
		await _reset_enemy(e)
		print("SEG ", Engine.get_frames_drawn())
		label.text = "%s   %s\nespecial (L)" % [tag, Characters.get_data(id)["name"]]
		p.add_meter(Player.METER_MAX)
		p.input.press(&"special")
		await _wait(110)
		main.queue_free()
		await _wait(2)
	print("SEG ", Engine.get_frames_drawn())
	quit()


func _add_label(main: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	label = Label.new()
	label.position = Vector2(16, 540)
	label.add_theme_font_size_override(&"font_size", 30)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 8)
	layer.add_child(label)
	main.add_child(layer)


func _reset_enemy(e: Enemy) -> void:
	await _until(func() -> bool: return e.state == Fighter.State.IDLE and p.state == Fighter.State.IDLE, 240)
	e.position = p.position + Vector2(26 * p.facing, 0)
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

extends SceneTree
## Vitrine da movimentação para gravar vídeo: o robô mostra cada movimento com
## uma legenda. Para gravar (precisa de janela; no servidor, use xvfb-run):
##   godot --path . --fixed-fps 60 --write-movie /tmp/mov.avi --script res://tests/demo_movement.gd

const MAIN := preload("res://scenes/main.tscn")
const CAPANGA := preload("res://data/enemies/capanga.tres")

var stage: Stage
var p: Player
var caption: Label


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(7)
	Characters.selected = "fire_knight"
	var main := MAIN.instantiate()
	stage = main.get_node("Stage")
	stage.auto_spawn = false
	root.add_child(main)
	p = stage.player
	p.input.scripted = true
	p.lives = 99
	_make_caption()
	await _frames(30)

	await _say("Andar: acelera e para rápido")
	p.input.move = Vector2(1, 0)
	await _frames(45)
	p.input.move = Vector2.ZERO
	await _frames(20)
	p.input.move = Vector2(0, -1)
	await _frames(20)
	p.input.move = Vector2.ZERO
	await _frames(25)

	await _say("Corrida: frente, frente e segura")
	await _double_tap(1)
	await _frames(60)
	await _say("Soltou: derrapa")
	p.input.move = Vector2.ZERO
	await _frames(40)

	await _say("Correndo + soco: investida")
	_spawn(Vector2(150, 0))
	_spawn(Vector2(175, 0))
	await _double_tap(1)
	await _frames(30)
	p.input.press(&"attack")
	await _frames(2)
	p.input.move = Vector2.ZERO
	await _frames(70)
	_clear()

	await _say("Rolamento (Shift): atravessa o golpe")
	var e := _spawn(Vector2(40, 0), true)
	await _until(func() -> bool: return e.state == Fighter.State.ATTACK, 240)
	await _frames(1)
	p.input.move = Vector2(1, 0)
	p.input.press(&"dodge")
	await _frames(2)
	p.input.move = Vector2.ZERO
	await _frames(24)
	p.facing = -1
	p.input.move = Vector2(-1, 0)
	await _frames(1)
	p.input.move = Vector2.ZERO
	for i in 3:
		p.input.press(&"attack")
		await _frames(14)
	await _frames(50)
	_clear()

	await _say("Esquiva + cima/baixo: passo lateral")
	p.input.move = Vector2(0, -1)
	p.input.press(&"dodge")
	await _frames(2)
	p.input.move = Vector2.ZERO
	await _frames(28)
	p.input.move = Vector2(0, 1)
	p.input.press(&"dodge")
	await _frames(2)
	p.input.move = Vector2.ZERO
	await _frames(28)
	p.input.press(&"dodge")
	await _frames(40)

	await _say("Pulo: toque curto pula baixo")
	await _jump(false)
	await _frames(20)
	await _say("Segurando, pula alto")
	await _jump(true)
	await _frames(20)

	await _say("Controle no ar")
	p.input.press(&"jump")
	await _frames(6)
	p.input.move = Vector2(1, 0)
	await _frames(14)
	p.input.move = Vector2(-1, 0)
	await _frames(14)
	p.input.move = Vector2.ZERO
	await _frames(30)

	await _say("Pulo da corrida vai longe")
	await _double_tap(1)
	await _frames(20)
	p.input.press(&"jump")
	await _frames(12)
	p.input.press(&"attack")
	await _until(func() -> bool: return p.state != Fighter.State.JUMP, 90)
	await _frames(25)
	p.input.move = Vector2.ZERO
	await _frames(30)

	await _say("Agarrão + pulo: salta por cima...")
	var g := _spawn(Vector2(40, 0))
	p.input.move = Vector2(1, 0)
	await _until(func() -> bool: return p.state == Fighter.State.GRAB, 60)
	p.input.move = Vector2.ZERO
	await _frames(15)
	p.input.press(&"jump")
	await _frames(PlayerMovement.VAULT_FRAMES + 12)
	await _say("...e soco: suplex!")
	p.input.press(&"attack")
	await _frames(14)
	p.input.press(&"attack")
	await _frames(16)
	p.input.move = Vector2(1, 0)
	p.input.press(&"attack")
	await _frames(1)
	p.input.move = Vector2.ZERO
	await _frames(90)
	_clear()

	await _say("Agarrão pelas costas: suplex direto")
	var b := _spawn(Vector2(60, 0))
	b.facing = 1
	p.input.move = Vector2(1, 0)
	await _until(func() -> bool: return p.state == Fighter.State.GRAB, 60)
	p.input.move = Vector2.ZERO
	await _frames(15)
	p.input.move = Vector2(1, 0)
	p.input.press(&"attack")
	await _frames(1)
	p.input.move = Vector2.ZERO
	await _frames(100)
	quit()


func _make_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(0, 30)
	caption.size = Vector2(384, 20)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override(&"font_size", 12)
	caption.add_theme_color_override(&"font_color", Color("ffe9a8"))
	caption.add_theme_color_override(&"font_outline_color", Color.BLACK)
	caption.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(caption)


func _say(text: String) -> void:
	caption.text = text
	await _frames(20)


func _spawn(offset: Vector2, ai := false) -> Enemy:
	var enemy := stage.spawn_enemy(CAPANGA, p.position + offset)
	enemy.ai_enabled = ai
	return enemy


func _clear() -> void:
	for enemy: Enemy in stage.enemies():
		if enemy.state != Fighter.State.DEAD:
			enemy.queue_free()


func _double_tap(dir: int) -> void:
	p.input.move = Vector2(dir, 0)
	await _frames(3)
	p.input.move = Vector2.ZERO
	await _frames(3)
	p.input.move = Vector2(dir, 0)
	await _frames(2)


func _jump(held: bool) -> void:
	p.input.press(&"jump")
	await _frames(2)
	p.input.jump_held = held
	await _until(func() -> bool: return p.state != Fighter.State.JUMP, 90)
	p.input.jump_held = true


func _until(condition: Callable, limit: int) -> void:
	for i in limit:
		if condition.call():
			return
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame

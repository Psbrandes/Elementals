extends SceneTree
## Vitrine dos golpes próprios: cada um dos 7 heróis mostra o golpe de virada,
## o carregado, o especial secundário, o golpe aéreo e o especial, e no fim dois
## heróis soltam um ataque em dupla. Feito para gravar vídeo:
##   godot --path . --fixed-fps 60 --write-movie /tmp/golpes.avi --script res://tests/showcase_moves.gd
## Argumento opcional depois de "--": ids dos heróis separados por vírgula.

const MAIN := preload("res://scenes/main.tscn")
const CAPANGA := preload("res://data/enemies/capanga.tres")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var stage: Stage
var player: Player
var hud: Control
var caption: Label
var _main: Node


func _initialize() -> void:
	# 16:9 fixo: sem gerenciador de janelas (gravação no Xvfb) a janela pode vir com outra proporção.
	DisplayServer.window_set_size(Vector2i(1152, 648))
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_run.call_deferred()


func _run() -> void:
	seed(7)
	var ids: Array = []
	for c: Dictionary in Characters.LIST:
		ids.append(c["id"])
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		ids = Array(args[0].split(","))
	for id: String in ids:
		await _hero_reel(id)
	if args.is_empty() or args.size() > 1:
		await _team_reel("fire_knight", "wind_hashashin")
	quit()


func _open(id: String) -> void:
	Characters.selected = id
	_main = MAIN.instantiate()
	stage = _main.get_node("Stage")
	stage.auto_spawn = false
	root.add_child(_main)
	player = stage.player
	player.input.scripted = true
	player.position = Vector2(170, 168)
	hud = _main.get_node("HUD/HUDView")
	caption = Label.new()
	caption.position = Vector2(6, 186)
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 3)
	_main.get_node("HUD").add_child(caption)
	await _frames(2)


func _close() -> void:
	_main.queue_free()
	await _frames(2)


func _enemy(at: Vector2) -> Enemy:
	var e := stage.spawn_enemy(CAPANGA, at)
	e.ai_enabled = false
	e.max_hp = 500
	e.hp = 500
	return e


func _hero_reel(id: String) -> void:
	await _open(id)
	var c := Characters.get_data(id)
	await _frames(3)
	hud._show_banner("%s, %s" % [c["name"].to_upper(), c["title"].to_upper()])
	var e1 := _enemy(Vector2(230, 168))
	var e2 := _enemy(Vector2(110, 168))
	var e3 := _enemy(Vector2(300, 176))
	player.add_meter(100)
	await _frames(70)

	# 1. Trás + J: inimigo atrás.
	await _approach(e2.position + Vector2(26, 0))
	player.facing = 1
	await _frames(14)
	_say("Trás + J: " + player.hero_move("back")["label"])
	player.input.move = Vector2(-1, 0)
	player.input.press(&"attack")
	await _frames(2)
	player.input.move = Vector2.ZERO
	await _frames(60)

	# 2. Segurar J e soltar.
	var target := _nearest_standing([e1, e2, e3])
	await _approach(target.position + Vector2(-28, 0))
	player.facing = 1
	_say("Segure J e solte: " + player.hero_move("charged")["label"])
	player.input.attack_held = true
	player.input.press(&"attack")
	await _frames(HeroMoves.CHARGE_FRAMES + 16)
	player.input.attack_held = false
	await _frames(70)

	# 3. Baixo + L (Metal: alguém ataca durante a postura).
	player.add_meter(100)
	target = _nearest_standing([e1, e2, e3])
	var counter: bool = player.hero_move("special2").get("counter", false)
	await _approach(target.position + Vector2(-(30 if counter else 50), 0))
	player.facing = 1
	_say("Baixo + L: " + player.hero_move("special2")["label"])
	player.input.move = Vector2(0, 1)
	player.input.press(&"special")
	await _frames(1)
	player.input.move = Vector2.ZERO
	if counter:
		await _frames(4)
		target.facing = -1
		target.start_attack(target._melee)
	await _frames(80)

	# 4. No ar: baixo + J.
	target = _nearest_standing([e1, e2, e3])
	await _approach(target.position + Vector2(-50, 0))
	player.facing = 1
	_say("No ar, baixo + J: " + player.hero_move("air")["label"])
	player.input.press(&"jump")
	await _frames(12)
	player.input.move = Vector2(0, 1)
	player.input.press(&"attack")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(80)

	# 5. O especial de sempre, para comparar.
	player.add_meter(100)
	target = _nearest_standing([e1, e2, e3])
	await _approach(target.position + Vector2(-30, 0))
	player.facing = 1
	_say("L: especial do elemento")
	player.input.press(&"special")
	await _frames(90)
	_say("")
	await _close()


func _team_reel(a: String, b: String) -> void:
	await _open(a)
	var partner: Player = PLAYER_SCENE.instantiate()
	partner.stage = stage
	partner.input.scripted = true
	partner.position = player.position + Vector2(40, 8)
	stage.actors.add_child(partner)
	partner.set_character(b)
	await _frames(3)
	hud._show_banner("ATAQUE EM DUPLA")
	var foes := [_enemy(Vector2(120, 160)), _enemy(Vector2(260, 168)), _enemy(Vector2(300, 176)),
		_enemy(Vector2(90, 176))]
	for e: Enemy in foes:
		e.hp = 60
	player.add_meter(100)
	partner.add_meter(100)
	await _frames(80)
	_say("Os dois apertam L juntos: fusão dos elementos")
	await _frames(30)
	player.input.press(&"special")
	await _frames(4)
	partner.input.press(&"special")
	await _frames(150)
	_say("")
	await _close()


func _nearest_standing(list: Array) -> Enemy:
	var best: Enemy = null
	for e: Enemy in list:
		if not is_instance_valid(e) or e.state == Fighter.State.DEAD:
			continue
		if best == null or e.position.distance_to(player.position) < best.position.distance_to(player.position):
			best = e
	return best


## Anda até o ponto (primeiro a profundidade, depois a horizontal), sem encostar para não agarrar.
func _approach(goal: Vector2) -> void:
	goal = stage.clamp_to_floor(goal)
	for i in 120:
		if player.state not in [Fighter.State.IDLE, Fighter.State.WALK]:
			player.input.move = Vector2.ZERO
			await _frames(1)
			continue
		var d := goal - player.position
		if absf(d.y) > 2.0:
			player.input.move = Vector2(0, signf(d.y))
		elif absf(d.x) > 2.0:
			player.input.move = Vector2(signf(d.x), 0)
		else:
			break
		await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(1)


func _say(text: String) -> void:
	caption.text = text


func _frames(count: int) -> void:
	for i in count:
		await physics_frame

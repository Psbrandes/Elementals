extends Control
## Sala do co-op online. Criar sala (host) ou entrar pelo IP; dentro da sala cada
## jogador escolhe o herói (setas), marca pronto (J) e o host começa a fase
## quando todos estão prontos. K (ou Esc) volta.

enum Mode { MENU, JOIN, ROOM }

const TITLE_SCENE := "res://scenes/title.tscn"
const MENU := ["Criar sala (host)", "Entrar numa sala", "Voltar"]
const START_DELAY := 45
const PORTRAIT_HEIGHT := 40.0
const IDLE_TICKS := 7

var mode := Mode.MENU
var _font: Font
var _frame := 0
var _cursor := 0
var _hero := 0
var _is_ready := false
var _countdown := 0
var _status := ""
var _address: LineEdit
var _name: LineEdit


func _ready() -> void:
	_font = ThemeDB.fallback_font
	Sound.music("titulo")
	_hero = maxi(Characters.index_of(Characters.selected), 0)
	_address = _make_edit("127.0.0.1", Vector2(150, 92))
	_name = _make_edit(Net.auto.get("name", "Jogador"), Vector2(150, 76))
	_name.max_length = 12
	_address.text_submitted.connect(func(_t: String) -> void: _connect())
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.connection_failed.connect(func(reason: String) -> void:
		_status = reason
		_set_mode(Mode.MENU if not Net.active else mode))
	if Net.active:
		# Voltando da fase concluída: continua na mesma sala.
		_is_ready = false
		_set_mode(Mode.ROOM)
	else:
		_set_mode(Mode.MENU)
		_status = Net.last_error
	if Net.auto.has("net-host") and not Net.active:
		_host()
	elif Net.auto.has("net-join") and not Net.active:
		_address.text = Net.auto["net-join"]
		_connect()


func _make_edit(text: String, pos: Vector2) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.position = pos
	edit.size = Vector2(120, 14)
	edit.add_theme_font_size_override(&"font_size", 8)
	edit.visible = false
	add_child(edit)
	return edit


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_address.visible = mode == Mode.JOIN
	_name.visible = mode != Mode.ROOM
	if mode == Mode.JOIN:
		_address.grab_focus()
	else:
		_address.release_focus()
		_name.release_focus()


func _process(_delta: float) -> void:
	_frame += 1
	if mode == Mode.ROOM and Net.auto.has("bot") and not _is_ready and Net.lobby.has(Net.my_id()):
		_is_ready = true
		Net.set_choice(Characters.LIST[_hero]["id"], true)
	if Net.is_host() and mode == Mode.ROOM:
		var wanted := int(Net.auto.get("players", "2"))
		var can_start := Net.all_ready() and (not Net.auto.has("net-host") or Net.lobby.size() >= wanted)
		if can_start:
			_countdown += 1
			if _countdown >= int(Net.auto.get("start-delay", str(START_DELAY))):
				_countdown = 0
				Net.start_match(0)
		else:
			_countdown = 0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	match mode:
		Mode.MENU:
			_input_menu(event)
		Mode.JOIN:
			if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
				_set_mode(Mode.MENU)
		Mode.ROOM:
			_input_room(event)


func _input_menu(event: InputEvent) -> void:
	if _name.has_focus():
		if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_down"):
			_name.release_focus()
		return
	if event.is_action_pressed(&"move_up"):
		_cursor = (_cursor + MENU.size() - 1) % MENU.size()
		Sound.play("menu_move", -6.0, 0.0)
	elif event.is_action_pressed(&"move_down"):
		_cursor = (_cursor + 1) % MENU.size()
		Sound.play("menu_move", -6.0, 0.0)
	elif event.is_action_pressed(&"attack") or event.is_action_pressed(&"ui_accept"):
		Sound.play("menu_ok", -4.0, 0.0)
		match _cursor:
			0:
				_host()
			1:
				_status = ""
				_set_mode(Mode.JOIN)
			2:
				get_tree().change_scene_to_file(TITLE_SCENE)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"pause"):
		get_tree().change_scene_to_file(TITLE_SCENE)


func _input_room(event: InputEvent) -> void:
	var count := Characters.LIST.size()
	if event.is_action_pressed(&"pause") or (event.is_action_pressed(&"jump") and not _is_ready):
		Net.leave()
		Sound.play("menu_back", -4.0, 0.0)
		_status = ""
		_set_mode(Mode.MENU)
		return
	if event.is_action_pressed(&"dodge") and Net.is_host():
		var order: Array = StageScenery.ORDER
		StageScenery.biome = order[(order.find(StageScenery.biome) + 1) % order.size()]
		Sound.play("menu_move", -6.0, 0.0)
		return
	if event.is_action_pressed(&"jump") and _is_ready:
		_is_ready = false
	elif event.is_action_pressed(&"attack") or event.is_action_pressed(&"ui_accept"):
		_is_ready = not _is_ready
		Sound.play("menu_ok", -4.0, 0.0)
	elif not _is_ready and event.is_action_pressed(&"move_left"):
		_hero = (_hero + count - 1) % count
		Sound.play("menu_move", -6.0, 0.0)
	elif not _is_ready and event.is_action_pressed(&"move_right"):
		_hero = (_hero + 1) % count
		Sound.play("menu_move", -6.0, 0.0)
	else:
		return
	Net.set_choice(Characters.LIST[_hero]["id"], _is_ready)


func _host() -> void:
	if Net.host(_player_name(), Net.port) == OK:
		_is_ready = false
		_set_mode(Mode.ROOM)
	_status = Net.last_error


func _connect() -> void:
	var address := _address.text.strip_edges()
	if address == "":
		return
	if Net.join(address, _player_name(), Net.port) == OK:
		_status = "Conectando em %s..." % address
		_is_ready = false
		_set_mode(Mode.ROOM)
	else:
		_status = Net.last_error


func _player_name() -> String:
	var text := _name.text.strip_edges()
	return text if text != "" else "Jogador"


func _on_lobby_changed() -> void:
	if not Net.active:
		_set_mode(Mode.MENU)
		_status = Net.last_error
		return
	if Net.lobby.has(Net.my_id()):
		_status = ""


# --- Desenho ----------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1d2b53"))
	_text_center("JOGO ONLINE (CO-OP)", Vector2(size.x / 2.0, 16.0), 12, Color("ffcc33"))
	match mode:
		Mode.MENU:
			_draw_menu()
		Mode.JOIN:
			_draw_join()
		Mode.ROOM:
			_draw_room()
	if _status != "":
		_text_center(_status, Vector2(size.x / 2.0, size.y - 18.0), 7, Color("ff9a7a"))


func _draw_menu() -> void:
	_text("Seu nome", Vector2(90, 86), 8, Color(1, 1, 1, 0.7))
	for i in MENU.size():
		var selected := i == _cursor
		var color := Color.WHITE if selected else Color(1, 1, 1, 0.5)
		_text_center(("> %s <" if selected else "%s") % MENU[i], Vector2(size.x / 2.0, 120.0 + i * 14.0), 9, color)
	_text_center("De 2 a 4 jogadores. Mesma rede, Tailscale/VPN, ou porta %d (UDP) liberada no host." % Net.port,
		Vector2(size.x / 2.0, 34.0), 6, Color(1, 1, 1, 0.55))
	_text_center("Setas escolhem   J confirma   K volta", Vector2(size.x / 2.0, size.y - 5.0), 7, Color(1, 1, 1, 0.55))


func _draw_join() -> void:
	_text("Seu nome", Vector2(90, 86), 8, Color(1, 1, 1, 0.7))
	_text("IP do host", Vector2(90, 102), 8, Color(1, 1, 1, 0.7))
	_text_center("Digite o IP do host (ou IP:porta) e aperte Enter", Vector2(size.x / 2.0, 130.0), 7, Color.WHITE)
	_text_center("Esc volta", Vector2(size.x / 2.0, size.y - 5.0), 7, Color(1, 1, 1, 0.55))


func _draw_room() -> void:
	if Net.is_host():
		var ips: Array = Net.local_addresses()
		var ip_text: String = ", ".join(ips.slice(0, 2)) if not ips.is_empty() else "127.0.0.1"
		_text_center("Você é o host. IP: %s   porta %d" % [ip_text, Net.port], Vector2(size.x / 2.0, 30.0), 7,
			Color(1, 1, 1, 0.8))
	elif Net.lobby.is_empty():
		_text_center("Conectando...", Vector2(size.x / 2.0, 30.0), 8, Color.WHITE)
	var order: Array = Net.peers_in_order()
	var slot_w := (size.x - 16.0) / Net.MAX_PLAYERS
	for i in Net.MAX_PLAYERS:
		var cell := Rect2(Vector2(8.0 + i * slot_w, 40.0), Vector2(slot_w, 112.0)).grow(-3.0)
		draw_rect(cell, Color(0, 0, 0, 0.25))
		_text_center("P%d" % (i + 1), Vector2(cell.get_center().x, cell.position.y + 10.0), 8, Color(1, 1, 1, 0.6))
		if i >= order.size():
			_text_center("vaga livre", Vector2(cell.get_center().x, cell.get_center().y), 7, Color(1, 1, 1, 0.3))
			continue
		var id: int = order[i]
		var info: Dictionary = Net.lobby[id]
		var mine := id == Net.my_id()
		var hero_id: String = Characters.LIST[_hero]["id"] if mine else info["hero"]
		var data := Characters.get_data(hero_id)
		draw_rect(cell, Color(data["color"], 0.22 if mine else 0.1))
		if mine:
			draw_rect(cell, data["color"] if _frame % 30 < 22 else Color.WHITE, false, 1.0)
		var anim := "atk1" if info["ready"] else "idle"
		var frames := _frames(hero_id, anim)
		var index := (_frame / 4) % frames if info["ready"] else _frame / IDLE_TICKS
		_draw_character(hero_id, anim, index, Vector2(cell.get_center().x, cell.position.y + 68.0))
		_text_center(info["name"], Vector2(cell.get_center().x, cell.position.y + 21.0), 7, Color.WHITE)
		_text_center(data["name"].to_upper(), Vector2(cell.get_center().x, cell.position.y + 80.0), 8, data["color"])
		if mine and not _is_ready:
			_text_center("<          >", Vector2(cell.get_center().x, cell.position.y + 50.0), 8, Color.WHITE)
		var ready_text := "PRONTO" if info["ready"] else "escolhendo"
		_text_center(ready_text, Vector2(cell.get_center().x, cell.position.y + 96.0), 8,
			Color("6cc04a") if info["ready"] else Color(1, 1, 1, 0.5))
	if Net.is_host():
		var biome := StageScenery.data()
		_text_center("Cenário: %s   (Shift troca)" % biome["name"], Vector2(size.x / 2.0, 166.0), 7, biome["color"])
	else:
		_text_center("O host escolhe o cenário", Vector2(size.x / 2.0, 166.0), 7, Color(1, 1, 1, 0.4))
	var hint := "Setas trocam o herói   J pronto   K sai da sala"
	if Net.all_ready():
		hint = "Começando..." if _frame % 30 < 20 else ""
	elif Net.lobby.size() < 2:
		hint = "Esperando mais jogadores (mínimo 2)   " + hint
	_text_center(hint, Vector2(size.x / 2.0, size.y - 5.0), 7, Color(1, 1, 1, 0.55))


func _frames(id: String, anim: String) -> int:
	var real := Characters.resolve_anim(id, anim)
	return int(Characters.meta(id)["anims"][real]["frames"])


func _draw_character(id: String, anim: String, index: int, feet: Vector2) -> void:
	var meta := Characters.meta(id)
	var real := Characters.resolve_anim(id, anim)
	var count := _frames(id, real)
	var frame_size := Vector2(meta["frame_size"][0], meta["frame_size"][1])
	var anchor := Vector2(meta["anchor"][0], meta["anchor"][1])
	var scale := minf(1.0, PORTRAIT_HEIGHT / float(meta["height"]))
	var columns := int(meta["columns"])
	var cell := index % count
	var source := Rect2(Vector2(frame_size.x * (cell % columns), frame_size.y * (cell / columns)), frame_size)
	draw_texture_rect_region(Characters.texture(id, real), Rect2(feet - anchor * scale, frame_size * scale), source)


func _text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_center(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(_font, pos - Vector2(300.0, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, 600.0, font_size, color)

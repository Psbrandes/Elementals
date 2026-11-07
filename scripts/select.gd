extends Control
## Seleção de personagem: grade 4x2 com os 7 Elementals. Setas escolhem,
## J confirma, L troca a dificuldade e K (ou Esc) volta ao título.

const MAIN_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const COLUMNS := 4
const CELL := Vector2(88.0, 62.0)
const GRID_ORIGIN := Vector2(16.0, 22.0)
const PORTRAIT_HEIGHT := 44.0
const IDLE_TICKS := 7
## Barras de atributo: [rótulo, chave, valor mínimo, valor máximo].
const STATS := [["Vida", "hp", 70.0, 150.0], ["Velocidade", "speed", 0.7, 1.3], ["Força", "power", 0.8, 1.3]]

var _font: Font
var _frame := 0
var _cursor := 0
var _confirmed := 0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	Sound.music("selecao")
	_cursor = Characters.index_of(Characters.selected)


func _process(_delta: float) -> void:
	_frame += 1
	if _confirmed > 0:
		_confirmed -= 1
		if _confirmed == 0:
			Stage.continue_section = 0
			Fases.reset_carry()
			get_tree().change_scene_to_file(MAIN_SCENE)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _confirmed > 0:
		return
	var count := Characters.LIST.size()
	var before := _cursor
	_handle(event, count)
	if _cursor != before:
		Sound.play("menu_move", -6.0, 0.0)


func _handle(event: InputEvent, count: int) -> void:
	if event.is_action_pressed(&"move_left"):
		_cursor = (_cursor + count - 1) % count
	elif event.is_action_pressed(&"move_right"):
		_cursor = (_cursor + 1) % count
	elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down"):
		# Troca de linha na mesma coluna; a 2ª linha tem 3, então a 4ª coluna desce para o último.
		_cursor = mini(_cursor - COLUMNS if _cursor >= COLUMNS else _cursor + COLUMNS, count - 1)
	elif event.is_action_pressed(&"dodge"):
		next_biome()
	elif event.is_action_pressed(&"attack") or event.is_action_pressed(&"restart") or event.is_action_pressed(&"ui_accept"):
		confirm()
	elif event.is_action_pressed(&"special"):
		Difficulty.cycle()
		Sound.play("menu_move", -6.0, 0.0)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"pause"):
		Sound.play("menu_back", -4.0, 0.0)
		get_tree().change_scene_to_file(TITLE_SCENE)


## Shift/I (RB/LB) troca o cenário da fase (Terra, Deserto, Natureza, Vulcão).
func next_biome() -> void:
	var order: Array = StageScenery.ORDER
	StageScenery.biome = order[(order.find(StageScenery.biome) + 1) % order.size()]
	Sound.play("menu_move", -6.0, 0.0)


func confirm() -> void:
	Characters.selected = Characters.LIST[_cursor]["id"]
	Sound.play("menu_ok", -4.0, 0.0)
	# Meio segundo com o golpe especial antes de começar a fase.
	_confirmed = 30


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1d2b53"))
	_text_center("ESCOLHA SEU ELEMENTAL", Vector2(size.x / 2.0, 14.0), 10, Color("ffcc33"))
	for i in Characters.LIST.size():
		_draw_cell(i)
	_draw_info(Characters.LIST[_cursor])


func _draw_cell(i: int) -> void:
	var data: Dictionary = Characters.LIST[i]
	var cell := Rect2(GRID_ORIGIN + Vector2(i % COLUMNS, i / COLUMNS) * CELL, CELL).grow(-2.0)
	var selected := i == _cursor
	draw_rect(cell, Color(data["color"], 0.25 if selected else 0.08))
	if selected:
		draw_rect(cell, data["color"] if _frame % 30 < 22 else Color.WHITE, false, 1.0)
	var anim := "idle"
	var index := 0
	if selected:
		anim = "sp_atk" if _confirmed > 0 else "idle"
		index = (30 - _confirmed) * _frames(data["id"], anim) / 30 if _confirmed > 0 else _frame / IDLE_TICKS
	var feet := Vector2(cell.get_center().x, cell.end.y - 4.0)
	_draw_character(data["id"], anim, index, feet, Color.WHITE if selected else Color(0.6, 0.6, 0.7))
	_text_center(data["name"].to_upper(), Vector2(cell.get_center().x, cell.position.y + 9.0), 7,
		Color.WHITE if selected else Color(1, 1, 1, 0.5))


func _draw_info(data: Dictionary) -> void:
	var top := GRID_ORIGIN.y + CELL.y * 2.0 + 6.0
	_text(data["title"].to_upper(), Vector2(GRID_ORIGIN.x, top + 8.0), 10, data["color"])
	_text("Elemento: %s" % data["element"], Vector2(GRID_ORIGIN.x, top + 20.0), 7, Color(1, 1, 1, 0.7))
	for s in STATS.size():
		var stat: Array = STATS[s]
		var y := top + 6.0 + s * 10.0
		var ratio := inverse_lerp(stat[2], stat[3], float(data[stat[1]]))
		_text(stat[0], Vector2(200.0, y + 5.0), 7, Color.WHITE)
		draw_rect(Rect2(250.0, y, 110.0, 5.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(250.0, y, 110.0 * clampf(ratio, 0.05, 1.0), 5.0), data["color"])
	var dif := Difficulty.current()
	_text("Dificuldade: %s" % dif["name"], Vector2(GRID_ORIGIN.x, top + 32.0), 7, dif["color"])
	var biome := StageScenery.data()
	_text("Cenário: %s" % biome["name"], Vector2(GRID_ORIGIN.x, top + 42.0), 7, biome["color"])
	_text_center("Setas escolhem   J confirma   L dificuldade   Shift cenário   K volta", Vector2(size.x / 2.0, size.y - 5.0), 7,
		Color(1, 1, 1, 0.55))


func _frames(id: String, anim: String) -> int:
	var real := Characters.resolve_anim(id, anim)
	return int(Characters.meta(id)["anims"][real]["frames"])


## Desenha um quadro com os pés em `feet`, reduzindo quem não cabe na célula.
func _draw_character(id: String, anim: String, index: int, feet: Vector2, tint: Color) -> void:
	var meta := Characters.meta(id)
	var real := Characters.resolve_anim(id, anim)
	var count := _frames(id, real)
	var frame_size := Vector2(meta["frame_size"][0], meta["frame_size"][1])
	var anchor := Vector2(meta["anchor"][0], meta["anchor"][1])
	var scale := minf(1.0, PORTRAIT_HEIGHT / float(meta["height"]))
	var columns := int(meta["columns"])
	var cell := index % count
	var source := Rect2(Vector2(frame_size.x * (cell % columns), frame_size.y * (cell / columns)), frame_size)
	var dest := Rect2(feet - anchor * scale, frame_size * scale)
	draw_texture_rect_region(Characters.texture(id, real), dest, source, tint)


func _text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_center(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(_font, pos - Vector2(200.0, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, font_size, color)

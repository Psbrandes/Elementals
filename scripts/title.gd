extends Control
## Tela de título com menu: Jogar, Co-op online, Opções, Controles, Créditos e Sair.
## Fundo desenhado em código: céu com estrelas, montanhas, os orbes dos elementos girando
## em volta do nome e os 7 heróis parados no chão. Setas escolhem, J ou Enter confirmam,
## K volta dos submenus. O atalho O (co-op online) continua valendo.

const SELECT_SCENE := "res://scenes/select.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const FADE_FRAMES := 30
const HERO_HEIGHT := 30.0
const CONTROLS := [
	["Mover", "Setas / WASD"],
	["Soco (combo de 3)", "J"],
	["Pulo (toque curto ou segurado)", "K"],
	["Especial  /  especial 2", "L  /  baixo + L"],
	["Esquiva", "Shift ou I"],
	["Correr  /  investida", "Frente 2x  /  correndo + J"],
	["Lançador  /  chute", "J, J, cima + J  /  J, J, frente + J"],
	["Agarrar", "Encostar no inimigo"],
	["Pausa", "Esc, P ou Start"],
]
const CREDITS := [
	["Heróis", "Elementals e Frost Guardian, de chierit (CC-BY 4.0)"],
	["Inimigos e cenário", "CraftPix"],
	["Música da fase, chefe e título", "xDeviruchi (CC-BY-SA 4.0)"],
	["Efeitos de combate", "400 Sounds Pack (Chequered Ink) e Pixabay"],
	["Efeitos visuais", "PVFX Foundry, Pixel VFX Studio (CC0)"],
	["Música de vitória e seleção", "originais do projeto (CC0)"],
	["Sons de menu, vitória e avisos", "originais do projeto (CC0)"],
	["Motor", "Godot Engine 4"],
]

var _frame := 0
## "menu", "opcoes", "controles" ou "creditos".
var _screen := "menu"
var _menu: MenuList
var _options: OptionsMenu
var _stars: Array = []
var _leaving := 0
var _leave_to := ""


func _ready() -> void:
	Sound.music("titulo")
	var items := [
		{"id": "jogar", "label": "Jogar"},
		{"id": "opcoes", "label": "Opções"},
		{"id": "controles", "label": "Controles"},
		{"id": "creditos", "label": "Créditos"},
	]
	# No navegador o co-op online (ENet/UDP) não existe: o item e o atalho O somem.
	if not OS.has_feature("web"):
		items.insert(1, {"id": "online", "label": "Co-op online"})
	if OS.has_feature("pc") and not OS.has_feature("web"):
		items.append({"id": "sair", "label": "Sair"})
	_menu = MenuList.new(items)
	_menu.pause_is_back = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.55), rng.randi_range(0, 90)])


func _process(_delta: float) -> void:
	_frame += 1
	if _leaving > 0:
		_leaving -= 1
		if _leaving == 0:
			get_tree().change_scene_to_file(_leave_to)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving > 0 or event is InputEventMouse:
		return
	match _screen:
		"menu":
			if event.is_action_pressed(&"online") and not OS.has_feature("web"):
				Sound.ui("menu_ok")
				_leave(LOBBY_SCENE)
				return
			var result := _menu.handle(event)
			if result.get("do", "") == "ok":
				_choose(result["id"])
		"opcoes":
			if _options.handle(event):
				_screen = "menu"
				Sound.ui("menu_close")
		_:
			if event.is_action_pressed(&"jump") or event.is_action_pressed(&"attack") \
					or event.is_action_pressed(&"restart") or event.is_action_pressed(&"pause"):
				Sound.ui("menu_back")
				_screen = "menu"
	_handled()


func _choose(id: String) -> void:
	match id:
		"jogar":
			_leave(SELECT_SCENE)
		"online":
			_leave(LOBBY_SCENE)
		"opcoes":
			_options = OptionsMenu.new()
			_screen = "opcoes"
			Sound.ui("menu_open")
		"controles", "creditos":
			_screen = id
			Sound.ui("menu_open")
		"sair":
			get_tree().quit()


## Saída com um fade curto, para o som de confirmar tocar antes da troca de cena.
func _leave(scene: String) -> void:
	_leave_to = scene
	_leaving = 18


# --- Desenho ----------------------------------------------------------------------

func _draw() -> void:
	_draw_sky()
	_draw_heroes()
	var cx := size.x / 2.0
	match _screen:
		"menu":
			_draw_logo(Vector2(cx, 56.0))
			var top := 100.0
			UiDraw.panel(self, Rect2(cx - 70.0, top - 12.0, 140.0, _menu.height() + 6.0), Color(1, 1, 1, 0.2))
			_menu.draw(self, cx, top, 132.0, _hero_color(_frame / 90))
		"opcoes":
			_draw_logo(Vector2(cx, 40.0), 0.7)
			UiDraw.panel(self, Rect2(cx - 95.0, 62.0, 190.0, 100.0), UiDraw.GOLD)
			_options.draw(self, cx, 78.0, _hero_color(_frame / 90))
		"controles":
			_draw_table("CONTROLES", CONTROLS, 200.0)
		"creditos":
			_draw_table("CRÉDITOS", CREDITS, 120.0)
	UiDraw.text_center(self, "Heróis por chierit (CC-BY 4.0)   Música por xDeviruchi   Sons originais CC0",
		Vector2(cx, size.y - 3.0), 6, Color(1, 1, 1, 0.4), false)
	var fade := 1.0 - minf(float(_frame) / FADE_FRAMES, 1.0)
	if _leaving > 0:
		fade = 1.0 - _leaving / 18.0
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, fade))


func _draw_sky() -> void:
	var bands := [Color("0b0f2a"), Color("131a40"), Color("1d2b53"), Color("2a2f63"), Color("3d2c66"), Color("5a2f5e")]
	var band_h := size.y * 0.7 / bands.size()
	for i in bands.size():
		draw_rect(Rect2(0.0, i * band_h, size.x, band_h + 1.0), bands[i])
	for star: Array in _stars:
		var twinkle := (_frame + int(star[1])) % 90
		var alpha := 0.35 + 0.5 * absf(sin(twinkle / 90.0 * PI))
		draw_rect(Rect2(Vector2(star[0].x * size.x, star[0].y * size.y).floor(), Vector2.ONE), Color(1, 1, 1, alpha))
	# Três cadeias de montanhas, cada uma andando um pouco (parallax).
	_mountains(size.y * 0.66, 34.0, 0.10, Color("2b2350"), 1)
	_mountains(size.y * 0.74, 26.0, 0.25, Color("231c3f"), 2)
	draw_rect(Rect2(0.0, size.y * 0.80, size.x, size.y * 0.2), Color("16122a"))
	draw_rect(Rect2(0.0, size.y * 0.80, size.x, 1.0), Color("3a2f5c"))


func _mountains(base: float, height: float, speed: float, color: Color, seed: int) -> void:
	var points := PackedVector2Array()
	var shift := fmod(_frame * speed, 64.0)
	points.append(Vector2(0.0, size.y))
	var x := -64.0 - shift
	var i := 0
	while x <= size.x + 64.0:
		var peak := height * (0.55 + 0.45 * absf(sin((i + seed * 3) * 1.7 + seed)))
		points.append(Vector2(x, base - (peak if i % 2 == 0 else peak * 0.35)))
		x += 32.0
		i += 1
	points.append(Vector2(size.x, size.y))
	draw_colored_polygon(points, color)


## O nome com cada letra numa cor de elemento que vai passando, contorno escuro e os orbes
## girando em volta. `scale` encolhe tudo (submenus).
func _draw_logo(center: Vector2, scale := 1.0) -> void:
	var font := UiDraw.font()
	var font_size := int(28 * scale)
	var word := "ELEMENTALS"
	# Orbes de trás (metade de cima da elipse) antes do texto, os da frente depois.
	_draw_orbs(center, scale, false)
	var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := center.x - width / 2.0
	for i in word.length():
		var letter := word[i]
		var bob := sin((_frame + i * 6) / 14.0) * 1.5 * scale
		var pos := Vector2(x, center.y + bob)
		for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 2), Vector2(1, 2)]:
			draw_string(font, pos + offset, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("0b0f2a"))
		var color := _hero_color(i + _frame / 12).lerp(UiDraw.PALE, 0.35)
		draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_draw_orbs(center, scale, true)
	if scale >= 1.0:
		UiDraw.text_center(self, "Sete elementos contra a ferrugem", center + Vector2(0, 14), 8, Color(1, 1, 1, 0.75))


func _draw_orbs(center: Vector2, scale: float, front: bool) -> void:
	var count := Characters.LIST.size()
	for i in count:
		var angle := _frame / 70.0 + TAU * i / count
		var is_front := sin(angle) > 0.0
		if is_front != front:
			continue
		var pos := center + Vector2(cos(angle) * 92.0, -9.0 + sin(angle) * 14.0) * scale
		var radius := (2.0 + (1.2 if front else 0.0)) * scale
		var color: Color = Characters.LIST[i]["color"]
		draw_circle(pos, radius + 2.0, Color(color, 0.25))
		draw_circle(pos, radius, color if front else color.darkened(0.35))


## Os 7 heróis parados lado a lado no chão; um de cada vez solta o especial.
func _draw_heroes() -> void:
	var count := Characters.LIST.size()
	var spacing := minf(size.x / (count + 1), 46.0)
	var start := size.x / 2.0 - spacing * (count - 1) / 2.0
	var feet_y := size.y * 0.80 + 22.0
	var showing := (_frame / 120) % count
	for i in count:
		var data: Dictionary = Characters.LIST[i]
		var id: String = data["id"]
		var anim := "idle"
		var index := (_frame + i * 5) / 7
		if i == showing and _frame % 120 < 60:
			anim = "sp_atk"
			index = (_frame % 120) * UiDraw.frame_count(id, anim) / 60
		var feet := Vector2(start + i * spacing, feet_y)
		draw_set_transform(feet + Vector2(0, 0.5), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
		UiDraw.character(self, id, anim, index, feet, HERO_HEIGHT, Color.WHITE, i >= count / 2)


func _draw_table(title: String, rows: Array, left_width: float) -> void:
	var height := 30.0 + rows.size() * 12.0
	var rect := Rect2(16.0, 12.0, size.x - 32.0, height + 8.0)
	UiDraw.panel(self, rect, UiDraw.GOLD)
	UiDraw.text_center(self, title, Vector2(size.x / 2.0, rect.position.y + 16.0), 12, UiDraw.GOLD)
	for i in rows.size():
		var y := rect.position.y + 32.0 + i * 12.0
		UiDraw.text(self, rows[i][0], Vector2(rect.position.x + 10.0, y), 7, Color(1, 1, 1, 0.65))
		UiDraw.text(self, rows[i][1], Vector2(rect.position.x + 10.0 + left_width * 0.0 + (rect.size.x * 0.42), y), 7, Color.WHITE)
	if _frame % 60 < 42:
		UiDraw.text_center(self, "J ou K para voltar", Vector2(size.x / 2.0, rect.end.y - 2.0 + 10.0), 7, Color(1, 1, 1, 0.6))


func _hero_color(i: int) -> Color:
	return Characters.LIST[posmod(i, Characters.LIST.size())]["color"]


## Marca a entrada como usada. Depois de trocar de cena este nó já saiu da árvore.
func _handled() -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()

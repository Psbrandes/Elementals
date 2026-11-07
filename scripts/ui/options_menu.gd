class_name OptionsMenu
extends RefCounted
## Submenu de opções usado no título e na pausa: volume da música, dos efeitos e tela cheia.
## Os valores ficam no autoload Settings, que salva sozinho.

var list: MenuList


func _init() -> void:
	var items := [
		{"id": "musica", "label": "Música", "slider": true},
		{"id": "efeitos", "label": "Efeitos", "slider": true},
	]
	if _settings() and _settings().can_fullscreen():
		items.append({"id": "tela", "label": "Tela cheia", "slider": true})
	items.append({"id": "voltar", "label": "Voltar"})
	list = MenuList.new(items)
	_refresh()


## true quando o jogador sai das opções.
func handle(event: InputEvent) -> bool:
	var result := list.handle(event)
	if result.is_empty():
		return false
	var settings := _settings()
	var id: String = result["id"]
	var step := 0
	match result["do"]:
		"left":
			step = -1
		"right":
			step = 1
		"ok":
			if id == "voltar":
				return true
			step = 1
		"back":
			return true
	if settings and step != 0:
		match id:
			"musica":
				settings.set_music(wrapi(settings.music_volume + step, 0, settings.STEPS + 1) if result["do"] == "ok" \
					else settings.music_volume + step)
			"efeitos":
				settings.set_sfx(wrapi(settings.sfx_volume + step, 0, settings.STEPS + 1) if result["do"] == "ok" \
					else settings.sfx_volume + step)
				Sound.ui("hit", -6.0)
			"tela":
				settings.set_fullscreen(not settings.fullscreen)
	_refresh()
	return false


func draw(canvas: CanvasItem, center_x: float, top: float, accent: Color) -> void:
	UiDraw.text_center(canvas, "OPÇÕES", Vector2(center_x, top), 12, UiDraw.GOLD)
	list.draw(canvas, center_x, top + 18.0, 170.0, accent)
	UiDraw.text_center(canvas, "Setas mudam   J confirma   K volta", Vector2(center_x, top + 22.0 + list.height()), 7,
		Color(1, 1, 1, 0.5))


func _refresh() -> void:
	var settings := _settings()
	if settings == null:
		return
	list.set_value("musica", _bar(settings.music_volume))
	list.set_value("efeitos", _bar(settings.sfx_volume))
	list.set_value("tela", "SIM" if settings.fullscreen else "NÃO")


func _bar(value: int) -> String:
	return "%d" % value if value > 0 else "MUDO"


func _settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"Settings") if tree else null

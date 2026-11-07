class_name MenuList
extends RefCounted
## Lista de opções navegável com setas/D-pad, desenhada em código. Cada item é
## {"id": String, "label": String} e pode ter "value" (texto à direita, como "8/10")
## e "slider": true (setas para os lados mudam o valor).
##
## `handle(event)` devolve o que o jogador fez: {"do": "ok"|"left"|"right"|"back", "id": ...}
## ou {} quando nada aconteceu. Quem usa a lista decide o que cada id faz.

const LINE := 12.0

var items: Array = []
var cursor := 0
## Esc/Start voltam (pausa, opções). No título não há para onde voltar.
var pause_is_back := true
var _blink := 0


func _init(list: Array = []) -> void:
	items = list


func current_id() -> String:
	return items[cursor]["id"] if not items.is_empty() else ""


func set_value(id: String, value: String) -> void:
	for item: Dictionary in items:
		if item["id"] == id:
			item["value"] = value


func handle(event: InputEvent) -> Dictionary:
	if items.is_empty() or event.is_echo():
		return {}
	var item: Dictionary = items[cursor]
	if pause_is_back and event.is_action_pressed(&"pause"):
		Sound.ui("menu_back")
		return {"do": "back", "id": item["id"]}
	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		cursor = (cursor + items.size() - 1) % items.size()
		Sound.ui("menu_move", -6.0)
		_blink = 0
		return {"do": "move", "id": current_id()}
	if event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		cursor = (cursor + 1) % items.size()
		Sound.ui("menu_move", -6.0)
		_blink = 0
		return {"do": "move", "id": current_id()}
	if item.get("slider", false):
		if event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left"):
			Sound.ui("menu_move", -6.0)
			return {"do": "left", "id": item["id"]}
		if event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right"):
			Sound.ui("menu_move", -6.0)
			return {"do": "right", "id": item["id"]}
	if event.is_action_pressed(&"attack") or event.is_action_pressed(&"restart") or event.is_action_pressed(&"ui_accept"):
		Sound.ui("menu_ok")
		return {"do": "ok", "id": item["id"]}
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_cancel"):
		Sound.ui("menu_back")
		return {"do": "back", "id": item["id"]}
	return {}


## Desenha a lista centrada em `center_x`, começando em `top`. `width` é a largura da faixa
## do item escolhido; `accent` é a cor do destaque.
func draw(canvas: CanvasItem, center_x: float, top: float, width: float, accent: Color, size := 9) -> void:
	_blink += 1
	for i in items.size():
		var item: Dictionary = items[i]
		var y := top + i * LINE
		var selected := i == cursor
		if selected:
			var band := Rect2(center_x - width / 2.0, y - 9.0, width, LINE - 1.0)
			canvas.draw_rect(band, Color(accent, 0.22))
			canvas.draw_rect(Rect2(band.position, Vector2(2, band.size.y)), accent)
		var color := Color.WHITE if selected else Color(1, 1, 1, 0.6)
		if item.has("value"):
			UiDraw.text(canvas, item["label"], Vector2(center_x - width / 2.0 + 8.0, y), size, color)
			var value: String = item["value"]
			if selected and item.get("slider", false):
				value = "< " + value + " >"
			UiDraw.text_right(canvas, value, Vector2(center_x + width / 2.0 - 6.0, y), size,
				UiDraw.PALE if selected else Color(1, 1, 1, 0.6))
		else:
			UiDraw.text_center(canvas, item["label"], Vector2(center_x, y), size, color)
		if selected and _blink % 40 < 28:
			UiDraw.text(canvas, ">", Vector2(center_x - width / 2.0 + (0.0 if item.has("value") else 6.0) - 6.0 + 4.0, y), size, accent)


func height() -> float:
	return items.size() * LINE

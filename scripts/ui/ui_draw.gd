class_name UiDraw
## Desenho compartilhado pelas telas de menu (título, pausa, vitória): texto com sombra,
## painéis e um quadro de animação de herói.

const SHADOW := Color(0, 0, 0, 0.6)
const PANEL := Color(0.05, 0.06, 0.14, 0.86)
const GOLD := Color("ffcc33")
const PALE := Color("fff1a8")


static func font() -> Font:
	return ThemeDB.fallback_font


static func text(canvas: CanvasItem, value: String, pos: Vector2, size: int, color: Color, shadow := true) -> void:
	if shadow:
		canvas.draw_string(font(), pos + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(SHADOW, SHADOW.a * color.a))
	canvas.draw_string(font(), pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_right(canvas: CanvasItem, value: String, pos: Vector2, size: int, color: Color, shadow := true) -> void:
	var at := pos - Vector2(300, 0)
	if shadow:
		canvas.draw_string(font(), at + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_RIGHT, 300, size, Color(SHADOW, SHADOW.a * color.a))
	canvas.draw_string(font(), at, value, HORIZONTAL_ALIGNMENT_RIGHT, 300, size, color)


static func text_center(canvas: CanvasItem, value: String, pos: Vector2, size: int, color: Color, shadow := true) -> void:
	var at := pos - Vector2(300, 0)
	if shadow:
		canvas.draw_string(font(), at + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_CENTER, 600, size, Color(SHADOW, SHADOW.a * color.a))
	canvas.draw_string(font(), at, value, HORIZONTAL_ALIGNMENT_CENTER, 600, size, color)


## Painel escuro com borda fina na cor dada.
static func panel(canvas: CanvasItem, rect: Rect2, border: Color) -> void:
	canvas.draw_rect(rect, PANEL)
	canvas.draw_rect(rect, Color(border, 0.8), false, 1.0)


## Um quadro da animação `anim` do herói `id` com os pés em `feet`, reduzido para caber em `height`.
static func character(canvas: CanvasItem, id: String, anim: String, index: int, feet: Vector2, height: float,
		tint := Color.WHITE, flip := false) -> void:
	var meta := Characters.meta(id)
	if meta.is_empty():
		return
	var real := Characters.resolve_anim(id, anim)
	var count := int(meta["anims"][real]["frames"])
	var frame_size := Vector2(meta["frame_size"][0], meta["frame_size"][1])
	var anchor := Vector2(meta["anchor"][0], meta["anchor"][1])
	var scale := minf(1.0, height / float(meta["height"]))
	var columns := int(meta["columns"])
	var cell := posmod(index, count)
	var source := Rect2(Vector2(frame_size.x * (cell % columns), frame_size.y * (cell / columns)), frame_size)
	# Desenha em volta dos pés; virado, espelha o eixo x nesse ponto.
	canvas.draw_set_transform(feet, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	canvas.draw_texture_rect_region(Characters.texture(id, real), Rect2(-anchor * scale, frame_size * scale), source, tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func frame_count(id: String, anim: String) -> int:
	var meta := Characters.meta(id)
	if meta.is_empty():
		return 1
	return int(meta["anims"][Characters.resolve_anim(id, anim)]["frames"])

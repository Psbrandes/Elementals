extends Node2D
## Cenário placeholder do Bairro do Porto, com paleta própria por seção:
## cais azulado, armazém marrom e pátio noturno roxo. Desenha além das bordas
## porque o stretch "expand" mostra mais cenário em telas mais largas que 16:9.

const MARGIN := 200.0
const FLOOR_TOP := 120.0
const BOTTOM := 216.0
const LINE_SPACING := 32.0


func _draw() -> void:
	var sections: Array = Stage.SECTIONS
	for i in sections.size():
		var left: float = sections[i]["start"]
		var right: float = Stage.STAGE_LENGTH if i == sections.size() - 1 else sections[i + 1]["start"]
		if i == 0:
			left -= MARGIN
		if i == sections.size() - 1:
			right += MARGIN
		match i:
			0:
				_draw_docks(left, right)
			1:
				_draw_warehouse(left, right)
			_:
				_draw_yard(left, right)


func _draw_docks(left: float, right: float) -> void:
	var width := right - left
	draw_rect(Rect2(left, 0.0, width, 48.0), Color("1d2b53"))
	draw_rect(Rect2(left, 48.0, width, 14.0), Color("29366f"))
	draw_rect(Rect2(left, 62.0, width, 10.0), Color("2b5f8a"))
	_draw_buildings(left, right, [Color("3b3b58"), Color("5a3d4a"), Color("2f4f6f")])
	_draw_floor(left, right, Color("4a4e5a"), Color("3e414c"), Color("6d6d7a"))


func _draw_warehouse(left: float, right: float) -> void:
	var width := right - left
	draw_rect(Rect2(left, 0.0, width, FLOOR_TOP), Color("4a3428"))
	# Vigas e janelas altas.
	var x := left
	while x < right:
		draw_rect(Rect2(x, 0.0, 6.0, FLOOR_TOP), Color("3a281f"))
		draw_rect(Rect2(x + 22.0, 20.0, 28.0, 22.0), Color("6f8fae"))
		draw_rect(Rect2(x + 35.0, 20.0, 2.0, 22.0), Color("3a281f"))
		x += 80.0
	# Caixas empilhadas no fundo.
	var i := 0
	x = left + 10.0
	while x < right:
		var stack := 1 + (i * 7) % 3
		for s in stack:
			draw_rect(Rect2(x, FLOOR_TOP - 22.0 * (s + 1), 24.0, 20.0), Color("8c6a3e"))
			draw_rect(Rect2(x, FLOOR_TOP - 22.0 * (s + 1), 24.0, 20.0), Color("5e4428"), false, 1.0)
		x += 60.0 + float((i * 23) % 40)
		i += 1
	_draw_floor(left, right, Color("6b4f3a"), Color("5a412f"), Color("7a5c44"))


func _draw_yard(left: float, right: float) -> void:
	var width := right - left
	draw_rect(Rect2(left, 0.0, width, FLOOR_TOP), Color("2a1d45"))
	draw_circle(Vector2(left + 300.0, 28.0), 12.0, Color("f2e6d0"))
	# Guindaste.
	var cx := left + 520.0
	draw_rect(Rect2(cx, 14.0, 8.0, FLOOR_TOP - 14.0), Color("1a1230"))
	draw_rect(Rect2(cx - 90.0, 14.0, 160.0, 6.0), Color("1a1230"))
	draw_line(Vector2(cx - 70.0, 20.0), Vector2(cx - 70.0, 70.0), Color("1a1230"), 1.0)
	draw_rect(Rect2(cx - 80.0, 70.0, 20.0, 12.0), Color("5a3d4a"))
	_draw_buildings(left, right, [Color("3d2b5e"), Color("33264f")], 0.6)
	_draw_floor(left, right, Color("4b4060"), Color("3e3452"), Color("6a5d80"))
	# Chuva leve.
	for j in 80:
		var rx := left + float((j * 97) % int(width))
		var ry := float((j * 53) % 200)
		draw_line(Vector2(rx, ry), Vector2(rx - 2.0, ry + 6.0), Color(0.7, 0.7, 0.9, 0.25), 1.0)


func _draw_buildings(left: float, right: float, colors: Array, lit_ratio := 1.0) -> void:
	var x := left
	var i := 0
	while x < right:
		var w := 40.0 + float((i * 37) % 28)
		var h := 34.0 + float((i * 53) % 30)
		draw_rect(Rect2(x, FLOOR_TOP - h, w - 2.0, h), colors[i % colors.size()])
		for wy in range(int(FLOOR_TOP - h) + 6, int(FLOOR_TOP) - 10, 10):
			for wx in range(int(x) + 5, int(x + w) - 8, 9):
				if (wx + wy + i) % 3 != 0:
					var lit := (wx * wy) % 5 == 0 and float((wx + wy) % 10) < lit_ratio * 10.0
					draw_rect(Rect2(wx, wy, 4.0, 4.0), Color("e8c170") if lit else Color("23233a"))
		x += w
		i += 1


## Chão de 96 px de profundidade, com linhas que afunilam para sugerir perspectiva.
func _draw_floor(left: float, right: float, base: Color, line: Color, edge: Color) -> void:
	var width := right - left
	draw_rect(Rect2(left, FLOOR_TOP - 4.0, width, 4.0), edge)
	draw_rect(Rect2(left, FLOOR_TOP, width, BOTTOM - FLOOR_TOP), base)
	var y := FLOOR_TOP
	var gap := 8.0
	while y < BOTTOM:
		draw_line(Vector2(left, y), Vector2(right, y), line)
		y += gap
		gap += 4.0
	var lx := left - fmod(left, LINE_SPACING)
	while lx <= right:
		draw_line(Vector2(lx, FLOOR_TOP), Vector2(lx - 20.0, BOTTOM), line)
		lx += LINE_SPACING

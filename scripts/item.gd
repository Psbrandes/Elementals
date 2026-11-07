class_name Item
extends Node2D
## Item no chão. Encostar pega: comida cura, moedas dão pontos.

const HEAL := {"maca": 20, "frango": 50}
const SCORE := {"moedas": 1000}
## Orbe elemental: enche metade do medidor.
const METER := {"orbe": 50}

## "maca", "frango", "moedas" ou "orbe".
var kind := "maca"

var _frame := 0


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % 8 == 0:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var bob := -2.0 if _frame % 48 < 24 else -3.0
	match kind:
		"maca":
			draw_circle(Vector2(0.0, bob - 4.0), 4.0, Color("d6332b"))
			draw_rect(Rect2(Vector2(-0.5, bob - 10.0), Vector2(1.0, 3.0)), Color("6b8f3a"))
		"frango":
			draw_rect(Rect2(Vector2(-6.0, bob - 7.0), Vector2(10.0, 6.0)), Color("c97b3a"))
			draw_rect(Rect2(Vector2(4.0, bob - 6.0), Vector2(4.0, 2.0)), Color("f2e6d0"))
		"orbe":
			draw_circle(Vector2(0.0, bob - 6.0), 4.5, Color("7fd4ff"))
			draw_circle(Vector2(-1.0, bob - 7.0), 1.5, Color.WHITE)
		"moedas":
			draw_rect(Rect2(Vector2(-5.0, bob - 8.0), Vector2(10.0, 7.0)), Color("8c6a2e"))
			draw_rect(Rect2(Vector2(-3.0, bob - 10.0), Vector2(6.0, 2.0)), Color("ffcc33"))

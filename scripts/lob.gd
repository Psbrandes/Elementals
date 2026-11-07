class_name Lob
extends Node2D
## Projétil em arco: bomba do Piromante e pedra arremessada pelo Ferrugem.
## Sai de quem lançou e cai num ponto do chão marcado desde o lançamento (o
## círculo vermelho no View3D). Ao cair, explode numa área: pular não salva,
## o jeito é sair do círculo. A bomba também acerta os outros inimigos.

## Ponto de saída e alvo no chão (x, profundidade).
var origin := Vector2.ZERO
var target := Vector2.ZERO
var flight := 50
var peak := 70.0
var damage := 12
## Meia largura da explosão; a profundidade usa metade disso.
var radius := 22.0
## "bomba" (fogo, acerta inimigos também) ou "pedra" (só o jogador).
var look := "bomba"
var stage: Stage
var source: Node2D

var height := 0.0
var frame := 0


func _ready() -> void:
	position = origin


func _physics_process(_delta: float) -> void:
	frame += 1
	var t := clampf(float(frame) / flight, 0.0, 1.0)
	position = origin.lerp(target, t)
	height = 4.0 * peak * t * (1.0 - t) + 20.0 * (1.0 - t)
	if frame >= flight:
		stage.explode(target, radius, damage, self, look == "bomba", look)
		queue_free()


## 0 no lançamento, 1 no impacto (o marcador do chão fica mais forte).
func progress() -> float:
	return clampf(float(frame) / flight, 0.0, 1.0)

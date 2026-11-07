class_name CharacterSprite
extends Sprite2D
## Desenha um personagem dos pacotes Elementals a partir das tiras de
## assets/characters. Quem escolhe a animação e o quadro é o lutador, a cada
## quadro de jogo, então o hit stop congela a arte junto com a lógica.
##
## A origem do nó fica nos pés: o espelhamento (scale.x negativo) é em volta deles.

const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
"""

static var _shader: Shader

var character_id := ""
var anim := ""
var frame_count := 1
var draw_scale := 1.0


func setup(id: String, scale_factor := 1.0) -> void:
	character_id = id
	draw_scale = scale_factor
	centered = false
	var meta := Characters.meta(id)
	offset = -Vector2(meta["anchor"][0], meta["anchor"][1])
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	material = ShaderMaterial.new()
	material.shader = _shader
	anim = ""
	show_frame("idle", 0)


func frames_of(anim_name: String) -> int:
	var real := Characters.resolve_anim(character_id, anim_name)
	return int(Characters.meta(character_id)["anims"][real]["frames"])


## Quadro em que a arte do golpe chega mais longe (alinhado com o quadro ativo).
func hit_frame_of(anim_name: String) -> int:
	var real := Characters.resolve_anim(character_id, anim_name)
	return int(Characters.meta(character_id)["anims"][real].get("hit", 0))


## Até onde a arte do golpe chega à frente dos pés, já na escala do desenho.
func reach_of(anim_name: String) -> float:
	var real := Characters.resolve_anim(character_id, anim_name)
	return float(Characters.meta(character_id)["anims"][real].get("reach", 0.0)) * draw_scale


func show_frame(anim_name: String, index: int) -> void:
	var real := Characters.resolve_anim(character_id, anim_name)
	if real != anim:
		anim = real
		texture = Characters.texture(character_id, real)
		frame_count = frames_of(real)
		frame = 0
		# Folhas em grade (no máximo 2048 px de largura, por causa do celular).
		var columns := int(Characters.meta(character_id)["columns"])
		hframes = mini(columns, frame_count)
		vframes = ceili(float(frame_count) / columns)
	frame = clampi(index, 0, frame_count - 1)


func set_pose(facing: int, lift: float, flash: bool) -> void:
	position = Vector2(0.0, -lift)
	scale = Vector2(facing * draw_scale, draw_scale)
	(material as ShaderMaterial).set_shader_parameter(&"flash", 0.85 if flash else 0.0)


# --- Ritmo dos golpes -------------------------------------------------------------
## A arte dos Elementals foi desenhada para ~12 quadros por segundo e tem golpes de
## 7 a 32 quadros; os golpes do jogo duram 14 a 30 ticks (60 por segundo). Tocar
## a arte inteira deixaria o jogo lento, e espremê-la (1 tick por quadro, como era)
## deixa o golpe "acelerado". O meio-termo é animar por poses: cada pose da arte
## fica no mínimo POSE_TICKS na tela (20 por segundo), pulando os intermediários.
##   preparo: poses que levam até o quadro de impacto (a 1ª fica mais tempo:
##            é a antecipação);
##   ativo:   segura o quadro de impacto (é ali que o hit stop congela);
##   recuperação: poses até o ÚLTIMO quadro da arte (o efeito sempre termina),
##            cada uma um pouco mais longa que a anterior (o golpe "assenta").
const POSE_TICKS := 3
## Quantos quadros de arte uma pose do preparo pode "pular" no máximo.
const WINDUP_SPAN := 3


## Quadro da arte do golpe no tick t (1 = primeiro tick do golpe).
## full = true toca o preparo inteiro, do quadro 0 (o especial).
func attack_frame(anim_name: String, t: int, startup: int, active: int, recovery: int, full := false) -> int:
	var count := frames_of(anim_name)
	var hit := mini(hit_frame_of(anim_name), count - 1)
	startup = maxi(startup, 1)
	if t <= startup:
		if hit == 0:
			return 0
		var poses := clampi(startup / POSE_TICKS, 1, hit)
		var first := 0 if full else maxi(hit - poses * WINDUP_SPAN, 0)
		var pose := _pose_at(t - 1, startup, poses, true)
		# Poses espalhadas de first até hit - 1 (a última encosta no impacto).
		return first + (pose * (hit - 1 - first)) / maxi(poses - 1, 1) if poses > 1 else hit - 1
	if t <= startup + active:
		return hit
	var tail := count - 1 - hit
	if tail <= 0:
		return hit
	recovery = maxi(recovery, 1)
	var steps := clampi(recovery / POSE_TICKS, 1, tail)
	var step := _pose_at(t - startup - active - 1, recovery, steps, false)
	return hit + (step + 1) * tail / steps


# --- Especiais: a arte inteira, quadro a quadro --------------------------------------
## Os especiais são a vitrine da arte (o efeito do elemento está desenhado no próprio
## herói), então não pulam quadros: cada quadro de art_from até art_to aparece, na
## ordem, art_windup_tpf ticks no preparo e art_tpf ticks dali em diante. O último
## quadro fica ART_SETTLE_TICKS a mais na tela (o golpe "assenta" antes do parado).
const ART_SETTLE_TICKS := 4


## Preenche startup/active/recovery de um golpe com "art_tpf" a partir da arte:
## o dano começa em art_impact e vale até art_end (o efeito na tela).
static func art_timing(attack: Dictionary) -> Dictionary:
	var a := attack.duplicate()
	var from := int(a.get("art_from", 0))
	var impact := int(a["art_impact"])
	var end := int(a["art_end"])
	var to := int(a["art_to"])
	var tpf := int(a["art_tpf"])
	var windup := int(a.get("art_windup_tpf", tpf))
	a["startup"] = maxi((impact - from) * windup, 1)
	a["active"] = (end - impact + 1) * tpf
	a["recovery"] = (to - end) * tpf + ART_SETTLE_TICKS
	return a


## Quadro da arte no tick t (1 = primeiro tick) de um golpe com art_timing.
static func art_frame_at(attack: Dictionary, t: int) -> int:
	var from := int(attack.get("art_from", 0))
	var impact := int(attack["art_impact"])
	var startup := int(attack["startup"])
	if t <= startup:
		return mini(from + (t - 1) / int(attack.get("art_windup_tpf", attack["art_tpf"])), impact - 1) \
			if impact > from else from
	return mini(impact + (t - startup - 1) / int(attack["art_tpf"]), int(attack["art_to"]))


## Em qual de `poses` poses está o tick `elapsed` de `total`. Com ease_in a 1ª
## pose ganha as sobras (antecipação); sem, a última ganha (assentamento).
static func _pose_at(elapsed: int, total: int, poses: int, ease_in: bool) -> int:
	var base := maxi(total / poses, 1)
	var extra := maxi(total - base * poses, 0)
	if ease_in:
		if elapsed < base + extra:
			return 0
		return mini(1 + (elapsed - base - extra) / base, poses - 1)
	return mini(elapsed / base, poses - 1)

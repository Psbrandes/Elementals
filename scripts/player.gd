class_name Player
extends Fighter
## O herói jogável: qualquer um dos 8 Elementals (veja Characters). Os números
## vêm do GDD (seções 3 e 4) e são ponto de partida: ajuste por sensação jogando.

signal meter_changed(value: int)
signal lives_changed(lives: int)
signal game_over
## Contador de combo: cada golpe que acerta soma; o bônus entra quando o combo
## termina e se perde se o herói apanhar antes.
signal combo_changed(hits: int, bonus: int)
signal combo_ended(hits: int, bonus: int, dropped: bool)
## Destaque de um golpe do combo para o HUD: "CONTRA!", "AÉREO", "CANCEL" etc.
signal combo_event(text: String)
## Um golpe próprio do herói saiu (o HUD mostra o nome por um instante).
signal move_used(label: String, color: Color)

const WALK_SPEED := Vector2(90.0, 60.0)
const JUMP_LIFT := 260.0
## Um botão apertado um pouco cedo ainda vale (inclusive durante o hit stop).
const INPUT_BUFFER_FRAMES := 6
## Quadros, depois de um golpe que acertou, para emendar o próximo do combo.
const COMBO_WINDOW_FRAMES := 8
## Frente, frente: o segundo toque precisa vir em até 15 quadros.
const DASH_TAP_FRAMES := 15
const DASH_READY_FRAMES := 20
const GRAB_RANGE := 22.0
const GRAB_HOLD_DISTANCE := 18.0
const GRAB_FRAMES := 60
const GRAB_COOLDOWN_FRAMES := 30
const KNEE_FRAMES := 14
const KNEE_HIT_FRAME := 5
const KNEE_DAMAGE := 5
const MAX_KNEES := 2
## Suplex (arremesso pelas costas ou depois de pular por cima): dano extra.
const SUPLEX_BONUS := 6
const METER_MAX := 100
const METER_PER_HIT := 8
const METER_PER_THROW := 12
const SPECIAL_COST := 50
const SPECIAL_HP_COST := 15
const FULL_METER_BONUS := 2
## Vidas no Normal; o nível escolhido decide as vidas de verdade (Difficulty).
const START_LIVES := 3
const RESPAWN_FRAMES := 60
const RESPAWN_INVULN_FRAMES := 120
## Sem acertar nada por 1 s, o combo termina e o bônus é somado.
const COMBO_TIMEOUT_FRAMES := 60
const COMBO_MIN_HITS := 3

## Sensação de cada golpe: "hitstop" (quadros congelados no acerto), "push"
## (empurrão no alvo), "shake" (tremor de tela). Golpe leve congela pouco,
## golpe que fecha o combo congela mais: é isso que dá peso.
const COMBO := [
	{"name": "jab", "startup": 5, "active": 3, "recovery": 10, "damage": 6, "near": 0.0, "far": 26.0,
		"hitstop": 3, "push": 45.0},
	{"name": "direto", "startup": 6, "active": 3, "recovery": 12, "damage": 8, "near": 0.0, "far": 28.0,
		"hitstop": 4, "push": 60.0, "shake": 0.75},
	{"name": "gancho", "startup": 9, "active": 4, "recovery": 22, "damage": 14, "near": 0.0, "far": 28.0,
		"knockdown": true, "y_hi": 46.0, "hitstop": 8, "shake": 2.5},
]
## Rotas do 3º golpe: segure uma direção ao apertar J pela terceira vez.
const LAUNCHER := {"name": "lancador", "startup": 8, "active": 4, "recovery": 20, "damage": 10,
	"near": 0.0, "far": 26.0, "knockdown": true, "launch": 240.0, "y_hi": 50.0, "hitstop": 7, "shake": 2.0}
const FLAME_KICK := {"name": "chute_de_brasa", "startup": 9, "active": 4, "recovery": 24, "damage": 6,
	"near": 0.0, "far": 32.0, "knockdown": true, "sends_flying": true, "y_lo": 10.0, "y_hi": 34.0,
	"hitstop": 9, "shake": 3.0}
const JUMP_KICK := {"name": "chute_aereo", "damage": 10, "near": -4.0, "far": 26.0,
	"y_lo": -8.0, "y_hi": 24.0, "knockdown": true, "hitstop": 5}
## Combo aéreo: no ar, J, J, J. O 2º e o 3º só saem se o anterior acertou.
## O pisão crava o inimigo no chão, ele quica e pode ser golpeado de novo.
const AIR_PUNCH := {"name": "soco_aereo", "damage": 7, "near": -4.0, "far": 28.0,
	"y_lo": 0.0, "y_hi": 36.0, "hitstop": 4}
const AIR_SPIKE := {"name": "pisao_aereo", "damage": 11, "near": -6.0, "far": 26.0,
	"y_lo": -16.0, "y_hi": 28.0, "knockdown": true, "spike": true, "hitstop": 8, "shake": 3.0}
const AIR_CHAIN := [JUMP_KICK, AIR_PUNCH, AIR_SPIKE]
const DASH_ATTACK := {"name": "investida", "startup": 6, "active": 12, "recovery": 16, "damage": 12,
	"near": 0.0, "far": 24.0, "knockdown": true, "move_speed": 150.0, "y_hi": 46.0, "hitstop": 6, "shake": 2.0}
const SPECIAL := {"name": "erupcao", "startup": 8, "active": 6, "recovery": 18, "damage": 20,
	"near": 0.0, "far": 52.0, "depth": 24.0, "y_lo": 0.0, "y_hi": 60.0, "area": true,
	"knockdown": true, "special": true, "hitstop": 10, "shake": 3.5}

# --- Cancelamentos, combo aéreo e ritmo do combo ----------------------------------
## Golpe que acertou: depois do quadro ativo, J já emenda o próximo (sem esperar
## a recuperação inteira) e K cancela num pulo para perseguir no ar.
const CANCEL_JUMP_SPEED := 24.0
## Ticks da recuperação que sempre aparecem antes de um cancelamento (o golpe
## mostra o impacto e o começo do "depois" em vez de sumir no quadro ativo).
const CANCEL_FOLLOW_TICKS := 5
## Quadros de um golpe aéreo antes de o próximo da corrente poder sair.
const AIR_CHAIN_MIN_FRAMES := 6
## Acertar no ar um inimigo no ar segura o herói lá em cima (até 3 vezes por pulo).
const AIR_HANG_LIFT := 110.0
const AIR_HANG_MAX := 3
const AIR_HANG_DRAG := 0.35
## Escala de dano: do 6º golpe em diante cada golpe tira um pouco menos.
const PRORATION_START := 5
const PRORATION_STEP := 0.07
const PRORATION_MIN := 0.4
## Estilo: cada golpe vale pontos (mais por variar, cancelar, contra-atacar e
## acertar no ar; repetir o mesmo golpe vale metade). A nota multiplica o bônus.
const STYLE_RANKS := [[64.0, "SS", 3.0], [42.0, "S", 2.0], [26.0, "A", 1.5], [14.0, "B", 1.25],
	[6.0, "C", 1.0], [0.0, "D", 1.0]]
const STYLE_TAG_POINTS := {"CONTRA!": 2.0, "AÉREO": 1.0, "CANCEL": 1.0, "JUGGLE": 1.0, "FINAL": 1.0}
## Câmera lenta no golpe que derruba o último inimigo da onda (e no chefe).
const KO_SLOWMO_SCALE := 0.3
const KO_SLOWMO_SECONDS := 0.45
const BOSS_SLOWMO_SECONDS := 1.0
const THROW_ANIM := {"name": "arremesso", "startup": 0, "active": 0, "recovery": 16}

const GLOVE_COLOR := Color("ff7a1a")
const BANDANA_COLOR := Color("d6332b")

## Animação de cada golpe na arte dos Elementals.
const ATTACK_ANIMS := {"jab": "atk1", "direto": "atk2", "gancho": "atk3", "lancador": "air_atk",
	"chute_de_brasa": "atk3", "chute_aereo": "air_atk", "investida": "roll", "erupcao": "sp_atk",
	"arremesso": "atk2", "soco_aereo": "atk1", "pisao_aereo": "atk3"}
## A arte de vários heróis vai bem mais longe que os 26 a 32 px dos golpes: o
## alcance cresce até onde a arte chega, com este teto (efeitos como explosões e
## flechas passam de 100 px e não contam inteiros).
const REACH_CAP := 48.0
## Especial (L) de cada herói, quadro a quadro da arte sp_atk (ver
## CharacterSprite.art_timing): tpf = ticks por quadro (60 ticks = 1 s), windup =
## ticks por quadro no preparo, impact = 1º quadro que dá dano (o efeito chega no
## inimigo), end = último quadro com dano (o efeito ainda na tela). A arte toca
## inteira, do 1º ao último quadro, sem pular nenhum.
const SPECIAL_ART := {
	"fire_knight": {"tpf": 3, "impact": 12, "end": 14},
	"wind_hashashin": {"tpf": 3, "impact": 8, "end": 27},
	"leaf_ranger": {"tpf": 3, "impact": 9, "end": 12},
	"ground_monk": {"tpf": 3, "impact": 4, "end": 20},
	"metal_bladekeeper": {"tpf": 4, "impact": 3, "end": 8, "near": -48.0},
	"crystal_mauler": {"tpf": 4, "impact": 8, "end": 12},
	"water_priestess": {"tpf": 3, "impact": 12, "end": 22},
}
## O alcance do especial acompanha até onde o efeito desenhado chega (com teto).
const SPECIAL_MAX_REACH := 96.0
## A queda mostra a morte até o quadro "caído" do herói; levantar é o inverso.
const FALL_FRAMES := 14
const IDLE_TICKS := 7
const RUN_TICKS := 5
const RUN_TICKS_FAST := 3
const JUMP_TICKS := 4
const AIR_ATTACK_FRAMES := 18
const DEATH_TICKS := 4
const RIPOSTE_INVULN_FRAMES := HeroMoves.RIPOSTE_INVULN
## Carregando o golpe, o herói anda mais devagar.
const CHARGE_WALK_SCALE := 0.5
const CHARGE_SLOW_AFTER := 10

var input := PlayerInput.new()
## Corrida, esquiva, pulo com controle e salto no agarrão (scripts/player_movement.gd).
var movement := PlayerMovement.new()
## Herói deste jogador; vazio usa o escolhido na tela de seleção.
var hero_id := ""
## Co-op online: id de rede do dono deste herói (1 = host). 0 no jogo solo.
var peer_id := 0
## Dados do personagem escolhido (Characters.LIST).
var character: Dictionary = {}
var meter := 0
var lives := Difficulty.start_lives()
## Quem acertou por último (Enemy, Projectile, Lob...): só para os testes de equilíbrio.
var last_hit_by: Node2D
var combo_hits := 0

var _buffer := {&"attack": 0, &"jump": 0, &"special": 0, &"dodge": 0}
var _frame := 0
var _combo_step := 0
var _combo_window := 0
var _combo_connected := false
var _dash_ready := 0
var _dash_dir := 1
var _grabbed: Fighter
var _knees := 0
var _knee_timer := 0
var _grab_cooldown := 0
## Agarrou pelas costas (ou pulou por cima): o arremesso vira um suplex.
var _back_grab := false
var _suplex := false
var _jump_kicking := false
var _combo_damage := 0
## Direção segurada no momento em que o ataque foi apertado (escolhe a rota do combo).
var _attack_move := Vector2.ZERO
var _combo_timer := 0
var _kick_frame := 0
## Pontos de estilo do combo atual (veja STYLE_RANKS) e o último golpe que pontuou.
var combo_style := 0.0
var combo_peak_rank := "D"
var _recent_moves: Array = []
var _air_step := 0
var _air_connected := false
var _air_hangs := 0
## O próximo golpe saiu de um cancelamento (vale estilo).
var _from_cancel := false
## Golpes próprios (HeroMoves): carga do J, virada, golpe aéreo e dupla.
## Vidas perdidas na fase (tela de vitória).
var deaths := 0
var _charge := 0
var _charge_release := 0
var _turn_frame := -100
var _air_move := false
## Quadro de física do último especial (para o ataque em dupla).
var last_special_tick := -1000


func _ready() -> void:
	add_to_group(&"players")
	set_character(hero_id if hero_id != "" else Characters.selected)
	super()


## Troca o personagem: vida, velocidade, força e a arte.
func set_character(id: String) -> void:
	character = Characters.get_data(id)
	max_hp = character["hp"]
	hp = max_hp
	body_color = character["color"]
	body_size = character.get("body", Vector2(BODY_WIDTH, BODY_HEIGHT))
	if sprite == null:
		sprite = CharacterSprite.new()
		add_child(sprite)
	sprite.setup(character["id"], character["scale"])
	_update_sprite()


func element_color() -> Color:
	return character.get("color", GLOVE_COLOR)


func _physics_process(delta: float) -> void:
	super(delta)
	_update_sprite()


func add_meter(amount: int) -> void:
	meter = clampi(meter + amount, 0, METER_MAX)
	meter_changed.emit(meter)


## Golpe do jogador: o "vush" sai junto com o golpe (o especial tem som próprio).
func start_attack(attack: Dictionary) -> void:
	super(attack)
	if not attack.get("special", false):
		Sound.play("whiff", -9.0, 0.12)


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)


func add_life() -> void:
	Sound.play("extra_life", -4.0, 0.0)
	lives += 1
	lives_changed.emit(lives)


func is_targetable() -> bool:
	return state != State.DEAD


## Na esquiva o herói não pisca (o brilho já mostra a invencibilidade).
func _is_visible_this_frame() -> bool:
	if movement.is_dodging():
		return true
	return super()


## Bônus do combo atual: dano total x número de golpes (a partir de 3 golpes).
## A nota de estilo multiplica o bônus (B x1,25, A x1,5, S x2, SS x3).
func combo_bonus() -> int:
	if combo_hits < COMBO_MIN_HITS:
		return 0
	return roundi(_combo_damage * combo_hits * combo_rank_multiplier())


# --- Controle -----------------------------------------------------------------

func _before_frame() -> void:
	_frame += 1
	input.poll()
	for action: StringName in _buffer:
		if input.get(action):
			_buffer[action] = INPUT_BUFFER_FRAMES
	if input.attack:
		_attack_move = input.move
	_detect_double_tap()


func _on_frame() -> void:
	for action: StringName in _buffer:
		# Apertar ataque durante um golpe guarda o próximo (é assim que o combo emenda).
		if action == &"attack" and state == State.ATTACK:
			continue
		# Golpe que acertou: K e L também ficam guardados até a janela de cancelamento.
		if state == State.ATTACK and _combo_connected:
			continue
		# No ar, depois de um acerto, o próximo J também fica guardado.
		if action == &"attack" and state == State.JUMP and _jump_kicking and _air_connected:
			continue
		_buffer[action] = maxi(_buffer[action] - 1, 0)
	_dash_ready = maxi(_dash_ready - 1, 0)
	movement.tick()
	_update_charge()
	_grab_cooldown = maxi(_grab_cooldown - 1, 0)
	if _combo_timer > 0:
		_combo_timer -= 1
		if _combo_timer == 0:
			_end_combo(false)


func _consume(action: StringName) -> bool:
	if _buffer[action] > 0:
		_buffer[action] = 0
		return true
	return false


## Frente, frente: arma a investida e começa a corrida (PlayerMovement).
func _detect_double_tap() -> void:
	movement.read_input(self)


func _update_control() -> void:
	match state:
		State.JUMP:
			_update_jump()
		State.GRAB:
			_update_grab()
		_:
			_update_ground()


func _update_ground() -> void:
	if _combo_window > 0:
		_combo_window -= 1
	else:
		_combo_step = 0
	# Rolando ou no passo lateral: nada mais sai até o fim (ou até o cancelamento).
	if movement.update_dodge(self):
		return
	if _charge_release > 0:
		_charge_release = 0
		_start_hero_move("charged")
		return
	if _consume(&"special") and _start_any_special():
		return
	if movement.try_dodge(self):
		return
	if _consume(&"jump"):
		_start_jump()
		return
	if _consume(&"attack"):
		if _dash_ready > 0 or movement.running:
			# Correndo (ou logo depois do frente, frente), o ataque é a investida.
			facing = movement.run_dir if movement.running else _dash_dir
			_dash_ready = 0
			_start_player_attack(DASH_ATTACK)
		elif _combo_step == 0 and _is_back_input():
			if _attack_move.x != 0.0:
				facing = int(_attack_move.x)
			_start_hero_move("back")
		else:
			_start_player_attack(_combo_attack(_combo_step))
		return
	var move := input.move
	var facing_before := facing
	movement.ground_move(self, move)
	if facing != facing_before:
		_turn_frame = _frame
	var walking := move != Vector2.ZERO or movement.is_moving(self)
	if walking != (state == State.WALK):
		enter_state(State.WALK if walking else State.IDLE)
	# Correndo não agarra: passa direto (ou entra com a investida).
	if move.x != 0.0 and not movement.running:
		_try_grab()


# --- Golpes e combo -------------------------------------------------------------

## Cópia do golpe com o alcance da arte do herói (entre o alcance base e REACH_CAP).
func _with_art_reach(attack: Dictionary) -> Dictionary:
	var anim := _anim_of(attack)
	if sprite == null or attack.get("area", false) or attack.get("no_hit", false) or anim == "":
		return attack
	var base := float(attack.get("far", 0.0))
	var far := clampf(sprite.reach_of(anim), base, maxf(base, REACH_CAP))
	if far <= base:
		return attack
	var copy := attack.duplicate()
	copy["far"] = far
	return copy


func _walk_speed() -> Vector2:
	# Carregando o golpe (segurar J), o herói anda mais devagar.
	var charge_scale := CHARGE_WALK_SCALE if _charge > CHARGE_SLOW_AFTER else 1.0
	return WALK_SPEED * float(character.get("speed", 1.0)) * charge_scale


func _start_player_attack(attack: Dictionary, from_cancel := false) -> void:
	movement.reset()
	_combo_connected = false
	_from_cancel = from_cancel
	start_attack(_with_art_reach(attack))


## O 3º golpe muda com a direção: cima lança, frente manda voando, neutro é o gancho.
func _combo_attack(step: int) -> Dictionary:
	if step == COMBO.size() - 1:
		if _attack_move.y < 0.0:
			return LAUNCHER
		if _attack_move.x == facing:
			return FLAME_KICK
	return COMBO[step]


func _combo_index(attack: Dictionary) -> int:
	for i in COMBO.size():
		if COMBO[i]["name"] == attack.get("name"):
			return i
	return -1


func _attack_damage(attack: Dictionary) -> int:
	var damage := roundi(int(attack.get("damage", 0)) * float(character.get("power", 1.0)))
	if meter >= METER_MAX and not attack.get("special", false):
		damage += FULL_METER_BONUS
	return maxi(roundi(damage * proration()), 1)


## Escala de dano do combo: 100% nos primeiros golpes, depois cai até 40%.
func proration() -> float:
	if combo_hits < PRORATION_START:
		return 1.0
	return maxf(1.0 - PRORATION_STEP * (combo_hits - PRORATION_START + 1), PRORATION_MIN)


## Arremesso também ganha a força do herói e o bônus do medidor cheio, como a joelhada.
func _throw_damage() -> int:
	return _attack_damage({"damage": THROW_DAMAGE + (SUPLEX_BONUS if _suplex else 0)})


func _on_attack_landed(target: Fighter) -> void:
	_combo_connected = true
	# Só golpe em inimigo conta no combo e carrega o medidor (lixeira não vale).
	if not target is Enemy:
		return
	var tags := []
	if target.last_hit_counter:
		tags.append("CONTRA!")
	if _from_cancel:
		tags.append("CANCEL")
	if state == State.JUMP:
		_air_connected = true
		tags.append("AÉREO")
	if target.height > 0.0 and target.state == State.KNOCKDOWN and not current_attack.has("launch"):
		tags.append("JUGGLE")
	if current_attack.get("knockdown", false):
		tags.append("FINAL")
	_count_hit(_attack_damage(current_attack), current_attack.get("name", ""), tags)
	if current_attack.get("special2", false):
		add_meter(HeroMoves.METER_PER_PROJECTILE_HIT)
	elif not current_attack.get("special", false):
		add_meter(METER_PER_HIT)
	if current_attack.get("sends_flying", false) and not target.heavy_body:
		# O chute de brasa transforma o inimigo num projétil, como o arremesso.
		target.get_thrown(self, facing)
	if state == State.JUMP and target.height > 0.0 and _air_hangs < AIR_HANG_MAX:
		# Combo aéreo: o acerto segura o herói no ar, perto do alvo.
		_air_hangs += 1
		vz = maxf(vz, AIR_HANG_LIFT)
		velocity.x *= AIR_HANG_DRAG
	# O "push" do golpe corpo a corpo já vira o empurrão que desliza (Fighter.take_hit);
	# o HeroMoves só aplica o resto (queimadura, gelo, puxão).
	var effects := current_attack.duplicate()
	effects.erase("push")
	HeroMoves.apply_effects(self, target, effects, facing)
	_check_finishing_blow(target)


## Golpe que derruba o último inimigo de pé (ou o chefe): câmera lenta e "K.O.!".
func _check_finishing_blow(target: Fighter) -> void:
	if stage == null or target.hp > 0:
		return
	for enemy: Fighter in stage.enemies():
		if enemy.hp > 0:
			return
	# O chefe (único com "phase") ganha uma câmera lenta mais longa.
	var seconds := BOSS_SLOWMO_SECONDS if "phase" in target else KO_SLOWMO_SECONDS
	stage.slow_motion(KO_SLOWMO_SCALE, seconds)
	stage.popup("K.O.!", target.position, target.height + target.body_size.y + 8.0, Color("fff1a8"))
	stage.shake(4.0)


func _count_hit(damage: int, move := "", tags := []) -> void:
	combo_hits += 1
	_combo_damage += damage
	_combo_timer = COMBO_TIMEOUT_FRAMES
	_add_style(move, tags)
	combo_changed.emit(combo_hits, combo_bonus())


## Pontos de estilo: 1 por golpe, mais os destaques; repetir o mesmo golpe
## seguido (3 vezes ou mais) vale a metade.
func _add_style(move: String, tags: Array) -> void:
	var points := 1.0
	for tag: String in tags:
		points += STYLE_TAG_POINTS.get(tag, 0.0)
	if move != "" and _recent_moves.count(move) >= 2:
		points *= 0.5
	_recent_moves.append(move)
	if _recent_moves.size() > 3:
		_recent_moves.pop_front()
	var before := combo_rank()
	combo_style += points
	var after := combo_rank()
	combo_peak_rank = after
	for tag: String in tags:
		if tag != "FINAL" and tag != "JUGGLE":
			combo_event.emit(tag)
	if after != before:
		Sound.play("rank_up", -8.0, 0.0)
		combo_event.emit("NOTA " + after)


## Nota do combo atual (D, C, B, A, S, SS).
func combo_rank() -> String:
	return _style_rank()[1]


func combo_rank_multiplier() -> float:
	return _style_rank()[2]


func _style_rank() -> Array:
	for rank: Array in STYLE_RANKS:
		if combo_style >= rank[0]:
			return rank
	return STYLE_RANKS[-1]


## Fração do tempo que falta para o combo acabar (a barrinha embaixo do número).
func combo_time_left() -> float:
	return float(_combo_timer) / COMBO_TIMEOUT_FRAMES


func _on_thrown_body_hit(target: Fighter) -> void:
	if target is Enemy:
		_count_hit(_throw_damage(), "corpo", ["FINAL"])


func _end_combo(dropped: bool) -> void:
	if combo_hits == 0:
		return
	var bonus := 0 if dropped else combo_bonus()
	combo_ended.emit(combo_hits, bonus, dropped)
	combo_hits = 0
	_combo_damage = 0
	_combo_timer = 0
	combo_style = 0.0
	_recent_moves.clear()


## Golpe que acertou pode ser cancelado no especial (o combo continua).
func _update_attack() -> void:
	HeroMoves.on_attack_frame(self)
	if _combo_connected and not current_attack.get("special", false) and _buffer[&"special"] > 0:
		if _start_any_special():
			_buffer[&"special"] = 0
			return
	if _try_cancel():
		return
	super()


## Golpe que acertou, depois do quadro ativo: K cancela num pulo (para perseguir
## o inimigo lançado) e J emenda o próximo golpe do combo na hora.
func _try_cancel() -> bool:
	if not _combo_connected or current_attack.get("special", false):
		return false
	var startup := int(current_attack.get("startup", 0))
	var active := int(current_attack.get("active", 0))
	# O cancelamento espera a pose de impacto assentar (CANCEL_FOLLOW_TICKS): o
	# próximo J fica guardado no buffer, então nenhum aperto se perde.
	if state_frame <= startup + active + CANCEL_FOLLOW_TICKS:
		return false
	if _buffer[&"jump"] > 0:
		_buffer[&"jump"] = 0
		_start_jump(true)
		return true
	var index := _combo_index(current_attack)
	if index >= 0 and index < COMBO.size() - 1 and _buffer[&"attack"] > 0:
		_buffer[&"attack"] = 0
		_combo_step = index + 1
		_start_player_attack(_combo_attack(_combo_step), true)
		return true
	return false


func _on_attack_finished() -> void:
	var index := _combo_index(current_attack)
	if index >= 0 and _combo_connected and index < COMBO.size() - 1:
		_combo_step = index + 1
		_combo_window = COMBO_WINDOW_FRAMES
	else:
		# Errou (ou fechou o combo): a cadeia recomeça do jab.
		_combo_step = 0
		_combo_window = 0
	enter_state(State.IDLE)


func _opponents() -> Array:
	return stage.enemies() + stage.breakables() if stage else []


# --- Pulo -----------------------------------------------------------------------

func _start_jump(from_cancel := false) -> void:
	# A saída vem do PlayerMovement: andando pula na direção, correndo pula longe.
	movement.start_jump(self)
	enter_state(State.JUMP)
	_jump_kicking = false
	_air_step = 0
	_air_connected = false
	_air_hangs = 0
	_from_cancel = from_cancel
	current_attack = {}
	_attack_hits.clear()
	if input.move.x != 0.0:
		facing = int(input.move.x)
	elif from_cancel:
		# Cancelado de um golpe: o pulo vai um pouco para a frente, atrás do alvo.
		velocity.x = facing * CANCEL_JUMP_SPEED
	Sound.play("jump", -8.0)


func _update_jump() -> void:
	if _buffer[&"attack"] > 0 and not _air_move:
		if not _jump_kicking:
			_buffer[&"attack"] = 0
			if input.move.y > 0.0:
				_start_air_move()
			else:
				_start_air_attack(0)
		elif _air_connected and _air_step < AIR_CHAIN.size() - 1 \
				and state_frame - _kick_frame >= AIR_CHAIN_MIN_FRAMES:
			_buffer[&"attack"] = 0
			_start_air_attack(_air_step + 1)
	if _air_move and current_attack.has("multi") and (state_frame - _kick_frame) % int(current_attack["multi"]) == 0:
		_attack_hits.clear()
	if _jump_kicking or _air_move:
		_check_attack_hits()
	elif input.move.x != 0.0:
		# Antes do chute dá para virar no ar e mirar para o outro lado.
		facing = int(input.move.x)
	# Controle no ar e altura variável; durante o chute a trajetória fica fixa.
	movement.update_air(self, not (_jump_kicking or _air_move))
	var landing_speed := -vz
	if _fly():
		var land: Dictionary = current_attack.get("land", {}) if _air_move else {}
		_jump_kicking = false
		_air_move = false
		current_attack = {}
		if land.is_empty():
			enter_state(State.IDLE)
			movement.on_land(self, landing_speed)
		else:
			# Mergulho próprio do herói: o impacto no chão sai como golpe.
			movement.reset()
			_combo_connected = false
			start_attack(land)


## Golpe da corrente aérea (chute, soco, pisão); fica ativo até tocar o chão.
func _start_air_attack(step: int) -> void:
	_air_step = step
	_jump_kicking = true
	_kick_frame = state_frame
	_air_connected = false
	_attack_hits.clear()
	current_attack = _with_art_reach(AIR_CHAIN[step])
	if step > 0:
		_from_cancel = false
		Sound.play("whiff", -9.0, 0.12)


# --- Agarrão e arremesso ----------------------------------------------------------

func _try_grab() -> void:
	if _grab_cooldown > 0 or stage == null:
		return
	for enemy: Fighter in stage.enemies():
		if not enemy.can_be_grabbed():
			continue
		var ahead := (enemy.position.x - position.x) * facing
		if ahead > 0.0 and ahead <= GRAB_RANGE and absf(enemy.position.y - position.y) <= 6.0:
			_start_grab(enemy)
			return


func _start_grab(target: Fighter) -> void:
	_grabbed = target
	_knees = 0
	_knee_timer = 0
	# De costas para o herói: agarrão pelas costas (o arremesso vira suplex).
	_back_grab = target.facing == facing
	movement.reset()
	Sound.play("grab", -6.0)
	target.become_grabbed(self)
	enter_state(State.GRAB)
	_hold_grabbed()


func _hold_grabbed() -> void:
	_grabbed.position = Vector2(position.x + facing * GRAB_HOLD_DISTANCE, position.y)


func _update_grab() -> void:
	if not is_instance_valid(_grabbed) or _grabbed.state != State.GRABBED:
		_end_grab()
		return
	if movement.is_vaulting():
		# Salto por cima: o inimigo fica parado e o herói pousa nas costas dele.
		if movement.update_vault(self):
			facing = -facing
			_back_grab = true
			_knees = 0
			state_frame = 0
		return
	_hold_grabbed()
	if _knee_timer > 0:
		_knee_timer -= 1
		if _knee_timer == KNEE_FRAMES - KNEE_HIT_FRAME:
			var damage := _attack_damage({"damage": KNEE_DAMAGE})
			if _grabbed.take_hit(damage, false, self):
				add_meter(METER_PER_HIT)
				_count_hit(damage, "joelhada")
		return
	if _consume(&"jump"):
		movement.start_vault(self)
		return
	if _consume(&"special"):
		# Só solta quem está preso se o especial sair de fato.
		if _start_any_special():
			_release_grabbed()
		return
	if _consume(&"attack"):
		var dir := int(input.move.x)
		if _back_grab and (dir != 0 or _knees >= MAX_KNEES):
			# Pelas costas: qualquer arremesso é o suplex, por cima do herói.
			_suplex = true
			_throw(-facing)
		elif dir != 0 or _knees >= MAX_KNEES:
			_throw(dir if dir != 0 else facing)
		else:
			_knees += 1
			_knee_timer = KNEE_FRAMES
		return
	if state_frame >= GRAB_FRAMES:
		_release_grabbed()


func _throw(dir: int) -> void:
	var target := _grabbed
	_grabbed = null
	facing = dir
	target.position.x = position.x + dir * 8.0
	target.get_thrown(self, dir)
	Sound.play("throw", -5.0)
	add_meter(METER_PER_THROW)
	_count_hit(_throw_damage(), "suplex" if _suplex else "arremesso", ["FINAL"])
	if _suplex and stage:
		stage.shake(2.5)
	_suplex = false
	_back_grab = false
	_grab_cooldown = GRAB_COOLDOWN_FRAMES
	_combo_connected = false
	start_attack(THROW_ANIM)
	if stage:
		stage.notify_enemy_hit(target)


func _release_grabbed() -> void:
	if is_instance_valid(_grabbed) and _grabbed.state == State.GRABBED:
		_grabbed.release_from_grab()
		_grabbed.position.x += facing * 8.0
	_end_grab()


func _end_grab() -> void:
	_grabbed = null
	_back_grab = false
	if movement.is_vaulting():
		movement.reset()
		height = 0.0
	_grab_cooldown = GRAB_COOLDOWN_FRAMES
	if state == State.GRAB:
		enter_state(State.IDLE)


func _on_grab_interrupted() -> void:
	_release_grabbed()


# --- Especial elemental -----------------------------------------------------------

## Erupção: gasta 50 do medidor; sem medidor, custa 15 de vida (nunca mata).
func _start_special() -> bool:
	if meter >= SPECIAL_COST:
		add_meter(-SPECIAL_COST)
	elif hp > 1:
		hp -= mini(SPECIAL_HP_COST, hp - 1)
		health_changed.emit(hp, max_hp)
	else:
		return false
	var attack := special_attack()
	start_attack(attack)
	Sound.special(character.get("element", "Fogo"))
	invuln = attack["startup"] + attack["active"] + attack["recovery"]
	if stage:
		stage.shake(1.5)
	_note_special()
	return true


## O especial também serve de fuga quando o herói está apanhando.
func _update_hurt() -> void:
	if _consume(&"special") and _start_special():
		return
	super()


# --- Dano, morte e vidas -----------------------------------------------------------

## Postura de contra-ataque (Metal): apanhar no ativo dela não dói e dispara o revide.
func take_hit(damage: int, knockdown: bool, from: Node2D, launch := 0.0) -> bool:
	if _try_counter(from):
		return false
	last_hit_by = from
	return super(Difficulty.damage(damage), knockdown, from, launch)


## Golpes pesados (Terra, Cristal) seguram o tranco enquanto saem.
func _resists_stagger() -> bool:
	return super() or (state == State.ATTACK and current_attack.get("armor", false))


func _on_damaged(_damage: int, heavy: bool) -> void:
	_end_combo(true)
	movement.reset()
	_jump_kicking = false
	_air_move = false
	_charge = 0
	_charge_release = 0
	_combo_step = 0
	_combo_window = 0
	if heavy:
		add_meter(-meter)


func _die() -> void:
	deaths += 1
	lives -= 1
	lives_changed.emit(lives)
	super()
	Sound.play("ko", -4.0, 0.0)
	if lives <= 0 and (stage == null or stage.is_game_over()):
		Sound.stop_music()
		Sound.play("game_over", 0.0, 0.0)
		game_over.emit()


func _update_dead() -> void:
	if lives > 0 and state_frame >= RESPAWN_FRAMES:
		hp = max_hp
		health_changed.emit(hp, max_hp)
		height = 0.0
		enter_state(State.IDLE)
		invuln = RESPAWN_INVULN_FRAMES


# --- Desenho -------------------------------------------------------------------------

func _limb_color() -> Color:
	if meter >= METER_MAX and _frame % 12 < 6:
		return Color("fff1a8")
	return GLOVE_COLOR


func _draw_details(body: Rect2) -> void:
	# Bandana que fica para trás.
	var tail_x := body.position.x + (-6.0 if facing > 0 else BODY_WIDTH)
	draw_rect(Rect2(Vector2(body.position.x, body.position.y + 2.0), Vector2(BODY_WIDTH, 3.0)), BANDANA_COLOR)
	draw_rect(Rect2(Vector2(tail_x, body.position.y + 3.0), Vector2(6.0, 2.0)), BANDANA_COLOR)
	# Luvas em repouso.
	if state != State.ATTACK and state != State.GRAB:
		var glove_x := body.position.x + BODY_WIDTH / 2.0 + facing * 7.0 - 3.0
		draw_rect(Rect2(Vector2(glove_x, body.position.y + 22.0), Vector2(6.0, 6.0)), _limb_color())
	if state == State.JUMP and _jump_kicking:
		var leg_x := body.position.x + BODY_WIDTH / 2.0
		_draw_reach(leg_x, body.end.y - 14.0, 26.0, 6.0)
	if state == State.GRAB and _knee_timer > KNEE_FRAMES - KNEE_HIT_FRAME - 4:
		var knee_x := body.position.x + BODY_WIDTH / 2.0 + facing * 8.0 - 4.0
		draw_rect(Rect2(Vector2(knee_x, body.position.y + 24.0), Vector2(8.0, 8.0)), body_color.lightened(0.2))


func _draw_effects() -> void:
	if state == State.ATTACK and current_attack.get("name") == "investida":
		for i in 3:
			var trail_x := -facing * (8.0 + i * 7.0) - 2.0
			var trail_color := element_color()
			trail_color.a = 0.7 - i * 0.2
			draw_rect(Rect2(Vector2(trail_x, -height - body_size.y + 14.0 + i * 8.0), Vector2(4.0, 4.0)), trail_color)
	if state == State.ATTACK and current_attack.get("special", false):
		_draw_eruption()


func _draw_eruption() -> void:
	var startup: int = current_attack["startup"]
	var active: int = current_attack["active"]
	var radius: float = current_attack["far"]
	var t := clampf(float(state_frame) / float(startup + active), 0.0, 1.0)
	if state_frame > startup + active:
		t = 1.0 - clampf(float(state_frame - startup - active) / float(current_attack["recovery"]), 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	var color := element_color()
	draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 32, color, 3.0)
	draw_arc(Vector2.ZERO, radius * t * 0.7, 0.0, TAU, 24, color.lightened(0.4), 2.0)
	draw_set_transform(Vector2.ZERO)
	if state_frame > startup and state_frame <= startup + active:
		for i in 8:
			var x := -radius + i * (radius * 2.0 / 7.0)
			var flame_h := 10.0 + float((i * 7 + state_frame * 3) % 12)
			var flame := color.lightened(0.3 * (i % 2))
			flame.a = 0.85
			draw_rect(Rect2(Vector2(x - 2.0, -flame_h), Vector2(4.0, flame_h)), flame)


# --- Arte ------------------------------------------------------------------------------

## Escolhe animação, quadro e inclinação da arte a partir do estado de jogo.
func _update_sprite() -> void:
	if sprite == null:
		return
	var lift := height
	sprite.modulate = PlayerMovement.DODGE_TINT if movement.dodge_invulnerable(self) else Color.WHITE
	if movement.is_dodging():
		_show_once("roll", movement.dodge_frame, PlayerMovement.ROLL_FRAMES if \
			movement.dodge == PlayerMovement.Dodge.ROLL else PlayerMovement.SIDESTEP_FRAMES)
		sprite.set_pose(facing, lift, flash > 0 and flash % 4 < 2)
		return
	match state:
		State.IDLE:
			_show_loop("idle", IDLE_TICKS)
		State.WALK:
			if movement.skid > 0 and not movement.running:
				sprite.show_frame("defend", 0)
			else:
				_show_loop("run", RUN_TICKS_FAST if movement.running else RUN_TICKS)
		State.JUMP:
			if _jump_kicking:
				var air_anim: String = ATTACK_ANIMS.get(current_attack.get("name", ""), "air_atk")
				_show_once(air_anim, state_frame - _kick_frame, AIR_ATTACK_FRAMES)
			elif _air_move:
				_show_once(_anim_of(current_attack), state_frame - _kick_frame, AIR_ATTACK_FRAMES)
			else:
				sprite.show_frame("j_up" if vz > 0.0 else "j_down", state_frame / JUMP_TICKS)
		State.ATTACK:
			_show_attack()
		State.GRAB:
			if movement.is_vaulting():
				sprite.show_frame("j_up" if movement.vault_frame < PlayerMovement.VAULT_FRAMES / 2 else "j_down", 1)
			elif _knee_timer > 0:
				_show_once("atk1", KNEE_FRAMES - _knee_timer, KNEE_FRAMES)
			else:
				sprite.show_frame("defend", 0)
		State.HURT, State.GRABBED:
			_show_once("take_hit", state_frame, HITSTUN_FRAMES)
		State.KNOCKDOWN, State.THROWN:
			# No ar vai caindo até o quadro caído; no chão fica nele.
			var down: int = character.get("down", 0)
			sprite.show_frame("death", mini(state_frame * down / FALL_FRAMES, down) if _airborne else down)
		State.GETUP:
			var down: int = character.get("down", 0)
			sprite.show_frame("death", down - state_frame * down / GETUP_FRAMES)
		State.DEAD:
			sprite.show_frame("death", state_frame / DEATH_TICKS)
	sprite.set_pose(facing, lift, flash > 0 and flash % 4 < 2)
	# Golpe carregado pronto: o herói pisca na cor do elemento.
	if _charge >= HeroMoves.CHARGE_FRAMES:
		sprite.modulate = Color.WHITE.lerp(element_color() * 1.6, 0.6 if _frame % 8 < 4 else 0.25)
	elif sprite.modulate != Color.WHITE:
		sprite.modulate = Color.WHITE


func _show_loop(anim: String, ticks: int) -> void:
	sprite.show_frame(anim, _frame / ticks % sprite.frames_of(anim))


func _show_once(anim: String, elapsed: int, duration: int) -> void:
	sprite.show_frame(anim, elapsed * sprite.frames_of(anim) / maxi(duration, 1))


## A arte do golpe anima por poses (ver CharacterSprite.attack_frame): preparo
## que leva ao impacto, impacto segurado no quadro ativo e recuperação até o fim.
func _show_attack() -> void:
	var anim := _anim_of(current_attack)
	if anim == "":
		anim = "atk1"
	if current_attack.has("art_tpf"):
		sprite.show_frame(anim, CharacterSprite.art_frame_at(current_attack, state_frame))
		return
	sprite.show_frame(anim, sprite.attack_frame(anim, state_frame, int(current_attack.get("startup", 0)),
		int(current_attack.get("active", 0)), int(current_attack.get("recovery", 0)),
		current_attack.get("special", false) or current_attack.get("full_art", false)))


## O especial com o tempo da arte do herói (SPECIAL_ART): o dano sai quando o
## efeito desenhado chega, dura enquanto ele está na tela, e a animação toca do
## primeiro ao último quadro.
func special_attack() -> Dictionary:
	var attack := SPECIAL.duplicate()
	if sprite == null:
		return attack
	var id: String = character.get("id", Characters.DEFAULT_ID)
	var art: Dictionary = SPECIAL_ART.get(id, {})
	var count := sprite.frames_of("sp_atk")
	if art.is_empty() or count < 2:
		return attack
	attack["anim"] = "sp_atk"
	attack["art_from"] = 0
	attack["art_to"] = count - 1
	attack["art_impact"] = clampi(int(art["impact"]), 1, count - 1)
	attack["art_end"] = clampi(int(art["end"]), int(attack["art_impact"]), count - 1)
	attack["art_tpf"] = int(art["tpf"])
	attack["art_windup_tpf"] = int(art.get("windup", art["tpf"]))
	attack["far"] = clampf(sprite.reach_of("sp_atk") - 8.0, float(SPECIAL["far"]), SPECIAL_MAX_REACH)
	attack["near"] = float(art.get("near", SPECIAL["near"]))
	return CharacterSprite.art_timing(attack)


## Efeito visual do especial (assets/vfx) para o elemento do herói.
static func special_effect(element: String) -> String:
	var key := element.to_lower().replace("á", "a")
	return "special_" + key if key in ["fogo", "agua", "vento", "folha", "terra", "cristal", "metal"] \
		else "special_fogo"


# --- Golpes próprios de cada herói (HeroMoves) ---------------------------------------

## Animação da arte que um golpe usa: a do próprio golpe ou a da tabela ATTACK_ANIMS.
func _anim_of(attack: Dictionary) -> String:
	if attack.has("anim"):
		return attack["anim"]
	return ATTACK_ANIMS.get(attack.get("name", ""), "")


## Segurar J carrega; soltar com a carga cheia guarda o golpe carregado para sair
## assim que o herói estiver livre.
func _update_charge() -> void:
	_charge_release = maxi(_charge_release - 1, 0)
	var can_charge := state in [State.IDLE, State.WALK, State.ATTACK]
	if input.attack_held and can_charge:
		_charge += 1
		if _charge == HeroMoves.CHARGE_FRAMES:
			Sound.play("charge_ready", -8.0, 0.0)
		return
	if _charge >= HeroMoves.CHARGE_FRAMES and can_charge:
		_charge_release = INPUT_BUFFER_FRAMES * 2
	_charge = 0


func is_charged() -> bool:
	return _charge >= HeroMoves.CHARGE_FRAMES


## Trás + J: a direção oposta segurada no aperto, ou uma virada bem recente com
## a direção ainda segurada (o toque para trás vira o herói um quadro antes do J).
func _is_back_input() -> bool:
	if _attack_move.x == 0.0:
		return false
	if int(_attack_move.x) != facing:
		return true
	return _frame - _turn_frame <= HeroMoves.BACK_TURN_FRAMES


func hero_move(slot: String) -> Dictionary:
	return HeroMoves.get_move(character.get("id", Characters.DEFAULT_ID), slot)


func _start_hero_move(slot: String) -> void:
	var move := hero_move(slot)
	_start_player_attack(move)
	_announce(move)


func _announce(move: Dictionary) -> void:
	if move.has("label"):
		move_used.emit(move["label"], element_color())


## L sai como especial; baixo + L sai como especial secundário.
func _start_any_special() -> bool:
	if input.move.y > 0.0:
		return _start_special2()
	return _start_special()


## Especial secundário: gasta 30 do medidor; sem medidor custa 10 de vida
## (nunca mata). A cura da Água só sai com medidor.
func _start_special2() -> bool:
	var move := hero_move("special2")
	var cost := int(move.get("meter_cost", HeroMoves.SPECIAL2_COST))
	if meter >= cost:
		add_meter(-cost)
	elif move.get("hp_ok", true) and hp > 1:
		hp -= mini(HeroMoves.SPECIAL2_HP_COST, hp - 1)
		health_changed.emit(hp, max_hp)
	else:
		return false
	move["special2"] = true
	_combo_connected = false
	start_attack(_with_art_reach(move))
	invuln = maxi(invuln, int(move.get("startup", 0)))
	Sound.special(character.get("element", "Fogo"))
	_announce(move)
	_note_special()
	return true


## No ar, baixo + J: o golpe aéreo do herói (mergulho com impacto ou chuva de flechas).
func _start_air_move() -> void:
	var move := hero_move("air")
	_air_move = true
	_kick_frame = state_frame
	_attack_hits.clear()
	current_attack = _with_art_reach(move)
	if move.has("dive"):
		var dive: Vector2 = move["dive"]
		velocity = Vector2(facing * dive.x, 0.0)
		vz = dive.y
	Sound.play("whiff", -6.0, 0.12)
	_announce(move)


## Projétil do herói que acertou: conta no combo, carrega um pouco o medidor e
## aplica o efeito do elemento.
func _on_projectile_hit(target: Fighter, data: Dictionary, dir: int, damage: int) -> void:
	HeroMoves.apply_effects(self, target, data, dir)
	if not target is Enemy:
		return
	_count_hit(damage)
	add_meter(HeroMoves.METER_PER_PROJECTILE_HIT)
	if stage:
		stage.notify_enemy_hit(target)


## Golpe que não acerta por si (só dispara projétil ou efeito).
func _check_attack_hits() -> void:
	if current_attack.get("no_hit", false):
		return
	super()


func _try_counter(from: Node2D) -> bool:
	if state != State.ATTACK or not current_attack.get("counter", false) or invuln > 0:
		return false
	var startup := int(current_attack.get("startup", 0))
	if state_frame <= startup or state_frame > startup + int(current_attack.get("active", 0)):
		return false
	if from != null and from.position.x != position.x:
		facing = 1 if from.position.x > position.x else -1
	var riposte := {"name": "revide", "label": "Revide de Aço", "anim": "sp_atk", "startup": 2, "active": 5,
		"recovery": 16, "damage": 24, "near": -10.0, "far": 44.0, "depth": 14.0, "knockdown": true,
		"fx": "special_metal", "shake": 3.0}
	_combo_connected = false
	start_attack(riposte)
	invuln = RIPOSTE_INVULN_FRAMES
	_announce(riposte)
	Sound.play("slash", -2.0)
	return true


## Marca o especial para o ataque em dupla: se o parceiro soltou o dele junto, sai a fusão.
func _note_special() -> void:
	last_special_tick = Engine.get_physics_frames()
	HeroMoves.try_team_attack(self)

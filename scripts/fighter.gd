class_name Fighter
extends Node2D
## Base de jogador e inimigos: vida, estados, golpes, dano e o pseudo-3D.
##
## Pseudo-3D: position.x é a posição horizontal e position.y é a profundidade,
## a linha do chão onde ficam os pés. A altura do pulo fica em `height` e só sobe
## o desenho; a sombra continua no chão. Com y_sort no nó Actors, todo mundo é
## ordenado pelos pés, como nos clássicos.
##
## A lógica roda em quadros de física (60 por segundo), porque o combate é
## contado em quadros: hit stop, hit stun, invencibilidade.
##
## Um golpe é um Dictionary com:
##   name, startup, active, recovery (quadros), damage, knockdown (bool),
##   near/far (alcance horizontal à frente, em px), depth (tolerância de
##   profundidade), y_lo/y_hi (faixa de altura acima dos pés), area (acerta dos
##   dois lados), move_speed (avança durante o golpe).
## Sensação do impacto (opcionais, veja "Sensação do combate" abaixo):
##   hitstop (quadros congelados no acerto), push (empurrão em px/s no alvo
##   atordoado), shake (tremor de tela), spike (crava o alvo no chão e ele quica).

signal health_changed(hp: int, max_hp: int)
signal died(fighter: Fighter)

enum State { IDLE, WALK, ATTACK, JUMP, GRAB, GRABBED, HURT, KNOCKDOWN, GETUP, THROWN, DEAD }

const DT := 1.0 / 60.0
const GRAVITY := 900.0
const BODY_WIDTH := 20.0
const BODY_HEIGHT := 48.0
## Caixa de profundidade de 16 px: o golpe só acerta com até 8 px de diferença.
const DEPTH_TOLERANCE := 8.0
const HITSTUN_FRAMES := 12
const HITSTOP_FRAMES := 3
const HITSTOP_KNOCKDOWN_FRAMES := 6
const KNOCKDOWN_GROUND_FRAMES := 40
const GETUP_FRAMES := 12
const GETUP_INVULN_FRAMES := 20
const KNOCKDOWN_SPEED := 70.0
const KNOCKDOWN_LIFT := 160.0
const THROW_SPEED := 170.0
const THROW_LIFT := 170.0
const THROW_DAMAGE := 12
## Juggle: um inimigo lançado aguenta até 3 golpes no ar antes de cair de vez.
## Juggle: um inimigo lançado aguenta até JUGGLE_HITS golpes no ar antes de cair
## de vez, e cada golpe o levanta um pouco menos (JUGGLE_DECAY), então o combo
## aéreo tem começo, meio e fim sem precisar de um corte seco.
const JUGGLE_HITS := 6
const JUGGLE_LIFT := 150.0
const JUGGLE_DECAY := 0.86
const JUGGLE_SPEED := 10.0
const LAUNCH_SPEED := 8.0

# --- Sensação do combate --------------------------------------------------------
## Contra-ataque: acertar quem está na antecipação do próprio golpe.
const COUNTER_DAMAGE_MULT := 1.5
const COUNTER_HITSTOP_BONUS := 4
## Golpe que zera a vida congela mais tempo.
const KO_HITSTOP_FRAMES := 12
## Empurrão do alvo atordoado (px/s), que freia a cada quadro.
const HURT_PUSH := 60.0
const HURT_PUSH_FRICTION := 0.8
## Tremor do sprite de quem apanhou durante o hit stop (px).
const HIT_JITTER := 1.5
## Pisão (spike): o alvo desce rápido, quica no chão e pode ser golpeado de novo.
const SPIKE_SPEED := 260.0
const BOUNCE_LIFT := 170.0
const BOUNCE_JUGGLE_HITS := 2

@export var max_hp := 100
@export var body_color := Color.WHITE
## Tamanho da hurtbox (e do retângulo placeholder): largura x altura.
@export var body_size := Vector2(BODY_WIDTH, BODY_HEIGHT)
## Golpes leves seguidos que o lutador aguenta sem entrar em hit stun (armadura).
@export var armor_hits := 0
## Corpo pesado (Brutamontes, chefe): não é lançado nem arremessado por golpes.
@export var heavy_body := false

var hp := 0
var facing := 1
var state := State.IDLE
var state_frame := 0
var height := 0.0
## Velocidade no chão: x horizontal, y profundidade (px/s).
var velocity := Vector2.ZERO
var vz := 0.0
var hitstop := 0
var invuln := 0
var flash := 0
var stage: Stage
var current_attack: Dictionary = {}

var _attack_hits: Array = []
var _airborne := false
var _thrown_hits: Array = []
var _armor_left := 0
var _armor_timer := 0
var _juggle_left := 0
var _thrown_by: Fighter
var _thrown_damage := THROW_DAMAGE
## Golpes no ar já levados neste voo (o levantamento diminui a cada um).
var _juggle_taken := 0
var _bounce_pending := false
var _bounced := false
var _push := 0.0
var _jitter := 0
## O último golpe recebido foi um contra-ataque (para o HUD e os testes).
var last_hit_counter := false
## Arte do personagem; sem ela o lutador é desenhado com retângulos.
var sprite: CharacterSprite

const ARMOR_RESET_FRAMES := 90


func _ready() -> void:
	hp = max_hp
	_armor_left = armor_hits


func _physics_process(_delta: float) -> void:
	_before_frame()
	if hitstop > 0:
		hitstop -= 1
		queue_redraw()
		return
	_jitter = 0
	state_frame += 1
	invuln = maxi(invuln - 1, 0)
	flash = maxi(flash - 1, 0)
	_armor_timer = maxi(_armor_timer - 1, 0)
	if _armor_timer == 0:
		_armor_left = armor_hits
	_on_frame()
	match state:
		State.ATTACK:
			_update_attack()
		State.HURT:
			_update_hurt()
		State.KNOCKDOWN:
			_update_knockdown()
		State.GETUP:
			if state_frame >= GETUP_FRAMES:
				enter_state(State.IDLE)
		State.THROWN:
			_update_thrown()
		State.DEAD:
			_update_dead()
		State.GRABBED:
			pass
		_:
			_update_control()
	_keep_inside_arena()
	queue_redraw()


func enter_state(new_state: State) -> void:
	state = new_state
	state_frame = 0


func can_be_hit() -> bool:
	if invuln > 0:
		return false
	if state == State.KNOCKDOWN:
		return _airborne and _juggle_left > 0
	return state not in [State.GETUP, State.THROWN, State.DEAD]


func is_juggled() -> bool:
	return state == State.KNOCKDOWN and _airborne and _juggle_left > 0


func can_be_grabbed() -> bool:
	return invuln == 0 and height == 0.0 and state in [State.IDLE, State.WALK]


## Na antecipação de um golpe: quem acerta agora faz contra-ataque.
func is_in_startup() -> bool:
	return state == State.ATTACK and state_frame <= int(current_attack.get("startup", 0)) \
		and not current_attack.is_empty()


## Quadros de hit stop de um acerto: o golpe pode pedir o seu ("hitstop"), o que
## derruba congela mais, o contra-ataque soma e o golpe final congela mais ainda.
func hitstop_for(attack: Dictionary, heavy: bool, counter: bool) -> int:
	var stop := HITSTOP_KNOCKDOWN_FRAMES if heavy else HITSTOP_FRAMES
	stop = int(attack.get("hitstop", stop))
	if counter:
		stop += COUNTER_HITSTOP_BONUS
	if hp == 0:
		stop = maxi(stop, KO_HITSTOP_FRAMES)
	return stop


## Deslocamento do desenho de quem apanhou durante o hit stop (o View3D aplica).
func hit_jitter() -> float:
	if hitstop <= 0 or _jitter <= 0:
		return 0.0
	return HIT_JITTER if hitstop % 2 == 0 else -HIT_JITTER


func start_attack(attack: Dictionary) -> void:
	current_attack = attack
	_attack_hits.clear()
	enter_state(State.ATTACK)


## Aplica um golpe. Devolve false se o alvo não podia ser atingido.
## `launch` > 0 lança o alvo para cima (velocidade vertical) e abre o juggle.
func take_hit(damage: int, knockdown: bool, from: Node2D, launch := 0.0) -> bool:
	if not can_be_hit():
		return false
	var held := state == State.GRABBED
	var juggled := state == State.KNOCKDOWN
	# Contra-ataque: pego no meio da antecipação do próprio golpe.
	var counter := is_in_startup()
	last_hit_counter = counter
	if counter:
		damage = roundi(damage * COUNTER_DAMAGE_MULT)
	var attack: Dictionary = from.current_attack if from is Fighter else {}
	if state == State.GRAB:
		_on_grab_interrupted()
	hp = maxi(hp - damage, 0)
	health_changed.emit(hp, max_hp)
	flash = 10
	var dir := 1.0 if position.x >= from.position.x else -1.0
	facing = -int(dir)
	# Armadura segura até golpe que derruba: o corpo pesado só cai quando ela acaba.
	var armored := _resists_stagger() and hp > 0 and height == 0.0 and not held
	var heavy := hp == 0 or height > 0.0 or (knockdown and not armored)
	var stop := hitstop_for(attack, heavy, counter)
	hitstop = stop
	_jitter = stop
	if from is Fighter:
		from.hitstop = maxi(from.hitstop, stop)
	if heavy:
		knock_down(dir, 0.0 if heavy_body else launch, juggled, attack.get("spike", false) and not heavy_body)
		if stage:
			stage.shake(float(attack.get("shake", 2.0)) + (1.0 if hp == 0 else 0.0))
	elif armored:
		# Armadura: leva o dano, pisca, mas continua o que estava fazendo.
		_armor_left = maxi(_armor_left - 1, 0)
	elif not held:
		enter_state(State.HURT)
		# Empurrão que freia: o alvo desliza um pouco em vez de pular de lugar.
		_push = dir * float(attack.get("push", HURT_PUSH))
		if stage and attack.has("shake"):
			stage.shake(float(attack["shake"]))
	_armor_timer = ARMOR_RESET_FRAMES
	if self is Player:
		Sound.play("hurt", -4.0)
	Sound.play("hit_heavy" if heavy else "hit")
	if stage:
		# Faísca na borda do corpo virada para quem bateu.
		stage.fx("hit_heavy" if heavy else "hit", position - Vector2(dir * body_size.x * 0.35, 0.0),
			height + body_size.y * 0.6, dir < 0.0)
	if from is Player and stage:
		# Número do dano subindo do alvo; contra-ataque ganha aviso próprio.
		var top := height + body_size.y * 0.8
		stage.popup(str(damage), position, top, Color("fff1a8") if counter else Color.WHITE)
		if counter:
			Sound.play("counter", -6.0)
			stage.popup("CONTRA!", position, top + 12.0, Color("ff5a3c"))
	_on_damaged(damage, heavy)
	return true


func knock_down(dir: float, launch := 0.0, juggled := false, spike := false) -> void:
	enter_state(State.KNOCKDOWN)
	_airborne = true
	_bounce_pending = false
	if not juggled:
		_juggle_taken = 0
		_bounced = false
	# Pisão: crava o alvo no chão; ele quica uma vez por voo.
	if spike and not _bounced:
		velocity = Vector2(dir * JUGGLE_SPEED, 0.0)
		vz = -SPIKE_SPEED
		_bounce_pending = true
		if juggled:
			_juggle_left -= 1
			_juggle_taken += 1
		return
	# Só lança quem está em pé: o lançador num alvo já no ar conta como golpe de juggle.
	if launch > 0.0 and not juggled:
		velocity = Vector2(dir * LAUNCH_SPEED, 0.0)
		vz = launch
		_juggle_left = JUGGLE_HITS
	elif juggled:
		velocity = Vector2(dir * JUGGLE_SPEED, 0.0)
		# Cada golpe no ar levanta menos: o combo aéreo acaba sozinho.
		vz = JUGGLE_LIFT * pow(JUGGLE_DECAY, _juggle_taken)
		_juggle_left -= 1
		_juggle_taken += 1
	else:
		velocity = Vector2(dir * KNOCKDOWN_SPEED, 0.0)
		vz = KNOCKDOWN_LIFT
		_juggle_left = 0


func become_grabbed(by: Fighter) -> void:
	enter_state(State.GRABBED)
	facing = -by.facing
	_on_grabbed()


func release_from_grab() -> void:
	if state == State.GRABBED:
		enter_state(State.IDLE)


func get_thrown(by: Fighter, dir: int) -> void:
	enter_state(State.THROWN)
	facing = -dir
	_thrown_hits.clear()
	_thrown_hits.append(by)
	_thrown_by = by
	_thrown_damage = by._throw_damage()
	height = maxf(height, 12.0)
	velocity = Vector2(dir * THROW_SPEED, 0.0)
	vz = THROW_LIFT


# --- Ganchos para as subclasses -------------------------------------------

## Roda todo quadro, inclusive durante o hit stop (para ler o controle).
func _before_frame() -> void:
	pass


## Roda nos quadros em que o lutador não está congelado.
func _on_frame() -> void:
	pass


## IDLE, WALK, JUMP e GRAB: quem decide é o jogador ou a IA.
func _update_control() -> void:
	pass


func _opponents() -> Array:
	return []


func _allies() -> Array:
	return []


func _attack_damage(attack: Dictionary) -> int:
	return attack.get("damage", 0)


func _on_attack_landed(_target: Fighter) -> void:
	pass


func _on_attack_finished() -> void:
	enter_state(State.IDLE)


func _on_damaged(_damage: int, _heavy: bool) -> void:
	pass


func _on_grabbed() -> void:
	pass


## Quem arremessou (ou chutou) este lutador fica sabendo que ele acertou alguém.
func _on_thrown_body_hit(_target: Fighter) -> void:
	pass


func _on_grab_interrupted() -> void:
	pass


func _update_dead() -> void:
	pass


func _clamps_x() -> bool:
	return true


func _limb_color() -> Color:
	return body_color.darkened(0.35)


## Dano de quem este lutador arremessa (na queda e em quem o corpo acertar).
func _throw_damage() -> int:
	return THROW_DAMAGE


## Golpe que acerta agora não interrompe nem derruba (armadura ou super armadura).
func _resists_stagger() -> bool:
	return _armor_left > 0


## Efeitos que aparecem com ou sem arte (rastro da investida, especial).
func _draw_effects() -> void:
	pass


func _draw_details(_body: Rect2) -> void:
	pass


# --- Estados comuns ---------------------------------------------------------

func _update_attack() -> void:
	var a := current_attack
	var startup: int = a.get("startup", 0)
	var active: int = a.get("active", 0)
	var recovery: int = a.get("recovery", 0)
	if state_frame > startup and state_frame <= startup + active:
		position.x += facing * float(a.get("move_speed", 0.0)) * DT
		_check_attack_hits()
	if state_frame >= startup + active + recovery:
		_on_attack_finished()


func _update_hurt() -> void:
	if _push != 0.0:
		position.x += _push * DT
		_push *= HURT_PUSH_FRICTION
		if absf(_push) < 4.0:
			_push = 0.0
	if state_frame >= HITSTUN_FRAMES:
		enter_state(State.IDLE)


func _update_knockdown() -> void:
	if _airborne:
		if _fly():
			if _bounce_pending:
				_ground_bounce()
				return
			_airborne = false
			_juggle_left = 0
			state_frame = 0
			if stage:
				stage.fx("dust", position)
		return
	if state_frame >= KNOCKDOWN_GROUND_FRAMES:
		if hp <= 0:
			_die()
		else:
			enter_state(State.GETUP)
			invuln = GETUP_INVULN_FRAMES


## Quica no chão depois do pisão: sobe de novo e aguenta mais uns golpes.
func _ground_bounce() -> void:
	_bounce_pending = false
	_bounced = true
	vz = BOUNCE_LIFT
	_juggle_left = maxi(_juggle_left, BOUNCE_JUGGLE_HITS)
	state_frame = 0
	if stage:
		stage.fx("dust", position)
		stage.shake(3.0)
		stage.popup("QUICOU!", position, height + body_size.y, Color("ffcc33"))
	Sound.play("hit_heavy", -6.0)


func _update_thrown() -> void:
	for other in _allies():
		if other in _thrown_hits or not other.can_be_hit():
			continue
		if absf(other.position.x - position.x) < (body_size.x + other.body_size.x) / 2.0 \
				and absf(other.position.y - position.y) <= DEPTH_TOLERANCE:
			_thrown_hits.append(other)
			if other.take_hit(_thrown_damage, true, self) and is_instance_valid(_thrown_by):
				_thrown_by._on_thrown_body_hit(other)
	if _fly():
		hp = maxi(hp - _thrown_damage, 0)
		health_changed.emit(hp, max_hp)
		flash = 10
		if stage:
			stage.shake(3.0)
		enter_state(State.KNOCKDOWN)
		_airborne = false


func _die() -> void:
	enter_state(State.DEAD)
	died.emit(self)


## Move no ar. Devolve true no quadro em que toca o chão.
func _fly() -> bool:
	position += velocity * DT
	height += vz * DT
	vz -= GRAVITY * DT
	if height > 0.0:
		return false
	height = 0.0
	vz = 0.0
	velocity = Vector2.ZERO
	return true


func _check_attack_hits() -> void:
	for target in _opponents():
		if target in _attack_hits or not target.can_be_hit():
			continue
		if not _attack_reaches(current_attack, target):
			continue
		_attack_hits.append(target)
		var launch: float = current_attack.get("launch", 0.0)
		if target.take_hit(_attack_damage(current_attack), current_attack.get("knockdown", false), self, launch):
			_on_attack_landed(target)


## Hitbox contra hurtbox, sempre em caixas: profundidade, alcance e altura.
func _attack_reaches(a: Dictionary, target: Fighter) -> bool:
	if absf(target.position.y - position.y) > a.get("depth", DEPTH_TOLERANCE):
		return false
	var dx := (target.position.x - position.x) * facing
	if a.get("area", false):
		dx = absf(target.position.x - position.x)
	var half := target.body_size.x / 2.0
	if dx < float(a.get("near", 0.0)) - half or dx > float(a.get("far", 0.0)) + half:
		return false
	var lo := height + float(a.get("y_lo", 16.0))
	var hi := height + float(a.get("y_hi", 40.0))
	return hi >= target.height and lo <= target.height + target.body_size.y


func _keep_inside_arena() -> void:
	if stage == null:
		return
	var r := stage.floor_rect
	position.y = clampf(position.y, r.position.y, r.end.y)
	if _clamps_x():
		# Corpos largos (Brutamontes, chefe) ficam um pouco mais para dentro da tela.
		var inset := maxf(body_size.x / 2.0 - 10.0, 0.0)
		position.x = clampf(position.x, r.position.x + inset, r.end.x - inset)


# --- Desenho placeholder ------------------------------------------------------

func _draw() -> void:
	# Sombra elíptica fixa no chão: é ela que mostra a profundidade no pulo.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if sprite:
		sprite.visible = _is_visible_this_frame()
		_draw_effects()
		if stage and stage.debug_draw:
			_draw_debug(Rect2(Vector2(-body_size.x / 2.0, -body_size.y - height), body_size))
		return
	if not _is_visible_this_frame():
		return
	var color := body_color
	if flash > 0 and flash % 4 < 2:
		color = Color.WHITE
	var lift := Vector2(0.0, -height)
	if _is_lying():
		var half_len := body_size.y / 2.0
		var thick := body_size.x / 2.0
		draw_rect(Rect2(Vector2(-half_len, -thick) + lift, Vector2(body_size.y, thick)), color)
		draw_rect(Rect2(Vector2(-facing * half_len - 6.0, -thick) + lift, Vector2(12.0, thick)), color.darkened(0.3))
		return
	var lean := -facing * 3.0 if state == State.HURT else 0.0
	var body := Rect2(Vector2(-body_size.x / 2.0 + lean, -body_size.y) + lift, body_size)
	draw_rect(body, color)
	# Cabeça mais escura e um "olho" para mostrar para onde o lutador olha.
	draw_rect(Rect2(body.position, Vector2(body_size.x, 12.0)), color.darkened(0.3))
	draw_rect(Rect2(body.position + Vector2(body_size.x / 2.0 + facing * (body_size.x / 4.0) - 1.5, 4.0), Vector2(3.0, 3.0)), Color.WHITE)
	_draw_arm(body)
	_draw_details(body)
	_draw_effects()
	if stage and stage.debug_draw:
		_draw_debug(body)


func _is_lying() -> bool:
	# No ar (derrubado, lançado ou arremessado) o corpo também fica deitado.
	return state in [State.KNOCKDOWN, State.THROWN, State.DEAD]


func _is_visible_this_frame() -> bool:
	if invuln > 0 and state != State.ATTACK:
		return state_frame % 4 < 2
	return true


func _draw_arm(body: Rect2) -> void:
	var center_x := body.position.x + body_size.x / 2.0
	var y := -height
	match state:
		State.ATTACK:
			var a := current_attack
			if a.get("area", false):
				return
			var startup: int = a.get("startup", 0)
			var active: int = a.get("active", 0)
			var arm_y: float = y - float(a.get("y_hi", 40.0)) + 6.0
			var reach: float = a.get("far", 0.0)
			if state_frame <= startup:
				reach = 4.0
			elif state_frame > startup + active:
				reach *= 0.5
			_draw_reach(center_x, arm_y, reach, 5.0)
		State.GRAB:
			_draw_reach(center_x, y - 30.0, 18.0, 5.0)


func _draw_reach(center_x: float, top: float, reach: float, thickness: float) -> void:
	var start := center_x + facing * (body_size.x / 2.0 - 2.0)
	var end := start + facing * maxf(reach - body_size.x / 2.0 + 2.0, 4.0)
	draw_rect(Rect2(Vector2(minf(start, end), top), Vector2(absf(end - start), thickness)), _limb_color())


func _draw_debug(body: Rect2) -> void:
	draw_rect(body, Color(0.2, 1.0, 0.3, 0.9), false, 1.0)
	draw_line(Vector2(-14, -DEPTH_TOLERANCE), Vector2(14, -DEPTH_TOLERANCE), Color(0.3, 0.7, 1.0, 0.6))
	draw_line(Vector2(-14, DEPTH_TOLERANCE), Vector2(14, DEPTH_TOLERANCE), Color(0.3, 0.7, 1.0, 0.6))
	if state != State.ATTACK and not (state == State.JUMP and not current_attack.is_empty()):
		return
	var a := current_attack
	var lo := -height - float(a.get("y_hi", 40.0))
	var h := float(a.get("y_hi", 40.0)) - float(a.get("y_lo", 16.0))
	var near: float = a.get("near", 0.0)
	var far: float = a.get("far", 0.0)
	var box := Rect2(Vector2(near if facing > 0 else -far, lo), Vector2(far - near, h))
	if a.get("area", false):
		box = Rect2(Vector2(-far, lo), Vector2(far * 2.0, h))
	draw_rect(box, Color(1.0, 0.2, 0.2, 0.9), false, 1.0)

class_name PlayerMovement
extends RefCounted
## Movimentação do herói, separada do combate: aceleração, corrida com duplo
## toque, esquiva (rolamento e passo lateral), pulo com controle no ar e altura
## variável, e o salto por cima de quem está agarrado.
##
## O Player chama estas funções nos pontos certos do quadro; os números ficam
## aqui no topo para ajustar a sensação jogando. Tudo é contado em quadros de
## 60 por segundo, como o resto do combate.

# --- Andar e correr ------------------------------------------------------------

## Quadros para sair do zero até a velocidade de andar (pouco: o controle
## continua firme, só tira o "liga e desliga" seco).
const WALK_ACCEL_FRAMES := 3.0
## Quadros para parar quando solta a direção.
const WALK_DECEL_FRAMES := 4.0
## Corrida: frente, frente e segura. Mais rápida na horizontal, menos na profundidade.
const RUN_MULT := 1.8
const RUN_DEPTH_MULT := 0.7
const RUN_ACCEL_FRAMES := 8.0
## Soltar a corrida derrapa um pouco antes de parar.
const SKID_FRAMES := 9
## A cada tantos quadros de corrida sobe uma poeirinha dos pés.
const RUN_DUST_EVERY := 14

# --- Esquiva --------------------------------------------------------------------

enum Dodge { NONE, ROLL, SIDESTEP }

## Rolamento: botão de esquiva (com ou sem direção). Sem direção, rola para trás.
const ROLL_FRAMES := 22
const ROLL_SPEED := 190.0
## Invencível do 2º ao 13º quadro: dá para atravessar golpes e projéteis.
const ROLL_INVULN_FRAMES := 12
## Passo lateral: esquiva segurando só cima ou baixo. Troca de faixa rápido.
const SIDESTEP_FRAMES := 14
const SIDESTEP_SPEED := 150.0
const SIDESTEP_INVULN_FRAMES := 9
## A partir deste quadro da esquiva, ataque, pulo ou especial já saem (cancelam o fim).
const DODGE_CANCEL_FROM := 14
const SIDESTEP_CANCEL_FROM := 9
## Intervalo mínimo entre duas esquivas (não dá para rolar sem parar).
const DODGE_COOLDOWN_FRAMES := 12
const DODGE_TINT := Color(1.35, 1.35, 1.6)

# --- Pulo ----------------------------------------------------------------------

## Soltar o botão de pulo enquanto sobe corta a subida: toque curto = pulo baixo.
const JUMP_CUT_VZ := 120.0
## Gravidade extra na descida: o pulo sobe macio e desce firme.
const FALL_EXTRA_GRAVITY := 260.0
## Controle no ar: segurar uma direção corrige o pulo (sem direção mantém o embalo).
const AIR_ACCEL := 420.0
const AIR_DEPTH_ACCEL := 220.0
## No ar a profundidade anda metade do chão.
const AIR_DEPTH_MULT := 0.5
## Pulo da corrida: um pouco mais baixo e bem mais longo.
const RUN_JUMP_LIFT := 235.0
const LANDING_DUST_SPEED := 120.0

# --- Agarrão -------------------------------------------------------------------

## Pulo durante o agarrão: o herói salta por cima e fica nas costas do inimigo.
const VAULT_FRAMES := 18
const VAULT_HEIGHT := 26.0

var running := false
var run_dir := 1
var skid := 0
var dodge := Dodge.NONE
var dodge_frame := 0
var dodge_dir := Vector2.ZERO
var cooldown := 0
var vault_frame := 0
var vault_from := 0.0
var vault_to := 0.0

var _last_tap_dir := 0
var _last_tap_frame := -100
var _prev_move_x := 0.0
var _run_frames := 0
var _last_ground_frame := -10
## Pulo saído da corrida: pousando com a direção ainda segura, volta a correr.
var _run_jump_dir := 0


## Chamado todo quadro (inclusive no hit stop): lê os toques duplos.
## O duplo toque arma a investida (frente, frente + ataque) e começa a corrida.
func read_input(p: Player) -> void:
	var x := p.input.move.x
	if x != 0.0 and _prev_move_x == 0.0:
		var dir := int(x)
		if dir == _last_tap_dir and p._frame - _last_tap_frame <= Player.DASH_TAP_FRAMES:
			p._dash_ready = Player.DASH_READY_FRAMES
			p._dash_dir = dir
			if _can_start_run(p):
				_start_run(p, dir)
		_last_tap_dir = dir
		_last_tap_frame = p._frame
	_prev_move_x = x


func tick() -> void:
	cooldown = maxi(cooldown - 1, 0)


func _can_start_run(p: Player) -> bool:
	return p.state in [Fighter.State.IDLE, Fighter.State.WALK] and dodge == Dodge.NONE


func _start_run(p: Player, dir: int) -> void:
	running = true
	run_dir = dir
	_run_frames = 0
	skid = 0
	p.facing = dir
	if p.stage:
		p.stage.fx("dust", p.position - Vector2(dir * 6.0, 0.0), 0.0, dir < 0)


func stop_run() -> void:
	running = false
	_run_frames = 0


## Esquecer tudo que estava em andamento (levou golpe, morreu, trocou de estado).
func reset() -> void:
	stop_run()
	skid = 0
	dodge = Dodge.NONE
	dodge_frame = 0
	vault_frame = 0


func max_speed(p: Player) -> Vector2:
	return p._walk_speed()


## Anda com aceleração. Correndo, a horizontal vai até RUN_MULT x e a
## profundidade fica mais dura de controlar.
func ground_move(p: Player, move: Vector2) -> void:
	var base := max_speed(p)
	if running and int(move.x) != run_dir:
		# Soltou ou virou: acaba a corrida e derrapa.
		stop_run()
		skid = SKID_FRAMES
		if p.stage:
			p.stage.fx("dust", p.position, 0.0, run_dir < 0)
	var target := move * base
	var accel_frames := Vector2(WALK_ACCEL_FRAMES, WALK_ACCEL_FRAMES)
	if running:
		_run_frames += 1
		target.x = run_dir * base.x * RUN_MULT
		target.y = move.y * base.y * RUN_DEPTH_MULT
		accel_frames.x = RUN_ACCEL_FRAMES
		if p.stage and _run_frames % RUN_DUST_EVERY == 0:
			p.stage.fx("dust", p.position - Vector2(run_dir * 8.0, 0.0), 0.0, run_dir < 0)
	elif skid > 0:
		skid -= 1
		# Na derrapagem a direção oposta freia, mas não anda para trás ainda.
		target.x = 0.0
		accel_frames.x = float(SKID_FRAMES)
	var vel := p.velocity
	if p._frame - _last_ground_frame > 1:
		# Voltou agora ao controle (depois de golpe, dano, agarrão): parte do zero.
		vel = Vector2.ZERO
	_last_ground_frame = p._frame
	# Virar é na hora: o embalo para o outro lado não atrasa a volta.
	if target.x != 0.0 and signf(target.x) != signf(vel.x) and skid == 0:
		vel.x = 0.0
	if target.y != 0.0 and signf(target.y) != signf(vel.y):
		vel.y = 0.0
	vel.x = _approach(vel.x, target.x, _step(base.x, accel_frames.x, target.x, vel.x))
	vel.y = _approach(vel.y, target.y, _step(base.y, accel_frames.y, target.y, vel.y))
	p.velocity = vel
	p.position += vel * Fighter.DT
	if move.x != 0.0 and skid == 0:
		p.facing = int(move.x)


## Quanto a velocidade muda por quadro: acelera em `frames`, freia em
## WALK_DECEL_FRAMES (ou devagar, na derrapagem).
func _step(speed: float, frames: float, target: float, current: float) -> float:
	if absf(target) < absf(current):
		return speed * RUN_MULT / float(SKID_FRAMES) if skid > 0 else speed / WALK_DECEL_FRAMES
	return absf(target) / maxf(frames, 1.0)


func _approach(value: float, target: float, amount: float) -> float:
	if value < target:
		return minf(value + amount, target)
	return maxf(value - amount, target)


func is_moving(p: Player) -> bool:
	return p.velocity.length_squared() > 1.0


# --- Esquiva -------------------------------------------------------------------

## Começa a esquiva se o botão foi apertado. Segurando só cima/baixo é o passo
## lateral; com frente/trás (ou diagonal) é o rolamento; sem direção, rola para trás.
func try_dodge(p: Player) -> bool:
	if cooldown > 0 or not p._consume(&"dodge"):
		return false
	var move := p.input.move
	stop_run()
	skid = 0
	dodge_frame = 0
	if move.x == 0.0 and move.y != 0.0:
		dodge = Dodge.SIDESTEP
		dodge_dir = Vector2(0.0, move.y * 0.8)
		p.invuln = maxi(p.invuln, SIDESTEP_INVULN_FRAMES)
	else:
		dodge = Dodge.ROLL
		var x := int(move.x) if move.x != 0.0 else -p.facing
		# Na diagonal o rolamento troca de faixa, mas anda menos na profundidade.
		dodge_dir = Vector2(x, move.y * 0.45)
		# Rolar para trás é recuar de costas; para os lados, vira para onde vai.
		if move.x != 0.0:
			p.facing = x
		p.invuln = maxi(p.invuln, ROLL_INVULN_FRAMES)
	cooldown = DODGE_COOLDOWN_FRAMES + (ROLL_FRAMES if dodge == Dodge.ROLL else SIDESTEP_FRAMES)
	p.velocity = Vector2.ZERO
	p.enter_state(Fighter.State.WALK)
	Sound.play("dodge", -8.0, 0.1)
	if p.stage:
		p.stage.fx("dust", p.position, 0.0, dodge_dir.x < 0.0)
	return true


## Um quadro da esquiva. Devolve true enquanto ela segura o herói; no fim (ou
## quando um ataque/pulo/especial guardado cancela o final) devolve false.
func update_dodge(p: Player) -> bool:
	if dodge == Dodge.NONE:
		return false
	if p.state not in [Fighter.State.IDLE, Fighter.State.WALK]:
		dodge = Dodge.NONE
		return false
	dodge_frame += 1
	var total := ROLL_FRAMES if dodge == Dodge.ROLL else SIDESTEP_FRAMES
	var cancel_from := DODGE_CANCEL_FROM if dodge == Dodge.ROLL else SIDESTEP_CANCEL_FROM
	if dodge_frame >= cancel_from and _has_buffered_action(p):
		_end_dodge(p)
		return false
	# Sai rápido e freia no fim (desacelera no último terço).
	var t := float(dodge_frame) / float(total)
	var speed := (ROLL_SPEED if dodge == Dodge.ROLL else SIDESTEP_SPEED) * clampf((1.0 - t) * 1.5, 0.15, 1.0)
	p.position += dodge_dir * speed * Fighter.DT
	if dodge_frame >= total:
		_end_dodge(p)
	return true


func _end_dodge(p: Player) -> void:
	dodge = Dodge.NONE
	dodge_frame = 0
	p.velocity = Vector2.ZERO


func _has_buffered_action(p: Player) -> bool:
	return p._buffer[&"attack"] > 0 or p._buffer[&"jump"] > 0 or p._buffer[&"special"] > 0


func is_dodging() -> bool:
	return dodge != Dodge.NONE


## Invencível agora por causa da esquiva (o desenho ganha um brilho).
func dodge_invulnerable(p: Player) -> bool:
	if dodge == Dodge.NONE or p.invuln <= 0:
		return false
	var limit := ROLL_INVULN_FRAMES if dodge == Dodge.ROLL else SIDESTEP_INVULN_FRAMES
	return dodge_frame <= limit


# --- Pulo ----------------------------------------------------------------------

## Velocidade de saída do pulo: andando, pula na direção; correndo, pula longe.
func start_jump(p: Player) -> void:
	var move := p.input.move
	var base := max_speed(p)
	var vel := Vector2(move.x * base.x, move.y * base.y * AIR_DEPTH_MULT)
	var lift := Player.JUMP_LIFT
	if running or absf(p.velocity.x) > base.x * 1.1:
		var dir := run_dir if running else int(signf(p.velocity.x))
		vel.x = dir * maxf(absf(p.velocity.x), base.x * RUN_MULT * 0.9)
		lift = RUN_JUMP_LIFT
		_run_jump_dir = dir
	else:
		_run_jump_dir = 0
	stop_run()
	skid = 0
	p.velocity = vel
	p.vz = lift


## Antes do _fly de cada quadro no ar: corrige a direção, corta a subida se o
## botão foi solto e puxa mais forte na descida.
func update_air(p: Player, can_steer: bool) -> void:
	if p.vz > JUMP_CUT_VZ and not p.input.jump_held:
		p.vz = JUMP_CUT_VZ
	if p.vz < 0.0:
		p.vz -= FALL_EXTRA_GRAVITY * Fighter.DT
	if not can_steer:
		return
	var move := p.input.move
	var base := max_speed(p)
	if move.x != 0.0:
		var cap := maxf(absf(p.velocity.x), base.x) if signf(p.velocity.x) == move.x else base.x
		p.velocity.x = _approach(p.velocity.x, move.x * cap, AIR_ACCEL * Fighter.DT)
	if move.y != 0.0:
		p.velocity.y = _approach(p.velocity.y, move.y * base.y * AIR_DEPTH_MULT, AIR_DEPTH_ACCEL * Fighter.DT)


func on_land(p: Player, landing_speed: float) -> void:
	if p.stage and landing_speed > LANDING_DUST_SPEED:
		p.stage.fx("dust", p.position)
		Sound.play("land", -12.0, 0.1)
	if _run_jump_dir != 0 and int(p.input.move.x) == _run_jump_dir:
		running = true
		run_dir = _run_jump_dir
		p.velocity = Vector2(run_dir * max_speed(p).x * RUN_MULT, 0.0)
		_last_ground_frame = p._frame
	_run_jump_dir = 0


# --- Salto por cima do agarrado -------------------------------------------------

func start_vault(p: Player) -> void:
	vault_frame = 1
	vault_from = p.position.x
	vault_to = p.position.x + p.facing * Player.GRAB_HOLD_DISTANCE * 2.0
	Sound.play("jump", -8.0)


func is_vaulting() -> bool:
	return vault_frame > 0


## Um quadro do salto. Devolve true no quadro em que o herói pousa do outro lado.
func update_vault(p: Player) -> bool:
	var t := float(vault_frame) / float(VAULT_FRAMES)
	p.position.x = lerpf(vault_from, vault_to, t)
	p.height = VAULT_HEIGHT * 4.0 * t * (1.0 - t)
	vault_frame += 1
	if vault_frame > VAULT_FRAMES:
		vault_frame = 0
		p.height = 0.0
		return true
	return false

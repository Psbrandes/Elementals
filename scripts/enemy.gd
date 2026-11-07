class_name Enemy
extends Fighter
## Inimigo comum. O arquétipo (EnemyData.behavior) decide como ele cerca e ataca:
##   BRAWLER  Capanga: chega perto e soca, em grupo.
##   RUNNER   Faca: espera o jogador se ocupar com outro, ataca rápido e recua.
##   TANK     Brutamontes: alinha na profundidade e investe com os ombros.
##   SHOOTER  Fundeiro: fica longe, atira pedras e foge se o jogador chega perto.
##   GUARD    Escudeiro: segura golpes de frente com o escudo e revida; cai com
##            golpe que derruba, pulo, agarrão, pelas costas ou com a fraqueza.
##   BOMBER   Piromante: fica a meia distância e joga bombas em arco no ponto
##            onde o jogador está (círculo no chão). A bomba acerta inimigos também.
##
## Elementos: golpe de herói com elemento em `weak_to` tira 1,5x e, se derruba,
## quebra a armadura; em `resists` tira 0,75x. Aparece "FRACO!" ou "RESISTE".
## IA de cerco do GDD: cada um escolhe um lado do jogador; só quem tem uma das
## vagas de ataque da Stage (no máximo 2) parte para o golpe de perto.

const ENGAGE_DISTANCE := 24.0
const HOLD_DISTANCE_MIN := 56.0
const HOLD_DISTANCE_MAX := 84.0
const HOLD_DEPTH := 18.0
const ALIGN_DEPTH := 4.0
const SEPARATION_RADIUS := 14.0
const AFTER_HURT_COOLDOWN := 30
const DEATH_FRAMES := 45
const RETREAT_FRAMES := 50
const RETREAT_DISTANCE := 110.0
const RETREAT_SPEED := 1.5
const CHARGE_LINE_DISTANCE := 100.0
const CHARGE_MIN_DISTANCE := 40.0
const CHARGE_MAX_DISTANCE := 170.0
## Quem espera demais sem atacar perde a paciência e parte para cima.
const PATIENCE_FRAMES := 240
const CORNERED_DISTANCE := 40.0
## Ritmo da arte, em quadros de jogo por quadro de animação.
const IDLE_TICKS := 7
const RUN_TICKS := 5
const DASH_TICKS := 3
const FALL_FRAMES := 14
const WEAK_MULTIPLIER := 1.5
const RESIST_MULTIPLIER := 0.75
const WEAK_COLOR := Color("ffcc33")
const RESIST_COLOR := Color("9aa4b0")
## Esquiva: sai da faixa durante estes quadros, mais rápido que o andar.
const DODGE_FRAMES := 16
const DODGE_SPEED := 2.6
const DODGE_DEPTH := 22.0
const DODGE_COOLDOWN := 90
## Começo da esquiva sem poder ser atingido (o passo sai junto com o golpe).
const DODGE_INVULN := 8
## Golpe emendado do combo inimigo: antecipação mais curta que o primeiro.
const CHAIN_STARTUP := 7
## Bloqueio do escudo: quadros mostrando a defesa e o empurrão.
const BLOCK_FRAMES := 14
const BLOCK_PUSH := 4.0
const BOMB_MIN_DISTANCE := 60.0
const BOMB_MAX_DISTANCE := 190.0
## Último inimigo da trava: mais rápido e sem esperar vaga.
const RAGE_SPEED := 1.3

@export var data: EnemyData
@export var ai_enabled := true

## Lado do jogador em que o inimigo quer ficar: -1 esquerda, 1 direita.
var side := 1
## Herói que este inimigo persegue (no co-op, o mais perto, revisto de tempos em tempos).
var target: Player

var _hold := Vector2(70.0, 0.0)
var _cooldown := 60
var _has_slot := false
var _rethink := 0
var _entered := false
var _retreat := 0
var _waiting := 0
var _melee := {}
var _charge := {}
var _shot := {}
var _art_frame := 0
var _dodge := 0
var _dodge_dir := 0.0
var _dodge_cooldown := 0
var _seen_player_attack := false
var _chain_left := 0
var _landed := false
var _blocks := 0
var _block_frames := 0
var _bash := {}
var _bomb := {}
var enraged := false
## Quadro da animação de morte usado como "caído".
var _down := 0


func _ready() -> void:
	if data:
		max_hp = Difficulty.enemy_hp(data.max_hp)
		body_color = data.body_color
		body_size = data.body_size
		armor_hits = data.armor_hits
		heavy_body = not data.grabbable
		_melee = {
			"name": "soco", "startup": data.attack_startup, "active": data.attack_active,
			"recovery": data.attack_recovery, "damage": data.attack_damage,
			"near": 0.0, "far": data.attack_reach, "telegraph": true, "knockdown": data.attack_knockdown,
		}
		_charge = {
			"name": "investida", "startup": data.charge_startup, "active": data.charge_frames,
			"recovery": data.charge_recovery, "damage": data.charge_damage, "knockdown": true,
			"near": 0.0, "far": 16.0, "move_speed": data.charge_speed, "telegraph": true,
			"y_hi": body_size.y - 12.0,
		}
		_shot = {"name": "pedra", "startup": 16, "active": 1, "recovery": 20, "damage": 0,
			"near": 0.0, "far": 0.0, "telegraph": true, "projectile": true}
		_bash = {"name": "escudada", "startup": 6, "active": 4, "recovery": 18, "damage": data.bash_damage,
			"knockdown": true, "near": 0.0, "far": data.attack_reach + 4.0, "telegraph": true, "move_speed": 60.0}
		_bomb = {"name": "bomba", "startup": 22, "active": 1, "recovery": 24, "damage": 0,
			"near": 999.0, "far": -999.0, "telegraph": true, "bomb": true}
	super()
	_cooldown = randi_range(30, 90)
	if data and data.sprite_id != "":
		sprite = CharacterSprite.new()
		add_child(sprite)
		sprite.setup(data.sprite_id, data.sprite_scale)
		sprite.modulate = data.sprite_tint
		_down = sprite.frames_of("death") - 1
		_update_sprite()


func _physics_process(delta: float) -> void:
	var frozen := hitstop > 0
	super(delta)
	if not frozen:
		_art_frame += 1
		_block_frames = maxi(_block_frames - 1, 0)
	_update_sprite()


func has_attack_slot() -> bool:
	return _has_slot


func can_be_grabbed() -> bool:
	return data.grabbable and super()


## Alvo da IA. Com um jogador só é sempre ele; fica num lugar só para o
## multiplayer trocar pelo jogador mais perto.
## Alvo atual (co-op: escolhido por _pick_target entre os heróis que podem apanhar).
func _target() -> Player:
	if stage and (not is_instance_valid(target) or not target.is_targetable()):
		target = _pick_target()
	return target


## Último da trava: acelera e ataca sem esperar vaga (ver Stage._update_last_enemy).
func enrage() -> void:
	if enraged:
		return
	enraged = true
	_waiting = PATIENCE_FRAMES + 1
	_cooldown = mini(_cooldown, 20)


func take_hit(damage: int, knockdown: bool, from: Node2D, launch := 0.0) -> bool:
	if not can_be_hit():
		return false
	var element := _attacker_element(from)
	var weak := element != "" and data != null and data.weak_to.has(element)
	var resist := element != "" and data != null and data.resists.has(element)
	if not weak and _blocks_hit(from, knockdown):
		_block(from)
		return false
	if weak:
		damage = ceili(damage * WEAK_MULTIPLIER)
		if knockdown:
			# Fraqueza com golpe que derruba quebra a armadura na hora.
			_armor_left = 0
		if stage:
			stage.popup("FRACO!", position, body_size.y + 6.0 + height, WEAK_COLOR)
	elif resist:
		damage = maxi(int(damage * RESIST_MULTIPLIER), 1)
		if stage:
			stage.popup("RESISTE", position, body_size.y + 6.0 + height, RESIST_COLOR)
	return super(damage, knockdown, from, launch)


func _attacker_element(from: Node2D) -> String:
	if from is Player:
		return String((from as Player).character.get("element", ""))
	return ""


## Escudo: segura golpe de frente que não derruba, de quem está no chão,
## enquanto o Escudeiro anda, espera ou já está bloqueando.
func _blocks_hit(from: Node2D, knockdown: bool) -> bool:
	if data == null or data.behavior != EnemyData.Behavior.GUARD or knockdown:
		return false
	if not state in [State.IDLE, State.WALK] or height > 0.0:
		return false
	if not from is Fighter or (from as Fighter).height > 4.0:
		return false
	var toward := 1 if from.position.x >= position.x else -1
	return toward == facing


func _block(from: Node2D) -> void:
	_blocks += 1
	_block_frames = BLOCK_FRAMES
	position.x -= facing * BLOCK_PUSH
	if from is Fighter:
		(from as Fighter).hitstop = maxi((from as Fighter).hitstop, HITSTOP_FRAMES)
	hitstop = HITSTOP_FRAMES
	Sound.play("block", -6.0)
	if stage:
		stage.fx("hit", position + Vector2(facing * body_size.x * 0.5, 0.0), body_size.y * 0.55, facing < 0)
		stage.popup("BLOQUEIO", position, body_size.y + 6.0, RESIST_COLOR)
	if _blocks >= data.guard_hits:
		# Segurou golpes demais: revida com o escudo na hora.
		_blocks = 0
		start_attack(_bash)


func is_blocking() -> bool:
	return _block_frames > 0


func _update_control() -> void:
	if stage and (not is_instance_valid(target) or not target.is_targetable() or _rethink <= 1):
		target = _pick_target()
	var player: Player = target
	if not ai_enabled or player == null or not player.is_targetable():
		_drop_slot()
		if state != State.IDLE:
			enter_state(State.IDLE)
		return
	_cooldown = maxi(_cooldown - 1, 0)
	_retreat = maxi(_retreat - 1, 0)
	_dodge_cooldown = maxi(_dodge_cooldown - 1, 0)
	if _dodge > 0:
		_dodge -= 1
		var away := signf(position.x - player.position.x)
		_walk_to(position + Vector2(away * 10.0, _dodge_dir * DODGE_DEPTH), player, DODGE_SPEED)
		return
	if _try_dodge(player):
		return
	_waiting = 0 if _has_slot else _waiting + 1
	_rethink -= 1
	if _rethink <= 0:
		_rethink = randi_range(60, 120)
		side = stage.pick_side(self)
		_hold = Vector2(randf_range(HOLD_DISTANCE_MIN, HOLD_DISTANCE_MAX), randf_range(-HOLD_DEPTH, HOLD_DEPTH))
	_think(player)


## Co-op: o herói mais perto, com desconto para quem já está cercado por outros
## inimigos (assim o grupo se divide entre os jogadores).
func _pick_target() -> Player:
	var best: Player = null
	var best_cost := INF
	for p: Player in stage.targetable_players():
		var cost := absf(p.position.x - position.x) + absf(p.position.y - position.y) * 2.0
		for other: Enemy in stage.enemies():
			if other != self and other.target == p:
				cost += 40.0
		if cost < best_cost:
			best = p
			best_cost = cost
	return best


func _think(player: Player) -> void:
	match data.behavior:
		EnemyData.Behavior.SHOOTER:
			_think_shooter(player)
		EnemyData.Behavior.TANK:
			_think_tank(player)
		EnemyData.Behavior.BOMBER:
			_think_bomber(player)
		_:
			_think_melee(player)


func _think_melee(player: Player) -> void:
	var wants_slot := _cooldown == 0 and _retreat == 0
	if data.behavior == EnemyData.Behavior.RUNNER and not enraged:
		var cornered := absf(player.position.x - position.x) < CORNERED_DISTANCE
		wants_slot = wants_slot and (_player_busy(player) or cornered or _waiting > PATIENCE_FRAMES)
	if not _has_slot and wants_slot:
		_has_slot = stage.request_attack_slot(self)
	if _retreat > 0:
		_walk_to(player.position + Vector2(side * RETREAT_DISTANCE, _hold.y), player, RETREAT_SPEED)
	elif _has_slot or enraged:
		_walk_to(_engage_goal(player, ENGAGE_DISTANCE), player, RAGE_SPEED if enraged else 1.0)
	else:
		_walk_to(_hold_goal(player), player)
	if (_has_slot or enraged) and _cooldown == 0 and _can_reach(player, data.attack_reach + 4.0):
		_chain_left = data.combo_hits - 1
		start_attack(_melee)


func _think_tank(player: Player) -> void:
	if not _has_slot and _cooldown == 0:
		_has_slot = stage.request_attack_slot(self)
	if _has_slot:
		_walk_to(_engage_goal(player, CHARGE_LINE_DISTANCE), player)
	else:
		_walk_to(_hold_goal(player), player)
	if not _has_slot or _cooldown > 0 or player.height >= 24.0:
		return
	var dx := absf(player.position.x - position.x)
	if _can_reach(player, data.attack_reach + 4.0):
		start_attack(_melee)
	elif absf(player.position.y - position.y) <= ALIGN_DEPTH and dx >= CHARGE_MIN_DISTANCE and dx <= CHARGE_MAX_DISTANCE:
		start_attack(_charge)


## Piromante: meia distância, em qualquer faixa (a bomba cai em arco, então não
## precisa alinhar). Joga no ponto onde o jogador está na hora do arremesso.
func _think_bomber(player: Player) -> void:
	_avoid_wall(player, data.keep_distance)
	var goal := Vector2(player.position.x + side * data.keep_distance, player.position.y + _hold.y)
	var dx := absf(player.position.x - position.x)
	if dx < data.flee_distance:
		goal.x = player.position.x + side * (data.keep_distance + 30.0)
	_walk_to(goal, player)
	if _cooldown == 0 and dx >= BOMB_MIN_DISTANCE and dx <= BOMB_MAX_DISTANCE:
		start_attack(_bomb)


## Quem luta de longe não fica preso na parede: se o posto cai fora da tela,
## troca de lado do jogador.
func _avoid_wall(player: Player, distance: float) -> void:
	var r := stage.floor_rect
	var x := player.position.x + side * distance
	if x < r.position.x or x > r.end.x:
		var other := player.position.x - side * distance
		if other >= r.position.x and other <= r.end.x:
			side = -side


## Esquiva: quando o jogador começa um golpe virado para mim, na minha faixa e
## perto, às vezes saio da linha (uma chance por golpe do jogador).
func _try_dodge(player: Player) -> bool:
	if data.dodge_chance <= 0.0:
		return false
	var attacking := player.state == State.ATTACK
	if not attacking:
		_seen_player_attack = false
		return false
	if _seen_player_attack or _dodge_cooldown > 0:
		return false
	_seen_player_attack = true
	var dx := position.x - player.position.x
	var aimed := signf(dx) == float(player.facing) and absf(dx) < 56.0 \
		and absf(position.y - player.position.y) <= DEPTH_TOLERANCE + 2.0
	if not aimed or randf() >= data.dodge_chance:
		return false
	_dodge = DODGE_FRAMES
	_dodge_cooldown = DODGE_COOLDOWN
	invuln = DODGE_INVULN
	var r := stage.floor_rect
	_dodge_dir = -1.0 if position.y > r.get_center().y else 1.0
	_drop_slot()
	return true


func _think_shooter(player: Player) -> void:
	# Fica a uma distância segura, na mesma faixa do jogador para mirar.
	_avoid_wall(player, data.keep_distance)
	_walk_to(Vector2(player.position.x + side * data.keep_distance, player.position.y), player)
	var dx := absf(player.position.x - position.x)
	if _cooldown == 0 and dx > data.flee_distance and absf(player.position.y - position.y) <= ALIGN_DEPTH * 2.0:
		start_attack(_shot)


## O jogador está ocupado: batendo, agarrando, apanhando ou de costas para mim.
func _player_busy(player: Player) -> bool:
	if player.state in [State.ATTACK, State.GRAB, State.HURT]:
		return true
	var my_side := 1 if position.x >= player.position.x else -1
	return player.facing != my_side


func _can_reach(player: Player, reach: float) -> bool:
	return player.height < 24.0 \
		and absf(player.position.y - position.y) <= ALIGN_DEPTH \
		and absf(player.position.x - position.x) <= reach


## Posto de espera ao redor do jogador. Quem espera não foge quando o jogador
## chega perto: só ajusta a profundidade (senão o jogador nunca alcança ninguém).
func _hold_goal(player: Player) -> Vector2:
	var goal := player.position + Vector2(side * _hold.x, _hold.y)
	var dx := position.x - player.position.x
	if signf(dx) == side and absf(dx) < _hold.x:
		goal.x = position.x
	return goal


func _engage_goal(player: Player, distance: float) -> Vector2:
	var r := stage.floor_rect
	var goal := player.position + Vector2(side * distance, 0.0)
	# Encostado na parede: ataca pelo outro lado.
	if goal.x < r.position.x or goal.x > r.end.x:
		side = -side
		goal = player.position + Vector2(side * distance, 0.0)
	return goal


func _walk_to(goal: Vector2, player: Player, speed_scale := 1.0) -> void:
	var step := _step_towards(stage.clamp_to_floor(goal), speed_scale) + _separation()
	position += step
	facing = 1 if player.position.x >= position.x else -1
	var moving := step.length() > 0.05
	if moving != (state == State.WALK):
		enter_state(State.WALK if moving else State.IDLE)


func _step_towards(goal: Vector2, speed_scale := 1.0) -> Vector2:
	var d := goal - position
	var speed := data.walk_speed * speed_scale * DT
	if absf(d.x) < 1.0:
		d.x = 0.0
	if absf(d.y) < 1.0:
		d.y = 0.0
	return Vector2(clampf(d.x, -speed.x, speed.x), clampf(d.y, -speed.y, speed.y))


## Empurrãozinho para os inimigos não ficarem um dentro do outro.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other: Fighter in stage.enemies():
		if other == self:
			continue
		var d := position - other.position
		if absf(d.x) < SEPARATION_RADIUS and absf(d.y) < 6.0:
			push.x += 0.5 if d.x >= 0.0 else -0.5
			push.y += 0.3 if d.y >= 0.0 else -0.3
	return push


func _update_attack() -> void:
	if state_frame == int(current_attack.get("startup", 0)) + 1:
		if current_attack.get("projectile", false):
			Sound.play("arrow", -4.0)
		elif not current_attack.get("shockwave", false):
			Sound.play("slash", -7.0, 0.1)
	if current_attack.get("projectile", false) and state_frame == int(current_attack["startup"]) + 1:
		var shot := stage.spawn_projectile(self, Vector2(position.x + facing * 12.0, position.y), facing,
			data.shot_damage, data.shot_speed, false)
		shot.art = data.shot_art
	if current_attack.get("bomb", false) and state_frame == int(current_attack["startup"]) + 1:
		var player := _target()
		if player:
			stage.spawn_lob(self, position + Vector2(facing * 8.0, 0.0), player.position,
				data.bomb_damage, data.bomb_radius, data.bomb_flight, "bomba")
			Sound.play("whiff", -4.0)
	super()


func _on_attack_landed(_target_hit: Fighter) -> void:
	_landed = true


func start_attack(attack: Dictionary) -> void:
	_landed = false
	# Bipe curto junto com o "!" do aviso: dá para ouvir o golpe vindo de fora da tela.
	if attack.get("telegraph", false):
		Sound.play("alert", -15.0, 0.05)
	super(attack)


func _on_attack_finished() -> void:
	# Combo inimigo: se o soco acertou, emenda o próximo com antecipação curta.
	if _chain_left > 0 and _landed and current_attack.get("name") == "soco":
		_chain_left -= 1
		var follow := _melee.duplicate()
		follow["startup"] = CHAIN_STARTUP
		start_attack(follow)
		return
	_chain_left = 0
	match data.behavior:
		EnemyData.Behavior.SHOOTER, EnemyData.Behavior.BOMBER:
			_cooldown = data.shot_interval
		EnemyData.Behavior.RUNNER:
			_cooldown = Difficulty.cooldown(randi_range(data.attack_cooldown_min, data.attack_cooldown_max))
			_retreat = RETREAT_FRAMES
		_:
			_cooldown = Difficulty.cooldown(randi_range(data.attack_cooldown_min, data.attack_cooldown_max))
	if enraged:
		_cooldown /= 2
	_drop_slot()
	enter_state(State.IDLE)


func _on_damaged(_damage: int, _heavy: bool) -> void:
	_drop_slot()
	_chain_left = 0
	_dodge = 0
	_cooldown = maxi(_cooldown, AFTER_HURT_COOLDOWN)


func _on_grabbed() -> void:
	_drop_slot()


func _drop_slot() -> void:
	if _has_slot and stage:
		stage.release_attack_slot(self)
	_has_slot = false


func _die() -> void:
	_drop_slot()
	super()


func _update_dead() -> void:
	if state_frame >= DEATH_FRAMES:
		queue_free()


func _opponents() -> Array:
	return stage.targetable_players() if stage else []


func _allies() -> Array:
	return stage.enemies() if stage else []


## Entra pela lateral de fora da tela; só passa a respeitar as bordas depois de entrar.
func _clamps_x() -> bool:
	if not _entered and stage:
		var r := stage.floor_rect
		_entered = position.x >= r.position.x and position.x <= r.end.x
	return _entered


func _is_visible_this_frame() -> bool:
	if _dodge > 0:
		return true
	if state == State.DEAD:
		return state_frame % 4 < 2
	return super()


# --- Arte ------------------------------------------------------------------------

## Escolhe animação e quadro pelo estado, como o jogador (o hit stop congela tudo).
func _update_sprite() -> void:
	if sprite == null:
		return
	if _block_frames > 0 and state in [State.IDLE, State.WALK]:
		sprite.show_frame("defend", 0)
		sprite.set_pose(facing, height, flash > 0 and flash % 4 < 2)
		return
	match state:
		State.IDLE:
			_show_loop("idle", IDLE_TICKS)
		State.WALK:
			_show_loop("run", RUN_TICKS)
		State.ATTACK:
			var anim := _attack_anim()
			if anim == "dash":
				# Investida: firma o escudo na antecipação e corre no ativo.
				if state_frame <= int(current_attack.get("startup", 0)):
					sprite.show_frame("defend", 0)
				else:
					_show_loop("dash", DASH_TICKS)
			else:
				_show_attack(anim)
		State.HURT, State.GRABBED:
			_show_once("take_hit", state_frame, HITSTUN_FRAMES)
		State.KNOCKDOWN, State.THROWN:
			sprite.show_frame("death", mini(state_frame * _down / FALL_FRAMES, _down) if _airborne else _down)
		State.GETUP:
			sprite.show_frame("death", _down - state_frame * _down / GETUP_FRAMES)
		State.DEAD:
			_show_once("death", state_frame, DEATH_FRAMES * 2 / 3)
		_:
			_show_loop("idle", IDLE_TICKS)
	sprite.set_pose(facing, height, flash > 0 and flash % 4 < 2)


func _attack_anim() -> String:
	match current_attack.get("name", ""):
		"investida":
			return "dash"
		"pedra":
			return "shot"
		"soco_de_pedra":
			return "atk1"
		"pisada", "bomba", "salto":
			return "sp_atk"
		"escudada":
			return "atk3"
		"arremesso_de_pedra":
			return "atk1"
	return data.attack_anim


func _show_loop(anim: String, ticks: int) -> void:
	sprite.show_frame(anim, _art_frame / ticks % sprite.frames_of(anim))


func _show_once(anim: String, elapsed: int, duration: int) -> void:
	var count := sprite.frames_of(anim)
	sprite.show_frame(anim, mini(elapsed * count / maxi(duration, 1), count - 1))


## O quadro de maior alcance da arte cai no primeiro quadro ativo do golpe.
func _show_attack(anim: String) -> void:
	sprite.show_frame(anim, sprite.attack_frame(anim, state_frame, int(current_attack.get("startup", 0)),
		int(current_attack.get("active", 0)), int(current_attack.get("recovery", 0))))


func _draw_details(body: Rect2) -> void:
	# Aviso do golpe: "!" amarelo durante a antecipação, para o jogador ler o golpe.
	if state == State.ATTACK and current_attack.get("telegraph", false) \
			and state_frame <= int(current_attack.get("startup", 0)):
		var x := body.position.x + body_size.x / 2.0 - 1.5
		draw_rect(Rect2(Vector2(x, body.position.y - 12.0), Vector2(3.0, 6.0)), Color("ffcc33"))
		draw_rect(Rect2(Vector2(x, body.position.y - 5.0), Vector2(3.0, 2.0)), Color("ffcc33"))
	if state == State.ATTACK and current_attack.get("name") == "investida" \
			and state_frame > int(current_attack.get("startup", 0)):
		for i in 3:
			var trail_x := body.position.x + body_size.x / 2.0 - facing * (body_size.x / 2.0 + 6.0 + i * 7.0) - 2.0
			draw_rect(Rect2(Vector2(trail_x, body.position.y + 20.0 + i * 12.0), Vector2(4.0, 4.0)), Color(0.9, 0.9, 0.8, 0.6 - i * 0.15))

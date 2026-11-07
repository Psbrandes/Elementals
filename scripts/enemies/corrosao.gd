class_name Corrosao
extends Boss
## Corrosão, a Lâmina Enferrujada: chefe da fase 2 (Cemitério de Ferro). Uma
## guerreira do Metal tomada pela ferrugem. Usa a mesma barra, a mesma marca de
## fase no HUD e as mesmas regras de fase do Ferrugem (Boss), com golpes próprios:
##
##   Fase 1  armadura (2 golpes): corte duplo (o 2º derruba), lâmina giratória
##           (bumerangue na faixa dela: mude de faixa ou pule, e cuidado na volta)
##           e postura de guarda: segura golpes de frente que não derrubam e, no
##           2º bloqueio, revida com um contragolpe. Quebra a guarda: golpe que
##           derruba, pelas costas, pulando ou com a fraqueza (Fogo, Terra).
##   Fase 2  (50%) a armadura cai, ela acelera e ganha a investida cortante: mira a
##           faixa do herói, marca no chão onde vai parar e atravessa a tela.
##   Fase 3  (25%, "FÚRIA!") chama duas Sombras e ganha a chuva de lâminas: três
##           lâminas em arco que cravam no chão onde o herói está e dos lados. O
##           corte duplo emenda na chuva.
## Todo golpe tem "!" (menos a guarda, que não machuca).

const SPEEDS := [1.0, 1.35, 1.6]
const MELEE_REACH := 46.0
const GUARD_CHANCE := 0.35
const GUARD_COOLDOWN := 240
## Bloqueios na guarda antes do contragolpe.
const GUARD_HITS := 2
const BLADE_MIN_DISTANCE := 80.0
const BLADE_DAMAGE := 10
const BLADE_SPEED := 190.0
const DASH_MIN_DISTANCE := 70.0
const DASH_SPEED := 250.0
## A investida mira a faixa do herói até este tanto antes do fim do preparo.
const DASH_AIM_STOP := 8
const RAIN_MIN_DISTANCE := 50.0
const RAIN_DAMAGE := 14
const RAIN_RADIUS := 18.0
const RAIN_SPREAD := 42.0
## Quem a fúria chama (carregado na hora: um preload aqui daria referência circular com a Stage).
const SUMMON := "res://data/enemies/sombra.tres"
const SUMMON_FURY := 2

const CORTE := {"name": "corte", "startup": 18, "active": 4, "recovery": 8, "damage": 12,
	"near": 0.0, "far": MELEE_REACH, "y_lo": 10.0, "y_hi": 60.0, "telegraph": true}
const CORTE_FINAL := {"name": "corte_final", "startup": 11, "active": 4, "recovery": 26, "damage": 14,
	"knockdown": true, "near": 0.0, "far": MELEE_REACH + 4.0, "y_lo": 10.0, "y_hi": 60.0, "telegraph": true,
	"move_speed": 50.0}
const LANCAR := {"name": "lancar_lamina", "startup": 22, "active": 1, "recovery": 22, "damage": 0,
	"near": 999.0, "far": -999.0, "telegraph": true}
const GUARDA := {"name": "guarda", "startup": 4, "active": 80, "recovery": 8, "damage": 0,
	"near": 999.0, "far": -999.0, "telegraph": false}
const CONTRAGOLPE := {"name": "contragolpe", "startup": 7, "active": 5, "recovery": 24, "damage": 16,
	"knockdown": true, "near": 0.0, "far": MELEE_REACH + 6.0, "y_lo": 10.0, "y_hi": 60.0, "telegraph": true,
	"move_speed": 90.0}
const INVESTIDA := {"name": "investida_cortante", "startup": 26, "active": 34, "recovery": 30, "damage": 16,
	"knockdown": true, "near": -12.0, "far": 26.0, "y_lo": 4.0, "y_hi": 60.0, "move_speed": DASH_SPEED,
	"telegraph": true}
const CHUVA := {"name": "chuva_de_laminas", "startup": 26, "active": 1, "recovery": 30, "damage": 0,
	"near": 999.0, "far": -999.0, "telegraph": true}
## Chuva emendada no corte duplo, na fúria: antecipação mais curta.
const CHUVA_RAPIDA := {"name": "chuva_de_laminas", "startup": 14, "active": 1, "recovery": 28, "damage": 0,
	"near": 999.0, "far": -999.0, "telegraph": true}

var _guard_cooldown := 120
var _guard_blocks := 0
var _blade: LaminaGiratoria


func _think(player: Player) -> void:
	_guard_cooldown = maxi(_guard_cooldown - 1, 0)
	_walk_to(_engage_goal(player, MELEE_REACH - 8.0), player, SPEEDS[phase - 1])
	if _cooldown > 0 or player.height >= 24.0:
		return
	var dx := absf(player.position.x - position.x)
	var dy := absf(player.position.y - position.y)
	if dy <= ALIGN_DEPTH and dx <= MELEE_REACH + 4.0:
		if phase == 1 and _guard_cooldown == 0 and randf() < GUARD_CHANCE:
			_guard_cooldown = GUARD_COOLDOWN
			_guard_blocks = 0
			start_attack(GUARDA)
		else:
			start_attack(CORTE)
		return
	var options := []
	if dy <= ALIGN_DEPTH * 2.0 and dx >= BLADE_MIN_DISTANCE and not is_instance_valid(_blade):
		options.append(LANCAR)
	if phase >= 2 and dx >= DASH_MIN_DISTANCE:
		options.append(INVESTIDA)
		options.append(INVESTIDA)
	if phase >= 3 and dx >= RAIN_MIN_DISTANCE:
		options.append(CHUVA)
		options.append(CHUVA)
	if not options.is_empty():
		start_attack(options.pick_random())


func _update_attack() -> void:
	var startup := int(current_attack.get("startup", 0))
	match current_attack.get("name", ""):
		"lancar_lamina":
			if state_frame == startup + 1:
				_throw_blade()
		"investida_cortante":
			_update_dash(startup)
		"chuva_de_laminas":
			if state_frame == startup + 1:
				_blade_rain()
	# Enemy._update_attack (sons e projéteis comuns), sem o abalo do Ferrugem.
	_update_enemy_attack()


func _update_enemy_attack() -> void:
	if state_frame == int(current_attack.get("startup", 0)) + 1 and current_attack.get("far", 0.0) > 0.0:
		Sound.play("slash", -5.0, 0.1)
	var a := current_attack
	var startup: int = a.get("startup", 0)
	var active: int = a.get("active", 0)
	if state_frame > startup and state_frame <= startup + active:
		position.x += facing * float(a.get("move_speed", 0.0)) * DT
		_check_attack_hits()
	if state_frame >= startup + active + int(a.get("recovery", 0)):
		_on_attack_finished()


func _throw_blade() -> void:
	var blade := LaminaGiratoria.new()
	blade.art = LaminaGiratoria.ART
	blade.stage = stage
	blade.thrower = self
	blade.position = position + Vector2(facing * 18.0, 0.0)
	blade.direction = facing
	blade.damage = BLADE_DAMAGE
	blade.speed = BLADE_SPEED
	stage.actors.add_child(blade)
	_blade = blade
	Sound.play("whiff", -2.0)


## Investida: no preparo mira a faixa do herói e marca onde vai parar; no ativo
## atravessa reto (o Fighter move com move_speed e confere os acertos).
func _update_dash(startup: int) -> void:
	var player := _target()
	if state_frame <= startup - DASH_AIM_STOP and player:
		position.y = move_toward(position.y, player.position.y, 1.2)
		facing = 1 if player.position.x >= position.x else -1
	if state_frame <= startup:
		var travel := DASH_SPEED * int(current_attack["active"]) * DT
		_leap_to = stage.clamp_to_floor(position + Vector2(facing * travel, 0.0))
	if state_frame == startup + 1:
		Sound.play("dodge", -2.0, 0.0)
		stage.fx("dust", position)


func _blade_rain() -> void:
	var player := _target()
	if player == null:
		return
	var center := player.position
	var spots := [center, center + Vector2(-RAIN_SPREAD, randf_range(-14.0, 14.0)),
		center + Vector2(RAIN_SPREAD, randf_range(-14.0, 14.0))]
	for i in spots.size():
		stage.spawn_lob(self, position + Vector2(facing * 10.0, 0.0), spots[i], RAIN_DAMAGE, RAIN_RADIUS,
			40 + i * 8, "lamina")
	Sound.play("whiff", -2.0)


func ground_marker() -> Dictionary:
	if state != State.ATTACK or current_attack.get("name") != "investida_cortante":
		return {}
	var startup := int(current_attack["startup"])
	if state_frame > startup:
		return {}
	return {"at": _leap_to, "radius": 20.0, "progress": float(state_frame) / startup}


# --- Guarda --------------------------------------------------------------------------

func _guarding() -> bool:
	return state == State.ATTACK and current_attack.get("name") == "guarda" \
		and state_frame <= int(current_attack["startup"]) + int(current_attack["active"])


func take_hit(damage: int, knockdown: bool, from: Node2D, launch := 0.0) -> bool:
	if _guarding() and can_be_hit() and _guard_holds(from, knockdown):
		_guard_block(from)
		return false
	return super(damage, knockdown, from, launch)


## A guarda segura golpe de frente, que não derruba, de quem está no chão, sem a fraqueza.
func _guard_holds(from: Node2D, knockdown: bool) -> bool:
	if knockdown:
		return false
	var element := _attacker_element(from if not from is HeroProjectile else (from as HeroProjectile).owner_player)
	if element != "" and data.weak_to.has(element):
		return false
	if from is Fighter and (from as Fighter).height > 4.0:
		return false
	var toward := 1 if from.position.x >= position.x else -1
	return toward == facing


func _guard_block(from: Node2D) -> void:
	_guard_blocks += 1
	_block_frames = BLOCK_FRAMES
	if from is Fighter:
		(from as Fighter).hitstop = maxi((from as Fighter).hitstop, HITSTOP_FRAMES)
	hitstop = HITSTOP_FRAMES
	Sound.play("block", -4.0)
	stage.fx("hit", position + Vector2(facing * body_size.x * 0.5, 0.0), body_size.y * 0.55, facing < 0)
	stage.popup("BLOQUEIO", position, body_size.y + 6.0, RESIST_COLOR)
	if _guard_blocks >= GUARD_HITS:
		_guard_blocks = 0
		start_attack(CONTRAGOLPE)


# --- Fases ---------------------------------------------------------------------------

func _on_attack_finished() -> void:
	match current_attack.get("name", ""):
		"corte":
			var follow := CORTE_FINAL.duplicate()
			if phase >= 2:
				follow["startup"] = 8
			start_attack(follow)
			return
		"corte_final":
			if phase == 3:
				start_attack(CHUVA_RAPIDA)
				return
	height = 0.0
	match phase:
		1:
			_cooldown = Difficulty.cooldown(randi_range(45, 75))
		2:
			_cooldown = Difficulty.cooldown(randi_range(25, 45))
		_:
			_cooldown = Difficulty.cooldown(randi_range(15, 30))
	enter_state(State.IDLE)


func _on_damaged(_damage: int, _heavy: bool) -> void:
	if phase == 1 and hp <= max_hp * PHASE_TWO_RATIO:
		phase = 2
		armor_hits = 0
		_armor_left = 0
		body_color = data.phase_two_color
		if sprite:
			sprite.modulate = data.phase_two_color.lightened(0.3)
		_phase_effect()
		stage.popup("SEM ARMADURA!", position, body_size.y + 10.0, GLOW_COLOR)
	if not _summoned and hp > 0 and hp <= max_hp * SUMMON_RATIO:
		_summoned = true
		phase = 3
		if sprite:
			sprite.modulate = FURY_COLOR.lightened(0.35)
		_phase_effect()
		stage.popup("FÚRIA!", position, body_size.y + 10.0, FURY_COLOR)
		stage.spawn_reinforcements(load(SUMMON) as EnemyData, SUMMON_FURY)


func _phase_effect() -> void:
	flash = 30
	stage.shake(4.0)
	Sound.play("phase", -2.0, 0.0)
	stage.fx("phase", position, body_size.y * 0.6)
	phase_changed.emit(phase)


func _attack_anim() -> String:
	match current_attack.get("name", ""):
		"corte":
			return "atk1"
		"corte_final", "contragolpe":
			return "atk2"
		"lancar_lamina":
			return "atk3"
		"guarda":
			return "defend"
		"investida_cortante":
			return "dash"
		"chuva_de_laminas":
			return "sp_atk"
	return super()


func _draw_details(body: Rect2) -> void:
	# Só o "!" comum (Enemy); as placas e o brilho são do Ferrugem.
	if state == State.ATTACK and current_attack.get("telegraph", false) \
			and state_frame <= int(current_attack.get("startup", 0)):
		var x := body.position.x + body_size.x / 2.0 - 1.5
		draw_rect(Rect2(Vector2(x, body.position.y - 12.0), Vector2(3.0, 6.0)), Color("ffcc33"))
		draw_rect(Rect2(Vector2(x, body.position.y - 5.0), Vector2(3.0, 2.0)), Color("ffcc33"))

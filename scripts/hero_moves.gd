class_name HeroMoves
## Golpes próprios de cada herói, com a identidade do elemento. Os comandos são
## os mesmos para todos; o que muda é o golpe que sai:
##
##   Trás + J ...................... golpe de virada (vira e bate em quem estava atrás)
##   Segurar J e soltar ............ ataque carregado (meio segundo segurando)
##   Baixo + L ..................... especial secundário (gasta 30 do medidor)
##   No ar: baixo + J .............. golpe aéreo próprio
##   L junto com o parceiro ........ ataque em dupla (dois heróis perto, especial ao mesmo tempo)
##
## Cada golpe é o Dictionary de sempre do Fighter (startup, active, recovery,
## damage, near/far, depth, y_lo/y_hi, area, knockdown, launch, move_speed) mais
## estas chaves, todas opcionais:
##
##   label ........ nome que aparece na tela quando o golpe sai
##   anim ......... animação da arte (atk1, atk2, atk3, air_atk, sp_atk, roll, defend)
##   full_art ..... toca a animação inteira, do preparo ao fim (como o especial)
##   burn ......... queimadura: N pulsos de dano ao longo do tempo (nunca mata)
##   freeze ....... congela o alvo por N quadros (um golpe que derruba estilhaça o gelo)
##   pull / push .. puxa ou empurra o alvo N px na horizontal
##   multi ........ o golpe acerta de novo a cada N quadros enquanto está ativo
##   drift ........ anda N px/s durante o preparo e o ativo (negativo = para trás)
##   teleport ..... no 1º quadro surge atrás do inimigo mais perto à frente (até N px)
##   armor ........ não é interrompido nem derrubado durante o golpe
##   counter ...... postura: se apanhar durante o ativo, não leva dano e revida (riposte)
##   heal ......... recupera N de vida no quadro de impacto
##   projectile ... dispara um projétil no quadro de impacto (veja HeroProjectile)
##   fx / shake ... efeito visual e tremor de tela no quadro de impacto
##   no_hit ....... o golpe em si não acerta (só o projétil ou o efeito)
##   dive ......... golpe aéreo: velocidade (x para a frente, z para baixo) do mergulho
##   land ......... golpe aéreo: impacto ao tocar o chão (outro golpe completo)
##   meter_cost ... custo do especial secundário (padrão SPECIAL2_COST)
##   hp_ok ........ false = o especial secundário só sai com medidor (sem pagar vida)

## Segurar J por este tanto de quadros carrega o golpe.
const CHARGE_FRAMES := 30
## Virar e apertar J em até este tanto de quadros ainda conta como golpe de virada.
const BACK_TURN_FRAMES := 6
const SPECIAL2_COST := 30
const SPECIAL2_HP_COST := 10
## Projétil e especial secundário carregam menos medidor que um golpe corpo a corpo.
const METER_PER_PROJECTILE_HIT := 4
## Ataque em dupla: os dois apertam o especial com até 15 quadros de diferença,
## perto um do outro.
const TEAM_WINDOW_FRAMES := 15
const TEAM_RANGE := Vector2(90.0, 24.0)
const TEAM_ATTACK := {"name": "fusao", "damage": 30, "radius": 96.0, "depth": 32.0, "launch": 220.0}
const RIPOSTE_INVULN := 24

const FX_DIR := "res://assets/heroes_fx/"

const LAND_BASE := {"anim": "j_down", "startup": 0, "active": 4, "recovery": 12, "near": 0.0,
	"area": true, "depth": 16.0, "y_lo": 0.0, "y_hi": 30.0, "knockdown": true, "shake": 2.5, "fx": "stomp"}

const MOVES := {
	# --- Brasa, Cavaleiro de Fogo: espada em chamas, queima quem toca ---------------
	"fire_knight": {
		"back": {"name": "lamina_reversa", "label": "Lâmina Reversa", "anim": "atk2", "startup": 4, "active": 4,
			"recovery": 12, "damage": 10, "near": -6.0, "far": 30.0, "burn": 3},
		"charged": {"name": "espada_incandescente", "label": "Espada Incandescente", "anim": "atk3",
			"startup": 6, "active": 6, "recovery": 18, "damage": 18, "near": 0.0, "far": 34.0, "knockdown": true,
			"burn": 4, "drift": 50.0, "y_hi": 50.0, "shake": 2.0},
		"special2": {"name": "bola_de_fogo", "label": "Bola de Fogo", "anim": "atk1", "startup": 8, "active": 2,
			"recovery": 14, "no_hit": true,
			"projectile": {"art": "fogo", "speed": 210.0, "damage": 14, "knockdown": true, "burn": 3}},
		"air": {"name": "meteoro", "label": "Meteoro", "anim": "air_atk", "damage": 10, "near": -4.0, "far": 28.0,
			"y_lo": -12.0, "y_hi": 24.0, "knockdown": true, "burn": 2, "dive": Vector2(130.0, -300.0),
			"land": {"name": "meteoro_impacto", "damage": 10, "far": 36.0, "burn": 3, "fx": "special_fogo"}},
	},
	# --- Vento, Assassino do Vento: velocidade, cortes múltiplos, some e aparece ------
	"wind_hashashin": {
		"back": {"name": "passo_do_vento", "label": "Passo do Vento", "anim": "atk2", "startup": 5, "active": 4,
			"recovery": 10, "damage": 10, "near": -10.0, "far": 30.0, "teleport": 90.0},
		"charged": {"name": "lamina_ciclone", "label": "Lâmina Ciclone", "anim": "atk3", "full_art": true,
			"startup": 6, "active": 30, "recovery": 12, "damage": 4, "near": 0.0, "far": 40.0, "area": true,
			"depth": 14.0, "multi": 6, "pull": 6.0},
		"special2": {"name": "corte_de_vacuo", "label": "Corte de Vácuo", "anim": "atk1", "startup": 5, "active": 2,
			"recovery": 10, "no_hit": true,
			"projectile": {"art": "vento", "speed": 320.0, "damage": 8, "pierce": true}},
		"air": {"name": "mergulho_do_falcao", "label": "Mergulho do Falcão", "anim": "air_atk", "damage": 6,
			"near": -4.0, "far": 30.0, "y_lo": -14.0, "y_hi": 26.0, "multi": 5, "dive": Vector2(220.0, -180.0),
			"land": {"name": "falcao_pouso", "damage": 6, "far": 26.0, "knockdown": false, "shake": 1.0, "fx": "special_vento"}},
	},
	# --- Folha, Arqueira da Folha: distância, flechas e raízes que prendem -----------
	"leaf_ranger": {
		"back": {"name": "salto_recuado", "label": "Salto Recuado", "anim": "roll", "startup": 4, "active": 10,
			"recovery": 8, "no_hit": true, "drift": -150.0,
			"projectile": {"art": "folha", "speed": 300.0, "damage": 8}},
		"charged": {"name": "flecha_perfurante", "label": "Flecha Perfurante", "anim": "atk1", "startup": 8,
			"active": 2, "recovery": 14, "no_hit": true,
			"projectile": {"art": "folha", "speed": 380.0, "damage": 16, "pierce": true, "knockdown": true}},
		"special2": {"name": "raizes", "label": "Raízes Prendedoras", "anim": "atk2", "startup": 8, "active": 4,
			"recovery": 14, "damage": 6, "near": 0.0, "far": 140.0, "depth": 18.0, "freeze": 75,
			"fx": "special_folha", "fx_on_target": true},
		"air": {"name": "chuva_de_flechas", "label": "Chuva de Flechas", "anim": "air_atk", "damage": 5,
			"near": 16.0, "far": 90.0, "depth": 16.0, "y_lo": -200.0, "y_hi": 10.0, "multi": 7},
	},
	# --- Terra, Monge da Terra: peso, tremores de chão, pilares de pedra -------------
	"ground_monk": {
		"back": {"name": "cotovelada_de_pedra", "label": "Cotovelada de Pedra", "anim": "atk2", "startup": 4,
			"active": 4, "recovery": 12, "damage": 12, "near": -6.0, "far": 28.0, "knockdown": true},
		"charged": {"name": "punho_sismico", "label": "Punho Sísmico", "anim": "atk3", "startup": 8, "active": 4,
			"recovery": 18, "damage": 16, "near": 0.0, "far": 32.0, "knockdown": true, "armor": true, "shake": 3.0,
			"projectile": {"ground": true, "speed": 170.0, "damage": 12, "knockdown": true}},
		"special2": {"name": "pilares_de_pedra", "label": "Pilares de Pedra", "anim": "sp_atk", "startup": 8,
			"active": 4, "recovery": 16, "damage": 14, "near": 0.0, "far": 50.0, "area": true, "depth": 20.0,
			"y_lo": 0.0, "y_hi": 50.0, "launch": 260.0, "knockdown": true, "fx": "special_terra", "shake": 2.5},
		"air": {"name": "queda_de_rocha", "label": "Queda de Rocha", "anim": "air_atk", "damage": 10, "near": -6.0,
			"far": 22.0, "y_lo": -20.0, "y_hi": 20.0, "knockdown": true, "dive": Vector2(0.0, -420.0),
			"land": {"name": "rocha_impacto", "damage": 14, "far": 46.0, "depth": 20.0, "shake": 4.0, "fx": "special_terra"}},
	},
	# --- Metal, Guardiã das Lâminas: precisão, estocadas longas e contra-ataque -------
	"metal_bladekeeper": {
		"back": {"name": "lamina_giratoria", "label": "Lâmina Giratória", "anim": "atk3", "startup": 4, "active": 8,
			"recovery": 12, "damage": 6, "near": 0.0, "far": 34.0, "area": true, "multi": 4},
		"charged": {"name": "estocada_de_aco", "label": "Estocada de Aço", "anim": "atk2", "startup": 6, "active": 10,
			"recovery": 16, "damage": 18, "near": 0.0, "far": 40.0, "knockdown": true, "move_speed": 230.0,
			"y_hi": 46.0},
		"special2": {"name": "postura_de_aco", "label": "Postura de Aço", "anim": "defend", "full_art": true,
			"startup": 2, "active": 40, "recovery": 10, "no_hit": true, "counter": true},
		"air": {"name": "chuva_de_laminas", "label": "Chuva de Lâminas", "anim": "air_atk", "damage": 12,
			"near": -6.0, "far": 34.0, "y_lo": -16.0, "y_hi": 26.0, "knockdown": true, "dive": Vector2(150.0, -260.0)},
	},
	# --- Cristal, Esmagador de Cristal: força bruta e estilhaços ---------------------
	"crystal_mauler": {
		"back": {"name": "ombro_de_cristal", "label": "Ombro de Cristal", "anim": "atk2", "startup": 5, "active": 6,
			"recovery": 12, "damage": 12, "near": 0.0, "far": 28.0, "knockdown": true, "move_speed": 140.0},
		"charged": {"name": "esmagamento", "label": "Esmagamento", "anim": "atk3", "startup": 10, "active": 5,
			"recovery": 20, "damage": 20, "near": 0.0, "far": 52.0, "area": true, "depth": 20.0, "y_lo": 0.0,
			"knockdown": true, "armor": true, "shake": 3.5, "fx": "special_cristal"},
		"special2": {"name": "estilhacos", "label": "Estilhaços", "anim": "atk1", "startup": 7, "active": 2,
			"recovery": 14, "no_hit": true,
			"projectile": {"art": "cristal", "speed": 260.0, "damage": 9, "lanes": [-14.0, 0.0, 14.0]}},
		"air": {"name": "bigorna", "label": "Bigorna", "anim": "air_atk", "damage": 10, "near": -6.0, "far": 24.0,
			"y_lo": -20.0, "y_hi": 20.0, "knockdown": true, "dive": Vector2(0.0, -440.0),
			"land": {"name": "bigorna_impacto", "damage": 16, "far": 50.0, "depth": 20.0, "launch": 220.0,
				"shake": 4.0, "fx": "special_cristal"}},
	},
	# --- Água, Sacerdotisa da Água: controle de espaço, ondas e cura -----------------
	"water_priestess": {
		"back": {"name": "contracorrente", "label": "Contracorrente", "anim": "atk1", "startup": 4, "active": 4,
			"recovery": 12, "damage": 8, "near": -6.0, "far": 34.0, "push": 40.0},
		"charged": {"name": "mare", "label": "Maré", "anim": "atk2", "startup": 8, "active": 2, "recovery": 16,
			"no_hit": true,
			"projectile": {"art": "agua", "speed": 170.0, "damage": 10, "pierce": true, "knockdown": true,
				"carry": true}},
		"special2": {"name": "fonte_de_cura", "label": "Fonte de Cura", "anim": "sp_atk", "startup": 8, "active": 4,
			"recovery": 14, "damage": 6, "near": 0.0, "far": 44.0, "area": true, "depth": 20.0, "y_lo": 0.0,
			"y_hi": 50.0, "knockdown": true, "heal": 20, "meter_cost": 40, "hp_ok": false, "fx": "heal"},
		"air": {"name": "gota_cadente", "label": "Gota Cadente", "anim": "air_atk", "damage": 8, "near": -4.0,
			"far": 28.0, "y_lo": -14.0, "y_hi": 24.0, "dive": Vector2(110.0, -300.0),
			"land": {"name": "gota_impacto", "damage": 10, "far": 42.0, "push": 30.0, "fx": "special_agua"}},
	},
}

## Nome do ataque em dupla para cada par de elementos (em ordem alfabética).
const TEAM_NAMES := {
	"Fogo+Vento": "Tornado de Fogo", "Água+Fogo": "Vapor Escaldante", "Fogo+Terra": "Magma",
	"Fogo+Folha": "Incêndio Florestal", "Fogo+Metal": "Forja",
	"Cristal+Fogo": "Prisma Ardente", "Água+Folha": "Floresta Viva",
	"Terra+Vento": "Tempestade de Areia", "Cristal+Terra": "Geodo",
	"Metal+Vento": "Furacão de Lâminas", "Água+Terra": "Lamaçal", "Folha+Vento": "Redemoinho de Folhas",
}


static func get_move(id: String, slot: String) -> Dictionary:
	var moves: Dictionary = MOVES.get(id, MOVES["fire_knight"])
	var move: Dictionary = moves[slot].duplicate(true)
	if move.has("land"):
		var land := LAND_BASE.duplicate()
		land.merge(move["land"], true)
		move["land"] = land
	return move


## Todos os nomes de golpes deste herói (para a arte achar a animação certa).
static func slots() -> Array:
	return ["back", "charged", "special2", "air"]


static func team_name(a: String, b: String) -> String:
	var pair := [a, b]
	pair.sort()
	var key := "%s+%s" % pair
	if TEAM_NAMES.has(key):
		return TEAM_NAMES[key]
	if a == b:
		return "Fúria de %s" % a
	return "Fusão %s e %s" % pair


static func is_team_name(label: String) -> bool:
	return TEAM_NAMES.values().has(label) or label.begins_with("Fúria de ") or label.begins_with("Fusão ")


# --- Quadro a quadro ---------------------------------------------------------------

## Chamado pelo Player a cada quadro de um golpe, antes da checagem de acerto.
static func on_attack_frame(p: Player) -> void:
	var a := p.current_attack
	var startup := int(a.get("startup", 0))
	var active := int(a.get("active", 0))
	var f := p.state_frame
	if f == 1 and a.has("teleport"):
		_teleport_behind(p, float(a["teleport"]))
	if a.has("drift") and f <= startup + active:
		p.position.x += p.facing * float(a["drift"]) * Fighter.DT
	if f == startup + 1:
		_on_impact(p, a)
	# Golpe de vários acertos: a lista de quem já levou é zerada de tempos em tempos.
	if a.has("multi") and f > startup and (f - startup - 1) % int(a["multi"]) == 0:
		p._attack_hits.clear()


static func _on_impact(p: Player, a: Dictionary) -> void:
	if a.has("projectile"):
		spawn_projectiles(p, a["projectile"])
	if a.has("heal"):
		p.heal(int(a["heal"]))
		if p.stage:
			p.stage.fx("heal", p.position, 20.0)
	if p.stage == null:
		return
	if a.has("fx") and not a.get("fx_on_target", false):
		var ahead := 0.0 if a.get("area", false) else float(a.get("far", 0.0)) * 0.6
		p.stage.fx(a["fx"], p.position + Vector2(p.facing * ahead, 0.0), 0.0, p.facing < 0)
	if a.has("shake"):
		p.stage.shake(float(a["shake"]))


## Vento: some e reaparece atrás do inimigo mais perto à frente, já virado para ele.
static func _teleport_behind(p: Player, reach: float) -> void:
	var best: Fighter = null
	for enemy: Fighter in p._opponents():
		if not enemy is Enemy or not enemy.can_be_hit():
			continue
		var ahead := (enemy.position.x - p.position.x) * p.facing
		if ahead < 0.0 or ahead > reach or absf(enemy.position.y - p.position.y) > 16.0:
			continue
		if best == null or ahead < (best.position.x - p.position.x) * p.facing:
			best = enemy
	if best == null:
		return
	if p.stage:
		p.stage.fx("dust", p.position)
	p.position = Vector2(best.position.x + p.facing * 20.0, best.position.y)
	p.facing = -p.facing
	if p.stage:
		p.stage.fx("special_vento", p.position, 0.0, p.facing < 0)


# --- Efeitos no alvo ----------------------------------------------------------------

## Queimadura, congelamento, puxão e empurrão de um golpe (ou projétil) que acertou.
static func apply_effects(source: Fighter, target: Fighter, data: Dictionary, dir: int) -> void:
	if not is_instance_valid(target) or target.state == Fighter.State.DEAD:
		return
	if data.has("burn"):
		ElementStatus.burn(target, int(data["burn"]))
	if data.has("freeze") and target.hp > 0 and not data.get("knockdown", false):
		ElementStatus.freeze(target, int(data["freeze"]))
	if data.has("pull") and not target.heavy_body:
		var gap := source.position.x - target.position.x
		target.position.x += clampf(gap, -float(data["pull"]), float(data["pull"])) * (1.0 if absf(gap) > 14.0 else 0.0)
		target.position.y = move_toward(target.position.y, source.position.y, 2.0)
	if data.has("push") and not target.heavy_body:
		target.position.x += dir * float(data["push"])
	if data.get("fx_on_target", false) and source.stage:
		source.stage.fx(data["fx"], target.position, 0.0, dir < 0)


# --- Projéteis ------------------------------------------------------------------------

static func spawn_projectiles(p: Player, data: Dictionary) -> void:
	if p.stage == null:
		return
	var lanes: Array = data.get("lanes", [0.0])
	for lane: float in lanes:
		var shot := HeroProjectile.new()
		shot.stage = p.stage
		shot.owner_player = p
		shot.data = data
		shot.direction = p.facing
		shot.speed = float(data.get("speed", 200.0))
		shot.damage = int(data.get("damage", 8))
		shot.ground = data.get("ground", false)
		if data.has("art"):
			shot.art = FX_DIR + String(data["art"]) + ".png"
		var at := p.position + Vector2(p.facing * 14.0, lane)
		shot.position = p.stage.clamp_to_floor(at) if lane != 0.0 else at
		p.stage.actors.add_child(shot)
	Sound.play("arrow" if data.get("art", "") == "folha" else "whiff", -6.0)


# --- Ataque em dupla --------------------------------------------------------------------

## Os dois heróis soltaram o especial juntos e perto: sai a fusão dos elementos no
## meio deles. Devolve o nome do ataque (vazio se não houve dupla).
static func try_team_attack(p: Player) -> String:
	if p.stage == null or not p.is_inside_tree():
		return ""
	var now := Engine.get_physics_frames()
	for other: Node in p.get_tree().get_nodes_in_group(&"players"):
		if other == p or not other is Player or not is_instance_valid(other):
			continue
		var partner := other as Player
		if partner.stage != p.stage or partner.state == Fighter.State.DEAD:
			continue
		if now - partner.last_special_tick > TEAM_WINDOW_FRAMES:
			continue
		var gap := (partner.position - p.position).abs()
		if gap.x > TEAM_RANGE.x or gap.y > TEAM_RANGE.y:
			continue
		# A fusão consome a "janela" dos dois: não dispara de novo no mesmo especial.
		partner.last_special_tick = -1000
		p.last_special_tick = -1000
		return _team_attack(p, partner)
	return ""


## Quantas fusões saíram (para o log do co-op e os testes).
static var team_attacks := 0


static func _team_attack(a: Player, b: Player) -> String:
	team_attacks += 1
	var ea: String = a.character.get("element", "Fogo")
	var eb: String = b.character.get("element", "Fogo")
	var title := team_name(ea, eb)
	var center := (a.position + b.position) / 2.0
	var power := (float(a.character.get("power", 1.0)) + float(b.character.get("power", 1.0))) / 2.0
	var damage := roundi(TEAM_ATTACK["damage"] * power)
	for enemy: Fighter in a.stage.enemies():
		var d := enemy.position - center
		if absf(d.x) > TEAM_ATTACK["radius"] or absf(d.y) > TEAM_ATTACK["depth"]:
			continue
		if enemy.take_hit(damage, true, a, TEAM_ATTACK["launch"]):
			a._count_hit(damage)
			b.add_meter(Player.METER_PER_HIT)
			a.add_meter(Player.METER_PER_HIT)
	a.stage.fx(Player.special_effect(ea), center + Vector2(-20.0, 0.0))
	a.stage.fx(Player.special_effect(eb), center + Vector2(20.0, 0.0), 0.0, true)
	a.stage.shake(5.0)
	a.move_used.emit(title, a.element_color())
	b.move_used.emit(title, b.element_color())
	return title

extends SceneTree
## Testes da fase 2 (Cemitério de Ferro): dados da fase, cenário trocável, Sombra,
## Curandeira, chefe Corrosão e a passagem da fase 1 para a 2.
##   godot --headless --path . --fixed-fps 60 --script res://tests/test_fase2.gd

const MAIN := preload("res://scenes/main.tscn")
const CAPANGA := preload("res://data/enemies/capanga.tres")
const SOMBRA := preload("res://data/enemies/sombra.tres")
const CURANDEIRA := preload("res://data/enemies/curandeira.tres")
const CORROSAO := preload("res://data/enemies/corrosao.tres")

var stage: Stage
var player: Player
var _main: Node
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tests := [
		test_fase_list_and_sections,
		test_every_wave_enemy_exists,
		test_scenery_is_swappable,
		test_fase_two_loads_its_sections,
		test_new_enemies_use_their_scripts_and_art,
		test_sombra_vanishes_and_strikes_from_behind,
		test_sombra_can_be_stopped_while_fading,
		test_curandeira_heals_wounded_allies,
		test_curandeira_heal_is_interrupted_by_a_hit,
		test_curandeira_never_heals_the_boss,
		test_boss_banner_and_phases,
		test_boss_guard_blocks_and_counters,
		test_boss_guard_breaks_from_behind_and_with_knockdown,
		test_boss_blade_returns_like_a_boomerang,
		test_boss_dash_marks_the_ground,
		test_boss_blade_rain_marks_three_spots,
		test_next_stage_carries_score_and_lives,
		test_online_always_plays_fase_one,
	]
	for test: Callable in tests:
		print("\n%s" % test.get_method())
		await test.call()
		if is_instance_valid(_main):
			await _teardown()
	Fases.current = 1
	print("\n%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- Testes ----------------------------------------------------------------------

func test_fase_list_and_sections() -> void:
	_check(Fases.count() >= 2, "pelo menos 2 fases")
	Fases.current = 1
	_check(Fases.sections() == Stage.SECTIONS, "a fase 1 continua usando Stage.SECTIONS")
	Fases.current = 2
	var sections := Fases.sections()
	_check(sections.size() == 3, "fase 2 com 3 seções")
	var waves := 0
	var boss_locks := 0
	for s: Dictionary in sections:
		for lock: Dictionary in s["locks"]:
			waves += lock["waves"].size()
			if lock.get("boss", false):
				boss_locks += 1
				_check(lock["waves"] == [["corrosao"]], "a trava do chefe só tem o Corrosão")
	_check(waves >= 12, "fase 2 com %d ondas (12 ou mais)" % waves)
	_check(boss_locks == 1, "uma trava de chefe, no fim")
	Fases.cycle(1)
	_check(Fases.current == 1, "trocar de fase no título dá a volta")
	Fases.cycle(-1)
	_check(Fases.current == 2, "e volta para a 2")
	Fases.current = 1


func test_every_wave_enemy_exists() -> void:
	var missing := []
	for n in Fases.count():
		Fases.current = n + 1
		for s: Dictionary in Fases.sections():
			for lock: Dictionary in s["locks"]:
				for wave: Array in lock["waves"]:
					for name: String in wave:
						if not Stage.ENEMIES.has(name):
							missing.append(name)
			for ambush: Dictionary in s.get("ambushes", []):
				for name: String in ambush["enemies"]:
					if not Stage.ENEMIES.has(name):
						missing.append(name)
	Fases.current = 1
	_check(missing.is_empty(), "todo inimigo das ondas existe em Stage.ENEMIES %s" % [missing])


func test_scenery_is_swappable() -> void:
	StageScenery.biome = "ferro_velho"
	Fases.current = 1
	_check(StageScenery.setting("bg") == "bg_%d.png", "fase 1: ferro-velho de dia")
	Fases.current = 2
	_check(StageScenery.setting("bg") == "bg_noite_%d.png", "fase 2 (provisório): ferro-velho à noite")
	_check(StageScenery.setting("back_row") == StageScenery.data("ferro_velho")["back"], "o que a fase não troca vem do padrão")
	var dir: String = StageScenery.setting("dir")
	for i in 4:
		_check(ResourceLoader.exists(dir + StageScenery.setting("bg") % (i + 1)), "camada %d do fundo existe" % (i + 1))
	_check(ResourceLoader.exists(dir + StageScenery.setting("floor")), "chão existe")
	_check(StageScenery.section_title(0) == "Portão do ferro-velho", "ferro-velho: seção com o nome da fase")
	# Num bioma elemental, a arte e os nomes de seção vêm do bioma em qualquer fase.
	StageScenery.biome = "vulcao"
	_check(StageScenery.setting("bg") == "bg_%d.png" and StageScenery.setting("dir").ends_with("vulcao/"), "fase 2 no vulcão: arte do bioma")
	_check(StageScenery.section_title(0) == "Encosta de cinzas", "fase 2 no vulcão: seção com o nome do bioma")
	StageScenery.biome = "ferro_velho"
	Fases.current = 1


func test_fase_two_loads_its_sections() -> void:
	Fases.current = 2
	await _setup(true)
	_check(stage.sections == Fases.FASE_2_SECTIONS, "a fase abre com as seções da fase 2")
	var bg_ok := false
	var scenery := _main.get_node("View3D/Scenery")
	for node in scenery.get_children():
		if node is MeshInstance3D and node.material_override is StandardMaterial3D:
			var tex: Texture2D = node.material_override.albedo_texture
			if tex and tex.resource_path.ends_with("bg_noite_1.png"):
				bg_ok = true
	_check(bg_ok, "o cenário 3D usa as camadas da fase 2")
	# Anda até a primeira trava e confere que a primeira onda é a da fase 2.
	player.lives = 99
	player.invuln = 100000
	for i in 600:
		player.input.move = Vector2(1, 0)
		await physics_frame
		if stage.locked:
			break
	player.input.move = Vector2.ZERO
	await _frames(30)
	_check(stage.locked and is_equal_approx(stage.cam_left, 288.0), "trava na primeira parada da fase 2")
	var names := stage.enemies().map(func(e: Enemy) -> String: return e.data.display_name)
	_check("Capanga" in names, "primeira onda chegou (%s)" % [names])
	Fases.current = 1


func test_new_enemies_use_their_scripts_and_art() -> void:
	await _setup()
	var sombra := _enemy(SOMBRA, Vector2(80, 0))
	var cura := _enemy(CURANDEIRA, Vector2(-80, 0))
	var boss := _enemy(CORROSAO, Vector2(150, 0))
	_check(sombra is Sombra, "Sombra usa scripts/enemies/sombra.gd")
	_check(cura is Curandeira, "Curandeira usa scripts/enemies/curandeira.gd")
	_check(boss is Corrosao and boss is Boss, "Corrosão é um chefe (Boss) com script próprio")
	_check(stage.boss == boss, "a fase registra o Corrosão como chefe")
	for e: Enemy in [sombra, cura, boss]:
		_check(e.sprite != null and e.sprite.texture != null, "%s tem arte" % e.data.display_name)
		_check(e.sprite.modulate != Color.WHITE, "%s tem paleta própria (corrompida)" % e.data.display_name)
	_check(ResourceLoader.exists(LaminaGiratoria.ART), "arte da lâmina existe")


func test_sombra_vanishes_and_strikes_from_behind() -> void:
	await _setup()
	player.facing = 1
	var sombra: Sombra = _enemy(SOMBRA, Vector2(120, 0), true)
	sombra._cooldown = 0
	sombra._sumir_cooldown = 0
	await _until(func() -> bool: return sombra.state == Fighter.State.ATTACK and sombra.current_attack.get("name") == "sumir", 120)
	_check(sombra.current_attack.get("name") == "sumir", "Sombra começa o Passo Sombrio de longe")
	await _until(func() -> bool: return sombra._vanished(), 40)
	_check(not sombra.can_be_hit() and not sombra._is_visible_this_frame(), "sumida: invisível e intocável")
	await _until(func() -> bool: return sombra.current_attack.get("name") == "corte_sombrio", 60)
	_check(sombra.current_attack.get("name") == "corte_sombrio", "reaparece e corta")
	_check(sombra.position.x < player.position.x, "reaparece nas costas do herói (virado para a direita)")
	_check(sombra.current_attack.get("telegraph", false) and int(sombra.current_attack["startup"]) >= 14,
		"o corte tem \"!\" com tempo de reação")
	var hp := player.hp
	await _frames(int(Sombra.CORTE["startup"]) + 6)
	_check(player.hp < hp, "o corte acerta quem não reage")


func test_sombra_can_be_stopped_while_fading() -> void:
	await _setup()
	var sombra: Sombra = _enemy(SOMBRA, Vector2(24, 0))
	sombra.start_attack(Sombra.SUMIR)
	await _frames(4)
	_check(sombra.take_hit(6, false, player), "dá para acertar enquanto ela some")
	_check(sombra.state == Fighter.State.HURT, "o golpe cancela o Passo Sombrio")


func test_curandeira_heals_wounded_allies() -> void:
	await _setup()
	var cura: Curandeira = _enemy(CURANDEIRA, Vector2(120, 0), true)
	var ally := _enemy(CAPANGA, Vector2(100, 10))
	var far := _enemy(CAPANGA, Vector2(-200, 0))
	ally.hp = 5
	far.hp = 5
	cura._cooldown = 0
	cura._cura_cooldown = 0
	player.invuln = 100000
	await _until(func() -> bool: return cura.current_attack.get("name") == "cura", 30)
	_check(cura.current_attack.get("name") == "cura", "Curandeira começa a rezar quando há aliado ferido")
	await _frames(Curandeira.CURA_STARTUP + 2)
	_check(ally.hp == 5 + Curandeira.CURA_AMOUNT, "aliado perto recupera %d de vida (%d)" % [Curandeira.CURA_AMOUNT, ally.hp])
	_check(far.hp == 5, "aliado longe não é curado")


func test_curandeira_heal_is_interrupted_by_a_hit() -> void:
	await _setup()
	var cura: Curandeira = _enemy(CURANDEIRA, Vector2(24, 0))
	var ally := _enemy(CAPANGA, Vector2(60, 0))
	ally.hp = 5
	cura.start_attack(Curandeira.CURA)
	await _frames(10)
	cura.take_hit(6, false, player)
	await _frames(Curandeira.CURA_STARTUP + 5)
	_check(ally.hp == 5, "golpe durante a reza cancela a cura")


func test_curandeira_never_heals_the_boss() -> void:
	await _setup()
	var cura: Curandeira = _enemy(CURANDEIRA, Vector2(-60, 0))
	var boss := _enemy(CORROSAO, Vector2(-100, 0))
	boss.ai_enabled = false
	boss.hp = boss.max_hp - 50
	_check(not boss in cura._wounded_allies(), "o chefe fica fora da cura")


func test_boss_banner_and_phases() -> void:
	await _setup()
	var hud := _main.get_node("HUD/HUDView")
	var boss: Corrosao = _enemy(CORROSAO, Vector2(100, 0))
	await _frames(2)
	_check(hud._banner_text == "CORROSÃO, A LÂMINA ENFERRUJADA", "faixa do chefe com o nome dele")
	boss.take_hit(int(boss.max_hp * 0.55), false, player)
	await _frames(20)
	_check(boss.phase == 2 and boss.armor_hits == 0, "com 50% vai para a fase 2 e perde a armadura")
	var before := stage.enemies().size()
	boss.take_hit(int(boss.max_hp * 0.3), false, player)
	await _frames(5)
	_check(boss.phase == 3, "com 25% entra na fúria (fase 3)")
	var sombras := stage.enemies().filter(func(e: Enemy) -> bool: return e is Sombra).size()
	_check(sombras == Corrosao.SUMMON_FURY and stage.enemies().size() == before + Corrosao.SUMMON_FURY,
		"a fúria chama %d Sombras" % Corrosao.SUMMON_FURY)


func test_boss_guard_blocks_and_counters() -> void:
	await _setup()
	var boss: Corrosao = _enemy(CORROSAO, Vector2(30, 0))
	boss.ai_enabled = false
	boss.facing = -1
	boss.start_attack(Corrosao.GUARDA)
	await _frames(6)
	var hp := boss.hp
	_check(not boss.take_hit(8, false, player), "guarda segura golpe de frente")
	_check(boss.hp == hp, "sem dano na guarda")
	boss.take_hit(8, false, player)
	_check(boss.current_attack.get("name") == "contragolpe", "no 2º bloqueio revida com o contragolpe")
	_check(boss.current_attack.get("knockdown", false), "o contragolpe derruba")


func test_boss_guard_breaks_from_behind_and_with_knockdown() -> void:
	await _setup()
	var boss: Corrosao = _enemy(CORROSAO, Vector2(30, 0))
	boss.ai_enabled = false
	boss.facing = 1
	boss.start_attack(Corrosao.GUARDA)
	await _frames(6)
	var hp := boss.hp
	_check(boss.take_hit(8, false, player), "pelas costas a guarda não segura")
	_check(boss.hp < hp, "e o golpe tira vida")
	await _setup()
	boss = _enemy(CORROSAO, Vector2(30, 0))
	boss.ai_enabled = false
	boss.facing = -1
	boss.start_attack(Corrosao.GUARDA)
	await _frames(6)
	_check(boss.take_hit(14, true, player), "golpe que derruba atravessa a guarda")


func test_boss_blade_returns_like_a_boomerang() -> void:
	await _setup()
	var boss: Corrosao = _enemy(CORROSAO, Vector2(-120, 0))
	boss.ai_enabled = false
	boss.facing = 1
	player.position.y = boss.position.y
	boss.start_attack(Corrosao.LANCAR)
	await _frames(int(Corrosao.LANCAR["startup"]) + 2)
	var blade := boss._blade
	_check(is_instance_valid(blade), "lança a lâmina")
	var hp := player.hp
	await _until(func() -> bool: return player.hp < hp, 60)
	_check(player.hp < hp, "a lâmina acerta na ida")
	player.invuln = 0
	player.position.y = boss.position.y + 40.0
	var max_x := blade.position.x
	for i in 200:
		await physics_frame
		if not is_instance_valid(blade):
			break
		max_x = maxf(max_x, blade.position.x)
	_check(not is_instance_valid(blade), "a lâmina volta e some na mão do chefe")
	_check(max_x > boss.position.x + 100.0, "vai longe antes de voltar")


func test_boss_dash_marks_the_ground() -> void:
	await _setup()
	var boss: Corrosao = _enemy(CORROSAO, Vector2(-140, 0))
	boss.ai_enabled = false
	boss.phase = 2
	boss.facing = 1
	boss.start_attack(Corrosao.INVESTIDA)
	await _frames(10)
	var marker := boss.ground_marker()
	_check(not marker.is_empty() and marker["at"].x > boss.position.x + 100.0, "a investida marca no chão onde vai parar")
	var hp := player.hp
	await _frames(int(Corrosao.INVESTIDA["startup"]) + 30)
	_check(player.hp < hp and player.state == Fighter.State.KNOCKDOWN, "a investida atravessa e derruba")


func test_boss_blade_rain_marks_three_spots() -> void:
	await _setup()
	var boss: Corrosao = _enemy(CORROSAO, Vector2(-100, 0))
	boss.ai_enabled = false
	boss.phase = 3
	boss.start_attack(Corrosao.CHUVA)
	await _frames(int(Corrosao.CHUVA["startup"]) + 2)
	var lobs := stage.actors.get_children().filter(func(n: Node) -> bool: return n is Lob and n.look == "lamina")
	_check(lobs.size() == 3, "chuva de lâminas: 3 lâminas em arco")
	_check(lobs.any(func(l: Lob) -> bool: return l.target.distance_to(player.position) < 2.0), "uma cai onde o herói está")


func test_next_stage_carries_score_and_lives() -> void:
	Fases.current = 1
	await _setup()
	stage.score = 12345
	player.lives = 2
	Fases.advance(stage.score, player.lives)
	_check(Fases.current == 2, "Próxima fase vai para a 2")
	await _teardown()
	await _setup(false, true)
	_check(stage.score == 12345, "os pontos passam para a fase 2")
	_check(player.lives == 2, "as vidas passam para a fase 2")
	_check(Fases.carry.is_empty(), "o que passou é usado uma vez só")
	_check(not Fases.has_next(), "a fase 2 é a última por enquanto")
	var hud := _main.get_node("HUD/HUDView")
	_check(hud._victory_menu.items[0]["id"] == "denovo", "sem \"Próxima fase\" na última fase")
	Fases.current = 1


func test_online_always_plays_fase_one() -> void:
	Fases.current = 2
	var net := root.get_node_or_null(^"/root/Net")
	if net == null:
		_check(true, "sem autoload Net (pulado)")
		return
	# Só a parte da troca de fase do _goto (sem trocar de cena).
	Fases.current = 2
	Fases.carry = {"score": 1}
	var src: String = (load("res://scripts/net/net.gd") as GDScript).source_code
	_check(src.contains("Fases.current = 1"), "a partida online volta para a fase 1")
	Fases.current = 1
	Fases.reset_carry()


# --- Apoio -----------------------------------------------------------------------

func _setup(waves := false, keep_carry := false) -> void:
	if is_instance_valid(_main):
		await _teardown()
	seed(1234)
	if not keep_carry:
		Fases.reset_carry()
	Stage.continue_section = 0
	# Água: elemento neutro contra os inimigos novos (a fraqueza fura a guarda).
	Characters.selected = "water_priestess"
	_main = MAIN.instantiate()
	stage = _main.get_node("Stage")
	stage.auto_spawn = waves
	root.add_child(_main)
	player = stage.player
	player.input.scripted = true
	player.position = Vector2(150, 168)
	await _frames(2)


func _teardown() -> void:
	_main.queue_free()
	await _frames(2)


func _enemy(data: EnemyData, offset: Vector2, ai := false) -> Enemy:
	var enemy := stage.spawn_enemy(data, player.position + offset)
	enemy.ai_enabled = ai
	return enemy


func _until(condition: Callable, limit: int) -> void:
	for i in limit:
		if condition.call():
			return
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok      %s" % message)
	else:
		_failures += 1
		print("  FALHOU  %s" % message)

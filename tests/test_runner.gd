extends SceneTree
## Testes do combate rodando o jogo de verdade, sem janela:
##   godot --headless --path . --fixed-fps 60 --script res://tests/test_runner.gd
## Cada teste monta a cena principal sem ondas automáticas, coloca inimigos onde
## precisa e aperta botões pelo PlayerInput.

const MAIN := preload("res://scenes/main.tscn")
const CAPANGA := preload("res://data/enemies/capanga.tres")
const FACA := preload("res://data/enemies/faca.tres")
const BRUTAMONTES := preload("res://data/enemies/brutamontes.tres")
const FUNDEIRO := preload("res://data/enemies/fundeiro.tres")
const FERRUGEM := preload("res://data/enemies/ferrugem.tres")
const BRIGAO := preload("res://data/enemies/capanga_brigao.tres")
const PIROMANTE := preload("res://data/enemies/piromante.tres")
const ESCUDEIRO := preload("res://data/enemies/escudeiro.tres")

var stage: Stage
var player: Player
var _main: Node
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tests := [
		test_project_settings,
		test_walk_in_8_directions,
		test_three_hit_combo,
		test_combo_breaks_on_miss,
		test_depth_lane,
		test_jump_kick,
		test_grab_knees_and_throw,
		test_special_with_meter,
		test_special_costs_health_without_meter,
		test_full_meter_bonus_and_reset,
		test_dash_attack,
		test_enemy_chases_and_punches,
		test_at_most_two_attackers,
		test_camera_scroll_and_locks,
		test_knife_waits_then_strikes_and_retreats,
		test_tank_armor_and_charge,
		test_slinger_keeps_distance_and_throws,
		test_shockwave_and_lanes,
		test_boss_phases_and_summon,
		test_breakables_and_items,
		test_boss_defeat_clears_stage,
		test_death_and_respawn,
		test_combo_counter_and_bonus,
		test_combo_dropped_when_hit,
		test_launcher_and_juggle,
		test_flame_kick_sends_enemy_flying,
		test_special_cancel,
		test_armor_holds_against_knockdown,
		test_heavy_body_is_not_launched,
		test_boss_phase_two_attacks_through_jabs,
		test_juggle_limit_and_launcher_no_reset,
		test_combo_ends_before_lone_enemy_gets_up,
		test_getup_invulnerability,
		test_grab_special_without_resources_keeps_hold,
		test_throw_gets_full_meter_bonus,
		test_all_characters_have_art,
		test_character_stats,
		test_sprite_follows_state,
		test_reach_follows_art,
		test_long_attack_art_plays_in_poses,
		test_view_3d_mirrors_actors,
		test_spawn_margin_grows_with_depth,
		test_enemies_have_art,
		test_sound_bank,
		test_vfx,
		test_hitstop_by_attack_weight,
		test_hit_confirm_cancel,
		test_jump_cancel_and_air_combo,
		test_air_spike_ground_bounce,
		test_counter_hit,
		test_hurt_push_slides,
		test_damage_proration,
		test_style_rank_and_bonus,
		test_finishing_blow_slow_motion,
		test_damage_popups,
		test_back_attack_turns_and_burns,
		test_back_turn_needs_direction_held,
		test_charged_attack,
		test_special2_fireball,
		test_special2_costs_health_without_meter,
		test_air_meteor_dive_and_impact,
		test_every_hero_has_four_new_moves,
		test_wind_teleports_behind,
		test_freeze_holds_and_knockdown_shatters,
		test_ice_guardian_enemy,
		test_leaf_roots_hold_enemies_far_away,
		test_metal_counter_stance,
		test_earth_charged_has_armor,
		test_water_heals_only_with_meter,
		test_crystal_shards_cover_three_lanes,
		test_team_attack_fuses_elements,
		test_elemental_weakness_and_resistance,
		test_weakness_knockdown_breaks_armor,
		test_shield_blocks_front_hits,
		test_shield_falls_to_jump_kick_and_grab,
		test_shield_counters_after_blocks,
		test_bomber_lobs_at_player_position,
		test_bomb_hurts_enemies_too,
		test_explosive_barrel_and_chain,
		test_crate_takes_two_hits_and_orb_fills_meter,
		test_enemy_dodges_out_of_lane,
		test_brawler_chains_punches,
		test_enemy_drops_item,
		test_wave_spawns_staggered_and_overlap,
		test_ambush_while_scrolling,
		test_last_enemy_enrages,
		test_boss_throws_rock,
		test_boss_leap_is_untouchable_and_lands_on_target,
		test_boss_phase_three_fury,
		test_new_enemies_have_art,
	]
	for test: Callable in tests:
		print("\n%s" % test.get_method())
		await _setup()
		await test.call()
		await _teardown()
	print("\n%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- Testes ----------------------------------------------------------------------

func test_project_settings() -> void:
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 384, "resolução base 384 de largura")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height") == 216, "resolução base 216 de altura")
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "viewport", "stretch viewport (3D em resolução baixa)")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "aspect expand")
	_check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "filtro Nearest")
	_check(Engine.physics_ticks_per_second == 60, "física a 60 quadros")
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack", &"jump", &"special", &"pause"]:
		_check(InputMap.has_action(action), "ação %s no Input Map" % action)
	_check(stage.actors.y_sort_enabled, "Actors com y_sort (ordem pelos pés)")


func test_walk_in_8_directions() -> void:
	var start := player.position
	player.input.move = Vector2(1, 1)
	await _frames(30)
	player.input.move = Vector2.ZERO
	var moved := player.position - start
	_check(absf(moved.x - 45.0) < 2.0, "anda 90 px/s no eixo X (andou %.1f em meio segundo)" % moved.x)
	_check(absf(moved.y - 30.0) < 2.0, "anda 60 px/s na profundidade (andou %.1f)" % moved.y)
	player.input.move = Vector2(-1, 0)
	await _frames(400)
	_check(player.position.x == stage.floor_rect.position.x, "não sai da stage pela esquerda")


func test_three_hit_combo() -> void:
	var enemy := _spawn(Vector2(22, 0))
	for i in 3:
		player.input.press(&"attack")
		await _frames(12)
	await _until(func() -> bool: return enemy.state == Fighter.State.KNOCKDOWN, 30)
	_check(enemy.state == Fighter.State.KNOCKDOWN, "o gancho derrubou")
	await _frames(40)
	_check(enemy.hp == 30 - 6 - 8 - 14, "jab + direto + gancho = 28 de dano (vida %d)" % enemy.hp)
	_check(player.meter == 24, "medidor +8 por golpe (medidor %d)" % player.meter)


func test_combo_breaks_on_miss() -> void:
	player.input.press(&"attack")
	await _frames(12)
	player.input.press(&"attack")
	await _frames(4)
	_check(player.current_attack.get("name") == "jab", "golpe errado não emenda: o segundo é jab de novo")


func test_depth_lane() -> void:
	var enemy := _spawn(Vector2(22, 12))
	player.input.press(&"attack")
	await _frames(30)
	_check(enemy.hp == 30, "fora da faixa de profundidade o soco não acerta")
	enemy.position.y = player.position.y + 6
	player.input.press(&"attack")
	await _frames(30)
	_check(enemy.hp == 24, "dentro da faixa (6 px) acerta")


func test_jump_kick() -> void:
	var enemy := _spawn(Vector2(40, 0))
	var behind := _spawn(Vector2(60, 0))
	player.input.move = Vector2(1, 0)
	player.input.press(&"jump")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(4)
	_check(player.state == Fighter.State.JUMP and player.height > 0.0, "pulou")
	player.input.press(&"attack")
	await _frames(60)
	_check(enemy.hp == 20, "chute aéreo tira 10 (vida %d)" % enemy.hp)
	_check(enemy.state in [Fighter.State.KNOCKDOWN, Fighter.State.GETUP], "chute aéreo derruba")
	_check(behind.hp == 20, "o chute atravessa e acerta o de trás também (vida %d)" % behind.hp)


func test_grab_knees_and_throw() -> void:
	var enemy := _spawn(Vector2(30, 0))
	var other := _spawn(Vector2(-40, 0))
	player.input.move = Vector2(1, 0)
	await _frames(10)
	player.input.move = Vector2.ZERO
	_check(player.state == Fighter.State.GRAB and enemy.state == Fighter.State.GRABBED, "encostar agarra")
	player.input.press(&"attack")
	await _frames(18)
	player.input.press(&"attack")
	await _frames(18)
	_check(enemy.hp == 20, "duas joelhadas de 5 (vida %d)" % enemy.hp)
	player.input.move = Vector2(-1, 0)
	player.input.press(&"attack")
	await _frames(1)
	player.input.move = Vector2.ZERO
	_check(enemy.state == Fighter.State.THROWN, "direção + ataque arremessa")
	await _frames(60)
	_check(enemy.hp == 8, "o arremessado leva 12 ao cair (vida %d)" % enemy.hp)
	_check(other.hp == 18, "quem é atingido pelo arremessado leva 12 (vida %d)" % other.hp)
	_check(player.meter == 8 + 8 + 12, "medidor: joelhadas +8, arremesso +12 (medidor %d)" % player.meter)


func test_special_with_meter() -> void:
	var front := _spawn(Vector2(30, 10))
	var back := _spawn(Vector2(-40, -5))
	var far := _spawn(Vector2(120, 0))
	player.add_meter(60)
	player.input.press(&"special")
	await _frames(5)
	_check(player.invuln > 0, "invencível durante a Erupção")
	await _frames(60)
	_check(player.meter == 10 and player.hp == 100, "gasta 50 do medidor e nada de vida")
	_check(front.hp == 10 and back.hp == 10, "acerta 20 dos dois lados (vidas %d e %d)" % [front.hp, back.hp])
	_check(far.hp == 30, "não acerta quem está longe")


func test_special_costs_health_without_meter() -> void:
	player.input.press(&"special")
	await _frames(70)
	_check(player.hp == 85, "sem medidor, custa 15 de vida (vida %d)" % player.hp)
	player.hp = 10
	player.input.press(&"special")
	await _frames(70)
	_check(player.hp == 1, "o custo nunca mata (vida %d)" % player.hp)


func test_full_meter_bonus_and_reset() -> void:
	var enemy := _spawn(Vector2(22, 0))
	player.add_meter(100)
	player.input.press(&"attack")
	await _frames(20)
	_check(enemy.hp == 30 - 8, "medidor cheio: +2 de dano (vida %d)" % enemy.hp)
	await _frames(30)
	player.take_hit(5, false, enemy)
	_check(player.meter == 100, "golpe leve não zera o medidor")
	await _frames(20)
	player.take_hit(5, true, enemy)
	_check(player.meter == 0, "ser derrubado zera o medidor")


func test_dash_attack() -> void:
	var enemy := _spawn(Vector2(60, 0))
	for i in 2:
		player.input.move = Vector2(1, 0)
		await _frames(2)
		player.input.move = Vector2.ZERO
		await _frames(2)
	player.input.press(&"attack")
	await _frames(3)
	_check(player.current_attack.get("name") == "investida", "frente, frente + ataque sai a investida")
	await _frames(40)
	_check(enemy.hp == 18, "investida tira 12 (vida %d)" % enemy.hp)


func test_enemy_chases_and_punches() -> void:
	var enemy := _spawn(Vector2(120, 30), true)
	var start_distance := enemy.position.distance_to(player.position)
	var closest := start_distance
	var punched := false
	for i in 400:
		await physics_frame
		closest = minf(closest, enemy.position.distance_to(player.position))
		punched = punched or enemy.state == Fighter.State.ATTACK
	_check(closest < 30.0, "o inimigo vem até o jogador (chegou a %.0f px)" % closest)
	_check(punched and player.hp == 100 - CAPANGA.attack_damage * ((100 - player.hp) / CAPANGA.attack_damage) and player.hp < 100,
		"e soca, 5 por soco (vida do jogador %d)" % player.hp)


func test_at_most_two_attackers() -> void:
	player.max_hp = 100000
	player.hp = 100000
	for i in 5:
		_spawn(Vector2(-90 + i * 45, (i % 3 - 1) * 20), true)
	var most := 0
	for i in 600:
		await physics_frame
		var attacking := 0
		for enemy: Enemy in stage.enemies():
			if enemy.state == Fighter.State.ATTACK:
				attacking += 1
		most = maxi(most, attacking)
	_check(most <= 2, "no máximo 2 golpeando ao mesmo tempo (máximo visto %d)" % most)
	_check(most >= 1, "e alguém ataca")
	var sides := {}
	for enemy: Enemy in stage.enemies():
		sides[enemy.side] = true
	_check(sides.size() == 2, "inimigos dos dois lados (cerco)")


func test_camera_scroll_and_locks() -> void:
	player.max_hp = 100000
	player.hp = 100000
	stage.auto_spawn = true
	player.input.move = Vector2(1, 0)
	for i in 600:
		await physics_frame
		if stage.locked:
			break
	player.input.move = Vector2.ZERO
	_check(stage.locked and stage.cam_left == 288.0, "a câmera rola e trava no primeiro encontro (x %.0f)" % stage.cam_left)
	await _frames(30)
	_check(stage.enemies().size() == 2, "primeira onda com 2 capangas (tem %d)" % stage.enemies().size())
	player.input.move = Vector2(1, 0)
	await _frames(200)
	player.input.move = Vector2.ZERO
	_check(player.position.x <= stage.cam_left + 372.0, "com a tela travada o jogador não passa da borda")
	_kill_all()
	await _frames(170)
	_check(stage.wave == 2 and stage.enemies().size() == 3, "segunda onda com 3 (tem %d)" % stage.enemies().size())
	_kill_all()
	await _frames(120)
	_check(not stage.locked, "limpou as ondas: a câmera destrava")
	_check(stage.score == 500, "100 pontos por capanga (pontos %d)" % stage.score)


func test_knife_waits_then_strikes_and_retreats() -> void:
	var knife := stage.spawn_enemy(FACA, player.position + Vector2(70, 0))
	player.facing = 1
	await _frames(200)
	_check(player.hp == 100, "a Faca não ataca de frente (vida %d)" % player.hp)
	player.facing = -1
	var hit_frame := -1
	for i in 400:
		await physics_frame
		if player.hp < 100 and hit_frame < 0:
			hit_frame = i
		if hit_frame >= 0 and i > hit_frame + 50:
			break
	_check(hit_frame >= 0, "ataca quando o jogador vira de costas")
	_check(absf(knife.position.x - player.position.x) > 60.0, "e recua depois do golpe (distância %.0f)" % absf(knife.position.x - player.position.x))


func test_tank_armor_and_charge() -> void:
	var tank := stage.spawn_enemy(BRUTAMONTES, player.position + Vector2(24, 0))
	tank.ai_enabled = false
	player.input.press(&"attack")
	await _frames(12)
	player.input.press(&"attack")
	await _frames(14)
	_check(tank.hp == 80 - 14 and tank.state != Fighter.State.HURT, "armadura: os 2 primeiros golpes não atordoam (vida %d)" % tank.hp)
	_check(not tank.can_be_grabbed(), "o Brutamontes não pode ser agarrado")
	tank.queue_free()
	await _frames(2)
	var charger := stage.spawn_enemy(BRUTAMONTES, player.position + Vector2(130, 0))
	var knocked := false
	for i in 400:
		await physics_frame
		if player.state == Fighter.State.KNOCKDOWN:
			knocked = true
			break
	_check(knocked and player.hp == 85, "a investida tira 15 e derruba (vida %d)" % player.hp)
	_check(charger.current_attack.get("name") == "investida", "foi a investida")


func test_slinger_keeps_distance_and_throws() -> void:
	var slinger := stage.spawn_enemy(FUNDEIRO, player.position + Vector2(40, 0))
	var hit := false
	for i in 400:
		await physics_frame
		if player.hp < 100:
			hit = true
			break
	_check(absf(slinger.position.x - player.position.x) > 80.0, "o Fundeiro se afasta (distância %.0f)" % absf(slinger.position.x - player.position.x))
	_check(hit and player.hp == 94, "a pedra tira 6 (vida %d)" % player.hp)


func test_shockwave_and_lanes() -> void:
	stage.spawn_projectile(null, player.position + Vector2(60, 0), -1, 15, 140.0, true)
	await _frames(40)
	_check(player.hp == 85, "o abalo acerta quem está na mesma faixa (vida %d)" % player.hp)
	await _frames(40)
	stage.spawn_projectile(null, player.position + Vector2(60, 12), -1, 15, 140.0, true)
	await _frames(40)
	_check(player.hp == 85, "mudar de faixa desvia")
	stage.spawn_projectile(null, player.position + Vector2(40, 0), -1, 15, 140.0, true)
	player.input.press(&"jump")
	await _frames(40)
	_check(player.hp == 85, "pular desvia do abalo")


func test_boss_phases_and_summon() -> void:
	var boss: Boss = stage.spawn_enemy(FERRUGEM, player.position + Vector2(120, 0))
	boss.ai_enabled = false
	_check(stage.boss == boss and boss.hp == 300, "Ferrugem com 300 de vida")
	boss.take_hit(160, false, player)
	_check(boss.phase == 2 and boss.armor_hits == 0, "com metade da vida a armadura quebra (fase 2)")
	await _frames(10)
	boss.take_hit(80, false, player)
	await _frames(2)
	_check(stage.enemies().size() == 3, "abaixo de 25%% chama 2 capangas (inimigos %d)" % stage.enemies().size())


func test_breakables_and_items() -> void:
	player.hp = 50
	stage._spawn_breakable({"kind": "lixeira", "x": player.position.x + 20.0, "y": player.position.y, "item": "maca"})
	await _frames(2)
	player.input.press(&"attack")
	await _frames(30)
	_check(stage.breakables().is_empty(), "a lixeira quebra com um soco")
	_check(player.meter == 0, "quebrar lixeira não carrega o medidor")
	player.input.move = Vector2(1, 0)
	await _frames(20)
	player.input.move = Vector2.ZERO
	_check(player.hp == 70, "a maçã cura 20 (vida %d)" % player.hp)


func test_boss_defeat_clears_stage() -> void:
	player.max_hp = 100000
	player.hp = 100000
	stage.auto_spawn = true
	stage.cam_left = 2688.0
	player.position.x = 2800.0
	stage._lock_index = stage._locks.size() - 1
	stage._start_lock(stage._locks[stage._lock_index])
	await _frames(40)
	_check(is_instance_valid(stage.boss), "o chefe entra na última trava")
	stage.boss.take_hit(999, true, player)
	await _frames(150)
	_check(stage.cleared, "derrotar o Ferrugem conclui a fase")
	_check(stage.score >= 2000, "2.000 pontos pelo chefe mais bônus (pontos %d)" % stage.score)


func test_death_and_respawn() -> void:
	var enemy := _spawn(Vector2(200, 0))
	player.take_hit(150, true, enemy)
	await _frames(80)
	_check(player.state == Fighter.State.DEAD and player.lives == 2, "morreu e perdeu uma vida")
	await _frames(70)
	_check(player.state == Fighter.State.IDLE and player.hp == 100 and player.invuln > 0, "volta com vida cheia e piscando")


func test_combo_counter_and_bonus() -> void:
	var enemy := _tough(Vector2(22, 0))
	var bonuses := []
	player.combo_ended.connect(func(hits: int, bonus: int, dropped: bool) -> void: bonuses.append([hits, bonus, dropped]))
	for i in 3:
		player.input.press(&"attack")
		await _frames(12)
	await _frames(15)
	_check(player.combo_hits == 3, "o contador soma cada golpe (%d)" % player.combo_hits)
	_check(player.combo_bonus() == 28 * 3, "bônus = dano x golpes (%d)" % player.combo_bonus())
	await _frames(Player.COMBO_TIMEOUT_FRAMES + 20)
	_check(bonuses == [[3, 84, false]], "o combo termina sozinho e paga o bônus %s" % [bonuses])
	_check(stage.score == 84, "o bônus vira pontos (pontos %d)" % stage.score)
	_check(enemy.hp == 999 - 28, "e o dano foi o normal")


func test_combo_dropped_when_hit() -> void:
	var enemy := _tough(Vector2(22, 0))
	for i in 3:
		player.input.press(&"attack")
		await _frames(12)
	await _frames(10)
	player.take_hit(5, false, enemy)
	await _frames(Player.COMBO_TIMEOUT_FRAMES + 20)
	_check(player.combo_hits == 0 and stage.score == 0, "apanhar zera o combo e perde o bônus")


func test_launcher_and_juggle() -> void:
	var enemy := _tough(Vector2(22, 0))
	player.input.press(&"attack")
	await _frames(12)
	player.input.press(&"attack")
	await _frames(12)
	player.input.move = Vector2(0, -1)
	player.input.press(&"attack")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(20)
	_check(player.current_attack.get("name") == "lancador", "cima + 3º golpe = lançador")
	await _frames(10)
	_check(enemy.is_juggled() and enemy.height > 0.0, "o inimigo sobe e pode ser golpeado no ar")
	var hp_after_launch := enemy.hp
	await _frames(4)
	for i in 3:
		player.input.press(&"attack")
		await _frames(18)
	_check(enemy.hp < hp_after_launch, "golpes no ar acertam (vida %d -> %d)" % [hp_after_launch, enemy.hp])
	_check(player.combo_hits >= 5, "e somam no combo (%d golpes)" % player.combo_hits)
	await _frames(80)
	_check(enemy.height == 0.0 and not enemy.is_juggled(), "depois do limite ele cai de vez")


func test_flame_kick_sends_enemy_flying() -> void:
	var front := _spawn(Vector2(22, 0))
	var behind := _spawn(Vector2(90, 0))
	player.input.press(&"attack")
	await _frames(12)
	player.input.press(&"attack")
	await _frames(12)
	player.input.move = Vector2(1, 0)
	player.input.press(&"attack")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(20)
	_check(player.current_attack.get("name") == "chute_de_brasa", "frente + 3º golpe = chute de brasa")
	await _frames(60)
	_check(behind.hp == 18, "o chutado voa e derruba quem está atrás (vida %d)" % behind.hp)
	_check(player.combo_hits == 4, "acertar com o corpo voando conta no combo (%d)" % player.combo_hits)


func test_special_cancel() -> void:
	_tough(Vector2(22, 0))
	player.add_meter(60)
	player.input.press(&"attack")
	await _frames(8)
	player.input.press(&"special")
	await _until(func() -> bool: return player.current_attack.get("special", false), 12)
	_check(player.current_attack.get("special", false), "golpe que acertou cancela no especial")
	await _frames(int(player.current_attack["startup"]) + 4)
	_check(player.combo_hits == 2, "e o combo continua (%d golpes)" % player.combo_hits)


func test_armor_holds_against_knockdown() -> void:
	var tank := stage.spawn_enemy(BRUTAMONTES, player.position + Vector2(24, 0))
	tank.ai_enabled = false
	tank.take_hit(14, true, player)
	_check(tank.state != Fighter.State.KNOCKDOWN, "golpe que derruba gasta armadura em vez de derrubar")
	tank.take_hit(14, true, player)
	_check(tank.state != Fighter.State.KNOCKDOWN, "a 2ª armadura também segura")
	await _frames(8)
	tank.take_hit(14, true, player)
	_check(tank.state == Fighter.State.KNOCKDOWN, "sem armadura, cai")
	await _frames(200)
	# J, J, J de verdade: jab e direto gastam a armadura, o gancho derruba.
	var fresh := stage.spawn_enemy(BRUTAMONTES, player.position + Vector2(24, 0))
	fresh.ai_enabled = false
	tank.queue_free()
	await _frames(2)
	for i in 3:
		player.input.press(&"attack")
		await _frames(12)
	await _until(func() -> bool: return fresh.state == Fighter.State.KNOCKDOWN, 30)
	_check(fresh.state == Fighter.State.KNOCKDOWN, "jab, direto e gancho: cai só no 3º golpe")


func test_heavy_body_is_not_launched() -> void:
	var tank := stage.spawn_enemy(BRUTAMONTES, player.position + Vector2(24, 0))
	tank.ai_enabled = false
	tank.armor_hits = 0
	tank._armor_left = 0
	tank.take_hit(10, true, player, 240.0)
	await _frames(10)
	_check(not tank.is_juggled() and tank.height < 20.0, "o lançador não lança o Brutamontes (altura %.0f)" % tank.height)
	await _frames(120)
	tank.armor_hits = 0
	tank._armor_left = 0
	player.position = tank.position - Vector2(20, 0)
	player.facing = 1
	player.start_attack(Player.FLAME_KICK)
	await _frames(14)
	_check(tank.state != Fighter.State.THROWN, "nem o chute de brasa o manda voando")


func test_boss_phase_two_attacks_through_jabs() -> void:
	var boss: Boss = stage.spawn_enemy(FERRUGEM, player.position + Vector2(30, 0))
	boss.ai_enabled = false
	boss.take_hit(160, false, player)
	await _frames(30)
	_check(boss.phase == 2 and boss.state == Fighter.State.IDLE, "fase 2")
	boss.facing = -1
	boss.start_attack(Boss.STONE_PUNCH)
	await _frames(5)
	boss.take_hit(6, false, player)
	boss.take_hit(14, true, player)
	await _frames(1)
	_check(boss.state == Fighter.State.ATTACK, "na antecipação ele apanha mas não para o golpe")
	await _frames(40)
	boss.take_hit(6, false, player)
	_check(boss.state == Fighter.State.HURT, "fora da antecipação o jab ainda atordoa")


func test_juggle_limit_and_launcher_no_reset() -> void:
	var enemy := _tough(Vector2(30, 0))
	enemy.take_hit(10, true, player, 240.0)
	_check(enemy._juggle_left == Fighter.JUGGLE_HITS, "lançado: %d golpes no ar" % Fighter.JUGGLE_HITS)
	await _frames(8)
	enemy.take_hit(10, true, player, 240.0)
	_check(enemy._juggle_left == Fighter.JUGGLE_HITS - 1, "o lançador num alvo no ar não reinicia o contador (%d)" % enemy._juggle_left)
	for i in Fighter.JUGGLE_HITS - 1:
		await _frames(8)
		enemy.take_hit(6, false, player)
	await _frames(4)
	_check(enemy._juggle_left == 0 and not enemy.can_be_hit(),
		"depois de %d golpes no ar ele não pode mais ser atingido" % Fighter.JUGGLE_HITS)
	var hp := enemy.hp
	_check(not enemy.take_hit(6, false, player) and enemy.hp == hp, "o 4º golpe no ar não acerta")


func test_combo_ends_before_lone_enemy_gets_up() -> void:
	var enemy := _tough(Vector2(22, 0))
	for i in 3:
		player.input.press(&"attack")
		await _frames(12)
	await _until(func() -> bool: return player.combo_hits == 3, 30)
	_check(player.combo_hits == 3, "3 golpes no combo")
	while not enemy.can_be_hit():
		await physics_frame
	_check(player.combo_hits == 0, "o combo fecha antes de o inimigo sozinho poder apanhar de novo")


func test_getup_invulnerability() -> void:
	var enemy := _tough(Vector2(30, 0))
	enemy.take_hit(10, true, player)
	while enemy.state != Fighter.State.IDLE:
		await physics_frame
	_check(enemy.invuln > 0 and not enemy.take_hit(6, false, player), "ao levantar fica invencível")
	await _frames(Fighter.GETUP_INVULN_FRAMES)
	_check(enemy.take_hit(6, false, player), "depois de 20 quadros volta a apanhar")


func test_grab_special_without_resources_keeps_hold() -> void:
	var enemy := _spawn(Vector2(30, 0))
	player.input.move = Vector2(1, 0)
	await _frames(10)
	player.input.move = Vector2.ZERO
	_check(player.state == Fighter.State.GRAB, "agarrou")
	player.hp = 1
	player.input.press(&"special")
	await _frames(2)
	_check(player.state == Fighter.State.GRAB and enemy.state == Fighter.State.GRABBED,
		"sem medidor e com 1 de vida o especial não sai e o agarrão continua")


func test_throw_gets_full_meter_bonus() -> void:
	var enemy := _tough(Vector2(30, 0))
	player.add_meter(Player.METER_MAX)
	player.input.move = Vector2(1, 0)
	await _frames(10)
	player.input.press(&"attack")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(60)
	_check(enemy.hp == 999 - Fighter.THROW_DAMAGE - Player.FULL_METER_BONUS,
		"arremesso com medidor cheio tira 12 + 2 (vida %d)" % enemy.hp)


func test_all_characters_have_art() -> void:
	_check(Characters.LIST.size() == 7, "7 personagens no elenco")
	_check(Characters.index_of("frost_guardian") == 0 and Characters.get_data("frost_guardian")["id"] != "frost_guardian",
		"o Guardião de Gelo não é jogável")
	_check(player.character["id"] == Characters.DEFAULT_ID, "o jogo começa com o Cavaleiro de Fogo")
	var needed := ["idle", "run", "j_up", "j_down", "atk1", "atk2", "atk3", "air_atk", "sp_atk", "take_hit", "death", "defend", "roll"]
	for data: Dictionary in Characters.LIST:
		var id: String = data["id"]
		var missing := []
		for anim: String in needed:
			var real := Characters.resolve_anim(id, anim)
			var tex := Characters.texture(id, real)
			var meta := Characters.meta(id)
			var frames := int(meta["anims"][real]["frames"])
			var columns := int(meta["columns"])
			var expected := Vector2i(int(meta["frame_size"][0]) * mini(columns, frames),
				int(meta["frame_size"][1]) * ceili(float(frames) / columns))
			if tex == null or tex.get_size() != Vector2(expected) or tex.get_width() > 2048:
				missing.append(anim)
		_check(missing.is_empty(), "%s: todas as animações têm arte %s" % [id, missing])


func test_character_stats() -> void:
	player.set_character("crystal_mauler")
	_check(player.max_hp == 120 and player.hp == 120, "Cristal tem 120 de vida")
	var enemy := _tough(Vector2(22, 0))
	player.input.press(&"attack")
	await _frames(10)
	_check(enemy.hp == 999 - roundi(6 * 1.15), "e bate mais forte (vida %d)" % enemy.hp)
	await _frames(20)
	player.set_character("wind_hashashin")
	var start := player.position.x
	# Para a esquerda, longe do inimigo (andar contra ele seria agarrão).
	player.input.move = Vector2(-1, 0)
	await _frames(30)
	player.input.move = Vector2.ZERO
	var walked := start - player.position.x
	_check(absf(walked - 90.0 * 1.2 * 0.5) < 3.0, "Vento anda mais rápido (%.0f px em 0,5 s)" % walked)


func test_sprite_follows_state() -> void:
	_check(player.sprite != null and player.sprite.anim == "idle", "parado mostra a animação idle")
	player.input.move = Vector2(-1, 0)
	await _frames(3)
	_check(player.sprite.anim == "run" and player.sprite.scale.x < 0.0, "andando para a esquerda: run espelhado")
	player.input.move = Vector2.ZERO
	await _frames(2)
	var enemy := _tough(Vector2(-22, 0))
	player.input.press(&"attack")
	await _frames(4)
	_check(player.sprite.anim == "atk1", "jab usa o 1º ataque da arte")
	await _frames(20)
	enemy.ai_enabled = true
	player.take_hit(10, true, enemy)
	var down: int = player.character["down"]
	await _until(func() -> bool: return player.sprite.frame == down, 40)
	_check(player.state == Fighter.State.KNOCKDOWN and player.sprite.anim == "death"
		and player.sprite.frame == player.character["down"] and player.sprite.rotation == 0.0,
		"derrubado: quadro caído da morte, sem girar o desenho")


func test_reach_follows_art() -> void:
	# A espada do Cavaleiro de Fogo vai longe: o jab acerta a 40 px, onde o placeholder não chegava.
	var enemy := _tough(Vector2(40, 0))
	player.input.press(&"attack")
	await _frames(10)
	_check(enemy.hp < 999, "jab do Cavaleiro de Fogo acerta a 40 px (alcance %.0f)" % player.current_attack["far"])
	_check(player.current_attack["far"] <= Player.REACH_CAP, "mas o alcance tem teto de %.0f px" % Player.REACH_CAP)
	await _frames(30)
	player.set_character("crystal_mauler")
	player.input.press(&"attack")
	await _frames(4)
	var expected := clampf(player.sprite.reach_of("atk1"), 26.0, Player.REACH_CAP)
	_check(is_equal_approx(player.current_attack["far"], expected),
		"cada herói tem o alcance da própria arte (Cristal: %.0f)" % player.current_attack["far"])


## A arte anima por poses: nenhuma pose some antes de POSE_TICKS (nada de 60
## quadros de arte por segundo), o impacto cai no quadro ativo e a arte chega ao
## último quadro (o efeito desenhado no golpe termina).
func test_long_attack_art_plays_in_poses() -> void:
	_tough(Vector2(22, 0))
	for attack: Dictionary in [Player.COMBO[0], Player.COMBO[1], Player.COMBO[2]]:
		player.start_attack(attack)
		var anim: String = Player.ATTACK_ANIMS[attack["name"]]
		var count := player.sprite.frames_of(anim)
		var hit := mini(player.sprite.hit_frame_of(anim), count - 1)
		var frames := []
		var hit_on_active := true
		while player.state == Fighter.State.ATTACK and frames.size() < 120:
			await physics_frame
			if player.state != Fighter.State.ATTACK:
				break
			if player.state_frame == int(attack["startup"]) + 1:
				hit_on_active = hit_on_active and player.sprite.frame == hit
			frames.append(player.sprite.frame)
		var shortest := 999
		var run := 1
		for i in range(1, frames.size()):
			if frames[i] == frames[i - 1]:
				run += 1
			else:
				shortest = mini(shortest, run)
				run = 1
		_check(shortest >= CharacterSprite.POSE_TICKS,
			"%s: cada pose fica pelo menos %d ticks (%d)" % [attack["name"], CharacterSprite.POSE_TICKS, shortest])
		_check(hit_on_active, "%s: quadro de impacto da arte no 1º quadro ativo" % attack["name"])
		_check(frames.max() == count - 1, "%s: a arte chega ao último quadro (%d de %d)" % [attack["name"],
			frames.max(), count - 1])
		_check(_is_sorted(frames),
			"%s: a arte nunca volta para trás" % attack["name"])
		await _frames(30)


func _is_sorted(values: Array) -> bool:
	for i in range(1, values.size()):
		if values[i] < values[i - 1]:
			return false
	return true


func test_view_3d_mirrors_actors() -> void:
	var view: View3D = _main.get_node("View3D")
	_check(not stage.get_node("Actors").visible, "atores 2D escondidos (quem desenha é o 3D)")
	var enemy := _spawn(Vector2(60, 20))
	await _frames(2)
	var hero: Dictionary = view._proxies[player.get_instance_id()]
	var foe: Dictionary = view._proxies[enemy.get_instance_id()]
	_check(hero["root"].position.is_equal_approx(View3D.to_3d(player.position)), "herói no 3D na posição lógica")
	_check(foe["root"].position.x > hero["root"].position.x and foe["root"].position.z > hero["root"].position.z,
		"inimigo à direita e mais perto da câmera no 3D")
	_check(hero["sprite"].frame == player.sprite.frame, "billboard mostra o mesmo quadro do sprite")
	var enemy_id := enemy.get_instance_id()
	enemy.queue_free()
	await _frames(2)
	_check(not view._proxies.has(enemy_id), "proxy some junto com o inimigo")


func test_spawn_margin_grows_with_depth() -> void:
	_check(stage.offscreen_margin(Stage.FLOOR_TOP, 30.0) > stage.offscreen_margin(Stage.FLOOR_BOTTOM, 30.0),
		"fundo do chão nasce mais longe da borda (perspectiva)")
	_check(is_equal_approx(stage.offscreen_margin(Stage.FLOOR_BOTTOM, 30.0), 30.0), "frente do chão usa a folga normal")


func test_enemies_have_art() -> void:
	for data: EnemyData in [CAPANGA, FACA, BRUTAMONTES, FUNDEIRO, FERRUGEM]:
		var anims: Dictionary = Characters.meta(data.sprite_id)["anims"]
		_check(anims.has("idle") and anims.has("run") and anims.has("take_hit") and anims.has("death"),
			"%s tem arte (%s)" % [data.display_name, data.sprite_id])
	var enemy := _spawn(Vector2(30, 0))
	_check(enemy.sprite != null and enemy.sprite.anim == "idle", "inimigo começa na animação parada")
	enemy.take_hit(1, false, player)
	await _frames(2)
	_check(enemy.sprite.anim == "take_hit", "inimigo atingido mostra a animação de dano")
	var view: View3D = _main.get_node("View3D")
	_check(view._proxies[enemy.get_instance_id()]["kind"] == "hero", "inimigo com arte vira billboard no 3D")


func test_sound_bank() -> void:
	var bank: Node = load("res://scripts/sound_bank.gd").new()
	get_root().add_child(bank)
	for name in ["hit", "hit_heavy", "hurt", "jump", "break", "ko", "menu_ok", "special_fogo", "special_agua",
			"special_terra", "special_vento", "game_over", "clear"]:
		_check(bank.has(name), "efeito %s carregado" % name)
	_check(bank._sfx["hit"].size() == 3, "golpe tem 3 variações")
	for track in ["fase", "chefe", "titulo"]:
		_check(ResourceLoader.exists("res://assets/audio/music/%s.ogg" % track), "música %s existe" % track)
	bank.play("hit")
	bank.music("fase")
	_check(bank._music.stream != null and bank._music.stream.loop, "música da fase em loop")
	bank.queue_free()


func test_vfx() -> void:
	var view: View3D = _main.get_node("View3D")
	for element in ["Fogo", "Água", "Vento", "Folha", "Terra", "Cristal", "Metal"]:
		var effect := Player.special_effect(element)
		_check(view._vfx_meta.has(effect) and ResourceLoader.exists("res://assets/vfx/%s.png" % effect),
			"especial de %s tem efeito (%s)" % [element, effect])
	for name in ["hit", "hit_heavy", "dust", "stomp", "break", "coin", "heal"]:
		_check(view._vfx_meta.has(name), "efeito %s no vfx.json" % name)
	var special := player.special_attack()
	_check(special["startup"] == 24,
		"especial do Brasa sai no quadro de impacto da arte (preparo %d)" % special["startup"])
	var before := view.active_effects()
	var enemy := _spawn(Vector2(30, 0))
	enemy.take_hit(1, false, player)
	await _frames(1)
	_check(view.active_effects() > before, "golpe acerta e solta faísca")
	await _frames(90)
	_check(view.active_effects() == 0, "efeitos somem quando a animação acaba")


# --- Golpes próprios de cada herói (HeroMoves) ----------------------------------------

func _hero(id: String) -> void:
	player.set_character(id)
	await _frames(1)


func _labels() -> Array:
	var seen := []
	player.move_used.connect(func(label: String, _c: Color) -> void: seen.append(label))
	return seen


func _charge_and_release() -> void:
	player.input.attack_held = true
	player.input.press(&"attack")
	await _frames(HeroMoves.CHARGE_FRAMES + 10)
	player.input.attack_held = false
	await _frames(1)


func test_back_attack_turns_and_burns() -> void:
	var enemy := _spawn(Vector2(-24, 0))
	var seen := _labels()
	player.facing = 1
	player.input.move = Vector2(-1, 0)
	player.input.press(&"attack")
	await _frames(2)
	player.input.move = Vector2.ZERO
	_check(player.facing == -1 and player.current_attack.get("name") == "lamina_reversa", "trás + J vira e sai a Lâmina Reversa")
	await _frames(10)
	_check(enemy.hp == 20, "acerta quem estava atrás (vida %d)" % enemy.hp)
	_check(ElementStatus.is_burning(enemy), "a lâmina do Brasa deixa o inimigo queimando")
	await _frames(70)
	_check(enemy.hp == 14 and enemy.hp > 0, "a queimadura tira 2 por pulso (vida %d)" % enemy.hp)
	_check("Lâmina Reversa" in seen, "o nome do golpe vai para o HUD")


func test_back_turn_needs_direction_held() -> void:
	_tough(Vector2(-60, 0))
	player.input.move = Vector2(-1, 0)
	await _frames(2)
	player.input.move = Vector2.ZERO
	player.input.press(&"attack")
	await _frames(3)
	_check(player.current_attack.get("name") == "jab", "virar, soltar a direção e apertar J ainda é jab")


func test_charged_attack() -> void:
	var enemy := _tough(Vector2(26, 0))
	var seen := _labels()
	player.input.attack_held = true
	player.input.press(&"attack")
	await _frames(HeroMoves.CHARGE_FRAMES + 10)
	_check(player.is_charged(), "segurar J por meio segundo carrega")
	var hp_before := enemy.hp
	player.input.attack_held = false
	await _frames(3)
	_check(player.current_attack.get("name") == "espada_incandescente", "soltar J dispara a Espada Incandescente")
	await _frames(40)
	_check(hp_before - enemy.hp >= 18, "o carregado tira 18 (tirou %d)" % (hp_before - enemy.hp))
	_check(enemy.state in [Fighter.State.KNOCKDOWN, Fighter.State.GETUP], "e derruba")
	_check("Espada Incandescente" in seen, "o nome aparece")
	player.input.attack_held = true
	player.input.press(&"attack")
	await _frames(10)
	player.input.attack_held = false
	await _frames(20)
	_check(player.current_attack.get("name") != "espada_incandescente", "toque rápido não solta o carregado")


func test_special2_fireball() -> void:
	var near := _spawn(Vector2(90, 0))
	var other_lane := _spawn(Vector2(90, 20))
	player.add_meter(60)
	player.input.move = Vector2(0, 1)
	player.input.press(&"special")
	await _frames(1)
	player.input.move = Vector2.ZERO
	_check(player.meter == 30, "baixo + L gasta 30 do medidor (medidor %d)" % player.meter)
	await _frames(45)
	_check(near.hp == 16 and near.state in [Fighter.State.KNOCKDOWN, Fighter.State.GETUP], "a bola de fogo voa e acerta 14 e derruba (vida %d)" % near.hp)
	_check(other_lane.hp == 30, "não acerta quem está em outra faixa")
	_check(player.combo_hits == 1, "o acerto do projétil conta no combo")


func test_special2_costs_health_without_meter() -> void:
	player.input.move = Vector2(0, 1)
	player.input.press(&"special")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(40)
	_check(player.hp == 90, "sem medidor, o especial 2 custa 10 de vida (vida %d)" % player.hp)


func test_air_meteor_dive_and_impact() -> void:
	var a := _spawn(Vector2(40, 0))
	var b := _spawn(Vector2(60, 6))
	player.input.press(&"jump")
	await _frames(14)
	player.input.move = Vector2(0, 1)
	player.input.press(&"attack")
	await _frames(1)
	player.input.move = Vector2.ZERO
	_check(player.current_attack.get("name") == "meteoro", "no ar, baixo + J sai o Meteoro")
	await _until(func() -> bool: return player.height == 0.0, 60)
	await _frames(10)
	_check(a.hp < 30 and b.hp < 30, "o mergulho e a explosão na queda acertam os dois (vidas %d e %d)" % [a.hp, b.hp])
	await _frames(30)
	_check(player.state in [Fighter.State.IDLE, Fighter.State.WALK], "volta ao controle depois do impacto")


## Cada herói tem os quatro golpes novos, e todos acertam alguém (o contra-ataque
## do Metal e a cura da Água têm testes próprios).
func test_every_hero_has_four_new_moves() -> void:
	for c: Dictionary in Characters.LIST:
		var id: String = c["id"]
		for slot: String in HeroMoves.slots():
			var move := HeroMoves.get_move(id, slot)
			_check(move.has("label") and move.has("name"), "%s: %s tem nome" % [c["name"], slot])
			if move.get("counter", false):
				continue
			await _teardown()
			await _setup()
			await _hero(id)
			var seen := _labels()
			var offset := Vector2(24, 0)
			if slot == "special2":
				offset = Vector2(40, 0)
			elif slot == "air":
				offset = Vector2(40, 0)
			var enemy := _tough(offset)
			var hp_before := enemy.hp
			match slot:
				"back":
					enemy.position = player.position + Vector2(-offset.x, 0)
					player.facing = 1
					player.input.move = Vector2(-1, 0)
					player.input.press(&"attack")
					await _frames(1)
					player.input.move = Vector2.ZERO
				"charged":
					await _charge_and_release()
					hp_before = enemy.hp
				"special2":
					player.add_meter(100)
					player.input.move = Vector2(0, 1)
					player.input.press(&"special")
					await _frames(1)
					player.input.move = Vector2.ZERO
				"air":
					player.input.press(&"jump")
					await _frames(12)
					player.input.move = Vector2(0, 1)
					player.input.press(&"attack")
					await _frames(1)
					player.input.move = Vector2.ZERO
			await _frames(70)
			_check(move["label"] in seen, "%s: %s sai (%s)" % [c["name"], slot, move["label"]])
			_check(enemy.hp < hp_before, "%s: %s acerta (tirou %d)" % [c["name"], move["label"], hp_before - enemy.hp])


func test_wind_teleports_behind() -> void:
	await _hero("wind_hashashin")
	var enemy := _tough(Vector2(-60, 0))
	player.facing = 1
	player.input.move = Vector2(-1, 0)
	player.input.press(&"attack")
	await _frames(2)
	player.input.move = Vector2.ZERO
	_check(player.position.x < enemy.position.x and player.facing == 1, "Passo do Vento: surge atrás do inimigo, virado para ele")
	await _frames(20)
	_check(enemy.hp < 999, "e acerta pelas costas")


## O congelamento continua no jogo (Raízes da Folha); quem congela não é mais o Gelo jogável.
func test_freeze_holds_and_knockdown_shatters() -> void:
	var enemy := _spawn(Vector2(30, 0), true)
	enemy.max_hp = 200
	enemy.hp = 200
	ElementStatus.freeze(enemy, 70)
	await _frames(2)
	_check(ElementStatus.is_frozen(enemy), "inimigo congelado")
	var x := enemy.position.x
	var frame := enemy.state_frame
	await _frames(30)
	_check(enemy.position.x == x and enemy.state_frame == frame, "congelado não anda nem conta tempo")
	player.position.x = enemy.position.x - 26
	player.facing = 1
	enemy.take_hit(1, true, player)
	await _frames(2)
	_check(not ElementStatus.is_frozen(enemy), "golpe que derruba estilhaça o gelo")


## O Guardião de Gelo é inimigo: pesado, com armadura, soco que derruba, fraco a Fogo.
func test_ice_guardian_enemy() -> void:
	var data: EnemyData = Stage.ENEMIES["guardiao_gelo"]
	_check(data.sprite_id == "frost_guardian" and data.element == "Gelo", "Guardião de Gelo usa a arte do Frost Guardian")
	var appears := false
	for section: Dictionary in Stage.SECTIONS:
		for lock: Dictionary in section["locks"]:
			for wave: Array in lock["waves"]:
				appears = appears or wave.has("guardiao_gelo")
	_check(appears, "e aparece numa onda da fase")
	var guard := stage.spawn_enemy(data, player.position + Vector2(24, 0))
	guard.ai_enabled = false
	_check(guard.sprite != null and guard.sprite.character_id == "frost_guardian", "desenhado com a arte dele")
	_check(not guard.can_be_grabbed(), "não pode ser agarrado")
	player.set_character("wind_hashashin")
	guard.take_hit(5, false, player)
	guard.take_hit(5, false, player)
	await _frames(1)
	_check(guard.hp == 100 and guard.state != Fighter.State.HURT, "armadura nos 2 primeiros golpes (vida %d)" % guard.hp)
	guard.queue_free()
	await _frames(30)
	player.hp = player.max_hp
	var hp_before := player.hp
	var attacker := stage.spawn_enemy(data, player.position + Vector2(30, 0))
	var knocked := false
	for i in 500:
		await physics_frame
		if player.state == Fighter.State.KNOCKDOWN:
			knocked = true
			break
	_check(knocked and player.hp == hp_before - 14, "o soco tira 14 e derruba (vida %d)" % player.hp)
	_check(attacker.current_attack.get("name") == "soco", "foi o soco")
	attacker.queue_free()
	await _frames(2)
	player.set_character("fire_knight")
	var weak := stage.spawn_enemy(data, player.position + Vector2(200, 0))
	weak.ai_enabled = false
	weak.take_hit(10, false, player)
	_check(weak.hp == 110 - 15, "Fogo é a fraqueza dele (vida %d)" % weak.hp)
	player.set_character("water_priestess")
	weak.take_hit(10, false, player)
	_check(weak.hp == 95 - 7, "Água resiste (vida %d)" % weak.hp)


func test_leaf_roots_hold_enemies_far_away() -> void:
	await _hero("leaf_ranger")
	var far := _spawn(Vector2(120, 0), true)
	player.add_meter(50)
	player.input.move = Vector2(0, 1)
	player.input.press(&"special")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(20)
	_check(far.hp < 30 and ElementStatus.is_frozen(far), "Raízes prendem um inimigo a 120 px")


func test_metal_counter_stance() -> void:
	await _hero("metal_bladekeeper")
	var enemy := _tough(Vector2(-26, 0))
	player.facing = 1
	player.add_meter(50)
	player.input.move = Vector2(0, 1)
	player.input.press(&"special")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(6)
	var hp := player.hp
	var hit := player.take_hit(10, true, enemy)
	_check(not hit and player.hp == hp, "Postura de Aço: o golpe não entra")
	_check(player.current_attack.get("name") == "revide" and player.facing == -1, "e ela revida virada para quem bateu")
	await _frames(20)
	_check(enemy.hp == 999 - 24, "o revide tira 24 (vida %d)" % enemy.hp)
	await _frames(40)
	player.input.press(&"attack")
	await _frames(2)
	_check(player.take_hit(5, false, enemy), "fora da postura, apanha normal")


func test_earth_charged_has_armor() -> void:
	await _hero("ground_monk")
	var enemy := _tough(Vector2(26, 0))
	var far := _spawn(Vector2(120, 0))
	await _charge_and_release()
	await _frames(3)
	player.take_hit(5, true, enemy)
	_check(player.state == Fighter.State.ATTACK and player.current_attack.get("name") == "punho_sismico",
		"Punho Sísmico segura o tranco (armadura)")
	await _frames(60)
	_check(far.hp < 30, "o tremor corre pelo chão e acerta longe (vida %d)" % far.hp)


func test_water_heals_only_with_meter() -> void:
	await _hero("water_priestess")
	player.hp = 50
	player.input.move = Vector2(0, 1)
	player.input.press(&"special")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(30)
	_check(player.hp == 50, "sem medidor, a Fonte de Cura não sai (vida %d)" % player.hp)
	player.add_meter(40)
	player.input.move = Vector2(0, 1)
	player.input.press(&"special")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(30)
	_check(player.hp == 70 and player.meter == 0, "com 40 de medidor, cura 20 (vida %d)" % player.hp)


func test_crystal_shards_cover_three_lanes() -> void:
	await _hero("crystal_mauler")
	player.position.y = 168
	var up := _spawn(Vector2(80, -14))
	var mid := _spawn(Vector2(80, 0))
	var down := _spawn(Vector2(80, 14))
	player.add_meter(50)
	player.input.move = Vector2(0, 1)
	player.input.press(&"special")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(40)
	_check(up.hp < 30 and mid.hp < 30 and down.hp < 30, "Estilhaços acertam as três faixas (%d, %d, %d)" % [up.hp, mid.hp, down.hp])


func test_team_attack_fuses_elements() -> void:
	var partner: Player = load("res://scenes/player.tscn").instantiate()
	partner.stage = stage
	partner.input.scripted = true
	partner.position = player.position + Vector2(30, 0)
	stage.actors.add_child(partner)
	partner.set_character("wind_hashashin")
	var enemy := _tough(Vector2(15, 50))
	enemy.position = (player.position + partner.position) / 2.0 + Vector2(60, 0)
	var seen := _labels()
	player.add_meter(50)
	partner.add_meter(50)
	player.input.press(&"special")
	await _frames(5)
	partner.input.press(&"special")
	await _frames(2)
	_check("Tornado de Fogo" in seen, "Fogo + Vento juntos soltam o Tornado de Fogo")
	_check(enemy.hp <= 999 - 25, "a fusão acerta longe dos dois (vida %d)" % enemy.hp)
	await _frames(80)
	seen.clear()
	player.add_meter(50)
	partner.add_meter(50)
	player.input.press(&"special")
	await _frames(40)
	partner.input.press(&"special")
	await _frames(2)
	_check(seen.is_empty(), "especiais longe no tempo não fazem dupla")
	partner.queue_free()


# --- Inimigos, ritmo e chefe (frente de jogabilidade) ------------------------------

func test_elemental_weakness_and_resistance() -> void:
	# O Brasa é de Fogo: o Fundeiro (Folha) é fraco, o Brigão (Fogo) resiste.
	var leaf := stage.spawn_enemy(FUNDEIRO, player.position + Vector2(200, 0))
	leaf.ai_enabled = false
	leaf.take_hit(10, false, player)
	_check(leaf.hp == 20 - 15, "fraqueza: 10 de dano vira 15 (vida %d)" % leaf.hp)
	var fire := stage.spawn_enemy(BRIGAO, player.position + Vector2(-200, 0))
	fire.ai_enabled = false
	fire.take_hit(10, false, player)
	_check(fire.hp == 36 - 7, "resistência: 10 vira 7 (vida %d)" % fire.hp)
	var plain := _spawn(Vector2(0, 30))
	plain.take_hit(10, false, player)
	_check(plain.hp == 20, "capanga é neutro (vida %d)" % plain.hp)
	plain.take_hit(5, false, plain)
	_check(plain.hp == 15, "dano que não vem de herói não tem elemento")
	player.set_character("water_priestess")
	fire.take_hit(10, false, player)
	_check(fire.hp == 29 - 15, "a Água acerta a fraqueza do Brigão (vida %d)" % fire.hp)


func test_weakness_knockdown_breaks_armor() -> void:
	player.set_character("water_priestess")
	var tank := stage.spawn_enemy(BRUTAMONTES, player.position + Vector2(200, 0))
	tank.ai_enabled = false
	tank.take_hit(10, true, player)
	await _frames(1)
	_check(tank.state == Fighter.State.KNOCKDOWN, "golpe que derruba da fraqueza (Água) quebra a armadura do Brutamontes")
	var tank2 := stage.spawn_enemy(BRUTAMONTES, player.position + Vector2(-200, 0))
	tank2.ai_enabled = false
	player.set_character("fire_knight")
	tank2.take_hit(10, true, player)
	await _frames(1)
	_check(tank2.state != Fighter.State.KNOCKDOWN, "sem fraqueza a armadura segura")


func test_shield_blocks_front_hits() -> void:
	var guard := stage.spawn_enemy(ESCUDEIRO, player.position + Vector2(22, 0))
	guard.ai_enabled = false
	guard.facing = -1
	await _frames(2)
	player.facing = 1
	player.input.press(&"attack")
	await _frames(20)
	_check(guard.hp == 45, "o Escudeiro segura o jab de frente (vida %d)" % guard.hp)
	_check(player.combo_hits == 0 and player.meter == 0, "bloqueio não conta combo nem medidor")
	guard.facing = 1
	player.input.press(&"attack")
	await _frames(20)
	_check(guard.hp < 45, "pelas costas o golpe entra (vida %d)" % guard.hp)
	var before := guard.hp
	guard.facing = -1
	guard.enter_state(Fighter.State.IDLE)
	await _frames(20)
	guard.take_hit(14, true, player)
	_check(guard.hp < before and guard.state == Fighter.State.KNOCKDOWN, "golpe que derruba quebra a guarda")


func test_shield_falls_to_jump_kick_and_grab() -> void:
	var guard := stage.spawn_enemy(ESCUDEIRO, player.position + Vector2(40, 0))
	guard.ai_enabled = false
	guard.facing = -1
	player.input.move = Vector2(1, 0)
	player.input.press(&"jump")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(4)
	player.input.press(&"attack")
	await _frames(60)
	_check(guard.hp == 35, "o chute aéreo passa por cima do escudo (vida %d)" % guard.hp)
	await _frames(60)
	guard.position = player.position + Vector2(30, 0)
	guard.facing = -1
	guard.enter_state(Fighter.State.IDLE)
	player.facing = 1
	player.input.move = Vector2(1, 0)
	await _until(func() -> bool: return player.state == Fighter.State.GRAB, 40)
	player.input.move = Vector2.ZERO
	_check(player.state == Fighter.State.GRAB, "o Escudeiro pode ser agarrado")


func test_shield_counters_after_blocks() -> void:
	var guard := stage.spawn_enemy(ESCUDEIRO, player.position + Vector2(22, 0))
	guard.ai_enabled = false
	guard.facing = -1
	await _frames(2)
	for i in 3:
		guard.take_hit(6, false, player)
	_check(guard.state == Fighter.State.ATTACK and guard.current_attack.get("name") == "escudada",
		"depois de 3 bloqueios revida com o escudo")
	await _until(func() -> bool: return player.state == Fighter.State.KNOCKDOWN, 30)
	_check(player.hp == 100 - ESCUDEIRO.bash_damage, "a escudada tira %d e derruba (vida %d)" % [ESCUDEIRO.bash_damage, player.hp])


func test_bomber_lobs_at_player_position() -> void:
	var bomber := stage.spawn_enemy(PIROMANTE, player.position + Vector2(110, 30))
	var thrown: Lob = null
	for i in 300:
		await physics_frame
		for node in stage.actors.get_children():
			if node is Lob:
				thrown = node
		if thrown:
			break
	_check(thrown != null, "o Piromante joga bomba de outra faixa (não precisa alinhar)")
	if thrown == null:
		return
	_check(thrown.target.distance_to(player.position) < 2.0, "a bomba mira onde o jogador está")
	var view: View3D = _main.get_node("View3D")
	await _frames(2)
	_check(view._proxies[thrown.get_instance_id()]["marker"].visible, "círculo de alvo no chão")
	bomber.ai_enabled = false
	for i in 80:
		if not is_instance_valid(thrown):
			break
		await physics_frame
	await _frames(2)
	_check(player.hp == 100 - PIROMANTE.bomb_damage and player.state == Fighter.State.KNOCKDOWN,
		"parado no círculo: %d de dano e cai (vida %d)" % [PIROMANTE.bomb_damage, player.hp])
	await _frames(80)
	var hp := player.hp
	var dodge := stage.spawn_lob(bomber, bomber.position, player.position, 12, 22.0, 40)
	player.input.move = Vector2(0, -1)
	await _frames(45)
	player.input.move = Vector2.ZERO
	_check(player.hp == hp and not is_instance_valid(dodge), "saindo do círculo não leva dano")


func test_bomb_hurts_enemies_too() -> void:
	var enemy := _spawn(Vector2(0, 40))
	stage.spawn_lob(null, player.position + Vector2(80, 40), enemy.position, 12, 22.0, 20, "bomba")
	await _frames(22)
	_check(enemy.hp == 18 and enemy.state == Fighter.State.KNOCKDOWN, "a bomba derruba inimigo no círculo (vida %d)" % enemy.hp)
	var other := _spawn(Vector2(0, -40))
	stage.spawn_lob(null, player.position + Vector2(80, -40), other.position, 14, 18.0, 20, "pedra")
	await _frames(22)
	_check(other.hp == 30, "a pedra do chefe só acerta o jogador")


func test_explosive_barrel_and_chain() -> void:
	var barrel := stage._spawn_breakable({"kind": "barril", "x": player.position.x + 22.0, "y": player.position.y, "item": ""})
	var far := stage._spawn_breakable({"kind": "barril", "x": player.position.x + 62.0, "y": player.position.y, "item": ""})
	var enemy := _spawn(Vector2(50, 10))
	await _frames(2)
	player.input.press(&"attack")
	await _frames(10)
	_check(barrel.is_lit() and barrel.state != Fighter.State.DEAD, "o golpe acende o pavio do barril")
	player.input.move = Vector2(-1, 0)
	await _frames(30)
	player.input.move = Vector2.ZERO
	await _until(func() -> bool: return barrel.state == Fighter.State.DEAD, Breakable.FUSE_FRAMES)
	_check(barrel.state == Fighter.State.DEAD, "o barril explode")
	_check(enemy.hp == 30 - Breakable.BARREL_DAMAGE, "a explosão acerta o inimigo perto (vida %d)" % enemy.hp)
	_check(player.hp == 100, "quem se afastou não leva dano")
	_check(is_instance_valid(far) and far.is_lit(), "a explosão acende o barril vizinho (reação em cadeia)")


func test_crate_takes_two_hits_and_orb_fills_meter() -> void:
	var crate := stage._spawn_breakable({"kind": "caixa", "x": player.position.x + 24.0, "y": player.position.y, "item": "orbe"})
	await _frames(2)
	crate.take_hit(1, false, player)
	_check(crate.state != Fighter.State.DEAD and crate.wobble > 0, "a caixa balança no primeiro golpe")
	crate.take_hit(1, false, player)
	_check(crate.state == Fighter.State.DEAD, "e quebra no segundo")
	await _frames(2)
	player.input.move = Vector2(1, 0)
	await _frames(20)
	player.input.move = Vector2.ZERO
	_check(player.meter == Item.METER["orbe"], "o orbe enche o medidor (medidor %d)" % player.meter)


func test_enemy_dodges_out_of_lane() -> void:
	var data: EnemyData = CAPANGA.duplicate()
	data.dodge_chance = 1.0
	var enemy := stage.spawn_enemy(data, player.position + Vector2(40, 0))
	await _frames(2)
	enemy._cooldown = 999
	var y := enemy.position.y
	player.facing = 1
	player.input.press(&"attack")
	await _frames(Enemy.DODGE_FRAMES)
	_check(enemy.hp == 30, "e o jab passa raspando (vida %d)" % enemy.hp)
	_check(absf(enemy.position.y - y) > 10.0, "com o golpe vindo ele sai da faixa (%.0f px)" % absf(enemy.position.y - y))


func test_brawler_chains_punches() -> void:
	player.max_hp = 1000
	player.hp = 1000
	var brawler := stage.spawn_enemy(BRIGAO, player.position + Vector2(20, 0))
	var attacks := 0
	var was := false
	for i in 300:
		await physics_frame
		var now := brawler.state == Fighter.State.ATTACK and brawler.state_frame == 1
		if now:
			attacks += 1
		if attacks >= 2:
			break
	await _frames(20)
	_check(player.hp == 1000 - BRIGAO.attack_damage * 2, "o Brigão emenda 2 socos (vida %d)" % player.hp)


func test_enemy_drops_item() -> void:
	var data: EnemyData = CAPANGA.duplicate()
	data.drop = "frango"
	data.drop_chance = 1.0
	var enemy := stage.spawn_enemy(data, player.position + Vector2(60, 0))
	enemy.ai_enabled = false
	enemy.take_hit(999, true, player)
	await _frames(90)
	_check(stage._items.size() == 1 and stage._items[0].kind == "frango", "inimigo derrotado solta o item")


func test_wave_spawns_staggered_and_overlap() -> void:
	player.max_hp = 100000
	player.hp = 100000
	stage.auto_spawn = true
	stage._start_lock({"x": stage.cam_left, "overlap": 1, "waves": [["capanga", "capanga", "capanga", "capanga"], ["faca"]]})
	stage.locked = true
	await _frames(22)
	_check(stage.enemies().size() == 2, "os 2 primeiros entram juntos (tem %d)" % stage.enemies().size())
	await _frames(Stage.SPAWN_STAGGER + 2)
	_check(stage.enemies().size() == 3, "o resto vem em fila (tem %d)" % stage.enemies().size())
	await _frames(Stage.SPAWN_STAGGER + 2)
	for enemy: Enemy in stage.enemies():
		enemy.ai_enabled = false
	var list := stage.enemies()
	for i in 3:
		list[i].take_hit(999, true, player)
	await _frames(Stage.NEXT_WAVE_DELAY + 80)
	_check(stage.wave == 2, "com 1 sobrando a próxima onda já entra (onda %d)" % stage.wave)


func test_ambush_while_scrolling() -> void:
	player.max_hp = 100000
	player.hp = 100000
	stage.auto_spawn = true
	player.input.move = Vector2(1, 0)
	for i in 900:
		await physics_frame
		if stage.locked:
			stage._pending_waves.clear()
			for enemy: Enemy in stage.enemies():
				enemy.take_hit(999, true, player)
		if stage.cam_left >= 520.0 and not stage.locked:
			break
	await _frames(2)
	var names := []
	for enemy: Enemy in stage.enemies():
		names.append(enemy.data.display_name)
	_check(not stage.locked and names.has("Faca"), "emboscada da Faca no meio do scroll (%s)" % [names])


func test_last_enemy_enrages() -> void:
	stage.auto_spawn = true
	stage.locked = true
	stage._lock_index = 0
	var a := _spawn(Vector2(120, 0), true)
	var b := _spawn(Vector2(-120, 0), true)
	await _frames(2)
	_check(not a.enraged and not b.enraged, "com 2 na tela ninguém se enfurece")
	b.take_hit(999, true, player)
	await _frames(90)
	_check(a.enraged, "o último inimigo parte para cima")


func test_boss_throws_rock() -> void:
	var boss: Boss = stage.spawn_enemy(FERRUGEM, player.position + Vector2(140, 30))
	var rock: Lob = null
	for i in 200:
		await physics_frame
		for node in stage.actors.get_children():
			if node is Lob:
				rock = node
		if rock:
			break
	_check(rock != null and rock.look == "pedra", "de longe e fora da faixa o Ferrugem arremessa pedra")


func test_boss_leap_is_untouchable_and_lands_on_target() -> void:
	var boss: Boss = stage.spawn_enemy(FERRUGEM, player.position + Vector2(100, 0))
	boss.ai_enabled = false
	boss.take_hit(160, false, player)
	await _frames(30)
	boss.start_attack(Boss.LEAP)
	await _frames(Boss.LEAP["startup"] + 10)
	_check(boss.height > 20.0 and not boss.can_be_hit(), "no ar o chefe não pode ser atingido")
	_check(not boss.ground_marker().is_empty(), "o salto marca o ponto de queda")
	var target: Vector2 = boss.ground_marker()["at"]
	await _frames(Boss.LEAP["active"])
	_check(boss.position.distance_to(target) < 2.0 and boss.height == 0.0, "cai no ponto marcado")
	_check(player.state == Fighter.State.KNOCKDOWN and player.hp == 100 - Boss.LEAP_DAMAGE,
		"quem ficou no círculo cai (vida %d)" % player.hp)


func test_boss_phase_three_fury() -> void:
	var boss: Boss = stage.spawn_enemy(FERRUGEM, player.position + Vector2(120, 0))
	boss.ai_enabled = false
	boss.take_hit(160, false, player)
	await _frames(10)
	boss.take_hit(80, false, player)
	await _frames(2)
	_check(boss.phase == 3, "abaixo de 25%% entra na fúria (fase %d)" % boss.phase)
	var names := []
	for enemy: Enemy in stage.enemies():
		names.append(enemy.data.display_name)
	_check(names.has("Capanga Brigão") and names.has("Capanga"), "chama um capanga e um brigão (%s)" % [names])
	boss.position = player.position + Vector2(30, 0)
	boss.facing = -1
	boss.enter_state(Fighter.State.IDLE)
	boss.start_attack(Boss.STONE_PUNCH)
	await _until(func() -> bool: return boss.current_attack.get("name") != "soco_de_pedra", 90)
	_check(boss.state == Fighter.State.ATTACK and boss.current_attack.get("name") == "pisada", "na fúria o soco emenda na pisada")


func test_new_enemies_have_art() -> void:
	for data: EnemyData in [PIROMANTE, ESCUDEIRO, BRIGAO]:
		var anims: Dictionary = Characters.meta(data.sprite_id)["anims"]
		_check(anims.has(data.attack_anim) and anims.has("take_hit") and anims.has("death"),
			"%s tem arte (%s)" % [data.display_name, data.sprite_id])
	_check(Characters.meta(ESCUDEIRO.sprite_id)["anims"].has("defend"), "Escudeiro tem a pose de defesa")
	for name: String in Stage.ENEMIES:
		var data: EnemyData = Stage.ENEMIES[name]
		for element in Array(data.weak_to) + Array(data.resists):
			var known := false
			for hero: Dictionary in Characters.LIST:
				known = known or hero["element"] == element
			_check(known, "%s: elemento %s existe no elenco" % [data.display_name, element])


# --- Infra -------------------------------------------------------------------------

func _setup() -> void:
	seed(1234)
	_main = MAIN.instantiate()
	stage = _main.get_node("Stage")
	stage.auto_spawn = false
	root.add_child(_main)
	player = stage.player
	player.input.scripted = true
	player.position = Vector2(150, 168)
	await _frames(2)


func _teardown() -> void:
	_main.queue_free()
	await _frames(2)


func _spawn(offset: Vector2, ai := false) -> Enemy:
	var enemy := stage.spawn_enemy(CAPANGA, player.position + offset)
	enemy.ai_enabled = ai
	return enemy


func _tough(offset: Vector2) -> Enemy:
	var enemy := _spawn(offset)
	enemy.max_hp = 999
	enemy.hp = 999
	return enemy


func _kill_all() -> void:
	for enemy: Enemy in stage.enemies():
		enemy.take_hit(999, true, player)


## Espera até a condição valer (ou até `limit` quadros), para o teste não
## depender da duração exata dos golpes.
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


# --- Sensação do combate e combos ---------------------------------------------------

## Golpe leve congela pouco, golpe que fecha o combo congela mais.
func test_hitstop_by_attack_weight() -> void:
	var enemy := _tough(Vector2(22, 0))
	var stops := []
	for i in 3:
		player.input.press(&"attack")
		await _until(func() -> bool: return enemy.hitstop > 0, 20)
		stops.append(enemy.hitstop)
		await _frames(12)
	_check(stops[0] <= 3 and stops[2] >= 7, "jab congela %d quadros, gancho %d" % [stops[0], stops[2]])
	_check(stops[1] > stops[0], "direto congela mais que o jab (%d)" % stops[1])


## Golpe que acertou emenda o próximo logo depois do quadro ativo.
func test_hit_confirm_cancel() -> void:
	_tough(Vector2(22, 0))
	player.input.press(&"attack")
	await _frames(2)
	player.input.press(&"attack")
	var frames := 0
	while player.current_attack.get("name") != "direto" and frames < 30:
		frames += 1
		await physics_frame
	var jab: Dictionary = Player.COMBO[0]
	var full := int(jab["startup"]) + int(jab["active"]) + int(jab["recovery"])
	_check(player.current_attack.get("name") == "direto", "J apertado cedo vira direto")
	_check(frames < full, "o direto sai antes da recuperação do jab acabar (%d quadros, jab inteiro %d + hit stop)" % [frames, full])
	await _frames(20)
	_check(player.combo_event.get_connections().size() >= 1, "HUD ouve os destaques do combo")


## Lançador, K cancela num pulo e J, J no ar continuam o combo.
func test_jump_cancel_and_air_combo() -> void:
	var enemy := _tough(Vector2(22, 0))
	var events := []
	player.combo_event.connect(func(text: String) -> void: events.append(text))
	await _launch_combo()
	_check(enemy.is_juggled(), "lançou")
	player.input.press(&"jump")
	await _until(func() -> bool: return player.state == Fighter.State.JUMP, 20)
	_check(player.state == Fighter.State.JUMP, "K cancela o lançador num pulo")
	var before := player.combo_hits
	for i in 3:
		await _frames(3)
		player.input.press(&"attack")
		await _until(func() -> bool: return player.combo_hits > before + i, 16)
	_check(player.combo_hits >= before + 2, "golpes no ar emendam (%d -> %d)" % [before, player.combo_hits])
	_check("AÉREO" in events and "CANCEL" in events, "o HUD recebe AÉREO e CANCEL %s" % [events])
	await _frames(120)
	_check(player.state != Fighter.State.JUMP, "volta ao chão")


## O pisão crava o inimigo no chão; ele quica uma vez e pode apanhar de novo.
func test_air_spike_ground_bounce() -> void:
	var enemy := _tough(Vector2(26, 0))
	enemy.take_hit(10, true, player, 240.0)
	await _frames(6)
	player.facing = 1
	player.state = Fighter.State.JUMP
	player.height = enemy.height
	enemy.take_hit(11, true, player)
	var hp := enemy.hp
	# Simula o pisão direto (o mesmo dicionário que o herói usa).
	player.current_attack = Player.AIR_SPIKE
	enemy.take_hit(11, true, player)
	await _until(func() -> bool: return enemy._bounced, 40)
	_check(enemy._bounced and enemy.is_juggled(), "quicou e pode ser golpeado (aguenta %d)" % enemy._juggle_left)
	_check(enemy.hp < hp, "o pisão tira vida")
	await _frames(6)
	_check(enemy.height > 0.0, "sobe de novo depois do quique (altura %.0f)" % enemy.height)
	player.current_attack = Player.AIR_SPIKE
	await _frames(2)
	await _until(func() -> bool: return enemy.height == 0.0, 120)
	enemy.take_hit(11, true, player)
	await _frames(40)
	_check(enemy.height == 0.0 or not enemy._bounce_pending, "só quica uma vez por voo")
	player.state = Fighter.State.IDLE
	player.height = 0.0
	player.current_attack = {}


## Acertar quem está na antecipação do golpe dá CONTRA!: mais dano e hit stop.
func test_counter_hit() -> void:
	var enemy := _spawn(Vector2(22, 0))
	enemy.facing = -1
	enemy.start_attack({"name": "soco", "startup": 30, "active": 3, "recovery": 10, "damage": 5,
		"near": 0.0, "far": 20.0})
	player.input.press(&"attack")
	await _until(func() -> bool: return enemy.hp < 30, 20)
	_check(enemy.last_hit_counter, "golpe na antecipação é contra-ataque")
	_check(enemy.hp == 30 - 9, "contra-ataque tira 50%% a mais (jab 6 -> 9, vida %d)" % enemy.hp)
	await _frames(30)
	player.input.press(&"attack")
	await _until(func() -> bool: return enemy.hp < 21, 20)
	_check(not enemy.last_hit_counter and enemy.hp == 15, "fora da antecipação o jab é normal (vida %d)" % enemy.hp)


## Apanhar empurra o alvo um pouco, freando (não teleporta 3 px).
func test_hurt_push_slides() -> void:
	var enemy := _tough(Vector2(22, 0))
	var x0 := enemy.position.x
	player.input.press(&"attack")
	await _until(func() -> bool: return enemy.state == Fighter.State.HURT, 20)
	var right_after := enemy.position.x - x0
	await _frames(Fighter.HITSTUN_FRAMES)
	var total := enemy.position.x - x0
	_check(right_after < 1.0, "no hit stop ainda não andou (%.1f)" % right_after)
	_check(total > 2.0 and total < 12.0, "desliza para trás e para (%.1f px)" % total)


func test_damage_proration() -> void:
	_check(is_equal_approx(player.proration(), 1.0), "começo do combo: dano cheio")
	player.combo_hits = 10
	var p10 := player.proration()
	player.combo_hits = 40
	var p40 := player.proration()
	player.combo_hits = 0
	_check(p10 < 1.0 and p10 > Player.PRORATION_MIN, "no 11º golpe o dano cai (%.0f%%)" % (p10 * 100.0))
	_check(is_equal_approx(p40, Player.PRORATION_MIN), "nunca abaixo de %.0f%%" % (Player.PRORATION_MIN * 100.0))


## Variar, cancelar e acertar no ar sobe a nota; a nota multiplica o bônus.
func test_style_rank_and_bonus() -> void:
	_tough(Vector2(22, 0))
	_check(player.combo_rank() == "D", "começa em D")
	player._count_hit(10, "jab", [])
	player._count_hit(10, "jab", [])
	var repeated := player.combo_style
	player._count_hit(10, "jab", [])
	_check(is_equal_approx(player.combo_style - repeated, 0.5), "repetir o mesmo golpe vale metade")
	for i in 8:
		player._count_hit(10, "golpe_%d" % i, ["AÉREO", "CANCEL"])
	_check(player.combo_rank() in ["A", "S", "SS"], "combo variado com aéreo e cancelamento chega em A ou mais (%s)" % player.combo_rank())
	var plain := 110 * 11
	_check(player.combo_bonus() > plain, "a nota multiplica o bônus (%d > %d)" % [player.combo_bonus(), plain])
	player._end_combo(true)
	_check(player.combo_style == 0.0 and player.combo_rank() == "D", "combo perdido zera a nota")


## Golpe que derruba o último inimigo: câmera lenta curta e volta ao normal.
func test_finishing_blow_slow_motion() -> void:
	var enemy := _spawn(Vector2(22, 0))
	enemy.hp = 4
	player.input.press(&"attack")
	await _until(func() -> bool: return enemy.hp == 0, 20)
	_check(Engine.time_scale < 1.0, "último inimigo derrubado: câmera lenta (%.2f)" % Engine.time_scale)
	await create_timer(Player.KO_SLOWMO_SECONDS + 0.2, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 1.0), "e o tempo volta ao normal")
	var a := _spawn(Vector2(22, 0))
	var b := _spawn(Vector2(80, 0))
	a.hp = 4
	await _frames(20)
	player.input.press(&"attack")
	await _until(func() -> bool: return a.hp == 0, 20)
	_check(is_equal_approx(Engine.time_scale, 1.0), "com outro inimigo de pé não tem câmera lenta")
	b.queue_free()


func test_damage_popups() -> void:
	var enemy := _spawn(Vector2(22, 0))
	var texts := []
	stage.popup_spawned.connect(func(text: String, _at: Vector2, _lift: float, _color: Color) -> void: texts.append(text))
	player.input.press(&"attack")
	await _until(func() -> bool: return enemy.hp < 30, 20)
	_check("6" in texts, "o dano aparece subindo do inimigo %s" % [texts])
	var view: View3D = _main.get_node("View3D")
	await process_frame
	_check(view._popups.size() >= 1, "o View3D desenha o número")


func _launch_combo() -> void:
	player.input.press(&"attack")
	await _frames(12)
	player.input.press(&"attack")
	await _frames(12)
	player.input.move = Vector2(0, -1)
	player.input.press(&"attack")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _until(func() -> bool: return player._combo_connected and player.current_attack.get("name") == "lancador", 30)

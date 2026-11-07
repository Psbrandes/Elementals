extends SceneTree
## Testes da movimentação (scripts/player_movement.gd), no mesmo esquema do
## test_runner: o jogo de verdade, sem janela, apertando botões pelo PlayerInput.
##   godot --headless --path . --fixed-fps 60 --script res://tests/test_movement.gd

const MAIN := preload("res://scenes/main.tscn")
const CAPANGA := preload("res://data/enemies/capanga.tres")

var stage: Stage
var player: Player
var _main: Node
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tests := [
		test_walk_accelerates_and_stops,
		test_double_tap_runs,
		test_run_skids_and_turns,
		test_run_attack_is_dash,
		test_run_does_not_grab,
		test_roll_backwards_with_invulnerability,
		test_roll_in_direction,
		test_sidestep_changes_lane,
		test_dodge_cooldown,
		test_roll_cancel_into_attack,
		test_dodge_input_action,
		test_short_and_full_jump,
		test_air_control,
		test_run_jump_goes_farther,
		test_keep_running_after_run_jump,
		test_vault_over_grabbed_enemy,
		test_back_grab_suplex,
		test_front_throw_unchanged,
		test_hit_cancels_run_and_dodge,
		test_sprite_for_moves,
	]
	for test: Callable in tests:
		print("\n%s" % test.get_method())
		await _setup()
		await test.call()
		await _teardown()
	print("\n%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- Andar e correr ----------------------------------------------------------------

func test_walk_accelerates_and_stops() -> void:
	var start := player.position.x
	player.input.move = Vector2(1, 0)
	await _frames(1)
	var first := player.position.x - start
	_check(first > 0.0 and first < 1.5, "primeiro quadro ainda acelerando (%.2f px)" % first)
	await _frames(29)
	var walked := player.position.x - start
	_check(absf(walked - 45.0) < 2.0, "em meio segundo chega aos 90 px/s (%.1f px)" % walked)
	player.input.move = Vector2.ZERO
	var at_release := player.position.x
	await _frames(10)
	var slide := player.position.x - at_release
	_check(slide > 0.5 and slide < 4.0, "solta e para em poucos quadros (%.1f px)" % slide)
	_check(player.state == Fighter.State.IDLE, "parado volta a idle")


func test_double_tap_runs() -> void:
	await _double_tap(1)
	_check(player.movement.running, "frente, frente e segura: corre")
	var start := player.position.x
	await _frames(30)
	var ran := player.position.x - start
	var expected := 90.0 * PlayerMovement.RUN_MULT * 0.5
	_check(ran > expected * 0.9 and ran <= expected + 1.0, "corre a %.0f px/s (%.1f px em 0,5 s)" % [expected * 2.0, ran])
	var y := player.position.y
	player.input.move = Vector2(1, 1)
	await _frames(30)
	var dy := player.position.y - y
	_check(dy > 10.0 and dy < 60.0 * 0.5 * PlayerMovement.RUN_DEPTH_MULT + 1.0,
		"correndo, a profundidade anda menos (%.1f px)" % dy)
	_check(player.movement.running, "diagonal na direção da corrida continua correndo")


func test_run_skids_and_turns() -> void:
	await _double_tap(1)
	await _frames(20)
	player.input.move = Vector2.ZERO
	await _frames(1)
	_check(not player.movement.running and player.movement.skid > 0, "soltou: derrapa")
	var at := player.position.x
	await _frames(20)
	var slid := player.position.x - at
	_check(slid > 3.0 and slid < 25.0, "a derrapagem anda um pouco (%.1f px)" % slid)
	_check(player.velocity == Vector2.ZERO, "e para")
	await _double_tap(1)
	player.input.move = Vector2(-1, 0)
	await _frames(4)
	_check(not player.movement.running and player.facing == 1, "virar acaba a corrida (derrapa olhando para a frente)")
	await _frames(PlayerMovement.SKID_FRAMES + 6)
	_check(player.facing == -1 and player.velocity.x < 0.0, "depois da derrapagem anda para o outro lado")


func test_run_attack_is_dash() -> void:
	var enemy := _spawn(Vector2(110, 0))
	await _double_tap(1)
	await _frames(25)
	player.input.press(&"attack")
	await _frames(2)
	_check(player.current_attack.get("name") == "investida", "correndo + ataque: investida")
	_check(not player.movement.running, "o golpe para a corrida")
	await _frames(40)
	_check(enemy.hp == 18, "a investida acerta (vida %d)" % enemy.hp)


func test_run_does_not_grab() -> void:
	var enemy := _spawn(Vector2(70, 0))
	await _double_tap(1)
	await _frames(20)
	_check(player.state != Fighter.State.GRAB and enemy.state != Fighter.State.GRABBED, "correndo passa sem agarrar")


# --- Esquiva -------------------------------------------------------------------

func test_roll_backwards_with_invulnerability() -> void:
	var enemy := _spawn(Vector2(30, 0))
	var start := player.position.x
	player.input.press(&"dodge")
	await _frames(3)
	_check(player.movement.dodge == PlayerMovement.Dodge.ROLL, "esquiva sem direção: rolamento")
	_check(not player.can_be_hit(), "invencível no começo do rolamento")
	_check(not player.take_hit(10, true, enemy) and player.hp == player.max_hp, "golpe atravessa sem dano")
	_check(player.facing == 1, "rola para trás sem virar de costas")
	await _frames(PlayerMovement.ROLL_FRAMES)
	var moved := start - player.position.x
	_check(moved > 35.0 and moved < 70.0, "recua rolando (%.1f px)" % moved)
	_check(not player.movement.is_dodging() and player.can_be_hit(), "no fim volta a poder apanhar")


func test_roll_in_direction() -> void:
	var start := player.position
	player.input.move = Vector2(1, 1)
	player.input.press(&"dodge")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _frames(PlayerMovement.ROLL_FRAMES)
	var moved := player.position - start
	_check(moved.x > 35.0, "rola para a frente (%.1f px)" % moved.x)
	_check(moved.y > 5.0 and moved.y < moved.x, "na diagonal troca um pouco de faixa (%.1f px)" % moved.y)


func test_sidestep_changes_lane() -> void:
	var enemy := _spawn(Vector2(24, 0))
	var start := player.position
	player.input.move = Vector2(0, -1)
	player.input.press(&"dodge")
	await _frames(1)
	player.input.move = Vector2.ZERO
	_check(player.movement.dodge == PlayerMovement.Dodge.SIDESTEP, "esquiva + cima: passo lateral")
	await _frames(PlayerMovement.SIDESTEP_FRAMES)
	var moved := player.position - start
	_check(absf(moved.x) < 0.5, "não anda na horizontal")
	_check(-moved.y > Fighter.DEPTH_TOLERANCE * 2.0, "sai da faixa de golpe (%.1f px)" % -moved.y)


func test_dodge_cooldown() -> void:
	player.input.press(&"dodge")
	await _frames(PlayerMovement.ROLL_FRAMES + 1)
	player.input.press(&"dodge")
	await _frames(2)
	_check(not player.movement.is_dodging(), "não dá para emendar esquivas sem parar")
	await _frames(PlayerMovement.DODGE_COOLDOWN_FRAMES)
	player.input.press(&"dodge")
	await _frames(2)
	_check(player.movement.is_dodging(), "depois do intervalo esquiva de novo")


func test_roll_cancel_into_attack() -> void:
	player.input.press(&"dodge")
	await _frames(PlayerMovement.DODGE_CANCEL_FROM - 2)
	player.input.press(&"attack")
	await _frames(1)
	_check(player.movement.is_dodging(), "antes do quadro de cancelamento o rolamento segue")
	await _frames(3)
	_check(player.state == Fighter.State.ATTACK, "o ataque guardado sai antes do fim do rolamento")


func test_dodge_input_action() -> void:
	_check(InputMap.has_action(&"dodge"), "ação dodge no Input Map")
	var keys := []
	for event in InputMap.action_get_events(&"dodge"):
		if event is InputEventKey:
			keys.append(event.physical_keycode)
	_check(KEY_SHIFT in keys and KEY_I in keys, "esquiva no Shift e no I")


# --- Pulo ----------------------------------------------------------------------

func test_short_and_full_jump() -> void:
	var full := await _jump_peak(true)
	await _frames(10)
	var short := await _jump_peak(false)
	_check(full > 30.0, "pulo segurado sobe bem (%.1f px)" % full)
	_check(short < full * 0.7 and short > 8.0, "toque curto pula baixo (%.1f px)" % short)


func test_air_control() -> void:
	player.input.press(&"jump")
	await _frames(4)
	var x := player.position.x
	player.input.move = Vector2(1, 0)
	await _frames(14)
	player.input.move = Vector2.ZERO
	_check(player.state == Fighter.State.JUMP and player.position.x - x > 5.0,
		"segurando a direção no ar o pulo vai para lá (%.1f px)" % (player.position.x - x))
	_check(player.facing == 1, "e vira para a direção")
	var vx := player.velocity.x
	await _frames(3)
	_check(player.velocity.x == vx, "sem direção mantém o embalo")


func test_run_jump_goes_farther() -> void:
	player.input.move = Vector2(1, 0)
	await _frames(20)
	var start := player.position.x
	player.input.press(&"jump")
	await _until(func() -> bool: return player.state == Fighter.State.JUMP, 5)
	await _until(func() -> bool: return player.state != Fighter.State.JUMP, 90)
	var walk_jump := player.position.x - start
	player.input.move = Vector2.ZERO
	player.position.x = 150.0
	await _frames(10)
	await _double_tap(1)
	await _frames(15)
	start = player.position.x
	player.input.press(&"jump")
	await _until(func() -> bool: return player.state == Fighter.State.JUMP, 5)
	player.input.move = Vector2.ZERO
	await _until(func() -> bool: return player.state != Fighter.State.JUMP, 90)
	var run_jump := player.position.x - start
	_check(run_jump > walk_jump * 1.5, "pulo da corrida vai bem mais longe (%.0f contra %.0f px)" % [run_jump, walk_jump])


func test_keep_running_after_run_jump() -> void:
	await _double_tap(1)
	await _frames(10)
	player.input.press(&"jump")
	await _until(func() -> bool: return player.state == Fighter.State.JUMP, 5)
	await _until(func() -> bool: return player.state != Fighter.State.JUMP, 90)
	await _frames(2)
	_check(player.movement.running, "pousou segurando a frente: continua correndo")


# --- Agarrão -------------------------------------------------------------------

func test_vault_over_grabbed_enemy() -> void:
	var enemy := _tough(Vector2(30, 0))
	player.input.move = Vector2(1, 0)
	await _frames(10)
	player.input.move = Vector2.ZERO
	_check(player.state == Fighter.State.GRAB, "agarrou")
	var enemy_x := enemy.position.x
	player.input.press(&"jump")
	await _frames(PlayerMovement.VAULT_FRAMES / 2)
	_check(player.height > 15.0, "salta por cima (altura %.0f)" % player.height)
	await _frames(PlayerMovement.VAULT_FRAMES)
	_check(player.position.x > enemy.position.x and player.facing == -1, "pousa do outro lado, olhando para ele")
	_check(player.state == Fighter.State.GRAB and enemy.state == Fighter.State.GRABBED, "e continua agarrando")
	_check(absf(enemy.position.x - enemy_x) < 0.5, "o inimigo fica no lugar")
	player.input.press(&"attack")
	player.input.move = Vector2(-1, 0)
	await _frames(1)
	player.input.move = Vector2.ZERO
	_check(enemy.state == Fighter.State.THROWN, "ataque com direção: suplex")
	_check(enemy.position.x > player.position.x - 1.0 and enemy.velocity.x > 0.0, "o suplex joga por cima do herói, para trás")
	await _until(func() -> bool: return enemy.state == Fighter.State.KNOCKDOWN and enemy.height == 0.0, 90)
	_check(enemy.hp == 999 - Fighter.THROW_DAMAGE - Player.SUPLEX_BONUS,
		"suplex tira %d (vida %d)" % [Fighter.THROW_DAMAGE + Player.SUPLEX_BONUS, enemy.hp])


func test_back_grab_suplex() -> void:
	var enemy := _tough(Vector2(30, 0))
	enemy.facing = 1
	player.input.move = Vector2(1, 0)
	await _frames(10)
	player.input.move = Vector2.ZERO
	_check(player.state == Fighter.State.GRAB and player._back_grab, "agarrou pelas costas")
	player.input.press(&"attack")
	player.input.move = Vector2(1, 0)
	await _frames(1)
	player.input.move = Vector2.ZERO
	_check(enemy.state == Fighter.State.THROWN and enemy.velocity.x < 0.0, "pelas costas o arremesso é suplex para trás")
	await _until(func() -> bool: return enemy.state == Fighter.State.KNOCKDOWN and enemy.height == 0.0, 90)
	_check(enemy.hp == 999 - Fighter.THROW_DAMAGE - Player.SUPLEX_BONUS, "suplex tira mais (vida %d)" % enemy.hp)


func test_front_throw_unchanged() -> void:
	var enemy := _tough(Vector2(30, 0))
	player.input.move = Vector2(1, 0)
	await _frames(10)
	_check(not player._back_grab, "de frente é o agarrão normal")
	player.input.press(&"attack")
	await _frames(1)
	player.input.move = Vector2.ZERO
	await _until(func() -> bool: return enemy.state == Fighter.State.KNOCKDOWN and enemy.height == 0.0, 90)
	_check(enemy.hp == 999 - Fighter.THROW_DAMAGE, "arremesso de frente continua 12 (vida %d)" % enemy.hp)


func test_hit_cancels_run_and_dodge() -> void:
	var enemy := _spawn(Vector2(-60, 0))
	await _double_tap(1)
	player.take_hit(5, false, enemy)
	_check(not player.movement.running, "apanhar acaba a corrida")
	await _frames(20)
	player.input.move = Vector2.ZERO
	await _frames(10)
	player.input.press(&"dodge")
	await _frames(PlayerMovement.ROLL_INVULN_FRAMES + 3)
	_check(player.take_hit(5, false, enemy), "no fim do rolamento já dá para apanhar")
	_check(not player.movement.is_dodging() and player.state == Fighter.State.HURT, "e o golpe interrompe o rolamento")


func test_sprite_for_moves() -> void:
	player.input.press(&"dodge")
	await _frames(3)
	_check(player.sprite.anim == "roll", "esquiva usa a animação de rolamento")
	_check(player.sprite.modulate != Color.WHITE, "brilha enquanto está invencível")
	_check(player._is_visible_this_frame(), "e não pisca")
	await _frames(PlayerMovement.ROLL_FRAMES + PlayerMovement.DODGE_COOLDOWN_FRAMES)
	_check(player.sprite.modulate == Color.WHITE, "o brilho some no fim")
	await _double_tap(1)
	await _frames(4)
	_check(player.sprite.anim == "run", "correndo usa run")


# --- Ajudantes -------------------------------------------------------------------

func _double_tap(dir: int) -> void:
	player.input.move = Vector2(dir, 0)
	await _frames(2)
	player.input.move = Vector2.ZERO
	await _frames(2)
	player.input.move = Vector2(dir, 0)
	await _frames(2)


## Pula parado e devolve a altura máxima. `held` false solta o botão logo.
func _jump_peak(held: bool) -> float:
	player.input.jump_held = true
	player.input.press(&"jump")
	await _frames(2)
	player.input.jump_held = held
	var peak := 0.0
	for i in 90:
		await physics_frame
		peak = maxf(peak, player.height)
		if player.state != Fighter.State.JUMP:
			break
	player.input.jump_held = true
	return peak


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


func _until(condition: Callable, limit: int) -> void:
	for i in limit:
		if condition.call():
			return
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, message: String) -> void:
	if message == "":
		return
	_checks += 1
	if ok:
		print("  ok      %s" % message)
	else:
		_failures += 1
		print("  FALHOU  %s" % message)

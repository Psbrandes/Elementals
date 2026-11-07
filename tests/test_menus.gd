extends SceneTree
## Testes do menu, das opções, da pausa e da tela de vitória:
##   godot --headless --path . --fixed-fps 60 --script res://tests/test_menus.gd

const MAIN := preload("res://scenes/main.tscn")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	test_stage_rank()
	test_menu_list()
	test_settings_buses()
	await test_sounds_exist()
	await test_pause_menu()
	await test_victory_flow()
	print("\n%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func test_stage_rank() -> void:
	print("\ntest_stage_rank")
	_check(Stage.stage_rank(200, 0, 35) == "S", "rápido, sem cair e combo grande: S")
	_check(Stage.stage_rank(300, 1, 20) == "A", "5 min, 1 queda, combo 20: A")
	_check(Stage.stage_rank(258, 7, 12) == "C", "o robô do playthrough (258 s, 7 quedas, combo 12): C")
	_check(Stage.stage_rank(600, 9, 3) == "D", "lento, caindo muito e sem combo: D")


func test_menu_list() -> void:
	print("\ntest_menu_list")
	var menu := MenuList.new([{"id": "a", "label": "A"}, {"id": "b", "label": "B"},
		{"id": "c", "label": "C", "slider": true, "value": "5"}])
	menu.handle(_action("move_up"))
	_check(menu.current_id() == "c", "cima no primeiro item dá a volta para o último")
	_check(menu.handle(_action("move_left")).get("do") == "left", "seta para o lado num slider")
	menu.handle(_action("move_down"))
	_check(menu.current_id() == "a", "baixo no último volta ao primeiro")
	_check(menu.handle(_action("attack")).get("do") == "ok", "J confirma")
	_check(menu.handle(_action("jump")).get("do") == "back", "K volta")
	_check(menu.handle(_action("pause")).get("do") == "back", "Esc volta quando pause_is_back")
	menu.pause_is_back = false
	_check(menu.handle(_action("pause")).is_empty(), "no título Esc não faz nada")


func test_settings_buses() -> void:
	print("\ntest_settings_buses")
	var settings := root.get_node_or_null(^"Settings")
	_check(settings != null, "autoload Settings carregado")
	if settings == null:
		return
	var music: int = settings.music_volume
	var sfx: int = settings.sfx_volume
	var music_bus := AudioServer.get_bus_index(&"Music")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	_check(music_bus > 0 and sfx_bus > 0, "barramentos Music e SFX criados")
	settings.set_music(0)
	_check(AudioServer.is_bus_mute(music_bus), "música em 0 fica muda")
	settings.set_music(10)
	_check(not AudioServer.is_bus_mute(music_bus) and absf(AudioServer.get_bus_volume_db(music_bus)) < 0.01,
		"música em 10 fica em 0 dB")
	settings.set_sfx(5)
	var half := AudioServer.get_bus_volume_db(sfx_bus)
	_check(half < -3.0 and half > -15.0, "efeitos em 5 ficam no meio (%.1f dB)" % half)
	settings.duck(true)
	_check(AudioServer.get_bus_volume_db(music_bus) < -5.0, "pausa abaixa a música")
	settings.duck(false)
	settings.set_music(music)
	settings.set_sfx(sfx)
	var bank := root.get_node_or_null(^"SoundBank")
	_check(bank != null and bank._music.bus == &"Music", "a música toca no barramento Music")


func test_sounds_exist() -> void:
	print("\ntest_sounds_exist")
	for name in ["dodge", "grab", "throw", "land", "rank_up", "alert", "boss_intro", "extra_life", "go",
			"block", "counter", "charge_ready", "tally", "tally_end", "stamp", "menu_open", "menu_close"]:
		_check(Sound.has(name), "efeito %s carregado" % name)
	for track in ["vitoria", "resultado", "selecao"]:
		_check(ResourceLoader.exists("res://assets/audio/music/%s.ogg" % track), "música %s existe" % track)


func test_pause_menu() -> void:
	print("\ntest_pause_menu")
	var main := MAIN.instantiate()
	main.get_node("Stage").auto_spawn = false
	root.add_child(main)
	await _frames(5)
	var hud: Control = main.get_node("HUD/HUDView")
	hud._unhandled_input(_action("pause"))
	_check(paused, "Esc pausa")
	hud._unhandled_input(_action("move_down"))
	hud._unhandled_input(_action("move_down"))
	hud._unhandled_input(_action("attack"))
	_check(hud._options != null, "Opções abre o submenu")
	hud._unhandled_input(_action("jump"))
	_check(hud._options == null and paused, "K fecha as opções e continua pausado")
	hud._unhandled_input(_action("pause"))
	_check(not paused, "Esc de novo despausa")
	main.queue_free()
	await _frames(2)


func test_victory_flow() -> void:
	print("\ntest_victory_flow")
	var main := MAIN.instantiate()
	main.get_node("Stage").auto_spawn = false
	root.add_child(main)
	await _frames(5)
	var stage: Stage = main.get_node("Stage")
	var hud: Control = main.get_node("HUD/HUDView")
	stage.score = 5000
	stage.kills = 12
	stage.best_combo = 9
	stage._frames = 60 * 200
	stage._clear_stage()
	var r := stage.final_results
	_check(r.get("score_before") == 5000, "guarda os pontos de antes dos bônus")
	_check(r.get("score") == stage.score and stage.score == 5000 + r["life_bonus"] + r["time_bonus"],
		"total = pontos + bônus de vida + bônus de tempo")
	_check(r.get("kills") == 12 and r.get("best_combo") == 9, "inimigos e maior combo na tela de vitória")
	_check(r.get("rank") == "A", "nota da fase calculada (%s)" % r.get("rank"))
	await _frames(30)
	_check(hud._victory > 0 and hud._victory < hud.V_MENU, "contagem rodando")
	hud._unhandled_input(_action("attack"))
	_check(hud._victory == hud.V_RANK - 1, "J pula a contagem até a nota")
	await _frames(hud.V_MENU - hud.V_RANK + 5)
	_check(hud._victory > hud.V_MENU, "menu de vitória aparece")
	main.queue_free()
	await _frames(2)


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok      %s" % message)
	else:
		_failures += 1
		print("  FALHOU  %s" % message)

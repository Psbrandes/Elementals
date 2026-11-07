extends Control
## HUD desenhado em código: vida, medidor elemental, vidas, pontos, a barra do
## último inimigo atingido, a barra do chefe e os avisos (seção, GO). Também cuida
## dos menus da partida, por isso roda mesmo com o jogo pausado: pausa (Esc), fim
## de jogo e a tela de vitória com a contagem dos pontos e a nota da fase.

const FONT_SIZE := 8
const HINT_SIZE := 7
const BANNER_FRAMES := 120
const GO_FRAMES := 150
const ENEMY_BAR_FRAMES := 180
const HINT_FRAMES := 900
const HP_COLOR := Color("ffcc33")
const HP_LOW_COLOR := Color("e04040")
const METER_COLOR := Color("ff7a1a")
const METER_FULL_COLOR := Color("fff1a8")
const BAR_BACK := Color(0, 0, 0, 0.6)
const COMBO_RESULT_FRAMES := 75
## Cor de cada nota de estilo do combo (Player.STYLE_RANKS).
const RANK_COLORS := {"D": Color("9aa4b0"), "C": Color("7fd3ff"), "B": Color("7dff8a"), "A": Color("ffcc33"),
	"S": Color("ff7a1a"), "SS": Color("ff4fd8")}
const COMBO_EVENT_FRAMES := 45
const COMBO_EVENT_MAX := 3
const MOVE_NAME_FRAMES := 60
const HINTS := [
	"J soco  K pulo  L especial  Shift esquiva  frente 2x corre  J J cima+J lança  no ar J J J",
	"Trás+J virada   segure J e solte: carregado   baixo+L especial 2   no ar baixo+J",
]

## Linha do tempo da tela de vitória, em quadros desde a vitória.
const V_MUSIC := 40
const V_PANEL := 90
const V_ROW := 120
const V_ROW_GAP := 18
const V_COUNT := 200
const V_COUNT_FRAMES := 50
const V_COUNT_GAP := 60
const V_RANK := 390
const V_MENU := 420
## A fanfarra dura cerca de 7,5 s; depois entra o loop calmo.
const V_LOOP_MUSIC := V_MUSIC + 460
const STAT_ROWS := 4
const OVER_MENU_DELAY := 60
const SELECT_SCENE := "res://scenes/select.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"

@export var stage: Stage

var _font: Font
var _last_enemy: Enemy
var _enemy_bar_frames := 0
var _banner_text := ""
var _banner_frames := 0
var _go_frames := 0
var _frame := 0
var _combo_pop := 0
var _combo_result_text := ""
var _combo_result_color := Color.WHITE
var _combo_result_frames := 0
var _rank_pop := 0
## Destaques recentes do combo: [texto, quadros restantes].
var _combo_events: Array = []
## Nome do golpe próprio do herói que acabou de sair.
var _move_text := ""
var _move_color := Color.WHITE
var _move_frames := 0
var _pause_menu := MenuList.new([{"id": "continuar", "label": "Continuar"},
	{"id": "secao", "label": "Recomeçar a seção"}, {"id": "opcoes", "label": "Opções"},
	{"id": "titulo", "label": "Menu principal"}])
var _options: OptionsMenu
var _over_menu := MenuList.new([{"id": "continuar", "label": "Continuar desta seção"},
	{"id": "titulo", "label": "Menu principal"}])
var _over_frames := 0
var _victory_menu := MenuList.new([{"id": "denovo", "label": "Jogar de novo"},
	{"id": "heroi", "label": "Escolher outro herói"}, {"id": "titulo", "label": "Menu principal"}])
## Quadros desde a vitória (-1 enquanto a fase não acabou).
var _victory := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	stage.enemy_damaged.connect(_on_enemy_damaged)
	stage.section_entered.connect(_on_section_entered)
	stage.camera_unlocked.connect(func() -> void: _go_frames = GO_FRAMES)
	stage.player.combo_changed.connect(func(_hits: int, _bonus: int) -> void: _combo_pop = 6)
	stage.player.combo_ended.connect(_on_combo_ended)
	stage.player.combo_event.connect(_on_combo_event)
	stage.player.move_used.connect(_on_move_used)
	stage.boss_appeared.connect(func(_boss: Boss) -> void: _show_banner("FERRUGEM, O TENENTE DE TERRA"))


func _process(_delta: float) -> void:
	_frame += 1
	_update_victory()
	if stage.is_game_over():
		_over_frames += 1
	if not get_tree().paused:
		_banner_frames = maxi(_banner_frames - 1, 0)
		_enemy_bar_frames = maxi(_enemy_bar_frames - 1, 0)
		_go_frames = maxi(_go_frames - 1, 0)
		_combo_pop = maxi(_combo_pop - 1, 0)
		_combo_result_frames = maxi(_combo_result_frames - 1, 0)
		_rank_pop = maxi(_rank_pop - 1, 0)
		for event: Array in _combo_events:
			event[1] -= 1
		_combo_events = _combo_events.filter(func(event: Array) -> bool: return event[1] > 0)
		_move_frames = maxi(_move_frames - 1, 0)
	queue_redraw()


## Online não tem pausa: o jogo dos outros continua rodando.
func _online() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net != null and net.active


func _unhandled_input(event: InputEvent) -> void:
	if stage.cleared:
		_victory_input(event)
		return
	if _online():
		return
	if stage.is_game_over():
		if _over_frames >= OVER_MENU_DELAY:
			var result := _over_menu.handle(event)
			if result.get("do", "") == "ok":
				if result["id"] == "continuar":
					stage.continue_here()
				else:
					stage.go_to_scene(TITLE_SCENE)
			if not result.is_empty():
				_handled()
		return
	if get_tree().paused:
		_pause_input(event)
		_handled()
	elif event.is_action_pressed(&"pause"):
		_set_paused(true)
		_handled()


## Pausa sozinho quando o app vai para o fundo ou a aba do navegador perde o foco.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if is_inside_tree() and not _online() and not stage.is_game_over() and not stage.cleared \
				and not get_tree().paused:
			_set_paused(true)


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	_options = null
	_pause_menu.cursor = 0
	Sound.ui("pause" if on else "menu_close")
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.duck(on)


func _pause_input(event: InputEvent) -> void:
	if _options:
		if _options.handle(event):
			_options = null
			Sound.ui("menu_close")
		return
	var result := _pause_menu.handle(event)
	match result.get("do", ""):
		"back":
			_set_paused(false)
		"ok":
			match result["id"]:
				"continuar":
					_set_paused(false)
				"secao":
					_leave_pause()
					stage.continue_here()
				"opcoes":
					_options = OptionsMenu.new()
					Sound.ui("menu_open")
				"titulo":
					_leave_pause()
					stage.go_to_scene(TITLE_SCENE)


func _leave_pause() -> void:
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.duck(false)


# --- Tela de vitória ----------------------------------------------------------------

func _update_victory() -> void:
	if not stage.cleared:
		return
	_victory += 1
	if _victory == V_MENU:
		stage.victory_menu_ready = true
	if _victory == V_MUSIC:
		Sound.music_local("vitoria", false)
	elif _victory == V_LOOP_MUSIC:
		Sound.music_local("resultado")
	if _victory > V_MENU:
		return
	# Sons da contagem: um tique por linha e por passo dos números.
	for i in STAT_ROWS:
		if _victory == V_ROW + i * V_ROW_GAP:
			Sound.ui("tally", -2.0)
	for i in 3:
		var start := V_COUNT + i * V_COUNT_GAP
		if _victory >= start and _victory < start + V_COUNT_FRAMES and (_victory - start) % 4 == 0:
			Sound.ui("tally", -6.0)
		elif _victory == start + V_COUNT_FRAMES:
			Sound.ui("tally_end", -4.0)
	if _victory == V_RANK:
		Sound.ui("stamp", -2.0)


func _victory_input(event: InputEvent) -> void:
	if _victory < V_MENU:
		# J pula a contagem direto para o fim.
		if event.is_action_pressed(&"attack") or event.is_action_pressed(&"restart") or event.is_action_pressed(&"ui_accept"):
			if _victory < V_RANK:
				_victory = V_RANK - 1
			_handled()
		return
	if _online():
		# Online, o host volta todo mundo para a sala (Stage._unhandled_input chama a rede).
		return
	var result := _victory_menu.handle(event)
	if result.get("do", "") == "ok":
		match result["id"]:
			"denovo":
				stage.restart_stage()
			"heroi":
				stage.go_to_scene(SELECT_SCENE)
			"titulo":
				stage.go_to_scene(TITLE_SCENE)
	if not result.is_empty():
		_handled()


func _on_enemy_damaged(enemy: Enemy) -> void:
	if enemy is Boss:
		return
	_last_enemy = enemy
	_enemy_bar_frames = ENEMY_BAR_FRAMES


func _on_combo_event(text: String) -> void:
	if text.begins_with("NOTA"):
		_rank_pop = 10
		return
	_combo_events.push_front([text, COMBO_EVENT_FRAMES])
	if _combo_events.size() > COMBO_EVENT_MAX:
		_combo_events.pop_back()


func _on_combo_ended(hits: int, bonus: int, dropped: bool) -> void:
	_combo_events.clear()
	if dropped and hits >= Player.COMBO_MIN_HITS:
		_combo_result_text = "COMBO PERDIDO"
		_combo_result_color = HP_LOW_COLOR
	elif bonus > 0:
		var rank := stage.player.combo_peak_rank
		_combo_result_text = "+%d  NOTA %s" % [bonus, rank]
		_combo_result_color = RANK_COLORS.get(rank, METER_FULL_COLOR)
	else:
		return
	_combo_result_frames = COMBO_RESULT_FRAMES


func _on_move_used(label: String, color: Color) -> void:
	_move_text = label.to_upper()
	_move_color = color.lightened(0.35)
	_move_frames = MOVE_NAME_FRAMES


func _on_section_entered(index: int, title: String) -> void:
	if index == 0:
		_show_banner("BAIRRO DO PORTO")
	else:
		_show_banner(title.to_upper())


func _show_banner(text: String) -> void:
	_banner_text = text
	_banner_frames = BANNER_FRAMES


func _draw() -> void:
	var coop := stage.players.size() > 1
	var enemy_y := 35.0
	if coop:
		_draw_coop_panels()
		_text_right("%06d  ONDA %d" % [stage.score, stage.wave], Vector2(size.x - 6, 37), Color(1, 1, 1, 0.8))
		enemy_y = 37.0
	else:
		_draw_player_panel(stage.player, Vector2(6, 0), 100.0, "")
		_text_right("%06d" % stage.score, Vector2(size.x - 6, 11), Color.WHITE)
		_text_right("ONDA %d" % stage.wave, Vector2(size.x - 6, 20), Color(1, 1, 1, 0.7))

	if _enemy_bar_frames > 0 and is_instance_valid(_last_enemy):
		_text(_last_enemy.data.display_name, Vector2(6, enemy_y), Color(1, 1, 1, 0.85))
		_bar(Rect2(6, enemy_y + 2.0, 60, 3), float(_last_enemy.hp) / _last_enemy.max_hp, HP_LOW_COLOR)
		# Elemento e fraqueza, para o jogador aprender quem trocar de herói enfrenta melhor.
		var info: EnemyData = _last_enemy.data
		if info.element != "":
			var line := info.element.to_upper()
			if not info.weak_to.is_empty():
				line += "  fraco: " + " ".join(info.weak_to).to_upper()
			_text(line, Vector2(6, enemy_y + 13.0), Color(1, 1, 1, 0.7), HINT_SIZE)

	_draw_combo()
	if _move_frames > 0:
		_text_center(_move_text, Vector2(size.x / 2.0, 34), _move_color, 10)

	var boss := stage.boss
	if is_instance_valid(boss) and boss.state != Fighter.State.DEAD:
		var bar := Rect2(size.x / 2.0 - 80.0, size.y - 10.0, 160.0, 4.0)
		var mark_x := bar.position.x + bar.size.x * Boss.PHASE_TWO_RATIO
		_text_center(boss.data.display_name.to_upper(), Vector2(size.x / 2.0, size.y - 13.0), Color.WHITE)
		_bar(bar, float(boss.hp) / boss.max_hp, HP_LOW_COLOR if boss.phase == 1 else METER_COLOR)
		draw_line(Vector2(mark_x, bar.position.y - 1.0), Vector2(mark_x, bar.end.y + 1.0), Color.WHITE)

	if _frame < HINT_FRAMES and not is_instance_valid(boss) and not stage.cleared and not stage.is_game_over() and not get_tree().paused:
		_text(HINTS[(_frame / 240) % HINTS.size()], Vector2(6, size.y - 4), Color(1, 1, 1, 0.55), HINT_SIZE)

	var center := size / 2.0
	if stage.cleared:
		_draw_victory(center)
	elif stage.is_game_over():
		_draw_game_over(center)
	elif get_tree().paused:
		_draw_pause(center)
	elif _banner_frames > 0:
		_text_center(_banner_text, center + Vector2(0, -36), METER_FULL_COLOR, 14)
	if _go_frames > 0 and not stage.cleared and _frame % 30 < 20:
		_text_right("GO! >>", Vector2(size.x - 10, center.y - 30), METER_FULL_COLOR, 16)


## Vida, medidor e vidas de um herói. `tag` é o "P1".."P4" do co-op.
func _draw_player_panel(player: Player, at: Vector2, width: float, tag: String) -> void:
	if not is_instance_valid(player):
		return
	var label: String = player.character["name"].to_upper()
	if tag != "":
		label = tag + " " + label
	var local := player == stage.player
	_text(label, at + Vector2(0, 11), METER_FULL_COLOR if local and tag != "" else Color.WHITE)
	var hp_ratio := float(player.hp) / player.max_hp
	_bar(Rect2(at + Vector2(0, 14), Vector2(width, 5)), hp_ratio, HP_COLOR if hp_ratio > 0.3 else HP_LOW_COLOR)
	var full := player.meter >= Player.METER_MAX
	var meter_color := METER_FULL_COLOR if full and _frame % 16 < 8 else player.element_color()
	_bar(Rect2(at + Vector2(0, 21), Vector2(width, 3)), float(player.meter) / Player.METER_MAX, meter_color)
	# Marca dos 50: a partir dela o especial sai sem gastar vida.
	var mark := at.x + width * float(Player.SPECIAL_COST) / Player.METER_MAX
	draw_line(Vector2(mark, at.y + 20), Vector2(mark, at.y + 25), Color.WHITE)
	_text("x%d" % maxi(player.lives, 0), at + Vector2(width + 4, 20), Color.WHITE)


## Co-op: um painel por herói lado a lado no topo, na ordem de entrada.
func _draw_coop_panels() -> void:
	var count := stage.players.size()
	var slot := minf((size.x - 6.0) / count, 120.0)
	for i in count:
		_draw_player_panel(stage.players[i], Vector2(6 + i * slot, 0), slot - 22.0, "P%d" % (i + 1))


## Contador no canto direito: número grande que pula a cada golpe, nota e bônus.
func _draw_combo() -> void:
	var right := size.x - 6
	var hits := stage.player.combo_hits
	# No co-op a linha de pontos fica logo abaixo dos painéis: o contador desce um pouco.
	var top := 58.0 if stage.players.size() > 1 else 44.0
	if hits >= 2:
		var number_size := 18 + _combo_pop
		_text_right("%d" % hits, Vector2(right - 38, top), METER_COLOR if hits < 10 else METER_FULL_COLOR, number_size)
		_text_right("GOLPES", Vector2(right, top), Color.WHITE)
		# Barrinha do tempo que falta para o combo acabar.
		var bar := Rect2(right - 60.0, top + 3.0, 60.0, 2.0)
		draw_rect(bar, BAR_BACK)
		var left := stage.player.combo_time_left()
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)),
			HP_LOW_COLOR if left < 0.3 else Color.WHITE)
		# Nota de estilo, que cresce quando sobe.
		var rank := stage.player.combo_rank()
		_text_right(rank, Vector2(right - 64.0, top), RANK_COLORS.get(rank, Color.WHITE), 14 + _rank_pop)
		var bonus := stage.player.combo_bonus()
		if bonus > 0:
			_text_right("+%d" % bonus, Vector2(right, top + 13.0), Color(1, 1, 1, 0.7))
		var y := top + 22.0
		for event: Array in _combo_events:
			var color := Color("ff5a3c") if event[0] == "CONTRA!" else METER_FULL_COLOR
			color.a = clampf(float(event[1]) / 15.0, 0.0, 1.0)
			_text_right(event[0], Vector2(right, y), color)
			y += 9.0
	elif _combo_result_frames > 0 and _frame % 8 < 6:
		_text_right(_combo_result_text, Vector2(right, top), _combo_result_color, 10)


func _draw_pause(center: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var accent := stage.player.element_color() if is_instance_valid(stage.player) else METER_COLOR
	if _options:
		UiDraw.panel(self, Rect2(center.x - 95.0, center.y - 52.0, 190.0, 100.0), accent)
		_options.draw(self, center.x, center.y - 36.0, accent)
		return
	var height := _pause_menu.height() + 34.0
	var rect := Rect2(center.x - 80.0, center.y - height / 2.0, 160.0, height)
	UiDraw.panel(self, rect, accent)
	UiDraw.text_center(self, "PAUSA", Vector2(center.x, rect.position.y + 16.0), 14, Color.WHITE)
	_pause_menu.draw(self, center.x, rect.position.y + 32.0, 148.0, accent)


func _draw_game_over(center: Vector2) -> void:
	var fade := minf(_over_frames / 40.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0, 0, 0.5 * fade))
	UiDraw.text_center(self, "FIM DE JOGO", center + Vector2(0, -22), 18, Color(1, 0.35, 0.3, fade))
	if _online():
		_text_center("J ou Enter para continuar desta seção", center + Vector2(0, 0), Color(1, 1, 1, 0.8))
		return
	if _over_frames >= OVER_MENU_DELAY:
		_over_menu.draw(self, center.x, center.y + 2.0, 150.0, HP_LOW_COLOR)


## Vitória: "FASE CONCLUÍDA!" caindo letra por letra, depois o painel com o herói, as linhas
## de estatística, a contagem dos bônus, a nota da fase carimbada e o menu.
func _draw_victory(center: Vector2) -> void:
	var t := _victory
	var results: Dictionary = stage.final_results if not stage.final_results.is_empty() else stage.results()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, minf(t / 90.0, 1.0) * 0.5))
	var accent := stage.player.element_color() if is_instance_valid(stage.player) else METER_COLOR
	_draw_victory_banner(Vector2(center.x, 24.0), t, accent)
	if t < V_PANEL:
		return
	var slide := 1.0 - pow(1.0 - minf((t - V_PANEL) / 20.0, 1.0), 3.0)
	var rect := Rect2(center.x - 125.0, 36.0 + (1.0 - slide) * size.y, 250.0, 154.0)
	UiDraw.panel(self, rect, accent)
	# Herói: comemora com o especial na hora da nota, parado no resto do tempo.
	if is_instance_valid(stage.player):
		var id: String = stage.player.character.get("id", "fire_knight")
		var anim := "idle"
		var index := _frame / 7
		if t >= V_RANK and t < V_RANK + 40:
			anim = "sp_atk"
			index = (t - V_RANK) * UiDraw.frame_count(id, anim) / 40
		var feet := rect.position + Vector2(34.0, 66.0)
		draw_rect(Rect2(feet.x - 26.0, feet.y - 50.0, 52.0, 52.0), Color(accent, 0.12))
		UiDraw.character(self, id, anim, index, feet, 48.0)
		UiDraw.text_center(self, stage.player.character.get("name", "").to_upper(), feet + Vector2(0, 11), 7, accent)
	var left := rect.position.x + 70.0
	var right := rect.end.x - 10.0
	var y := rect.position.y + 16.0
	var seconds: int = results.get("seconds", 0)
	var rows := [["Tempo", "%d:%02d" % [seconds / 60, seconds % 60]],
		["Inimigos derrotados", str(results.get("kills", 0))],
		["Maior combo", "%d golpes" % results.get("best_combo", 0)],
		["Quedas", str(results.get("deaths", 0))]]
	for i in rows.size():
		if t >= V_ROW + i * V_ROW_GAP:
			UiDraw.text(self, rows[i][0], Vector2(left, y), 8, Color(1, 1, 1, 0.75))
			UiDraw.text_right(self, rows[i][1], Vector2(right, y), 8, Color.WHITE)
		y += 11.0
	draw_line(Vector2(left, y - 6.0), Vector2(right, y - 6.0), Color(1, 1, 1, 0.2))
	y += 3.0
	var before: int = results.get("score_before", stage.score)
	var counts := [["Bônus de vida", results.get("life_bonus", 0), 0, Color.WHITE],
		["Bônus de tempo", results.get("time_bonus", 0), 0, Color.WHITE],
		["Total", results.get("score", stage.score), before, METER_FULL_COLOR]]
	for i in counts.size():
		var start := V_COUNT + i * V_COUNT_GAP
		if t >= start - 10:
			var ratio := clampf(float(t - start) / V_COUNT_FRAMES, 0.0, 1.0)
			var value := int(lerpf(float(counts[i][2]), float(counts[i][1]), ratio))
			var text := ("%06d" % value) if i == 2 else ("+%d" % value)
			UiDraw.text(self, counts[i][0], Vector2(left, y), 8 if i < 2 else 9, counts[i][3])
			UiDraw.text_right(self, text, Vector2(right, y), 8 if i < 2 else 10, counts[i][3])
		y += 11.0 if i < 1 else 13.0
	# Nota da fase: entra grande e encolhe até o tamanho final, com um tremor.
	if t >= V_RANK:
		var rank: String = results.get("rank", "C")
		var grow := maxf(1.0 - (t - V_RANK) / 8.0, 0.0)
		var font_size := int(30 + 30 * grow)
		var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0 if t < V_RANK + 12 else Vector2.ZERO
		var at := rect.position + Vector2(34.0, 124.0)
		UiDraw.text_center(self, "NOTA DA FASE", rect.position + Vector2(34.0, 92.0), 7, Color(1, 1, 1, 0.7))
		UiDraw.text_center(self, rank, at + shake + Vector2(0, font_size * 0.3 - 9.0), font_size, RANK_COLORS.get(rank, Color.WHITE))
	if t < V_MENU:
		if t > V_PANEL + 20 and _frame % 60 < 40:
			UiDraw.text_center(self, "J pula a contagem", Vector2(center.x, rect.end.y + 10.0), 7, Color(1, 1, 1, 0.5))
		return
	var menu_top := rect.position.y + 120.0
	if _online():
		var net := get_node_or_null(^"/root/Net")
		var text := "J ou Enter: voltar à sala" if net and net.is_host() else "Aguardando o host..."
		if _frame % 60 < 44:
			UiDraw.text_center(self, text, Vector2(rect.get_center().x + 30.0, menu_top + 12.0), 8, Color.WHITE)
		return
	_victory_menu.draw(self, rect.get_center().x + 30.0, menu_top, 150.0, accent, 8)


func _draw_victory_banner(at: Vector2, t: int, accent: Color) -> void:
	var word := "FASE CONCLUÍDA!"
	var font := UiDraw.font()
	var font_size := 16
	var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := at.x - width / 2.0
	for i in word.length():
		var letter := word[i]
		var appear := t - i * 3
		var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if appear > 0:
			# Cai de cima e quica uma vez.
			var p := minf(appear / 14.0, 1.0)
			var drop := -40.0 * pow(1.0 - p, 2.0) + (sin(p * PI) * -3.0 if p < 1.0 else 0.0)
			var wave := sin((_frame + i * 5) / 10.0) * 1.0 if t > 60 else 0.0
			var pos := Vector2(x, at.y + drop + wave)
			for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(1, 2)]:
				draw_string(font, pos + offset, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("0b0f2a"))
			var color := METER_FULL_COLOR if (i + _frame / 6) % 6 else accent.lightened(0.3)
			draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += w


func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect.grow(1.0), BAR_BACK)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)


func _text(text: String, pos: Vector2, color: Color, font_size := FONT_SIZE) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_right(text: String, pos: Vector2, color: Color, font_size := FONT_SIZE) -> void:
	draw_string(_font, pos - Vector2(200, 0), text, HORIZONTAL_ALIGNMENT_RIGHT, 200, font_size, color)


func _text_center(text: String, pos: Vector2, color: Color, font_size := FONT_SIZE) -> void:
	draw_string(_font, pos - Vector2(200, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 400, font_size, color)


## Marca a entrada como usada. Depois de trocar de cena este nó já saiu da árvore.
func _handled() -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()

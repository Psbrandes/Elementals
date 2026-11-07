class_name Stage
extends Node2D
## Fase 1, Bairro do Porto (GDD seção 6): três seções com scroll lateral e trava
## de câmera. Cada trava solta suas ondas, uma depois da outra; quando a última
## cai, aparece o "GO" e a câmera volta a seguir o jogador. O chefe Ferrugem
## fecha a terceira seção.
## A fase em jogo vem de Fases (scripts/fases.gd): a fase 2 usa as mesmas regras
## com outras seções, ondas e chefe.
##
## Também organiza o cerco: no máximo 2 inimigos atacam ao mesmo tempo (mais um
## por jogador extra no co-op).
##
## Co-op: `players` tem todos os heróis da partida; `player` é o herói desta
## máquina (no jogo solo, o único). Com o autoload Net em partida online, quem
## manda é o host: o cliente fica em modo `puppet` e só espelha o que chega pela
## rede (scripts/net/net_session.gd).

signal score_changed(score: int)
signal wave_started(wave: int)
signal enemy_damaged(enemy: Enemy)
signal section_entered(index: int, title: String)
signal camera_unlocked
signal boss_appeared(boss: Boss)
signal stage_cleared
## Efeito visual (assets/vfx) num ponto da fase; quem desenha é o View3D.
signal effect_spawned(name: String, at: Vector2, lift: float, flip: bool)
## Texto que sobe do ponto do golpe (dano, CONTRA!, FRACO!, BLOQUEIO). O View3D desenha.
signal popup_spawned(text: String, at: Vector2, lift: float, color: Color)

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const ENEMIES := {
	"capanga": preload("res://data/enemies/capanga.tres"),
	"brigao": preload("res://data/enemies/capanga_brigao.tres"),
	"faca": preload("res://data/enemies/faca.tres"),
	"brutamontes": preload("res://data/enemies/brutamontes.tres"),
	"fundeiro": preload("res://data/enemies/fundeiro.tres"),
	"piromante": preload("res://data/enemies/piromante.tres"),
	"escudeiro": preload("res://data/enemies/escudeiro.tres"),
	"guardiao_gelo": preload("res://data/enemies/guardiao_gelo.tres"),
	"ferrugem": preload("res://data/enemies/ferrugem.tres"),
	# Fase 2 (scripts/fases.gd).
	"sombra": preload("res://data/enemies/sombra.tres"),
	"curandeira": preload("res://data/enemies/curandeira.tres"),
	"corrosao": preload("res://data/enemies/corrosao.tres"),
}

## Largura de referência: travas, scroll e câmera são pensados nela. Telas mais
## largas que 16:9 mostram mais dos dois lados (stretch "expand"), e a arena e os
## pontos de spawn acompanham a largura visível de verdade (view_left/view_right).
const VIEW_WIDTH := 384.0
const STAGE_LENGTH := 3072.0
const FLOOR_TOP := 128.0
const FLOOR_BOTTOM := 208.0
const EDGE_MARGIN := 12.0
## Com a câmera 2.5D em perspectiva, o fundo do chão mostra mais largura que a
## frente: quem nasce lá atrás precisa de mais folga para não surgir na tela.
const PERSPECTIVE_MARGIN := 60.0
## A câmera anda quando o jogador passa deste ponto da tela.
const SCROLL_LEAD := 200.0
const SCROLL_SPEED := 3.0
const NEXT_WAVE_DELAY := 40
## Ondas entram em fila: os 2 primeiros juntos, o resto um a cada SPAWN_STAGGER quadros.
const SPAWN_STAGGER := 28
const SPAWN_AT_ONCE := 2
## Quando sobra 1 inimigo e não vem mais ninguém, ele parte para cima (ritmo).
const LAST_ENEMY_RAGE := true
const MAX_ATTACKERS := 2
const EXTRA_LIFE_SCORE := 20000
const PICKUP_DISTANCE := Vector2(12.0, 8.0)
const TIME_BONUS_SECONDS := 480
const TIME_BONUS_PER_SECOND := 10
const LIFE_BONUS_PER_POINT := 100

## Layout da fase. O "x" de cada trava é a borda esquerda da câmera quando ela trava.
## "overlap": a próxima onda da trava já entra quando sobram tantos inimigos (0 =
## só com a tela limpa), para o ritmo não cair entre uma onda e outra.
## "ambushes": emboscadas no meio do scroll, sem travar a câmera.
## Ritmo: cada seção apresenta um inimigo novo sozinho antes de misturá-lo, e a
## comida vem logo depois dos encontros mais duros.
const SECTIONS := [
	{
		"title": "Rua do cais", "start": 0.0,
		"locks": [
			{"x": 288.0, "waves": [["capanga", "capanga"], ["capanga", "capanga", "capanga"]]},
			{"x": 768.0, "overlap": 1, "waves": [["capanga", "faca", "capanga"], ["escudeiro", "capanga"]]},
		],
		"ambushes": [
			{"x": 520.0, "enemies": ["faca"]},
		],
		"props": [
			{"kind": "lixeira", "x": 520.0, "y": 136.0, "item": "maca"},
			{"kind": "lixeira", "x": 548.0, "y": 140.0, "item": ""},
			{"kind": "barril", "x": 940.0, "y": 140.0, "item": ""},
			{"kind": "caixa", "x": 1110.0, "y": 196.0, "item": "maca"},
		],
	},
	{
		"title": "Armazém", "start": 1152.0,
		"locks": [
			{"x": 1344.0, "overlap": 1, "waves": [["brutamontes", "capanga", "capanga"], ["piromante", "capanga"]]},
			{"x": 1632.0, "waves": [["fundeiro", "fundeiro", "capanga", "brigao"]]},
			{"x": 1920.0, "overlap": 1, "waves": [["escudeiro", "piromante", "brigao"], ["brutamontes", "faca", "fundeiro"]]},
		],
		"ambushes": [
			{"x": 1500.0, "enemies": ["fundeiro", "capanga"]},
		],
		"props": [
			{"kind": "barril", "x": 1460.0, "y": 182.0, "item": ""},
			{"kind": "caixa", "x": 1560.0, "y": 150.0, "item": "frango"},
			{"kind": "barril", "x": 1760.0, "y": 140.0, "item": ""},
			{"kind": "caixa", "x": 1800.0, "y": 134.0, "item": "moedas"},
			{"kind": "caixa", "x": 1830.0, "y": 180.0, "item": ""},
			{"kind": "barril", "x": 2080.0, "y": 190.0, "item": ""},
			{"kind": "lixeira", "x": 2230.0, "y": 150.0, "item": "orbe"},
		],
	},
	{
		"title": "Pátio do porto", "start": 2304.0,
		"locks": [
			{"x": 2400.0, "overlap": 1, "waves": [["capanga", "brigao", "capanga", "faca"], ["guardiao_gelo"],
				["piromante", "escudeiro", "brigao"]]},
			{"x": 2688.0, "waves": [["ferrugem"]], "boss": true},
		],
		"ambushes": [],
		"props": [
			{"kind": "barril", "x": 2560.0, "y": 176.0, "item": ""},
			{"kind": "caixa", "x": 2640.0, "y": 140.0, "item": "orbe"},
			{"kind": "lixeira", "x": 2660.0, "y": 150.0, "item": "frango"},
		],
	},
]

## Seções da fase que está sendo jogada (Fases.sections(): a fase 1 é SECTIONS).
var sections: Array = SECTIONS

## Seção onde a fase recomeça depois de um fim de jogo (continue).
static var continue_section := 0

@export var auto_spawn := true
## Cliente online: nada é simulado aqui, os atores vêm do host.
var puppet := false
## Todos os heróis da partida (co-op). `player` é o desta máquina.
var players: Array = []

var floor_rect := Rect2(EDGE_MARGIN, FLOOR_TOP, VIEW_WIDTH - EDGE_MARGIN * 2.0, FLOOR_BOTTOM - FLOOR_TOP)
var cam_left := 0.0
var locked := false
var section := 0
var wave := 0
var score := 0
var boss: Boss
var cleared := false
## Números da tela de vitória: inimigos derrotados e o maior combo da fase.
var kills := 0
var best_combo := 0
## Resultado congelado na hora da vitória (o HUD mostra e anima a contagem).
var final_results := {}
## O HUD liga quando a contagem da vitória acaba (online, o host só sai depois disso).
var victory_menu_ready := false
var debug_draw := false

var _locks: Array = []
var _lock_index := 0
var _pending_waves: Array = []
var _wave_delay := 0
var _lock_overlap := 0
var _spawn_queue: Array = []
var _spawn_timer := 0
var _ambushes: Array = []
var _attackers: Array = []
var _items: Array = []
var _shake := 0.0
var _next_life_at := EXTRA_LIFE_SCORE
var _frames := 0

@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	Fases.read_args()
	sections = Fases.sections()
	Sound.music(Fases.info()["music"])
	section = clampi(continue_section, 0, sections.size() - 1)
	cam_left = sections[section]["start"]
	_register_player(player)
	_apply_carry()
	var net := get_node_or_null(^"/root/Net")
	if net and net.active:
		# Partida online: a sessão de rede cria os outros heróis e, no cliente,
		# liga o modo puppet (sem ondas nem objetos: tudo vem do host).
		net.attach_stage(self)
	if section > 0:
		for i in players.size():
			players[i].position = Vector2(cam_left + 60.0, 168.0 - i * 16.0)
	for i in sections.size():
		for lock: Dictionary in sections[i]["locks"]:
			if lock["x"] >= cam_left:
				_locks.append(lock)
		for ambush: Dictionary in sections[i].get("ambushes", []):
			if ambush["x"] >= cam_left:
				_ambushes.append(ambush)
	if auto_spawn:
		for i in range(section, sections.size()):
			for prop: Dictionary in sections[i]["props"]:
				_spawn_breakable(prop)
	_update_floor()
	_update_camera_node()
	_announce_section.call_deferred()


func _physics_process(_delta: float) -> void:
	if puppet:
		_update_floor()
		_shake = maxf(_shake - 0.25, 0.0)
		_update_camera_node()
		return
	if not cleared:
		_frames += 1
	_update_camera()
	_update_floor()
	_update_spawns()
	if auto_spawn:
		_update_ambushes()
		_update_lock()
		_update_last_enemy()
	_collect_items()
	_attackers = _attackers.filter(func(e): return is_instance_valid(e) and e.state != Fighter.State.DEAD)
	_shake = maxf(_shake - 0.25, 0.0)
	_update_camera_node()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_hitboxes"):
		debug_draw = not debug_draw
		return
	# Fora do online, o fim de jogo e a vitória têm menu próprio no HUD.
	var net := get_node_or_null(^"/root/Net")
	if not (net and net.active):
		return
	var confirm := event.is_action_pressed(&"attack") or event.is_action_pressed(&"restart")
	if not confirm or not (is_game_over() or cleared) or (cleared and not victory_menu_ready):
		return
	# Online, só o host decide continuar ou voltar; os clientes vão junto.
	if net.is_host():
		net.host_after_stage(cleared, section)


## Continue: recomeça do início da seção atual, com os pontos zerados.
func continue_here() -> void:
	continue_section = section
	get_tree().paused = false
	get_tree().reload_current_scene()


## Joga a fase de novo desde o começo, com o mesmo herói.
func restart_stage() -> void:
	continue_section = 0
	Fases.reset_carry()
	get_tree().paused = false
	get_tree().reload_current_scene()


## Fase concluída: abre a próxima com os pontos e as vidas de agora.
func next_stage() -> void:
	var lives := 0
	for p: Player in players:
		if is_instance_valid(p):
			lives = maxi(lives, p.lives)
	Fases.advance(score, lives)
	continue_section = 0
	get_tree().paused = false
	get_tree().reload_current_scene()


## Pontos e vidas trazidos da fase anterior (só na primeira vez que a fase abre).
func _apply_carry() -> void:
	if Fases.carry.is_empty():
		return
	score = int(Fases.carry.get("score", 0))
	_next_life_at = (score / EXTRA_LIFE_SCORE + 1) * EXTRA_LIFE_SCORE
	player.lives = maxi(int(Fases.carry.get("lives", player.lives)), 1)
	Fases.reset_carry()
	score_changed.emit.call_deferred(score)


func go_to_scene(path: String) -> void:
	continue_section = 0
	Fases.reset_carry()
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


## Fim de jogo: todos os heróis sem vidas.
func is_game_over() -> bool:
	for p: Player in players:
		if not (p.state == Fighter.State.DEAD and p.lives <= 0):
			return false
	return true


func add_player(p: Player) -> void:
	actors.add_child(p)
	_register_player(p)


func _register_player(p: Player) -> void:
	if p in players:
		return
	p.stage = self
	p.combo_ended.connect(_on_combo_ended)
	players.append(p)


func remove_player(p: Player) -> void:
	players.erase(p)
	_attackers = _attackers.filter(func(e): return is_instance_valid(e))
	if is_instance_valid(p):
		p.queue_free()


## Heróis que os inimigos podem perseguir.
func targetable_players() -> Array:
	return players.filter(func(p): return is_instance_valid(p) and p.is_targetable())


func nearest_player(from: Vector2) -> Player:
	var best: Player = null
	for p: Player in targetable_players():
		if best == null or p.position.distance_squared_to(from) < best.position.distance_squared_to(from):
			best = p
	return best if best else player


func elapsed_seconds() -> int:
	return _frames / 60


## Bônus da tela de resultado: vida restante x 100 e tempo abaixo de 8 minutos.
func results() -> Dictionary:
	var life_bonus := 0
	for p: Player in players:
		life_bonus += p.hp * LIFE_BONUS_PER_POINT
	var time_bonus := maxi(TIME_BONUS_SECONDS - elapsed_seconds(), 0) * TIME_BONUS_PER_SECOND
	var deaths := 0
	for p: Player in players:
		if is_instance_valid(p):
			deaths += p.deaths
	return {"life_bonus": life_bonus, "time_bonus": time_bonus, "seconds": elapsed_seconds(), "kills": kills,
		"best_combo": best_combo, "deaths": deaths,
		"rank": stage_rank(elapsed_seconds(), deaths, best_combo)}


## Nota da fase, de D a S: até 3 pontos pelo tempo, 3 por cair pouco e 3 pelo maior combo.
static func stage_rank(seconds: int, deaths: int, combo: int) -> String:
	var points := 0
	points += 3 if seconds < 240 else 2 if seconds < 360 else 1 if seconds < 480 else 0
	points += 3 if deaths == 0 else 2 if deaths <= 2 else 1 if deaths <= 4 else 0
	points += 3 if combo >= 30 else 2 if combo >= 15 else 1 if combo >= 8 else 0
	return "S" if points >= 8 else "A" if points >= 6 else "B" if points >= 4 else "C" if points >= 2 else "D"


# --- Câmera e travas -------------------------------------------------------------

func _update_camera() -> void:
	if not locked:
		# Co-op: segue quem vai mais à frente, sem deixar ninguém para trás da tela.
		var lead := -INF
		var back := INF
		for p: Player in players:
			if not is_instance_valid(p) or (p.state == Fighter.State.DEAD and p.lives <= 0):
				continue
			lead = maxf(lead, p.position.x)
			back = minf(back, p.position.x)
		if lead == -INF:
			lead = player.position.x
			back = lead
		var target := minf(lead - SCROLL_LEAD, back - EDGE_MARGIN * 2.0 - (VIEW_WIDTH - view_width()) / 2.0)
		target = clampf(target, cam_left, STAGE_LENGTH - VIEW_WIDTH)
		cam_left = minf(target, cam_left + SCROLL_SPEED)
		if auto_spawn and _lock_index < _locks.size() and cam_left >= _locks[_lock_index]["x"]:
			cam_left = _locks[_lock_index]["x"]
			_start_lock(_locks[_lock_index])
	var current := 0
	for i in sections.size():
		if cam_left + VIEW_WIDTH / 2.0 >= sections[i]["start"]:
			current = i
	if current != section:
		section = current
		section_entered.emit(section, StageScenery.section_title(section))


func _update_camera_node() -> void:
	var offset := Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	camera.position = Vector2(cam_left + VIEW_WIDTH / 2.0, 108.0)
	camera.offset = offset


func _update_floor() -> void:
	floor_rect = Rect2(view_left() + EDGE_MARGIN, FLOOR_TOP, view_width() - EDGE_MARGIN * 2.0, FLOOR_BOTTOM - FLOOR_TOP)


## Distância além da borda da tela para nascer fora de vista na profundidade y.
func offscreen_margin(y: float, base: float) -> float:
	return base + PERSPECTIVE_MARGIN * inverse_lerp(FLOOR_BOTTOM, FLOOR_TOP, y)


func view_width() -> float:
	if not is_inside_tree():
		return VIEW_WIDTH
	return maxf(get_viewport().get_visible_rect().size.x, VIEW_WIDTH)


## Bordas da tela visível; a câmera fica centrada na janela de referência.
func view_left() -> float:
	return cam_left + (VIEW_WIDTH - view_width()) / 2.0


func view_right() -> float:
	return view_left() + view_width()


func _start_lock(lock: Dictionary) -> void:
	locked = true
	_pending_waves = lock["waves"].duplicate()
	_lock_overlap = int(lock.get("overlap", 0))
	_wave_delay = 20


func _update_lock() -> void:
	if cleared or not locked or not _spawn_queue.is_empty():
		return
	# Com ondas por vir, a próxima entra quando sobram "overlap" inimigos.
	var allowed := _lock_overlap if not _pending_waves.is_empty() else 0
	if enemies().size() > allowed:
		return
	_wave_delay -= 1
	if _wave_delay > 0:
		return
	if not _pending_waves.is_empty():
		_spawn_wave(_pending_waves.pop_front())
		_wave_delay = NEXT_WAVE_DELAY
		return
	var finished: Dictionary = _locks[_lock_index]
	locked = false
	_lock_index += 1
	if finished.get("boss", false):
		_clear_stage()
	else:
		Sound.play("go", -6.0, 0.0)
		camera_unlocked.emit()


func _clear_stage() -> void:
	Sound.stop_music()
	Sound.play("clear", 0.0, 0.0)
	cleared = true
	locked = true
	continue_section = 0
	var bonus := results()
	bonus["score_before"] = score
	score += bonus["life_bonus"] + bonus["time_bonus"]
	bonus["score"] = score
	final_results = bonus
	score_changed.emit(score)
	stage_cleared.emit()


func _announce_section() -> void:
	section_entered.emit(section, StageScenery.section_title(section))


# --- Inimigos ------------------------------------------------------------------------

## Inimigos vivos (os que estão morrendo não contam).
func enemies() -> Array:
	var list := []
	for child in actors.get_children():
		if child is Enemy and child.state != Fighter.State.DEAD and not child.is_queued_for_deletion():
			list.append(child)
	return list


func breakables() -> Array:
	var list := []
	for child in actors.get_children():
		if child is Breakable and child.can_be_hit():
			list.append(child)
	return list


## Inimigo com comportamento próprio (EnemyData.custom_script) ou da cena padrão.
static func make_enemy(data: EnemyData) -> Enemy:
	if data.custom_script:
		return data.custom_script.new()
	var scene := BOSS_SCENE if data.behavior == EnemyData.Behavior.BOSS else ENEMY_SCENE
	return scene.instantiate()


func spawn_enemy(data: EnemyData, at: Vector2) -> Enemy:
	var enemy: Enemy = make_enemy(data)
	enemy.data = data
	enemy.position = at
	enemy.stage = self
	var near := nearest_player(at)
	enemy.facing = 1 if at.x < near.position.x else -1
	enemy.side = -1 if at.x < near.position.x else 1
	enemy.died.connect(_on_enemy_died)
	enemy.health_changed.connect(func(_hp: int, _max_hp: int) -> void: enemy_damaged.emit(enemy))
	actors.add_child(enemy)
	if enemy is Boss:
		boss = enemy
		Sound.play("boss_intro", -3.0, 0.0)
		boss_appeared.emit(boss)
	return enemy


## Inimigos chamados no meio da luta: entram pelas duas laterais.
func spawn_reinforcements(data: EnemyData, count: int) -> void:
	for i in count:
		var from_left := i % 2 == 0
		var y := randf_range(FLOOR_TOP, FLOOR_BOTTOM)
		var x := view_left() - offscreen_margin(y, 24.0) if from_left else view_right() + offscreen_margin(y, 24.0)
		spawn_enemy(data, Vector2(x, y))


func spawn_projectile(_source: Fighter, at: Vector2, dir: int, damage: int, speed: float, ground: bool) -> Projectile:
	var projectile := Projectile.new()
	projectile.stage = self
	projectile.position = at
	projectile.direction = dir
	projectile.damage = damage
	projectile.speed = speed
	projectile.ground = ground
	actors.add_child(projectile)
	return projectile


func notify_enemy_hit(enemy: Fighter) -> void:
	if enemy is Enemy:
		enemy_damaged.emit(enemy)


## Escolhe o lado do jogador com menos inimigos: assim alguém sempre flanqueia.
func pick_side(enemy: Enemy) -> int:
	var left := 0
	var right := 0
	for other: Enemy in enemies():
		if other == enemy:
			continue
		if other.side < 0:
			left += 1
		else:
			right += 1
	if left == right:
		var target: Player = enemy.target if is_instance_valid(enemy.target) else nearest_player(enemy.position)
		return -1 if enemy.position.x < target.position.x else 1
	return -1 if left < right else 1


func request_attack_slot(enemy: Enemy) -> bool:
	if enemy in _attackers:
		return true
	if _attackers.size() >= maxi(MAX_ATTACKERS + Difficulty.extra_attackers(), 1) + maxi(players.size() - 1, 0):
		return false
	_attackers.append(enemy)
	return true


func release_attack_slot(enemy: Enemy) -> void:
	_attackers.erase(enemy)


func attacker_count() -> int:
	return _attackers.size()


func clamp_to_floor(point: Vector2) -> Vector2:
	return point.clamp(floor_rect.position, floor_rect.end)


func fx(name: String, at: Vector2, lift := 0.0, flip := false) -> void:
	effect_spawned.emit(name, at, lift, flip)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func popup(text: String, at: Vector2, lift := 0.0, color := Color.WHITE) -> void:
	popup_spawned.emit(text, at, lift, color)


## Câmera lenta do golpe final (último inimigo da onda ou chefe). O tempo é real,
## então funciona mesmo com o jogo desacelerado.
func slow_motion(scale: float, seconds: float) -> void:
	# Online, só o host desacelera; o cliente recebe o tempo na foto (NetSession).
	if puppet:
		return
	Engine.time_scale = scale
	var timer := get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)
	while score >= _next_life_at:
		for p: Player in players:
			p.add_life()
		_next_life_at += EXTRA_LIFE_SCORE


## Os 2 primeiros entram juntos; o resto vem em fila, alternando os lados.
func _spawn_wave(names: Array) -> void:
	wave += 1
	for i in names.size():
		if i < SPAWN_AT_ONCE:
			_spawn_one(names[i], i)
		else:
			_spawn_queue.append([names[i], i])
	_spawn_timer = SPAWN_STAGGER
	wave_started.emit(wave)


func _spawn_one(name: String, i: int, only_right := false) -> Enemy:
	var data: EnemyData = ENEMIES[name]
	var from_left := i % 2 == 1 and not only_right
	var y := randf_range(FLOOR_TOP, FLOOR_BOTTOM)
	var x := view_right() + offscreen_margin(y, 30.0 + i * 12.0)
	if from_left:
		x = view_left() - offscreen_margin(y, 30.0 + i * 12.0)
	if data.behavior == EnemyData.Behavior.BOSS:
		y = (FLOOR_TOP + FLOOR_BOTTOM) / 2.0
		x = view_right() + offscreen_margin(y, 40.0)
		Sound.music(Fases.info()["boss_music"])
	return spawn_enemy(data, Vector2(x, y))


func _update_spawns() -> void:
	if _spawn_queue.is_empty():
		return
	_spawn_timer -= 1
	if _spawn_timer > 0:
		return
	var entry: Array = _spawn_queue.pop_front()
	_spawn_one(entry[0], entry[1])
	_spawn_timer = SPAWN_STAGGER


## Emboscada: entra pela frente enquanto a câmera ainda rola.
func _update_ambushes() -> void:
	if locked or _ambushes.is_empty() or cam_left < _ambushes[0]["x"]:
		return
	var ambush: Dictionary = _ambushes.pop_front()
	for i in ambush["enemies"].size():
		_spawn_one(ambush["enemies"][i], i, true)


## O último inimigo da trava (sem mais ondas) perde a paciência: acelera e ataca
## sem esperar a vez, para a luta não morrer num inimigo que só rodeia.
func _update_last_enemy() -> void:
	if not LAST_ENEMY_RAGE or not locked or not _pending_waves.is_empty() or not _spawn_queue.is_empty():
		return
	var alive := enemies()
	if alive.size() == 1 and not alive[0] is Boss:
		alive[0].enrage()


func _on_combo_ended(hits: int, bonus: int, _dropped: bool) -> void:
	best_combo = maxi(best_combo, hits)
	if bonus > 0:
		add_score(bonus)


func _on_enemy_died(fighter: Fighter) -> void:
	var enemy := fighter as Enemy
	kills += 1
	add_score(enemy.data.score)
	if enemy.data.drop != "" and randf() < Difficulty.drop_chance(enemy.data.drop_chance):
		spawn_item(enemy.data.drop, clamp_to_floor(enemy.position))


## Explosão em área (bomba, pedra do chefe, barril). Derruba quem estiver no
## círculo e no chão ou perto dele; com `hurts_enemies` acerta os inimigos e
## quebra o cenário também (um barril pode estourar outro).
func explode(at: Vector2, radius: float, damage: int, source: Node2D, hurts_enemies := true, look := "bomba") -> void:
	var targets: Array = players.filter(func(p: Player) -> bool: return is_instance_valid(p))
	if hurts_enemies:
		targets += enemies() + breakables()
	for target: Fighter in targets:
		if target == source or not target.can_be_hit() or target.height > 30.0:
			continue
		var d := (target.position - at).abs()
		if d.x <= radius + target.body_size.x / 2.0 and d.y <= radius * 0.5:
			target.take_hit(damage, true, source)
	shake(4.0)
	Sound.play("stomp" if look == "pedra" else "slash" if look == "lamina" else "hit_heavy", -2.0)
	fx({"pedra": "stomp", "lamina": "special_metal"}.get(look, "special_fogo"), at, 0.0)


func spawn_lob(source: Node2D, from: Vector2, to: Vector2, damage: int, radius: float, flight: int, look := "bomba") -> Lob:
	var lob := Lob.new()
	lob.stage = self
	lob.source = source
	lob.origin = from
	lob.target = clamp_to_floor(to)
	lob.damage = damage
	lob.radius = radius
	lob.flight = flight
	lob.look = look
	actors.add_child(lob)
	return lob


# --- Cenário: objetos quebráveis e itens -------------------------------------------

func _spawn_breakable(prop: Dictionary) -> Breakable:
	var breakable := Breakable.new()
	breakable.kind = prop["kind"]
	breakable.item = prop["item"]
	breakable.position = Vector2(prop["x"], prop["y"])
	breakable.stage = self
	actors.add_child(breakable)
	return breakable


func on_breakable_broken(breakable: Breakable) -> void:
	if breakable.item != "":
		spawn_item(breakable.item, breakable.position + Vector2(0.0, 2.0))


func spawn_item(kind: String, at: Vector2) -> Item:
	var item := Item.new()
	item.kind = kind
	item.position = at
	actors.add_child(item)
	_items.append(item)
	return item


func _collect_items() -> void:
	for p: Player in players:
		if is_instance_valid(p) and p.is_targetable() and p.height <= 8.0:
			_collect_items_for(p)


func _collect_items_for(p: Player) -> void:
	for item: Item in _items.duplicate():
		var d := (item.position - p.position).abs()
		if d.x > PICKUP_DISTANCE.x or d.y > PICKUP_DISTANCE.y:
			continue
		Sound.play("food" if Item.HEAL.has(item.kind) else "coin", -4.0, 0.0)
		fx("heal" if Item.HEAL.has(item.kind) else "coin", item.position, 14.0)
		if Item.HEAL.has(item.kind):
			p.heal(Item.HEAL[item.kind])
		if Item.SCORE.has(item.kind):
			add_score(Item.SCORE[item.kind])
		if Item.METER.has(item.kind):
			p.add_meter(Item.METER[item.kind])
			popup("+ENERGIA", item.position, 24.0, p.element_color())
		_items.erase(item)
		item.queue_free()

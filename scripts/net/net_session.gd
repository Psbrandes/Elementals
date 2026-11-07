extends Node
## Sessão online de uma fase (filho da Stage, criado por Net.attach_stage).
##
## No host: cria um herói para cada cliente (controle `scripted`, alimentado pelos
## comandos que chegam pela rede), numera os atores e, a cada quadro, manda para
## os clientes uma foto compacta de todos eles.
##
## No cliente: a Stage fica em modo puppet. O herói desta máquina e os demais
## atores são nós comuns (Player, Enemy, Breakable...) com a física desligada;
## esta sessão copia neles os números da foto e chama a mesma escolha de quadro
## da arte (_update_sprite), então o View3D e o HUD funcionam sem mudança.
##
## Para jogar pela internet (atraso, variação e perda de pacotes), o cliente:
## - guarda as fotos num buffer e as mostra uma por quadro, na ordem do host, um
##   pouco atrás da mais nova (o quanto atrás se ajusta sozinho à variação da rede);
## - quando falta uma foto (perdida ou host mandando 30 por segundo), interpola as
##   posições entre a anterior e a próxima;
## - prevê o próprio herói andando: aplica os próprios comandos que o host ainda não
##   confirmou por cima da posição mais nova e corrige devagar o que errar. Golpes,
##   pulo e esquiva continuam decididos pelo host (aparecem depois de um "ping").

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const COMPRESSION := FileAccess.COMPRESSION_DEFLATE

enum Kind { PLAYER, ENEMY, BOSS, BREAKABLE, ITEM, PROJECTILE, LOB }

## Bits do golpe atual (só o que a arte e o "!" de aviso precisam).
const ATTACK_FLAGS := ["special", "telegraph", "area", "projectile", "shockwave", "knockdown", "full_art", "special2"]
## Botões mandados como contador (um pacote perdido não engole o aperto).
const ACTIONS := [&"attack", &"jump", &"special", &"dodge"]

var net: Node
var stage: Stage
var host := false
## Cliente: id de rede -> nó.
var _nodes := {}
var _next_nid := 1
## Host: comandos de cada cliente (último contador de cada botão).
var _inputs := {}
## Cliente: comandos locais (teclado/gamepad ou o robô).
var local_input := PlayerInput.new()
var _presses := [0, 0, 0, 0]
var _latest: Array
var _have_snapshot := false
var bot: RefCounted
## Para o vídeo e os testes: quantas fotos chegaram e o tamanho médio.
var snapshots_received := 0
## Cliente: ataques em dupla anunciados pelo host.
var _team_seen := 0
var snapshots_sent := 0
var bytes_sent := 0

## Host: quadro atual (vai em cada foto e evento) e de quantos em quantos quadros sai foto.
var tick := 0
var _send_every := 1

## Cliente: buffer de fotos. false (--sem-suavizar) volta ao jeito antigo: aplica a
## mais nova assim que chega.
var smooth := true
const WINDOW_FRAMES := 180
const MAX_BEHIND := 8
var _buf := {}
var _newest := -1
var _play := -1
var _shown_tick := -1
var _prev_pos := {}
var _prev_cam := 0.0
var _arrivals := []
var _local_frame := 0
var _gap := 1
var _events := []
var _first_tick := -1
var _received_ticks := 0
## Cliente: herói próprio (foto mais nova, comandos ainda não confirmados, correção).
var _own_entry: Array = []
var _seq := 0
var _hist := []
var _ack := 0
var _err := Vector2.ZERO
var _pred_prev := Vector2.ZERO
var _was_pred := false
var _last_step := Vector2.ZERO
var _walk_frame := 0
var rtt_ms := 0.0
## Estatísticas para os testes e o painel (F3).
var stat_frames := 0
var stat_frozen := 0
var stat_jumps := 0
var stat_interp := 0
var stat_late := 0
var stat_pred := 0
var _delay_sum := 0.0
var _delay_n := 0
var _corr_sum := 0.0
var _overlay: Label
var _overlay_on := true
var _toast := ""
var _toast_frames := 0


func setup(owner_net: Node, owner_stage: Stage) -> void:
	net = owner_net
	stage = owner_stage
	host = net.is_host()
	if host:
		_setup_host()
	else:
		_setup_client()
	if net.auto.has("bot"):
		var Bot := load("res://scripts/net/net_bot.gd")
		bot = Bot.new(stage)
	_make_overlay()


func _setup_host() -> void:
	_send_every = 2 if int(net.auto.get("net-rate", "60")) <= 30 else 1
	stage.actors.child_entered_tree.connect(_number_actor)
	stage.player.peer_id = 1
	stage.player.set_meta(&"nid", -1)
	var order: Array = net.peers_in_order()
	var depth := 0
	for id: int in order:
		if id == 1:
			continue
		depth += 1
		var p: Player = PLAYER_SCENE.instantiate()
		p.hero_id = net.lobby[id]["hero"]
		p.peer_id = id
		p.input.scripted = true
		p.position = stage.player.position + Vector2(-16.0 * depth, -18.0 * depth)
		p.set_meta(&"nid", -id)
		stage.add_player(p)
		_inputs[id] = {"move": Vector2.ZERO, "presses": [0, 0, 0, 0]}
	stage.players.sort_custom(func(a, b): return net.slot_of(a.peer_id) < net.slot_of(b.peer_id))
	# Avisos da fase que o HUD do cliente precisa ver.
	stage.section_entered.connect(func(i: int, t: String) -> void: net.send_event("section", [i, t]))
	stage.camera_unlocked.connect(func() -> void: net.send_event("unlocked", []))
	stage.stage_cleared.connect(func() -> void: net.send_event("cleared", [stage.final_results]))
	stage.effect_spawned.connect(func(n: String, at: Vector2, lift: float, flip: bool) -> void:
		net.send_event("fx", [n, at, lift, flip]))
	stage.popup_spawned.connect(func(t: String, at: Vector2, lift: float, color: Color) -> void:
		net.send_event("popup", [t, at, lift, color]))
	for p: Player in stage.players:
		_watch_combo(p)
	if net.auto.has("bot"):
		stage.player.input.scripted = true


func _watch_combo(p: Player) -> void:
	p.combo_ended.connect(func(hits: int, bonus: int, dropped: bool) -> void:
		if is_instance_valid(p):
			net.send_event("combo_end", [p.peer_id, hits, bonus, dropped]))
	# Destaques do combo (CONTRA!, AÉREO...) e nome dos golpes próprios (e da dupla).
	p.combo_event.connect(func(text: String) -> void:
		if is_instance_valid(p):
			net.send_event("combo_event", [p.peer_id, text]))
	p.move_used.connect(func(label: String, color: Color) -> void:
		if is_instance_valid(p):
			net.send_event("move", [p.peer_id, label, color, HeroMoves.team_attacks if HeroMoves.is_team_name(label) else 0]))


func _setup_client() -> void:
	stage.puppet = true
	stage.auto_spawn = false
	var me: Player = stage.player
	me.peer_id = net.my_id()
	me.set_physics_process(false)
	_nodes[-me.peer_id] = me
	local_input.scripted = net.auto.has("bot")
	smooth = not net.auto.has("sem-suavizar")


func _number_actor(node: Node) -> void:
	if not node.has_meta(&"nid"):
		node.set_meta(&"nid", _next_nid)
		_next_nid += 1


func on_peer_left(id: int) -> void:
	_inputs.erase(id)
	for p: Player in stage.players.duplicate():
		if p.peer_id == id:
			stage.remove_player(p)


func _physics_process(_delta: float) -> void:
	if net.auto.has("log") and Engine.get_physics_frames() % 300 == 0:
		_log()
	if bot:
		bot.drive(stage.player, stage.player.input if host else local_input, host)
	if host:
		tick += 1
		_feed_remote_players()
		if tick % _send_every == 0:
			_send_snapshot()
	else:
		_local_frame += 1
		stat_frames += 1
		_send_input()
		if smooth:
			_advance_playback()
			_flush_events()
			_update_own()
		elif _have_snapshot:
			var advance := _newest - _shown_tick
			if _shown_tick >= 0 and advance > _gap:
				stat_jumps += 1
			_shown_tick = _newest
			_apply(_latest)
			_have_snapshot = false
		elif _shown_tick >= 0:
			stat_frozen += 1
	_update_overlay()


## Host: quadro dos eventos emitidos agora (os atores rodam antes da sessão, então o
## evento pertence à foto que sai no fim deste quadro).
func event_tick() -> int:
	return tick + 1


## Resumo para os testes (--log): quem está na fase e quanto a rede está mandando.
func _log() -> void:
	var heroes := []
	for p: Player in stage.players:
		if is_instance_valid(p):
			heroes.append("%s(peer %d) x=%d y=%d hp=%d %s" % [p.character["name"], p.peer_id, p.position.x,
				p.position.y, p.hp, Fighter.State.keys()[p.state]])
	var traffic := "enviadas=%d media=%dB" % [snapshots_sent, bytes_sent / maxi(snapshots_sent, 1)] if host \
		else "recebidas=%d %s" % [snapshots_received, net_stats_text()]
	print("[%s] fps=%d t=%ds cam=%d onda=%d pontos=%d inimigos=%d duplas=%d fotos %s | %s" % ["HOST" if host else "CLIENTE",
		Engine.get_frames_per_second(), Engine.get_physics_frames() / 60, stage.cam_left, stage.wave, stage.score,
		stage.enemies().size(), HeroMoves.team_attacks if host else _team_seen, traffic, " ; ".join(heroes)])


# --- Comandos -------------------------------------------------------------------

## Cliente: direção + contadores de cada botão. Contadores (em vez de "apertou
## agora") fazem um pacote perdido não engolir um golpe: o host vê a diferença.
func _send_input() -> void:
	local_input.poll()
	if local_input.attack:
		_presses[0] += 1
	if local_input.jump:
		_presses[1] += 1
	if local_input.special:
		_presses[2] += 1
	if local_input.dodge:
		_presses[3] += 1
	_seq += 1
	var pressed := local_input.attack or local_input.jump or local_input.special or local_input.dodge
	_hist.append([_seq, local_input.move, pressed, Time.get_ticks_usec() / 1000.0])
	if _hist.size() > 240:
		_hist.pop_front()
	var data := PackedByteArray()
	data.resize(9)
	data.encode_s8(0, int(local_input.move.x))
	data.encode_s8(1, int(local_input.move.y))
	for i in 4:
		data.encode_u8(2 + i, _presses[i] % 256)
	# Botões segurados: J (golpe carregado) e K (altura do pulo).
	data.encode_u8(6, (1 if local_input.attack_held else 0) | (2 if local_input.jump_held else 0))
	data.encode_u16(7, _seq % 65536)
	net.send_input(data)


func on_client_input(id: int, data: PackedByteArray) -> void:
	if not _inputs.has(id) or data.size() < 7:
		return
	var state: Dictionary = _inputs[id]
	state["move"] = Vector2(data.decode_s8(0), data.decode_s8(1))
	for i in 4:
		var count := data.decode_u8(2 + i)
		var before: int = state["presses"][i]
		state["presses"][i] = count
		state.get_or_add("pending", [0, 0, 0, 0])[i] += (count - before + 256) % 256
	var held := data.decode_u8(6)
	state["attack_held"] = held & 1 != 0
	state["jump_held"] = held & 2 != 0
	if data.size() >= 9:
		state["seq"] = data.decode_u16(7)


func _feed_remote_players() -> void:
	for p: Player in stage.players:
		if not is_instance_valid(p) or not _inputs.has(p.peer_id):
			continue
		var state: Dictionary = _inputs[p.peer_id]
		# Confirmação para a predição do cliente: o comando que o herói usou neste
		# quadro foi o entregue no quadro anterior.
		state["ack"] = state.get("fed", 0)
		state["fed"] = state.get("seq", 0)
		p.input.move = state["move"]
		p.input.attack_held = state.get("attack_held", false)
		p.input.jump_held = state.get("jump_held", true)
		var pending: Array = state.get_or_add("pending", [0, 0, 0, 0])
		for i in 4:
			# Um aperto por quadro: dois apertos no mesmo pacote viram dois quadros seguidos.
			if pending[i] > 0:
				p.input.press(ACTIONS[i])
				pending[i] -= 1


# --- Foto (host) -------------------------------------------------------------------

func _send_snapshot() -> void:
	var boss_nid := 0
	if is_instance_valid(stage.boss):
		boss_nid = stage.boss.get_meta(&"nid", 0)
	var header := [stage.cam_left, stage.locked, stage.section, stage.score, stage.wave, stage.cleared,
		stage._shake, stage._frames, boss_nid, Engine.time_scale, _send_every]
	var actors := []
	for node in stage.actors.get_children():
		if node.is_queued_for_deletion() or not node.has_meta(&"nid"):
			continue
		var entry := _pack(node)
		if not entry.is_empty():
			actors.append(entry)
	var bytes := var_to_bytes([header, actors]).compress(COMPRESSION)
	snapshots_sent += 1
	bytes_sent += bytes.size()
	net.send_snapshot(tick, bytes)


func _pack(node: Node) -> Array:
	var nid: int = node.get_meta(&"nid")
	if node is Player:
		var p: Player = node
		return [nid, Kind.PLAYER, p.hero_id if p.hero_id != "" else p.character["id"]] + _fighter(p) + [
			p.meter, p.lives, p.combo_hits, p.combo_bonus(), p._jump_kicking, p._kick_frame, p._knee_timer,
			p.vz, p.peer_id, p._frame, _player_extra(p)]
	if node is Boss:
		return [nid, Kind.BOSS, node.data.resource_path] + _fighter(node) + [node._art_frame, _enemy_extra(node),
			node.phase, node._leap_to]
	if node is Enemy:
		return [nid, Kind.ENEMY, node.data.resource_path] + _fighter(node) + [node._art_frame, _enemy_extra(node)]
	if node is Breakable:
		return [nid, Kind.BREAKABLE, node.kind, node.position.x, node.position.y, node.state, node.state_frame,
			node.fuse, node.wobble, node.flash]
	if node is Lob:
		return [nid, Kind.LOB, node.look, node.position.x, node.position.y, node.origin, node.target, node.flight,
			node.peak, node.radius, node.frame, node.height]
	if node is Item:
		return [nid, Kind.ITEM, node.kind, node.position.x, node.position.y]
	if node is Projectile:
		return [nid, Kind.PROJECTILE, node.art, node.position.x, node.position.y, node.direction, node.ground,
			node._frame]
	return []


func _fighter(f: Fighter) -> Array:
	var attack: Variant = null
	if not f.current_attack.is_empty():
		var a := f.current_attack
		var flags := 0
		for i in ATTACK_FLAGS.size():
			if a.get(ATTACK_FLAGS[i], false):
				flags |= 1 << i
		attack = [a.get("name", ""), a.get("startup", 0), a.get("active", 0), a.get("recovery", 0),
			a.get("far", 0.0), a.get("y_hi", 40.0), flags, a.get("anim", "")]
	return [f.position.x, f.position.y, f.height, f.facing, f.state, f.state_frame, f.flash, f.invuln,
		f.hp, f.max_hp, f._airborne, attack]


## Estado do herói que muda a arte ou o HUD (movimentação, golpes próprios, nota).
func _player_extra(p: Player) -> Dictionary:
	var m := p.movement
	return {"air_move": p._air_move, "charge": p._charge, "style": p.combo_style, "timer": p._combo_timer,
		"dmg": p._combo_damage, "mv": [m.dodge, m.dodge_frame, m.skid, m.running, m.vault_frame],
		"hs": p.hitstop, "jit": p._jitter, "vel": p.velocity, "rd": m.run_dir,
		"ack": _inputs[p.peer_id].get("ack", 0) if _inputs.has(p.peer_id) else 0}


## Estado do inimigo que muda a arte: escudo, esquiva, cor (gelo, queimadura, fase do chefe).
func _enemy_extra(e: Enemy) -> Dictionary:
	return {"blk": e._block_frames, "dodge": e._dodge, "mod": e.sprite.modulate if e.sprite else Color.WHITE,
		"hs": e.hitstop, "jit": e._jitter, "rage": e.enraged}


# --- Foto (cliente) ------------------------------------------------------------------

func on_snapshot(snap_tick: int, data: PackedByteArray) -> void:
	snapshots_received += 1
	var decoded: Variant = bytes_to_var(data.decompress_dynamic(-1, COMPRESSION))
	if not decoded is Array or decoded.size() != 2:
		return
	if not smooth:
		# Jeito antigo: só a mais nova importa (uma atrasada é jogada fora).
		if snap_tick <= _newest:
			stat_late += 1
			return
		_newest = snap_tick
		_latest = decoded
		_have_snapshot = true
		return
	if snap_tick <= _play or _buf.has(snap_tick):
		stat_late += 1
		return
	if _first_tick < 0:
		_first_tick = snap_tick
	_received_ticks += 1
	_buf[snap_tick] = decoded
	_arrivals.append([_local_frame, snap_tick - _local_frame])
	if snap_tick > _newest:
		_newest = snap_tick
		var header: Array = decoded[0]
		if header.size() > 10:
			_gap = maxi(int(header[10]), 1)
		var my_nid: int = -net.my_id()
		for entry: Array in decoded[1]:
			if entry[0] == my_nid:
				_own_entry = entry
				_on_ack(int(entry[25].get("ack", 0)))
				break


# --- Buffer e interpolação (cliente) -------------------------------------------------

## Mostra um quadro do host por quadro local, `atraso` atrás da foto mais nova. O
## atraso é o mínimo que, nos últimos 3 s, teria dado tempo de todas as fotos chegarem.
## Se ficou para trás anda 2 por quadro; se está na frente, espera um quadro.
func _advance_playback() -> void:
	if _newest < 0:
		return
	while not _arrivals.is_empty() and _arrivals[0][0] < _local_frame - WINDOW_FRAMES:
		_arrivals.pop_front()
	var min_offset := _newest - _local_frame
	for a: Array in _arrivals:
		min_offset = mini(min_offset, a[1])
	var target := _local_frame + min_offset - _gap
	if _play < 0:
		_play = target - 1
	var behind := target - _play
	var step := 1
	if behind > MAX_BEHIND:
		_play = target - 1
		stat_jumps += 1
	elif behind >= 3:
		step = 2
		stat_jumps += 1
	elif behind <= -2:
		step = 0
	_play += step
	if step == 0:
		stat_frozen += 1
	else:
		_render(_play)
	_delay_sum = lerpf(_delay_sum, float(_newest - _play), 0.02)
	_delay_n += 1


func _render(t: int) -> void:
	if _buf.has(t):
		_apply(_buf[t])
		_shown_tick = t
		for k: int in _buf.keys():
			if k <= t:
				_buf.erase(k)
		return
	var next := -1
	for k: int in _buf.keys():
		if k > t and (next < 0 or k < next):
			next = k
	if next < 0 or _shown_tick < 0:
		stat_frozen += 1
		return
	# Falta esta foto: posições no meio do caminho entre a última e a próxima.
	stat_interp += 1
	var w := float(t - _shown_tick) / float(next - _shown_tick)
	var snap: Array = _buf[next]
	stage.cam_left = lerpf(_prev_cam, snap[0][0], w)
	for entry: Array in snap[1]:
		var node: Node = _nodes.get(entry[0])
		var prev: Array = _prev_pos.get(entry[0], [])
		if node == null or not is_instance_valid(node) or prev.is_empty():
			continue
		node.position = Vector2(lerpf(prev[0], entry[3], w), lerpf(prev[1], entry[4], w))
		if node is Fighter:
			node.height = lerpf(prev[2], entry[5], w)
			if node.state == entry[7]:
				node.state_frame += 1
		if node is CanvasItem:
			node.queue_redraw()


func queue_event(event_tick: int, kind: String, args: Array) -> void:
	if not smooth:
		on_event(kind, args)
		return
	_events.append([event_tick, kind, args])


## Eventos tocam junto com a foto do mesmo quadro.
func _flush_events() -> void:
	while not _events.is_empty() and (_events[0][0] <= _play or _events.size() > 400):
		var ev: Array = _events.pop_front()
		on_event(ev[1], ev[2])


# --- Herói próprio (cliente) -------------------------------------------------------

func _on_ack(ack16: int) -> void:
	var full := _seq - ((_seq - ack16) & 0xFFFF)
	if full <= _ack:
		return
	_ack = full
	for h: Array in _hist:
		if h[0] == full:
			var sample: float = Time.get_ticks_usec() / 1000.0 - h[3]
			rtt_ms = sample if rtt_ms == 0.0 else lerpf(rtt_ms, sample, 0.1)
			break
	while not _hist.is_empty() and _hist[0][0] < _ack:
		_hist.pop_front()


## Andando, o próprio herói não espera o host: parte da posição mais nova que o host
## mandou e refaz os passos dos comandos que ele ainda não usou. Erros pequenos
## (o host viu outra coisa) somem aos poucos em vez de dar um tranco.
func _update_own() -> void:
	var me: Player = stage.player
	var predicting := _predict(me)
	var now := me.position
	var correction := Vector2.ZERO
	if predicting:
		correction = _pred_prev + _last_step - now
	elif _was_pred:
		correction = _pred_prev - now
	_err = _err * 0.8 + correction
	_corr_sum += correction.length()
	if _err.length() > 48.0 or _err.length() < 0.05:
		_err = Vector2.ZERO
	_pred_prev = now
	_was_pred = predicting
	if _err != Vector2.ZERO:
		me.position = now + _err
		me.queue_redraw()


func _predict(me: Player) -> bool:
	var e := _own_entry
	if e.is_empty() or net.auto.has("sem-predicao"):
		return false
	var x: Dictionary = e[25]
	var mv: Array = x["mv"]
	if not int(e[7]) in [Fighter.State.IDLE, Fighter.State.WALK] or float(e[5]) != 0.0 or int(mv[0]) != 0 \
			or int(mv[4]) != 0 or int(x["hs"]) > 0 or me.state == Fighter.State.DEAD:
		return false
	stat_pred += 1
	var pos := Vector2(e[3], e[4])
	var vel: Vector2 = x.get("vel", Vector2.ZERO)
	var running: bool = mv[3]
	var run_dir := int(x.get("rd", 0))
	var facing := int(e[6])
	var base := me._walk_speed()
	var move := Vector2.ZERO
	_last_step = Vector2.ZERO
	for h: Array in _hist:
		if h[0] <= _ack:
			continue
		if h[2]:
			break # apertou golpe/pulo/esquiva: daqui em diante quem decide é o host
		move = h[1]
		if running and int(move.x) != run_dir:
			running = false
		var target := move * base
		var accel := Vector2(PlayerMovement.WALK_ACCEL_FRAMES, PlayerMovement.WALK_ACCEL_FRAMES)
		if running:
			target.x = run_dir * base.x * PlayerMovement.RUN_MULT
			target.y = move.y * base.y * PlayerMovement.RUN_DEPTH_MULT
			accel.x = PlayerMovement.RUN_ACCEL_FRAMES
		if target.x != 0.0 and signf(target.x) != signf(vel.x):
			vel.x = 0.0
		if target.y != 0.0 and signf(target.y) != signf(vel.y):
			vel.y = 0.0
		vel.x = _approach(vel.x, target.x, base.x, accel.x)
		vel.y = _approach(vel.y, target.y, base.y, accel.y)
		var before := pos
		me.position = pos + vel * Fighter.DT
		me._keep_inside_arena()
		pos = me.position
		_last_step = pos - before
		if move.x != 0.0:
			facing = int(move.x)
	me.position = pos
	me.height = 0.0
	me.facing = facing
	var walking := move != Vector2.ZERO or vel.length_squared() > 1.0
	var want := Fighter.State.WALK if walking else Fighter.State.IDLE
	_walk_frame += 1
	if me.state != want:
		me.state = want
		me.state_frame = _walk_frame
		me.current_attack = {}
	me.movement.running = running
	me._update_sprite()
	me.queue_redraw()
	return true


func _approach(value: float, target: float, speed: float, frames: float) -> float:
	var amount := speed / PlayerMovement.WALK_DECEL_FRAMES if absf(target) < absf(value) \
		else absf(target) / maxf(frames, 1.0)
	if value < target:
		return minf(value + amount, target)
	return maxf(value - amount, target)


# --- Foto (cliente) ------------------------------------------------------------------

func _apply(decoded: Array) -> void:
	var header: Array = decoded[0]
	_apply_header(header)
	var seen := {}
	for entry: Array in decoded[1]:
		var nid: int = entry[0]
		seen[nid] = true
		var node: Node = _nodes.get(nid)
		if node == null or not is_instance_valid(node):
			node = _create(entry)
			if node == null:
				continue
			_nodes[nid] = node
		_unpack(node, entry)
		_prev_pos[nid] = [entry[3], entry[4], float(entry[5]) if node is Fighter else 0.0]
	_prev_cam = stage.cam_left
	for nid in _nodes.keys():
		if seen.has(nid):
			continue
		var gone: Node = _nodes[nid]
		_nodes.erase(nid)
		_prev_pos.erase(nid)
		if not is_instance_valid(gone) or gone == stage.player:
			continue
		if gone is Player:
			stage.remove_player(gone)
		else:
			gone.queue_free()
	var boss_nid: int = header[8]
	if boss_nid != 0 and _nodes.has(boss_nid) and stage.boss != _nodes[boss_nid]:
		stage.boss = _nodes[boss_nid]
		stage.boss_appeared.emit(stage.boss)


func _apply_header(h: Array) -> void:
	stage.cam_left = h[0]
	stage.locked = h[1]
	stage.section = h[2]
	if stage.score != h[3]:
		stage.score = h[3]
		stage.score_changed.emit(stage.score)
	if stage.wave != h[4]:
		stage.wave = h[4]
		stage.wave_started.emit(stage.wave)
	stage.cleared = h[5]
	stage._shake = maxf(stage._shake, h[6])
	stage._frames = h[7]
	# Câmera lenta do golpe final: só o host decide; aqui ela só desacelera os
	# efeitos e as animações locais (a simulação vem do host).
	if h.size() > 9 and not is_equal_approx(Engine.time_scale, h[9]):
		Engine.time_scale = h[9]


func _create(entry: Array) -> Node:
	var kind: int = entry[1]
	var node: Node
	match kind:
		Kind.PLAYER:
			var p: Player = PLAYER_SCENE.instantiate()
			p.hero_id = entry[2]
			p.peer_id = -int(entry[0])
			p.position = Vector2(entry[3], entry[4])
			stage.add_player(p)
			p.set_physics_process(false)
			stage.players.sort_custom(func(a, b): return net.slot_of(a.peer_id) < net.slot_of(b.peer_id))
			return p
		Kind.ENEMY, Kind.BOSS:
			var data: EnemyData = load(entry[2])
			var enemy: Enemy = Stage.make_enemy(data)
			enemy.data = data
			enemy.ai_enabled = false
			enemy.stage = stage
			enemy.health_changed.connect(func(_hp: int, _max: int) -> void: stage.enemy_damaged.emit(enemy))
			node = enemy
		Kind.BREAKABLE:
			var b := Breakable.new()
			b.kind = entry[2]
			b.stage = stage
			node = b
		Kind.ITEM:
			var item := Item.new()
			item.kind = entry[2]
			node = item
		Kind.LOB:
			var lob := Lob.new()
			lob.stage = stage
			lob.look = entry[2]
			lob.origin = entry[5]
			lob.target = entry[6]
			lob.flight = entry[7]
			lob.peak = entry[8]
			lob.radius = entry[9]
			node = lob
		Kind.PROJECTILE:
			var shot := Projectile.new()
			shot.stage = stage
			shot.art = entry[2]
			shot.direction = entry[5]
			shot.ground = entry[6]
			node = shot
		_:
			return null
	node.position = Vector2(entry[3], entry[4])
	stage.actors.add_child(node)
	if kind != Kind.ITEM:
		node.set_physics_process(false)
	return node


func _unpack(node: Node, e: Array) -> void:
	node.position = Vector2(e[3], e[4])
	match int(e[1]):
		Kind.PLAYER:
			var p: Player = node
			_unpack_fighter(p, e)
			var i := 15
			p.meter = e[i]
			p.lives = e[i + 1]
			if e[i + 2] > p.combo_hits:
				p.combo_hits = e[i + 2]
				p.combo_changed.emit(p.combo_hits, e[i + 3])
			p.combo_hits = e[i + 2]
			var x: Dictionary = e[i + 10]
			p._combo_damage = x["dmg"]
			p.combo_style = x["style"]
			p._combo_timer = x["timer"]
			p._air_move = x["air_move"]
			p._charge = x["charge"]
			p.hitstop = x["hs"]
			p._jitter = x["jit"]
			var mv: Array = x["mv"]
			p.movement.dodge = mv[0]
			p.movement.dodge_frame = mv[1]
			p.movement.skid = mv[2]
			p.movement.running = mv[3]
			p.movement.vault_frame = mv[4]
			p._jump_kicking = e[i + 4]
			p._kick_frame = e[i + 5]
			p._knee_timer = e[i + 6]
			p.vz = e[i + 7]
			p._frame = e[i + 9]
			p._update_sprite()
		Kind.ENEMY, Kind.BOSS:
			var enemy: Enemy = node
			var before := enemy.hp
			_unpack_fighter(enemy, e)
			enemy._art_frame = e[15]
			var x: Dictionary = e[16]
			enemy._block_frames = x["blk"]
			enemy._dodge = x["dodge"]
			enemy.hitstop = x["hs"]
			enemy._jitter = x["jit"]
			enemy.enraged = x["rage"]
			if int(e[1]) == Kind.BOSS:
				var boss: Boss = enemy
				boss._leap_to = e[18]
				if boss.phase != e[17]:
					boss.phase = e[17]
					boss.body_color = boss.data.phase_two_color
			if enemy.hp < before:
				stage.enemy_damaged.emit(enemy)
			enemy._update_sprite()
			if enemy.sprite:
				enemy.sprite.modulate = x["mod"]
		Kind.BREAKABLE:
			var b: Breakable = node
			b.state = e[5]
			b.state_frame = e[6]
			b.fuse = e[7]
			b.wobble = e[8]
			b.flash = e[9]
		Kind.PROJECTILE:
			node._frame = e[7]
		Kind.LOB:
			var lob: Lob = node
			lob.frame = e[10]
			lob.height = e[11]
	if node is CanvasItem:
		node.queue_redraw()


func _unpack_fighter(f: Fighter, e: Array) -> void:
	f.height = e[5]
	f.facing = e[6]
	f.state = e[7]
	f.state_frame = e[8]
	f.flash = e[9]
	f.invuln = e[10]
	f.max_hp = e[12]
	f.hp = e[11]
	f._airborne = e[13]
	var a: Variant = e[14]
	if a == null:
		f.current_attack = {}
	else:
		var attack := {"name": a[0], "startup": a[1], "active": a[2], "recovery": a[3], "far": a[4], "y_hi": a[5]}
		for i in ATTACK_FLAGS.size():
			if int(a[6]) & (1 << i):
				attack[ATTACK_FLAGS[i]] = true
		if a.size() > 7 and a[7] != "":
			attack["anim"] = a[7]
		f.current_attack = attack


# --- Eventos -------------------------------------------------------------------------

func on_event(kind: String, args: Array) -> void:
	match kind:
		"fx":
			stage.fx(args[0], args[1], args[2], args[3])
		"section":
			stage.section_entered.emit(args[0], args[1])
		"unlocked":
			stage.camera_unlocked.emit()
		"cleared":
			if args.size() > 0:
				stage.final_results = args[0]
			stage.cleared = true
			stage.stage_cleared.emit()
		"popup":
			stage.popup(args[0], args[1], args[2], args[3])
		"combo_event":
			for p: Player in stage.players:
				if p.peer_id == args[0]:
					p.combo_event.emit(args[1])
		"move":
			if args.size() > 3:
				_team_seen = maxi(_team_seen, args[3])
			for p: Player in stage.players:
				if p.peer_id == args[0]:
					p.move_used.emit(args[1], args[2])
		"combo_end":
			for p: Player in stage.players:
				if p.peer_id == args[0]:
					p.combo_ended.emit(args[1], args[2], args[3])
		"sound_play":
			Sound.play(args[0], args[1], args[2])
		"sound_special":
			Sound.special(args[0])
		"sound_music":
			Sound.music(args[0], args[1] if args.size() > 1 else true)
		"sound_stop_music":
			Sound.stop_music()


# --- Painel de rede (F3) e simulador (F8) -----------------------------------------

func _make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_overlay = Label.new()
	_overlay.add_theme_font_size_override(&"font_size", 7)
	_overlay.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	_overlay.add_theme_constant_override(&"shadow_offset_x", 1)
	_overlay.add_theme_constant_override(&"shadow_offset_y", 1)
	_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_overlay)
	# Canto de baixo, à direita: em cima ficam a pontuação e o contador de combo.
	_overlay.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_overlay.offset_left = -244.0
	_overlay.offset_right = -4.0
	_overlay.offset_top = -24.0
	_overlay.offset_bottom = -2.0
	_overlay.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_overlay.modulate = Color(1, 1, 1, 0.75)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		_overlay_on = not _overlay_on
	elif key.keycode == KEY_F8:
		_toast = "F8: " + net.next_sim_profile()
		_toast_frames = 150


func _update_overlay() -> void:
	if _overlay == null:
		return
	_overlay.visible = _overlay_on
	if not _overlay_on or Engine.get_physics_frames() % 15 != 0:
		return
	var lines := []
	if host:
		var pings := []
		var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		for id: int in _inputs.keys():
			var peer: ENetPacketPeer = enet.get_peer(id) if enet else null
			if peer:
				pings.append("P%d %d ms" % [net.slot_of(id) + 1,
					peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)])
		lines.append("HOST  ping " + ("  ".join(pings) if not pings.is_empty() else "-"))
	else:
		lines.append(net_stats_text(true))
	var sim: String = net.sim_text()
	if _toast_frames > 0:
		_toast_frames -= 15
		lines.append(_toast)
	elif sim != "":
		lines.append(sim)
	_overlay.text = "\n".join(lines)


func net_stats_text(short := false) -> String:
	var expected := (_newest - _first_tick) / maxi(_gap, 1) + 1 if _first_tick >= 0 else 0
	var loss := 100.0 * (1.0 - float(_received_ticks) / float(expected)) if expected > 0 and smooth else 0.0
	var delay := _delay_sum
	if short:
		return "ping %d ms   espera %d ms   perda %d%%" % [rtt_ms, delay * 1000.0 / 60.0, maxf(loss, 0.0)]
	var f := float(maxi(stat_frames, 1))
	return "suave=%s ping=%dms espera=%.1fq perda=%.1f%% congelados=%.1f%% saltos=%.1f%% interp=%.1f%% predito=%.0f%% correcao=%.2fpx/q atrasadas=%d" % [
		"sim" if smooth else "nao", rtt_ms, delay, maxf(loss, 0.0), 100.0 * stat_frozen / f, 100.0 * stat_jumps / f,
		100.0 * stat_interp / f, 100.0 * stat_pred / f, _corr_sum / f, stat_late]

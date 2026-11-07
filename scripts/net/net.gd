extends Node
## Co-op online (autoload "Net"): de 2 a 4 jogadores com a rede nativa do Godot
## (ENet, UDP). Um jogador cria a sala (host) e os outros entram pelo IP dele.
##
## Modelo: o host é a autoridade. Só ele roda a lógica da fase (inimigos, golpes,
## dano, itens). Cada cliente manda os próprios comandos para o host a cada
## quadro e recebe de volta uma "foto" de todos os atores (net_session.gd), que
## ele só desenha. Assim a lógica do combate não sabe nada de rede: o herói de
## um cliente, no host, é um Player comum com o controle em modo `scripted`.
##
## Todo RPC passa por este autoload (o caminho /root/Net existe em todas as
## máquinas, em qualquer cena), e a sessão da fase é avisada daqui.
##
## Linha de comando (para testes e vídeo), depois de "--":
##   --net-host [--players=2]      cria a sala e começa quando todos estiverem prontos
##   --net-join=127.0.0.1          entra na sala desse IP
##   --hero=<id>  --name=<nome>  --port=<porta>  --bot (um robô joga por você)
##   --lag=<ms> --jitter=<ms> --loss=<%>  simula internet ruim no que ESTA instância manda
##                                        (F8 na fase troca entre perfis prontos)
##   --net-rate=<30|60>                   fotos por segundo do host (padrão 60)
##   --sem-suavizar                       cliente sem buffer/interpolação/predição (para comparar)

signal lobby_changed
signal connection_failed(reason: String)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"

## Em partida online (na sala ou na fase).
var active := false
## Na fase (a sala recusa quem chega depois disso).
var in_game := false
## peer_id -> {"name", "hero", "ready", "slot"}
var lobby := {}
## Mensagem para mostrar na sala (conexão caiu, sala cheia...).
var last_error := ""
var port := DEFAULT_PORT
## Muda a cada (re)início da fase: fotos da fase anterior que chegarem atrasadas são ignoradas.
var match_gen := 0
## Sessão da fase atual (net_session.gd), ou null.
var session: Node
## Opções da linha de comando.
var auto := {}

var _relay_sounds := false

# --- Simulador de internet ruim (só para testes) ------------------------------------
## Atraso de ida (ms), variação aleatória extra (ms) e perda (%) do que esta instância
## manda. Pacotes confiáveis (eventos, sala) só atrasam, nunca se perdem, como no ENet.
var sim_lag_ms := 0.0
var sim_jitter_ms := 0.0
var sim_loss := 0.0
var sim_dropped := 0
## Perfis do F8: [nome, atraso, variação, perda].
const SIM_PROFILES := [["sem simulação", 0, 0, 0], ["rede boa (40 ms)", 20, 5, 0],
	["Brasil-Brasil (80 ms)", 40, 15, 1], ["longe (160 ms)", 80, 30, 3], ["ruim (250 ms, 8% perda)", 125, 60, 8]]
var sim_profile := 0
var _outbox := []
var _last_reliable_at := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_read_cmdline()


func _read_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.substr(2).split("=", true, 1)
			auto[parts[0]] = parts[1] if parts.size() > 1 else "1"
	if auto.has("port"):
		port = int(auto["port"])
	if auto.has("hero"):
		Characters.selected = auto["hero"]
	sim_lag_ms = float(auto.get("lag", "0"))
	sim_jitter_ms = float(auto.get("jitter", "0"))
	sim_loss = float(auto.get("loss", "0"))
	if auto.has("net-host") or auto.has("net-join"):
		(func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE)).call_deferred()


# --- Conexão ---------------------------------------------------------------------

func host(player_name: String, use_port := DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(use_port, MAX_PLAYERS - 1)
	if err != OK:
		last_error = "Não deu para abrir a porta %d (%s)." % [use_port, error_string(err)]
		return err
	port = use_port
	multiplayer.multiplayer_peer = peer
	active = true
	lobby = {1: {"name": player_name, "hero": Characters.selected, "ready": false, "slot": 0}}
	last_error = ""
	lobby_changed.emit()
	return OK


func join(address: String, player_name: String, use_port := DEFAULT_PORT) -> Error:
	leave()
	# Aceita "ip:porta" (ou "nome-do-pc:porta", com Tailscale/MagicDNS).
	if address.count(":") == 1 and address.get_slice(":", 1).is_valid_int():
		use_port = int(address.get_slice(":", 1))
		address = address.get_slice(":", 0)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, use_port)
	if err != OK:
		last_error = "Endereço inválido (%s)." % error_string(err)
		return err
	port = use_port
	multiplayer.multiplayer_peer = peer
	active = true
	lobby = {}
	last_error = ""
	set_meta(&"pending_name", player_name)
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	in_game = false
	lobby = {}
	session = null
	_relay_sounds = false
	_outbox.clear()


func is_host() -> bool:
	return active and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


## Jogadores na ordem de entrada (P1 é sempre o host).
func peers_in_order() -> Array:
	var ids := lobby.keys()
	ids.sort_custom(func(a, b): return lobby[a]["slot"] < lobby[b]["slot"])
	return ids


func slot_of(peer_id: int) -> int:
	return lobby[peer_id]["slot"] if lobby.has(peer_id) else 99


## Endereços IPv4 desta máquina na rede local, para o host passar aos amigos.
func local_addresses() -> Array:
	var vpn := []
	var list := []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			# Tailscale (100.64.0.0/10) e Radmin VPN (26.x) primeiro: é o IP que o amigo usa.
			var b := int(address.get_slice(".", 1))
			if (address.begins_with("100.") and b >= 64 and b < 128) or address.begins_with("26."):
				vpn.append(address)
			else:
				list.append(address)
	return vpn + list


func _on_peer_connected(id: int) -> void:
	_no_throttle(id)
	if not multiplayer.is_server():
		return
	if in_game or lobby.size() >= MAX_PLAYERS:
		# Sala cheia ou partida em andamento: avisa e derruba a conexão.
		_rejected.rpc_id(id, "Sala cheia." if not in_game else "A partida já começou.")
		(func() -> void: multiplayer.multiplayer_peer.disconnect_peer(id)).call_deferred()


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	lobby.erase(id)
	if in_game and session:
		session.on_peer_left(id)
	_broadcast_lobby()


## O ENet joga fora pacotes "unreliable" de propósito quando o ping varia (throttle).
## Na internet isso vira perda de fotos sem motivo: as fotos já são pequenas e o
## cliente aguenta a variação com o buffer, então o throttle fica desligado.
func _no_throttle(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return
	var peer := enet.get_peer(id)
	if peer:
		peer.throttle_configure(5000, ENetPacketPeer.PACKET_THROTTLE_SCALE, 0)


func _on_connected() -> void:
	_no_throttle(1)
	_hello.rpc_id(1, get_meta(&"pending_name", "Jogador"), Characters.selected)


func _on_connection_failed() -> void:
	leave()
	last_error = "Não conectou. Confira o IP e se a porta %d está liberada." % port
	connection_failed.emit(last_error)
	lobby_changed.emit()


func _on_server_disconnected() -> void:
	var was_in_game := in_game
	leave()
	last_error = "O host saiu da partida."
	connection_failed.emit(last_error)
	if was_in_game:
		get_tree().change_scene_to_file(LOBBY_SCENE)
	else:
		lobby_changed.emit()


# --- Sala ---------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _hello(player_name: String, hero: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var used := []
	for p in lobby.values():
		used.append(p["slot"])
	var slot := 0
	while slot in used:
		slot += 1
	lobby[id] = {"name": player_name.left(12), "hero": hero, "ready": false, "slot": slot}
	_broadcast_lobby()


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	last_error = reason
	connection_failed.emit(reason)


## Escolha de herói e "pronto" de cada jogador (o host repassa para todos).
func set_choice(hero: String, ready: bool) -> void:
	if not active:
		return
	if multiplayer.is_server():
		_apply_choice(1, hero, ready)
	else:
		_choice.rpc_id(1, hero, ready)


@rpc("any_peer", "reliable")
func _choice(hero: String, ready: bool) -> void:
	if multiplayer.is_server():
		_apply_choice(multiplayer.get_remote_sender_id(), hero, ready)


func _apply_choice(id: int, hero: String, ready: bool) -> void:
	if not lobby.has(id) or Characters.get_data(hero)["id"] != hero:
		return
	lobby[id]["hero"] = hero
	lobby[id]["ready"] = ready
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	if multiplayer.is_server():
		_lobby_state.rpc(lobby)
		lobby_changed.emit()


@rpc("authority", "reliable")
func _lobby_state(state: Dictionary) -> void:
	lobby = state
	lobby_changed.emit()


func all_ready() -> bool:
	if lobby.size() < 2:
		return false
	for p in lobby.values():
		if not p["ready"]:
			return false
	return true


## Host: todo mundo para a fase, a partir da seção pedida.
func start_match(section := 0) -> void:
	if not is_host():
		return
	_goto.rpc(MAIN_SCENE, section, match_gen + 1, lobby, StageScenery.biome)


## Host, no fim de jogo ou fase concluída: continua da seção ou volta todos para a sala.
func host_after_stage(cleared: bool, section: int) -> void:
	if not is_host():
		return
	if cleared:
		for p in lobby.values():
			p["ready"] = false
		_goto.rpc(LOBBY_SCENE, 0, match_gen + 1, lobby, StageScenery.biome)
	else:
		_goto.rpc(MAIN_SCENE, section, match_gen + 1, lobby, StageScenery.biome)


@rpc("authority", "reliable", "call_local")
func _goto(scene: String, section: int, gen: int, state: Dictionary, biome := "ferro_velho") -> void:
	lobby = state
	# O cenário da fase é o do host.
	if StageScenery.BIOMES.has(biome):
		StageScenery.biome = biome
	match_gen = gen
	session = null
	in_game = scene == MAIN_SCENE
	_relay_sounds = in_game and multiplayer.is_server()
	if lobby.has(my_id()):
		Characters.selected = lobby[my_id()]["hero"]
	Stage.continue_section = section
	get_tree().change_scene_to_file(scene)


# --- Fase -----------------------------------------------------------------------------

## Chamado pela Stage quando a fase abre numa partida online.
func attach_stage(stage: Node) -> void:
	var NetSession := load("res://scripts/net/net_session.gd")
	session = NetSession.new()
	session.name = "NetSession"
	session.setup(self, stage)
	stage.add_child(session)


## Comandos do cliente para o host (o herói dele, a cada quadro).
func send_input(data: PackedByteArray) -> void:
	var gen := match_gen
	_out(false, func() -> void: _client_input.rpc_id(1, gen, data))


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func _client_input(gen: int, data: PackedByteArray) -> void:
	if gen == match_gen and session and multiplayer.is_server():
		session.on_client_input(multiplayer.get_remote_sender_id(), data)


## Foto da fase, do host para todos os clientes. `tick` é o quadro do host: o cliente
## guarda as fotos num buffer e as toca na ordem, então elas podem chegar fora de ordem
## (canal "unreliable" em vez de "unreliable_ordered": uma foto atrasada ainda serve).
func send_snapshot(tick: int, data: PackedByteArray) -> void:
	var gen := match_gen
	_out(false, func() -> void: _snapshot.rpc(gen, tick, data))


@rpc("authority", "unreliable", "call_remote", 2)
func _snapshot(gen: int, tick: int, data: PackedByteArray) -> void:
	if gen == match_gen and session:
		session.on_snapshot(tick, data)


## Eventos que não cabem na foto: efeitos, sons, avisos da fase e fim de combo.
## Levam o quadro do host para o cliente tocar junto com a foto certa.
func send_event(kind: String, args: Array) -> void:
	var gen := match_gen
	var tick: int = session.event_tick() if session else 0
	_out(true, func() -> void: _event.rpc(gen, tick, kind, args))


@rpc("authority", "reliable", "call_remote", 3)
func _event(gen: int, tick: int, kind: String, args: Array) -> void:
	if gen == match_gen and session:
		session.queue_event(tick, kind, args)


## Chamado pela classe Sound: no host, cada som da fase também toca nos clientes.
func relay_sound(kind: String, args: Array) -> void:
	if _relay_sounds and session and multiplayer.is_server():
		send_event("sound_" + kind, args)


# --- Simulador -----------------------------------------------------------------------

func simulating() -> bool:
	return sim_lag_ms > 0.0 or sim_jitter_ms > 0.0 or sim_loss > 0.0


## Troca o perfil de simulação (F8 na fase).
func next_sim_profile() -> String:
	sim_profile = (sim_profile + 1) % SIM_PROFILES.size()
	var prof: Array = SIM_PROFILES[sim_profile]
	sim_lag_ms = prof[1]
	sim_jitter_ms = prof[2]
	sim_loss = prof[3]
	return prof[0]


func sim_text() -> String:
	if not simulating():
		return ""
	return "simulando +%d ms (±%d) %d%% perda" % [sim_lag_ms, sim_jitter_ms, sim_loss]


func _out(reliable: bool, send: Callable) -> void:
	if not simulating():
		send.call()
		return
	if not reliable and randf() * 100.0 < sim_loss:
		sim_dropped += 1
		return
	var at := Time.get_ticks_usec() / 1000.0 + sim_lag_ms + randf() * sim_jitter_ms
	if reliable:
		# Confiável chega em ordem: nunca passa na frente do anterior.
		at = maxf(at, _last_reliable_at)
		_last_reliable_at = at
	_outbox.append([at, send])


func _process(_delta: float) -> void:
	if _outbox.is_empty():
		return
	var now := Time.get_ticks_usec() / 1000.0
	_outbox.sort_custom(func(a, b): return a[0] < b[0])
	while not _outbox.is_empty() and _outbox[0][0] <= now:
		var item: Array = _outbox.pop_front()
		if active and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			item[1].call()

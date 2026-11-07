class_name Sound
## Atalho para o autoload SoundBank: Sound.play("hit"), Sound.music("fase").
## Sem o autoload (testes rodando por script) as chamadas não fazem nada.
## No co-op online, o host repassa cada som da fase para os clientes (autoload Net).


static func play(name: String, volume_db := 0.0, pitch_spread := 0.08) -> void:
	var bank := _bank()
	if bank:
		bank.play(name, volume_db, pitch_spread)
	_relay("play", [name, volume_db, pitch_spread])


static func special(element: String) -> void:
	var bank := _bank()
	if bank:
		bank.special(element)
	_relay("special", [element])


static func music(name: String, loop := true) -> void:
	var bank := _bank()
	if bank:
		bank.music(name, loop)
	_relay("music", [name, loop])


## Som de interface (menus, pausa, contagem da vitória): toca só nesta tela, sem repassar
## para os outros jogadores do co-op, que têm o próprio HUD.
static func ui(name: String, volume_db := -4.0) -> void:
	var bank := _bank()
	if bank:
		bank.play(name, volume_db, 0.0)


static func music_local(name: String, loop := true) -> void:
	var bank := _bank()
	if bank:
		bank.music(name, loop)


static func stop_music() -> void:
	var bank := _bank()
	if bank:
		bank.stop_music()
	_relay("stop_music", [])


static func has(name: String) -> bool:
	var bank := _bank()
	return bank != null and bank.has(name)


static func _relay(kind: String, args: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var net := tree.root.get_node_or_null(^"Net")
	if net and net.active:
		net.relay_sound(kind, args)


static func _bank() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("SoundBank")

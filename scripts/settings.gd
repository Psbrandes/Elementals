extends Node
## Opções do jogador (autoload "Settings"): volume da música, volume dos efeitos e tela cheia.
## Ficam salvas em user://opcoes.cfg. Os volumes vão de 0 a 10 e controlam os barramentos de
## áudio "Music" e "SFX", criados aqui mesmo (o SoundBank toca em cada um deles).

const PATH := "user://opcoes.cfg"
const STEPS := 10
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

var music_volume := 8
var sfx_volume := 8
var fullscreen := false
## Música mais baixa enquanto o jogo está pausado.
var ducked := false
const DUCK_DB := -10.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	_load()
	apply()


func set_music(value: int) -> void:
	music_volume = clampi(value, 0, STEPS)
	apply()
	save()


func set_sfx(value: int) -> void:
	sfx_volume = clampi(value, 0, STEPS)
	apply()
	save()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save()


## A tela cheia só existe no PC; no celular e na web a opção some do menu.
func can_fullscreen() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("web")


func duck(on: bool) -> void:
	if ducked != on:
		ducked = on
		apply()


func apply() -> void:
	_set_bus(MUSIC_BUS, music_volume, DUCK_DB if ducked else 0.0)
	_set_bus(SFX_BUS, sfx_volume)
	if can_fullscreen() and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "musica", music_volume)
	cfg.set_value("audio", "efeitos", sfx_volume)
	cfg.set_value("tela", "cheia", fullscreen)
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_volume = clampi(int(cfg.get_value("audio", "musica", music_volume)), 0, STEPS)
	sfx_volume = clampi(int(cfg.get_value("audio", "efeitos", sfx_volume)), 0, STEPS)
	fullscreen = bool(cfg.get_value("tela", "cheia", fullscreen))


## 0 a 10 vira decibéis numa curva que soa linear ao ouvido; 0 desliga o barramento.
func _set_bus(bus: StringName, value: int, offset_db := 0.0) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, value <= 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(pow(float(value) / STEPS, 1.6)) + offset_db if value > 0 else -80.0)

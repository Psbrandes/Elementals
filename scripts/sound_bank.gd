extends Node
## Som do jogo (autoload "SoundBank", usado pela classe Sound): efeitos com variação de tom e uma faixa de
## música em loop. Os nomes são os arquivos de assets/audio/sfx e assets/audio/music;
## um efeito com variações (hit_1, hit_2...) sorteia uma delas.
##
## Efeitos: 400 Sounds Pack (Chequered Ink) e Pixabay (especiais e game over).
## Música: xDeviruchi, 8-Bit Fantasy & Adventure Music (CC-BY-SA 4.0).
## Músicas vitoria, resultado e selecao e os efeitos de menu, vitória, esquiva, agarrão e avisos:
## originais do projeto, gerados por tools/gerar_audio.py (CC0).
## Os efeitos tocam no barramento "SFX" e a música no "Music" (volumes no autoload Settings).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 10
const MUSIC_DB := -8.0
## Especial de cada herói, pelo elemento.
const SPECIAL_BY_ELEMENT := {"Fogo": "special_fogo", "Terra": "special_terra", "Cristal": "special_terra",
	"Metal": "special_terra", "Água": "special_agua", "Vento": "special_vento",
	"Folha": "special_vento"}

var _sfx := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
## Sorteio próprio: tocar um som não mexe na sequência aleatória do jogo (inimigos, testes).
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for file in DirAccess.get_files_at(SFX_DIR):
		file = file.trim_suffix(".import")
		if not file.ends_with(".ogg"):
			continue
		var name := file.trim_suffix(".ogg")
		# hit_1, hit_2 -> "hit"; hit_heavy_1 -> "hit_heavy".
		var base := name
		var cut := name.rfind("_")
		if cut > 0 and name.substr(cut + 1).is_valid_int():
			base = name.left(cut)
		if not _sfx.has(base):
			_sfx[base] = []
		if not _sfx[base].has(file):
			_sfx[base].append(file)
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	_music.bus = &"Music"
	add_child(_music)


func has(name: String) -> bool:
	return _sfx.has(name)


func play(name: String, volume_db := 0.0, pitch_spread := 0.08) -> void:
	if not _sfx.has(name):
		return
	var files: Array = _sfx[name]
	var voice := _voices[_next]
	_next = (_next + 1) % VOICES
	voice.stream = load(SFX_DIR + files[_rng.randi() % files.size()])
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	voice.play()


func special(element: String) -> void:
	play(SPECIAL_BY_ELEMENT.get(element, "special_fogo"), -2.0, 0.0)


## `loop` falso toca uma vez só (a fanfarra de vitória, por exemplo).
func music(name: String, loop := true) -> void:
	if name == _music_name and _music.playing:
		return
	_music_name = name
	var stream: AudioStream = load(MUSIC_DIR + name + ".ogg")
	if stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		stream.loop = loop
	_music.stream = stream
	_music.play()


func music_name() -> String:
	return _music_name if _music.playing else ""


func stop_music() -> void:
	_music_name = ""
	_music.stop()

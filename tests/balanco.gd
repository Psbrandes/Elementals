extends SceneTree
## Robô "habilidoso" para medir o equilíbrio: usa o que um jogador bom usa
## (combo com lançador, pulo cancelado e combo aéreo, esquiva no aviso "!",
## golpe de virada, especial 2 e especial). Mostra mortes, vida perdida e tempo.
##   godot --headless --path . --fixed-fps 60 --script res://tests/balanco.gd -- [herói] [habil|basico]
## Opções: "sem_esquiva"; "reacao=N" (quadros até reagir ao "!", 0 = reflexo
## perfeito; um jogador atento fica em 12 a 18); "vidas" (para no fim de jogo com
## as vidas normais em vez de 99); "trechos" (mostra tempo e dano de cada trava);
## "dif=facil|normal|dificil" (nível de dificuldade).

const MAIN := preload("res://scenes/main.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(7)
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		Characters.selected = args[0]
	var skilled := args.size() < 2 or args[1] != "basico"
	var use_dodge := skilled and not args.has("sem_esquiva")
	# "seg=N": joga só N segundos (para gravar vídeo).
	var limit := 60 * 60 * 10
	var reaction := 0
	for a: String in args:
		if a.begins_with("seg="):
			limit = int(a.substr(4)) * 60
		if a.begins_with("reacao="):
			reaction = int(a.substr(7))
		if a.begins_with("dif="):
			Difficulty.current()
			Difficulty.level = Difficulty.ARG_NAMES[a.substr(4)]
	var real_lives := args.has("vidas")
	var by_lock := args.has("trechos")
	var main := MAIN.instantiate()
	root.add_child(main)
	var stage: Stage = main.get_node("Stage")
	var p: Player = stage.player
	p.input.scripted = true
	if not real_lives:
		p.lives = 99
	var lock_seen := -1
	var lock_start := 0
	var lock_hp := 0
	var lock_report := []
	var by_source := {}
	var hp_box := [p.hp]
	p.health_changed.connect(func(hp: int, _max: int) -> void:
		if hp < hp_box[0]:
			var who := _source_name(p.last_hit_by)
			by_source[who] = by_source.get(who, 0) + hp_box[0] - hp
			p.last_hit_by = null
		hp_box[0] = hp)
	var deaths := 0
	var was_dead := false
	var hp_lost := 0
	var last_hp := p.hp
	var f := 0
	var plan := []
	var dodges := 0
	while f < limit and not stage.cleared:
		f += 1
		await physics_frame
		if p.hp < last_hp:
			hp_lost += last_hp - p.hp
		last_hp = p.hp
		if by_lock and stage.locked and not stage.cleared and stage._lock_index != lock_seen:
			lock_seen = stage._lock_index
			lock_start = f
			lock_hp = hp_lost
		elif by_lock and not stage.locked and lock_seen >= 0 and lock_report.size() <= lock_seen:
			lock_report.append("trava%d %ds dano=%d" % [lock_seen + 1, (f - lock_start) / 60, hp_lost - lock_hp])
		if real_lives and p.lives <= 0 and p.state == Fighter.State.DEAD:
			break
		if p.state == Fighter.State.DEAD:
			if not was_dead:
				deaths += 1
			was_dead = true
			plan.clear()
			continue
		was_dead = false
		p.input.move = Vector2.ZERO
		if not plan.is_empty():
			var step: Array = plan.pop_front()
			p.input.move = step[0]
			if step[1] != &"":
				p.input.press(step[1])
			continue
		var target = null
		for e in stage.enemies() + stage.breakables():
			if not stage.floor_rect.grow(2).has_point(e.position):
				continue
			if target == null or e.position.distance_to(p.position) < target.position.distance_to(p.position):
				target = e
		if target == null:
			p.input.move = Vector2(1, 0)
			continue
		var d: Vector2 = target.position - p.position
		var near := 0
		var threat := false
		for e: Enemy in stage.enemies():
			if e.position.distance_to(p.position) < 50:
				near += 1
			if skilled and e.state == Fighter.State.ATTACK and e.state_frame >= reaction \
					and e.state_frame <= int(e.current_attack.get("startup", 0)) \
					and absf(e.position.x - p.position.x) < 60 and absf(e.position.y - p.position.y) < 14:
				threat = true
		var free := p.state in [Fighter.State.IDLE, Fighter.State.WALK]
		if use_dodge and threat and free:
			# Esquiva para o lado (sai da faixa do golpe).
			var side := -1.0 if p.position.y > stage.floor_rect.get_center().y else 1.0
			plan = [[Vector2(0, side), &"dodge"]]
			dodges += 1
			continue
		if p.meter >= 50 and near >= 2 and free:
			p.input.press(&"special")
			continue
		if skilled and p.meter >= 30 and p.meter < 50 and near >= 2 and free and f % 20 == 0:
			plan = [[Vector2(0, 1), &"special"]]
			continue
		if absf(d.y) > 3:
			p.input.move = Vector2(0, signf(d.y))
		elif absf(d.x) > 26:
			p.input.move = Vector2(signf(d.x), 0)
		elif absf(d.x) < 4:
			p.input.move = Vector2(signf(stage.floor_rect.get_center().x - p.position.x), 0)
		elif skilled and free and target is Enemy and int(signf(d.x)) != p.facing:
			# Inimigo atrás: golpe de virada.
			plan = [[Vector2(signf(d.x), 0), &"attack"]]
		elif skilled and free and target is Enemy:
			# Combo: J, J, cima+J (lançador), K cancela no pulo, J J J no ar.
			plan = [[Vector2.ZERO, &"attack"]] + _wait(7) + [[Vector2.ZERO, &"attack"]] + _wait(7) \
				+ [[Vector2(0, -1), &"attack"]] + _wait(9) + [[Vector2.ZERO, &"jump"]] + _wait(6) \
				+ [[Vector2.ZERO, &"attack"]] + _wait(8) + [[Vector2.ZERO, &"attack"]] + _wait(8) \
				+ [[Vector2.ZERO, &"attack"]] + _wait(30)
		else:
			if free:
				p.facing = int(signf(d.x)) if d.x != 0 else p.facing
			if f % 6 == 0:
				p.input.press(&"attack")
	if by_lock and stage.cleared and lock_report.size() <= lock_seen:
		lock_report.append("trava%d %ds dano=%d" % [lock_seen + 1, (f - lock_start) / 60, hp_lost - lock_hp])
	print("BALANCO heroi=%s modo=%s fim=%s t=%ds mortes=%d vida_perdida=%d esquivas=%d pontos=%d trava=%d" % [
		p.character["name"], "habil" if skilled else "basico", stage.cleared, f / 60, deaths, hp_lost, dodges,
		stage.score, stage._lock_index + 1])
	if by_lock:
		print("TRECHOS " + " | ".join(lock_report))
		var keys := by_source.keys()
		keys.sort_custom(func(a, b): return by_source[a] > by_source[b])
		print("FONTES " + ", ".join(keys.map(func(k): return "%s=%d" % [k, by_source[k]])))
	quit()


func _wait(n: int) -> Array:
	var out := []
	for i in n:
		out.append([Vector2.ZERO, &""])
	return out


func _source_name(from: Variant) -> String:
	if from == null:
		return "custo_especial"
	if not is_instance_valid(from):
		return "outro"
	if from is Enemy:
		var e := from as Enemy
		return "%s:%s" % [e.data.display_name, e.current_attack.get("name", "?")]
	if from is Lob:
		return "lob:" + (from as Lob).look
	if from is Projectile:
		return "abalo" if (from as Projectile).ground else "pedra"
	return "outro" if from == null else String(from.get_script().get_global_name()) if from.get_script() else from.get_class()

class_name ElementStatus
extends Node
## Efeitos de elemento que ficam no alvo depois do golpe: queimadura (dano aos
## poucos, nunca mata) e congelamento (o alvo para no lugar). Fica como filho do
## lutador e some sozinho quando os efeitos acabam.
##
## O congelamento usa o hit stop do próprio lutador: enquanto dura, o alvo não
## anda, não ataca e não conta tempo de estado. Um golpe que derruba estilhaça o gelo.

const BURN_INTERVAL := 20
const BURN_DAMAGE := 2
const BURN_TINT := Color(1.0, 0.6, 0.35)
const FREEZE_TINT := Color(0.55, 0.85, 1.5)
## Corpo pesado (Brutamontes, chefe) fica congelado só metade do tempo.
const HEAVY_FREEZE_RATIO := 0.5

var burn_ticks := 0
var freeze_frames := 0

var _fighter: Fighter
var _timer := 0
var _base_modulate := Color.WHITE


static func of(fighter: Fighter) -> ElementStatus:
	var status := fighter.get_node_or_null(^"ElementStatus") as ElementStatus
	if status == null:
		status = ElementStatus.new()
		status.name = "ElementStatus"
		status._fighter = fighter
		if fighter.sprite:
			status._base_modulate = fighter.sprite.modulate
		fighter.add_child(status)
	return status


static func burn(fighter: Fighter, ticks: int) -> void:
	var status := of(fighter)
	status.burn_ticks = maxi(status.burn_ticks, ticks)


static func freeze(fighter: Fighter, frames: int) -> void:
	if fighter.heavy_body:
		frames = roundi(frames * HEAVY_FREEZE_RATIO)
	var status := of(fighter)
	status.freeze_frames = maxi(status.freeze_frames, frames)
	fighter.hitstop = maxi(fighter.hitstop, 1)


static func is_frozen(fighter: Fighter) -> bool:
	var status := fighter.get_node_or_null(^"ElementStatus") as ElementStatus
	return status != null and status.freeze_frames > 0


static func is_burning(fighter: Fighter) -> bool:
	var status := fighter.get_node_or_null(^"ElementStatus") as ElementStatus
	return status != null and status.burn_ticks > 0


func _physics_process(_delta: float) -> void:
	var f := _fighter
	if f.state == Fighter.State.DEAD:
		_finish()
		return
	if freeze_frames > 0:
		if f.state in [Fighter.State.KNOCKDOWN, Fighter.State.THROWN]:
			# Golpe que derruba quebra o gelo.
			freeze_frames = 0
			if f.stage:
				f.stage.fx("break", f.position, 20.0)
		else:
			freeze_frames -= 1
			f.hitstop = maxi(f.hitstop, 1)
	if burn_ticks > 0:
		_timer += 1
		if _timer >= BURN_INTERVAL:
			_timer = 0
			burn_ticks -= 1
			if f.hp > 1:
				f.hp = maxi(f.hp - BURN_DAMAGE, 1)
				f.health_changed.emit(f.hp, f.max_hp)
				if f.stage:
					f.stage.fx("hit", f.position, f.height + f.body_size.y * 0.5)
	if freeze_frames <= 0 and burn_ticks <= 0:
		_finish()
		return
	if f.sprite:
		var tint := FREEZE_TINT if freeze_frames > 0 else BURN_TINT
		if freeze_frames <= 0 and _timer % 10 >= 5:
			tint = _base_modulate
		f.sprite.modulate = _base_modulate * tint


func _finish() -> void:
	if _fighter.sprite:
		_fighter.sprite.modulate = _base_modulate
	queue_free()

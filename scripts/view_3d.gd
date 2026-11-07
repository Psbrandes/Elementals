class_name View3D
extends Node3D
## Apresentação 2.5D: cenário em 3D com câmera em perspectiva e os lutadores
## como sprites (billboards) dentro dele.
##
## A lógica do jogo continua toda no Stage 2D (x, profundidade e altura, em
## pixels); este nó só lê o estado a cada quadro de tela e posiciona um
## "representante" 3D para cada ator. Por isso os testes rodam sem mudança.
##
## Mapa de coordenadas (1 unidade = 1 pixel da arte):
##   x 3D = x da fase
##   y 3D = altura do pulo (height)
##   z 3D = (profundidade - meio do chão) * DEPTH_SCALE, crescendo para perto da câmera

const DEPTH_SCALE := 1.75
const FLOOR_MID := (Stage.FLOOR_TOP + Stage.FLOOR_BOTTOM) / 2.0
## Câmera: 30° de campo vertical, inclinada 32° para baixo. Com isso a faixa de
## chão ocupa a metade de baixo da tela e quem está no fundo aparece ~25% menor.
const CAMERA_FOV := 28.0
const CAMERA_PITCH := 22.0
const CAMERA_HEIGHT := 245.0
const CAMERA_DISTANCE := 425.0
const SHAKE_SCALE := 1.0

const FLASH_MODULATE := Color(4.0, 4.0, 4.0)
const SHADOW_COLOR := Color(0, 0, 0, 0.35)
const TELEGRAPH_COLOR := Color("ffcc33")
const VFX_DIR := "res://assets/vfx/"
## Escala de cada efeito (pixel_size); o especial é ajustado pela largura.
const VFX_SCALE := {"hit": 0.8, "hit_heavy": 0.5, "dust": 0.7, "stomp": 1.1, "break": 0.8, "arrow_hit": 0.6,
	"coin": 0.8, "heal": 0.8, "phase": 1.0}
const SPECIAL_VFX_WIDTH := 120.0
const SPECIAL_VFX_MAX_SCALE := 1.7
const MARKER_COLOR := Color(1.0, 0.25, 0.15)

@export var stage: Stage

var camera: Camera3D
var _proxies := {}
var _materials := {}
var _shadow_mesh: QuadMesh
var _shadow_material: StandardMaterial3D
var _frame := 0
var _vfx_meta := {}
var _vfx: Array[Dictionary] = []
var _popups: Array[Dictionary] = []

## Números de dano e avisos (CONTRA!, QUICOU!): sobem e somem em POPUP_SECONDS.
const POPUP_SECONDS := 0.6
const POPUP_RISE := 22.0
var _marker_texture: GradientTexture2D


func _ready() -> void:
	# O 2D continua rodando a lógica, mas quem aparece na tela é o 3D.
	stage.get_node("Background").visible = false
	stage.actors.visible = false
	_build_camera()
	_build_lights()
	StageScenery.build(self)
	_shadow_mesh = QuadMesh.new()
	_shadow_mesh.orientation = PlaneMesh.FACE_Y
	_shadow_mesh.size = Vector2.ONE
	# Sombra redonda e suave: gradiente radial do preto ao transparente.
	var gradient := Gradient.new()
	gradient.set_color(0, SHADOW_COLOR)
	gradient.set_color(1, Color(0, 0, 0, 0))
	var blob := GradientTexture2D.new()
	blob.gradient = gradient
	blob.fill = GradientTexture2D.FILL_RADIAL
	blob.fill_from = Vector2(0.5, 0.5)
	blob.fill_to = Vector2(1.0, 0.5)
	_shadow_material = _flat(Color.WHITE, true)
	_shadow_material.albedo_texture = blob
	_vfx_meta = JSON.parse_string(FileAccess.get_file_as_string(VFX_DIR + "vfx.json"))
	stage.effect_spawned.connect(spawn_effect)
	stage.popup_spawned.connect(spawn_popup)
	# Anel do alvo no chão (bomba, pedra e salto do chefe).
	var ring := Gradient.new()
	ring.offsets = PackedFloat32Array([0.0, 0.62, 0.8, 1.0])
	ring.colors = PackedColorArray([Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0)])
	_marker_texture = GradientTexture2D.new()
	_marker_texture.gradient = ring
	_marker_texture.fill = GradientTexture2D.FILL_RADIAL
	_marker_texture.fill_from = Vector2(0.5, 0.5)
	_marker_texture.fill_to = Vector2(1.0, 0.5)


## Ponto da fase (x, profundidade) mais a altura, em coordenadas 3D.
static func to_3d(pos: Vector2, lift := 0.0) -> Vector3:
	return Vector3(pos.x, lift, (pos.y - FLOOR_MID) * DEPTH_SCALE)


func _process(_delta: float) -> void:
	_frame += 1
	var center_x := stage.cam_left + Stage.VIEW_WIDTH / 2.0
	camera.position = Vector3(center_x, CAMERA_HEIGHT, CAMERA_DISTANCE)
	var shake := stage.camera.offset * SHAKE_SCALE
	camera.h_offset = shake.x
	camera.v_offset = -shake.y
	var seen := {}
	for node in stage.actors.get_children():
		if node.is_queued_for_deletion():
			continue
		var id := node.get_instance_id()
		seen[id] = true
		if not _proxies.has(id):
			_proxies[id] = _make_proxy(node)
		_update_proxy(node, _proxies[id])
	for id in _proxies.keys():
		if not seen.has(id):
			_proxies[id]["root"].queue_free()
			_proxies.erase(id)
	_update_vfx(_delta)
	_update_popups(_delta)


func _make_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.mesh = _shadow_mesh
	var material := _flat(MARKER_COLOR, true)
	material.albedo_texture = _marker_texture
	material.no_depth_test = true
	material.render_priority = 1
	marker.material_override = material
	marker.visible = false
	add_child(marker)
	return marker


## Anel no chão: cresce de cor conforme o impacto chega (progress 0 a 1).
func _update_marker(marker: MeshInstance3D, info: Dictionary) -> void:
	marker.visible = not info.is_empty()
	if info.is_empty():
		return
	var radius: float = info["radius"]
	marker.position = to_3d(info["at"], 0.6)
	marker.scale = Vector3(radius * 2.0, 1.0, radius * DEPTH_SCALE)
	var progress: float = info["progress"]
	var blink := 1.0 if progress < 0.7 or _frame % 6 < 3 else 0.4
	(marker.material_override as StandardMaterial3D).albedo_color = Color(MARKER_COLOR, (0.45 + 0.55 * progress) * blink)


# --- Efeitos (PVFX Foundry) --------------------------------------------------------

## Toca um efeito de assets/vfx no ponto da fase, de frente para a câmera.
func spawn_effect(name: String, at: Vector2, lift := 0.0, flip := false) -> void:
	if not _vfx_meta.has(name):
		return
	var meta: Dictionary = _vfx_meta[name]
	var size := Vector2(meta["size"][0], meta["size"][1])
	var pivot := Vector2(meta["pivot"][0], meta["pivot"][1])
	if pivot == Vector2.ZERO:
		pivot = Vector2(size.x / 2.0, size.y * 0.85)
	var sprite := _billboard(load(VFX_DIR + name + ".png"), _vfx_scale(name, size.x))
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.render_priority = 2
	sprite.hframes = int(meta["columns"])
	sprite.vframes = ceili(float(meta["frames"]) / sprite.hframes)
	sprite.offset = Vector2(size.x / 2.0 - pivot.x, pivot.y - size.y / 2.0)
	sprite.flip_h = flip
	if flip:
		sprite.offset.x = -sprite.offset.x
	sprite.position = to_3d(at, lift) + Vector3(0.0, 0.0, 6.0)
	add_child(sprite)
	_vfx.append({"sprite": sprite, "durations": meta["durations_ms"], "frame": 0, "time": 0.0})


func _vfx_scale(name: String, width: float) -> float:
	if name.begins_with("special_"):
		return minf(SPECIAL_VFX_WIDTH / width, SPECIAL_VFX_MAX_SCALE)
	return VFX_SCALE.get(name, 1.0)


func _update_vfx(delta: float) -> void:
	for effect in _vfx.duplicate():
		var sprite: Sprite3D = effect["sprite"]
		var durations: Array = effect["durations"]
		effect["time"] += delta * 1000.0
		while effect["frame"] < durations.size() and effect["time"] >= float(durations[effect["frame"]]):
			effect["time"] -= float(durations[effect["frame"]])
			effect["frame"] += 1
		if effect["frame"] >= durations.size():
			sprite.queue_free()
			_vfx.erase(effect)
		else:
			sprite.frame = effect["frame"]


## Texto que sobe do ponto do golpe, sempre por cima de tudo.
func spawn_popup(text: String, at: Vector2, lift: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32 if text.length() <= 3 else 28
	label.pixel_size = 0.4
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var x_jitter := randf_range(-6.0, 6.0)
	label.position = to_3d(at, lift) + Vector3(x_jitter, 0.0, 8.0)
	add_child(label)
	_popups.append({"label": label, "time": 0.0, "base": label.position})


func _update_popups(delta: float) -> void:
	for popup in _popups.duplicate():
		var label: Label3D = popup["label"]
		popup["time"] += delta
		var t: float = popup["time"] / POPUP_SECONDS
		if t >= 1.0:
			label.queue_free()
			_popups.erase(popup)
			continue
		# Sobe rápido e desacelera; some no último terço.
		label.position = popup["base"] + Vector3(0.0, POPUP_RISE * (1.0 - pow(1.0 - t, 3.0)), 0.0)
		label.modulate.a = clampf((1.0 - t) * 3.0, 0.0, 1.0)


## Quantos efeitos estão tocando agora.
func active_effects() -> int:
	return _vfx.size()


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.rotation_degrees = Vector3(-CAMERA_PITCH, 0.0, 0.0)
	camera.far = 4000.0
	camera.near = 10.0
	add_child(camera)
	camera.make_current()


func _build_lights() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var biome := StageScenery.data()
	env.background_color = biome["sky"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = biome["ambient"]
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_color = biome["sun"]
	sun.light_energy = 0.9
	add_child(sun)


# --- Representantes ------------------------------------------------------------

func _make_proxy(node: Node) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var proxy := {"root": root, "kind": "other"}
	var shadow := MeshInstance3D.new()
	shadow.mesh = _shadow_mesh
	shadow.material_override = _shadow_material
	add_child(shadow)
	root.tree_exiting.connect(shadow.queue_free)
	proxy["shadow"] = shadow
	if node is Fighter and node.sprite != null:
		# Herói ou inimigo com arte: billboard copiando o quadro do sprite 2D.
		proxy["kind"] = "hero"
		var sprite := _billboard(null, 1.0)
		root.add_child(sprite)
		proxy["sprite"] = sprite
		if not node is Player:
			proxy["warn"] = _make_warn(root)
		if node.has_method("ground_marker"):
			proxy["marker"] = _make_marker()
			root.tree_exiting.connect(proxy["marker"].queue_free)
	elif node is Breakable:
		proxy["kind"] = "breakable"
		# Barril e caixa com a cara do cenário, com a altura da caixa de colisão.
		var texture := StageScenery.breakable_art(node.kind)
		var sprite := _billboard(texture, node.body_size.y / texture.get_height())
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sprite.position.y = node.body_size.y / 2.0
		root.add_child(sprite)
		proxy["mesh"] = sprite
		if node.kind == "barril":
			sprite.modulate = StageScenery.data()["barrel_tint"]
		proxy["pieces"] = _make_pieces(root, _shaded({"lixeira": Color("5f6f80"), "barril": Color("b03a2e")}.get(node.kind, Color("b07a43"))))
	elif node is Fighter:
		proxy["kind"] = "fighter"
		_make_body(node, root, proxy)
	elif node is Projectile:
		proxy["kind"] = "projectile"
		if node.art != "":
			var arrow := _billboard(load(node.art), 0.62)
			arrow.position.y = Projectile.STONE_HEIGHT
			arrow.flip_h = node.direction < 0
			root.add_child(arrow)
			return proxy
		var mesh := MeshInstance3D.new()
		if node.ground:
			var wave := BoxMesh.new()
			wave.size = Vector3(22.0, 8.0, 10.0)
			mesh.mesh = wave
			mesh.position.y = 4.0
			mesh.material_override = _shaded(Color("c97b3a"))
		else:
			var stone := SphereMesh.new()
			stone.radius = 3.0
			stone.height = 6.0
			mesh.mesh = stone
			mesh.position.y = Projectile.STONE_HEIGHT
			mesh.material_override = _shaded(Color("b0a89a"))
		root.add_child(mesh)
		proxy["mesh"] = mesh
	elif node is Lob:
		proxy["kind"] = "lob"
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var bomb: bool = node.look == "bomba"
		sphere.radius = 4.0 if bomb else 7.0
		sphere.height = sphere.radius * 2.0
		ball.mesh = sphere
		ball.material_override = _flat(Color("ff7a1a")) if bomb else _shaded(Color("8c6a4e"))
		root.add_child(ball)
		proxy["mesh"] = ball
		proxy["marker"] = _make_marker()
		root.tree_exiting.connect(proxy["marker"].queue_free)
	elif node is Item:
		proxy["kind"] = "item"
		var mesh := MeshInstance3D.new()
		match node.kind:
			"maca":
				var apple := SphereMesh.new()
				apple.radius = 4.0
				apple.height = 8.0
				mesh.mesh = apple
				mesh.material_override = _shaded(Color("d6332b"))
			"orbe":
				var orb := SphereMesh.new()
				orb.radius = 4.5
				orb.height = 9.0
				mesh.mesh = orb
				mesh.material_override = _flat(Color("7fd4ff"))
			"frango":
				var chicken := CapsuleMesh.new()
				chicken.radius = 3.5
				chicken.height = 12.0
				mesh.mesh = chicken
				mesh.rotation_degrees.z = 90.0
				mesh.material_override = _shaded(Color("c97b3a"))
			_:
				var coins := CylinderMesh.new()
				coins.top_radius = 5.0
				coins.bottom_radius = 5.0
				coins.height = 5.0
				mesh.mesh = coins
				mesh.material_override = _shaded(Color("ffcc33"))
		root.add_child(mesh)
		proxy["mesh"] = mesh
	return proxy


## Inimigos e chefe ainda são placeholders: corpo, cabeça, "olho" para o lado em
## que olham, braço no golpe e o "!" de aviso.
func _make_body(fighter: Fighter, root: Node3D, proxy: Dictionary) -> void:
	var pose := Node3D.new()
	root.add_child(pose)
	var size := fighter.body_size
	var depth := size.x * 0.7
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(size.x, size.y - 12.0, depth)
	body.mesh = body_mesh
	body.position.y = (size.y - 12.0) / 2.0
	pose.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(size.x, 12.0, depth)
	head.mesh = head_mesh
	head.position.y = size.y - 6.0
	pose.add_child(head)
	var eye := MeshInstance3D.new()
	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(3.0, 3.0, 3.0)
	eye.mesh = eye_mesh
	eye.material_override = _flat(Color.WHITE)
	pose.add_child(eye)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3.ONE
	arm.mesh = arm_mesh
	pose.add_child(arm)
	var warn := _make_warn(root)
	var body_material := StandardMaterial3D.new()
	var head_material := StandardMaterial3D.new()
	var arm_material := StandardMaterial3D.new()
	body.material_override = body_material
	head.material_override = head_material
	arm.material_override = arm_material
	proxy.merge({"pose": pose, "body": body, "head": head, "eye": eye, "arm": arm, "warn": warn,
		"body_material": body_material, "head_material": head_material, "arm_material": arm_material,
		"depth": depth})


func _make_pieces(root: Node3D, material: Material) -> Array:
	var pieces := []
	for i in 5:
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4.0, 4.0, 4.0)
		piece.mesh = box
		piece.material_override = material
		piece.visible = false
		root.add_child(piece)
		pieces.append(piece)
	return pieces


func _billboard(texture: Texture2D, pixel_size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return sprite


## "!" amarelo da antecipação do golpe inimigo.
func _make_warn(root: Node3D) -> Label3D:
	var warn := Label3D.new()
	warn.text = "!"
	warn.font_size = 48
	warn.pixel_size = 0.5
	warn.modulate = TELEGRAPH_COLOR
	warn.outline_size = 8
	warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warn.no_depth_test = true
	warn.visible = false
	root.add_child(warn)
	return warn


func _update_warn(fighter: Fighter, warn: Label3D, top: float) -> void:
	warn.visible = fighter.state == Fighter.State.ATTACK and fighter.current_attack.get("telegraph", false) \
		and fighter.state_frame <= int(fighter.current_attack.get("startup", 0)) and _frame % 8 < 6
	warn.position.y = top + 14.0 + fighter.height


func _update_proxy(node: Node2D, proxy: Dictionary) -> void:
	var root: Node3D = proxy["root"]
	root.position = to_3d(node.position)
	var shadow: MeshInstance3D = proxy["shadow"]
	shadow.position = to_3d(node.position, 0.4)
	match proxy["kind"]:
		"hero":
			_update_hero(node, proxy)
		"fighter":
			_update_fighter(node, proxy)
		"breakable":
			_update_breakable(node, proxy)
		"projectile":
			shadow.visible = not node.ground
			shadow.scale = Vector3(8.0, 1.0, 6.0)
			if node.ground:
				var mesh: MeshInstance3D = proxy["mesh"]
				mesh.scale.y = 0.7 + 0.3 * float((_frame / 4) % 3)
		"lob":
			var ball: MeshInstance3D = proxy["mesh"]
			ball.position.y = node.height
			ball.rotation.z += 0.2
			shadow.scale = Vector3(8.0, 1.0, 6.0)
			_update_marker(proxy["marker"], {"at": node.target, "radius": node.radius, "progress": node.call("progress")})
		"item":
			shadow.scale = Vector3(14.0, 1.0, 10.0)
			var mesh: MeshInstance3D = proxy["mesh"]
			mesh.position.y = 6.0 + (1.0 if (_frame / 24) % 2 == 0 else 0.0)
			mesh.rotation.y += 0.04


func _update_hero(player: Fighter, proxy: Dictionary) -> void:
	var source := player.sprite
	var sprite: Sprite3D = proxy["sprite"]
	if sprite.texture != source.texture:
		sprite.texture = source.texture
	sprite.hframes = source.hframes
	sprite.vframes = source.vframes
	sprite.frame = source.frame
	# A origem do representante fica nos pés, como no CharacterSprite.
	var frame_size := Vector2(source.texture.get_width() / source.hframes, source.texture.get_height() / source.vframes)
	var anchor := -source.offset
	# Espelhar com escala negativa gira em volta dos pés.
	sprite.offset = Vector2(frame_size.x / 2.0 - anchor.x, anchor.y - frame_size.y / 2.0)
	# Quem apanhou treme durante o hit stop.
	sprite.position = Vector3(player.hit_jitter(), player.height, 0.0)
	sprite.scale = Vector3(player.facing, 1.0, 1.0) * source.draw_scale
	sprite.visible = player._is_visible_this_frame()
	sprite.modulate = FLASH_MODULATE if player.flash > 0 and player.flash % 4 < 2 else source.modulate
	var shadow: MeshInstance3D = proxy["shadow"]
	shadow.scale = Vector3(player.body_size.x + 8.0, 1.0, player.body_size.x * 0.6)
	if not player is Player:
		_update_warn(player, proxy["warn"], player.body_size.y)
	if proxy.has("marker"):
		_update_marker(proxy["marker"], player.call("ground_marker"))


func _update_fighter(fighter: Fighter, proxy: Dictionary) -> void:
	var visible_now := fighter._is_visible_this_frame()
	var pose: Node3D = proxy["pose"]
	pose.visible = visible_now
	var flash := fighter.flash > 0 and fighter.flash % 4 < 2
	var color := Color.WHITE if flash else fighter.body_color
	(proxy["body_material"] as StandardMaterial3D).albedo_color = color
	(proxy["head_material"] as StandardMaterial3D).albedo_color = color.darkened(0.3)
	var size := fighter.body_size
	var depth: float = proxy["depth"]
	var eye: MeshInstance3D = proxy["eye"]
	eye.position = Vector3(fighter.facing * size.x / 4.0, size.y - 6.0, depth / 2.0 + 0.5)
	pose.position = Vector3(0.0, fighter.height, 0.0)
	pose.rotation = Vector3.ZERO
	if fighter._is_lying():
		# Deitado: o corpo tomba para trás e fica centrado onde estava.
		pose.rotation.z = fighter.facing * PI / 2.0
		pose.position += Vector3(fighter.facing * size.y / 2.0, depth / 2.0, 0.0)
	_update_arm(fighter, proxy)
	_update_warn(fighter, proxy["warn"], size.y)
	var shadow: MeshInstance3D = proxy["shadow"]
	shadow.scale = Vector3(size.x + 8.0, 1.0, size.x * 0.8)


## Mesmo desenho do braço do placeholder 2D: curto na antecipação, esticado no ativo.
func _update_arm(fighter: Fighter, proxy: Dictionary) -> void:
	var arm: MeshInstance3D = proxy["arm"]
	arm.visible = false
	if fighter.state != Fighter.State.ATTACK or fighter._is_lying():
		return
	var a := fighter.current_attack
	if a.get("area", false) or a.get("far", 0.0) <= 0.0:
		return
	var startup: int = a.get("startup", 0)
	var active: int = a.get("active", 0)
	var reach: float = a.get("far", 0.0)
	if fighter.state_frame <= startup:
		reach = 4.0
	elif fighter.state_frame > startup + active:
		reach *= 0.5
	var half := fighter.body_size.x / 2.0
	var length := maxf(reach - half + 2.0, 4.0)
	arm.visible = true
	arm.scale = Vector3(length, 5.0, 5.0)
	arm.position = Vector3(fighter.facing * (half - 2.0 + length / 2.0), float(a.get("y_hi", 40.0)) - 8.5,
		float(proxy["depth"]) / 2.0)
	(proxy["arm_material"] as StandardMaterial3D).albedo_color = fighter._limb_color()


func _update_breakable(breakable: Breakable, proxy: Dictionary) -> void:
	var mesh: Node3D = proxy["mesh"]
	var pieces: Array = proxy["pieces"]
	var broken := breakable.state == Fighter.State.DEAD
	mesh.visible = not broken
	if breakable.kind == "barril":
		(mesh as Sprite3D).modulate = FLASH_MODULATE if breakable.flash > 0 else StageScenery.data()["barrel_tint"]
	mesh.position.x = 1.0 if breakable.wobble > 0 and breakable.wobble % 4 < 2 else 0.0
	var shadow: MeshInstance3D = proxy["shadow"]
	shadow.visible = not broken
	shadow.scale = Vector3(breakable.body_size.x + 4.0, 1.0, breakable.body_size.x)
	for i in pieces.size():
		var piece: MeshInstance3D = pieces[i]
		piece.visible = broken
		if broken:
			var t := float(breakable.state_frame)
			var dir := float(i - 2)
			piece.position = Vector3(dir * t * 0.8, 10.0 + t * 1.5 - t * t * 0.08 + i * 2.0, (i % 2) * 4.0)


# --- Materiais -----------------------------------------------------------------

func _shaded(color: Color) -> StandardMaterial3D:
	var key := "s" + color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		_materials[key] = material
	return _materials[key]


## Material sem luz (efeitos e sombras). Os de efeito mudam de cor, então não são compartilhados.
func _flat(color: Color, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

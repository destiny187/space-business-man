class_name FrontierPlanetView
extends Node3D

signal interacted(kind: String, id: String)
signal placement_requested(location: Vector2)

var campaign: FrontierCampaign
var world_root: Node3D
var player: CharacterBody3D
var camera: Camera3D
var head: Node3D
var sky_material: ShaderMaterial
var environment: Environment
var visual_nodes: Dictionary = {}
var robot_nodes: Dictionary = {}
var foliage: Array[Node3D] = []
var material_cache: Dictionary = {}
var asset_cache: Dictionary = {}
var target: Dictionary = {}
var build_kind: String = ""
var build_rotation: int = 0
var ghost: Node3D
var ghost_location: Vector2
var controls_enabled: bool = false
var orbit_mode: bool = false
var orbital_camera: Camera3D
var elapsed: float = 0.0
var last_signature: String = ""
var ground_material: ShaderMaterial
var outline: ShaderMaterial
var handheld: Node3D
var beam: MeshInstance3D
var impact: CPUParticles3D
var ghost_material: StandardMaterial3D
var work_effects: Dictionary = {}
var machine_effects: Dictionary = {}
var effects: FrontierEffects
var recoil: float = 0.0
var suction_strength: float = 0.0
var combat_clock: Dictionary = {}
var moving_parts: Array[Node] = []
var muzzle_light: OmniLight3D
var world_font: FontVariation
var sun: DirectionalLight3D
var graphics_key: String = "balanced"
var graphics_config: Dictionary = {}
var practical_lights: Array[OmniLight3D] = []
var light_clock: float = 0.0
var sky_state := Vector2(-1,-1)

func _ready() -> void:
	effects = FrontierEffects.new()
	add_child(effects)
	world_font = FontVariation.new()
	world_font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	world_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):500.0}
	outline = ShaderMaterial.new()
	outline.shader = load("res://assets/materials/toon_outline.gdshader")
	world_root = Node3D.new()
	add_child(world_root)
	_setup_lighting()
	player = CharacterBody3D.new()
	player.name = "RemoteEquipment"
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	player.add_child(collision)
	head = Node3D.new()
	head.position.y = 1.8
	player.add_child(head)
	camera = Camera3D.new()
	camera.fov = 78
	camera.far = 700
	head.add_child(camera)
	camera.current = true
	handheld = model("manual_tool")
	handheld.position = Vector3(0.36,-0.30,-0.92)
	handheld.scale = Vector3.ONE*0.72
	handheld.rotation.y = -0.03
	camera.add_child(handheld)
	handheld.set_meta("intake_offset",Vector3(0,0,-0.78))
	muzzle_light = OmniLight3D.new()
	muzzle_light.position = Vector3(0,0,-0.78)
	muzzle_light.omni_range = 4
	muzzle_light.light_color = Color("ffc07c")
	muzzle_light.light_energy = 0
	handheld.add_child(muzzle_light)
	moving_parts = handheld.find_children("Anim_*","Node3D",true,false)
	for part in moving_parts: part.set_meta("rest",part.position)
	beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.012
	beam_mesh.bottom_radius = 0.025
	beam_mesh.radial_segments = 8
	beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color("c3f4c5")
	beam_mat.emission_enabled = true
	beam_mat.emission = Color("75e0c3")
	beam_mat.emission_energy_multiplier = 3
	beam.material_override = beam_mat
	beam.visible = false
	add_child(beam)
	impact = CPUParticles3D.new()
	impact.amount = 24
	impact.lifetime = 0.4
	impact.emitting = false
	impact.direction = Vector3.UP
	impact.spread = 70
	impact.initial_velocity_min = 0.8
	impact.initial_velocity_max = 2.5
	impact.gravity = Vector3(0,-4,0)
	impact.scale_amount_min = 0.015
	impact.scale_amount_max = 0.04
	var fragment := SphereMesh.new()
	fragment.radius = 1
	fragment.height = 2
	fragment.radial_segments = 6
	fragment.rings = 3
	fragment.material = beam_mat
	impact.mesh = fragment
	add_child(impact)
	orbital_camera = Camera3D.new()
	add_child(orbital_camera)
	orbital_camera.far = 700
	orbital_camera.position = Vector3(35,28,40)
	orbital_camera.look_at(Vector3.ZERO)
	apply_graphics(str(campaign.profile.settings.get("graphics","balanced")))

func _setup_lighting() -> void:
	var we := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://assets/materials/planet_sky.gdshader")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("bda08c")
	environment.fog_density = 0.0018
	environment.fog_aerial_perspective = 0.35
	environment.fog_sun_scatter = 0.15
	environment.ssao_radius = 0.9
	environment.ssao_intensity = 1.5
	environment.ssao_power = 1.3
	environment.ssao_detail = 0.6
	environment.ssao_light_affect = 0.12
	environment.ssil_radius = 3.5
	environment.ssil_intensity = 0.65
	environment.ssr_max_steps = 48
	environment.ssr_fade_in = 0.15
	environment.ssr_fade_out = 2.0
	environment.glow_intensity = 0.45
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.3
	environment.glow_normalized = true
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "TerraformSun"
	sun.rotation_degrees = Vector3(-38,-38,0)
	sun.light_color = Color("ffe0b8")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 1.7
	sun.shadow_blur = 1.2
	sun.directional_shadow_split_1 = 0.12
	sun.directional_shadow_split_2 = 0.3
	sun.directional_shadow_split_3 = 0.6
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	for i in range(6):
		var lamp := OmniLight3D.new()
		lamp.name = "PracticalLight"+str(i)
		lamp.omni_range = 5.5
		lamp.omni_attenuation = 1.6
		lamp.light_color = Color("83efd7")
		lamp.light_energy = 0.28
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		practical_lights.append(lamp)

func apply_graphics(key: String) -> void:
	graphics_key = FrontierGraphics.resolve(key)
	graphics_config = FrontierGraphics.apply(get_viewport(),environment,sun,graphics_key)
	_update_local_lights()

func _update_local_lights() -> void:
	for lamp in practical_lights: lamp.visible = false
	if campaign == null or campaign.planet.is_empty() or graphics_config.is_empty(): return
	var current_camera: Camera3D = get_viewport().get_camera_3d()
	if current_camera == null: return
	var candidates: Array[Node3D] = []
	for building in campaign.planet.buildings:
		if building.type not in ["base","charger","factory","atmosphere","water","biolab","reactor"]: continue
		if building.type != "base" and not building.get("active",false): continue
		var object: Node3D = visual_nodes.get(building.id)
		if is_instance_valid(object) and object.position.distance_to(current_camera.global_position) < 42:
			candidates.append(object)
	candidates.sort_custom(func(a: Node3D,b: Node3D): return a.position.distance_squared_to(current_camera.global_position) < b.position.distance_squared_to(current_camera.global_position))
	for i in range(mini(int(graphics_config.local_lights),candidates.size())):
		practical_lights[i].position = candidates[i].position+Vector3(0,1.5,1.8).rotated(Vector3.UP,candidates[i].rotation.y)
		practical_lights[i].visible = true

func rebuild(p: Dictionary) -> void:
	effects.clear()
	sky_state = Vector2(-1,-1)
	for lamp in practical_lights: lamp.visible = false
	combat_clock.clear()
	for child in world_root.get_children(): child.free()
	visual_nodes.clear()
	robot_nodes.clear()
	foliage.clear()
	work_effects.clear()
	machine_effects.clear()
	ghost = null
	last_signature = ""
	var backdrop: Dictionary = p if not p.is_empty() else FrontierPlanetFactory.make("basalt","preview",71491,0)
	_terrain(backdrop)
	_distant_landscape(backdrop)
	if p.is_empty():
		for item in [["base",Vector2.ZERO],["miner",Vector2(-4,6)],["solar",Vector2(7,2)],["atmosphere",Vector2(-8,-2)],["storage",Vector2(1,7)]]:
			var obj: Node3D = model(item[0])
			obj.position = Vector3(item[1].x,0,item[1].y)
			world_root.add_child(obj)
		orbital_camera.current = true
		handheld.visible = false
		orbital_camera.position = Vector3(18,13,22)
		orbital_camera.look_at(Vector3(0,0,-1))
		return
	for node in p.nodes:
		if node.amount > 0: _entity("resource",node.id,"ore_"+node.resource,node.position,1.6,float(node.scale))
	for event in p.events: _entity("event",event.id,event.kind,event.position,2.5)
	var location: Vector2 = FrontierCampaign.point(p.player.position)
	player.position = Vector3(location.x,0.2,location.y)
	player.rotation.y = float(p.player.yaw)
	head.rotation.x = -0.05
	camera.current = true
	handheld.visible = true
	orbit_mode = false
	sync()

func _terrain(p: Dictionary) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = int(p.seed)
	noise.frequency = 0.028
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := Color(FrontierCatalog.entry("planets",p.kind).color)
	for x in range(-128,128,4):
		for z in range(-128,128,4):
			var vertices: Array[Vector3] = []
			for corner in [Vector2(x,z),Vector2(x+4,z),Vector2(x+4,z+4),Vector2(x,z+4)]:
				var edge: float = clampf((maxf(absf(corner.x),absf(corner.y))-78)/40,0,1)
				vertices.append(Vector3(corner.x,noise.get_noise_2d(corner.x,corner.y)*edge*14-0.06,corner.y))
			for i in [0,1,2,0,2,3]:
				st.set_color(color.lerp(Color("bd9c83"),clampf(noise.get_noise_2d(vertices[i].x,vertices[i].z)*0.35+0.2,0,1)))
				st.add_vertex(vertices[i])
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://assets/materials/ground.gdshader")
	ground_material.set_shader_parameter("soil",color.darkened(0.12))
	mesh.material_override = ground_material
	world_root.add_child(mesh)
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(160,0.5,160)
	collider.shape = shape
	collider.position.y = -0.25
	ground.add_child(collider)
	world_root.add_child(ground)
	var water := MeshInstance3D.new()
	water.mesh = _water_mesh()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(-42,-0.14,-45)
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://assets/materials/water.gdshader")
	water.material_override = water_mat
	water.name = "WaterSurface"
	world_root.add_child(water)
	_ground_detail(p)

func _water_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(12):
		for segment in range(96):
			var corners: Array[Vector2] = []
			for step in [Vector2(ring,segment),Vector2(ring+1,segment),Vector2(ring+1,segment+1),Vector2(ring,segment+1)]:
				var angle: float = step.y*TAU/96
				corners.append(Vector2(cos(angle),sin(angle))*step.x/12)
			for index in [0,1,2,0,2,3]:
				var point: Vector2 = corners[index]
				var angle: float = point.angle()
				var radius: float = 14.0*(1.0+sin(angle*3)*0.065+cos(angle*7)*0.035)
				st.set_uv(point*0.5+Vector2.ONE*0.5)
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(point.x*radius,0,point.y*radius))
	st.index()
	return st.commit()

func _distant_landscape(p: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed) + 34
	var strata := ShaderMaterial.new()
	strata.shader = load("res://assets/materials/strata.gdshader")
	for i in range(26):
		var rock: Node3D = model("mesa_"+str(i%3))
		var angle: float = i*TAU/26
		var distance: float = rng.randf_range(110,148)
		rock.position = Vector3(cos(angle)*distance,-2,sin(angle)*distance)
		rock.rotation.y = rng.randf()*TAU
		rock.scale = Vector3(rng.randf_range(.8,1.5),rng.randf_range(.8,1.4),rng.randf_range(.8,1.5))
		for mesh in rock.find_children("*","MeshInstance3D",true,false):
			mesh.material_override = strata
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(rock)
	var moon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 27
	sphere.height = 54
	moon.mesh = sphere
	moon.position = Vector3(105,83,-170)
	var moon_mat := ShaderMaterial.new()
	moon_mat.shader = load("res://assets/materials/moon.gdshader")
	moon.material_override = moon_mat
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(moon)
	for i in range(65):
		var tree: Node3D = model("tree")
		var angle: float = rng.randf()*TAU
		var distance: float = rng.randf_range(18,74)
		tree.position = Vector3(cos(angle)*distance,0,sin(angle)*distance)
		if not _decor_clear(Vector2(tree.position.x,tree.position.z),p): tree.free(); continue
		tree.rotation.y = rng.randf()*TAU
		var size: float = rng.randf_range(0.65,1.5)
		tree.scale = Vector3.ONE*size
		tree.visible = false
		world_root.add_child(tree)
		foliage.append(tree)

func _decor_clear(point: Vector2,p: Dictionary) -> bool:
	if point.length() < 15: return false
	for collection in [p.nodes,p.events,p.buildings]:
		for item in collection:
			if FrontierCampaign.point(item.position).distance_to(point) < 5: return false
	return point.distance_to(Vector2(-42,-45)) > 15

func _ground_detail(p: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed)+908
	var gravel := MultiMeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 5
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mesh.material = mat
	gravel.multimesh = MultiMesh.new()
	gravel.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	gravel.multimesh.use_colors = true
	gravel.multimesh.mesh = mesh
	gravel.multimesh.instance_count = 700
	for i in range(700):
		var pos := Vector2(rng.randf_range(-78,78),rng.randf_range(-78,78))
		var size: float = rng.randf_range(0.08,0.36)
		var basis: Basis = Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size*1.5,size*0.45,size))
		gravel.multimesh.set_instance_transform(i,Transform3D(basis,Vector3(pos.x,-0.01,pos.y)))
		gravel.multimesh.set_instance_color(i,Color("685b54").lerp(Color("a48d76"),rng.randf()))
	world_root.add_child(gravel)

func model(key: String) -> Node3D:
	var path: String = "res://assets/models/%s.glb" % key
	if not asset_cache.has(key):
		if ResourceLoader.exists(path): asset_cache[key] = load(path)
		else: return Node3D.new()
	var scene: PackedScene = asset_cache[key]
	var instance: Node3D = scene.instantiate()
	_style_meshes(instance)
	return instance

func _style_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(index)
			if original is StandardMaterial3D:
				var key: int = original.get_instance_id()
				if not material_cache.has(key):
					var mat: StandardMaterial3D = original.duplicate()
					var name_lower: String = mat.resource_name.to_lower()
					var natural: bool = name_lower.contains("basalt") or name_lower.contains("foliage") or name_lower.contains("mineral")
					mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
					mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
					mat.roughness = 0.48
					if natural: mat.roughness = 0.88
					elif name_lower.contains("steel"): mat.roughness = 0.27
					elif name_lower.contains("chassis"): mat.roughness = 0.52
					elif name_lower.contains("glass") or name_lower.contains("solar"): mat.roughness = 0.22
					elif name_lower.contains("enamel"): mat.roughness = 0.34
					if name_lower.contains("ice") or name_lower.contains("crystal"): mat.roughness = 0.2
					mat.rim_enabled = not natural
					mat.rim = 0.12
					mat.rim_tint = 0.3
					if mat.emission_enabled: mat.emission_energy_multiplier *= 1.25
					mat.next_pass = outline if not natural and not mat.emission_enabled else null
					material_cache[key] = mat
				node.set_surface_override_material(index,material_cache[key])
	for child in node.get_children(): _style_meshes(child)

func _entity(kind: String,id: String,asset: String,location: Array,radius: float,scale_value: float = 1.0) -> Node3D:
	var body := StaticBody3D.new()
	body.set_meta("kind",kind)
	body.set_meta("id",id)
	body.position = Vector3(float(location[0]),0,float(location[1]))
	var visual: Node3D = model(asset)
	visual.scale = Vector3.ONE*scale_value
	visual.set_meta("original_scale",visual.scale)
	body.add_child(visual)
	if asset != "charger":
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.45 if asset == "solar" else radius
		shape.height = 2.1 if kind == "resource" else 3
		collision.shape = shape
		collision.position.y = shape.height/2
		body.add_child(collision)
	world_root.add_child(body)
	visual_nodes[id] = body
	return body

func sync() -> void:
	if campaign == null or campaign.planet.is_empty(): return
	var p: Dictionary = campaign.planet
	for node in p.nodes:
		if node.amount > 0 and visual_nodes.has(node.id):
			var visual: Node3D = visual_nodes[node.id].get_child(0)
			visual.scale = visual.get_meta("original_scale",Vector3.ONE)*lerpf(0.48,1.0,float(node.amount)/float(node.initial))
		if node.amount <= 0 and visual_nodes.has(node.id):
			visual_nodes[node.id].queue_free()
			visual_nodes.erase(node.id)
	var current_buildings: Dictionary = {}
	for b in p.buildings:
		current_buildings[b.id] = true
		if not visual_nodes.has(b.id):
			var radius: float = 2.8 if b.type == "base" else FrontierCatalog.entry("buildings",b.type).radius
			var object: Node3D = _entity("building",b.id,b.type,b.position,radius)
			object.rotation.y = deg_to_rad(float(b.rotation))
			if b.type in ["atmosphere","thermal","water","biolab"]: machine_effects[b.id] = _vent(object)
		if machine_effects.has(b.id): machine_effects[b.id].emitting = b.get("active",false) and controls_enabled
	for id in visual_nodes.keys():
		var node: Node3D = visual_nodes[id]
		if node.get_meta("kind") == "building" and not current_buildings.has(id):
			machine_effects.erase(id)
			node.queue_free()
			visual_nodes.erase(id)
	for robot in p.robots:
		if not robot_nodes.has(robot.id):
			var object: Node3D = model(robot.model)
			var pos: Vector2 = FrontierCampaign.point(robot.position)
			object.position = Vector3(pos.x,0,pos.y)
			world_root.add_child(object)
			robot_nodes[robot.id] = object
			object.set_meta("parts",object.find_children("Anim_*","Node3D",true,false))
			if robot.model == "guardian":
				var turret := Node3D.new()
				turret.name = "AimingTurret"
				turret.position = Vector3(0,1.65,0)
				object.add_child(turret)
				for part in object.get_meta("parts"):
					if part.name.begins_with("Anim_Turret") or part.name.begins_with("Anim_Barrel"): part.reparent(turret,true)
				object.set_meta("turret",turret)
			for part in object.get_meta("parts"): part.set_meta("rest",part.position)
			var badge := Label3D.new()
			badge.text = FrontierCatalog.entry("grades",robot.grade).name
			badge.font = world_font
			badge.font_size = 32
			badge.pixel_size = 0.008
			badge.modulate = Color(FrontierCatalog.entry("grades",robot.grade).color)
			badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			badge.position.y = 2.6
			object.add_child(badge)
	for event in p.events:
		if not visual_nodes.has(event.id): continue
		var object: Node3D = visual_nodes[event.id]
		var visual: Node3D = object.get_child(0)
		visual.visible = event.choice != "capture" and event.choice != "extract"
		visual.scale.y = 0.22 if event.choice == "destroy" else 1.0
	var e: Dictionary = p.environment
	var growth: float = float(e.ecology)/100.0
	for i in range(foliage.size()):
		foliage[i].visible = float(i)/foliage.size() < growth and _decor_clear(Vector2(foliage[i].position.x,foliage[i].position.z),p)
	var next_sky := Vector2(roundf(float(e.toxicity)),roundf(float(e.ecology)))
	if next_sky != sky_state:
		sky_state = next_sky
		sky_material.set_shader_parameter("zenith",Color("213c59").lerp(Color("387fbb"),1.0-next_sky.x/100.0))
		sky_material.set_shader_parameter("horizon",Color("c49b7c").lerp(Color("bed5cd"),next_sky.y/100.0))
		sky_material.set_shader_parameter("life",next_sky.y/100.0)
	environment.fog_light_color = Color("987c75").lerp(Color("8fb4bd"),growth)
	environment.fog_density = lerpf(0.0017,0.0032,float(e.toxicity)/100.0)
	ground_material.set_shader_parameter("growth",growth)
	var water: Node3D = world_root.get_node_or_null("WaterSurface")
	if water:
		water.position.y = lerpf(-0.2,0.035,clampf(float(e.water)/60,0,1))
		water.scale = Vector3.ONE * maxf(0.05,float(e.water)/100)
	_update_local_lights()

func _vent(parent: Node3D) -> CPUParticles3D:
	# Small plumes avoid the Metal particle-shader cleanup warning on release exit.
	var particles := CPUParticles3D.new()
	particles.amount = 12
	particles.lifetime = 2.0
	particles.position.y = 3.4
	particles.visibility_aabb = AABB(Vector3(-2,-1,-2),Vector3(4,7,4))
	particles.direction = Vector3.UP
	particles.spread = 12
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 0.9
	particles.gravity = Vector3(0.1,0.1,0)
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.22
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.65,0.86,0.81,0.22))
	gradient.set_color(1,Color(0.65,0.86,0.81,0))
	particles.color_ramp = gradient
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	parent.add_child(particles)
	return particles

func _physics_process(delta: float) -> void:
	if campaign == null or campaign.planet.is_empty(): return
	if controls_enabled and not orbit_mode:
		var axis := Input.get_vector("frontier_left","frontier_right","frontier_forward","frontier_backward")
		var direction: Vector3 = player.basis * Vector3(axis.x,0,axis.y)
		var speed: float = 9.0 if FrontierInput.pressed("sprint") else 5.5
		player.velocity.x = direction.x*speed
		player.velocity.z = direction.z*speed
		player.velocity.y -= 18*delta
		if player.is_on_floor() and FrontierInput.pressed("jump"): player.velocity.y = 6
		var before_move: Vector3 = player.position
		player.move_and_slide()
		FrontierOnboarding.record(campaign.state,"travel",Vector2(player.position.x-before_move.x,player.position.z-before_move.z).length())
		player.position.x = clampf(player.position.x,-77,77)
		player.position.z = clampf(player.position.z,-77,77)
		campaign.planet.player.position = [player.position.x,player.position.z]
		campaign.planet.player.yaw = player.rotation.y
	_update_target()
	if not build_kind.is_empty(): _update_ghost()

func _process(delta: float) -> void:
	elapsed += delta
	light_clock += delta
	if light_clock >= 0.5:
		light_clock = 0
		_update_local_lights()
	beam.visible = false
	impact.emitting = false
	effects.running = controls_enabled
	if campaign == null: return
	if campaign.planet.is_empty():
		orbital_camera.position = Vector3(18+sin(elapsed*0.08)*3,13,22)
		orbital_camera.look_at(Vector3(0,0,-1))
		return
	handheld.visible = not orbit_mode
	var mining: bool = controls_enabled and not orbit_mode and build_kind.is_empty() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and target.get("kind","") == "resource" and FrontierCatalog.total(campaign.planet.player.cargo) < 140
	if mining:
		var ore: Dictionary = FrontierCampaign.find_by_id(campaign.planet.nodes,target.id)
		mining = not ore.is_empty() and ore.amount > 0 and FrontierCampaign.point(ore.position).distance_to(FrontierCampaign.point(campaign.planet.player.position)) <= 5
	suction_strength = move_toward(suction_strength,1.0 if mining else 0.0,delta*5)
	recoil = move_toward(recoil,0,delta*5)
	muzzle_light.light_energy = pow(recoil,4)*2.0
	var bob: float = 0.018*sin(elapsed*9) if player.velocity.length() > 1 else 0.005*sin(elapsed*2)
	handheld.position = Vector3(0.36,-0.30+bob, -0.92+recoil*0.13)
	handheld.rotation = Vector3(recoil*0.16,0,-0.03+sin(elapsed*36)*suction_strength*0.007)
	camera.position = Vector3(sin(elapsed*95)*recoil*0.012,cos(elapsed*77)*recoil*0.012,0)
	for part in moving_parts:
		if part.name.begins_with("Anim_Fan"): part.rotate_z(delta*(2+suction_strength*35))
		elif part.name.begins_with("Anim_Piston") or part.name.begins_with("Anim_Collar"):
			part.position = part.get_meta("rest")+Vector3(0,0,recoil*0.075)
	if mining:
		impact.position = target.position
		impact.emitting = true
	for robot in campaign.planet.robots:
		if not robot_nodes.has(robot.id): continue
		var object: Node3D = robot_nodes[robot.id]
		var pos: Vector2 = FrontierCampaign.point(robot.position)
		var destination := Vector3(pos.x,0,pos.y)
		var difference: Vector3 = destination-object.position
		object.position = object.position.lerp(destination,1-exp(-delta*12))
		if difference.length() > 0.03:
			object.rotation.y = lerp_angle(object.rotation.y,atan2(difference.x,difference.z),delta*9)
		for part in object.get_meta("parts",[]):
			if part.name.begins_with("Anim_Wheel") and difference.length() > 0.03 and controls_enabled: part.rotate_y(delta*8)
			elif part.name.begins_with("Anim_Barrel"):
				part.position = part.get_meta("rest")+Vector3(0,0,-0.18*maxf(0,1-fmod(elapsed+float(robot.id.hash()%10)*0.07,0.6)*10)) if robot.status == "전투 작전 중" and controls_enabled else part.get_meta("rest")
		var rotor: Node3D = object.find_child("ToolRotor",true,false)
		if rotor and robot.status == "채광 중": rotor.rotate_y(delta*15)
		object.position.y = sin(elapsed*5+float(robot.id.hash()%20))*0.015
		var working: bool = robot.status in ["채광 중","전투 작전 중"] and controls_enabled
		var endpoint: Dictionary = FrontierCampaign.find_by_id(campaign.planet.nodes,robot.target) if robot.status == "채광 중" else FrontierCampaign.find_by_id(campaign.planet.events,campaign.planet.conflict)
		if working and not endpoint.is_empty():
			var end: Vector2 = FrontierCampaign.point(endpoint.position)
			var point: Vector3 = Vector3(end.x,1.0,end.y)
			var attack: bool = robot.status == "전투 작전 중"
			if attack and object.has_meta("turret"):
				var turret: Node3D = object.get_meta("turret")
				var aim: Vector3 = point-object.position
				turret.rotation.y = lerp_angle(turret.rotation.y,atan2(aim.x,aim.z)-object.rotation.y,minf(1,delta*9))
			if elapsed >= float(combat_clock.get(robot.id,0)):
				combat_clock[robot.id] = elapsed+(0.6 if attack else 0.45)
				if attack:
					effects.pulse(object.position+Vector3(0,1.8,0),point)
					flash_entity(campaign.planet.conflict,Color("ffbd81"))
				else: effects.suction(point,object,endpoint.resource,6)
			if work_effects.has(robot.id): work_effects[robot.id].visible = false
		elif work_effects.has(robot.id): work_effects[robot.id].visible = false
	for event in campaign.planet.events:
		if event.kind == "animal" and visual_nodes.has(event.id):
			var pet: Node3D = visual_nodes[event.id].get_child(0)
			pet.position.y = absf(sin(elapsed*1.8))*0.07
			pet.rotation.y = sin(elapsed*0.4)*0.4

func _work_beam(id: String,origin: Vector3,destination: Vector3,combat: bool) -> void:
	if not work_effects.has(id):
		var effect := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.018
		cylinder.bottom_radius = 0.03
		cylinder.radial_segments = 6
		effect.mesh = cylinder
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("f29a67") if combat else Color("a3e0be")
		effect.material_override = mat
		world_root.add_child(effect)
		work_effects[id] = effect
	var effect: MeshInstance3D = work_effects[id]
	effect.visible = fmod(elapsed,0.5) < 0.12 if combat else true
	effect.position = (origin+destination)*0.5
	effect.mesh.height = origin.distance_to(destination)
	effect.look_at(destination,Vector3.UP)
	effect.rotate_object_local(Vector3.RIGHT,PI/2)

func _unhandled_input(event: InputEvent) -> void:
	if controls_enabled and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not orbit_mode:
		var sensitivity: float = campaign.profile.settings.sensitivity
		player.rotate_y(-event.relative.x*sensitivity)
		head.rotation.x = clampf(head.rotation.x-event.relative.y*sensitivity,-1.35,1.25)

func _update_target() -> void:
	target = {}
	if orbit_mode: return
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*7)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("kind"):
		target = {"kind":hit.collider.get_meta("kind"),"id":hit.collider.get_meta("id"),"position":hit.position}

func begin_build(kind: String) -> void:
	end_build()
	if orbit_mode: toggle_camera()
	build_kind = kind
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost = model(kind)
	_set_ghost_material(ghost)
	world_root.add_child(ghost)

func end_build() -> void:
	build_kind = ""
	if is_instance_valid(ghost): ghost.queue_free()
	ghost = null

func _set_ghost_material(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = ghost_material
	for child in node.get_children(): _set_ghost_material(child)

func _update_ghost() -> void:
	if not is_instance_valid(ghost): return
	var ray: Vector3 = -camera.global_basis.z
	var t: float = -camera.global_position.y/ray.y if ray.y < -0.08 else 9.0
	t = clampf(t,4,14)
	var location: Vector3 = camera.global_position+ray*t
	ghost_location = Vector2(snappedf(location.x,2),snappedf(location.z,2))
	ghost.position = Vector3(ghost_location.x,0.03,ghost_location.y)
	ghost.rotation.y = deg_to_rad(float(build_rotation))
	ghost_material.albedo_color = Color(0.4,1,0.8,0.5) if campaign.placement_error(build_kind,ghost_location).is_empty() else Color(1,0.26,0.18,0.55)

func toggle_camera() -> void:
	orbit_mode = not orbit_mode
	if orbit_mode:
		orbital_camera.position = player.position + Vector3(23,27,29)
		orbital_camera.look_at(player.position)
		orbital_camera.current = true
	else: camera.current = true

func ray_hit(distance: float = 25.0) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*distance)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func mining_feedback(id: String,point: Vector3,resource: String,amount: int,depleted: bool) -> void:
	effects.suction(point,handheld,resource,amount)
	recoil = maxf(recoil,0.12)
	if depleted: effects.burst(point,Color(FrontierCatalog.entry("resources",resource).color),24)
	else: flash_entity(id,Color(FrontierCatalog.entry("resources",resource).color))

func fire_feedback(destination: Vector3,target_id: String = "") -> void:
	recoil = 1.0
	effects.pulse(handheld.to_global(Vector3(0,0,-0.78)),destination)
	if not target_id.is_empty(): flash_entity(target_id,Color("ffbd81"))

func flash_entity(id: String,color: Color) -> void:
	if not visual_nodes.has(id): return
	var entity: Node3D = visual_nodes[id]
	var flash: ShaderMaterial = entity.get_meta("flash") if entity.has_meta("flash") else null
	if flash == null:
		flash = ShaderMaterial.new()
		flash.shader = load("res://assets/materials/hit_flash.gdshader")
		entity.set_meta("flash",flash)
		for mesh in entity.find_children("*","MeshInstance3D",true,false): mesh.material_overlay = flash
	flash.set_shader_parameter("tint",color)
	flash.set_shader_parameter("strength",1.0)
	var previous: Tween = entity.get_meta("flash_tween") if entity.has_meta("flash_tween") else null
	if previous and previous.is_valid(): previous.kill()
	var tween: Tween = entity.create_tween()
	tween.tween_property(flash,"shader_parameter/strength",0.0,0.22)
	entity.set_meta("flash_tween",tween)

func building_feedback(position_value: Vector2) -> void:
	effects.construction(Vector3(position_value.x,0,position_value.y))
	for b in campaign.planet.buildings:
		if FrontierCampaign.point(b.position).is_equal_approx(position_value) and visual_nodes.has(b.id):
			var visual: Node3D = visual_nodes[b.id].get_child(0)
			visual.scale = Vector3.ONE*0.05
			visual.create_tween().tween_property(visual,"scale",Vector3.ONE,0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

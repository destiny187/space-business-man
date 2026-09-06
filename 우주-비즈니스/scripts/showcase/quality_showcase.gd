extends Node3D
## Standalone art direction candidate. No campaign or persistence dependencies.
const MODEL_ROOT := "res://assets/models/showcase/"
const SHADER_ROOT := "res://assets/materials/showcase/"
var camera: Camera3D
var environment: Environment
var overlay: CanvasLayer
var caption: Label
var orbit := false
var dragging := false
var target := Vector3(0,1.45,0)
var assets: Dictionary = {}
var materials: Dictionary = {}
var rng := RandomNumberGenerator.new()
var capture_mode := false
var preset := 0
var shots := [
	[Vector3(8.7,3.8,12.9),Vector3(-.7,1.85,-.4),43.0],
	[Vector3(5.9,3.05,7.8),Vector3(.2,1.62,.6),36.0],
	[Vector3(15,10,20),Vector3(0,1.6,-3),48.0]
]

func _ready() -> void:
	rng.seed = 9206
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(1600,900)
	get_window().content_scale_size = Vector2i(2560,1440) if capture_mode else Vector2i(1920,1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_title("LOCUS — 카툰 렌더링 품질 연구")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().mesh_lod_threshold = 0.5
	RenderingServer.directional_shadow_atlas_set_size(8192,true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH,false,.5,2,50,100)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_HIGH,false,.5,2,50,100)
	RenderingServer.screen_space_roughness_limiter_set_active(true,.2,.18)
	setup_environment()
	build_landscape()
	var hero := place("locus_m07",Vector3(0,0,1))
	hero.name = "HeroM07"
	place("atmos_spire",Vector3(-6.5,height(-6.5,-2.0),-2.0),1.1)
	build_details()
	build_oasis()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.near = .08
	camera.far = 500
	set_shot(0)
	build_overlay()
	print("SHOWCASE_READY: three views, drag orbit, wheel zoom")
	if capture_mode: capture_sequence()

func setup_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADER_ROOT+"sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_512
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = .45
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = .92
	environment.ssao_enabled = true
	environment.ssao_radius = 1.1
	environment.ssao_intensity = 1.8
	environment.ssao_power = 1.2
	environment.ssil_enabled = true
	environment.sdfgi_enabled = "--experimental-gi" in OS.get_cmdline_user_args()
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_min_cell_size = .20
	environment.sdfgi_cascades = 4
	environment.sdfgi_energy = .85
	environment.ssil_radius = 4
	environment.ssil_intensity = .7
	environment.ssr_enabled = true
	environment.glow_enabled = true
	environment.glow_intensity = .30
	environment.glow_bloom = .04
	environment.glow_hdr_threshold = 1.5
	environment.fog_enabled = true
	environment.fog_light_color = Color(.51,.64,.62)
	environment.fog_density = .0025
	environment.volumetric_fog_enabled = "--experimental-gi" in OS.get_cmdline_user_args()
	environment.volumetric_fog_density = .004
	environment.volumetric_fog_length = 80
	environment.volumetric_fog_albedo = Color(.80,.87,.79)
	environment.volumetric_fog_ambient_inject = .18
	environment.fog_sky_affect = .12
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36,-38,0)
	sun.light_color = Color(1,.82,.66)
	sun.light_energy = 1.5
	sun.light_bake_mode = Light3D.BAKE_DYNAMIC
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 80
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = .1
	sun.shadow_normal_bias = 1.7
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_color = Color(.40,.73,1)
	fill.light_energy = .16
	add_child(fill)
	var glow := OmniLight3D.new()
	glow.position = Vector3(-6.5,2.6,-2)
	glow.light_color = Color(.25,1,.78)
	glow.light_energy = 3
	glow.omni_range = 6
	add_child(glow)
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 21
	sphere.height = 42
	sphere.radial_segments = 128
	sphere.rings = 64
	planet.mesh = sphere
	planet.position = Vector3(-100,24,-180)
	var pm := ShaderMaterial.new()
	pm.shader = load(SHADER_ROOT+"planet.gdshader")
	planet.material_override = pm
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(planet)

func height(x: float,z: float) -> float:
	var river := 7.4+sin(z*.095)*2.4
	var bed := exp(-pow((x-river)/2.1,4.0))*.72
	return sin(x*.29)*sin(z*.19)*.22 + sin(z*.35+x*.11)*.10 - bed

func build_landscape() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 170
	var step := .65
	for z in range(n):
		for x in range(n):
			var x0: float = (x-n/2)*step
			var z0: float = (z-n/2)*step-15
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var px: float = x0+offset.x*step
				var pz: float = z0+offset.y*step
				st.set_uv(Vector2(px,pz))
				st.add_vertex(Vector3(px,height(px,pz),pz))
	st.generate_normals()
	st.index()
	var ground := MeshInstance3D.new()
	ground.mesh = st.commit()
	ground.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	var gm := ShaderMaterial.new()
	gm.shader = load(SHADER_ROOT+"terrain.gdshader")
	ground.material_override = gm
	add_child(ground)
	var distant_ground := MeshInstance3D.new()
	var distant_plane := PlaneMesh.new()
	distant_plane.size = Vector2(1600,1600)
	distant_plane.subdivide_width = 128
	distant_plane.subdivide_depth = 128
	distant_ground.mesh = distant_plane
	distant_ground.position.y = -2.5
	var distant_material := gm.duplicate() as ShaderMaterial
	distant_material.set_shader_parameter("distant",true)
	distant_ground.material_override = distant_material
	distant_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(distant_ground)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(18,115)
	plane.subdivide_width = 50
	plane.subdivide_depth = 120
	water.mesh = plane
	water.position = Vector3(10,-.33,-15)
	var wm := ShaderMaterial.new()
	wm.shader = load(SHADER_ROOT+"water.gdshader")
	water.material_override = wm
	add_child(water)
	# Background grouped strata have different scales; no regular cone repetition.
	for i in range(27):
		var x := rng.randf_range(-44,42)
		var z := rng.randf_range(-68,-43)
		var h := rng.randf_range(2.2,6.4)
		var rock := place("mesa_sculpt_"+str(i%3),Vector3(x,-.5,z),1)
		rock.scale = Vector3(rng.randf_range(3.4,6.5),h*.60,rng.randf_range(3.0,5.8))
		rock.rotation.y = rng.randf_range(0,TAU)

func build_details() -> void:
	for i in range(85):
		var x := rng.randf_range(-17,17)
		var z := rng.randf_range(-18,12)
		if Vector2(x,z-1).length()<3.6 or abs(x-7.4-sin(z*.095)*2.4)<2.3: continue
		var s := rng.randf_range(.12,.62)
		var rock := place("sandstone_"+str(i%3),Vector3(x,height(x,z)-s*.22,z),s)
		rock.scale.y *= .52
		rock.rotation.y = rng.randf_range(0,TAU)
	for i in range(135):
		var x := rng.randf_range(-17,16)
		var z := rng.randf_range(-20,10)
		if Vector2(x,z-1).length()<3.3 or abs(x-7.4-sin(z*.095)*2.4)<2.7: continue
		var plant := place("jade_rosette",Vector3(x,height(x,z),z),rng.randf_range(.32,1.2))
		plant.rotation.y = rng.randf_range(0,TAU)
	# Hero-side ore formation establishes the work context.
	for i in range(7):
		var x := 3.5+rng.randf_range(-.55,.55)
		var z := .6+rng.randf_range(-.5,.5)
		var crystal := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = .14
		shape.bottom_radius = rng.randf_range(.14,.28)
		shape.height = rng.randf_range(.45,.95)
		shape.radial_segments = 6
		crystal.mesh = shape
		var tip := MeshInstance3D.new()
		var cap := CylinderMesh.new()
		cap.top_radius = 0.0
		cap.bottom_radius = .14
		cap.height = .23
		cap.radial_segments = 6
		tip.mesh = cap
		tip.position.y = shape.height*.5+.115
		crystal.add_child(tip)
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(.08,.51,.43)
		cm.metallic = .4
		cm.roughness = .23
		crystal.material_override = cm
		tip.material_override = cm
		crystal.position = Vector3(x,height(x,z)+shape.height*.5,z)
		crystal.rotation_degrees.z = rng.randf_range(-22,22)
		add_child(crystal)

func place(key: String,pos: Vector3,size: float=1.0) -> Node3D:
	if not assets.has(key): assets[key] = load(MODEL_ROOT+key+".glb")
	var node: Node3D = assets[key].instantiate()
	add_child(node)
	node.position = pos
	node.scale = Vector3.ONE*size
	style_meshes(node)
	return node

func style_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		for index in range(mi.mesh.get_surface_count()):
			var original := mi.mesh.surface_get_material(index) as StandardMaterial3D
			if original == null: continue
			var key := original.resource_name
			if not materials.has(key):
				if key.begins_with("Rock"):
					var rm := ShaderMaterial.new()
					rm.shader = load(SHADER_ROOT+"terrain.gdshader")
					rm.set_shader_parameter("rock",true)
					materials[key] = rm
				elif key.begins_with("Leaf"):
					var leaf := original.duplicate() as StandardMaterial3D
					leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
					leaf.backlight_enabled = true
					leaf.backlight = Color(.05,.08,.025)
					materials[key] = leaf
				else:
					var m := ShaderMaterial.new()
					m.shader = load(SHADER_ROOT+"enamel.gdshader")
					m.set_shader_parameter("base_color",original.albedo_color)
					m.set_shader_parameter("metal",original.metallic)
					m.set_shader_parameter("rough",original.roughness)
					m.set_shader_parameter("light_color",original.emission)
					m.set_shader_parameter("light_energy",original.emission_energy_multiplier if original.emission_enabled else 0.0)
					materials[key] = m
			mi.set_surface_override_material(index,materials[key])
	for child in node.get_children(): style_meshes(child)

func set_shot(index: int) -> void:
	preset = index
	camera.position = shots[index][0]
	target = shots[index][1]
	camera.fov = shots[index][2]
	camera.look_at(target)

func build_overlay() -> void:
	overlay = CanvasLayer.new()
	add_child(overlay)
	var title := Label.new()
	title.position = Vector2(38,27)
	title.text = "L O C U S   /   F R O N T I E R"
	title.add_theme_font_size_override("font_size",32)
	title.add_theme_color_override("font_color",Color(.95,.91,.77))
	title.add_theme_constant_override("shadow_offset_x",1)
	title.add_theme_constant_override("shadow_offset_y",2)
	title.add_theme_color_override("font_shadow_color",Color(0,0,0,.5))
	overlay.add_child(title)
	caption = Label.new()
	caption.position = Vector2(40,74)
	caption.text = "M–07   •   테라포밍 개척지   /   렌더링 방향 검토"
	caption.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"))
	caption.add_theme_font_size_override("font_size",20)
	caption.modulate = Color(.88,.91,.83)
	overlay.add_child(caption)
	var help := Label.new()
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(40,get_viewport().get_visible_rect().size.y-44)
	help.text = "1 전경   2 로봇 상세   3 풍경     |     드래그 회전 · 휠 확대     |     SPACE 자동 회전   H UI   F12 촬영   ESC 종료"
	help.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"))
	help.add_theme_font_size_override("font_size",20)
	help.modulate = Color(.9,.91,.82,.85)
	overlay.add_child(help)

func _process(delta: float) -> void:
	if orbit:
		camera.position = target+(camera.position-target).rotated(Vector3.UP,delta*.13)
		camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_shot(0)
			KEY_2: set_shot(1)
			KEY_3: set_shot(2)
			KEY_SPACE: orbit = not orbit
			KEY_H: overlay.visible = not overlay.visible
			KEY_F12: save_screenshot()
			KEY_ESCAPE: get_tree().quit()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := .91 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
			var distance := clampf((camera.position-target).length()*factor,4,45)
			camera.position = target+(camera.position-target).normalized()*distance
	if event is InputEventMouseMotion and dragging:
		var offset := camera.position-target
		offset = offset.rotated(Vector3.UP,-event.relative.x*.005)
		var right := camera.global_basis.x
		var next := offset.rotated(right,-event.relative.y*.005)
		if next.normalized().y > .06 and next.normalized().y < .92: offset = next
		camera.position = target+offset
		camera.look_at(target)

func save_screenshot(path: String="") -> void:
	await RenderingServer.frame_post_draw
	if path.is_empty(): path = ProjectSettings.globalize_path("res://../test-results/showcase/manual-"+str(Time.get_unix_time_from_system())+".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var save_error := get_viewport().get_texture().get_image().save_png(path)
	if save_error != OK:
		push_error("Could not save showcase screenshot: "+error_string(save_error))
		return
	print("SHOWCASE_SCREENSHOT ",path)

func capture_sequence() -> void:
	overlay.hide()
	var quick := "--quick" in OS.get_cmdline_user_args()
	var results: Array = []
	var destination := ProjectSettings.globalize_path("res://../test-results/showcase/")
	DirAccess.make_dir_recursive_absolute(destination)
	for index in range(1 if quick else 3):
		set_shot(index)
		await get_tree().create_timer(4.0).timeout
		await save_screenshot(destination+["hero.png","detail.png","landscape.png"][index])
		if quick: break
		var frames: Array[float] = []
		var last := Time.get_ticks_usec()
		for sample in range(120):
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			frames.append((now-last)/1000.0)
			last = now
		frames.sort()
		var mean := 0.0
		for value in frames: mean += value/frames.size()
		results.append({"shot":index,"mean_frame_ms":mean,"p95_frame_ms":frames[114],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"rendered_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var report := {"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"resolution":[get_viewport().get_texture().get_width(),get_viewport().get_texture().get_height()],"samples_per_shot":120,"vsync":"default enabled; displayed frame interval, not GPU time","scope":"standalone art study; no campaign simulation","sdfgi":environment.sdfgi_enabled,"volumetric_fog":environment.volumetric_fog_enabled,"views":results}
	if not quick: FileAccess.open(destination+"measurements.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SHOWCASE_COMPLETE ",JSON.stringify(report))
	get_tree().quit()

func build_oasis() -> void:
	# Plants follow wet banks and pockets rather than a uniform random scatter.
	for entry in [[Vector3(-10,0,0),1.8],[Vector3(-11,0,-6),1.5],[Vector3(11,0,-11),1.8],[Vector3(13,0,-17),1.5],[Vector3(-15,0,-14),2.2],[Vector3(-17,0,5),1.7]]:
		var p: Vector3 = entry[0]
		p.y = height(p.x,p.z)
		place("oasis_tree",p,entry[1])
	for i in range(45):
		var x := rng.randf_range(-13,13)
		var z := rng.randf_range(-12,9)
		if Vector2(x,z-1).length()<3.5 or abs(x-7.4-sin(z*.095)*2.4)<2.4: continue
		place("oasis_blossom",Vector3(x,height(x,z),z),rng.randf_range(.6,1.35))
	var points: Array[Transform3D] = []
	for i in range(4500):
		var x := rng.randf_range(-21,20)
		var z := rng.randf_range(-29,14)
		var bank := absf(x-7.4-sin(z*.095)*2.4)
		var lush := sin(x*.35+z*.27)*cos(z*.43-x*.21)
		if bank<2.15 or Vector2(x,z-1).length()<3.5 or Vector2(x+6.5,z+2).length()<2.3: continue
		if bank>4.8 and lush<.15: continue
		var scale_value := rng.randf_range(.65,1.45)
		points.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale_value),Vector3(x,height(x,z)-.01,z)))
	var source := place("oasis_grass",Vector3.ZERO)
	var nodes: Array[Node] = source.find_children("*","MeshInstance3D",true,false)
	for child in nodes:
		var mi := child as MeshInstance3D
		var batch := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mi.mesh
		mm.instance_count = points.size()
		for i in range(points.size()):
			mm.set_instance_transform(i,points[i]*mi.global_transform)
			mm.set_instance_color(i,Color(.8+rng.randf()*.2,.8+rng.randf()*.2,.8+rng.randf()*.2))
		batch.multimesh = mm
		batch.material_override = mi.get_surface_override_material(0)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
	source.queue_free()

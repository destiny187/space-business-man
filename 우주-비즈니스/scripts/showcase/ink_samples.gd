extends Node3D
## A four-asset studio for the bold contour art direction. No save or campaign.
const INK := "res://assets/materials/ink/"
const SAMPLES := [
	{"id":"robot","title":"01   /   로봇","name":"M–07  ·  자율 채광 로봇","model":"res://assets/models/showcase/locus_m07.glb"},
	{"id":"resource","title":"02   /   자원","name":"청록 광물  ·  구리맥을 품은 결정","model":"res://assets/models/ink-study/mineral_deposit.glb"},
	{"id":"grass","foliage":true,"title":"03   /   풀","name":"개척지 풀  ·  굽은 잎과 잎맥","model":"res://assets/models/ink-study/frontier_grass.glb"},
	{"id":"building","title":"04   /   건물","name":"LOCUS 정제소  ·  광물 가공 시설","model":"res://assets/models/ink-study/ore_refinery.glb"}
]
var samples: Array = SAMPLES.duplicate(true)
var camera: Camera3D
var subject: Node3D
var target := Vector3.ZERO
var contour: ShaderMaterial
var title: Label
var subtitle: Label
var helper: Label
var index := 0
var dragging := false
var orbit := false
var cache: Dictionary = {}
var capture_mode := false
var studio_ground: MeshInstance3D
var stage: Node3D
var direction := Vector3(1.22,.84,1.70).normalized()

func _ready() -> void:
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(1200,1000)
	get_window().content_scale_size = Vector2i(1440,1200)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_title("LOCUS — 굵은 검은선 카툰 / 네 가지 예제")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().scaling_3d_scale = 1.5
	get_viewport().mesh_lod_threshold = .4
	RenderingServer.directional_shadow_atlas_set_size(4096,true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e5e2d6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.65,.73,.90)
	env.ambient_light_energy = .36
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = .9
	env.ssao_intensity = 1.4
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48,-32,0)
	key.light_color = Color(1,.95,.85)
	key.light_energy = 1.35
	key.shadow_enabled = true
	key.shadow_bias = .1
	key.shadow_normal_bias = 1.7
	key.directional_shadow_max_distance = 35
	key.directional_shadow_blend_splits = true
	key.light_angular_distance = 1.6
	add_child(key)
	var ground := MeshInstance3D.new()
	studio_ground = ground
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	ground.mesh = plane
	ground.position.y = -.022
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("dedccd")
	ground_mat.roughness = 1
	ground.material_override = ground_mat
	add_child(ground)
	stage = Node3D.new()
	add_child(stage)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = .05
	camera.far = 120
	camera.current = true
	add_child(camera)
	contour = FrontierInkStyle.attach(self,true)
	build_ui()
	select_sample(0)
	print("INK_STUDIO_READY: 1–4 samples; drag orbit; wheel zoom; O contours")
	if capture_mode: capture_all()

func select_sample(which: int) -> void:
	index = which
	if subject != null:
		stage.remove_child(subject)
		subject.queue_free()
	subject = load(samples[index].model).instantiate()
	stage.add_child(subject)
	apply_materials(subject)
	var box := bounds(subject)
	studio_ground.position.y = box.position.y-.022
	studio_ground.scale = Vector3.ONE*maxf(1.,box.size.length()*.2)
	var center := box.get_center()
	camera.far = maxf(120.,box.size.length()*8.)
	camera.position = center+direction*box.size.length()*2.4
	camera.look_at(center)
	var inv := camera.global_transform.affine_inverse()
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for i in range(8):
		var p := inv*box.get_endpoint(i)
		low = low.min(Vector2(p.x,p.y))
		high = high.max(Vector2(p.x,p.y))
	var extent := high-low
	camera.size = maxf(extent.y,extent.x/(float(get_window().content_scale_size.x)/get_window().content_scale_size.y))*(1.22 if samples[index].get("foliage",false) else 1.45)
	target = center+camera.global_basis.y*camera.size*.035
	camera.position += target-center
	camera.look_at(target)
	contour.set_shader_parameter("outer_width",FrontierInkStyle.config().outer_width if not samples[index].get("foliage",false) else FrontierInkStyle.config().foliage_outer_width)
	contour.set_shader_parameter("inner_width",FrontierInkStyle.config().inner_width if not samples[index].get("foliage",false) else FrontierInkStyle.config().foliage_inner_width)
	contour.set_shader_parameter("crease_depth_floor",.005 if not samples[index].get("foliage",false) else 0.0)
	title.text = samples[index].title
	subtitle.text = samples[index].name

func bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*","MeshInstance3D",true,false):
		var mi := child as MeshInstance3D
		var b: AABB = mi.global_transform*mi.get_aabb()
		if first: result=b; first=false
		else: result=result.merge(b)
	return result

func apply_materials(node: Node) -> void:
	FrontierInkStyle.apply(node,cache)

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var source_font: Font = load("res://assets/fonts/NotoSansKR.ttf")
	var font := FontVariation.new()
	font.base_font = source_font
	font.variation_opentype = {"wght":450}
	var bold := FontVariation.new()
	bold.base_font = source_font
	bold.variation_opentype = {"wght":750}
	title = Label.new()
	title.position = Vector2(65,42)
	title.add_theme_font_override("font",bold)
	title.add_theme_font_size_override("font_size",41)
	title.add_theme_color_override("font_color",Color("121b1f"))
	canvas.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(66,105)
	subtitle.add_theme_font_override("font",font)
	subtitle.add_theme_font_size_override("font_size",23)
	subtitle.add_theme_color_override("font_color",Color("465257"))
	canvas.add_child(subtitle)
	var rubric := Label.new()
	rubric.position = Vector2(65,1132)
	rubric.text = "LOCUS   /   INK STUDY      —      굵은 윤곽선 · 3단 명암 · 재질별 하이라이트"
	rubric.add_theme_font_override("font",font)
	rubric.add_theme_font_size_override("font_size",20)
	rubric.add_theme_color_override("font_color",Color("36474b"))
	canvas.add_child(rubric)
	helper = Label.new()
	helper.position = Vector2(65,1170)
	helper.text = "1–4 예제 선택    드래그 회전    휠 확대    Space 자동 회전    O 외곽선    Esc 종료"
	helper.add_theme_font_override("font",font)
	helper.add_theme_font_size_override("font_size",15)
	helper.add_theme_color_override("font_color",Color("526066"))
	canvas.add_child(helper)

func _process(delta: float) -> void:
	if orbit:
		camera.position = target+(camera.position-target).rotated(Vector3.UP,delta*.22)
		camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4: select_sample(event.keycode-KEY_1)
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		if event.keycode == KEY_SPACE: orbit=not orbit
		if event.keycode == KEY_O:
			var current: float = contour.get_shader_parameter("strength")
			contour.set_shader_parameter("strength",1.0-current)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: camera.size=clampf(camera.size*(.90 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.7,20)
	if event is InputEventMouseMotion and dragging:
		var v := (camera.position-target).rotated(Vector3.UP,-event.relative.x*.005)
		var next := v.rotated(camera.global_basis.x,-event.relative.y*.004)
		if next.normalized().y > .1 and next.normalized().y < .94: v=next
		camera.position=target+v
		camera.look_at(target)

func capture_all() -> void:
	helper.hide()
	var dest := ProjectSettings.globalize_path("res://../test-results/ink-study/")
	DirAccess.make_dir_recursive_absolute(dest)
	var board := Image.create(2880,2400,false,Image.FORMAT_RGBA8)
	var records: Array = []
	for i in range(4):
		select_sample(i)
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		assert(shot.save_png(dest+SAMPLES[i].id+".png") == OK)
		board.blit_rect(shot,Rect2i(0,0,1440,1200),Vector2i((i%2)*1440,(i/2)*1200))
		records.append({"id":SAMPLES[i].id,"resolution":[shot.get_width(),shot.get_height()],"model":SAMPLES[i].model})
		print("INK_RENDER ",SAMPLES[i].id)
		if "--quick" in OS.get_cmdline_user_args(): break
	if not "--quick" in OS.get_cmdline_user_args():
		board.fill_rect(Rect2i(1439,0,2,2400),Color("c7c9bd"))
		board.fill_rect(Rect2i(0,1199,2880,2),Color("c7c9bd"))
		assert(board.save_png(dest+"ink-contact-sheet.png") == OK)
		FileAccess.open(dest+"renders.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"samples":records,"native_engine_pixels":true,"render_scale_3d":1.5,"msaa":4,"board":"unscaled four-panel assembly"},"  "))
	print("INK_CAPTURE_COMPLETE")
	get_tree().quit()

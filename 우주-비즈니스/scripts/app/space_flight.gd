class_name FrontierSpaceFlight
extends Node3D

var state: Dictionary = {}
var store := FrontierWorldStore.new()
var ship: Node3D
var camera: Camera3D
var planets := {}
var landmarks: FrontierSystemLandmarks
var sky_material: ShaderMaterial
var system_art: Node3D
var galactic_core: FrontierGalacticCore
var orbit_time:=0.0
var current_system := 0
var target_ordinal := 0
var autopilot := false
var speed := 0.0
var jump_remaining := 0.0
var pending_ordinal := -1
var jump_direction := Vector3.FORWARD
var flight_config: Dictionary
var status: Label
var destination: Label
var address: LineEdit
var sidebar: VBoxContainer
var cursor_label: Label
var travel_distance := 0.0
var test_mode := false
var cache: Dictionary = {}
var ui_root: Control

func _ready() -> void:
	test_mode = "--exploration-test" in OS.get_cmdline_user_args()
	if test_mode: store = FrontierWorldStore.new("user://test_exploration_ui.json")
	state = store.read_state()
	if state.is_empty() and store.has_history():
		FrontierWorldLoadError.show_error(self,store.last_error)
		return
	if state.is_empty(): state = FrontierUniverse.new_world(int(FrontierUniverse.config().starting_seed))
	if state.get("mode","space")=="surface":
		set_physics_process(false)
		get_tree().call_deferred("change_scene_to_file","res://scenes/app/planet_exploration.tscn")
		return
	flight_config = state.manifest.settings.flight
	target_ordinal = FrontierUniverse.ordinal_of(state.manifest, state.get("navigation_target",state.location))
	current_system = FrontierUniverse.system_index(state.manifest,FrontierUniverse.ordinal_of(state.manifest,state.location))
	_setup_space()
	_build_ui()
	_load_system(current_system)
	ship.position = Vector3(state.flight_position[0],state.flight_position[1],state.flight_position[2])
	_select(target_ordinal)

func _setup_space() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/materials/space/sky.gdshader")
	sky.sky_material = sky_mat
	sky_material=sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("879caf")
	env.ambient_light_energy = .45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled=true;env.glow_intensity=.85;env.glow_bloom=.08
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28,-40,0)
	sun.light_color = Color("ffedd6")
	sun.light_energy = .35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(15,140,0)
	fill.light_color = Color("8cb9d3")
	fill.light_energy = .25
	add_child(fill)
	ship = Node3D.new()
	ship.name = "Kestrel"
	add_child(ship)
	var hull: Node3D = load("res://assets/models/ships/kestrel.glb").instantiate()
	FrontierInkStyle.apply(hull,cache)
	ship.add_child(hull)
	camera = Camera3D.new()
	camera.position = Vector3(0,8,31)
	camera.rotation_degrees.x = -10
	camera.fov = 65
	camera.far = 160000
	ship.add_child(camera)
	camera.current = true
	FrontierInkStyle.attach(ship)
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

func _load_system(index: int) -> void:
	for entry in planets.values():
		remove_child(entry.node)
		entry.node.queue_free()
	planets.clear()
	current_system = index
	if galactic_core!=null:galactic_core.queue_free();galactic_core=null
	var s: Dictionary = FrontierUniverse.system(state.manifest,index)
	for orbit in FrontierUniverse.body_count(state.manifest,index):
		var ordinal: int = FrontierUniverse.first_ordinal(state.manifest,index)+orbit
		var body: Dictionary = FrontierUniverse.body(state.manifest,ordinal)
		var radius: float = FrontierUniverse.radius(body)
		if body.get("origin","")=="solar_reference":
			var solar:=FrontierSolarPlanet.new();solar.name="Planet_%d"%ordinal;add_child(solar);solar.configure(orbit,radius)
			solar.position=FrontierUniverse.position(state.manifest,ordinal,orbit_time);solar.set_epoch(orbit_time)
			planets[ordinal]={"node":solar,"radius":FrontierUniverse.navigation_radius(body),"body":body}
			continue
		var node := MeshInstance3D.new()
		node.name = "Planet_%d" % ordinal
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius*2
		sphere.radial_segments = 128
		sphere.rings = 64
		node.mesh = sphere
		node.position = FrontierUniverse.position(state.manifest,ordinal,orbit_time)
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/materials/space/planet.gdshader")
		material.set_shader_parameter("seed_offset",float(body.streams.terrain % 10000))
		material.set_shader_parameter("rough",.94)
		var t: Dictionary=body.traits
		var template: Node3D=load("res://assets/models/planet-variants/"+str(t.id)+".glb").instantiate()
		var authored: MeshInstance3D=template.find_children("*","MeshInstance3D",true,false)[0]
		node.mesh=authored.mesh;node.scale=Vector3.ONE*radius;template.free()
		material.set_shader_parameter("authored_relief",true)
		material.set_shader_parameter("highlight_strength",.08)
		material.set_shader_parameter("gas_bands",not FrontierUniverse.landable(body))
		material.set_shader_parameter("land_color",Color(t.dust))
		material.set_shader_parameter("sea_color",Color(t.sea))
		material.set_shader_parameter("rock_color",Color(t.rock))
		material.set_shader_parameter("sea_level",lerpf(.20,.61,float(t.water)/100.0) if float(t.water)>0 else 0.0)
		material.set_shader_parameter("cloud_amount",float(t.cloud))
		material.set_shader_parameter("seed_offset",float(t.pattern_seed))
		material.set_shader_parameter("molten",t.id=="volcanic")

		node.material_override = material
		add_child(node)
		var atmosphere := MeshInstance3D.new()
		atmosphere.mesh = node.mesh
		atmosphere.scale = Vector3.ONE*1.018
		var air := ShaderMaterial.new()
		air.shader = load("res://assets/materials/space/atmosphere.gdshader")
		air.set_shader_parameter("tint",Color(t.sea).lightened(.35))
		atmosphere.material_override = air
		atmosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(atmosphere)
		planets[ordinal] = {"node":node,"radius":radius,"body":body}
	_build_system_art(s)
	_refresh_candidates()
	status.text = "%s · 항성계 %08d · 주변 천체 %d개" % [state.manifest.settings.band_names[int(s.band)],index+1,FrontierUniverse.body_count(state.manifest,index)]

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):500.0}
	var theme_value := Theme.new()
	theme_value.default_font = font
	theme_value.default_font_size = 15
	for key in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.035,.095,.12,.87) if key == "normal" else Color("30594e")
		style.border_color = Color("74a797")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 12
		style.content_margin_right = 12
		theme_value.set_stylebox(key,"Button",style)
	ui_root.theme = theme_value
	var header := VBoxContainer.new()
	header.position = Vector2(28,24)
	header.custom_minimum_size.x = 740
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(header)
	_label(header,"L O C U S   /   K E S T R E L",23,Color("c8e3d4"))
	status = _label(header,"항법 시스템 준비",15)
	_label(header,"W/S 추진 · A/D 선회 · ↑/↓ 기수 · Shift 가속 · Space 제동",13,Color("a9bdbd"))
	_label(header,"천체 클릭: 조준  /  F: 자동 접근  /  C: 시점  /  Tab: 항법 패널  /  F5: 저장",13,Color("a9bdbd"))
	var panel := PanelContainer.new()
	panel.name = "NavigationPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-310,24)
	panel.custom_minimum_size = Vector2(282,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025,.065,.09,.90)
	style.border_color = Color("36585e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	for side in ["left","right","top","bottom"]: style.set("content_margin_"+side,14)
	panel.add_theme_stylebox_override("panel",style)
	ui_root.add_child(panel)
	panel.anchor_bottom=1
	panel.offset_bottom=-54
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	_label(column,"원정 항법",22,Color("a0dfc5"))
	_label(column,"한 은하 · 시드 %d\n100만 개의 행성 주소" % int(state.manifest.seed),14)
	address = LineEdit.new()
	address.placeholder_text = "행성 번호 1 ~ %d" % int(state.manifest.settings.planet_count)
	address.max_length = str(int(state.manifest.settings.planet_count)).length()
	column.add_child(address)
	_button(column,"목적지 설정",_address_target)
	destination = _label(column,"",15,Color("eac89a"))
	_button(column,"항해 시작  F",start_travel)
	_button(column,"선정 행성에 착륙",land)
	sidebar = VBoxContainer.new()
	column.add_child(sidebar)
	_button(column,"관측 자료",_observations)
	_button(column,"항해 저장",save_flight)
	cursor_label = Label.new()
	cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_label.add_theme_color_override("font_color",Color("c1eadc"))
	ui_root.add_child(cursor_label)
	var footer := Label.new()
	footer.text = "3D 항해 실증  ·  천체 크기·거리는 플레이용 축약  ·  생성 지형과 생태는 가상"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(28,-35)
	footer.add_theme_font_size_override("font_size",12)
	footer.add_theme_color_override("font_color",Color("a9bdbd"))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(footer)

func _label(parent: Node,text_value: String,size_value: int=15,color: Color=Color("d8e2df")) -> Label:
	var label_value := Label.new()
	label_value.text = text_value
	label_value.add_theme_font_size_override("font_size",size_value)
	label_value.add_theme_color_override("font_color",color)
	label_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_value.custom_minimum_size.x = 230
	parent.add_child(label_value)
	return label_value

func _button(parent: Node,text_value: String,action: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)

func _refresh_candidates() -> void:
	for child in sidebar.get_children():sidebar.remove_child(child);child.queue_free()
	_label(sidebar,"주변 천체",14)
	for ordinal in planets:
		var body: Dictionary = planets[ordinal].body
		_button(sidebar,"%s · T%d" % [body.name,int(body.planet_tier)],_select.bind(ordinal))

func _select(ordinal: int) -> void:
	if jump_remaining>0:status.text="도약 완료 후 목적지를 변경할 수 있습니다.";return
	var body: Dictionary = FrontierUniverse.body(state.manifest,ordinal)
	if body.is_empty():return
	target_ordinal = ordinal
	autopilot = false
	address.text = str(ordinal+1)
	destination.text = "%s · T%d\n%s" % [body.name,int(body.planet_tier),FrontierUniverse.kind_label(body)]+"\n"+FrontierMineralWorld.summary(body)
	if not FrontierUniverse.landable(body):destination.text+="\n착륙 불가 · 궤도 탐사 대상";return
	var habitat: Dictionary=FrontierEcology.profile(body)
	destination.text+="\n궤도 추정 %.1f°C · %.0f kPa\n%s · 착륙 후 생명 신호 조사"%[habitat.temperature,habitat.pressure,FrontierEcologyCatalog.config().habitats[habitat.environment].label]

func _address_target() -> void:
	if not address.text.is_valid_int() or int(address.text)<1 or int(address.text)>int(state.manifest.settings.planet_count):
		status.text = "행성 번호는 1~%d 정수입니다." % int(state.manifest.settings.planet_count)
		return
	_select(int(address.text)-1)

func start_travel() -> void:
	if jump_remaining > 0:return
	if FrontierUniverse.system_index(state.manifest,target_ordinal) != current_system:
		pending_ordinal = target_ordinal
		jump_remaining = float(flight_config.jump_seconds)
		cursor_label.hide()
		jump_direction = -ship.basis.z
		var nearest := INF
		for entry in planets.values():
			var distance: float = ship.position.distance_to(entry.node.position)
			if distance<nearest:
				nearest=distance
				jump_direction=(ship.position-entry.node.position).normalized()
		autopilot = false
		status.text = "도약 항로 진입 · 먼 항성계 이동을 압축합니다."
	else:autopilot = true
	get_viewport().gui_release_focus()

func _physics_process(delta: float) -> void:
	step_flight(minf(delta,.1))

func _flight_basis(direction: Vector3) -> Basis:
	if direction.length_squared()<0.000001:direction=Vector3.FORWARD
	var up: Vector3=Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP))>.98 else Vector3.UP
	return Basis.looking_at(direction,up)

func step_flight(delta: float) -> void:
	var before := ship.position
	if jump_remaining>0:
		jump_remaining = maxf(0,jump_remaining-delta)
		ship.quaternion=ship.quaternion.slerp(_flight_basis(jump_direction).get_rotation_quaternion(),minf(delta*3,1))
		ship.position += jump_direction*float(flight_config.boost_speed)*delta
		camera.fov = lerpf(camera.fov,100.0,minf(delta*3,1))
		if jump_remaining<=0:
			_load_system(FrontierUniverse.system_index(state.manifest,pending_ordinal))
			ship.position = Vector3(0,2200,0) if state.manifest.settings.generator_version=="galaxy-v3" else Vector3(0,0,80)
			ship.rotation = Vector3.ZERO
			target_ordinal = pending_ordinal
			pending_ordinal = -1
			autopilot = true
			speed = float(flight_config.cruise_speed)
		return
	camera.fov = lerpf(camera.fov,65.0,minf(delta*3,1))
	if autopilot and planets.has(target_ordinal):
		var target: Dictionary = planets[target_ordinal]
		var center: Vector3 = target.node.position
		var separation: float = ship.position.distance_to(center)-float(target.radius)
		if separation <= float(flight_config.arrival_clearance)+3:
			autopilot = false
			speed = 0
			state.location = target.body.id
			state.visited[target.body.id] = true
			status.text = "궤도 접근 완료 · %s 조사 위치" % target.body.name
		else:
			var direction: Vector3 = (center-ship.position).normalized()
			ship.quaternion = ship.quaternion.slerp(_flight_basis(direction).get_rotation_quaternion(),minf(delta*2,1))
			speed = move_toward(speed,minf(float(flight_config.cruise_speed),maxf(12,separation-float(flight_config.arrival_clearance))),float(flight_config.acceleration)*delta)
			ship.position += direction*minf(speed*delta,maxf(0,separation-float(flight_config.arrival_clearance)))
	else:
		var focused: bool = get_viewport().gui_get_focus_owner() is LineEdit
		if not focused and not test_mode:
			var yaw_input: float = float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D))
			var pitch_input: float = float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN))
			ship.rotate_object_local(Vector3.UP,yaw_input*delta*.65)
			ship.rotate_object_local(Vector3.RIGHT,pitch_input*delta*.5)
			var throttle: float = float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S))
			var maximum: float = float(flight_config.boost_speed) if Input.is_physical_key_pressed(KEY_SHIFT) else float(flight_config.cruise_speed)
			speed = clampf(speed+throttle*float(flight_config.acceleration)*delta,0,maximum)
			if Input.is_physical_key_pressed(KEY_SPACE):speed = move_toward(speed,0,float(flight_config.acceleration)*3*delta)
		ship.position -= ship.basis.z*speed*delta
	for entry in planets.values():
		var center: Vector3 = entry.node.position
		var min_distance: float = float(entry.radius)+28
		if ship.position.distance_to(center)<min_distance:
			ship.position = center+(ship.position-center).normalized()*min_distance
			speed = 0
			autopilot = false
			status.text = "지표 접근 한계 · 기수를 돌려 안전 거리를 확보하세요."
	travel_distance += before.distance_to(ship.position)
	if ship.position.length()>90000:
		ship.position = before;speed = 0;status.text = "항성계 운항 경계 · 항법으로 다음 목적지를 선택하세요."
	_update_target_marker()

func _update_target_marker() -> void:
	cursor_label.visible = planets.has(target_ordinal) and jump_remaining<=0
	if not cursor_label.visible:return
	var entry: Dictionary = planets[target_ordinal]
	if camera.is_position_behind(entry.node.position):cursor_label.visible=false;return
	var p: Vector2 = camera.unproject_position(entry.node.position)
	cursor_label.position = p+Vector2(20,-25)
	cursor_label.text = "◇ %s\n%.0f m · %.0f m/s" % [entry.body.name,maxf(0,ship.position.distance_to(entry.node.position)-entry.radius),speed]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F:start_travel()
		elif event.physical_keycode==KEY_F5:save_flight()
		elif event.physical_keycode==KEY_TAB:ui_root.get_node("NavigationPanel").visible = not ui_root.get_node("NavigationPanel").visible
		elif event.physical_keycode==KEY_SPACE:autopilot=false
		elif event.physical_keycode==KEY_C:
			camera.position = Vector3(24,12,24) if camera.position.x==0 else Vector3(0,8,31)
			camera.look_at(ship.global_position+ship.basis*Vector3(0,0,-8),ship.basis.y)
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var ray: Vector3 = camera.project_ray_normal(event.position)
		var best := -1
		var nearest := INF
		for ordinal in planets:
			var entry: Dictionary = planets[ordinal]
			var offset: Vector3 = entry.node.position-camera.global_position
			var along: float = offset.dot(ray)
			if along>0 and along<nearest and (offset-ray*along).length()<entry.radius:nearest=along;best=ordinal
		if best>=0:_select(best)

func save_flight() -> void:
	if jump_remaining>0:status.text="도약 완료 후 저장할 수 있습니다.";return
	# Save current system, not an unvisited destination in another system.
	state.location = FrontierUniverse.body_id(state.manifest,FrontierUniverse.first_ordinal(state.manifest,current_system))
	state.navigation_target = FrontierUniverse.body_id(state.manifest,target_ordinal)
	state.flight_position = [ship.position.x,ship.position.y,ship.position.z]
	status.text = "항해 위치와 조사 기록을 저장했습니다." if store.write(state) else store.last_error

func land() -> bool:
	if jump_remaining>0 or not planets.has(target_ordinal):status.text="먼저 대상 행성의 궤도로 접근하세요.";return false
	var entry: Dictionary=planets[target_ordinal]
	if not FrontierUniverse.landable(entry.body):status.text="착륙 불가 · 가스/얼음 거대행성";return false
	if ship.position.distance_to(entry.node.position)-entry.radius>float(flight_config.arrival_clearance)+10:
		status.text="자동 접근을 완료한 뒤 착륙할 수 있습니다.";return false
	var next: Dictionary=state.duplicate(true)
	next.location=entry.body.id
	next.navigation_target=entry.body.id
	next.flight_position=[ship.position.x,ship.position.y,ship.position.z]
	next.mode="surface"
	if not next.has("terrain_settings"):
		next.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
		next.terrain_settings_hash=FrontierUniverse.fingerprint(next.terrain_settings)
	if not store.write(next):status.text=store.last_error;return false
	state=next
	get_tree().change_scene_to_file("res://scenes/app/planet_exploration.tscn")
	return true

func _observations() -> void:
	var popup := AcceptDialog.new()
	popup.title = "실제 관측 자료 · NASA Exoplanet Archive / PS"
	var lines: PackedStringArray = []
	for record in state.manifest.catalog.records:
		lines.append("%s  |  반지름 %s 지구반지름  |  평형 온도 %s K" % [record.name,str(record.values.radius.value),str(record.values.equilibrium_temperature.value)])
	lines.append("\n평형 온도는 지표 실측값이 아닙니다. 출처와 오차는 동봉 카탈로그에 보존합니다.\n성도의 천체·지형·생명은 가상이며, 위 관측 천체와 구분합니다.")
	popup.dialog_text = "\n".join(lines)
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
	ui_root.add_child(popup)
	popup.popup_centered(Vector2i(760,260))

func _build_system_art(system_value: Dictionary) -> void:
	if is_instance_valid(system_art):remove_child(system_art);system_art.queue_free()
	system_art=Node3D.new();add_child(system_art)
	if state.manifest.settings.generator_version!="galaxy-v3":return
	var stellar_radius: float=FrontierUniverse.system_layout(state.manifest,current_system).star_radius
	var star:=FrontierStarVisual.new();star.name="StarVisual";system_art.add_child(star);star.configure(system_value,stellar_radius)
	var label:=Label3D.new();label.text=system_value.star.name;label.font=load("res://assets/fonts/NotoSansKR.ttf");label.font_size=64;label.pixel_size=3;label.position=Vector3(0,stellar_radius*.8,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;system_art.add_child(label)
	for entry in planets.values():
		var caption:=Label3D.new();caption.text=entry.body.name+("" if FrontierUniverse.landable(entry.body) else " · 착륙 불가");caption.font=label.font;caption.font_size=48;caption.pixel_size=2.0;caption.position.y=entry.radius+130;caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED;entry.node.add_child(caption)

	landmarks=FrontierSystemLandmarks.new();system_art.add_child(landmarks);landmarks.configure(state.manifest,current_system,planets)
	var theme: String=FrontierUniverse.system_layout(state.manifest,current_system).theme
	if sky_material!=null:
		sky_material.set_shader_parameter("local_haze",{"open":.03,"debris":.22,"satellites":.10,"giant_court":.16}.get(theme,0.0))
		sky_material.set_shader_parameter("haze_color",{"debris":Color("b39169"),"satellites":Color("649cbb"),"giant_court":Color("887fb5")}.get(theme,Color("658aab")))

func update_orbits(elapsed: float) -> void:
	orbit_time=elapsed
	if is_instance_valid(landmarks):landmarks.update_epoch(elapsed)
	for ordinal in planets:
		planets[ordinal].node.position=FrontierUniverse.position(state.manifest,ordinal,elapsed)
		if planets[ordinal].node is FrontierSolarPlanet:planets[ordinal].node.set_epoch(elapsed)

func _process(_delta: float) -> void:
	_update_galactic_core()

func _update_galactic_core() -> void:
	if state.is_empty() or camera==null:return
	var local_viewer:=to_local(camera.global_position)
	var view:=FrontierUniverse.central_view(state.manifest,current_system,local_viewer)
	if not view.visible:
		if galactic_core!=null:galactic_core.hide()
		return
	if galactic_core==null:
		galactic_core=FrontierGalacticCore.new();galactic_core.name="CentralBlackHole";add_child(galactic_core)
	galactic_core.show()
	# Floating-origin render projection preserves direction and angular size.
	# The actual celestial position stays at galaxy center, never follows the ship.
	var distance: float=camera.far*.82
	galactic_core.position=local_viewer+Vector3(view.direction)*distance
	galactic_core.scale=Vector3.ONE*float(view.angular_scale)*distance
	galactic_core.look_at(camera.global_position,Vector3.UP,true)
	galactic_core.rotate_object_local(Vector3.RIGHT,.20)

class_name FrontierPlanetExploration
extends Node3D
var state: Dictionary={}
var store:=FrontierWorldStore.new()
var body: Dictionary
var terrain: FrontierTerrainStreamer
var distant: FrontierDistantTerrain
var player: CharacterBody3D
var head: Node3D
var camera: Camera3D
var environment: Environment
var hud: Label
var message: Label
var menu: PanelContainer
var config: Dictionary
var body_id: String
var spawn:=Vector3(0,4,0)
var ship_position:=Vector3(-12,5,12)
var cooldown:=0.0
var test_mode:=false
var moving_enabled:=false
var last_anchor:=Vector3i(99999,99999,99999)
var debug_visible:=false
var movement_input:=Vector2.ZERO
var material_cache: Dictionary={}
var courier: FrontierSurfaceCourier
var logistics: Dictionary
var render_settings: Dictionary
var headlamp: SpotLight3D
var lamp_timer:=0.0
var lamp_target:=0.0
var lamp_mode: String="auto"
var ecology_view: FrontierSurfaceEcology
var journal: FrontierEcologyJournal
var ecology_hud: Label
var scan_progress:=0.0
var scan_id: String=""
var scan_held:=false
var ecology_tick:=0.0
var current_encounter: Dictionary={}
var autosave_timer:=0.0
var plot_marker: MeshInstance3D


func _ready() -> void:
	render_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_render.json"))
	test_mode="--exploration-test" in OS.get_cmdline_user_args()
	if test_mode:store=FrontierWorldStore.new("user://test_exploration_ui.json")
	state=store.read_state()
	if state.is_empty() and store.has_history():
		FrontierWorldLoadError.show_error(self,store.last_error)
		return
	if state.is_empty():state=FrontierUniverse.new_world(71491)
	get_tree().auto_accept_quit=false
	body_id=state.location
	body=FrontierUniverse.body_from_id(state.manifest,body_id)
	if not state.has("terrain_settings"):
		state.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
		state.terrain_settings_hash=FrontierUniverse.fingerprint(state.terrain_settings)
	config=state.terrain_settings
	if not state.has("surface_positions"):state.surface_positions={}
	if state.surface_positions.has(body_id):
		var point: Array=state.surface_positions[body_id]
		spawn=Vector3(point[0],point[1],point[2])
	_setup_environment()
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://assets/materials/space/terrain.gdshader")
	mat.set_shader_parameter("rough",.96)
	if body.kind=="glacial":
		mat.set_shader_parameter("rock_color",Color("4e777f"));mat.set_shader_parameter("dust_color",Color("b9cdd0"))
	elif body.kind=="sulfur":
		mat.set_shader_parameter("rock_color",Color("7c634b"));mat.set_shader_parameter("dust_color",Color("b39962"))
	terrain=FrontierTerrainStreamer.new()
	terrain.configure(int(body.streams.terrain),state.terrain_edits.get(body_id,[]),mat,config)
	add_child(terrain)
	distant=FrontierDistantTerrain.new()
	add_child(distant)
	_setup_player()
	_setup_ship()
	_setup_ui()
	_setup_logistics()
	_setup_ecology()
	terrain.geometry_changed.connect(func():message.text="굴착을 완료했습니다.";_refresh_distant())
	_update_interest()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if test_mode else Input.MOUSE_MODE_CAPTURED

func _setup_environment() -> void:
	var world:=WorldEnvironment.new()
	environment=Environment.new()
	environment.background_mode=Environment.BG_SKY
	var sky:=Sky.new()
	var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("253748")
	sky_material.sky_horizon_color=Color("c6ae91")
	sky_material.ground_horizon_color=Color("b99977")
	sky_material.ground_bottom_color=Color("433844")
	sky.sky_material=sky_material
	environment.sky=sky
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("a2b5c5")
	environment.ambient_light_energy=.28
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled=true
	environment.fog_light_color=Color("b8a080")
	environment.fog_density=.0007
	environment.ssao_enabled=true
	environment.ssao_radius=1.2
	environment.ssao_intensity=1.2
	world.environment=environment
	add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-35,-30,0)
	sun.light_color=Color("ffe1b5")
	sun.light_energy=1.8
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=180
	add_child(sun)
	get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA

func _setup_player() -> void:
	player=CharacterBody3D.new()
	player.name="Explorer"
	player.position=spawn
	player.rotation.y=-PI/2
	player.floor_snap_length=.6
	var collision:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.4;capsule.height=1.8
	collision.shape=capsule
	player.add_child(collision)
	add_child(player)
	head=Node3D.new();head.position.y=.65;head.rotation.x=-.1;player.add_child(head)
	camera=Camera3D.new();camera.fov=72;camera.far=1800;head.add_child(camera);camera.current=true
	var lamp:=SpotLight3D.new()
	headlamp=lamp
	lamp.position=Vector3(.15,-.1,0)
	lamp.light_color=Color("d5f0eb")
	lamp.light_energy=0.0
	lamp.spot_range=60
	lamp.spot_angle=48
	lamp.shadow_enabled=true
	camera.add_child(lamp)
	FrontierInkStyle.attach(player)

func _setup_ship() -> void:
	var ship: Node3D=load("res://assets/models/ships/kestrel.glb").instantiate()
	ship.position=ship_position
	FrontierInkStyle.apply(ship,material_cache)
	add_child(ship)

func _setup_logistics() -> void:
	if not state.has("surface_logistics"):state.surface_logistics={}
	if not state.surface_logistics.has(body_id):state.surface_logistics[body_id]=FrontierSurfaceLogistics.create()
	logistics=state.surface_logistics[body_id]
	courier=FrontierSurfaceCourier.new()
	courier.configure(logistics,terrain,player)
	add_child(courier)
	courier.status_changed.connect(func(text: String):message.text=text)

func _setup_ui() -> void:
	var layer:=CanvasLayer.new();add_child(layer)
	var font:=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):500.0}
	var theme_value:=Theme.new();theme_value.default_font=font;theme_value.default_font_size=16
	theme_value.set_color("font_outline_color","Label",Color(0.03,0.035,0.04,.9))
	theme_value.set_constant("outline_size","Label",3)
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=theme_value;layer.add_child(root)
	hud=Label.new();hud.position=Vector2(24,22);root.add_child(hud)
	message=Label.new();message.position=Vector2(24,140);message.text="착륙 지점을 확인하고 있습니다.";root.add_child(message)
	var cross:=Label.new();cross.text="+";cross.add_theme_font_size_override("font_size",26);cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER);cross.position=Vector2(-8,-18);root.add_child(cross)
	var footer:=Label.new();footer.text="WASD 이동 · Shift 달리기 · Space 점프 · 클릭 굴착 · R 로봇 · E 스캔 · Q 표본 · J 생태 · L 조명 · F5 저장 · Esc 메뉴";footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);footer.position=Vector2(24,-38);footer.add_theme_font_size_override("font_size",13);root.add_child(footer)
	menu=PanelContainer.new();menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER);menu.position=Vector2(-180,-120);menu.custom_minimum_size=Vector2(360,220);root.add_child(menu)
	var column:=VBoxContainer.new();menu.add_child(column)
	for entry in [["현장 복귀",_resume],["탐사 기록 저장",save_surface],["우주선 출항",return_to_orbit],["착륙 지점으로 구조 요청",rescue]]:
		var button:=Button.new();button.text=entry[0];button.custom_minimum_size.y=45;button.pressed.connect(entry[1]);column.add_child(button)
	menu.hide()
	ecology_hud=Label.new();ecology_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);ecology_hud.position=Vector2(-390,28);ecology_hud.custom_minimum_size=Vector2(365,110);ecology_hud.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;root.add_child(ecology_hud)
	journal=FrontierEcologyJournal.new();root.add_child(journal);journal.configure(self)

func _resume() -> void:
	menu.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _update_interest() -> void:
	var interests: Array[Vector3]=[player.position]
	if is_instance_valid(courier):interests.append(courier.position)
	terrain.update_interests(interests)
	var anchor:=terrain.field.key_at(player.position)
	if anchor!=last_anchor:last_anchor=anchor;_refresh_distant()

func _refresh_distant() -> void:
	distant.rebuild(terrain.field,terrain.field.key_at(player.position),int(config.active_radius),terrain.material)

func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	_process_ecology(delta)
	autosave_timer+=delta
	if autosave_timer>=30.0:
		autosave_timer=0
		save_surface()
	headlamp.light_energy=lerpf(headlamp.light_energy,lamp_target,minf(1,delta*float(render_settings.lamp_response)))
	_update_interest()
	if not moving_enabled and terrain.ready_at(player.position):moving_enabled=true;message.text="착륙 완료 · 전방의 지하 신호를 조사하세요."
	var underground: float=clampf(-player.position.y/10.0,0,1)
	environment.ambient_light_energy=lerpf(.28,.035,underground)
	environment.fog_density=lerpf(.0007,.002,underground)
	hud.text="%s  /  T%d\n좌표 %.0f, %.0f  ·  깊이 %.1f m\n우주선까지 %.0f m" % [body.name,int(body.planet_tier),player.position.x,player.position.z,maxf(0,-player.position.y),player.position.distance_to(ship_position)]
	if not logistics.is_empty():hud.text+="\n휴대 암석 %d · 운반 중 %d · 창고 %d" % [int(logistics.hand_rock),int(logistics.robot.cargo),int(logistics.depot_rock)]
	if debug_visible:hud.text+="\n활성 청크 %d · 작업 %d · 최대 생성 %.1fms · 최근 설치 %.1fms" % [terrain.chunks.size(),terrain.jobs.size(),terrain.max_build_ms,terrain.last_install_ms]
	message.position.y=maxf(140,hud.position.y+hud.get_minimum_size().y+10)

func _physics_process(delta: float) -> void:
	if not moving_enabled:return
	lamp_timer-=delta
	if lamp_timer<=0:
		lamp_timer=float(render_settings.lamp_check_interval)
		var query:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*60)
		query.exclude=[player.get_rid()]
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		var distance: float=60.0 if hit.is_empty() else camera.global_position.distance_to(hit.position)
		var covered: bool=terrain.field.density(camera.global_position+Vector3.UP*8)>0
		lamp_target=clampf(float(render_settings.lamp_energy)*pow(distance/float(render_settings.lamp_exposure_distance),2),float(render_settings.lamp_minimum_energy),float(render_settings.lamp_energy)) if lamp_mode=="on" or (lamp_mode=="auto" and covered) else 0.0
	var direction:=Vector3.ZERO
	if not menu.visible and not journal.visible:
		var input: Vector2=movement_input if test_mode else Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
		direction=player.basis*Vector3(input.x,0,input.y)
		if player.is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE):player.velocity.y=float(config.jump_speed)
	var move_speed: float=float(config.sprint_speed) if Input.is_physical_key_pressed(KEY_SHIFT) else float(config.walk_speed)
	var next: Vector3=player.position+direction*move_speed*delta
	if not terrain.ready_at(next):player.velocity=Vector3.ZERO;return
	player.velocity.x=direction.x*move_speed;player.velocity.z=direction.z*move_speed
	if not player.is_on_floor():player.velocity.y-=float(config.gravity)*delta
	player.move_and_slide()
	if player.position.y<float(config.minimum_depth)+2 or maxf(absf(player.position.x),absf(player.position.z))>float(config.region_half_extent):rescue()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode==KEY_E:
		scan_held=event.pressed
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x*.0025);head.rotation.x=clampf(head.rotation.x-event.relative.y*.0025,-1.5,1.5)
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:dig()
		elif not menu.visible and not journal.visible:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			if journal.visible:toggle_journal()
			else:menu.visible=not menu.visible;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if menu.visible else Input.MOUSE_MODE_CAPTURED
		elif event.physical_keycode==KEY_J:toggle_journal()
		elif event.physical_keycode==KEY_L:
			lamp_mode={"auto":"on","on":"off","off":"auto"}[lamp_mode]
			message.text="손전등 · "+{"auto":"자동","on":"켜짐","off":"꺼짐"}[lamp_mode]
		elif event.physical_keycode==KEY_Q:ecology_action("collect")
		elif event.physical_keycode==KEY_R:courier.request_pickup()
		elif event.physical_keycode==KEY_F5:save_surface()
		elif event.physical_keycode==KEY_F3:debug_visible=not debug_visible

func dig() -> bool:
	if cooldown>0 or not terrain.batch.is_empty() or not moving_enabled:return false
	var start: Vector3=camera.global_position
	var query:=PhysicsRayQueryParameters3D.create(start,start-camera.global_basis.z*float(config.dig_range))
	query.exclude=[player.get_rid()]
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("terrain_chunk"):message.text="굴착할 지층에 가까이 접근하세요.";return false
	if hit.position.y<float(config.minimum_depth)+5:message.text="현재 장비의 굴착 깊이 한계입니다.";return false
	var edit: Dictionary=terrain.dig(hit.position,float(config.dig_radius))
	if edit.is_empty():return false
	if not state.terrain_edits.has(body_id):state.terrain_edits[body_id]=[]
	state.terrain_edits[body_id].append(edit)
	logistics.hand_rock+=int(FrontierSurfaceLogistics.config().rock_per_excavation)
	cooldown=float(config.dig_interval)
	message.text="굴착 중…"
	return true

func save_surface() -> bool:
	state.mode="surface"
	state.surface_positions[body_id]=[player.position.x,player.position.y,player.position.z]
	var saved: bool=store.write(state)
	message.text="지형·생태 기록과 탐사 위치를 저장했습니다." if saved else store.last_error
	return saved

func rescue() -> void:
	player.position=Vector3(0,4,0);player.velocity=Vector3.ZERO;moving_enabled=false
	message.text="착륙 지점으로 구조했습니다. 지형 변화는 유지됩니다."

func return_to_orbit() -> void:
	if player.position.distance_to(ship_position)>24:message.text="우주선 가까이 돌아와 출항하세요.";return
	state.mode="space"
	state.surface_positions[body_id]=[player.position.x,player.position.y,player.position.z]
	if not store.write(state):message.text=store.last_error;return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/app/exploration.tscn")

func _exit_tree() -> void:
	get_tree().auto_accept_quit=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _setup_ecology() -> void:
	if not state.has("ecology"):state.ecology=FrontierEcology.create()
	FrontierEcology.ensure_planet(state.ecology,body)
	ecology_view=FrontierSurfaceEcology.new()
	ecology_view.configure(state.ecology,body,terrain,player)
	add_child(ecology_view)
	plot_marker=MeshInstance3D.new()
	var ring:=TorusMesh.new();ring.inner_radius=float(FrontierEcologyCatalog.config().plot_radius)-.08;ring.outer_radius=float(FrontierEcologyCatalog.config().plot_radius)+.08;ring.rings=64;ring.ring_segments=6
	plot_marker.mesh=ring
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("80c7b2");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	plot_marker.material_override=mat;plot_marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plot_marker)
	_update_plot_marker()

func _update_plot_marker() -> void:
	var plot: Dictionary=state.ecology.planets[body_id].plot
	plot_marker.visible=not plot.is_empty()
	if plot_marker.visible:plot_marker.position=Vector3(plot.center[0],plot.center[1]-.75,plot.center[2])

func _process_ecology(delta: float) -> void:
	if not is_instance_valid(ecology_view):return
	current_encounter=ecology_view.target(camera) if not menu.visible and not journal.visible and moving_enabled else {}
	var id: String=current_encounter.get("id","")
	if id!=scan_id or not scan_held or id.is_empty():scan_progress=0;scan_id=id
	if not id.is_empty():
		var form:=FrontierEcologyCatalog.form(current_encounter.form_id)
		var known: bool=state.ecology.observations.has(body_id+":"+form.id)
		ecology_hud.text="%s\n%s · %s\n%s"%[form.name,form.environment_label,"휴면" if current_encounter.status=="dormant" else "활성","Q 표본 확보 · J 연구 기록" if known else "E 길게 누르기 · 생태 스캔"]
		if scan_held and not known:
			scan_progress+=minf(delta,.1)
			ecology_hud.text+=" · %d%%"%mini(100,int(scan_progress/float(FrontierEcologyCatalog.config().scan_seconds)*100))
			if scan_progress>=float(FrontierEcologyCatalog.config().scan_seconds):ecology_action("scan");scan_progress=0;scan_held=false
	else:
		var record: Dictionary=state.ecology.planets[body_id]
		ecology_hud.text="생태 탐사 · J\n활성 신호 %d · 휴면 군체 %d"%[ecology_view.active_count,ecology_view.dormant_count]
		if record.profile.origin=="sterile":ecology_hud.text+="\n고유 생명 신호 없음 · 외부 표본 도입 가능"
	ecology_tick+=delta
	if ecology_tick>=1.0:
		FrontierEcology.advance(state.ecology,body_id,1.0)
		ecology_tick=0

func toggle_journal() -> void:
	journal.visible=not journal.visible
	ecology_hud.visible=not journal.visible
	if journal.visible:menu.hide();journal.refresh()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if journal.visible else Input.MOUSE_MODE_CAPTURED
	scan_held=false

func ecology_action(action: String,selection: String="") -> bool:
	var encounter: Dictionary=ecology_view.target(camera)
	if action in ["scan","collect"]:
		if encounter.is_empty():message.text="생명체가 시야 안에 보이도록 가까이 접근하세요.";return false
		if action=="collect" and player.position.distance_to(encounter.point)>float(FrontierEcologyCatalog.config().sample_range):message.text="생체 표본 확보는 4m 이내에서 가능합니다.";return false
	elif player.position.distance_to(ship_position)>float(FrontierEcologyCatalog.config().lab_range):message.text="우주선 가까이에서 연구·격리 시험을 진행하세요.";return false
	var draft: Dictionary=state.duplicate(true)
	var result: String=""
	var layer: String="cave" if terrain.field.height(player.position.x,player.position.z)-player.position.y>6 else "surface"
	var supplies: Dictionary=draft.surface_logistics[body_id]
	match action:
		"scan":result=FrontierEcology.scan(draft.ecology,body_id,encounter)
		"collect":result=FrontierEcology.collect(draft.ecology,body_id,encounter)
		"analyze":result=FrontierEcology.analyze(draft.ecology,selection,supplies)
		"restore":result=FrontierEcology.restore_plot(draft.ecology,body_id,selection,player.position,layer,supplies)
		"resupply":result=FrontierEcology.resupply_plot(draft.ecology,body_id,supplies)
		"introduce":
			if not draft.ecology.specimens.has(selection):message.text="운송 표본을 선택하세요.";return false
			var sample: Dictionary=draft.ecology.specimens[selection]
			var candidate: Dictionary={"form_id":sample.form_id,"look_id":sample.look_id,"point":player.position-player.basis.z*3,"layer":layer,"yaw":0.0}
			var point:=FrontierEcologyPlacement.ground(terrain.field,candidate)
			if not point.is_finite():message.text="표본이 안정적으로 설 수 있는 평탄하고 넓은 장소가 필요합니다.";return false
			result=FrontierEcology.introduce(draft.ecology,body_id,selection,point,layer)
		_:return false
	if draft.ecology==state.ecology and supplies==logistics:message.text=result;return false
	draft.surface_positions[body_id]=[player.position.x,player.position.y,player.position.z]
	if not store.write(draft):message.text=store.last_error;return false
	state.ecology=draft.ecology
	logistics.depot_rock=supplies.depot_rock
	ecology_view.ecology=state.ecology;ecology_view.invalidate()
	_update_plot_marker()
	message.text=result
	return true

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if state.is_empty() or not is_instance_valid(player) or save_surface():get_tree().quit()

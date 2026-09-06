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

func _ready() -> void:
	test_mode="--exploration-test" in OS.get_cmdline_user_args()
	if test_mode:store=FrontierWorldStore.new("user://test_exploration_ui.json")
	state=store.read_state()
	if state.is_empty():state=FrontierUniverse.new_world(71491)
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
	lamp.position=Vector3(.15,-.1,0)
	lamp.light_color=Color("d5f0eb")
	lamp.light_energy=40.0
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
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=theme_value;layer.add_child(root)
	hud=Label.new();hud.position=Vector2(24,22);root.add_child(hud)
	message=Label.new();message.position=Vector2(24,104);message.text="착륙 지점을 확인하고 있습니다.";root.add_child(message)
	var cross:=Label.new();cross.text="+";cross.add_theme_font_size_override("font_size",26);cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER);cross.position=Vector2(-8,-18);root.add_child(cross)
	var footer:=Label.new();footer.text="WASD 이동 · Shift 달리기 · Space 점프 · 클릭 굴착 · R 로봇 호출 · F5 저장 · Esc 항해 메뉴 · F3 계측";footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);footer.position=Vector2(24,-38);footer.add_theme_font_size_override("font_size",13);root.add_child(footer)
	menu=PanelContainer.new();menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER);menu.position=Vector2(-180,-120);menu.custom_minimum_size=Vector2(360,220);root.add_child(menu)
	var column:=VBoxContainer.new();menu.add_child(column)
	for entry in [["현장 복귀",_resume],["탐사 기록 저장",save_surface],["우주선 출항",return_to_orbit],["착륙 지점으로 구조 요청",rescue]]:
		var button:=Button.new();button.text=entry[0];button.custom_minimum_size.y=45;button.pressed.connect(entry[1]);column.add_child(button)
	menu.hide()

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
	_update_interest()
	if not moving_enabled and terrain.ready_at(player.position):moving_enabled=true;message.text="착륙 완료 · 전방의 지하 신호를 조사하세요."
	var underground: float=clampf(-player.position.y/10.0,0,1)
	environment.ambient_light_energy=lerpf(.28,.035,underground)
	environment.fog_density=lerpf(.0007,.002,underground)
	hud.text="%s  /  T%d\n좌표 %.0f, %.0f  ·  깊이 %.1f m\n우주선까지 %.0f m" % [body.name,int(body.planet_tier),player.position.x,player.position.z,maxf(0,-player.position.y),player.position.distance_to(ship_position)]
	if not logistics.is_empty():hud.text+="\n휴대 암석 %d · 운반 중 %d · 창고 %d" % [int(logistics.hand_rock),int(logistics.robot.cargo),int(logistics.depot_rock)]
	if debug_visible:hud.text+="\n활성 청크 %d · 작업 %d · 최대 생성 %.1fms · 최근 설치 %.1fms" % [terrain.chunks.size(),terrain.jobs.size(),terrain.max_build_ms,terrain.last_install_ms]

func _physics_process(delta: float) -> void:
	if not moving_enabled:return
	var direction:=Vector3.ZERO
	if not menu.visible:
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
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x*.0025);head.rotation.x=clampf(head.rotation.x-event.relative.y*.0025,-1.5,1.5)
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:dig()
		elif not menu.visible:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:menu.visible=not menu.visible;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if menu.visible else Input.MOUSE_MODE_CAPTURED
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

func save_surface() -> void:
	state.mode="surface"
	state.surface_positions[body_id]=[player.position.x,player.position.y,player.position.z]
	message.text="지형 변화와 탐사 위치를 저장했습니다." if store.write(state) else store.last_error

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
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

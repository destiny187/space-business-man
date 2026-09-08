class_name FrontierCrewExpedition
extends Node3D
var arrival: Node
var onboarding: FrontierFirstDeparture
var waiting_screen: ColorRect
var waiting_panel: VBoxContainer
var waiting_roster: Label
var waiting_info: Label
var waiting_ready: Button
var waiting_start: Button
var navigation_journal: FrontierNavigationJournal
var navigation_records: FrontierNavigationRecords
var rovers: FrontierRoverController
var navigation_ui: Control
var chart: Control
var inventory_panel: FrontierEquipmentPanel
var field_hud: FrontierFieldHud
var feedback: FrontierExpeditionFeedback
var soundtrack: Node
var session: FrontierCrewSession
var profile:=FrontierPlayerProfile.new()
var world_store:=FrontierWorldStore.new("user://crew_world_v3.json")
var actors: Dictionary={}
var recovery_models: Dictionary={}
var visuals: Dictionary={}
var cache: Dictionary={}
var camera: Camera3D
var flight: FrontierCrewFlightView
var space_view: SubViewport
var exterior_view: TextureRect
var navigation_frame: PanelContainer
var research_frame: PanelContainer
var surface_tools: HBoxContainer
var navigation_toggle: Button
var help_text: Label
var surface_transition:=false
var destination_initialized:=false
var panel: VBoxContainer
var lobby: VBoxContainer
var roster: Label
var status: FrontierResourceReadout
var travel_status: Label
var selected_ordinal: int=2
var pilot_choices: OptionButton
var name_input: LineEdit
var host_address: LineEdit
var port_input: SpinBox
var yaw:=0.0
var pitch:=0.0
var mouse_steering:=Vector2.ZERO
var cursor_released:=false
var mouse_resume_guard:=false
var previous_accumulated_input:=true
var outside:=false
var movement_timer:=0.0
var ready_button: Button
var crew_ids: Array=[]
var ui: Control
var ui_theme: Theme
var test_mode:=false
var test_direction:=Vector2.ZERO
var test_camera_position:=Vector3.ZERO
var spaces:=FrontierCrewSpaces.new()
var cabin_root: Node3D
var surface_world: FrontierCrewSurfaceScene
var surface_panel: VBoxContainer
var surface_status: FrontierResourceReadout
var form_options: OptionButton
var sample_options: OptionButton
var surface_target: Dictionary={}
var survey_journal: FrontierSurveyJournal
var dig_timer:=0.0
var test_scan:=false
var test_sprint:=false
var test_jump:=false
var jump_held:=false
var jump_request:=0
var prediction_history: Array[Dictionary]=[]
var prediction_snapshot: Dictionary={}
var predicted_motion: Dictionary={}
var camera_correction:=Vector3.ZERO
var local_direction:=Vector2.ZERO
var local_sprint:=false
var reticle: Label
var stations: FrontierCrewStations
var station_market: FrontierStationMarketPanel
var shipyard_panel: FrontierShipyardPanel
var research_actions: Array[Control]=[]
var business_panel: FrontierBusinessPanel
var preferred_robot_id: String=""
var placement_kind: String=""
var placement_point:=Vector3.INF
var placement_valid:=false
var placement_reason: String=""
var placement_ghost: Node3D
var ghost_material: StandardMaterial3D
func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	previous_accumulated_input=Input.use_accumulated_input
	Input.use_accumulated_input=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	world_store=FrontierWorldStore.new(selected_world_path(false))
	test_mode="--crew-ui-test" in OS.get_cmdline_user_args()
	if test_mode:
		profile=FrontierPlayerProfile.new("user://test_crew_ui_profile.json")
		world_store=FrontierWorldStore.new("user://test_crew_ui_world.json")
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--crew-folder="):
				var folder:=argument.trim_prefix("--crew-folder=")
				profile=FrontierPlayerProfile.new(folder+"/profile.json");world_store=FrontierWorldStore.new(folder+"/world.json")
	session=FrontierCrewSession.new();session.name="Coop";add_child(session)
	session.snapshot_received.connect(_snapshot)
	session.surface_received.connect(_surface_packet)
	session.notice.connect(func(message: String):status.value=message)
	session.response_received.connect(func(_sequence: int,value: Dictionary):
		if value.get("code")=="mining_cooldown":return
		if not value.get("ok",false):status.value=value.get("error","작업 실패")
		else:status.value="원정 기록을 저장했습니다.")
	if get_tree().has_meta("startup_loader"):
		await get_tree().get_meta("startup_loader").checkpoint(40, "우주선 내부 준비")
	_build_cabin()
	if get_tree().has_meta("startup_loader"):
		await get_tree().get_meta("startup_loader").checkpoint(55, "탐험 장비와 화면 준비")
	_build_ui();cabin_root.hide();spaces.configure(self)
	feedback=FrontierExpeditionFeedback.new();add_child(feedback);feedback.configure(self)
	rovers=FrontierRoverController.new();add_child(rovers);rovers.configure(self)
	stations=FrontierCrewStations.new();add_child(stations);stations.configure(self)
	var rover_factory:=FrontierRoverWorkshop.new();business_panel.tabs.add_child(rover_factory);rover_factory.configure(self,true)
	arrival=load("res://scripts/app/planet_arrival.gd").new();add_child(arrival);arrival.configure(self)
	onboarding=FrontierFirstDeparture.new();navigation_frame.get_parent().add_child(onboarding);onboarding.theme=ui_theme;onboarding.configure(self)
	navigation_ui.get_parent().move_child(navigation_ui,-1)
	for frame in menu_frames()+[waiting_screen,onboarding.letter]:
		frame.visibility_changed.connect(_menu_changed)
	if get_tree().has_meta("startup_loader"):
		await get_tree().get_meta("startup_loader").checkpoint(72, "환경음과 원정 기록 준비")
	soundtrack=load("res://scripts/app/expedition_audio.gd").new();add_child(soundtrack);soundtrack.configure(self)
	_apply_client_settings.call_deferred()
	if FileAccess.file_exists(profile.path) and profile.ensure():
		name_input.text=profile.data.character.name;name_input.editable=false
	get_tree().auto_accept_quit=false
	if get_tree().get_meta("expedition_mode","") in ["solo","solo_new"]:
		var fresh: bool=get_tree().get_meta("expedition_mode")=="solo_new"
		get_tree().remove_meta("expedition_mode")
		if get_tree().has_meta("startup_loader"):
			await get_tree().get_meta("startup_loader").checkpoint(82, "은하와 시작 항성계 준비")
			start_solo(fresh)
		else:start_solo.call_deferred(fresh)
	set_process(true)
	set_physics_process(true)
	set_process_input(true)
	set_meta("startup_complete", true)
func _apply_client_settings() -> void:
	# Direct scene launches also need to wait until the root finishes setup.
	var settings:=FrontierClientSettings.ensure(get_tree())
	settings.apply_all()
	settings.overlay.visibility_changed.connect(_menu_changed)

func _build_cabin() -> void:
	cabin_root=Node3D.new();cabin_root.name="Cabin";add_child(cabin_root)
	var room: Node3D=load("res://assets/models/crew/kestrel_cabin.glb").instantiate()
	cabin_root.add_child(room);FrontierInkStyle.apply(room,cache)
	_collision(Vector3(0,-.25,0),Vector3(8,.5,16))
	for side in [-1,1]:
		_collision(Vector3(side*3.9,2,0),Vector3(.3,4,16))
		for z in [-4,-1,2]:_collision(Vector3(side*2.65,.9,z),Vector3(1.18,1.8,1.2))
		_collision(Vector3(side*2.7,.8,-6.6),Vector3(1.8,1.6,1.2))
	for z in [-7.9,7.9]:_collision(Vector3(0,2,z),Vector3(8,4,.3))
	_collision(Vector3(0,.6,5.6),Vector3(1.85,1.3,1.0))
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("152b39")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("89aaa8");env.ambient_light_energy=.4
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=env;cabin_root.add_child(environment)
	for z in [-5,1,6]:
		var lamp:=OmniLight3D.new();lamp.position=Vector3(0,3.4,z);lamp.light_color=Color("e3edcd");lamp.light_energy=1.25;lamp.omni_range=7;lamp.shadow_enabled=true;cabin_root.add_child(lamp)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-28,-30,0);sun.light_energy=.25;sun.light_color=Color("c8e5ed");cabin_root.add_child(sun)
	camera=Camera3D.new();camera.position=Vector3(0,1.72,6.7);camera.fov=76;camera.current=true;add_child(camera)
	FrontierInkStyle.attach(camera)
	get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
func _collision(position_value: Vector3,size: Vector3) -> void:
	var body:=StaticBody3D.new();body.position=position_value;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);cabin_root.add_child(body)
func _build_ui() -> void:
	var layer:=CanvasLayer.new();add_child(layer)
	ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	ui_theme=FrontierInterfaceStyle.theme();ui.theme=ui_theme
	reticle=Label.new();reticle.text="＋";reticle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;reticle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(reticle);reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER);reticle.offset_left=-14;reticle.offset_right=14;reticle.offset_top=-14;reticle.offset_bottom=14;reticle.hide()
	exterior_view=TextureRect.new();exterior_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);exterior_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;exterior_view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;exterior_view.mouse_filter=Control.MOUSE_FILTER_IGNORE;exterior_view.hide();ui.add_child(exterior_view)
	waiting_screen=ColorRect.new();waiting_screen.color=Color("08141f");ui.add_child(waiting_screen);waiting_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new();waiting_screen.add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);center.offset_right=-355
	waiting_panel=VBoxContainer.new();waiting_panel.custom_minimum_size=Vector2(380,0);waiting_panel.add_theme_constant_override("separation",18);center.add_child(waiting_panel)
	_label(waiting_panel,"L O C U S",38)
	_label(waiting_panel,"하나의 은하, 지구에서 시작하는 탐험",19)
	waiting_info=_label(waiting_panel,"100만 행성 · 항성계와 공전 궤도\n암석 행성의 개척 · 가스 행성의 궤도 탐색",15)
	waiting_roster=_label(waiting_panel,"오른쪽에서 혼자 시작하거나 방을 만들고 참가하세요.",17)
	waiting_ready=_button(waiting_panel,"준비 완료",func():session.send_request("lobby_ready",{"value":not session.latest.get("lobby_ready",{}).get(session.latest.self_id,false)}));waiting_ready.hide()
	waiting_start=_button(waiting_panel,"호스트 · 게임 시작",func():session.send_request("start_game",{}));waiting_start.hide()
	_button(waiting_panel,"내 캐릭터 · 소유 장비",show_equipment)
	var header:=VBoxContainer.new();header.position=Vector2(24,22);ui.add_child(header)
	_label(header,"L O C U S  /  우주 탐험",23)
	status=_resource_label(header,"세계를 열고 준비한 뒤 지구에서 탐험을 시작하세요.",15)
	help_text=_label(header,"WASD 이동 · Space 점프 · 마우스 시선 · C 외부 시점 · Tab 항해",13)
	for child in header.get_children():child.custom_minimum_size.x=minf(740,get_viewport().get_visible_rect().size.x-390)
	get_viewport().size_changed.connect(func():
		for child in header.get_children():child.custom_minimum_size.x=minf(740,get_viewport().get_visible_rect().size.x-390))
	navigation_frame=PanelContainer.new();var frame:=navigation_frame;ui.add_child(frame);frame.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);frame.offset_left=-338;frame.offset_right=-22;frame.offset_top=22;frame.offset_bottom=-22
	var style:=StyleBoxFlat.new();style.bg_color=FrontierInterfaceStyle.INK;style.border_color=FrontierInterfaceStyle.LINE;style.set_border_width_all(1);style.set_content_margin_all(18);style.set_corner_radius_all(3);frame.add_theme_stylebox_override("panel",style)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;frame.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",8);scroll.add_child(column)
	lobby=VBoxContainer.new();lobby.add_theme_constant_override("separation",9);column.add_child(lobby)
	_label(lobby,"함께하는 탐험",22)
	_button(lobby,"혼자 게임 시작 · 연결 설정 없음",start_solo).name="SoloStart"
	name_input=LineEdit.new();name_input.placeholder_text="탐험가 이름";name_input.text="탐험가";name_input.max_length=24;lobby.add_child(name_input)
	host_address=LineEdit.new();host_address.text="127.0.0.1";host_address.placeholder_text="호스트 주소";lobby.add_child(host_address)
	port_input=SpinBox.new();port_input.min_value=1024;port_input.max_value=65535;port_input.value=24560;lobby.add_child(port_input)
	_button(lobby,"세계 열기 · 최대 6명",host_world)
	_button(lobby,"새 은하로 방 만들기",func():world_store=FrontierWorldStore.new("user://crew_"+FrontierPlayerProfile.token()+".json");host_world())
	_button(lobby,"주소로 참가",join_world)
	if FileAccess.file_exists("user://crew_world.json"):
		_button(lobby,"이전 공동 세계 이어하기",func():world_store=FrontierWorldStore.new("user://crew_world.json");host_world())
	if FileAccess.file_exists("user://solo_world.json"):
		_button(lobby,"이전 혼자 세계 이어하기",func():
			if not profile.ensure(name_input.text):status.value=profile.error;return
			if session.host(profile,FrontierWorldStore.new("user://solo_world.json"),24560,"*",true):session.send_request("start_game",{}))
	_label(lobby,"현재 접속: 직접 UDP\n인터넷 원정에는 호스트 포트 접근이 필요합니다.",13)
	panel=VBoxContainer.new();panel.add_theme_constant_override("separation",12);panel.hide();column.add_child(panel)
	research_frame=load("res://scripts/ui/research_panel.gd").new();ui.add_child(research_frame);research_frame.configure(self)
	var research_scroll:=ScrollContainer.new();research_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;research_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;research_frame.ecology.add_child(research_scroll)
	survey_journal=FrontierSurveyJournal.new();survey_journal.configure(self);research_scroll.add_child(survey_journal)
	var action_scroll:=ScrollContainer.new();action_scroll.custom_minimum_size.x=300;action_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;action_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;research_frame.ecology.add_child(action_scroll)
	surface_panel=VBoxContainer.new();surface_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;action_scroll.add_child(surface_panel)
	_label(surface_panel,"관측 → 분석 → 시험 → 이식",20)
	_label(surface_panel,"E로 생물을 조사한 뒤 대상을 선택하세요.",14)
	surface_status=_resource_label(header,"지표를 준비 중입니다.",14);surface_status.hide()
	form_options=OptionButton.new();form_options.fit_to_longest_item=false;surface_panel.add_child(form_options)
	research_actions.append(_button(surface_panel,"기초 분석 · 광물 3",func():surface_action("surface_analyze")))
	research_actions.append(_button(surface_panel,"서식지 시험 · 광물 6",func():surface_action("surface_restore")))
	sample_options=OptionButton.new();sample_options.fit_to_longest_item=false;surface_panel.add_child(sample_options)
	research_actions.append(_button(surface_panel,"운송 표본 이식",func():surface_action("surface_introduce")))
	research_actions.append(_button(surface_panel,"지원 팩 보충 · 광물 3",func():surface_action("surface_resupply")))
	var dock:=HBoxContainer.new();ui.add_child(dock);dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);dock.position=Vector2(24,get_viewport().get_visible_rect().size.y-62);dock.add_theme_constant_override("separation",8)
	get_viewport().size_changed.connect(func():dock.position=Vector2(24,get_viewport().get_visible_rect().size.y-62))
	navigation_toggle=_button(dock,"지도 [Tab]",toggle_navigation);navigation_toggle.hide()
	_button(dock,"설정 [F10]",func():FrontierClientSettings.ensure(get_tree()).open()).name="Settings"
	surface_tools=HBoxContainer.new();dock.add_child(surface_tools);surface_tools.hide()
	_button(surface_tools,"건설 [B]",toggle_business)
	_button(surface_tools,"연구 [J]",toggle_research)
	_button(surface_tools,"아이템 [I]",toggle_inventory)
	business_panel=FrontierBusinessPanel.new();ui.add_child(business_panel)
	business_panel.command.connect(func(kind: String,args: Dictionary):session.send_request(kind,args))
	business_panel.place_building.connect(begin_placement)
	business_panel.prefer_robot.connect(func(id: String):preferred_robot_id=id;close_menus();feedback.show_cue("현장 지시 · "+("고등급 자동 선정" if id.is_empty() else id+" 우선")))
	business_panel.station_action.connect(station_action)
	station_market=FrontierStationMarketPanel.new();ui.add_child(station_market)
	station_market.command.connect(func(kind: String,args: Dictionary):
		if not session.send_request(kind,args):station_market.pending=false;station_market.message.text="현재 교역 요청을 보낼 수 없습니다.";station_market.refresh_detail())
	session.request_started.connect(func(sequence: int,kind: String,_args: Dictionary):
		if kind.begins_with("station_") and station_market.pending:station_market.pending_sequence=sequence)
	session.response_received.connect(station_market.response)
	shipyard_panel=FrontierShipyardPanel.new();ui.add_child(shipyard_panel)
	shipyard_panel.command.connect(func(kind: String,args: Dictionary):session.send_request(kind,args))
	inventory_panel=FrontierEquipmentPanel.new();ui.add_child(inventory_panel);inventory_panel.configure(self,ui)
	field_hud=FrontierFieldHud.new();ui.add_child(field_hud);field_hud.configure(self)
	navigation_ui=load("res://scripts/ui/expedition_navigation.gd").new();ui.add_child(navigation_ui);navigation_ui.configure(self)
	_button(lobby,"시작 화면",return_title)
func _label(parent: Node,value: String,size: int=15) -> Label:
	var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",size);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=265;parent.add_child(label);return label
func _resource_label(parent: Node,value: String,size: int=15) -> FrontierResourceReadout:
	var label:=FrontierResourceReadout.new();label.custom_minimum_size.x=265;label.value=value;label.add_theme_font_size_override("normal_font_size",size);parent.add_child(label);return label
func _button(parent: Node,value: String,callback: Callable) -> Button:
	var button:=Button.new();button.text=value;button.custom_minimum_size.y=35;button.pressed.connect(callback);parent.add_child(button);FrontierResourceIcons.button_caption(button);return button
func host_world() -> void:
	if not profile.ensure(name_input.text):status.value=profile.error;return
	if session.host(profile,world_store,int(port_input.value)):remember_world(false);lobby.hide();panel.hide()
func join_world() -> void:
	if not profile.ensure(name_input.text):status.value=profile.error;return
	if session.join(profile,host_address.text.strip_edges(),int(port_input.value)):lobby.hide();panel.hide();waiting_roster.text="호스트에 연결 중입니다."
func _setup_flight() -> void:
	space_view=SubViewport.new();space_view.size=Vector2i(get_viewport().get_visible_rect().size);space_view.own_world_3d=true;space_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(space_view)
	get_viewport().size_changed.connect(func():
		if is_instance_valid(space_view):space_view.size=Vector2i(get_viewport().get_visible_rect().size))
	flight=FrontierCrewFlightView.new();flight.state={"manifest":session.manifest};space_view.add_child(flight)
	navigation_journal=FrontierNavigationJournal.new();navigation_journal.configure(session.manifest,session.world_id,session.latest.self_id)
	flight.soundscape.bind_session(session)
	navigation_records.journal=navigation_journal;chart.journal=navigation_journal
	flight.scanned=navigation_journal.scan_flags()
	flight.planet_scanned.connect(func(ordinal: int):navigation_journal.scanned(ordinal);_refresh_scan_detail();chart.queue_redraw())
	exterior_view.texture=space_view.get_texture()
	var window:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(7.3,2.35);window.mesh=quad;window.position=Vector3(0,2.16,-7.72)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_texture=space_view.get_texture();material.uv1_scale=Vector3(1,.515,1);material.uv1_offset=Vector3(0,.2425,0);window.material_override=material;window.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;cabin_root.add_child(window)
func _spawn_actor(id: String,member: Dictionary) -> void:
	var actor:=CharacterBody3D.new();actor.name="Crew_"+id;actor.collision_layer=2;actor.collision_mask=1;actor.floor_snap_length=.7;actor.position=FrontierCrewWorld.vector(member.position)
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.29;capsule.height=1.86;collision.shape=capsule;collision.position.y=.93;actor.add_child(collision);add_child(actor)
	var visual: Node3D=load("res://assets/models/crew/surveyor_suit.glb").instantiate();actor.add_child(visual);FrontierInkStyle.apply(visual,cache);_suit_color(visual,int(member.profile.tint))
	var label:=Label3D.new();label.render_priority=110;label.outline_render_priority=109;label.outline_size=4;label.text=member.profile.name;label.font=ui_theme.default_font;label.font_size=52;label.pixel_size=.0035;label.position.y=2.2;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;actor.add_child(label)
	var pose:=FrontierCrewPose.new();actor.add_child(pose);pose.configure(visual)
	pose.landed.connect(func(point: Vector3,strength: float):
		if surface_world!=null and not feedback.blocked():feedback.effects.burst(point+Vector3.UP*.06,Color("a99f88"),int(3+strength*5)))
	actors[id]=actor;visuals[id]={"model":visual,"label":label,"last":actor.position,"pose":pose,"replica":FrontierCrewMotionReplica.new(),"area":member.area,"motion":FrontierCrewLocomotion.create()}
	if session.hosting:session.authority.motions[id]=FrontierCrewLocomotion.create()
var first_snapshot_pending: Dictionary = {}
var preparing_first_snapshot := false

func _snapshot(value: Dictionary) -> void:
	if preparing_first_snapshot:
		first_snapshot_pending = value
		return
	# A network game starts after the lobby; cover its first world build as well.
	if value.get("phase") == "playing" and flight == null and not get_tree().has_meta("startup_loader") and DisplayServer.get_name() != "headless":
		preparing_first_snapshot = true
		first_snapshot_pending = value
		_prepare_first_world.call_deferred()
		return
	_apply_snapshot(value)

func _prepare_first_world() -> void:
	var loading: Node = load("res://scripts/app/loading.gd").new()
	loading.overlay_only = true
	add_child(loading)
	await loading.checkpoint(40, "시작 항성계 준비")
	_apply_snapshot(first_snapshot_pending)
	await loading.checkpoint(92, "첫 화면 렌더 준비")
	for frame in 6:await RenderingServer.frame_post_draw
	# Apply the newest authoritative state received during presentation warmup.
	_apply_snapshot(first_snapshot_pending)
	await loading.checkpoint(100, "준비 완료")
	get_tree().remove_meta("startup_loader")
	loading.queue_free()
	preparing_first_snapshot = false
	first_snapshot_pending = {}

func _apply_snapshot(value: Dictionary) -> void:
	if not value.get("active",false):return
	if value.get("phase","lobby")=="lobby":
		waiting_screen.show();cabin_root.hide();exterior_view.hide();lobby.hide();panel.hide();help_text.hide();navigation_toggle.hide()
		var lines: PackedStringArray=[]
		var all_ready:=true
		for id in value.crew.members:
			var is_host: bool=id==value.crew.owner_id
			var prepared: bool=value.lobby_ready.get(id,false)
			lines.append(("호스트  " if is_host else ("✓ 준비  " if prepared else "○ 대기  "))+value.crew.members[id].profile.name)
			if not is_host and not prepared:all_ready=false
		waiting_roster.text="대기실 · %d / 6\n\n"%value.crew.members.size()+"\n".join(lines)
		waiting_info.text="은하 시드 %d · 행성 1,000,000개\n시작/재개 위치: %s\n준비 후 호스트가 게임을 시작합니다."%[int(session.manifest.seed),FrontierUniverse.body_from_id(session.manifest,value.location).name]
		waiting_ready.visible=not session.hosting;waiting_start.visible=session.hosting;waiting_start.disabled=not all_ready
		waiting_ready.text="준비 취소" if value.lobby_ready.get(value.self_id,false) else "준비 완료"
		return
	waiting_screen.hide();cabin_root.show();help_text.show()
	if flight==null:_setup_flight()
	onboarding.update_snapshot(value)
	flight.update_navigation(value.crew.navigation)
	navigation_journal.observe(value)
	flight.refits.flight_mode=true
	flight.refits.update_loadout({"hull":"finch"} if not value.get("local_shuttle","").is_empty() else value.get("vessel",{}))
	business_panel.shuttle_panel.update_snapshot(value)
	business_panel.vessel_terminal.update_snapshot(value)
	station_market.update_snapshot(value)
	shipyard_panel.update_snapshot(value,session.surface.get("business",{}))
	_sync_recovery(value.crew.recovery)
	var members: Dictionary=value.crew.members
	for id in actors.keys():
		if not members.has(id) or not members[id].get("connected",true):actors[id].queue_free();actors.erase(id);visuals.erase(id)
	var lines: PackedStringArray=["승무원 %d / 6" % members.size()]
	for id in members:
		if not members[id].get("connected",true):continue
		if not actors.has(id):_spawn_actor(id,members[id])
		elif visuals[id].area!=members[id].area or visuals[id].get("place_key","")!=members[id].get("place_key",""):
			actors[id].position=FrontierCrewWorld.vector(members[id].position);actors[id].velocity=Vector3.ZERO;visuals[id].area=members[id].area;visuals[id].last=actors[id].position;visuals[id]["place_key"]=members[id].get("place_key","")
			visuals[id].pose.reset();visuals[id].replica.frames.clear()
			if id==value.self_id:prediction_history.clear();predicted_motion.clear();camera_correction=Vector3.ZERO
			if session.hosting:session.authority.motions[id]=FrontierCrewLocomotion.create()
		if not session.hosting:
			visuals[id].replica.push(FrontierCrewWorld.vector(members[id].position),value.get("motion",{}).get(id,FrontierCrewLocomotion.create()))
			if id==value.self_id and value.get("motion",{}).has(id):prediction_snapshot={"position":FrontierCrewWorld.vector(members[id].position),"motion":value.motion[id].duplicate(true)}
		lines.append("%s %s%s" % ["✓" if members[id].ready else "○",members[id].profile.name," · 조종" if id==value.crew.pilot_id else ""])
	var own: Dictionary=members[value.self_id]
	lines.append("창고 %d · 운반 %d" % [int(value.crew.rock),int(own.carried)])
	var nav: Dictionary=value.crew.navigation
	var on_surface: bool=not value.crew.get("landing",{}).is_empty()
	if on_surface!=surface_transition:
		if on_surface and destination_initialized:arrival.begin()
		elif not on_surface and destination_initialized:
			if surface_world!=null and not value.get("local_shuttle","").is_empty():
				surface_world.refits.update_loadout({"hull":"finch"})
				if surface_world.shuttle_models.has(value.self_id):surface_world.landing_ship.position=surface_world.shuttle_models[value.self_id].position
			arrival.begin_launch()
		surface_transition=on_surface;close_menus()
	if on_surface and own.aboard and not arrival.active:arrival.begin_boarding()
	surface_tools.visible=on_surface;surface_status.visible=on_surface;navigation_toggle.show()
	if not destination_initialized:
		destination_initialized=true;selected_ordinal=int(nav.target)
		if not on_surface:navigation_frame.hide();outside=true;exterior_view.show();if_flight_view()
	lobby.hide();panel.show()
	navigation_ui.refresh(value)
	_sync_surface_view()
func _physics_process(delta: float) -> void:
	if preparing_first_snapshot:return
	if not session.active or session.latest.is_empty() or session.latest.get("phase")!="playing":return
	spaces.sync()
	if business_panel.visible and actors.has(session.latest.self_id) and not business_panel.context_in_range(actors[session.latest.self_id].position):close_menus()
	rovers.physics(delta)
	dig_timer=maxf(0,dig_timer-delta)
	if rovers.seat().is_empty() and surface_world!=null and not test_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and dig_timer<=0 and not mouse_resume_guard and not feedback.blocked() and placement_kind.is_empty() and get_viewport().gui_get_hovered_control()==null:
		var tool:=FrontierEquipment.active(session.latest.crew.members[session.latest.self_id])
		if tool.get("kind")=="miner":use_equipped()
	var controls_enabled:=_locomotion_enabled()
	var jump_pressed:=test_jump if test_mode else FrontierInput.pressed("jump")
	if jump_pressed and not jump_held and controls_enabled:jump_request+=1;movement_timer=0
	jump_held=jump_pressed
	movement_timer-=delta
	if movement_timer<=0 or (not session.hosting and not outside):
		movement_timer=.05
		var direction:=test_direction if test_mode else Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if (onboarding!=null and onboarding.letter.visible) or inventory_panel.visible or outside or navigation_frame.visible or business_panel.visible or shipyard_panel.visible or research_frame.visible or get_viewport().gui_get_focus_owner() is LineEdit:direction=Vector2.ZERO
		direction=direction.rotated(-yaw).limit_length()
		if not session.latest.crew.get("landing",{}).is_empty() and (surface_world==null or not surface_world.ready_at(actors[session.latest.self_id].position)):direction=Vector2.ZERO
		var scanning: bool=(test_scan if test_mode else Input.is_physical_key_pressed(KEY_E)) and surface_world!=null and not inventory_panel.visible and not business_panel.visible and not shipyard_panel.visible and not research_frame.visible and not navigation_frame.visible and not get_viewport().gui_get_focus_owner() is LineEdit
		if feedback.blocked() or (onboarding!=null and onboarding.letter.visible):direction=Vector2.ZERO;scanning=false
		var flight_controls: Array=[0.0,0.0,0.0]
		if outside and surface_world==null and not test_mode and not cursor_released and _mouse_look_allowed() and not navigation_frame.visible and not inventory_panel.visible and not business_panel.visible and not research_frame.visible and not shipyard_panel.visible and not FrontierClientSettings.ensure(get_tree()).is_open() and get_viewport().gui_get_focus_owner()==null:
			flight_controls=[float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S)),clampf(mouse_steering.x/.05,-1,1),clampf(mouse_steering.y/.05,-1,1),float(Input.is_physical_key_pressed(KEY_SHIFT))]
		mouse_steering=Vector2.ZERO
		local_direction=direction if controls_enabled else Vector2.ZERO
		local_sprint=(test_sprint if test_mode else Input.is_physical_key_pressed(KEY_SHIFT)) and direction.length_squared()>0 and not scanning
		session.send_input(direction,-camera.global_basis.z,scanning,(test_sprint if test_mode else Input.is_physical_key_pressed(KEY_SHIFT)) and direction.length_squared()>0 and not scanning,flight_controls,jump_request,controls_enabled,rovers.controls(controls_enabled))
	if not session.hosting:_predict_local(delta,controls_enabled)
	if session.hosting and not session.authority.stopped:
		for peer in session.authority.peers:
			var id: String=session.authority.peers[peer]
			if not actors.has(id):continue
			if not rovers.seat(id).is_empty():continue
			var actor: CharacterBody3D=actors[id];var direction:=session.authority.direction_for(peer)
			var input: Dictionary=session.authority.inputs.get(peer,{})
			var enabled: bool=float(input.get("expires",-1))>=session.authority.now and input.get("controls_enabled",true) and (not arrival.active or arrival.phase=="boarding" or FrontierShuttles.area_key(session.authority.world,id)!=FrontierShuttles.area_key(session.authority.world,session.latest.self_id))
			var member: Dictionary=session.authority.world.crew.members[id]
			var local:=FrontierShuttles.context(session.authority.world,id)
			if (member.has("shuttle_id") and member.area=="cabin") or (FrontierCrewSurface.landed(local) and member.aboard) or (arrival.active and arrival.phase in ["ascent","escape_loading","escape","exit_handover"] and FrontierShuttles.area_key(session.authority.world,id)==FrontierShuttles.area_key(session.authority.world,session.latest.self_id)):
				actor.velocity=Vector3.ZERO;continue
			var motion: Dictionary=session.authority.motions.get(id,FrontierCrewLocomotion.create())
			session.authority.motions[id]=motion
			var wants_sprint: bool=enabled and input.get("sprinting",false) and direction.length_squared()>0
			var multiplier:=FrontierCrewVitals.step(member,delta,wants_sprint,actor.is_on_floor() and Vector2(actor.velocity.x,actor.velocity.z).length()>.1)
			var speed:=float(FrontierCrewWorld.config().movement_speed)
			var gravity:=float(FrontierCrewLocomotion.config().cabin_gravity)
			if FrontierCrewSurface.landed(local):
				var ground:=spaces.terrain_for(id)
				if ground==null or not ground.ready_at(actor.position):
					actor.velocity=Vector3.ZERO;motion.buffer=0.0;motion.takeoff=0.0;motion.jump_request=int(input.get("jump_request",0));continue
				speed=float(FrontierCrewSurface.config().movement_speed)*multiplier*FrontierCrewAugmentation.multiplier(member,"mobility");gravity=float(FrontierCrewSurface.config().gravity)
				var next:=actor.position+Vector3(direction.x,0,direction.y)*speed*delta
				if not ground.ready_at(next):direction=Vector2.ZERO;enabled=false
				if actor.position.y<float(ground.config.minimum_depth)+2 or maxf(absf(actor.position.x),absf(actor.position.z))>float(ground.config.region_half_extent):
					actor.position=Vector3(0,4,0);actor.velocity=Vector3.ZERO;motion=FrontierCrewLocomotion.create();session.authority.motions[id]=motion
			var old_land: int=motion.land_serial
			FrontierCrewLocomotion.step(actor,motion,direction,speed,gravity,int(input.get("jump_request",0)),delta,enabled)
			motion.input_ack=int(session.authority.input_sequences.get(peer,0))
			if member.area=="surface" and int(motion.land_serial)>old_land and FrontierCrewVitals.land(member,float(motion.impact)):
				actor.position=FrontierCrewWorld.vector(FrontierCrewSurface.config().landing_spawn_positions[0]);actor.velocity=Vector3.ZERO
			session.authority.update_position(peer,actor.position)
func _predict_local(delta: float,enabled: bool) -> void:
	if not rovers.seat().is_empty():prediction_history.clear();predicted_motion.clear();return
	if outside or (arrival.active and arrival.phase in ["boarding","ascent","escape_loading","escape","exit_handover"]):prediction_history.clear();predicted_motion.clear();return
	var id: String=session.latest.self_id
	if not actors.has(id):return
	var body: CharacterBody3D=actors[id]
	if not session.latest.crew.get("landing",{}).is_empty() and (surface_world==null or not surface_world.ready_at(body.position)):
		prediction_history.clear();predicted_motion.clear();return
	if not prediction_snapshot.is_empty():
		var previous:=body.position
		var confirmed: Dictionary=prediction_snapshot.motion
		var ack:=int(confirmed.input_ack)
		prediction_history=prediction_history.filter(func(frame: Dictionary):return int(frame.sequence)>ack)
		body.position=prediction_snapshot.position;body.velocity=FrontierCrewWorld.vector(confirmed.velocity)
		predicted_motion=confirmed.duplicate(true)
		for frame in prediction_history:
			FrontierCrewLocomotion.step(body,predicted_motion,frame.direction,frame.speed,frame.gravity,frame.jump,frame.delta,frame.enabled)
		var correction:=previous-body.position
		camera_correction=(camera_correction+correction).limit_length(.3) if correction.length()<1.0 else Vector3.ZERO
		prediction_snapshot.clear()
	if predicted_motion.is_empty():return
	var member: Dictionary=session.latest.crew.members[id]
	var on_surface: bool=member.area=="surface"
	var speed:=float(FrontierCrewSurface.config().movement_speed) if on_surface else float(FrontierCrewWorld.config().movement_speed)
	if on_surface and local_sprint and predicted_motion.grounded and float(member.get("vitals",{}).get("stamina",0))>0 and not member.get("vitals",{}).get("exhausted",false):speed*=float(FrontierCrewVitals.config().sprint_multiplier)
	if on_surface:speed*=FrontierCrewAugmentation.multiplier(member,"mobility")
	var gravity:=float(FrontierCrewSurface.config().gravity) if on_surface else float(FrontierCrewLocomotion.config().cabin_gravity)
	var frame: Dictionary={"sequence":session.movement_sequence,"direction":local_direction,"speed":speed,"gravity":gravity,"jump":jump_request,"delta":delta,"enabled":enabled}
	FrontierCrewLocomotion.step(body,predicted_motion,local_direction,speed,gravity,jump_request,delta,enabled)
	prediction_history.append(frame)
	# Bounded replay: stale links cannot build an unbounded local simulation backlog.
	if prediction_history.size()>90:prediction_history.pop_front()

func _locomotion_enabled() -> bool:
	if any_menu_open() or feedback.blocked() or outside or (onboarding!=null and onboarding.letter.visible) or get_viewport().gui_get_focus_owner() is LineEdit:return false
	if not test_mode and not get_window().has_focus():return false
	if not session.latest.crew.get("landing",{}).is_empty():
		return surface_world!=null and actors.has(session.latest.self_id) and surface_world.ready_at(actors[session.latest.self_id].position)
	return true

func _process(delta: float) -> void:
	if preparing_first_snapshot:return
	_sync_mouse_capture()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):mouse_resume_guard=false
	if arrival!=null and arrival.active and not session.active:arrival.cancel()
	if session!=null and session.latest.get("phase")=="playing":
		status.get_parent().visible=false
		navigation_toggle.get_parent().visible=false
		if flight!=null:
			flight.scan_enabled=outside and _mouse_look_allowed() and not cursor_released
			flight.presentation_blocked=feedback.blocked() or (onboarding!=null and onboarding.letter.visible) or surface_world!=null or not get_window().has_focus()
	if session==null or session.latest.is_empty() or not session.active or session.latest.get("phase")!="playing":return
	var members: Dictionary=session.latest.crew.members
	for id in actors:
		var actor: CharacterBody3D=actors[id];var visual: Dictionary=visuals[id]
		var motion: Dictionary=session.authority.motions.get(id,{}) if session.hosting else {}
		if not session.hosting:
			var frame: Dictionary=visual.replica.sample()
			if id==session.latest.self_id and not predicted_motion.is_empty():motion=predicted_motion
			elif not frame.is_empty():actor.position=frame.position;motion=frame.motion
		visual.motion=motion
		var own: bool=id==session.latest.self_id
		# Success sounds/events always follow the host, including the predicted owner.
		var presentation: Dictionary=motion.duplicate(true)
		if own and not session.hosting:
			var approved: Dictionary=session.latest.get("motion",{}).get(id,{})
			for key in ["jump_serial","land_serial","impact"]:presentation[key]=approved.get(key,0)
		visual.pose.animate(presentation,delta,not feedback.blocked() and not outside and members[id].get("place_key","")==members[session.latest.self_id].get("place_key","") and (test_mode or get_window().has_focus()),not arrival.active)
		var here: bool=members[id].get("place_key","")==members[session.latest.self_id].get("place_key","") and members[id].get("connected",true)
		visual.model.visible=not own and not arrival.active and here;visual.label.visible=not own and not arrival.active and here
		if not session.hosting:actor.collision_layer=2 if here else 0;actor.collision_mask=1 if here else 0
	camera_correction=camera_correction.lerp(Vector3.ZERO,1-exp(-delta*18))
	if actors.has(session.latest.self_id):camera.position=actors[session.latest.self_id].position+Vector3(0,1.72,0)+camera_correction
	if test_mode and test_camera_position!=Vector3.ZERO:camera.position=test_camera_position
	camera.rotation=Vector3(pitch,yaw,0)
	_update_surface_hud()
	_update_business_placement()
	arrival.tick(delta)
	rovers.present(delta)
func _input(event: InputEvent) -> void:
	if get_tree().has_meta("startup_loader"):return
	if arrival!=null and arrival.active:return
	if FrontierClientSettings.ensure(get_tree()).is_open() or FrontierCursorPolicy.modal_open(get_tree()):return
	if event is InputEventKey and event.pressed and not event.echo and session.active and session.latest.get("phase")=="playing":
		if event.physical_keycode==KEY_ESCAPE:
			if not placement_kind.is_empty():cancel_placement();_menu_changed()
			elif any_menu_open():close_menus()
			else:open_menu(navigation_ui.pause_frame)
			get_viewport().set_input_as_handled();return
		if onboarding!=null and onboarding.letter.visible:return
		if not get_viewport().gui_get_focus_owner() is LineEdit:
			match event.physical_keycode:
				KEY_TAB:toggle_navigation()
				KEY_I:toggle_inventory()
				KEY_B:toggle_business()
				KEY_J:toggle_research()
				KEY_K:toggle_shipyard()
				KEY_P:open_menu(navigation_ui.crew_frame)
				_:return _look_input(event)
			get_viewport().set_input_as_handled();return
	_look_input(event)
func _look_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and _mouse_look_allowed():
		var preferences:=FrontierClientSettings.ensure(get_tree())
		_mouse_look(event.screen_relative,preferences.mouse_sensitivity(),bool(preferences.values.invert_y))
		get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if arrival!=null and arrival.active:return
	if event is InputEventMouseButton and mouse_resume_guard:return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and outside and surface_world==null and _mouse_look_allowed() and not cursor_released and not navigation_frame.visible and not FrontierClientSettings.ensure(get_tree()).is_open() and session.latest.get("self_id","")==session.latest.get("crew",{}).get("pilot_id",""):
		var scale_factor: float=maxf(exterior_view.size.x/space_view.size.x,exterior_view.size.y/space_view.size.y)
		var pointer: Vector2=exterior_view.global_position+exterior_view.size*.5 if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else event.position
		var point: Vector2=(pointer-exterior_view.global_position+(Vector2(space_view.size)*scale_factor-exterior_view.size)*.5)/scale_factor
		var ordinal: int=flight.pick_planet(point)
		if ordinal>=0 and flight.scanned.has(FrontierUniverse.body_id(session.manifest,ordinal)):
			selected_ordinal=ordinal;select_destination();get_viewport().set_input_as_handled();return
	var preferences:=FrontierClientSettings.ensure(get_tree())
	if preferences.is_open() or FrontierCursorPolicy.modal_open(get_tree()) or any_menu_open() or not session.active or session.latest.get("phase")!="playing":return

	if event is InputEventKey and event.pressed and not event.echo:
		if get_viewport().gui_get_focus_owner() is LineEdit and event.physical_keycode!=KEY_ESCAPE:return
		if FrontierInput.matches(event,"rover_seat") and not rovers.seat().is_empty():session.send_request("rover_switch",{"id":rovers.seat().id});return
		if FrontierInput.matches(event,"camera") and not rovers.seat().is_empty():rovers.chase=not rovers.chase;return
		if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_5 and surface_world!=null and not feedback.blocked():
			session.send_request("equipment_select",{"slot":event.physical_keycode-KEY_1});return
		if event.physical_keycode==KEY_H and surface_world!=null and not feedback.blocked():field_hud.environment.toggle_details();return
		if event.physical_keycode==KEY_R and surface_world!=null and not feedback.blocked():order_robot();return
		if event.physical_keycode==KEY_C and surface_world==null and _mouse_look_allowed():outside=not outside;exterior_view.visible=outside;if_flight_view();get_viewport().gui_release_focus()
		if event.physical_keycode==KEY_G and onboarding.can_open_map() and _mouse_look_allowed():navigation_ui.open_galaxy();return
		if event.physical_keycode==KEY_E and outside and surface_world==null and _mouse_look_allowed() and flight.scan_target>=0 and flight.scan_progress>=1.0:
			navigation_ui.start_route(flight.scan_target);return
		if event.physical_keycode==KEY_Q:surface_action("surface_collect")
		if FrontierInput.matches(event,"rover_interact") and _mouse_look_allowed():
			if not stations.interact() and not rovers.interact() and not navigation_ui.interact():interact_business()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and surface_world!=null and dig_timer<=0:
		if not placement_kind.is_empty():
			if placement_valid:session.send_request("business_build",{"building":placement_kind,"position":FrontierExpeditionBusiness.array(placement_point)});cancel_placement()
			else:feedback.reject(placement_reason)
			return
		if inventory_panel.visible or business_panel.visible or shipyard_panel.visible or research_frame.visible or navigation_frame.visible:return
		use_equipped()
func if_flight_view() -> void:
	if flight!=null:flight.exterior=outside
func toggle_ready() -> void:
	if session.active:session.send_request("ready",{"value":not session.latest.crew.members[session.latest.self_id].ready})
func assign_pilot() -> void:
	if not crew_ids.is_empty():session.send_request("pilot",{"character_id":crew_ids[pilot_choices.selected]})
func select_destination() -> void:
	session.send_request("navigate",{"ordinal":selected_ordinal})
func recover_nearby() -> void:
	if not session.active:return
	var own: Dictionary=session.latest.crew.members[session.latest.self_id]
	for id in session.latest.crew.recovery:
		var crate: Dictionary=session.latest.crew.recovery[id]
		if _crate_here(crate) and crate.area==own.area and FrontierCrewWorld.vector(crate.position).distance_to(FrontierCrewWorld.vector(own.position))<=float(FrontierCrewWorld.config().interaction_distance):session.send_request("recover",{"crate_id":id});return
	status.value="가까운 곳에 회수 화물이 없습니다."
func leave_world() -> void:
	if await session.close_session():get_tree().reload_current_scene()
func return_title() -> void:
	if await session.close_session():get_tree().change_scene_to_file("res://scenes/app/main.tscn")
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if await session.close_session():get_tree().quit()

func _suit_color(node: Node,tint: int) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		for index in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(index)
			if material is ShaderMaterial and material.resource_name=="teal":
				var personal: ShaderMaterial=material.duplicate()
				personal.set_shader_parameter("base_color",Color(["175e61","98552b","385a77","57654a","7a6750","784648"][tint]))
				node.set_surface_override_material(index,personal)
	for child in node.get_children():_suit_color(child,tint)

func kick_selected() -> void:
	if not crew_ids.is_empty():
		if not session.kick(crew_ids[pilot_choices.selected]):status.value="다른 승무원을 선택하세요."
func show_equipment() -> void:
	if surface_world!=null:toggle_inventory();return
	if profile.data.is_empty():return
	var dialog:=AcceptDialog.new();dialog.theme=ui_theme;dialog.title="내 캐릭터 · 소유 장비"
	var lines: PackedStringArray=[profile.data.character.name]
	for item in profile.data.character.equipment:
		lines.append("%s · %s · %s" % [{"pressure_suit":"탐험복","survey_scanner":"조사 스캐너","rock_tool":"굴착 도구"}[item.definition],{"standard":"기본","improved":"개량","rare":"희귀"}[item.grade]," / ".join(item.traits.map(func(value: String):return {"efficient":"절전","sturdy":"내구 강화","expanded_cargo":"확장 적재"}[value])) if not item.traits.is_empty() else "기본 특성"])
	lines.append("\n이 장비는 다른 호스트의 원정에서도 유지됩니다.")
	dialog.dialog_text="\n".join(lines);dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free);add_child(dialog);dialog.popup_centered(Vector2i(580,240))

func _sync_recovery(records: Dictionary) -> void:
	for id in recovery_models.keys():
		if not records.has(id) or not _crate_here(records[id]):recovery_models[id].queue_free();recovery_models.erase(id)
	for id in records:
		if not _crate_here(records[id]) or recovery_models.has(id):continue
		var crate: Node3D=load("res://assets/models/crew/recovery_crate.glb").instantiate()
		crate.position=FrontierCrewWorld.vector(records[id].position);FrontierInkStyle.apply(crate,cache);add_child(crate)
		var label:=Label3D.new();label.render_priority=110;label.outline_render_priority=109;label.outline_size=4;label.text="회수 화물 · 암석 %d" % int(records[id].rock);label.font=ui_theme.default_font;label.position.y=.95;label.font_size=42;label.pixel_size=.002;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;crate.add_child(label)
		recovery_models[id]=crate

func _crate_here(record: Dictionary) -> bool:
	var landing: Dictionary=session.latest.get("crew",{}).get("landing",{})
	return record.area=="cabin" if landing.is_empty() else record.area=="surface" and record.get("body_id","")==landing.body_id

func _surface_packet(packet: Dictionary) -> void:
	if preparing_first_snapshot:return
	if not session.active or session.latest.get("phase")!="playing":return
	_sync_surface_view()
	if surface_world!=null:
		surface_world.accept(packet);_refresh_surface_options()
		business_panel.update(packet.get("business",{}),surface_world.body.id,session.latest.self_id,int(surface_world.body.planet_tier),session.surface.get("engineering",{}),session.surface.get("ecology",{}),surface_world.body,camera.global_position,session.latest.crew.members.size())

func _sync_surface_view() -> void:
	if session.latest.is_empty() or session.latest.get("phase")!="playing":return
	var landing: Dictionary=session.latest.crew.get("landing",{})
	if landing.is_empty():
		if arrival.active and arrival.phase=="ascent":return
		if surface_world!=null:remove_child(surface_world);surface_world.queue_free();surface_world=null
		if cabin_root.get_parent()==null:add_child(cabin_root)
		if space_view!=null:space_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		research_frame.hide();surface_status.hide();reticle.hide();business_panel.hide();cancel_placement();return
	if cabin_root.get_parent()!=null:remove_child(cabin_root)
	outside=false;exterior_view.hide()
	if space_view!=null:space_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if arrival.active and arrival.phase=="approach":
		outside=true;exterior_view.show();space_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	reticle.show()
	if session.surface.is_empty() or session.surface.body_id!=landing.body_id or int(session.surface.epoch)!=int(landing.epoch):surface_status.value="호스트의 지표 기록을 수신 중입니다.";return
	if surface_world!=null and (surface_world.body.id!=landing.body_id or surface_world.epoch!=int(landing.epoch)):remove_child(surface_world);surface_world.queue_free();surface_world=null
	if surface_world==null and actors.has(session.latest.self_id):
		surface_world=FrontierCrewSurfaceScene.new();add_child(surface_world);surface_world.configure(session,session.surface,actors[session.latest.self_id],camera)
		_refresh_surface_options()

func _update_surface_hud() -> void:
	if surface_world==null or session.surface.is_empty() or arrival.active:return
	for id in surface_world.ecology.actors:
		var creature: Node3D=surface_world.ecology.actors[id]
		var hp: int=int(session.latest.crew.get("combat",{}).get(surface_world.body.id+"/"+str(id),FrontierEquipment.config().animal_health))
		if creature.get_meta("combat_hp",-1)!=hp:
			creature.set_meta("combat_hp",hp)
			if hp<int(FrontierEquipment.config().animal_health):creature.set_state("dormant" if hp==0 else "stressed")
	surface_target=surface_world.ecology.target(camera)
	var position: Vector3=actors[session.latest.self_id].position
	var text: String="%s · 깊이 %.1fm"%[surface_world.body.name,maxf(0,-position.y)]
	var distance: float=position.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	text+=" · 우주선 %.0fm · 표본 %d / %d"%[distance,session.surface.ecology.specimens.size(),int(FrontierEcologyCatalog.config().cargo_capacity)]

	if not surface_target.is_empty():
		var form:=FrontierEcologyCatalog.form(surface_target.form_id)
		text+="\n"+str(form.name)
		if form.category=="animal":text+=" · 체력 %d/%d"%[int(session.latest.crew.get("combat",{}).get(surface_world.body.id+"/"+str(surface_target.id),FrontierEquipment.config().animal_health)),int(FrontierEquipment.config().animal_health)]
		var progress: Dictionary=session.latest.get("scan",{})
		var known: bool=session.surface.ecology.observations.has(surface_world.body.id+":"+form.id)
		text+="\nQ 생체 표본" if known else "\nE 유지 · 스캔 %d%%"%int(float(progress.get("progress",0))*100)
	else:text+="\nI 아이템·제작  ·  1–5 장비 전환  ·  E 내장 스캐너"
	if not surface_world.ready_at(position):text+="\n안전한 지형을 불러오는 중입니다."
	var business_target:=surface_world.business_view.target(camera,actors[session.latest.self_id])
	if not business_target.is_empty():
		text+="\nF 현장 작업 · B 개발/건설"
		if business_target.get("kind")=="vein":
			var vein:=FrontierExpeditionBusiness.find_vein(surface_world.body,business_target.id)
			text+=" · 채집기 %d등급 필요"%int(vein.get("required_tier",1))
	surface_status.value=text
	surface_status.visible=not inventory_panel.visible and not business_panel.visible and not research_frame.visible and not shipyard_panel.visible

func _refresh_surface_options() -> void:
	if session.surface.is_empty():return
	var ecological: Dictionary=session.surface.ecology
	if not form_options.get_popup().visible:
		var selected: String=str(form_options.get_item_metadata(form_options.selected)) if form_options.selected>=0 else ""
		form_options.clear();var ids: Array=[]
		for row in ecological.observations.values():
			if row.form_id not in ids:ids.append(row.form_id)
		for row in ecological.research.values():
			if row.form_id not in ids:ids.append(row.form_id)
		ids.sort()
		for id in ids:form_options.add_icon_item(FrontierResourceIcons.menu_texture(FrontierResourceIcons.specimen_id(FrontierEcologyCatalog.form(id))),FrontierEcologyCatalog.form(id).name);form_options.set_item_metadata(form_options.item_count-1,id)
		if selected in ids:form_options.select(ids.find(selected))
		if ids.is_empty():form_options.add_item("스캔한 생명체 없음");form_options.set_item_metadata(0,"")
	if not sample_options.get_popup().visible:
		var selected: String=str(sample_options.get_item_metadata(sample_options.selected)) if sample_options.selected>=0 else ""
		sample_options.clear();var ids: Array=ecological.specimens.keys();ids.sort()
		for id in ids:sample_options.add_icon_item(FrontierResourceIcons.menu_texture(FrontierResourceIcons.specimen_id(FrontierEcologyCatalog.form(ecological.specimens[id].form_id))),FrontierEcologyCatalog.form(ecological.specimens[id].form_id).name);sample_options.set_item_metadata(sample_options.item_count-1,id)
		if selected in ids:sample_options.select(ids.find(selected))
		if ids.is_empty():sample_options.add_item("격리 운송 표본 없음");sample_options.set_item_metadata(0,"")

func surface_action(kind: String) -> void:
	if not session.active or surface_world==null:return
	if kind in ["surface_dig","surface_attack","surface_collect"] and (inventory_panel.visible or business_panel.visible or shipyard_panel.visible or research_frame.visible or navigation_frame.visible):return
	var aim: Vector3=-camera.global_basis.z
	var args: Dictionary={"aim":[aim.x,aim.y,aim.z]}
	if kind=="surface_collect":
		if surface_target.is_empty():status.value="생명체를 가까이서 조준하세요.";return
		args.encounter_id=surface_target.id
	elif kind in ["surface_analyze","surface_restore"]:
		var id: String=str(form_options.get_item_metadata(form_options.selected)) if form_options.selected>=0 else ""
		var form:=FrontierEcologyCatalog.form(id)
		if form.is_empty():status.value="스캔한 생명체를 먼저 선택하세요.";return
		args.form_id=id;args.environment=form.environment
	elif kind=="surface_introduce":args.sample_id=str(sample_options.get_item_metadata(sample_options.selected)) if sample_options.selected>=0 else ""
	session.send_request(kind,args)

func _exit_tree() -> void:
	Input.use_accumulated_input=previous_accumulated_input
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(cabin_root) and cabin_root.get_parent()==null:cabin_root.free()

func menu_frames() -> Array:
	var frames: Array=[rovers.panel if rovers!=null else null,rovers.dock if rovers!=null else null,navigation_frame,inventory_panel,business_panel,shipyard_panel,research_frame,station_market]
	if stations!=null:frames.append(stations.panel)
	if navigation_ui!=null:frames.append_array([navigation_ui.pause_frame,navigation_ui.crew_frame])
	return frames
func any_menu_open() -> bool:
	if get_tree().has_meta("startup_loader"):return true
	for frame in menu_frames():
		if is_instance_valid(frame) and frame.is_visible_in_tree():return true
	return false
func close_menus() -> void:
	for frame in menu_frames():
		if is_instance_valid(frame):frame.hide()
	_menu_changed()
func open_menu(frame: Control) -> void:
	var opening:=not frame.visible
	close_menus();cancel_placement()
	if opening:frame.show()
	_menu_changed()
func _menu_changed() -> void:
	cursor_released=false;mouse_steering=Vector2.ZERO
	mouse_resume_guard=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if any_menu_open():
		if field_hud!=null:field_hud.hide()
		if inventory_panel!=null:inventory_panel.hotbar.visible=inventory_panel.visible
		if navigation_ui!=null:
			navigation_ui.context.hide();navigation_ui.mini.hide()
		if onboarding!=null:onboarding.depart.hide()
	get_viewport().gui_release_focus()
	_sync_mouse_capture()
func toggle_shipyard() -> void:
	if not session.active:return
	open_menu(shipyard_panel)
	shipyard_panel.update_snapshot(session.latest,session.surface.get("business",{}))
func toggle_business() -> void:
	if not session.active or surface_world==null:return
	business_panel.set_context("build")
	open_menu(business_panel)
	business_panel.update(session.surface.get("business",{}),surface_world.body.id,session.latest.self_id,int(surface_world.body.planet_tier),session.surface.get("engineering",{}),session.surface.get("ecology",{}),surface_world.body,camera.global_position,session.latest.crew.members.size())
func interact_business() -> void:
	if not session.active or surface_world==null or inventory_panel.visible or business_panel.visible or shipyard_panel.visible or research_frame.visible or navigation_frame.visible:return
	var target:=surface_world.business_view.target(camera,actors[session.latest.self_id])
	match target.get("kind",""):
		"vein":session.send_request("business_mine",{"vein_id":target.id})
		"base":open_station("base",target.id)
		"crate":session.send_request("business_recover_crate",{"crate_id":target.id})
		"robot":open_station("robot",target.id)
		"building":
			var row: Dictionary=session.surface.get("business",{}).get("sites",{}).get(surface_world.body.id,{}).get("buildings",{}).get(target.id,{})
			if not row.is_empty():open_station(row.type,target.id)
		_:status.value="광맥이나 현장 창고를 조준하고 F를 누르세요."
func open_station(kind: String,id: String="",management: bool=false) -> void:
	if not session.active or surface_world==null:return
	if kind in ["base","storage"] and not management:
		open_menu(inventory_panel);inventory_panel.warehouse_choice.select(0);inventory_panel.tabs.current_tab=2;return
	close_menus()
	business_panel.set_context(kind,id)
	business_panel.shuttle_panel.update_snapshot(session.latest)
	business_panel.vessel_terminal.update_snapshot(session.latest)
	open_menu(business_panel)
	business_panel.update(session.surface.get("business",{}),surface_world.body.id,session.latest.self_id,int(surface_world.body.planet_tier),session.surface.get("engineering",{}),session.surface.get("ecology",{}),surface_world.body,camera.global_position,session.latest.crew.members.size())
func open_warehouse_management() -> void:
	if not session.active or surface_world==null:return
	var current: Dictionary=session.surface.get("business",{}).get("sites",{}).get(surface_world.body.id,{})
	if current.is_empty():return
	var position_value:=FrontierCrewWorld.vector(session.latest.crew.members[session.latest.self_id].position)
	var closest: String="";var distance:=position_value.distance_to(FrontierCrewWorld.vector(current.center))
	for id in current.get("buildings",{}):
		var row: Dictionary=current.buildings[id]
		if row.type!="storage":continue
		var gap:=position_value.distance_to(FrontierCrewWorld.vector(row.position))
		if gap<distance:distance=gap;closest=id
	if distance>float(FrontierExpeditionBusiness.config().deposit_range):status.value="현장 창고 9m 이내로 접근하세요.";return
	open_station("base" if closest.is_empty() else "storage",closest,true)
func station_action(kind: String) -> void:
	match kind:
		"inventory":
			open_menu(inventory_panel)
		"storage":
			open_station("base")
		"cargo":
			open_menu(inventory_panel);inventory_panel.warehouse_choice.select(1);inventory_panel.tabs.current_tab=2
		"research":
			close_menus();toggle_research()
			for control in research_actions:control.show()
		"shipyard":toggle_shipyard()
		"launch":
			close_menus()
			session.send_request("surface_board",{})
func order_robot() -> void:
	var target:=surface_world.business_view.target(camera,actors[session.latest.self_id])
	if target.get("kind")!="vein":feedback.reject("광맥을 조준하고 R로 로봇에게 지시하세요.");return
	session.send_request("business_assign",{"vein_id":target.id,"robot_id":preferred_robot_id})

func begin_placement(kind: String) -> void:
	cancel_placement();close_menus()
	if kind.is_empty() or surface_world==null:return
	placement_kind=kind
	placement_ghost=load("res://assets/models/"+FrontierCatalog.entry("buildings",kind).model+".glb").instantiate();add_child(placement_ghost)
	ghost_material=StandardMaterial3D.new();ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ghost_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ghost_material.albedo_color=Color(.3,.9,.6,.45)
	for node in placement_ghost.find_children("*","MeshInstance3D",true,false):node.material_override=ghost_material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func cancel_placement() -> void:
	placement_kind="";placement_valid=false;placement_reason=""
	if is_instance_valid(placement_ghost):placement_ghost.queue_free()
	placement_ghost=null
func _update_business_placement() -> void:
	if placement_kind.is_empty() or surface_world==null:return
	var query:=PhysicsRayQueryParameters3D.create(camera.position,camera.position-camera.global_basis.z*12);query.exclude=[actors[session.latest.self_id].get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	placement_valid=false
	if hit.is_empty():placement_ghost.hide();placement_reason="12m 안의 지면을 조준하세요 · Esc 취소";return
	placement_point=hit.position
	var ground_height: float=surface_world.terrain.field.height(placement_point.x,placement_point.z)
	var on_surface: bool=absf(placement_point.y-ground_height)<1.5
	if on_surface:placement_point.y=ground_height
	placement_ghost.position=placement_point;placement_ghost.show()
	var packet: Dictionary=session.surface
	var world: Dictionary=FrontierShuttles.context(session.authority.world,session.latest.self_id) if session.hosting else {"manifest":session.manifest,"location":surface_world.body.id,"business":packet.get("business",{}),"crew":session.latest.crew,"terrain_settings":packet.terrain_settings,"terrain_edits":{surface_world.body.id:packet.edits}}
	var current:=FrontierExpeditionBusiness.site(world)
	var reason: String="착륙 지표를 준비 중입니다." if current.is_empty() else FrontierExpeditionBusiness.build_reason(world,session.latest.self_id,placement_kind,placement_point,session.latest.crew.members.keys().reduce(func(acc: Dictionary,id: String):acc[id]=id;return acc,{}))
	if not on_surface:reason="지표의 평탄한 지면에 배치하세요 · Esc 취소"
	if reason.is_empty() and not surface_world.ready_at(placement_point):reason="지면을 불러오는 중입니다."
	placement_reason=reason
	placement_valid=on_surface and reason.is_empty() and surface_world.ready_at(placement_point)
	ghost_material.albedo_color=Color(.3,.9,.6,.45) if placement_valid else Color(.95,.25,.15,.45)
	status.value=("클릭 건설 · "+FrontierCatalog.cost_text(FrontierCatalog.entry("buildings",placement_kind).cost)) if placement_valid else reason

func start_solo(fresh: bool=false) -> void:
	if not test_mode:world_store=FrontierWorldStore.new("user://solo_"+FrontierPlayerProfile.token()+".json" if fresh else selected_world_path(true))
	if not profile.ensure(name_input.text):status.value=profile.error;return
	if session.host(profile,world_store,24560,"*",true):
		remember_world(true)
		session.send_request("start_game",{})
		lobby.hide();panel.show();outside=session.latest.crew.get("landing",{}).is_empty();exterior_view.visible=outside;if_flight_view();get_viewport().gui_release_focus()
func depart_selected() -> void:
	navigation_ui.start_route(selected_ordinal)
func travel_action(action: String) -> void:
	if session.offline or not session.latest.get("local_shuttle","").is_empty():
		session.send_request("ready",{"value":true})
		if not session.latest.crew.members[session.latest.self_id].ready:return
	session.send_request(action,{})
	get_viewport().gui_release_focus()
func toggle_navigation() -> void:
	if not session.active or session.latest.get("phase")!="playing":return
	open_menu(navigation_frame)
	if navigation_frame.visible:navigation_ui.show_target(flight.scan_target if flight!=null and flight.scan_target>=0 else selected_ordinal)
func toggle_research() -> void:
	if surface_world!=null:open_menu(research_frame)

static func selected_world_path(solo: bool) -> String:
	var selection:=ConfigFile.new();selection.load("user://world_selection.cfg")
	return str(selection.get_value("worlds","solo" if solo else "crew","user://solo_world_v3.json" if solo else "user://crew_world_v3.json"))
func remember_world(solo: bool) -> void:
	if test_mode:return
	var selection:=ConfigFile.new();selection.load("user://world_selection.cfg")
	selection.set_value("worlds","solo" if solo else "crew",world_store.path)
	if selection.save("user://world_selection.cfg")!=OK:status.value="세계는 저장했지만 최근 세계 선택을 저장하지 못했습니다."

func toggle_inventory() -> void:
	if not session.active or session.latest.get("phase")!="playing":return
	open_menu(inventory_panel)
func use_equipped() -> void:
	if not rovers.seat().is_empty():return
	var tool:=FrontierEquipment.active(session.latest.crew.members[session.latest.self_id])
	if tool.is_empty():feedback.reject("빈 슬롯입니다. I에서 제작한 장비를 장착하세요.");return
	if tool.kind=="miner" and not session.mining_ready():return
	dig_timer=float(tool.interval)
	match tool.kind:
		"miner":
			var target:=surface_world.business_view.target(camera,actors[session.latest.self_id])
			if target.get("kind")=="vein":session.send_request("business_mine",{"vein_id":target.id})
			else:feedback.reject("자원 광맥을 조준하세요.")
		"terrain":surface_action("surface_dig")
		"pulse":surface_action("surface_attack")

func _mouse_look_allowed() -> bool:
	if session==null or not session.active or session.latest.get("phase")!="playing":return false
	if waiting_screen!=null and waiting_screen.is_visible_in_tree():return false
	if lobby!=null and lobby.is_visible_in_tree():return false
	return not any_menu_open() and feedback!=null and not feedback.blocked() and (onboarding==null or not onboarding.letter.visible)

func _sync_mouse_capture() -> void:
	if test_mode:return
	var capture: bool=_mouse_look_allowed() and not cursor_released and get_window().has_focus()
	var desired: int=Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode!=desired:Input.mouse_mode=desired
	if not capture:mouse_steering=Vector2.ZERO

func _mouse_look(relative: Vector2,sensitivity: float,invert_y: bool) -> void:
	var motion:=relative*sensitivity
	if invert_y:motion.y=-motion.y
	if outside and flight!=null:
		var nav: Dictionary=session.latest.crew.navigation
		if nav.mode=="idle" and session.latest.self_id==session.latest.crew.pilot_id:
			mouse_steering+=Vector2(motion.x,-motion.y)
			flight.look_offset=Vector2.ZERO
		else:
			flight.look_offset.x=clampf(flight.look_offset.x-motion.x,-2.6,2.6)
			flight.look_offset.y=clampf(flight.look_offset.y-motion.y,-1.3,1.3)
	else:
		yaw-=motion.x
		pitch=clampf(pitch-motion.y,deg_to_rad(-89),deg_to_rad(89))
		if camera!=null:camera.rotation=Vector3(pitch,yaw,0)

func _refresh_scan_detail() -> void:
	if navigation_ui!=null:navigation_ui.refresh_survey()

func open_trade_station() -> void:
	station_market.update_snapshot(session.latest)
	if station_market.in_range():open_menu(station_market)
func approach_trade_station() -> void:
	if session.latest.crew.navigation.mode!="idle":return
	if session.offline:session.send_request("ready",{"value":true})
	session.send_request("station_approach",{});close_menus()

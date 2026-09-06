class_name FrontierCrewExpedition
extends Node3D
var session: FrontierCrewSession
var profile:=FrontierPlayerProfile.new()
var world_store:=FrontierWorldStore.new("user://crew_world.json")
var actors: Dictionary={}
var recovery_models: Dictionary={}
var visuals: Dictionary={}
var cache: Dictionary={}
var camera: Camera3D
var flight: FrontierCrewFlightView
var space_view: SubViewport
var exterior_view: TextureRect
var panel: VBoxContainer
var lobby: VBoxContainer
var roster: Label
var status: Label
var travel_status: Label
var address: LineEdit
var pilot_choices: OptionButton
var name_input: LineEdit
var host_address: LineEdit
var port_input: SpinBox
var yaw:=0.0
var pitch:=0.0
var outside:=false
var movement_timer:=0.0
var ready_button: Button
var crew_ids: Array=[]
var ui_theme: Theme
var test_mode:=false
var test_direction:=Vector2.ZERO
var test_camera_position:=Vector3.ZERO
var cabin_root: Node3D
var surface_world: FrontierCrewSurfaceScene
var surface_panel: VBoxContainer
var surface_status: Label
var form_options: OptionButton
var sample_options: OptionButton
var surface_target: Dictionary={}
var dig_timer:=0.0
var test_scan:=false
var reticle: Label
func _ready() -> void:
	test_mode="--crew-ui-test" in OS.get_cmdline_user_args()
	if test_mode:
		profile=FrontierPlayerProfile.new("user://test_crew_ui_profile.json")
		world_store=FrontierWorldStore.new("user://test_crew_ui_world.json")
	session=FrontierCrewSession.new();session.name="Coop";add_child(session)
	session.snapshot_received.connect(_snapshot)
	session.surface_received.connect(_surface_packet)
	session.notice.connect(func(message: String):status.text=message)
	session.response_received.connect(func(_sequence: int,value: Dictionary):
		if not value.get("ok",false):status.text=value.get("error","작업 실패")
		else:status.text="원정 기록을 저장했습니다.")
	_build_cabin();_build_ui()
	if FileAccess.file_exists(profile.path) and profile.ensure():
		name_input.text=profile.data.character.name;name_input.editable=false
	get_tree().auto_accept_quit=false
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
	var ui:=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	var font:=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf");font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):550.0}
	var theme_value:=Theme.new();theme_value.default_font=font;theme_value.default_font_size=15
	theme_value.set_color("font_color","Label",Color("e0ebe3"));theme_value.set_color("font_outline_color","Label",Color("10232c"));theme_value.set_constant("outline_size","Label",4)
	for key in ["normal","hover","pressed"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color(.03,.10,.13,.94) if key=="normal" else Color("376666");style.border_color=Color("729b91");style.set_border_width_all(1);style.set_corner_radius_all(5);style.content_margin_left=12;style.content_margin_right=12;theme_value.set_stylebox(key,"Button",style)
	ui_theme=theme_value;ui.theme=theme_value
	reticle=Label.new();reticle.text="＋";reticle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;reticle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(reticle);reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER);reticle.offset_left=-14;reticle.offset_right=14;reticle.offset_top=-14;reticle.offset_bottom=14;reticle.hide()
	exterior_view=TextureRect.new();exterior_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);exterior_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;exterior_view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;exterior_view.mouse_filter=Control.MOUSE_FILTER_IGNORE;exterior_view.hide();ui.add_child(exterior_view)
	var header:=VBoxContainer.new();header.position=Vector2(24,22);ui.add_child(header)
	_label(header,"L O C U S  /  함께하는 원정",23)
	status=_label(header,"개인 장비를 챙기고 같은 우주선에 승선하세요.",15)
	_label(header,"WASD 이동 · 우클릭 시선 · C 외부 · 지표: 클릭 굴착 / E 스캔 / Q 표본",13)
	for child in header.get_children():child.custom_minimum_size.x=minf(740,get_viewport().get_visible_rect().size.x-390)
	get_viewport().size_changed.connect(func():
		for child in header.get_children():child.custom_minimum_size.x=minf(740,get_viewport().get_visible_rect().size.x-390))
	var frame:=PanelContainer.new();ui.add_child(frame);frame.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);frame.offset_left=-338;frame.offset_right=-22;frame.offset_top=22;frame.offset_bottom=-22
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.065,.09,.92);style.set_content_margin_all(14);style.set_corner_radius_all(7);frame.add_theme_stylebox_override("panel",style)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;frame.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",8);scroll.add_child(column)
	lobby=VBoxContainer.new();lobby.add_theme_constant_override("separation",9);column.add_child(lobby)
	_label(lobby,"원정 참가",22)
	name_input=LineEdit.new();name_input.placeholder_text="탐험가 이름";name_input.text="탐험가";name_input.max_length=24;lobby.add_child(name_input)
	host_address=LineEdit.new();host_address.text="127.0.0.1";host_address.placeholder_text="호스트 주소";lobby.add_child(host_address)
	port_input=SpinBox.new();port_input.min_value=1024;port_input.max_value=65535;port_input.value=24560;lobby.add_child(port_input)
	_button(lobby,"방 만들기 · 최대 6명",host_world)
	_button(lobby,"주소로 참가",join_world)
	_label(lobby,"현재 접속: 직접 UDP\n인터넷 원정에는 호스트 포트 접근이 필요합니다.",13)
	panel=VBoxContainer.new();panel.add_theme_constant_override("separation",8);panel.hide();column.add_child(panel)
	roster=_label(panel,"",15)
	ready_button=_button(panel,"출항 준비",toggle_ready)
	pilot_choices=OptionButton.new();panel.add_child(pilot_choices)
	_button(panel,"조종 권한 전달",assign_pilot).name="TransferPilot"
	_button(panel,"선택한 승무원 내보내기",kick_selected).name="Kick"
	address=LineEdit.new();address.placeholder_text="행성 주소 1 ~ 1000000";address.max_length=7;panel.add_child(address)
	_button(panel,"항로 설정",select_destination).name="Navigate"
	travel_status=_label(panel,"",14)
	_button(panel,"전원 준비 후 항해",func():session.send_request("depart",{})).name="Depart"
	_button(panel,"전원 준비 후 착륙",func():session.send_request("land",{})).name="Land"
	_button(panel,"전원 복귀 후 이륙",func():session.send_request("launch",{})).name="Launch"
	var row:=HBoxContainer.new();panel.add_child(row)
	_button(row,"암석 1 꺼내기",func():session.send_request("withdraw",{"amount":1}))
	_button(row,"1 넣기",func():session.send_request("deposit",{"amount":1}))
	_button(panel,"주변 회수 화물 줍기",recover_nearby)
	surface_panel=VBoxContainer.new();surface_panel.add_theme_constant_override("separation",7);panel.add_child(surface_panel);surface_panel.hide();panel.move_child(surface_panel,2)
	surface_status=_label(surface_panel,"지표를 준비 중입니다.",14)
	form_options=OptionButton.new();form_options.fit_to_longest_item=false;surface_panel.add_child(form_options)
	_button(surface_panel,"선택한 생명체 기초 분석 · 광물 3",func():surface_action("surface_analyze"))
	_button(surface_panel,"선택한 서식지 시험 구획 · 광물 6",func():surface_action("surface_restore"))
	sample_options=OptionButton.new();sample_options.fit_to_longest_item=false;surface_panel.add_child(sample_options)
	_button(surface_panel,"선택한 운송 표본 이식",func():surface_action("surface_introduce"))
	_button(surface_panel,"지원 팩 보충 · 광물 3",func():surface_action("surface_resupply"))
	_button(panel,"내 소유 장비",show_equipment)
	_button(panel,"원정 나가기",leave_world)
	_button(column,"시작 화면",return_title)
func _label(parent: Node,value: String,size: int=15) -> Label:
	var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",size);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=265;parent.add_child(label);return label
func _button(parent: Node,value: String,callback: Callable) -> Button:
	var button:=Button.new();button.text=value;button.custom_minimum_size.y=35;button.pressed.connect(callback);parent.add_child(button);return button
func host_world() -> void:
	if not profile.ensure(name_input.text):status.text=profile.error;return
	if session.host(profile,world_store,int(port_input.value)):lobby.hide();panel.show()
func join_world() -> void:
	if not profile.ensure(name_input.text):status.text=profile.error;return
	if session.join(profile,host_address.text.strip_edges(),int(port_input.value)):lobby.hide();panel.show()
func _setup_flight() -> void:
	space_view=SubViewport.new();space_view.size=Vector2i(1280,800);space_view.own_world_3d=true;space_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(space_view)
	flight=FrontierCrewFlightView.new();flight.state={"manifest":session.manifest};space_view.add_child(flight)
	exterior_view.texture=space_view.get_texture()
	var window:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(7.3,2.35);window.mesh=quad;window.position=Vector3(0,2.16,-7.72)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_texture=space_view.get_texture();material.uv1_scale=Vector3(1,.515,1);material.uv1_offset=Vector3(0,.2425,0);window.material_override=material;window.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;cabin_root.add_child(window)
func _spawn_actor(id: String,member: Dictionary) -> void:
	var actor:=CharacterBody3D.new();actor.name="Crew_"+id;actor.collision_layer=2;actor.collision_mask=1;actor.floor_snap_length=.7;actor.position=FrontierCrewWorld.vector(member.position)
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.29;capsule.height=1.86;collision.shape=capsule;collision.position.y=.93;actor.add_child(collision);add_child(actor)
	var visual: Node3D=load("res://assets/models/crew/surveyor_suit.glb").instantiate();actor.add_child(visual);FrontierInkStyle.apply(visual,cache);_suit_color(visual,int(member.profile.tint))
	var label:=Label3D.new();label.render_priority=110;label.outline_render_priority=109;label.outline_size=4;label.text=member.profile.name;label.font=ui_theme.default_font;label.font_size=52;label.pixel_size=.0035;label.position.y=2.2;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;actor.add_child(label)
	actors[id]=actor;visuals[id]={"model":visual,"label":label,"last":actor.position,"phase":0.0,"limbs":{},"area":member.area}
	for limb in ["Anim_Arm_L","Anim_Arm_R","Anim_Leg_L","Anim_Leg_R"]:visuals[id].limbs[limb]=visual.find_child(limb,true,false)
func _snapshot(value: Dictionary) -> void:
	if not value.get("active",false):return
	if flight==null:_setup_flight()
	flight.update_navigation(value.crew.navigation)
	_sync_recovery(value.crew.recovery)
	var members: Dictionary=value.crew.members
	for id in actors.keys():
		if not members.has(id):actors[id].queue_free();actors.erase(id);visuals.erase(id)
	var lines: PackedStringArray=["승무원 %d / 6" % members.size()]
	for id in members:
		if not actors.has(id):_spawn_actor(id,members[id])
		elif visuals[id].area!=members[id].area:
			actors[id].position=FrontierCrewWorld.vector(members[id].position);actors[id].velocity=Vector3.ZERO;visuals[id].area=members[id].area;visuals[id].last=actors[id].position
		lines.append("%s %s%s" % ["✓" if members[id].ready else "○",members[id].profile.name," · 조종" if id==value.crew.pilot_id else ""])
	var own: Dictionary=members[value.self_id]
	lines.append("창고 %d · 운반 %d" % [int(value.crew.rock),int(own.carried)])
	roster.text="\n".join(lines);ready_button.text="준비 취소" if own.ready else "원정 준비"
	var nav: Dictionary=value.crew.navigation
	var on_surface: bool=not value.crew.get("landing",{}).is_empty()
	for action in ["Navigate","Depart","Land"]:panel.get_node(action).visible=not on_surface
	panel.get_node("Launch").visible=on_surface
	address.visible=not on_surface;travel_status.visible=not on_surface
	panel.get_node("TransferPilot").disabled=not session.hosting
	panel.get_node("Kick").disabled=not session.hosting
	panel.get_node("Navigate").disabled=value.self_id!=value.crew.pilot_id or nav.mode!="idle" or not value.crew.get("landing",{}).is_empty()
	panel.get_node("Depart").disabled=value.self_id!=value.crew.pilot_id or nav.mode!="idle" or not value.crew.get("landing",{}).is_empty()
	panel.get_node("Land").disabled=value.self_id!=value.crew.pilot_id or nav.mode!="idle" or not value.crew.get("landing",{}).is_empty()
	panel.get_node("Launch").disabled=value.self_id!=value.crew.pilot_id or value.crew.get("landing",{}).is_empty()
	travel_status.text="행성 %07d · %s\n속도 %.0f m/s" % [int(nav.target)+1,{"idle":"궤도 대기","approach":"공동 접근 중","jump":"성간 도약 중"}[nav.mode],float(nav.speed)]
	if crew_ids!=members.keys():
		crew_ids=members.keys();pilot_choices.clear()
		for id in crew_ids:pilot_choices.add_item(members[id].profile.name)
	lobby.hide();panel.show()
	_sync_surface_view()
func _physics_process(delta: float) -> void:
	if not session.active or session.latest.is_empty():return
	dig_timer=maxf(0,dig_timer-delta)
	movement_timer-=delta
	if movement_timer<=0:
		movement_timer=.05
		var direction:=test_direction if test_mode else Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if outside or get_viewport().gui_get_focus_owner() is LineEdit:direction=Vector2.ZERO
		direction=direction.rotated(-yaw).limit_length()
		if not session.latest.crew.get("landing",{}).is_empty() and (surface_world==null or not surface_world.ready_at(actors[session.latest.self_id].position)):direction=Vector2.ZERO
		var scanning: bool=(test_scan if test_mode else Input.is_physical_key_pressed(KEY_E)) and surface_world!=null and not surface_target.is_empty() and not get_viewport().gui_get_focus_owner() is LineEdit
		session.send_input(direction,-camera.global_basis.z,scanning)
	if session.hosting and not session.authority.stopped:
		for peer in session.authority.peers:
			var id: String=session.authority.peers[peer]
			if not actors.has(id):continue
			var actor: CharacterBody3D=actors[id];var direction:=session.authority.direction_for(peer)
			if FrontierCrewSurface.landed(session.authority.world):
				if surface_world==null or not surface_world.ready_at(actor.position):actor.velocity=Vector3.ZERO;continue
				var next:=actor.position+Vector3(direction.x,0,direction.y)*float(FrontierCrewSurface.config().movement_speed)*delta
				if not surface_world.ready_at(next):actor.velocity=Vector3.ZERO;continue
				actor.velocity.x=direction.x*float(FrontierCrewSurface.config().movement_speed);actor.velocity.z=direction.y*float(FrontierCrewSurface.config().movement_speed)
				if not actor.is_on_floor():actor.velocity.y-=float(FrontierCrewSurface.config().gravity)*delta
				else:actor.velocity.y=-1
				if actor.position.y<float(surface_world.config.minimum_depth)+2 or maxf(absf(actor.position.x),absf(actor.position.z))>float(surface_world.config.region_half_extent):actor.position=Vector3(0,4,0);actor.velocity=Vector3.ZERO
			else:actor.velocity=Vector3(direction.x*float(FrontierCrewWorld.config().movement_speed),-1,direction.y*float(FrontierCrewWorld.config().movement_speed))
			actor.move_and_slide();session.authority.update_position(peer,actor.position)
func _process(delta: float) -> void:
	if session==null or session.latest.is_empty() or not session.active:return
	var members: Dictionary=session.latest.crew.members
	for id in actors:
		var actor: CharacterBody3D=actors[id];var visual: Dictionary=visuals[id]
		if not session.hosting:actor.position=actor.position.lerp(FrontierCrewWorld.vector(members[id].position),minf(delta*14,1))
		var displacement: Vector3=actor.position-visual.last;visual.last=actor.position
		var distance:=Vector2(displacement.x,displacement.z).length();visual.phase+=distance*7
		if distance>.0005:visual.model.rotation.y=lerp_angle(visual.model.rotation.y,atan2(-displacement.x,-displacement.z),minf(delta*12,1))
		for limb in visual.limbs:
			if visual.limbs[limb]!=null:visual.limbs[limb].rotation.x=sin(float(visual.phase))*.45*(1 if limb in ["Anim_Arm_L","Anim_Leg_R"] else -1) if distance>.0005 else lerpf(visual.limbs[limb].rotation.x,0,minf(delta*10,1))
		var own: bool=id==session.latest.self_id
		visual.model.visible=not own;visual.label.visible=not own
	if actors.has(session.latest.self_id):camera.position=actors[session.latest.self_id].position+Vector3(0,1.72,0)
	if test_mode and test_camera_position!=Vector3.ZERO:camera.position=test_camera_position
	camera.rotation=Vector3(pitch,yaw,0)
	_update_surface_hud()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):yaw-=event.relative.x*.0025;pitch=clampf(pitch-event.relative.y*.0025,-1.3,1.3)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_C and surface_world==null:outside=not outside;exterior_view.visible=outside;if_flight_view()
		if event.physical_keycode==KEY_Q:surface_action("surface_collect")
		if event.physical_keycode==KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;get_viewport().gui_release_focus()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and surface_world!=null and dig_timer<=0:
		dig_timer=.35;surface_action("surface_dig")
func if_flight_view() -> void:
	if flight!=null:flight.exterior=outside
func toggle_ready() -> void:
	if session.active:session.send_request("ready",{"value":not session.latest.crew.members[session.latest.self_id].ready})
func assign_pilot() -> void:
	if not crew_ids.is_empty():session.send_request("pilot",{"character_id":crew_ids[pilot_choices.selected]})
func select_destination() -> void:
	if not address.text.is_valid_int():status.text="행성 번호를 입력하세요.";return
	session.send_request("navigate",{"ordinal":int(address.text)-1})
func recover_nearby() -> void:
	if not session.active:return
	var own: Dictionary=session.latest.crew.members[session.latest.self_id]
	for id in session.latest.crew.recovery:
		var crate: Dictionary=session.latest.crew.recovery[id]
		if _crate_here(crate) and crate.area==own.area and FrontierCrewWorld.vector(crate.position).distance_to(FrontierCrewWorld.vector(own.position))<=float(FrontierCrewWorld.config().interaction_distance):session.send_request("recover",{"crate_id":id});return
	status.text="가까운 곳에 회수 화물이 없습니다."
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
		if not session.kick(crew_ids[pilot_choices.selected]):status.text="다른 승무원을 선택하세요."
func show_equipment() -> void:
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
	if not session.active:return
	_sync_surface_view()
	if surface_world!=null:surface_world.accept(packet);_refresh_surface_options()

func _sync_surface_view() -> void:
	if session.latest.is_empty():return
	var landing: Dictionary=session.latest.crew.get("landing",{})
	if landing.is_empty():
		if surface_world!=null:remove_child(surface_world);surface_world.queue_free();surface_world=null
		if cabin_root.get_parent()==null:add_child(cabin_root)
		if space_view!=null:space_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		surface_panel.hide();reticle.hide();return
	if cabin_root.get_parent()!=null:remove_child(cabin_root)
	outside=false;exterior_view.hide()
	if space_view!=null:space_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	surface_panel.show();reticle.show()
	if session.surface.is_empty() or session.surface.body_id!=landing.body_id or int(session.surface.epoch)!=int(landing.epoch):surface_status.text="호스트의 지표 기록을 수신 중입니다.";return
	if surface_world!=null and (surface_world.body.id!=landing.body_id or surface_world.epoch!=int(landing.epoch)):remove_child(surface_world);surface_world.queue_free();surface_world=null
	if surface_world==null and actors.has(session.latest.self_id):
		surface_world=FrontierCrewSurfaceScene.new();add_child(surface_world);surface_world.configure(session,session.surface,actors[session.latest.self_id],camera)
		_refresh_surface_options()

func _update_surface_hud() -> void:
	if surface_world==null:return
	surface_target=surface_world.ecology.target(camera)
	var position: Vector3=actors[session.latest.self_id].position
	var record: Dictionary=surface_world.ecology.ecology.planets[surface_world.body.id]
	var text: String="%s · 깊이 %.1fm"%[surface_world.body.name,maxf(0,-position.y)]
	var distance: float=position.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	text+="\n우주선 %.0fm · 격리 화물 %d / %d"%[distance,session.surface.ecology.specimens.size(),int(FrontierEcologyCatalog.config().cargo_capacity)]
	if distance>float(FrontierCrewSurface.config().boarding_distance):text+="\n연구·화물 작업은 우주선 근처에서 가능합니다."
	if not record.plot.is_empty():
		text+="\n관리 구획 · 생물량 %.1f\n지원 팩 %d분 남음"%[float(record.plot.biomass),ceili(float(record.plot.support_remaining)/60)]
		if float(record.plot.support_remaining)<=0:text+=" · 보충 필요"
	if not surface_target.is_empty():
		var form:=FrontierEcologyCatalog.form(surface_target.form_id)
		text+="\n"+str(form.name)
		var progress: Dictionary=session.latest.get("scan",{})
		var known: bool=session.surface.ecology.observations.has(surface_world.body.id+":"+form.id)
		text+="\nQ 생체 표본" if known else "\nE 유지 · 스캔 %d%%"%int(float(progress.get("progress",0))*100)
	else:text+="\n생명체를 조준하고 E를 유지하세요."
	if not surface_world.ready_at(position):text+="\n안전한 지형을 불러오는 중입니다."
	surface_status.text=text

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
		for id in ids:form_options.add_item(FrontierEcologyCatalog.form(id).name);form_options.set_item_metadata(form_options.item_count-1,id)
		if selected in ids:form_options.select(ids.find(selected))
		if ids.is_empty():form_options.add_item("스캔한 생명체 없음");form_options.set_item_metadata(0,"")
	if not sample_options.get_popup().visible:
		var selected: String=str(sample_options.get_item_metadata(sample_options.selected)) if sample_options.selected>=0 else ""
		sample_options.clear();var ids: Array=ecological.specimens.keys();ids.sort()
		for id in ids:sample_options.add_item(FrontierEcologyCatalog.form(ecological.specimens[id].form_id).name);sample_options.set_item_metadata(sample_options.item_count-1,id)
		if selected in ids:sample_options.select(ids.find(selected))
		if ids.is_empty():sample_options.add_item("격리 운송 표본 없음");sample_options.set_item_metadata(0,"")

func surface_action(kind: String) -> void:
	if not session.active or surface_world==null:return
	var aim: Vector3=-camera.global_basis.z
	var args: Dictionary={"aim":[aim.x,aim.y,aim.z]}
	if kind=="surface_collect":
		if surface_target.is_empty():status.text="생명체를 가까이서 조준하세요.";return
		args.encounter_id=surface_target.id
	elif kind in ["surface_analyze","surface_restore"]:
		var id: String=str(form_options.get_item_metadata(form_options.selected)) if form_options.selected>=0 else ""
		var form:=FrontierEcologyCatalog.form(id)
		if form.is_empty():status.text="스캔한 생명체를 먼저 선택하세요.";return
		args.form_id=id;args.environment=form.environment
	elif kind=="surface_introduce":args.sample_id=str(sample_options.get_item_metadata(sample_options.selected)) if sample_options.selected>=0 else ""
	session.send_request(kind,args)

func _exit_tree() -> void:
	if is_instance_valid(cabin_root) and cabin_root.get_parent()==null:cabin_root.free()

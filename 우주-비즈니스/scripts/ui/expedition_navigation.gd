extends Control
## The map is a planning surface. Flight actions belong to nearby world targets.
var app: FrontierCrewExpedition
var pause_frame: PanelContainer
var crew_frame: PanelContainer
var mini: Control
var context: Button
var context_kind: String=""
var context_ordinal: int=-1
var context_ready:=false
var context_distance:=INF
var route: Button
var target_name: Label
var target_kind: Label
var resources: HBoxContainer
var survey: VBoxContainer
var survey_bars: Dictionary={}
var survey_note: Label
var map_mode: Button
var card: VBoxContainer
var message: Label
var toast_left:=0.0
var pending_route: int=-1
var pending_sequence: int=-1
var pending_revision: int=-1
var closing:=false
var selected_preview: int=-1
var preview: SubViewport
var preview_root: Node3D
var preview_camera: Camera3D
var preview_body: Node3D
var preview_key: String=""

func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;theme=app.ui_theme;mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_map()
	_build_pause()
	_build_crew()
	mini=load("res://scripts/ui/galaxy_chart.gd").new();mini.compact=true;mini.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(mini)
	context=Button.new();context.hide();context.focus_mode=Control.FOCUS_NONE;context.pressed.connect(interact);add_child(context)
	context.add_theme_stylebox_override("normal",FrontierInterfaceStyle.box(Color("10191fd9"),Color("31434d00"),12))
	message=FrontierInterfaceStyle.label(self,"",14,FrontierInterfaceStyle.WARNING);message.hide()
	app.session.notice.connect(func(value: String):
		if value.contains("실패") or value.contains("없") or value.contains("오류"): _notice(value))
	app.session.request_started.connect(func(sequence: int,kind: String,_args: Dictionary):
		if pending_route>=0 and kind=="navigate":pending_sequence=sequence)
	app.session.response_received.connect(_response)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _button(parent: Node,title: String,action: Callable) -> Button:
	var button:=Button.new();button.text=title;button.custom_minimum_size.y=38;parent.add_child(button);button.pressed.connect(action);return button
func _frame() -> PanelContainer:
	var frame:=PanelContainer.new();frame.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK));add_child(frame);frame.hide();return frame
func _column(frame: PanelContainer) -> VBoxContainer:
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);frame.add_child(column);return column
func _build_map() -> void:
	var heading:=HBoxContainer.new();app.panel.add_child(heading)
	var title:=FrontierInterfaceStyle.label(heading,"항성 지도",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	map_mode=_button(heading,"은하 보기",func():app.chart.galaxy=not app.chart.galaxy;app.chart.reset_view();_map_mode())
	_button(heading,"기록",func():app.navigation_records.refresh();app.navigation_records.popup_centered())
	_button(heading,"닫기  Tab",app.close_menus)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",18);app.panel.add_child(body)
	app.chart=load("res://scripts/ui/galaxy_chart.gd").new();app.chart.size_flags_horizontal=Control.SIZE_EXPAND_FILL;app.chart.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(app.chart)
	app.chart.selected.connect(show_target)
	card=VBoxContainer.new();card.custom_minimum_size.x=240;card.add_theme_constant_override("separation",12);body.add_child(card)
	preview=SubViewport.new();preview.size=Vector2i(320,240);preview.own_world_3d=true;preview.transparent_bg=true;preview.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(preview)
	preview_root=Node3D.new();preview.add_child(preview_root)
	preview_camera=Camera3D.new();preview_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;preview_camera.size=2.9;preview_camera.position=Vector3(0,.4,4);preview_root.add_child(preview_camera);preview_camera.look_at(Vector3.ZERO);FrontierInkStyle.attach(preview_camera)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,-35,0);sun.light_energy=1.4;preview_root.add_child(sun)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("10191f");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("91aab3");environment.environment.ambient_light_energy=.5;preview_root.add_child(environment)
	var picture:=TextureRect.new();picture.texture=preview.get_texture();picture.custom_minimum_size=Vector2(240,160);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;card.add_child(picture)
	target_name=FrontierInterfaceStyle.label(card,"천체를 선택하세요",22);target_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	target_kind=FrontierInterfaceStyle.label(card,"",13,FrontierInterfaceStyle.MUTED);target_kind.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	resources=HBoxContainer.new();card.add_child(resources)
	survey=VBoxContainer.new();survey.add_theme_constant_override("separation",12);card.add_child(survey)
	for entry in [["water","수자원"],["air","대기 적합"],["temperature","기온 적합"]]:
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);survey.add_child(row)
		var label:=FrontierInterfaceStyle.label(row,entry[1],12,FrontierInterfaceStyle.MUTED);label.custom_minimum_size.x=70
		var bar:=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size=Vector2(120,8);bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		bar.focus_mode=Control.FOCUS_ALL
		bar.add_theme_stylebox_override("background",FrontierInterfaceStyle.box(Color("26363e"),Color.TRANSPARENT,0))
		bar.add_theme_stylebox_override("fill",FrontierInterfaceStyle.box(FrontierInterfaceStyle.ACCENT,Color.TRANSPARENT,0))
		row.add_child(bar);survey_bars[entry[0]]=bar
	survey_note=FrontierInterfaceStyle.label(card,"",12,FrontierInterfaceStyle.MUTED);survey_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	route=_button(card,"출발",func():start_route(selected_preview))
	app.travel_status=target_kind
	app.navigation_records=FrontierNavigationRecords.new();app.add_child(app.navigation_records);app.navigation_records.selected.connect(show_target)
	app.navigation_records.visibility_changed.connect(app._menu_changed)
	app.navigation_frame.visibility_changed.connect(func():
		preview.render_target_update_mode=SubViewport.UPDATE_ALWAYS if app.navigation_frame.visible else SubViewport.UPDATE_DISABLED)
	_map_mode()
func _build_pause() -> void:
	pause_frame=_frame();var column:=_column(pause_frame)
	FrontierInterfaceStyle.label(column,"메뉴",25)
	_button(column,"계속하기  Esc",app.close_menus)
	_button(column,"설정",func():FrontierClientSettings.ensure(get_tree()).open())
	_button(column,"우주선 정비  K",app.toggle_shipyard)
	_button(column,"승무원  P",func():app.open_menu(crew_frame))
	_button(column,"시작 화면으로",func():_leave(false))
	_button(column,"게임 종료",func():_leave(true))
func _build_crew() -> void:
	crew_frame=_frame();var column:=_column(crew_frame)
	FrontierInterfaceStyle.label(column,"승무원",24)
	app.roster=FrontierInterfaceStyle.label(column,"",15)
	app.ready_button=_button(column,"준비",app.toggle_ready)
	app.pilot_choices=OptionButton.new();column.add_child(app.pilot_choices)
	var transfer:=_button(column,"조종 권한 전달",app.assign_pilot);transfer.name="TransferPilot"
	var kick:=_button(column,"선택 승무원 내보내기",app.kick_selected);kick.name="Kick"
	_button(column,"닫기  Esc",app.close_menus)
func _leave(quit_game: bool) -> void:
	if closing:return
	closing=true
	if await app.session.close_session():
		if quit_game:get_tree().quit()
		else:get_tree().change_scene_to_file("res://scenes/app/main.tscn")
	else:closing=false
func _map_mode() -> void:
	map_mode.text="항성계 보기" if app.chart.galaxy else "은하 보기"
	app.chart.queue_redraw()
func _layout() -> void:
	var view_size:=get_viewport().get_visible_rect().size
	if app.session.active and app.session.latest.get("phase")=="playing":
		app.navigation_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app.navigation_frame.offset_left=24;app.navigation_frame.offset_top=24;app.navigation_frame.offset_right=-24;app.navigation_frame.offset_bottom=-24
		app.panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
		app.panel.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	# Match the ground radar's top/right inset and diameter.
	mini.position=Vector2(view_size.x-208,26);mini.size=Vector2(180,180)
	for frame in [pause_frame,crew_frame]:
		frame.position=Vector2((view_size.x-320)/2,maxf(24,(view_size.y-390)/2));frame.size=Vector2(320,0)
	context.position=Vector2((view_size.x-context.size.x)/2,view_size.y*.66)
	message.position=Vector2(24,view_size.y-55);message.size.x=view_size.x-48

func refresh(value: Dictionary) -> void:
	_layout()
	var nav: Dictionary=value.crew.navigation
	for map in [app.chart,mini]:
		map.manifest=app.session.manifest;map.current_system=int(nav.system);map.elapsed=float(nav.get("orbit_time",0));map.ship_position=FrontierCrewWorld.vector(nav.position);map.ship_direction=FrontierCrewWorld.vector(nav.direction);map.journal=app.navigation_journal
		map.transit=nav.get("transit",{}) if nav.mode=="jump" else {};map.queue_redraw()
	mini.system_index=int(nav.system);mini.target=int(nav.target)
	mini.galaxy=nav.mode=="jump"
	if selected_preview<0:show_target(int(nav.target))
	var members: Dictionary=value.crew.members
	var lines: PackedStringArray=[]
	for id in members:
		lines.append(("✓  " if members[id].ready else "○  ")+members[id].profile.name+("  ◈ 조종" if id==value.crew.pilot_id else ""))
	app.roster.text="\n".join(lines)
	app.ready_button.visible=not app.session.offline
	app.ready_button.text="준비 취소" if members[value.self_id].ready else "준비 완료"
	if app.crew_ids!=members.keys():
		app.crew_ids=members.keys();app.pilot_choices.clear()
		for id in app.crew_ids:app.pilot_choices.add_item(members[id].profile.name)
	app.pilot_choices.visible=not app.session.offline
	for name_value in ["TransferPilot","Kick"]:
		var button: Button=crew_frame.find_child(name_value,true,false);button.visible=not app.session.offline;button.disabled=not app.session.hosting
	route.disabled=not value.crew.get("landing",{}).is_empty() or value.self_id!=value.crew.pilot_id or nav.mode!="idle" or pending_route>=0
	route.tooltip_text="지표에서는 우주선으로 돌아와 이륙하세요." if not value.crew.get("landing",{}).is_empty() else ("조종사만 항로를 설정할 수 있습니다." if value.self_id!=value.crew.pilot_id else "")

func show_target(ordinal: int) -> void:
	if ordinal<0 or app.session.manifest.is_empty():return
	if not app.chart.can_inspect_system(FrontierUniverse.system_index(app.session.manifest,ordinal)):return
	selected_preview=ordinal;app.selected_ordinal=ordinal
	var body:=FrontierUniverse.body(app.session.manifest,ordinal)
	app.chart.target=ordinal;app.chart.system_index=int(body.system_ordinal);app.chart.queue_redraw();_map_mode()
	target_name.text=body.name
	target_kind.text=FrontierUniverse.kind_label(body)+" · T%d"%int(body.planet_tier)
	if not FrontierUniverse.landable(body):target_kind.text+="\n"+FrontierUniverse.landing_restriction(body)
	refresh_survey()
	_update_preview(body)

func refresh_survey() -> void:
	if selected_preview<0 or app.session.manifest.is_empty():return
	var body:=FrontierUniverse.body(app.session.manifest,selected_preview)
	for child in resources.get_children():resources.remove_child(child);child.queue_free()
	var known: bool=(app.flight!=null and app.flight.scanned.has(body.id)) or body.get("origin","")=="solar_reference"
	var report:=FrontierOrbitalSurvey.report(body)
	survey.visible=known and report.available
	resources.visible=known and report.available
	survey_note.text="미조사" if not known else ""
	if not known or not report.available:return
	for id in report.resources.slice(0,4):
		var icon:=FrontierResourceIcons.view(id,32);icon.tooltip_text=FrontierCatalog.entry("resources",id).name;resources.add_child(icon)
	var environment: Dictionary=body.traits.duplicate();environment.ecology=0;environment.stable_seconds=0
	var scores:=FrontierEvaluator.scores(environment)
	survey_bars.water.value=report.water
	survey_bars.water.tooltip_text="수자원 %.0f%%"%report.water
	survey_bars.air.value=report.air
	survey_bars.air.tooltip_text="대기 적합 %.0f/100 · 기압 %.2f atm · 산소 %.1f%%"%[report.air,environment.pressure,float(environment.oxygen)*100]
	survey_bars.temperature.value=scores.temperature
	survey_bars.temperature.tooltip_text="기온 %.0f°C · 적합도 %.0f/100"%[environment.temperature,scores.temperature]
	if report.risk!="주의":survey_note.text="△ "+str(report.risk);survey_note.modulate=FrontierInterfaceStyle.WARNING
	else:survey_note.modulate=Color.WHITE

func _update_preview(body: Dictionary) -> void:
	if preview_key==body.id:return
	preview_key=body.id
	if is_instance_valid(preview_body):preview_body.queue_free()
	if body.get("origin","")=="solar_reference":
		preview_body=FrontierSolarPlanet.new();preview_root.add_child(preview_body);preview_body.configure(int(body.ordinal)-FrontierUniverse.first_ordinal(app.session.manifest,int(body.system_ordinal)),1.0)
	else:
		# Reuse the authored Blender mesh and the same planet material as the flight view.
		var template: Node3D=load("res://assets/models/planet-variants/"+str(body.traits.id)+".glb").instantiate()
		var mesh:=MeshInstance3D.new();mesh.mesh=template.find_children("*","MeshInstance3D",true,false)[0].mesh;template.free()
		var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/space/planet.gdshader")
		var t: Dictionary=body.traits
		material.set_shader_parameter("authored_relief",true);material.set_shader_parameter("highlight_strength",.08);material.set_shader_parameter("gas_bands",not FrontierUniverse.landable(body))
		material.set_shader_parameter("land_color",Color(t.dust));material.set_shader_parameter("sea_color",Color(t.sea));material.set_shader_parameter("rock_color",Color(t.rock));material.set_shader_parameter("sea_level",lerpf(.20,.61,float(t.water)/100.0) if float(t.water)>0 else 0.0);material.set_shader_parameter("cloud_amount",float(t.cloud));material.set_shader_parameter("seed_offset",float(t.pattern_seed));material.set_shader_parameter("molten",t.id=="volcanic")
		mesh.material_override=material;preview_body=mesh;preview_root.add_child(mesh)

func start_route(ordinal: int) -> void:
	if ordinal<0 or pending_route>=0:return
	pending_route=ordinal;pending_sequence=-1;pending_revision=-1
	if not app.session.send_request("navigate",{"ordinal":ordinal}):pending_route=-1
func _response(sequence: int,value: Dictionary) -> void:
	if not value.get("ok",false):_notice(str(value.get("error","실행할 수 없습니다.")))
	if sequence!=pending_sequence or pending_route<0:return
	if value.get("ok",false):pending_revision=int(value.revision)
	else:pending_route=-1;pending_sequence=-1;pending_revision=-1
func _notice(value: String) -> void:
	message.text=value;toast_left=4;message.show()

func _process(delta: float) -> void:
	toast_left=maxf(0,toast_left-delta);message.visible=toast_left>0
	var active: bool=app.session.active and app.session.latest.get("phase")=="playing"
	if active and pending_route>=0 and pending_revision>=0 and int(app.session.latest.crew.revision)>=pending_revision:
		var destination:=pending_route
		pending_route=-1;pending_sequence=-1;pending_revision=-1
		if int(app.session.latest.crew.navigation.target)==destination:app.travel_action("depart");app.close_menus()
	mini.visible=active and app.surface_world==null and not app.feedback.blocked() and not app.onboarding.letter.visible
	preview.render_target_update_mode=SubViewport.UPDATE_ALWAYS if app.navigation_frame.is_visible_in_tree() and active else SubViewport.UPDATE_DISABLED
	context.hide();context_kind=""
	if not active or not app._mouse_look_allowed():return
	_update_context()
	_layout()
func _update_context() -> void:
	var value: Dictionary=app.session.latest
	var nav: Dictionary=value.crew.navigation
	var own: Dictionary=value.crew.members[value.self_id]
	var pilot: bool=value.self_id==value.crew.pilot_id
	if not app.outside:
		for crate in value.crew.recovery.values():
			if app._crate_here(crate) and crate.area==own.area and FrontierCrewWorld.vector(crate.position).distance_to(FrontierCrewWorld.vector(own.position))<=float(FrontierCrewWorld.config().interaction_distance):
				context_kind="recover";context_ready=true;context.text="F  회수 화물 인수";context.disabled=false;context.reset_size();context.show();return
	if app.surface_world==null and not app.outside:
		if FrontierCrewWorld.vector(own.position).distance_to(FrontierCrewWorld.vector(FrontierCrewWorld.config().locker_position))<=float(FrontierCrewWorld.config().interaction_distance):
			context_kind="cargo";context_ready=true;context.text="F  공동 화물";context.disabled=false;context.reset_size();context.show()
		return
	if app.surface_world!=null:
		var position_value:=FrontierCrewWorld.vector(own.position)
		if position_value.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return
		var nearby_target:=app.surface_world.business_view.target(app.camera,app.actors[value.self_id])
		if not nearby_target.is_empty():return
		context_kind="launch";context_ordinal=-1
		context.text="F  착륙선 탑승"
	else:
		if nav.mode!="idle" or not app.outside:return
		var gazed: int=app.flight.pick_planet(Vector2(app.space_view.size)*.5) if app.flight!=null else -1
		var ordinal: int=gazed if gazed>=0 else int(nav.target)
		if FrontierUniverse.system_index(app.session.manifest,ordinal)!=int(nav.system):return
		var body:=FrontierUniverse.body(app.session.manifest,ordinal)
		var gap: float=FrontierCrewWorld.vector(nav.position).distance_to(FrontierCrewNavigation.center(ordinal,app.session.manifest,float(nav.get("orbit_time",0))))-FrontierUniverse.navigation_radius(body)
		var limit: float=float(app.session.manifest.settings.flight.arrival_clearance)+3
		# Keep a selected near target stable as it crosses the exact action boundary.
		var retained: bool=context_ordinal==ordinal and context_distance<=limit+80
		context_ordinal=ordinal;context_distance=gap
		if gap>limit+(80 if retained else 0):return
		context_kind="land";context_ready=gap<=limit and FrontierUniverse.landable(body)
		context.text=body.name+"  ·  "+("F  착륙" if pilot else "F  착륙 준비")
		if not FrontierUniverse.landable(body):context.text=body.name+" · "+FrontierUniverse.landing_restriction(body)
		elif gap>limit:context.text=body.name+" · 조금 더 접근하세요"
	if context_kind=="launch":context_ready=true
	if not app.session.offline:
		var ready_count:=0;var connected_count:=0
		for member in value.crew.members.values():
			if member.get("connected",true):
				connected_count+=1
				if member.ready:ready_count+=1
		context.text+="  ·  준비 %d/%d"%[ready_count,connected_count]
		if pilot and not own.ready:context.text+="  [P]"
	context.disabled=not context_ready;context.reset_size();context.show()
func interact() -> bool:
	if context_kind.is_empty() or not context.visible:return false
	if not app._mouse_look_allowed():return false
	if not context_ready:return true
	if context_kind=="recover":app.recover_nearby();return true
	if context_kind=="cargo":app.toggle_inventory();app.inventory_panel.tabs.current_tab=2;return true
	if context_kind=="launch":
		app.station_action("launch");return true
	var value: Dictionary=app.session.latest
	if value.self_id!=value.crew.pilot_id:app.toggle_ready();return true
	if app.session.offline:app.session.send_request("ready",{"value":true})
	app.session.send_request(context_kind,{"ordinal":context_ordinal} if context_kind=="land" else {})
	return true

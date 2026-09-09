class_name FrontierCrewStations
extends Node
## Render/collision stations follow the main ship. FINCH never gains these facilities.
var app: FrontierCrewExpedition
var definitions: Dictionary
var cabin: Node3D
var surface: Node3D
var surface_body: String=""
var panel: PanelContainer
var augmentation: FrontierAugmentationPanel
var research: FrontierExpeditionResearchPanel
var title: Label
var augmentation_tabs: TabContainer
var research_tabs: TabContainer
var ecology_holder: HBoxContainer
var hint: Label
var selected: String=""
var hovered: String=""
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_stations.json")).stations
	cabin=build_set(app.cabin_root,false)
	var ui: Control=app.navigation_frame.get_parent()
	panel=PanelContainer.new();ui.add_child(panel);panel.theme=FrontierInterfaceStyle.theme()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.offset_left=40;panel.offset_right=-40;panel.offset_top=40;panel.offset_bottom=-90
	panel.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	var column:=VBoxContainer.new();panel.add_child(column)
	var header:=HBoxContainer.new();column.add_child(header);title=FrontierInterfaceStyle.label(header,"",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close:=Button.new();close.text="닫기  Esc";header.add_child(close);close.pressed.connect(panel.hide)
	research_tabs=TabContainer.new();research_tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;research_tabs.use_hidden_tabs_for_min_size=false;column.add_child(research_tabs)
	research=FrontierExpeditionResearchPanel.new();research_tabs.add_child(research);research.configure(app);research.name="표본 분석"
	var shared:=FrontierProgressionResearchPanel.new();research_tabs.add_child(shared);shared.configure(app,true)
	ecology_holder=HBoxContainer.new();ecology_holder.name="생태 작업";research_tabs.add_child(ecology_holder)
	augmentation_tabs=TabContainer.new();augmentation_tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;augmentation_tabs.use_hidden_tabs_for_min_size=false;column.add_child(augmentation_tabs)
	augmentation=FrontierAugmentationPanel.new();augmentation_tabs.add_child(augmentation);augmentation.configure(app);augmentation.name="신체 증강"
	var equipment:=FrontierEquipmentWorkshop.new();augmentation_tabs.add_child(equipment);equipment.configure(app)
	var personal:=FrontierProgressionResearchPanel.new();augmentation_tabs.add_child(personal);personal.configure(app)
	var transport:=FrontierRoverWorkshop.new();augmentation_tabs.add_child(transport);transport.configure(app)
	panel.hide()
	hint=FrontierInterfaceStyle.label(ui,"",16);hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_stylebox_override("normal",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,8));hint.hide()
func build_set(parent: Node3D,outdoors: bool,terrain: FrontierTerrainStreamer=null) -> Node3D:
	var group:=Node3D.new();group.name="ShipStations";parent.add_child(group)
	for key in definitions:
		var d: Dictionary=definitions[key];var node:=FrontierCrewStation.new();group.add_child(node);node.configure(key,d)
		node.position=FrontierCrewWorld.vector(d.surface_offset if outdoors else d.cabin_position)
		if outdoors:
			node.position+=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
			node.position.y=terrain.field.height(node.position.x,node.position.z)
		node.rotation.y=deg_to_rad(float(d.surface_yaw if outdoors else d.cabin_yaw))
	return group
func _process(delta: float) -> void:
	if app.session.latest.is_empty():hint.hide();panel.hide();return
	if app.session.hosting:
		app.session.authority.augmentation_station_provider=resolve
		app.session.authority.research_station_provider=resolve
	sync_spaces()
	var local:=local_set()
	hovered=target() if not app.any_menu_open() and not app.outside and not app.arrival.active else ""
	hint.visible=not hovered.is_empty()
	if hint.visible:
		app.field_hud.context.hide();app.navigation_ui.context.hide()
		hint.text="F  "+str(definitions[hovered].name)
		var width:=get_viewport().get_visible_rect().size.x
		hint.position=Vector2(width*.5-150,get_viewport().get_visible_rect().size.y*.66);hint.size=Vector2(300,40)
	for group in [cabin,surface]:
		if not is_instance_valid(group):continue
		for node in group.get_children():
			node.present(delta,group==local and (node.kind==hovered or (panel.visible and node.kind==selected)))
			if node.kind=="research":
				node.load_gem(research.selected if group==local and panel.visible and selected=="research" and (research.loaded or research.phase=="success") else "")
				continue
			var showing: bool=group==local and panel.visible and selected=="augmentation"
			node.load_gem(augmentation.body.preview.gem_id if showing else "")
			if showing:
				node.scan.position=augmentation.body.preview.station.scan.position
				node.tray.position=augmentation.body.preview.station.tray.position
	if panel.visible:
		if selected=="research" and app.surface_panel.at_station:
			if app.session.surface.is_empty() or app.session.latest.crew.get("landing",{}).is_empty():app.surface_panel.hide()
			else:app.surface_panel.refresh(work_reason("research").is_empty())
		if local==null or not is_instance_valid(local.get_node_or_null("Station_"+selected)) or not within(local.get_node("Station_"+selected)):panel.hide();return
func sync_spaces() -> void:
	var snapshot: Dictionary=app.session.latest
	var cabin_parent: Node3D=app.cabin_root
	if app.session.hosting and app.spaces.spaces.has("cabin"):cabin_parent=app.spaces.spaces.cabin.root
	if not is_instance_valid(cabin):cabin=build_set(cabin_parent,false)
	elif cabin.get_parent()!=cabin_parent:cabin.reparent(cabin_parent,false)
	cabin.visible=snapshot.get("local_shuttle","").is_empty() or cabin_parent!=app.cabin_root
	# Ship devices stay aboard; do not duplicate buildings on unexplored ground.
	if is_instance_valid(surface):surface.queue_free();surface=null
func local_set() -> Node3D:
	if not app.session.latest.get("local_shuttle","").is_empty():return null
	if app.surface_world!=null:return cabin
	return cabin if app.cabin_root.is_visible_in_tree() else null
func within(node: FrontierCrewStation) -> bool:
	var actor: String=app.session.latest.self_id
	return app.actors.has(actor) and app.actors[actor].position.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position) if app.surface_world!=null else node.interaction_point())<=(float(FrontierCrewSurface.config().boarding_distance) if app.surface_world!=null else float(FrontierCrewAugmentation.config().interaction_range))
func target() -> String:
	if app.surface_world!=null:return "" # Surface access is through the ship terminal.
	var group:=local_set()
	if group==null:return ""
	for node in group.get_children():
		if not within(node):continue
		var delta: Vector3=node.interaction_point()-app.camera.global_position
		if delta.normalized().dot(-app.camera.global_basis.z)<.90:continue
		var query:=PhysicsRayQueryParameters3D.create(app.camera.global_position,node.interaction_point());query.exclude=[app.actors[app.session.latest.self_id].get_rid()]
		var hit:=app.camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and not node.is_ancestor_of(hit.collider):continue
		return node.kind
	return ""
func interact() -> bool:
	var key:=target()
	if key.is_empty():return false
	open_device(key)
	return true
func resolve(actor: String,station_id: String) -> Dictionary:
	if station_id not in ["ship:augmentation","ship:research"] or not app.session.hosting:return {}
	var world: Dictionary=app.session.authority.world
	if not world.crew.members.has(actor) or FrontierShuttles.aboard(world,actor):return {}
	var group: Node3D=cabin
	var area: String=world.crew.members[actor].area
	if area=="surface":
		return {"ship_terminal":true,"enabled":true,"position":FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position),"area":"surface","body_id":world.crew.get("landing",{}).get("body_id","")}
	if not is_instance_valid(group) or group.is_queued_for_deletion() or not group.is_inside_tree():return {}
	var node: FrontierCrewStation=group.get_node_or_null("Station_augmentation" if station_id=="ship:augmentation" else "Station_research")
	if not is_instance_valid(node) or node.is_queued_for_deletion():return {}
	return {"enabled":true,"position":node.interaction_point(),"area":area,"body_id":surface_body if area=="surface" else ""}

func open_device(key: String,page: int=0) -> void:
	selected=key;app.open_menu(panel);title.text=definitions[key].name
	for container in [augmentation_tabs,research_tabs]:
		for i in range(1,container.get_tab_count()):container.set_tab_disabled(i,app.surface_world==null)
	if app.surface_world==null:page=0
	research_tabs.visible=key=="research";augmentation_tabs.visible=key=="augmentation"
	if key=="augmentation":augmentation_tabs.current_tab=page;augmentation.open()
	else:
		app.survey_journal.reparent(ecology_holder);app.surface_panel.at_station=true
		research_tabs.current_tab=page;research.open()
	app.feedback.audio.play("sfx_pickup_resource")
func navigate(key: String,page: int=0) -> void:
	var group:=local_set()
	if group!=null:
		var device: FrontierCrewStation=group.get_node_or_null("Station_"+key)
		if device!=null and within(device):open_device(key,page);return
	app.feedback.show_cue("착륙선 가까이에서 F  "+str(definitions[key].name))
func work_reason(key: String) -> String:
	var descriptor: Dictionary={}
	var group:=local_set()
	if group!=null:
		var device: FrontierCrewStation=group.get_node_or_null("Station_"+key)
		if device!=null:descriptor={"ship_terminal":true,"enabled":true,"position":FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position) if app.surface_world!=null else device.interaction_point(),"area":"surface" if app.surface_world!=null else "cabin","body_id":app.surface_world.body.id if app.surface_world!=null else ""}
	return FrontierUpgradeAccess.reason({"crew":app.session.latest.crew},app.session.latest.self_id,key,descriptor)

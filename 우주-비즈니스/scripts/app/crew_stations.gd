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
var preview: FrontierEquipmentPreview
var title: Label
var detail: Label
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
	var close:=Button.new();close.text="닫기 · Esc";header.add_child(close);close.pressed.connect(panel.hide)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(280,260);preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(preview)
	detail=FrontierInterfaceStyle.label(column,"",16);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	augmentation=FrontierAugmentationPanel.new();column.add_child(augmentation);augmentation.configure(app);augmentation.hide()
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
			if node.kind!="augmentation":continue
			var showing: bool=group==local and panel.visible and selected=="augmentation"
			node.load_gem(augmentation.body.preview.gem_id if showing else "")
			if showing:
				node.scan.position=augmentation.body.preview.station.scan.position
				node.tray.position=augmentation.body.preview.station.tray.position
	if panel.visible:
		if local==null or not is_instance_valid(local.get_node_or_null("Station_"+selected)) or not within(local.get_node("Station_"+selected)):panel.hide();return
		if selected=="research":detail.text="표본 계측 · 시제품 연구\n탐사 기록은 J에서 확인할 수 있습니다."
func sync_spaces() -> void:
	var snapshot: Dictionary=app.session.latest
	var cabin_parent: Node3D=app.cabin_root
	if app.session.hosting and app.spaces.spaces.has("cabin"):cabin_parent=app.spaces.spaces.cabin.root
	if not is_instance_valid(cabin):cabin=build_set(cabin_parent,false)
	elif cabin.get_parent()!=cabin_parent:cabin.reparent(cabin_parent,false)
	cabin.visible=snapshot.get("local_shuttle","").is_empty() or cabin_parent!=app.cabin_root
	var landing: Dictionary=app.session.authority.world.crew.get("landing",{}) if app.session.hosting else snapshot.get("main_landing",{})
	var body_id:=str(landing.get("body_id",""))
	var terrain: FrontierTerrainStreamer
	var parent: Node3D
	if not body_id.is_empty():
		if app.session.hosting:
			terrain=app.spaces.terrain_for_body(body_id);parent=app.spaces.root_for_body(body_id)
		elif app.surface_world!=null and snapshot.get("local_shuttle","").is_empty() and app.surface_world.body.id==body_id:
			terrain=app.surface_world.terrain;parent=app.surface_world
	if is_instance_valid(surface) and (surface_body!=body_id or terrain==null or surface.get_parent()!=parent):surface.queue_free();surface=null
	if terrain!=null and not is_instance_valid(surface):surface=build_set(parent,true,terrain);surface_body=body_id
func local_set() -> Node3D:
	if not app.session.latest.get("local_shuttle","").is_empty():return null
	if app.surface_world!=null:return surface if is_instance_valid(surface) and surface_body==app.surface_world.body.id else null
	return cabin if app.cabin_root.is_visible_in_tree() else null
func within(node: FrontierCrewStation) -> bool:
	var actor: String=app.session.latest.self_id
	return app.actors.has(actor) and app.actors[actor].position.distance_to(node.interaction_point())<=float(FrontierCrewAugmentation.config().interaction_range)
func target() -> String:
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
	selected=key;app.open_menu(panel);title.text=definitions[key].name
	preview.visible=key=="research";detail.visible=key=="research";augmentation.visible=key=="augmentation"
	if key=="augmentation":augmentation.open()
	else:
		preview.show_model(definitions[key].model)
		preview.camera.position.z=absf(preview.camera.position.z);preview.camera.look_at(Vector3.ZERO)
	app.feedback.audio.play("sfx_pickup_resource")
	return true
func resolve(actor: String,station_id: String) -> Dictionary:
	if station_id not in ["ship:augmentation","ship:research"] or not app.session.hosting:return {}
	var world: Dictionary=app.session.authority.world
	if not world.crew.members.has(actor) or FrontierShuttles.aboard(world,actor):return {}
	var group: Node3D=cabin
	var area: String=world.crew.members[actor].area
	if area=="surface":
		if not is_instance_valid(surface) or surface.is_queued_for_deletion() or surface_body!=world.crew.get("landing",{}).get("body_id",""):return {}
		group=surface
	if not is_instance_valid(group) or group.is_queued_for_deletion() or not group.is_inside_tree():return {}
	var node: FrontierCrewStation=group.get_node_or_null("Station_augmentation" if station_id=="ship:augmentation" else "Station_research")
	if not is_instance_valid(node) or node.is_queued_for_deletion():return {}
	return {"enabled":true,"position":node.interaction_point(),"area":area,"body_id":surface_body if area=="surface" else ""}

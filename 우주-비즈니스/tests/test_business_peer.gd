extends "res://tests/test_crew_surface_peer.gd"
var build_spot: Dictionary={}
func handle_command(command: Dictionary) -> void:
	match command.kind:
		"business_menu":app.toggle_business()
		"interact":app.interact_business()
		"begin_build":app.begin_placement(command.building)
		"click_build":
			var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;app._unhandled_input(event)
		"prepare_build":
			find_build_spot(command.building);build_spot["token"]=command.token
		"engineering_action":
			app.toggle_business() if not app.business_panel.visible else null
			var panel: FrontierBusinessPanel=app.business_panel
			for i in panel.research_project.item_count:
				if panel.research_project.get_item_metadata(i)==command.project:panel.research_project.select(i)
			panel.update_engineering()
			for i in panel.research_facility.item_count:
				if panel.research_facility.get_item_metadata(i)==command.building_id:panel.research_facility.select(i)
			var tabs: TabContainer=panel.research_detail.get_parent().get_parent();tabs.current_tab=3
			panel.get("research_"+command.stage+"_button").pressed.emit()
		"industry_ticks":
			if app.session.hosting:
				for i in mini(100,int(command.count)):FrontierExpeditionIndustry.tick(app.session.authority.world,1)
				app.session.authority.checkpoint();app.session._publish();app.session._publish_surface()
		"business_overview":
			app.business_panel.hide();app.test_camera_position=Vector3(-42,28,46)
			var direction: Vector3=(Vector3(-12,2,-8)-app.test_camera_position).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
		"reset_camera":app.test_camera_position=Vector3.ZERO
		_:super.handle_command(command)
func find_build_spot(kind: String) -> void:
	if not app.session.hosting:return
	var core:=app.session.authority;var owner: String=core.peers[1];var old: Vector3=FrontierCrewWorld.vector(core.world.crew.members[owner].position)
	for x in range(-36,17,7):
		for z in range(-32,25,7):
			var p:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(core.world),x,z,float(FrontierCatalog.entry("buildings",kind).radius))
			if not p.is_finite():continue
			var stand:=p+Vector3(0,0,4.5);stand.y=FrontierCrewSurface.field(core.world).height(stand.x,stand.z)
			core.update_position(1,stand)
			var reason:=FrontierExpeditionBusiness.placement(core.world,kind,p,core.peers)
			core.update_position(1,old)
			if reason.is_empty():build_spot={"kind":kind,"position":FrontierExpeditionBusiness.array(p),"stand":FrontierExpeditionBusiness.array(stand)};return
func status_value() -> Dictionary:
	var value:=super.status_value()
	value["business"]=app.session.surface.get("business",{})
	value["engineering"]=app.session.surface.get("engineering",{})
	value["research_detail"]=app.business_panel.research_detail.text
	value["build_spot"]=build_spot;value["placement_valid"]=app.placement_valid;value["placement_message"]=app.status.text
	value["business_menu"]=app.business_panel.visible
	if app.surface_world!=null and app.session.latest.has("self_id") and app.actors.has(app.session.latest.self_id):
		value["business_models"]=app.surface_world.business_view.nodes.keys()
		var positions: Dictionary={}
		for id in app.surface_world.business_view.nodes:positions[id]=FrontierExpeditionBusiness.array(app.surface_world.business_view.nodes[id].position)
		value["business_model_positions"]=positions
		value["business_target"]=app.surface_world.business_view.target(app.camera,app.actors[app.session.latest.self_id])
	return value

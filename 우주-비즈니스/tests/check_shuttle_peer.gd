extends "res://tests/test_crew_play_peer.gd"
func handle_command(command: Dictionary) -> void:
	match command.kind:
		"start":app.session.send_request("start_game",{})
		"menu":
			app.open_station(str(command.get("context","ship")),str(command.get("id","")))
			for i in app.business_panel.tabs.get_tab_count():
				if app.business_panel.tabs.get_tab_title(i)=="소형선":app.business_panel.tabs.current_tab=i
		"capture_scene":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+str(command.get("name","scene"))+".png")
		"close_menu":app.close_menus()
		"fixture_position":
			if not app.session.hosting:return
			var id:=str(command.get("id",app.session.latest.self_id))
			var point:=FrontierCrewWorld.vector(command.point)
			app.session.authority.world.crew.members[id].position=command.point
			if app.actors.has(id):app.actors[id].position=point;app.actors[id].velocity=Vector3.ZERO
		"look":app.yaw=float(command.get("yaw",0));app.pitch=float(command.get("pitch",0))
		"size":root.size=Vector2i(int(command.width),int(command.height));root.content_scale_size=root.size
func status_value() -> Dictionary:
	var value:=super.status_value()
	value["surface"]=app.surface_world.body.id if app.surface_world!=null else ""
	value["arrival"]=app.arrival.phase if app.arrival.active else ""
	value["positions"]={};value["parents"]={}
	for id in app.actors:
		value.positions[id]=FrontierExpeditionBusiness.array(app.actors[id].position)
		value.parents[id]=str(app.actors[id].get_parent().get_path())
	value["spaces"]=app.spaces.spaces.keys();value["menu"]=app.business_panel.visible
	return value

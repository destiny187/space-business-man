extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var world:=FrontierUniverse.new_world(61739);var m: Dictionary=world.manifest
	var view:=FrontierCrewFlightView.new();view.state={"manifest":m};root.add_child(view)
	var nav:=FrontierCrewNavigation.create(world);view.update_navigation(nav);view.set_process(false)
	# Inspection camera in the real flight renderer; keep the player's hull behind the camera.
	var offset:=float(FrontierUniverse.derive(int(m.seed),"space_y_freight_phase")%20)+75
	for pair in [[.028,"freighter-unload"],[.053,"freighter-empty"],[.077,"freighter-load"],[.12,"freighter-departure-detail"],[.43,"freighter-cruise"],[.91,"freighter-approach-wait"],[.98,"freighter-dock"]]:
		var t:=600+float(pair[0])*600-offset;var row:=FrontierSpaceTraffic.sample(m,0,t)
		var point: Vector3=row.position+Vector3(190,180,-240)
		nav.orbit_time=t;nav.position=FrontierExpeditionBusiness.array(point+Vector3(0,100,500));nav.direction=[0,0,-1]
		view.update_navigation(nav);view.ship.position=FrontierCrewWorld.vector(nav.position)
		view.camera.global_position=point;view.camera.look_at(row.position);view.scan_enabled=true;view.presentation_blocked=false
		view.traffic.update(1,t,false);view.transit_overlay.hide()
		await create_timer(.25).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/production/media/corporate-space/"+pair[1]+".png"))
	view.queue_free();await process_frame;quit()

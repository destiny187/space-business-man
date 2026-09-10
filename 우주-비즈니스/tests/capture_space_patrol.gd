extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var world:=FrontierUniverse.new_world(61739);var m: Dictionary=world.manifest
	var view:=FrontierCrewFlightView.new();view.state={"manifest":m};root.add_child(view)
	var nav:=FrontierCrewNavigation.create(world);view.update_navigation(nav);view.set_process(false);view.transit_overlay.hide()
	var t:=45.0;var rows:=FrontierSpaceTraffic.all(m,0,t)
	var a: Vector3=rows[4].position;var b: Vector3=rows[5].position;var midpoint: Vector3=(a+b)*.5
	var f:=FrontierSpacePatrol.frame(m,"solar_mars_port",t)
	var point: Vector3=midpoint+f.radial*420+f.tangent*230+Vector3.UP*330
	nav.orbit_time=t;nav.position=FrontierExpeditionBusiness.array(point+Vector3(0,100,500));view.update_navigation(nav);view.ship.position=FrontierCrewWorld.vector(nav.position)
	view.camera.global_position=point;view.camera.look_at(midpoint);view.scan_enabled=true
	view.traffic.update(1,t,false)
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/production/media/corporate-space/fighter-formation.png"))
	view.queue_free();await process_frame;quit()

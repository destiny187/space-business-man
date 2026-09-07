extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1000,800)
	var m:=FrontierUniverse.generate(61739)
	var samples: Dictionary={}
	for i in 160:
		var system:=FrontierUniverse.system(m,i)
		samples[FrontierStarVisual.appearance(system).id]=i
	assert(samples.size()==4)
	assert(FrontierStarVisual.appearance(FrontierUniverse.system(m,0)).id=="yellow")
	var view:=FrontierCrewFlightView.new();view.state={"manifest":m};root.add_child(view);view.set_process(false);view.ship.hide();view.transit_overlay.hide()
	var out:=ProjectSettings.globalize_path("res://../docs/production/media/star-variants");DirAccess.make_dir_recursive_absolute(out)
	for family in ["yellow","red","blue","active"]:
		var index: int=samples[family];view.orbit_time=0;view._load_system(index)
		for entry in view.planets.values():entry.node.hide()
		view.landmarks.hide()
		for mesh in view.system_art.find_children("*","MeshInstance3D",true,false):assert(not mesh.mesh is ImmediateMesh)
		var first:=FrontierUniverse.first_ordinal(m,index)
		var previous: Vector3=view.planets[first].node.position;view.update_orbits(30)
		assert(previous.distance_to(view.planets[first].node.position)>.1)
		var radius: float=FrontierUniverse.system_layout(m,index).star_radius
		view.camera.global_position=Vector3(0,radius*.2,radius*4.7);view.camera.look_at(Vector3.ZERO)
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/"+family+".png")
	print("STAR PASS: four families, solar profile, orbit lines absent, orbital motion retained; Forward+ renders")
	view.queue_free();await process_frame;quit()

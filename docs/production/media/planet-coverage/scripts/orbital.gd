extends SceneTree
var failed:=false
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failed=true
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var m:=FrontierUniverse.generate(91723)
	var samples: Dictionary={};var colors: Dictionary={};var mixed:=false
	for i in range(8,180):
		var body:=FrontierUniverse.body(m,i)
		samples[body.traits.id]=body;colors[body.traits.dust]=true
		if not body.mineral_profile.is_empty() and "+" in body.mineral_profile.name:mixed=true
	check(samples.size()==15 and colors.size()>50,"15 archetypes and seeded palettes")
	check(mixed,"mixed geological profiles")
	check(FrontierUniverse.fingerprint(FrontierUniverse.body(JSON.parse_string(JSON.stringify(m)),19))==FrontierUniverse.fingerprint(FrontierUniverse.body(m,19)),"save/load reproduces traits and resource rules")
	# Render the exact flight loader's meshes/materials, arranged for comparison.
	root.size=Vector2i(1440,960)
	var view:=FrontierCrewFlightView.new();view.state={"manifest":m};root.add_child(view)
	view.ship.hide();view.ui_root.hide();view.transit_overlay.hide()
	var board:=Node3D.new();view.add_child(board)
	var ids: Array=FrontierPlanetTraits.rules().archetypes.keys()
	for index in ids.size():
		var b: Dictionary=samples[ids[index]]
		view._load_system(int(b.system_ordinal))
		var node: Node3D=view.planets[int(b.ordinal)].node
		view.planets.erase(int(b.ordinal));node.reparent(board)
		node.position=Vector3((index/3-2)*2.5,(1-index%3)*2.55,0);node.scale=Vector3.ONE*.94
		node.get_node("OrbitalLOD").set_process(false)
	for entry in view.planets.values():entry.node.hide()
	view.system_art.hide()
	if view.galactic_core!=null:view.galactic_core.hide()
	var camera:=Camera3D.new();view.add_child(camera);camera.position=Vector3(0,0,20);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13.2;camera.current=true
	await process_frame
	for i in 12:await process_frame
	var out:=ProjectSettings.globalize_path("res://../docs/production/media/planet-coverage")
	DirAccess.make_dir_recursive_absolute(out)
	root.get_texture().get_image().save_png(out+"/orbital-near.png")
	for node in board.get_children():
		var lod=node.get_node("OrbitalLOD")
		node.mesh=lod.far_mesh;lod.shell.mesh=lod.far_mesh
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/orbital-far.png")
	print("PASS rendered flight variants")
	view.queue_free();await process_frame;quit()

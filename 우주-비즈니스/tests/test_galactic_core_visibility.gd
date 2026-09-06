extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures+=1
func run() -> void:
	var manifest:=FrontierUniverse.generate(71491)
	var core:=FrontierUniverse.central_body(manifest)
	check(Vector3(core.galaxy_position[0],core.galaxy_position[1],core.galaxy_position[2])==Vector3.ZERO and not core.landable,"Single central black hole at galaxy origin")
	for index in [0,12500,40000,75000]:check(not FrontierUniverse.central_view(manifest,index).visible,"Outer/mid system has no visible core: "+str(index))
	var view:=FrontierUniverse.central_view(manifest,124999)
	check(view.visible and view.distance_galaxy_units<=180,"Inner system can see core")
	check(view.id==core.id,"Same celestial entity across local frames")
	var moved:=FrontierUniverse.central_view(manifest,124999,Vector3(10000,0,20000))
	check(moved.direction!=view.direction and moved.id==view.id,"Parallax responds to local position without moving the celestial center")
	root.size=Vector2i(1280,800)
	var flight:=FrontierCrewFlightView.new();flight.state={"manifest":manifest};root.add_child(flight)
	await process_frame
	flight._update_galactic_core()
	check(flight.galactic_core==null,"Earth flight does not even instantiate the black hole")
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/mineral-galaxy")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/outer-flight-no-core.png")
	flight._load_system(124999);flight._update_galactic_core()
	check(flight.galactic_core!=null and flight.galactic_core.visible,"Inner flight instantiates actual core GLB")
	flight.camera.look_at(flight.galactic_core.global_position,Vector3.UP)
	flight._update_galactic_core()
	await create_timer(.6).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/inner-flight-core.png")
	flight._load_system(0);flight._update_galactic_core()
	check(flight.galactic_core==null,"Returning to outer system removes the rendered core")
	var result={"failed":failures,"outer_hidden":true,"central_entity_id":core.id,"inner_distance_galaxy_units":view.distance_galaxy_units,"renderer":RenderingServer.get_current_rendering_method()}
	var output:=FileAccess.open(folder+"/core-visibility.json",FileAccess.WRITE);output.store_string(JSON.stringify(result,"\t"));output.close()
	quit(0 if failures==0 else 1)

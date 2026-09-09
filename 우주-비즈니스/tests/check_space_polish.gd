extends SceneTree
var view: FrontierCrewFlightView
var out: String
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
	out=ProjectSettings.globalize_path("res://../docs/production/media/space-polish-v2")
	DirAccess.make_dir_recursive_absolute(out)
	var manifest:=FrontierUniverse.generate(61739)
	view=FrontierCrewFlightView.new();view.state={"manifest":manifest};root.add_child(view)
	var earth:=FrontierUniverse.position(manifest,2)
	var toward_sun:=(-earth).normalized()
	var point:=earth+toward_sun*1000+Vector3.UP*260
	var facing: Vector3=(earth-point).normalized()
	var nav: Dictionary={"system":0,"target":2,"position":[point.x,point.y,point.z],"direction":[facing.x,facing.y,facing.z],"speed":0.0,"mode":"idle","orbit_time":0.0}
	view.update_navigation(nav);view.exterior=true;view.scan_enabled=false;view.transit_overlay.hide()
	await create_timer(1.2).timeout
	view.set_process(false)
	view.orbital_presentation.update(1,0)
	await capture("earth-day")
	view.ship.global_position=earth+(-toward_sun+Vector3.UP*.22).normalized()*1000
	view.ship.look_at(earth);view.orbital_presentation.update(1,0)
	await capture("earth-night")
	view.ship.global_position=earth+(toward_sun.cross(Vector3.UP)+toward_sun*.2+Vector3.UP*.2).normalized()*1000
	view.ship.look_at(earth);view.orbital_presentation.update(1,0)
	await capture("earth-limb")
	var saturn:=FrontierUniverse.position(manifest,5)
	view.ship.global_position=saturn+Vector3(0,1900,3600);view.ship.look_at(saturn);view.orbital_presentation.update(1,0)
	await capture("saturn-rings")
	print("SPACE POLISH: four actual flight renders completed")
	view.queue_free();await process_frame;quit()
func capture(id: String) -> void:
	await create_timer(.35).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+id+".png")

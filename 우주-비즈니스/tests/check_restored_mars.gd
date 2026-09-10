extends SceneTree
var failures:=0
var folder:=ProjectSettings.globalize_path("res://../docs/production/media/corporate-space")
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func capture(name_value: String) -> void:
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func run() -> void:
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(folder)
	var world:=FrontierUniverse.new_world(61739)
	var old: Dictionary=world.duplicate(true);old.manifest.settings.erase("corporate_space");old.manifest_hash=FrontierUniverse.fingerprint(old.manifest)
	var mars:=FrontierUniverse.body(world.manifest,3);var original:=FrontierUniverse.body(old.manifest,3)
	check(FrontierUniverse.restored_mars(mars) and not FrontierUniverse.restored_mars(original),"new restored / legacy Mars branch")
	check(mars.id==original.id and mars.orbit==original.orbit and mars.astro==original.astro,"reference address and planetary cycles unchanged")
	check(not FrontierUniverse.landable(mars) and FrontierUniverse.landing_restriction(mars).contains("Space Y"),"managed territory surface restriction")
	check(FrontierUniverse.validate_world(world).is_empty() and FrontierUniverse.validate_world(old).is_empty(),"new and old save format")
	check(not world.has("business") and not world.has("terraforming"),"no player restoration award")
	for pair in [{"world":world,"name":"mars-restored"},{"world":old,"name":"mars-legacy"}]:
		var view:=FrontierCrewFlightView.new();view.state={"manifest":pair.world.manifest};root.add_child(view)
		var nav:=FrontierCrewNavigation.create(pair.world)
		var target:=FrontierUniverse.position(pair.world.manifest,3)
		var body:=FrontierUniverse.body(pair.world.manifest,3);var radius:=FrontierUniverse.radius(body)
		# Review the lit hemisphere in the actual flight renderer; no orbital fixture changes.
		var offset: Vector3=(-target.normalized()+Vector3(0,.26,0)).normalized()
		var point:=target+offset*radius*3.1
		nav.target=3;nav.position=FrontierExpeditionBusiness.array(point);nav.direction=FrontierExpeditionBusiness.array((target-point).normalized())
		view.update_navigation(nav);view.exterior=false
		await create_timer(2.4).timeout
		var model: FrontierSolarPlanet=view.planets[3].node
		check(model.detail.visible and not model.distant.visible,"near LOD "+pair.name)
		check(view.transit_overlay.scan_progress>=1 and view.transit_overlay.scan_body.get("ordinal",-1)==3,"actual gaze scan "+pair.name)
		await capture(pair.name+"-scan")
		view.scan_enabled=false;view.transit_overlay.scan_body={}
		await capture(pair.name+"-near")
		if pair.name=="mars-restored":
			point=target+offset*radius*13.0;nav.position=FrontierExpeditionBusiness.array(point);view.update_navigation(nav)
			await create_timer(.5).timeout
			check(model.distant.visible and not model.detail.visible,"far LOD switch")
			await capture("mars-restored-far")
		view.queue_free();await process_frame
	print("RESTORED MARS failures=",failures);quit(1 if failures else 0)

extends "res://tests/check_facility_interactions.gd"
## Focused regression: real build/demolition must not empty cosmetic terrain tiles.
class MemoryWorldStore extends FrontierWorldStore:
	var snapshot: Dictionary={}
	func write(value: Dictionary) -> bool:
		last_error=FrontierUniverse.validate_world(value)
		if not last_error.is_empty():return false
		snapshot=value.duplicate(true);return true
	func read_state() -> Dictionary:
		return snapshot.duplicate(true)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	# Optional isolation when reviewing rendering independently of save migrations.
	if "--memory-world" in OS.get_cmdline_user_args():app.world_store=MemoryWorldStore.new()
	if not app.world_store.write(FrontierUniverse.new_world(71491)):
		check(false,"fixture world: "+app.world_store.last_error);quit(1);return
	app.start_solo()
	if not await until(func():return app.session.active,20):check(false,"session: "+app.status.value);quit(1);return
	app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.navigation_radius(body)+30)
	nav.position=FrontierExpeditionBusiness.array(point);nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,120):quit(1);return
	app.close_menus();app.session.send_request("business_register",{})
	var details:=app.surface_world.surface_details
	var owner: String=app.session.latest.self_id
	# A tile corner exercises footprints that cross four tile boundaries.
	point=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,-24,-24,2.4)
	if not point.is_finite():check(false,"fixture ground");quit(1);return
	move_to(point+Vector3(0,.2,6));app.test_camera_position=point+Vector3(0,3.1,7)
	app.camera.position=app.test_camera_position;app.camera.look_at(point)
	app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
	app.session.authority.world.business.bags[owner]=FrontierExpeditionBusiness.inventory()
	FrontierExpeditionBusiness.transfer(app.session.authority.world.business.bags[owner],FrontierCatalog.entry("buildings","solar").cost,1)
	await create_timer(.5).timeout
	check(await until(func():return details.presentation_ready() and details.tiles.size()>=9,30),"initial detail coverage ready")
	var before:=tile_ids(details)
	var original_keys: Array=before.keys()
	var original:=rows_by_id(details,original_keys)
	await capture("before")
	app.session.send_request("business_build",{"building":"solar","position":FrontierExpeditionBusiness.array(point)})
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.buildings.size()==1,"host accepts solar construction")
	if site.buildings.is_empty():quit(1);return
	var building_id: String=site.buildings.keys()[0]
	details.accept(app.session.authority.world.business)
	var affected: Dictionary=details.dirty_tiles.duplicate()
	check(affected.size()>0 and affected.size()<before.size(),"only footprint tiles scheduled")
	check(affected.has(Vector2i(-2,-2)) and affected.has(Vector2i(-1,-1)),"footprint spans tile corner")
	await verify_refresh(details,before,affected,"build")
	var built:=rows_by_id(details,original_keys)
	check(built.size()<original.size(),"building removes actual footprint decoration")
	var stable:=true
	for id in built:
		if original.has(id) and built[id]!=original[id]:stable=false
	check(stable,"surviving decoration retains transform and tint")
	before=tile_ids(details)
	app.session.send_request("business_demolish",{"building_id":building_id})
	check(FrontierExpeditionBusiness.site(app.session.authority.world).buildings.is_empty(),"host accepts demolition")
	details.accept(app.session.authority.world.business);affected=details.dirty_tiles.duplicate()
	await verify_refresh(details,before,affected,"demolish")
	check(rows_by_id(details,original_keys)==original,"demolition restores seeded decoration")
	before=tile_ids(details)
	details.accept(app.session.authority.world.business)
	check(details.dirty_tiles.is_empty(),"unchanged snapshots do not schedule rebuilds")
	# The same replacement path also handles geometry invalidation without blanking.
	details.invalidate()
	check(not details.presentation_ready(),"readiness waits for invalidated geometry")
	await verify_refresh(details,before,before,"geometry")
	check(await until(func():return details.presentation_ready(),20),"readiness resumes after replacements and newly streamed tiles")
	check(await app.session.close_session(),"isolated visual session closes")
	print("DETAIL_CONSTRUCTION_FAILURES ",failures);quit(1 if failures else 0)

func tile_ids(details: FrontierSurfaceDetails) -> Dictionary:
	var result: Dictionary={}
	for key in details.tiles:result[key]=details.tiles[key].node.get_instance_id()
	return result

func rows_by_id(details: FrontierSurfaceDetails,keys: Array=[]) -> Dictionary:
	var result: Dictionary={}
	for key in (details.tiles.keys() if keys.is_empty() else keys):
		for row in details.candidates(key):result[row.id]=row
	return result

func verify_refresh(details: FrontierSurfaceDetails,before: Dictionary,affected: Dictionary,label: String) -> void:
	var covered:=true;var untouched:=true;var counts_ok:=true;var samples: Array=[]
	for frame in 90:
		await process_frame;await RenderingServer.frame_post_draw
		for key in before:
			if not details.tiles.has(key):covered=false
			elif not affected.has(key) and details.tiles[key].node.get_instance_id()!=before[key]:untouched=false
		var total:=0
		for row in details.tiles.values():total+=int(row.count)
		if details.instance_total!=total:counts_ok=false
		samples.append([frame,details.tiles.size(),details.instance_total,details.dirty_tiles.size()])
		if frame==0:root.get_texture().get_image().save_png(folder+"/"+label+"-first-frame.png")
		if not details.dirty and details.dirty_tiles.is_empty():break
	print("DETAIL_SAMPLES ",label," ",samples)
	check(covered,label+" keeps every visible tile during refresh")
	check(untouched,label+" keeps unrelated MultiMesh nodes")
	check(counts_ok,label+" instance count stays accurate")
	check(not details.dirty and details.dirty_tiles.is_empty(),label+" refresh completes")
	await capture(label+"-after")

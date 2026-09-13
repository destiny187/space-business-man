extends "res://tests/check_facility_interactions.gd"
## Focused regression: real build/demolition must not empty cosmetic terrain tiles.
class MemoryWorldStore extends FrontierWorldStore:
	var snapshot: Dictionary={}
	func _init(save_path: String) -> void:super(save_path)
	func write(value: Dictionary) -> bool:
		last_error=FrontierUniverse.validate_world(value)
		if not last_error.is_empty():return false
		snapshot=value.duplicate(true);return true
	func read_state() -> Dictionary:
		return snapshot.duplicate(true)
	# Request/checkpoint commits acquired a separate asynchronous entry point.
	# Keep every writer in memory; never inherit a default user save destination.
	func begin_commit(value: Dictionary) -> bool:return write(value)
	func begin_checkpoint(value: Dictionary) -> bool:return write(value)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	# Optional isolation when reviewing rendering independently of save migrations.
	if "--memory-world" in OS.get_cmdline_user_args():app.world_store=MemoryWorldStore.new(folder+"/memory-world.json")
	if not app.world_store.write(FrontierUniverse.new_world(71491)):
		check(false,"fixture world: "+app.world_store.last_error);quit(1);return
	app.start_solo()
	if not await until(func():return app.session.active,20):check(false,"session: "+app.status.value);quit(1);return
	if not await until(func():return app.session.latest.get("phase")=="playing" and not app.session.authority.autonomous_pending(),20):check(false,"start commit: "+app.status.value);quit(1);return
	app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	# The fixture enters an already approached orbit; skip the unrelated Sol shot.
	nav.erase("solar_opening")
	nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.navigation_radius(body)+30)
	nav.position=FrontierExpeditionBusiness.array(point);nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame
	app.session.send_request("ready",{"value":true})
	if not await until(func():return app.session.latest.crew.members[app.session.latest.self_id].ready,10):check(false,"ready commit: "+app.status.value);quit(1);return
	app.session.send_request("land",{})
	if not await until(func():return not app.session.authority.world.crew.get("landing",{}).is_empty(),10):check(false,"landing request: "+app.status.value);quit(1);return
	if not await until(func():return app.surface_world!=null and not app.arrival.active,120):check(false,"landing presentation: "+app.status.value);quit(1);return
	app.close_menus();app.session.send_request("business_register",{})
	if not await until(func():return not FrontierExpeditionBusiness.site(app.session.authority.world).is_empty(),10):check(false,"register commit");quit(1);return
	var details:=app.surface_world.surface_details
	var owner: String=app.session.latest.self_id
	# A tile corner exercises footprints that cross four tile boundaries.
	app.session.authority.world.business.bags[owner]=FrontierExpeditionBusiness.inventory()
	FrontierExpeditionBusiness.transfer(app.session.authority.world.business.bags[owner],FrontierFacilityResearch.construction("solar").cost,1)
	point=Vector3.INF
	var blocked_reason:=""
	var span: float=details.settings.tile_size
	var footprint: float=FrontierCatalog.entry("buildings","solar").radius+1.2
	# Find an actually buildable tile corner; a fixed coordinate can overlap
	# seeded mineral access paths and should not bypass the placement rules.
	for x in [-1,1,-2,2,-3,3]:
		for z in [-1,1,-2,2,-3,3]:
			var candidate:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x*span,z*span,2.4)
			if not candidate.is_finite():continue
			app.session.authority.update_position(1,candidate+Vector3(0,.2,6))
			blocked_reason=FrontierExpeditionBusiness.build_reason(app.session.authority.world,owner,"solar",candidate,app.session.authority.peers)
			if not blocked_reason.is_empty():continue
			var removable:=false
			for offset in [Vector2i.ZERO,Vector2i(-1,0),Vector2i(0,-1),Vector2i(-1,-1)]:
				for row in details.candidates(Vector2i(x,z)+offset):
					var origin: Vector3=row.transform.origin
					if absf(origin.y-candidate.y)<3 and Vector2(origin.x-candidate.x,origin.z-candidate.z).length()<footprint:removable=true
			if removable:point=candidate;break
		if point.is_finite():break
	if not point.is_finite():check(false,"fixture ground: "+blocked_reason);quit(1);return
	move_to(point+Vector3(0,.2,6));app.test_camera_position=point+Vector3(0,3.1,7)
	app.camera.position=app.test_camera_position;app.camera.look_at(point)
	app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
	# Refunds now require real warehouse capacity. Prepare one separate storage
	# fixture before the baseline so building/demolition only changes solar tiles.
	app.session.authority.resolve_autonomous(true)
	var fixture_site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	var storage_point:=point+Vector3(18,0,18);storage_point.y=app.surface_world.terrain.field.height(storage_point.x,storage_point.z)
	fixture_site.buildings["fixture-refund-storage"]={"id":"fixture-refund-storage","type":"storage","tier":1,"position":FrontierExpeditionBusiness.array(storage_point),"yaw":0.0,"enabled":true,"active":false,"status":"검수 준비","work":0.0,"region_id":FrontierRegionalTerraform.region_id(fixture_site,point)}
	app.session._publish();app.session._publish_surface()
	await create_timer(.5).timeout
	check(await until(func():return details.presentation_ready() and details.tiles.size()>=9,30),"initial detail coverage ready")
	var before:=tile_ids(details)
	var original_keys: Array=before.keys()
	var original:=rows_by_id(details,original_keys)
	await capture("before")
	# Finish any automatic checkpoint before injecting the bounded fixture stock;
	# an older pending draft would otherwise replace this direct test-only grant.
	app.session.authority.resolve_autonomous(true)
	app.session.authority.world.business.bags[owner]=FrontierExpeditionBusiness.inventory()
	FrontierExpeditionBusiness.transfer(app.session.authority.world.business.bags[owner],FrontierFacilityResearch.construction("solar").cost,1)
	app.session._publish()
	print("CONSTRUCTION_PREFLIGHT ",FrontierExpeditionBusiness.build_reason(app.session.authority.world,owner,"solar",point,app.session.authority.peers))
	app.session.response_received.connect(func(_seq: int,result: Dictionary):
		if not result.get("ok",false):print("REQUEST_REJECTED ",result))
	app.session.send_request("business_build",{"building":"solar","position":FrontierExpeditionBusiness.array(point)})
	await until(func():return FrontierExpeditionBusiness.site(app.session.authority.world).buildings.size()==2,10)
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	var solar_ids: Array=site.buildings.keys().filter(func(id: String)->bool:return site.buildings[id].type=="solar")
	check(solar_ids.size()==1,"host accepts solar construction: "+app.status.value)
	if solar_ids.size()!=1:quit(1);return
	var building_id: String=solar_ids[0]
	details.accept(app.session.authority.world.business)
	var affected: Dictionary=details.dirty_tiles.duplicate()
	# A durable asynchronous reply may arrive after a tile has already refreshed.
	for key in before:
		if details.tiles.has(key) and details.tiles[key].node.get_instance_id()!=before[key]:affected[key]=true
	check(affected.size()>0 and affected.size()<before.size(),"only footprint tiles scheduled")
	var corner:=Vector2i(floori(point.x/span),floori(point.z/span))
	check(affected.has(corner-Vector2i.ONE) and affected.has(corner),"footprint spans tile corner")
	await verify_refresh(details,before,affected,"build")
	var built:=rows_by_id(details,original_keys)
	check(built.size()<original.size(),"building removes actual footprint decoration")
	var stable:=true
	for id in built:
		if original.has(id) and built[id]!=original[id]:stable=false
	check(stable,"surviving decoration retains transform and tint")
	before=tile_ids(details)
	app.session.send_request("business_demolish",{"building_id":building_id})
	await until(func():return not FrontierExpeditionBusiness.site(app.session.authority.world).buildings.has(building_id),10)
	check(not FrontierExpeditionBusiness.site(app.session.authority.world).buildings.has(building_id),"host accepts demolition")
	details.accept(app.session.authority.world.business);affected=details.dirty_tiles.duplicate()
	for key in before:
		if details.tiles.has(key) and details.tiles[key].node.get_instance_id()!=before[key]:affected[key]=true
	await verify_refresh(details,before,affected,"demolish")
	check(rows_by_id(details,original_keys)==original,"demolition restores seeded decoration")
	before=tile_ids(details)
	details.accept(app.session.authority.world.business)
	check(details.dirty_tiles.is_empty(),"unchanged snapshots do not schedule rebuilds")
	if "--construction-only" in OS.get_cmdline_user_args():
		check(await app.session.close_session(),"isolated visual session closes")
		print("DETAIL_CONSTRUCTION_FAILURES ",failures);quit(1 if failures else 0);return
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
	var frame:=0;var deadline:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		await process_frame;await RenderingServer.frame_post_draw
		for key in before:
			if not details.tiles.has(key):covered=false
			elif not affected.has(key) and details.tiles[key].node.get_instance_id()!=before[key]:untouched=false
		var total:=0
		for row in details.tiles.values():total+=int(row.count)
		if details.instance_total!=total:counts_ok=false
		samples.append([frame,details.tiles.size(),details.instance_total,details.dirty_tiles.size()])
		if frame==0:root.get_texture().get_image().save_png(folder+"/"+label+"-first-frame.png")
		if details.presentation_ready():break
		frame+=1
	print("DETAIL_SAMPLES ",label," frames=",samples.size()," first=",samples.slice(0,4)," last=",samples.back() if not samples.is_empty() else [])
	check(covered,label+" keeps every visible tile during refresh")
	check(untouched,label+" keeps unrelated MultiMesh nodes")
	check(counts_ok,label+" instance count stays accurate")
	# Far tiles waiting for collision streaming are deliberately deferred. The
	# runtime readiness contract waits for every currently supported visible tile.
	check(details.presentation_ready(),label+" supported visible tiles finish refreshing")
	await capture(label+"-after")

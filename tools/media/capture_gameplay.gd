extends SceneTree
## Capture real crew_expedition play and its mixed audio using Godot Movie Maker.
## All persistence is redirected to a temporary copy via --crew-folder.
var app: FrontierCrewExpedition
var dest:=""
var preview:=false
var segments: Array=[]
var evidence: Dictionary={}
var start_frame:=0
var clip_name:=""
var owner:=""
var ore: Dictionary={}
var ore_point:=Vector3.ZERO
var native_fixture: Dictionary={}

func _initialize() -> void:run.call_deferred()

func until(condition: Callable,seconds: float=60) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while not condition.call() and Time.get_ticks_msec()<end:await process_frame
	return condition.call()

func move_before_clip(point: Vector3) -> void:
	app.actors[owner].position=point;app.session.authority.update_position(1,point);app.session._publish()

func aim(point: Vector3) -> void:
	app.camera.look_at(point);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x

func start_clip(label: String) -> void:
	clip_name=label;start_frame=Engine.get_process_frames();print("PLAY_CLIP_START ",label," ",start_frame)

func end_clip() -> void:
	var end:=Engine.get_process_frames()
	segments.append({"id":clip_name,"start_frame":start_frame,"end_frame":end,"fps":30})
	print("PLAY_CLIP_END ",clip_name," ",end)
	FileAccess.open(dest+"/segments.json",FileAccess.WRITE).store_string(JSON.stringify({"segments":segments,"evidence":evidence},"  "))

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dest+"/"+label+".png")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dest="):dest=arg.trim_prefix("--dest=")
		if arg=="--preview":preview=true
	assert("--crew-ui-test" in OS.get_cmdline_user_args())
	assert(not dest.is_empty());DirAccess.make_dir_recursive_absolute(dest)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_title("게임 플레이 촬영")
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	var saved:=fresh_world()
	if saved.is_empty():quit(1);return
	var body:=FrontierUniverse.body_from_id(saved.manifest,saved.location)
	var region: Dictionary=saved.get("celestial_regions",{}).get(body.id,{})
	var best_time:=float(saved.crew.navigation.orbit_time);var best_height:=-2.0
	for sample in range(0,20001,80):
		var sky:=FrontierPlanetaryCycles.sky_state(body,float(sample),region)
		if float(sky.sun_height)>best_height:best_height=float(sky.sun_height);best_time=float(sample)
	saved.crew.navigation.orbit_time=best_time
	if not app.world_store.write(saved):printerr("PLAY_SAVE_ERROR ",app.world_store.last_error);quit(1);return
	app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not app.preparing_first_snapshot and not has_meta("startup_loader"),90):printerr("PLAY_START_FAILED");quit(1);return
	owner=app.session.latest.self_id
	# Prepare starting stock only in the isolated filming session, before any clip.
	app.session.authority.world.business.bags[owner]={"iron":50,"copper":50,"stone":50,"ice":50,"crystal":50}
	app.session._publish()
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	FrontierClientSettings.ensure(self).values.music_volume=0.0
	app.outside=false;app.exterior_view.hide();app.if_flight_view();app.mouse_resume_guard=false
	# Use the normal game camera, HUD, world simulation, tool feedback and sound.
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),-80)
	app.session.response_received.connect(func(seq: int,result: Dictionary):
		if not result.get("ok",false):print("PLAY_REQUEST ",seq," ",result))
	await create_timer(.6).timeout
	var field:=app.surface_world.terrain.field
	var candidates:=FrontierExpeditionBusiness.veins(app.surface_world.body,Vector3.ZERO)
	for row in candidates:
		if row.resource!="iron":continue
		var p:=FrontierMineralWorld.point(field,row)
		if not p.is_finite() or Vector2(p.x,p.z).length()>85:continue
		var approach:=FrontierExpeditionBusiness.ground(field,p.x,p.z+13)
		if not approach.is_finite():continue
		ore=row;ore_point=p;move_before_clip(approach+Vector3.UP*.12);break
	if ore.is_empty():printerr("NO_REACHABLE_IRON");quit(1);return
	if not await until(func():return app.surface_world.ready_at(app.actors[owner].position) and app.surface_world.business_view.nodes.has(ore.id),60):printerr("ORE_NOT_STREAMED");quit(1);return
	app.session.send_request("equipment_select",{"slot":0});aim(ore_point+Vector3.UP*.65)
	await create_timer(.7).timeout;await still("approach-preview")
	if preview:await app.session.close_session();quit();return
	var remaining_before: int=FrontierExpeditionBusiness.site(app.session.authority.world).remaining.get(ore.id,ore.capacity)
	var iron_before: int=FrontierExpeditionBusiness.bag(app.session.authority.world,owner).get("iron",0)
	start_clip("walk_and_mine")
	for i in 330:
		var distance:=Vector2(app.actors[owner].position.x-ore_point.x,app.actors[owner].position.z-ore_point.z).length()
		app.test_direction=Vector2(0,-1) if distance>3.8 and i<115 else Vector2.ZERO
		aim(ore_point+Vector3.UP*.65)
		if i>115 and app.dig_timer<=0:app.use_equipped()
		await process_frame
	app.test_direction=Vector2.ZERO
	evidence["mining"]={"vein":ore.id,"before":remaining_before,"after":FrontierExpeditionBusiness.site(app.session.authority.world).remaining.get(ore.id,ore.capacity),"iron_before":iron_before,"iron_after":FrontierExpeditionBusiness.bag(app.session.authority.world,owner).get("iron",0)}
	end_clip();await still("mining-result")
	await build_clip()
	await creature_clip()
	await collect_and_return_clip()
	FileAccess.open(dest+"/segments.json",FileAccess.WRITE).store_string(JSON.stringify({"segments":segments,"evidence":evidence},"  "))
	await app.session.close_session();app.queue_free();await process_frame;print("GAMEPLAY_CAPTURE_COMPLETE");quit()

func build_clip() -> void:
	var field:=app.surface_world.terrain.field
	var p:=Vector3.INF
	for x in range(-24,25,8):
		if p.is_finite():break
		for z in range(-24,25,8):
			var candidate:=FrontierExpeditionBusiness.ground(field,x,z,2.2)
			if not candidate.is_finite():continue
			move_before_clip(candidate+Vector3(0,.1,5))
			var reason:=FrontierExpeditionBusiness.build_reason(app.session.authority.world,owner,"solar",candidate,app.session.authority.peers)
			if reason.is_empty():p=candidate;break
	if not p.is_finite():printerr("NO_BUILD_POSITION");return
	if not await until(func():return app.surface_world.ready_at(app.actors[owner].position) and app.surface_world.ready_at(p),60):return
	aim(p+Vector3.UP*.1);await create_timer(.6).timeout
	var count_before: int=FrontierExpeditionBusiness.site(app.session.authority.world).buildings.size()
	start_clip("place_and_inspect")
	for i in 255:
		if i==18:app.begin_placement("solar")
		if i>=18 and i<100:aim(p+Vector3(sin(float(i)*.06)*.6,.05,0))
		if i==105:
			if app.placement_valid:
				var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(640,400);app._unhandled_input(click)
			else:print("PLAY_PLACEMENT_INVALID ",app.placement_reason)
		if i>140:
			app.test_direction=Vector2(.32,0);aim(p+Vector3.UP*1.25)
		await process_frame
	app.test_direction=Vector2.ZERO
	evidence["building"]={"before":count_before,"after":FrontierExpeditionBusiness.site(app.session.authority.world).buildings.size()}
	end_clip();await still("placed-facility")

func creature_clip() -> void:
	var fixture: Dictionary=native_fixture
	var point:=FrontierCrewWorld.vector(fixture.encounter.point)
	var field:=app.surface_world.terrain.field
	var approach:=Vector3(point.x,field.height(point.x,point.z+8)+.15,point.z+8)
	move_before_clip(approach)
	if not await until(func():return app.surface_world.ready_at(app.actors[owner].position) and app.surface_world.ecology.actors.has(fixture.encounter.id),70):printerr("CREATURE_NOT_STREAMED");return
	var creature: Node3D=app.surface_world.ecology.actors[fixture.encounter.id]
	var height: float=(float(creature.definition.geometry.near.max[1])-float(creature.definition.geometry.near.floor_y))*creature.base_scale
	var center:=point+field.normal(point)*maxf(.35,height*.5)
	var key: String=app.surface_world.body.id+":"+creature.definition.id
	var known_before: bool=app.session.authority.world.ecology.observations.has(key)
	aim(center);await create_timer(.7).timeout
	start_clip("encounter_and_scan")
	for i in 285:
		var dist:=Vector2(app.actors[owner].position.x-creature.global_position.x,app.actors[owner].position.z-creature.global_position.z).length()
		app.test_direction=Vector2(0,-1) if dist>5.8 and i<100 else Vector2.ZERO
		aim(center)
		app.test_scan=i>=100 and i<225
		await process_frame
	app.test_scan=false;app.test_direction=Vector2.ZERO
	evidence["creature"]={"form":creature.definition.id,"position":FrontierExpeditionBusiness.array(creature.global_position),"known_before":known_before,"known_after":app.session.authority.world.ecology.observations.has(key)}
	end_clip();await still("creature-scan")

func collect_and_return_clip() -> void:
	var point:=FrontierCrewWorld.vector(native_fixture.encounter.point)
	var creature: Node3D=app.surface_world.ecology.actors[native_fixture.encounter.id]
	var field:=app.surface_world.terrain.field
	var height: float=(float(creature.definition.geometry.near.max[1])-float(creature.definition.geometry.near.floor_y))*creature.base_scale
	var center:=point+field.normal(point)*maxf(.35,height*.5)
	var ship:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	ship.y=field.height(ship.x,ship.z)
	var before: int=FrontierSpecimenItems.carried(FrontierExpeditionBusiness.bag(app.session.authority.world,owner)).size()
	var start_position: Vector3=app.actors[owner].position
	start_clip("collect_and_return")
	for i in 630:
		if i<90:
			var dist:=Vector2(app.actors[owner].position.x-point.x,app.actors[owner].position.z-point.z).length()
			app.test_direction=Vector2(0,-1) if dist>3.2 else Vector2.ZERO
			aim(center)
		if i==90:app.test_direction=Vector2.ZERO;app.surface_action("surface_collect")
		if i==165:
			app.open_menu(app.inventory_panel);app.inventory_panel.tabs.current_tab=0
		if i==180:
			for key in FrontierExpeditionBusiness.bag(app.session.authority.world,owner):
				if FrontierSpecimenItems.is_item(key):app.inventory_panel.selected_resource=key;app.inventory_panel.selected_item="";app.inventory_panel._refresh_details();app.inventory_panel._highlight();break
		if i==285:app.close_menus()
		if i>=285:
			app.camera.look_at(ship+Vector3.UP*3)
			app.yaw=lerp_angle(app.yaw,app.camera.rotation.y,.08);app.pitch=lerpf(app.pitch,app.camera.rotation.x,.08)
			var distance:=Vector2(app.actors[owner].position.x-ship.x,app.actors[owner].position.z-ship.z).length()
			app.test_direction=Vector2(0,-1) if i>=325 and distance>13 else Vector2.ZERO
		await process_frame
	app.test_direction=Vector2.ZERO
	evidence["sample"]={"before":before,"after":FrontierSpecimenItems.carried(FrontierExpeditionBusiness.bag(app.session.authority.world,owner)).size()}
	evidence["return"]={"from":FrontierExpeditionBusiness.array(start_position),"to":FrontierExpeditionBusiness.array(app.actors[owner].position)}
	end_clip();await still("return-to-ship")

func fresh_world() -> Dictionary:
	var character:=FrontierPlayerProfile.new_character("탐험가",2)
	app.profile.data={"version":1,"character":character,"sessions":{}};app.profile.save()
	var core:=FrontierCrewAuthority.new()
	if not core.start(FrontierUniverse.new_world(71491),character,func(_world):return true):printerr("FRESH_CORE ",core.error);return {}
	var world: Dictionary=core.world;var selected: Dictionary={}
	for ordinal in range(8,1400):
		var body:=FrontierUniverse.body(world.manifest,ordinal)
		if not FrontierUniverse.landable(body) or int(body.planet_tier)>2:continue
		var record:=FrontierEcology.ensure_planet(world.ecology,body)
		if record.profile.origin!="established":continue
		var field:=FrontierExplorationIncidents.field(body)
		for candidate in FrontierEcologyPlacement.candidates(body,record,Vector3(25,0,25)):
			var form:=FrontierEcologyCatalog.form(candidate.form_id)
			if form.category!="animal" or candidate.layer!="surface" or "/biota/" in str(form.lods.near.path):continue
			var point:=FrontierEcologyPlacement.ground(field,candidate)
			if not point.is_finite() or FrontierEcology.status(record,form,point,"surface")!="active":continue
			candidate.point=FrontierExpeditionBusiness.array(point);native_fixture={"ordinal":ordinal,"encounter":candidate};selected=body;break
		if not selected.is_empty():break
	if selected.is_empty():printerr("NO_NATIVE_FILM_LOCATION");return {}
	world.crew.phase="playing"
	if world.crew.navigation.has("solar_opening"):world.crew.navigation.solar_opening.elapsed=world.crew.navigation.solar_opening.duration
	var nav: Dictionary=world.crew.navigation
	nav.system=selected.system_ordinal;nav.target=selected.ordinal;nav.mode="idle";nav.speed=0.0
	nav.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(int(selected.ordinal),world.manifest,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(selected)+1))
	world.location=selected.id;world.navigation_target=selected.id;world.crew.members[character.character_id].ready=true
	var reason:=FrontierCrewSurface.apply(world,character.character_id,"land",{},{1:character.character_id})
	if not reason.is_empty():printerr("FRESH_LAND ",reason);return {}
	FileAccess.open(dest+"/fixture.json",FileAccess.WRITE).store_string(JSON.stringify(native_fixture,"  "))
	print("FRESH_LOCATION ",selected.ordinal," ",native_fixture.encounter.form_id)
	return world

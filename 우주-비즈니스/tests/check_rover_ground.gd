extends "res://tests/check_facility_interactions.gd"
var rover_id:=""
func request(kind: String,args: Dictionary={},peer: int=1) -> Dictionary:
	var a:=app.session.authority;var id: String=a.peers[peer]
	var result:=a.request(peer,{"session_id":a.session_id,"sequence":int(a.world.crew.members[id].last_sequence)+1,"revision":a.world.crew.revision,"kind":kind,"args":args})
	app.session.latest=a.snapshot(1);app.session.snapshot_received.emit(app.session.latest)
	if not result.ok and kind!="business_build":print("REJECT ",kind," ",result," STORE ",app.world_store.last_error)
	return result
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	if not "--rover-resume" in OS.get_cmdline_user_args():app.world_store.write(FrontierUniverse.new_world(71491))
	app.start_solo()
	if not await until(func():return app.session.active,15):check(false,"session");quit(1);return
	app.onboarding.letter.hide()
	if "--rover-resume" not in OS.get_cmdline_user_args():
		var world: Dictionary=app.session.authority.world;var ordinal:=FrontierCrewNavigation.first_destination(world.manifest);var body:=FrontierUniverse.body(world.manifest,ordinal);var nav: Dictionary=world.crew.navigation
		nav.system=FrontierUniverse.system_index(world.manifest,ordinal);nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
		var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
		nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
		app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):check(false,"landing");quit(1);return
	app.close_menus()
	var world: Dictionary=app.session.authority.world;var owner_id: String=world.crew.owner_id
	if "--rover-resume" not in OS.get_cmdline_user_args():
		move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
		check(request("business_register").ok,"register fixture")
		world=app.session.authority.world;world.business.technologies.append("robotics");world.business.bags[owner_id]=FrontierExpeditionBusiness.inventory();world.business.bags[owner_id].merge({"iron":250,"copper":150,"stone":100},true)
		check(request("rover_research").ok,"own bag logistics I research")
		app.open_menu(app.research_frame);app.research_frame.tabs.current_tab=3;await create_timer(.3).timeout;await capture("rover-research");app.close_menus()
		var factory_id:=""
		for kind in ["solar","solar","charger","factory"]:
			var found:=false
			for x in range(-42,43,7):
				if found:break
				for z in range(-42,43,7):
					var p:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x,z,float(FrontierCatalog.entry("buildings",kind).radius))
					if not p.is_finite():continue
					move_to(p+Vector3(0,.1,5))
					var before: Array=FrontierExpeditionBusiness.site(app.session.authority.world).buildings.keys()
					var result:=request("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(p)})
					if not result.ok:continue
					if kind=="factory":
						for id in FrontierExpeditionBusiness.site(app.session.authority.world).buildings:
							if id not in before:factory_id=id
					found=true;break
			check(found,"build "+kind)
		if factory_id.is_empty():quit(1);return
		world=app.session.authority.world;var site:=FrontierExpeditionBusiness.site(world)
		for resource in FrontierRovers.config().cost:site.inventory[resource]=FrontierRovers.config().cost[resource]*2
		move_to(FrontierCrewWorld.vector(site.buildings[factory_id].position)+Vector3(0,0,5));await create_timer(1.2).timeout
		var result:=request("rover_craft",{"factory_id":factory_id});check(result.ok,"craft starts "+str(result))
		check(not request("business_craft",{"building_id":factory_id}).ok,"factory reservation blocks robot duplicate")
		app.open_station("factory",factory_id)
		for i in app.business_panel.tabs.get_tab_count():
			if app.business_panel.tabs.get_tab_control(i).name=="로버 제작":app.business_panel.tabs.current_tab=i
		await create_timer(.5).timeout;await capture("rover-factory");app.close_menus()
		if not await until(func():return not FrontierRovers.local(app.session.authority.world).is_empty(),65):check(false,"rover completes 45 second assembly");quit(1);return
		check(true,"real timed assembly completes")
	await verify_rover()
func verify_rover() -> void:
	rover_id=str(FrontierRovers.local(app.session.authority.world).keys()[0])
	var r: Dictionary=FrontierRovers.fleet(app.session.authority.world).vehicles[rover_id]
	move_to(FrontierRovers.point(r,[-2.3,0,0])+Vector3.UP*.1)
	app.yaw=PI/2;app.pitch=0
	await create_timer(1).timeout
	check(request("rover_enter",{"id":rover_id,"seat":0}).ok,"driver enters exact door")
	await create_timer(.3).timeout;await capture("rover-cockpit")
	check(not request("business_mine",{"vein_id":"fake"}).ok,"driver cannot mine while seated")
	app.rovers.chase=true;app.rovers.test_controls=[1.0,.25,0.0,0.0]
	var start:=FrontierRovers.point(FrontierRovers.fleet(app.session.authority.world).vehicles[rover_id]);await create_timer(3).timeout
	r=FrontierRovers.fleet(app.session.authority.world).vehicles[rover_id]
	print("DRIVE ",r)
	check(FrontierRovers.point(r).distance_to(start)>1 and float(r.battery)<100,"host drives real collision chassis and spends battery")
	check(app.rovers.actors[rover_id].drive.playing,"ElevenLabs drive loop plays in scene")
	await capture("rover-driving")
	app.open_menu(app.navigation_ui.pause_frame);await create_timer(2.5).timeout
	r=FrontierRovers.fleet(app.session.authority.world).vehicles[rover_id]
	check(absf(float(r.speed))<.1 and not app.rovers.actors[rover_id].drive.playing,"menu brakes and silences vehicle")
	app.rovers.test_controls=[0.0,0.0,1.0,0.0];app.close_menus()
	check(request("rover_exit",{"id":rover_id}).ok,"exit requests authoritative safe stop")
	check(await until(func():return app.rovers.seat().is_empty(),4),"safe exit completes")
	r=FrontierRovers.fleet(app.session.authority.world).vehicles[rover_id];move_to(FrontierRovers.point(r,[0,0,3.5]))
	app.session.authority.world.business.bags[app.session.latest.self_id]=FrontierExpeditionBusiness.inventory();app.session.authority.world.business.bags[app.session.latest.self_id].merge({"iron":50,"copper":20},true)
	check(request("rover_transfer",{"id":rover_id,"resource":"iron"}).ok,"click transfers own bag to rover")
	check(request("rover_transfer",{"id":rover_id,"resource":"iron","withdraw":true}).ok,"click withdraws rover cargo")
	r=FrontierRovers.fleet(app.session.authority.world).vehicles[rover_id];r.health=150;r.battery=0
	check(request("rover_repair",{"id":rover_id}).ok,"repair uses held iron and copper")
	check(request("rover_rescue",{"id":rover_id}).ok,"paid emergency charge keeps location")
	app.rovers.panel.vehicle_id=rover_id;app.open_menu(app.rovers.panel);await create_timer(.5).timeout;await capture("rover-cargo")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await create_timer(.4).timeout;await capture("rover-cargo-small");app.close_menus()
	var error:=FrontierUniverse.validate_world(app.session.authority.world);check(error.is_empty(),"world validates "+error)
	check(app.session.authority.checkpoint(),"vehicle persisted with world")
	var stored:=app.world_store.read_state();check(not stored.is_empty(),"world save can reload "+str(stored.get("error","")))
	print("ROVER_GROUND_RESULT ",failures)
	await app.session.close_session();quit(1 if failures else 0)

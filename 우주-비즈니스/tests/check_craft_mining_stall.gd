extends "res://tests/test_solo_entry.gd"

func timed(label: String,operation: Callable) -> Variant:
	var start:=Time.get_ticks_usec()
	var result: Variant=operation.call()
	print("TIMING ",label," ",(Time.get_ticks_usec()-start)/1000.0," ms")
	return result

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader") and app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"copied ground save loaded",150):quit(1);return
	app.onboarding.letter.hide();app.close_menus()
	await create_timer(3).timeout
	app.set_physics_process(false);app.set_process(false);app.session.set_process(false);app.session.set_physics_process(false)
	var authority:=app.session.authority
	authority.resolve_autonomous(true);app.session._drain_completed_requests()
	var actor: String=app.session.latest.self_id
	app.session.response_received.connect(func(_seq,value):print("RESPONSE ",value))
	app.session.surface_received.disconnect(app._surface_packet)
	app.session.surface_received.connect(func(packet):timed("surface apply",func():app._surface_packet(packet)))
	var panel:=app.inventory_panel
	panel.show();panel.tabs.set_tab_hidden(1,false);panel.tabs.current_tab=1;panel._process(.01)
	panel.selected_definition="pistol_1";panel._refresh_details()
	await capture("craft-before")
	# Reproduce hidden details refresh when leaving a selected firearm recipe.
	for tab in [3,4,5,6,1]:panel.tabs.current_tab=tab
	panel.selected_definition="pistol_1";panel._refresh_details()
	var member: Dictionary=authority.world.crew.members[actor]
	var stock: Dictionary=FrontierExpeditionBusiness.bag(authority.world,actor)
	for resource in stock:stock[resource]=0
	for resource in FrontierEquipment.config().items.pistol_1.cost:stock[resource]=50
	member.carried=0
	for building in authority.world.business.sites[app.surface_world.body.id].buildings.values():
		if building.type=="equipment_workbench":member.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(building.position)+Vector3(0,0,3))
	app.actors[actor].position=FrontierCrewWorld.vector(member.position)
	app.camera.set_as_top_level(true);app.camera.position=app.actors[actor].position+Vector3.UP*1.72;app.camera.rotation=Vector3.ZERO
	app.session._publish()
	for id in member.loadout.items.keys():
		if member.loadout.items[id]=="pistol_1" and id not in member.loadout.slots:
			member.loadout.items.erase(id);member.loadout.weapon_rolls.erase(id);member.loadout.weapon_states.erase(id)
	var before: int=member.loadout.items.size()
	timed("craft request",func():app.session.send_request("equipment_craft",{"definition":"pistol_1","element_id":"kinetic"}))
	await finish_commit("craft")
	timed("craft publication",func():app.session._drain_completed_requests())
	check(authority.world.crew.members[actor].loadout.items.size()==before+1,"pistol crafted exactly once")
	await capture("craft-after")
	panel.hide()
	var body:=app.surface_world.body
	var vein: Dictionary=FrontierExpeditionBusiness.starter_veins(body)[0]
	var point:=FrontierMineralWorld.point(FrontierCrewSurface.field(authority.world),vein)+Vector3.UP
	member=authority.world.crew.members[actor];member.position=FrontierExpeditionBusiness.array(point)
	app.actors[actor].position=point;app.camera.position=point+Vector3(0,1.72,2);app.camera.look_at(point-Vector3.UP)
	var site: Dictionary=authority.world.business.sites[body.id]
	site.remaining[vein.id]=1
	var bag: Dictionary=FrontierExpeditionBusiness.bag(authority.world,actor)
	bag[vein.resource]=mini(int(bag.get(vein.resource,0)),50)
	# Freeze autonomous ticks for this one action, and publish the prepared
	# pre-extraction state so only its completion is measured.
	app.session._publish();app.session._publish_surface()
	var view:=app.surface_world.business_view
	if not await until(func():return not view.nodes.is_empty() and view.nodes.has(vein.id),"mining target model loaded",100):quit(1);return
	var nodes_before: Dictionary={}
	for id in view.nodes:nodes_before[id]=view.nodes[id].get_instance_id()
	var before_amount: int=bag.get(vein.resource,0)
	timed("validation",func():return FrontierUniverse.validate_world(authority.world))
	timed("snapshot",func():return preload("res://scripts/persistence/world_snapshot.gd").copy(authority.world))
	timed("mining request",func():app.session.send_request("business_mine",{"vein_id":vein.id}))
	await finish_commit("mining")
	timed("mining publication",func():app.session._drain_completed_requests())
	check(int(authority.world.business.sites[body.id].remaining[vein.id])==0,"last ore extracted")
	check(int(FrontierExpeditionBusiness.bag(authority.world,actor).get(vein.resource,0))==before_amount+1,"one ore granted")
	check(not view.nodes.has(vein.id) and not view.pending_models.has(vein.id),"depleted ore removed from visuals and pending models")
	var retained:=true
	for id in nodes_before:
		if id!=vein.id and (not view.nodes.has(id) or view.nodes[id].get_instance_id()!=nodes_before[id]):retained=false
	check(retained and nodes_before.size()>1,"unrelated loaded nodes retained")
	await capture("mining-after")
	check(await app.session.close_session(),"copied session saved")
	print("CRAFT_MINING_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)

func finish_commit(label: String) -> void:
	var started:=Time.get_ticks_msec();var peak:=0
	while app.session.authority.autonomous_pending() and Time.get_ticks_msec()-started<10000:
		var tick:=Time.get_ticks_usec()
		app.session.authority.resolve_autonomous(false)
		peak=maxi(peak,Time.get_ticks_usec()-tick)
		await process_frame
	print("TIMING ",label," async elapsed ",Time.get_ticks_msec()-started," ms; peak poll ",peak/1000.0," ms")

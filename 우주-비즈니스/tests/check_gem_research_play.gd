extends "res://tests/test_solo_entry.gd"
## Targeted live bridge: seeded exposed gem -> equipped mining -> shared proof -> ship analysis.
## Travel position and Mk.2 assembly parts are fixtures; gems and discovery are not injected.
func press(key: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=key;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
func run() -> void:
	folder="/tmp/a01-a06-gem"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/a01-a06-gem" not in OS.get_cmdline_user_args():quit(1);return
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not has_meta("startup_loader") and not app.arrival.active,"isolated landed world",60):quit(1);return
	if not app.test_mode or app.world_store.path!=folder+"/world.json":printerr("ISOLATION_MISMATCH");quit(1);return
	app.onboarding.letter.hide();app.close_menus()
	var id: String=app.session.latest.self_id;var actor: CharacterBody3D=app.actors[id]
	var world: Dictionary=app.session.authority.world
	world.expedition_research=FrontierExpeditionResearch.create(false)
	world.business.bags[id]=FrontierExpeditionBusiness.inventory();world.business.bags[id].merge({"reinforced_frame":1,"control_circuit":1})
	var miner: String=""
	for item in world.crew.members[id].loadout.items:
		if world.crew.members[id].loadout.items[item]=="miner_1":miner=item;break
	check(not miner.is_empty(),"existing starter miner available")
	if miner.is_empty():quit(1);return
	app.session._publish();app.session.send_request("equipment_upgrade",{"item_id":miner});app.session.send_request("equipment_equip",{"item_id":miner,"slot":0});app.session.send_request("equipment_select",{"slot":0})
	check(FrontierEquipment.active(app.session.latest.crew.members[id]).tier==2,"Mk.2 assembled through real equipment transaction")
	var field: FrontierTerrainField=app.surface_world.terrain.field
	var vein: Dictionary={};var stand:=Vector3.INF;var point:=Vector3.INF
	for row in FrontierExpeditionBusiness.veins(app.surface_world.body):
		if row.resource not in FrontierExpeditionResearch.config().projects.deep_mining.sample_resources or int(row.required_tier)>2:continue
		var p:=FrontierMineralWorld.point(field,row)
		if not p.is_finite():continue
		for angle in 16:
			var candidate:=p+Vector3(cos(angle*TAU/16)*2.3,.15,sin(angle*TAU/16)*2.3)
			if field.density(candidate+Vector3.UP*1.2)>0 or field.density(candidate-Vector3.UP*.6)<=0:continue
			if not FrontierCrewSurface.visible_in_field(field,candidate+Vector3.UP*1.72,p+Vector3.UP):continue
			vein=row;stand=candidate;point=p;break
		if not vein.is_empty():break
	check(not vein.is_empty(),"seed contains a real exposed T2 gem and reachable sightline")
	if vein.is_empty():quit(1);return
	print("GEM ",vein.resource," ",vein.id," ",point)
	actor.position=stand;app.session.authority.update_position(1,stand);app.session._publish();app.session._publish_surface()
	if not await until(func():return app.surface_world.ready_at(stand) and app.surface_world.business_view.nodes.has(vein.id),"cave collision and real gem mesh loaded",30):quit(1);return
	actor.position=stand;app.session.authority.update_position(1,stand)
	var direction: Vector3=(point+Vector3.UP*.6-(stand+Vector3.UP*1.72)).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
	await create_timer(.2).timeout
	var target:=app.surface_world.business_view.target(app.camera,actor)
	check(target.get("id")==vein.id,"crosshair physics ray selects the exposed gem")
	if target.get("id")!=vein.id:print("TARGET ",target," ACTOR ",actor.position);await capture("gem-target-failed");quit(1);return
	await capture("gem-before")
	app.use_equipped();await create_timer(.15).timeout
	var proof: Dictionary=app.session.latest.expedition_research.projects.deep_mining.evidence.get(vein.resource,{})
	check(int(app.session.latest.inventory.get(vein.resource,0))>=3 and proof.get("source")=="extraction" and proof.get("vein_id")==vein.id,"real mining supplies gems and records host extraction evidence")
	if proof.is_empty():print(app.status.value);quit(1);return
	await capture("gem-mined")
	var bench: FrontierCrewStation=app.stations.surface.get_node("Station_research")
	stand=bench.global_position+bench.global_basis.z*2.1;stand.y=field.height(stand.x,stand.z)+.1
	actor.position=stand;app.session.authority.update_position(1,stand);app.session._publish();app.session._publish_surface()
	if not await until(func():return app.surface_world.ready_at(stand),"return to landed ship collision",30):quit(1);return
	actor.position=stand;app.session.authority.update_position(1,stand);direction=(bench.interaction_point()-(stand+Vector3.UP*1.72)).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
	await create_timer(.3).timeout;await press(KEY_F)
	var ui: FrontierExpeditionResearchPanel=app.stations.research
	check(app.stations.panel.visible and ui.is_visible_in_tree(),"F opens ship-side research after returning from cave")
	ui.prepare(vein.resource);ui.quantity.value=3;ui.action.pressed.emit();await process_frame
	check(ui.last_receipt.get("ok",false) and app.session.latest.expedition_research.projects.deep_mining.stage=="analyzed","mined specimens complete real ship analysis")
	await capture("mined-sample-analysis")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(saved.expedition_research.projects.deep_mining.evidence[vein.resource].vein_id==vein.id and saved.expedition_research.projects.deep_mining.stage=="analyzed","disk retains real vein evidence and analysis")
	print("GEM_RESEARCH_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

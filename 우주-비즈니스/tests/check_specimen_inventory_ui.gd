extends "res://tests/test_solo_entry.gd"
func run() -> void:
	folder="/tmp/specimen-inventory"
	if "--crew-folder=/tmp/specimen-inventory" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("표본 탐험가",2)
	var initial:=FrontierUniverse.new_world(71491)
	FrontierWorldStore.new(folder+"/world.json").write(initial)
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"ship ready",60):quit(1);return
	check(app.test_mode and app.session.store.path==folder+"/world.json","isolated fixture save")
	app.outside=false;app.exterior_view.hide();app.if_flight_view();app.close_menus();app.onboarding.letter.hide()
	var world: Dictionary=app.session.authority.world
	var ordinal:=source_ordinal(world.manifest)
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=FrontierUniverse.system_index(world.manifest,ordinal);nav.target=ordinal;nav.mode="idle"
	nav.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(ordinal,world.manifest,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
	app.session.send_request("ready",{"value":true});app.session.send_request("land",{})
	var actor: CharacterBody3D=app.actors[owner.character_id]
	if not await until(func():return app.surface_world!=null and not app.arrival.active and app.surface_world.ready_at(actor.position),"landed field",60):quit(1);return
	app.onboarding.letter.hide()
	var encounter:=find_sample(app.session.authority,1)
	check(not encounter.is_empty(),"real seeded sample has host sightline")
	if encounter.is_empty():quit(1);return
	actor.position=encounter.observer;actor.velocity=Vector3.ZERO
	FrontierEcology.scan(app.session.authority.world.ecology,app.session.authority.world.location,encounter)
	app.session.send_request("surface_collect",{"encounter_id":encounter.id,"aim":[encounter.aim.x,encounter.aim.y,encounter.aim.z]})
	world=app.session.authority.world
	check(world.ecology.specimens.size()==1,"actual app collects physical sample")
	if world.ecology.specimens.is_empty():quit(1);return
	var sample: Dictionary=world.ecology.specimens.values()[0]
	var key:=FrontierSpecimenItems.resource(sample)
	world.business.bags[owner.character_id].iron=18
	app.session._publish();app.session._publish_surface()
	app.toggle_inventory();await process_frame
	var ui: FrontierEquipmentPanel=app.inventory_panel
	ui.tabs.current_tab=0
	if not await until(func():return ui.owned.get_children().any(func(tile):return tile.get_meta("resource","")==key),"sample tile ready",5):quit(1);return
	for tile in ui.owned.get_children():
		if tile.get_meta("resource","")==key:tile.pressed.emit();break
	await capture("items-1280")
	check(ui.owned.get_children().any(func(tile):return tile.get_meta("resource","")==key) and ui.owned.get_children().any(func(tile):return tile.get_meta("resource","")=="iron"),"specimen and ore share the item grid")
	check(ui.preview.model!=null and ui.title.text.ends_with("표본"),"specimen shows authored species model and readable name")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("items-960")
	check(ui.action.get_global_rect().end.y<=640 and ui.detail_shell.get_global_rect().end.x<=960,"sample detail fits small screen")
	actor.position=Vector3(0,3,0);actor.velocity=Vector3.ZERO;app.session.authority.update_position(1,actor.position)
	ui.tabs.current_tab=2;ui.warehouse_choice.select(1);ui.last_key="";await process_frame
	ui._transfer_cargo({"resource":key,"source":"bag","amount":1});await create_timer(.4).timeout
	check(app.session.latest.crew.cargo.get(key,0)==1 and app.session.latest.inventory.get(key,0)==0,"I cargo action deposits specimen through host")
	await capture("cargo-960")
	ui._transfer_cargo({"resource":key,"source":"warehouse","amount":1});await create_timer(.4).timeout
	check(app.session.latest.inventory.get(key,0)==1 and app.session.latest.crew.cargo.get(key,0)==0,"I cargo action withdraws same specimen")
	check(FrontierUniverse.validate_world(app.session.authority.world).is_empty(),"rendered app world validates")
	check(await app.session.close_session(),"save and close")
	app.queue_free();await process_frame;await process_frame
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not saved.is_empty() and saved.ecology.specimens[sample.id].source_body==sample.source_body and FrontierSpecimenItems.validate(saved).is_empty(),"disk preserves specimen history and one physical location")
	print("SPECIMEN_INVENTORY_UI ",checks," FAILURES ",failures);quit(1 if failures else 0)
func find_sample(core: FrontierCrewAuthority,peer: int) -> Dictionary:
	var id: String=core.world.crew.landing.body_id
	var body:=FrontierUniverse.body_from_id(core.world.manifest,id)
	var terrain:=FrontierCrewSurface.field(core.world)
	for candidate in FrontierEcologyPlacement.candidates(body,core.world.ecology.planets[id],Vector3.ZERO):
		if candidate.layer!="surface":continue
		var point:=FrontierEcologyPlacement.ground(terrain,candidate)
		if not point.is_finite():continue
		var form:=FrontierEcologyCatalog.form(candidate.form_id)
		var height: float=(form.geometry.near.max[1]-form.geometry.near.floor_y)*FrontierEcologyCatalog.look(form.id,candidate.look_id).scale
		for angle in 8:
			var position:=point+Vector3(sin(angle*TAU/8)*2.2,0,cos(angle*TAU/8)*2.2)
			position.y=terrain.height(position.x,position.z)
			core.update_position(peer,position)
			var aim: Vector3=(point+terrain.normal(point)*maxf(.35,height*.5)-position-Vector3.UP*1.72).normalized()
			var target:=FrontierCrewSurface.target(core.world,core.peers[peer],aim)
			if target.get("id")==candidate.id:target.aim=aim;target.observer=position;return target
	return {}
func source_ordinal(manifest: Dictionary,start: int=8) -> int:
	for ordinal in range(start,200):
		var body:=FrontierUniverse.body(manifest,ordinal)
		if body.get("landable",true) and body.kind=="basalt" and FrontierEcology.profile(body).origin!="sterile":return ordinal
	return -1

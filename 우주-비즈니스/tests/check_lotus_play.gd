extends "res://tests/test_solo_entry.gd"
func run() -> void:
	folder="/tmp/lotus-play"
	if "--crew-folder=/tmp/lotus-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("Lotus 개척자",2)
	var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"fresh world with equipment")
	var world: Dictionary=core.world
	var destination:=FrontierCrewNavigation.first_destination(world.manifest)
	var planet:=FrontierUniverse.body(world.manifest,destination)
	world.location=planet.id;world.navigation_target=planet.id;world.crew.navigation.system=planet.system_ordinal;world.crew.navigation.target=destination
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(destination,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
	world.crew.members[owner.character_id].ready=true
	var reason:=FrontierCrewSurface.apply(world,owner.character_id,"land",{},{1:owner.character_id})
	check(reason.is_empty(),"prepare focused landing: "+reason)
	var store:=FrontierWorldStore.new(folder+"/world.json")
	check(store.write(world),"save isolated fixture: "+store.last_error)
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"actual Forward+ landing ready",80):quit(1);return
	if "--lotus-letter-only" in OS.get_cmdline_user_args():
		root.size=Vector2i(960,640);root.content_scale_size=root.size
		app.onboarding.letter.show();await capture("lotus-welcome-960")
		await app.session.close_session();app.queue_free();await process_frame;quit(0);return
	app.close_menus();app.onboarding.letter.hide();app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var actor: CharacterBody3D=app.actors[owner.character_id]
	check(not app.surface_world.business_view.nodes.has("business-base") and not is_instance_valid(app.stations.surface),"first landing has no automatic warehouse or outdoor stations")
	check(app.surface_world.shuttle_models.size()==1,"equipped FINCH is visible on the landing pad")
	var finch: Node3D=app.surface_world.shuttle_models.values()[0]
	look(actor,finch.position+Vector3(7,0,8),finch.position+Vector3.UP*1.6)
	await capture("finch-start")
	look(actor,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(14,0,0),finch.position)
	app.open_station("ship");await capture("ship-terminal")
	if "--lotus-terminal-only" in OS.get_cmdline_user_args():
		var event:=InputEventKey.new();event.pressed=true;event.physical_keycode=KEY_L;app._input(event)
		check(not app.lotus.panel.visible,"L no longer opens supply")
		app.business_panel.vessel_terminal.cards.augmentation.pressed.emit();await process_frame
		check(app.stations.panel.visible and app.stations.work_reason("augmentation").is_empty(),"ship augmentation menu keeps valid host access")
		app.open_station("ship");app.business_panel.vessel_terminal.cards.research.pressed.emit();await process_frame
		check(app.stations.panel.visible and app.stations.work_reason("research").is_empty(),"ship research menu keeps valid host access")
		app.open_station("ship");root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("ship-terminal-960")
		await app.session.close_session();app.queue_free();await process_frame
		print("LOTUS_TERMINAL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	app.business_panel.vessel_terminal.cards.lotus.pressed.emit();await capture("support-1280")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("support-960")
	check(app.lotus.request_button.get_global_rect().end.y<640 and app.lotus.panel.get_global_rect().end.x<=960,"support action fits small screen")
	check(app.feedback.blocked(),"support panel blocks tool input")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app.lotus.selected="iron";app.lotus.refresh();app.lotus.request_button.pressed.emit()
	check(app.lotus.pending==-1 and app.session.authority.world.lotus.crates.size()==1,"UI call receives synchronous host approval")
	check(app.lotus.status.text.contains("접수 완료"),"approval appears after committed request")
	if app.session.authority.world.lotus.crates.is_empty():printerr(app.lotus.status.text);quit(1);return
	check(app.lotus.own_audio.stream("ui_lotus_dispatch")!=null,"ElevenLabs dispatch cue connected")
	app.close_menus()
	var id: String=app.session.authority.world.lotus.crates.keys()[0]
	var p:=FrontierCrewWorld.vector(app.session.authority.world.lotus.crates[id].position)
	look(actor,p+Vector3(10,0,17),p+Vector3.UP*6)
	if not await until(func():return app.lotus.visuals.has(id) and app.lotus.visuals[id].carrier.visible,"real-time carrier arrives",30):quit(1);return
	await create_timer(7).timeout
	look(actor,p+Vector3(14,0,18),app.lotus.visuals[id].carrier.position+Vector3.UP*1.7)
	await capture("carrier-approach")
	var model: FrontierLotusDelivery=app.lotus.visuals[id]
	check(model.engine.playing and model.engine.stream!=null and model.rotors.size()==4 and model.jets.size()==4,"carrier motion, thrust and ElevenLabs 3D loop active")
	app.open_menu(app.navigation_ui.pause_frame);await process_frame;await process_frame
	check(not model.engine.playing or model.engine.stream_paused,"menu mutes carrier loop")
	app.close_menus()
	if not await until(func():return app.session.authority.world.lotus.crates[id].landed,"host commits touchdown",15):quit(1);return
	look(actor,p+Vector3(5,0,7),p+Vector3.UP*.8)
	await capture("crate-landed")
	check(model.collider.collision_layer==1 and model.impact.stream!=null,"crate has physical collision and landing audio")
	if not await until(func():return app.session.authority.world.lotus.crates[id].elapsed>=FrontierLotusSupport.duration(),"carrier completes departure",12):quit(1);return
	model.queue_free();app.lotus.visuals.erase(id)
	await process_frame;await process_frame
	model=app.lotus.visuals[id]
	check(not model.carrier.visible and model.crate.visible and not model.engine.playing and not model.impact.playing,"late visitor sees only saved crate without replay or touchdown sound")
	await capture("crate-late-arrival")
	look(actor,p+Vector3(0,0,3.1),p+Vector3.UP*.85)
	await create_timer(.4).timeout
	app.lotus.update_hint();check(app.lotus.hovered==id,"F target resolves actual crate")
	var before:=int(app.session.latest.inventory.get("iron",0))
	check(app.lotus.interact(),"F interaction sends receipt")
	await create_timer(.6).timeout
	check(int(app.session.latest.inventory.get("iron",0))==before+50,"physical crate gives exact quantity")
	check(model.lid!=null and model.lid.rotation.x<-.1 and model.audio.stream("sfx_lotus_open")!=null,"lid opening and receipt sound connected")
	await capture("crate-open")
	check(await app.session.close_session(),"support progress saves")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not saved.is_empty() and saved.lotus.free_remaining==2,"saved allowance and delivery ledger")
	app.queue_free();await process_frame;await process_frame
	print("LOTUS_PLAY_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
func look(actor: CharacterBody3D,p: Vector3,target: Vector3) -> void:
	p.y=app.surface_world.terrain.field.height(p.x,p.z)+.1
	actor.position=p;app.session.authority.update_position(1,p)
	var delta:=target-(p+Vector3.UP*1.72)
	app.yaw=atan2(-delta.x,-delta.z);app.pitch=atan2(delta.y,Vector2(delta.x,delta.z).length())

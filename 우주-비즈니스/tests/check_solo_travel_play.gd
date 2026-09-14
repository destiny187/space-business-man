extends "res://tests/test_solo_entry.gd"
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or FileAccess.file_exists(folder+"/world.json"):quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var store:=FrontierWorldStore.new(folder+"/world.json")
	check(store.write(FrontierUniverse.new_world(61739)),"fresh isolated first-expedition save")
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.start_solo();app.session.set_physics_process(false);app.set_physics_process(false)
	if not await until(func():return app.flight!=null and not app.preparing_first_snapshot,"actual solo game prepared",90):quit(1);return
	var a:=app.session.authority
	FrontierSolarOpening.step(a.world,30)
	app.session._publish();app.onboarding.letter.hide()
	app.onboarding.progress.solar_move=true;app.onboarding.progress.solar_boost=true;app.onboarding.progress.solar_scan=true
	var m: Dictionary=a.world.manifest
	var destination:=-1
	for i in 10000:
		if i==0 or FrontierUniverse.map_position(m,0).distance_to(FrontierUniverse.map_position(m,i))>FrontierVesselRefit.stellar_range(a.world):continue
		var ordinal:=FrontierUniverse.first_ordinal(m,i)
		if FrontierVesselAccess.departure_reason(a.world,ordinal).is_empty():destination=ordinal;break
	check(destination>=0,"first route uses stock ship range")
	var events: Array=[];var replies: Array=[]
	app.session.request_started.connect(func(_n,kind,args):events.append({"kind":kind,"args":args}))
	app.session.response_received.connect(func(_n,value):replies.append(value))
	var original_revision: int=a.world.crew.revision
	var original_energy:=float(a.world.crew.navigation.get("energy",100))
	# Hold the real disk job's publication while the actual UI sends the request.
	a.poll_autonomous=func():return 0
	app.navigation_ui.start_route(destination)
	await create_timer(.2).timeout
	check(a.autonomous_pending() and a.world.crew.navigation.mode=="idle","route selection waits for disk confirmation")
	a.resolve_autonomous(true);app.session._drain_completed_requests()
	if not await until(func():return a.autonomous_pending(),"route UI submits departure without a second click",10):quit(1);return
	check(events.size()==2 and events[0].kind=="navigate" and events[1].kind=="depart" and events[1].args.get("auto_ready",false),"UI emits selection plus atomic departure, no ready request")
	check(not a.world.crew.members[a.world.crew.owner_id].ready and a.world.crew.navigation.mode=="idle","pending departure has no early readiness or flight")
	# Avoid holding the publication of future unrelated simulation in the scene.
	a.poll_autonomous=func():return -1 if not app.session.store.poll_checkpoint() else (0 if app.session.store.has_pending() else 1)
	a.resolve_autonomous(true);app.session._drain_completed_requests()
	check(a.world.crew.navigation.mode=="jump" and app.session.latest.crew.navigation.mode=="jump","single route click begins the actual flight scene")
	check(a.world.crew.revision==original_revision+2,"route and departure use only two revisions")
	check(replies.size()==2 and replies.all(func(value):return value.get("ok",false)),"no stale-state response")
	check(float(a.world.crew.navigation.energy)==original_energy-float(m.settings.flight.get("transit_energy_cost",30)),"propulsion energy charged once")
	await capture("first-stellar-departure")
	check(await app.session.close_session(),"departure saved on normal close")
	var restored:=store.read_state()
	check(not restored.is_empty() and restored.crew.navigation.mode=="jump" and int(restored.crew.navigation.target)==destination,"saved departure reloads with the selected destination")
	print("SOLO TRAVEL PLAY checks ",checks," failures ",failures)
	app.queue_free();await process_frame;quit(1 if failures else 0)

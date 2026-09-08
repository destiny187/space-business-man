extends "res://tests/test_solo_entry.gd"
func run() -> void:
	folder="/tmp/augmentation-a01-ui"
	if "--crew-folder=/tmp/augmentation-a01-ui" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var source:=FrontierWorldStore.new("/tmp/augmentation-a01/world.json").read_state()
	if source.is_empty():printerr("Run check_augmentation_foundation.gd first");quit(1);return
	check(FrontierWorldStore.new(folder+"/world.json").write(source),"isolated world prepared")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json")
	profile.data={"version":1,"character":source.crew.members[source.crew.owner_id].profile,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active,"surface loads",60):quit(1);return
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	app.close_menus()
	if app.onboarding.letter.visible:app.onboarding.letter.hide()
	await create_timer(.5).timeout
	var actor: CharacterBody3D=app.actors[app.session.latest.self_id]
	root.gui_release_focus()
	if not await until(func():return app.surface_world.ready_at(actor.position) and actor.is_on_floor(),"terrain collision ready",60):quit(1);return
	app.test_direction=Vector2(1,0)
	await create_timer(.4).timeout
	var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
	app.test_direction=Vector2.ZERO
	var expected:=float(FrontierCrewSurface.config().movement_speed)*1.3
	check(absf(speed-expected)<.25,"actual character movement uses migrated augmentation: %.2f / %.2f"%[speed,expected])
	var instruments: FrontierFieldInstruments=app.field_hud.instruments
	check(is_equal_approx(instruments.health.max_value,140.0),"actual HUD uses personal health maximum")
	check(instruments.health_text.text.ends_with("/ 140"),"HUD displays current and maximum health")
	check(instruments.health_text.get_global_rect().end.x<=960,"health text fits small viewport")
	await capture("augmentation-hud-960")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	check(not FrontierWorldStore.new(folder+"/world.json").read_state().is_empty(),"runtime world saves and reloads")
	print("AUGMENTATION_A01_UI ",checks," FAILURES ",failures);quit(1 if failures else 0)

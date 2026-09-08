extends "res://tests/test_solo_entry.gd"
func run() -> void:
	folder="/tmp/shuttle-recovery-ui"
	if "--crew-folder=/tmp/shuttle-recovery-ui" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var source:=FrontierWorldStore.new("/tmp/finch-sortie/world.json").read_state()
	if source.is_empty():quit(1);return
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(source),"isolated scene")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":source.crew.members[source.crew.owner_id].profile,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
	app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active,"current entry loads",60):quit(1);return
	app.open_menu(app.navigation_ui.crew_frame)
	var panel: FrontierShuttleRecoveryPanel=app.navigation_ui.shuttle_recovery
	await capture("recall-1280")
	check(panel.visible and panel.ids.size()==1 and panel.preview.model!=null,"disconnected craft rendered and selected")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	await capture("recall-960")
	check(panel.action.get_global_rect().end.x<=960 and app.navigation_ui.crew_frame.get_global_rect().end.y<=640,"small screen fits recovery controls")
	check(app.feedback.blocked(),"menu blocks field input and work audio")
	var id: String=panel.ids[0]
	var cargo:=FrontierUniverse.fingerprint(app.session.authority.world.crew.shuttles[id].cargo)
	panel.action.pressed.emit()
	await capture("recalled-960")
	check(app.session.authority.world.crew.shuttles[id].state=="docked" and panel.outcome.text.begins_with("회수 완료"),"button completes durable recall and displays response")
	check(FrontierUniverse.fingerprint(app.session.authority.world.crew.shuttles[id].cargo)==cargo,"cargo retained by owner")
	app.close_menus();await process_frame;await process_frame
	check(panel.preview.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"hidden preview stops rendering")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	check(not FrontierWorldStore.new(folder+"/world.json").read_state().is_empty(),"recovery save reloads")
	print("RECOVERY_UI_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

extends "res://tests/test_solo_entry.gd"
func run() -> void:
	folder="/tmp/early-access-ui"
	if "--crew-folder=/tmp/early-access-ui" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var source:=FrontierWorldStore.new("/tmp/early-checked-world.json").read_state()
	if source.is_empty():quit(1);return
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(source),"isolated scene")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":source.crew.members[source.crew.owner_id].profile,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
	app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active,"current entry loads",60):quit(1);return
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	var world: Dictionary=app.session.authority.world
	var site: Dictionary=world.business.sites[world.location]
	var robot: Dictionary=site.robots.values()[0]
	app.actors[app.session.latest.self_id].position=FrontierCrewWorld.vector(robot.position)
	app.open_station("robot",robot.id)
	await capture("robot-work-960")
	check(app.business_panel.work_cards.get_child_count()==2,"automatic and discovered iron cards only")
	check(app.business_panel.work_cards.get_global_rect().end.x<=960,"cards fit small screen")
	check(app.feedback.blocked(),"menu blocks field input and sound")
	app.close_menus();app.toggle_research()
	await capture("research-960")
	check(app.research_frame.tabs.get_tab_count()==3,"basic technology purchase tab removed")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	print("EARLY_UI ",checks," FAILURES ",failures);quit(1 if failures else 0)

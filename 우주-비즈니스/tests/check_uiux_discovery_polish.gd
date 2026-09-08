extends "res://tests/test_solo_entry.gd"
func run() -> void:
	folder="/tmp/uiux-ux02"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/uiux-ux02" not in OS.get_cmdline_user_args():quit(1);return
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not has_meta("startup_loader") and not app.arrival.active,"UX02 polish fixture",60):quit(1);return
	if not app.test_mode or app.world_store.path!=folder+"/world.json":quit(1);return
	app.close_menus();app.onboarding.letter.hide();app.navigation_journal.path=folder+"/navigation.json"
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	var actor: String=app.session.latest.self_id
	var point:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	app.actors[actor].position=point;app.session.authority.update_position(1,point);app.session._publish();app.session._publish_surface();await create_timer(.3).timeout
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(2);app.survey_journal.refresh();await capture("biology-final-960")
	check(app.survey_journal.grid.columns==4 and app.survey_journal.get_global_rect().end.x<root.size.x,"four codex columns fit small viewport")
	var overlay:=false
	for button in app.research_actions:
		for child in button.get_children():
			if child is RichTextLabel:overlay=true
	check(not overlay,"dynamic ecology labels have no duplicate old caption")
	app.close_menus();app.open_station("ship");await process_frame
	var panel:=app.business_panel
	for i in panel.tabs.get_tab_count():
		if str(panel.tabs.get_tab_control(i).name)=="생산 거점":panel.tabs.current_tab=i
	await capture("supply-960")
	var all_button: Button
	for control in panel.supply_panel.find_children("*","Button",true,false):
		if control.text.begins_with("창고 전체"):all_button=control;break
	check(all_button!=null,"production site exposes full warehouse action")
	all_button.pressed.emit();await capture("supply-expanded-960")
	var popup: FrontierResourceListDialog
	for child in panel.supply_panel.get_children():
		if child is FrontierResourceListDialog:popup=child
	check(popup!=null and popup.grid.get_child_count()>4,"site warehouse expands beyond four types")
	popup.queue_free();await process_frame;app.close_menus()
	app.toggle_navigation()
	var nav=app.navigation_ui
	nav.selected_preview=56058;app.flight.scanned[FrontierUniverse.body_id(app.session.manifest,56058)]=true;nav.refresh_survey()
	var more: Button
	for control in nav.resources.get_children():
		if control is Button:more=control
	check(more!=null,"orbital survey exposes remaining resources")
	more.pressed.emit();await capture("orbital-expanded-960")
	for child in nav.get_children():
		if child is FrontierResourceListDialog:popup=child
	check(popup!=null and popup.grid.get_child_count()==FrontierOrbitalSurvey.report(FrontierUniverse.body(app.session.manifest,56058)).resources.size(),"orbital popup includes every measured mineral")
	popup.queue_free();await process_frame;app.close_menus()
	check(await app.session.close_session(),"polish fixture saved and closed")
	print("UIUX_POLISH ",checks," FAILURES ",failures);quit(1 if failures else 0)

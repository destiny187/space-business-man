extends "res://tests/test_solo_entry.gd"
var m: Dictionary={}
var trace: Dictionary={}
func run() -> void:
	if "--crew-folder=/tmp/corporate-traces-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/corporate-traces");DirAccess.make_dir_recursive_absolute("/tmp/corporate-traces-play")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("기업 활동 조사",2);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true);m=core.world.manifest
	check(FrontierWorldStore.new("/tmp/corporate-traces-play/world.json").write(core.world),"current expedition fixture save")
	var profile:=FrontierPlayerProfile.new("/tmp/corporate-traces-play/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition opens",45):quit(1);return
	app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	app.outside=true;app.exterior_view.show();app.if_flight_view();app.set_process(false);app.session.set_process(false)
	app.flight.set_process(false);app.flight.scan_enabled=true;app.flight.presentation_blocked=false;app.flight.soundscape.blocked=false;app.flight.camera.set_as_top_level(true);app.flight.transit_overlay.hide()
	for index in [53978,702,2805]:
		trace=FrontierCorporateTraces.all(m,index,0)[0]
		place(1800)
		check(app.flight.trace_view.models.size()==1,"local trace instantiated "+str(trace.company))
		check(app.orbital_scan_allowed(),"outside E input enabled "+str(trace.company))
		app.flight.trace_view.update(0,false);check(int(app.flight.trace_view.selected.get("stage",-1))==0,"unknown signal before physical identification")
		if index==53978:await show_map("trace-map-unknown")
		app.test_scan=true
		if not await stage(1,3.5):quit(1);return
		app.test_scan=false;await create_timer(.15).timeout
		if index==53978:await capture("trace-identified-hud")
		check(int(app.navigation_journal.data.get("corporate_traces",{}).get(trace.id,0))==1,"host stage projects into map journal")
		if index==53978:await show_map("trace-map-identified")
		place(520);app.test_scan=true
		await create_timer(.6).timeout;publish_view()
		check(app.flight.trace_view.scanning and app.flight.soundscape.scan.playing,"held scan plays existing orbital audio")
		if index==53978:await capture("trace-progress-hud")
		if index==53978:
			app.open_menu(app.inventory_panel);await create_timer(.2).timeout
			check(not app.orbital_scan_allowed() and not app.session.authority.inputs[1].scanning,"menu blocks actual E input")
			app.close_menus();publish_view()
		if not await stage(2,4.5):quit(1);return
		app.test_scan=false;publish_view()
		if index==53978:await capture("trace-recorded-hud")
		check(app.flight.soundscape.library.last_played.has("sfx_orbital_complete"),"persisted completion plays confirmation cue")
		# Closer visual inspection uses an isolated camera; host position stays at valid scan distance.
		var point:=FrontierCrewWorld.vector(trace.position)
		app.flight.camera.global_position=point+Vector3(110,70,175);app.flight.camera.look_at(point)
		app.flight.trace_view.update(0,false);await capture("trace-"+str(trace.company)+"-game")
		var mechanism: Node3D=app.flight.trace_view.mechanisms[0];var before: Vector3=mechanism.rotation
		app.flight.trace_view.update(2,false);check(mechanism.rotation.distance_to(before)>.01,"functional mechanism moves "+str(trace.company));app.flight.trace_view.update(0,false)
		if index==53978:await show_map("trace-map-recorded")
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(5);app.survey_journal.refresh()
	await create_timer(.5).timeout
	check(app.survey_journal.grid.get_child_count()==3 and app.survey_journal.preview.visible,"J shows three physical trace cards and GLB preview")
	var framing:=app.survey_journal.preview.camera.size;app.survey_journal.select(app.survey_journal.selected_entry)
	check(is_equal_approx(framing,app.survey_journal.preview.camera.size),"reselect keeps trace preview framing")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("trace-journal-960")
	check(app.survey_journal.detail_column.get_global_rect().end.x<=960,"trace dossier fits narrow display")
	var scroll: ScrollContainer=app.survey_journal.detail_column.get_child(0);scroll.scroll_vertical=1000;await capture("trace-journal-detail-960")
	var journal:=FrontierNavigationJournal.new();journal.configure(m,app.session.world_id,app.session.latest.self_id)
	check(journal.data.get("corporate_traces",{}).size()==3,"personal map projection survives reload")
	app.test_scan=false;app.queue_free();await process_frame;await process_frame
	print("CORPORATE_TRACE_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func place(distance: float) -> void:
	var world: Dictionary=app.session.authority.world;var nav: Dictionary=world.crew.navigation
	nav.system=int(trace.system);nav.target=int(trace.body);nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(trace.position)+Vector3(0,0,distance));nav.direction=[0,0,-1];nav.orbit_time=0;nav.speed=0;nav.mode="idle";nav.manual=true;nav.traffic_patrols={};nav.traffic_observers=[]
	world.flight_position=nav.position.duplicate();world.location=trace.body_id;world.navigation_target=trace.body_id
	app.session._publish();app.flight.camera.global_position=FrontierCrewWorld.vector(nav.position);app.flight.camera.look_at(FrontierCrewWorld.vector(trace.position));publish_view()
func publish_view() -> void:
	app.session._publish();app.flight.trace_view.update(0,false);app.flight.corporate_view.update(0,false)
	if is_instance_valid(app.flight.traffic):app.flight.traffic.update(.1,0,true)
	app.flight.soundscape.update(.1,app.flight.trace_view.scanning,float(app.flight.trace_scan.get("progress",0)))
func stage(value: int,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await create_timer(.1).timeout;publish_view()
		if int(FrontierCorporateTraces.records(app.session.authority.world).get(trace.id,0))>=value:check(true,"actual E input reaches saved stage "+str(value)+" "+str(trace.company));return true
	check(false,"actual E scan stage "+str(value)+" "+str(app.session.authority.scans));await capture("trace-scan-failed");return false
func show_map(filename: String) -> void:
	var layer:=CanvasLayer.new();layer.layer=50;root.add_child(layer)
	var chart: Control=load("res://scripts/ui/galaxy_chart.gd").new();layer.add_child(chart);chart.size=Vector2(root.size)
	chart.manifest=m;chart.journal=app.navigation_journal;chart.system_index=int(trace.system);chart.current_system=int(trace.system);chart.ship_position=app.flight.camera.global_position;chart.queue_redraw()
	await capture(filename);layer.queue_free();await process_frame

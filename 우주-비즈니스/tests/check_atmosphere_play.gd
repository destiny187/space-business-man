extends "res://tests/test_solo_entry.gd"
var body: Dictionary={}
var sample: Dictionary={}
func run() -> void:
	if "--crew-folder=/tmp/biota-atmosphere-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	var fixture: bool="--recipe-fixture" in OS.get_cmdline_user_args()
	if fixture:load("res://tests/native_biota_fixture.gd").prepare()
	folder=ProjectSettings.globalize_path("res://../docs/production/media/biota");DirAccess.make_dir_recursive_absolute("/tmp/biota-atmosphere-play")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("대기층 생물 관측",2);var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"create focused native galaxy")
	if core.world.is_empty():printerr(core.error);quit(1);return
	for id in core.world.manifest.native_biota.planets:
		var candidate:=FrontierUniverse.body(core.world.manifest,int(id),false)
		if candidate.kind not in ["gas_giant","ice_giant"] or candidate.native_ecology.origin!="established":continue
		for row in FrontierAtmosphereSurvey.observable(candidate):
			var form:=FrontierEcologyCatalog.form(row.form_id)
			if form.has("lods") and ResourceLoader.exists("res://"+str(form.lods.near.path).trim_prefix("우주-비즈니스/")):
				body=candidate;sample=row;break
		if not body.is_empty():break
	check(not sample.is_empty(),"finished atmospheric species has a natural home")
	if sample.is_empty():quit(1);return
	# Previously inspected signals are genuine native rows in the same prepared save.
	# This leaves the selected authored model as the next observable signal.
	FrontierEcology.ensure_planet(core.world.ecology,body)
	for row in FrontierAtmosphereSurvey.observable(body):
		if row.form_id==sample.form_id:break
		FrontierEcology.scan(core.world.ecology,body.id,row)
	core.world.crew.navigation.erase("solar_opening")
	check(FrontierWorldStore.new("/tmp/biota-atmosphere-play/world.json").write(core.world),"save orbital fixture")
	var profile:=FrontierPlayerProfile.new("/tmp/biota-atmosphere-play/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.session.notice.connect(func(message):print("ATMOSPHERE_NOTICE ",message));app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition opens",20):
		printerr("OPEN_STATE ",app.status.value," active=",app.session.active," phase=",app.session.latest.get("phase", "none")," world=",app.world_store.last_error);await capture("atmosphere-open-failed");quit(1);return
	app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	app.outside=true;app.exterior_view.show();app.if_flight_view();app.set_process(false);app.session.set_process(false);app.flight.set_process(false)
	app.flight.scan_enabled=true;app.flight.presentation_blocked=false;app.flight.soundscape.blocked=false;app.flight.camera.set_as_top_level(true)
	var world: Dictionary=app.session.authority.world;var nav: Dictionary=world.crew.navigation
	var center:=FrontierUniverse.position(world.manifest,int(body.ordinal),0)
	nav.system=int(body.system_ordinal);nav.target=int(body.ordinal);nav.position=FrontierExpeditionBusiness.array(center+Vector3.BACK*(FrontierUniverse.navigation_radius(body)+500));nav.direction=[0,0,-1];nav.orbit_time=0;nav.speed=0;nav.mode="idle";nav.manual=true;nav.traffic_patrols={};nav.traffic_observers=[]
	world.flight_position=nav.position.duplicate();world.location=body.id;world.navigation_target=body.id
	app.session._publish();app.flight.camera.global_position=FrontierCrewWorld.vector(nav.position)+Vector3(0,90,180);app.flight.camera.look_at(center);publish_view()
	check(app.orbital_scan_allowed() and not app.flight.atmosphere_target.is_empty(),"orbital E selects atmosphere at valid distance")
	app.test_scan=true;await create_timer(.7).timeout;publish_view()
	check(app.flight.atmosphere_overlay.preview.visible and float(app.session.latest.scan.progress)<1,"actual skinned organism shown during held scan")
	await capture("atmosphere-progress")
	app.open_menu(app.inventory_panel);await create_timer(.25).timeout
	check(not app.orbital_scan_allowed() and not app.session.authority.inputs[1].scanning,"menu blocks live E observation")
	app.close_menus();app.test_scan=true
	var deadline:=Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<deadline and not app.session.authority.world.ecology.observations.has(body.id+":"+sample.form_id):
		await create_timer(.1).timeout;publish_view()
	check(app.session.authority.world.ecology.observations.has(body.id+":"+sample.form_id),"held E persists atmospheric native species")
	publish_view();root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("atmosphere-confirmed-960")
	check(app.flight.soundscape.library.last_played.has("sfx_orbital_complete"),"confirmed scan plays existing ElevenLabs completion")
	check(app.flight.atmosphere_overlay.get_global_rect().end.x<=app.flight.get_viewport().size.x,"observation panel fits viewport")
	app.test_scan=false;app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(2);app.survey_journal.search.text=FrontierEcologyCatalog.form(sample.form_id).name;app.survey_journal.refresh()
	check(await until(func():return app.survey_journal.selected_entry.get("row",{}).get("form_id","")==sample.form_id,"J finds atmospheric observation",8),"journal record")
	await capture("atmosphere-journal-960")
	check(app.survey_journal.preview.model!=null and app.survey_journal.selected_entry.row.get("observed_layer","")=="atmosphere","journal displays actual model and orbital provenance")
	check(await app.session.close_session(),"orbital observation save closes")
	var restored:=FrontierWorldStore.new("/tmp/biota-atmosphere-play/world.json").read_state()
	check(not restored.is_empty() and restored.ecology.observations.has(body.id+":"+sample.form_id),"atmosphere observation reloads")
	FileAccess.open(folder+"/atmosphere-play-check.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"body":body.id,"form":sample.form_id,"recipe_fixture":fixture},"  "))
	app.queue_free();await process_frame;print("ATMOSPHERE_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func publish_view() -> void:
	app.session._publish();app.flight.trace_view.update(0,true);app.flight.corporate_view.update(0,true)
	if is_instance_valid(app.flight.freight_view):app.flight.freight_view.update(.1,0,true)
	if is_instance_valid(app.flight.traffic):app.flight.traffic.update(.1,0,true)
	var blocked:=app.flight._update_atmosphere(.2,not app.orbital_scan_allowed())
	var progress:=float(app.flight.trace_scan.get("progress",0))
	app.flight.soundscape.update(.1,not blocked and progress>0 and progress<1,progress)

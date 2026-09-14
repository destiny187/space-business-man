extends "res://tests/check_freight_salvage_play.gd"
func run() -> void:
	if "--crew-folder=/tmp/freight-salvage-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder="/tmp/playtest-tether";DirAccess.make_dir_recursive_absolute(folder);DirAccess.make_dir_recursive_absolute("/tmp/freight-salvage-play")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("항로 회수 작업",2);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true);m=core.world.manifest
	event=FrontierFreightSalvage.definition(m,"freight-v1:0")
	check(FrontierWorldStore.new("/tmp/freight-salvage-play/world.json").write(core.world),"new expedition fixture saved")
	var profile:=FrontierPlayerProfile.new("/tmp/freight-salvage-play/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader") and not app.preparing_first_snapshot,"current expedition opens",90):quit(1);return
	app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	app.outside=true;app.exterior_view.show();app.if_flight_view();app.set_process(false);app.session.set_process(false)
	app.flight.set_process(false);app.flight.scan_enabled=true;app.flight.presentation_blocked=false;app.flight.soundscape.blocked=false;app.flight.camera.set_as_top_level(true);app.flight.transit_overlay.hide()
	app.onboarding.welcome_pending=false;app.onboarding.letter.hide();app.session.authority.world.crew.navigation.erase("solar_opening")
	place(1800)
	root.grab_focus();root.gui_release_focus();app.cursor_released=false;await process_frame
	check(app.orbital_scan_allowed() and int(app.flight.freight_view.selected.get("stage",-1))==0,"actual E input sees SOS target")
	await capture("freight-sos-hud");app.test_scan=true
	if not await stage(1,4):quit(1);return
	app.test_scan=false;await create_timer(.2).timeout;place(180);app.test_scan=true
	await create_timer(.7).timeout;publish_view()
	var view: FrontierFreightSalvageView=app.flight.freight_view
	check(view.scanning and view.winch.playing and not view.cable.visible,"held connection fills gauge with sound before cable appears")
	check(view.models[event.id].global_position.distance_to(FrontierCrewWorld.vector(event.position))<.01,"cargo stays at source throughout held connection")
	check(view.cradles.is_empty() and view.overlay.carry.is_empty(),"connection creates no cradle or premature carried cargo")
	await capture("freight-winch-hud")
	if failures:await app.session.close_session();quit(1);return
	app.open_menu(app.inventory_panel);await create_timer(.2).timeout
	check(not app.orbital_scan_allowed() and not app.session.authority.inputs[1].scanning,"menu cancels actual held recovery input")
	var cancel_time:=float(app.session.authority.world.crew.navigation.orbit_time)
	view.update(.1,cancel_time,true);check(not view.winch.playing and view.overlay.row.is_empty(),"blocked presentation silences winch and hides cargo targeting")
	var source:=FrontierFreightSalvage.definition(m,event.id,cancel_time)
	check(view.models[event.id].global_position.distance_to(FrontierCrewWorld.vector(source.position))<.01 and not view.cable.visible,"cancelled connection leaves cargo in place without cable")
	app.close_menus();app.test_scan=false;root.grab_focus();root.gui_release_focus();app.cursor_released=false;publish_view();await create_timer(.2).timeout;app.test_scan=true
	if not await stage(2,7):quit(1);return
	app.test_scan=false;publish_view()
	check(view.cable.visible and not view.overlay.carry.is_empty(),"saved cargo retains visible towing cable and status")
	check(view.models[event.id].global_position.distance_to(view.socket({"id":"crew"}).origin)>20,"cargo trails behind the hull")
	check(view.cradles.is_empty(),"confirmed tether uses no loading cradle")
	var cargo_before: Vector3=view.models[event.id].global_position
	var nav: Dictionary=app.session.authority.world.crew.navigation
	nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(nav.position)+Vector3(35,0,-100))
	await create_timer(.2).timeout;publish_view()
	check(not app.session.authority.inputs[1].scanning and view.cable.visible and int(FrontierFreightSalvage.records(app.session.authority.world)[event.id].stage)==2,"released F retains confirmed tether while ship moves")
	check(view.models[event.id].global_position.distance_to(cargo_before)>1,"towed cargo follows ship after F release")
	check(app.flight.soundscape.library.last_played.has("sfx_lotus_touchdown"),"saved clamp lock plays reused ElevenLabs cargo cue")
	app.business_panel.vessel_terminal.update_snapshot(app.session.latest)
	check(app.business_panel.vessel_terminal.freight_card.visible,"ship terminal reflects occupied external cradle")
	var ship_point:=app.flight.ship.global_position;app.flight.camera.global_position=ship_point+Vector3(105,30,145);app.flight.camera.look_at(ship_point+Vector3(0,-12,0));publish_view();await capture("freight-on-ship-game")
	# Controlled approach isolates the handover from unrelated long-distance navigation.
	place(350,true);app.test_scan=true;await create_timer(.8).timeout;publish_view();await capture("freight-handover-hud")
	if not await stage(3,4):quit(1);return
	app.test_scan=false;publish_view()
	check(not view.cable.visible and view.overlay.carry.is_empty(),"confirmed delivery empties physical rig")
	check(view.models[event.id].global_position.distance_to(FrontierCrewWorld.vector(event.receiver))<1,"single recovered pod remains on actual receiving deck")
	check(int(app.session.latest.shared_credits)==int(FrontierExpeditionBusiness.config().starting_credits)+350,"receipt payment reaches current UI snapshot")
	app.flight.camera.global_position=FrontierCrewWorld.vector(event.receiver)+Vector3(90,70,150);app.flight.camera.look_at(FrontierCrewWorld.vector(event.receiver));publish_view();await capture("freight-received-game")
	check(await app.session.close_session(),"towing session saves")
	app.queue_free();await process_frame;print("TETHER_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

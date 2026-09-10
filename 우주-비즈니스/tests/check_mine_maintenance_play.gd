extends "res://tests/check_freight_salvage_play.gd"
func run() -> void:
	if "--crew-folder=/tmp/mine-maintenance-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/mine-maintenance");DirAccess.make_dir_recursive_absolute("/tmp/mine-maintenance-play")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("mine 현장 정비",2);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true);m=core.world.manifest
	event=FrontierMineMaintenance.definition(m,702)
	core.world.crew.navigation.system=702;core.world.crew.navigation.target=event.body;core.world.location=event.body_id;core.world.navigation_target=event.body_id
	check(FrontierWorldStore.new("/tmp/mine-maintenance-play/world.json").write(core.world),"industrial expedition fixture saved")
	var profile:=FrontierPlayerProfile.new("/tmp/mine-maintenance-play/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition opens",45):quit(1);return
	app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	app.outside=true;app.exterior_view.show();app.if_flight_view();app.set_process(false);app.session.set_process(false)
	app.flight.set_process(false);app.flight.scan_enabled=true;app.flight.presentation_blocked=false;app.flight.soundscape.blocked=false;app.flight.camera.set_as_top_level(true);app.flight.transit_overlay.hide()
	place(480,true);var view: FrontierFreightSalvageView=app.flight.freight_view
	check(int(view.selected.get("stage",-1))==0,"stopped worksite receives actual E input")
	await capture("mine-diagnosis-hud");app.test_scan=true
	if not await stage(1,5):quit(1);return
	app.test_scan=false;await create_timer(.2).timeout;place(180);app.test_scan=true
	await create_timer(1.1).timeout;publish_view()
	check(view.winch.playing and view.cable.visible,"spare loading drives physical cable and ElevenLabs winch")
	await capture("mine-spare-pickup")
	if not await stage(2,6):quit(1);return
	app.test_scan=false;publish_view();check(view.cradles.crew.visible,"replacement cartridge rides on visible ship cradle")
	place(300,true);app.test_scan=true
	if not await stage(3,5):quit(1);return
	app.test_scan=false;publish_view();await create_timer(.2).timeout
	var receiver: Node3D=view.receivers[event.id];var rotor: Node3D=receiver.find_child("Anim_DrillRotor",true,false)
	check(rotor.rotation.x==0 and not view.cradles.crew.visible,"installed part still leaves drill stopped")
	app.test_scan=true;await create_timer(1.2).timeout;publish_view()
	check(view.repair_sound.playing and absf(receiver.find_child("Anim_RepairArm",true,false).rotation.y)>.01,"held repair actuates service arm and motor audio")
	await capture("mine-repair-hud")
	app.open_menu(app.inventory_panel);await create_timer(.2).timeout;view.update(.1,0,true)
	check(not view.repair_sound.playing and not app.session.authority.inputs[1].scanning,"menu cancels repair input and sound")
	app.close_menus();app.test_scan=false;await create_timer(.2).timeout;app.test_scan=true
	if not await stage(4,9):quit(1);return
	app.test_scan=false;publish_view();check(absf(rotor.rotation.x)>.01 and int(app.session.latest.shared_credits)==int(FrontierExpeditionBusiness.config().starting_credits)+500,"saved restart rotates drill and shows one payment")
	app.flight.camera.global_position=FrontierCrewWorld.vector(event.receiver)+Vector3(170,120,210);app.flight.camera.look_at(FrontierCrewWorld.vector(event.receiver)+Vector3(-35,0,0));publish_view();await capture("mine-restarted-game")
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(4);app.survey_journal.search.text="mine";app.survey_journal.refresh();await create_timer(.4).timeout
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("mine-journal-960")
	check(app.survey_journal.detail_column.get_global_rect().end.x<=960,"service dossier fits 960 width")
	check(int(app.navigation_journal.data.get("freight_stages",{}).get(event.id,0))==4,"map preserves all four service stages")
	app.queue_free();await process_frame;await process_frame;print("MINE_MAINTENANCE_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func place(distance: float,receiver: bool=false) -> void:
	var w: Dictionary=app.session.authority.world;var nav: Dictionary=w.crew.navigation
	event=FrontierMineMaintenance.definition(m,702)
	var point:=FrontierCrewWorld.vector(event.receiver if receiver else event.position)
	nav.system=702;nav.target=event.body;nav.position=FrontierExpeditionBusiness.array(point+Vector3(0,0,distance));nav.direction=[0,0,-1];nav.orbit_time=0;nav.speed=0;nav.mode="idle";nav.manual=true;nav.traffic_patrols={};nav.traffic_observers=[];nav.erase("freight_anchor")
	w.flight_position=nav.position.duplicate();w.location=event.body_id;w.navigation_target=event.body_id
	app.session._publish();app.flight.ship.global_position=FrontierCrewWorld.vector(nav.position);app.flight.ship.basis=Basis.IDENTITY;app.flight.camera.global_position=FrontierCrewWorld.vector(nav.position)+Vector3(0,4,-25);app.flight.camera.look_at(point);publish_view()

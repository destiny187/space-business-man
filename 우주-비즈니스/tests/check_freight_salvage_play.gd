extends "res://tests/test_solo_entry.gd"
var m: Dictionary={}
var event: Dictionary={}
func run() -> void:
	if "--crew-folder=/tmp/freight-salvage-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/freight-salvage");DirAccess.make_dir_recursive_absolute("/tmp/freight-salvage-play")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("항로 회수 작업",2);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true);m=core.world.manifest
	event=FrontierFreightSalvage.definition(m,"freight-v1:0")
	check(FrontierWorldStore.new("/tmp/freight-salvage-play/world.json").write(core.world),"new expedition fixture saved")
	var profile:=FrontierPlayerProfile.new("/tmp/freight-salvage-play/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition opens",45):quit(1);return
	app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	app.outside=true;app.exterior_view.show();app.if_flight_view();app.set_process(false);app.session.set_process(false)
	app.flight.set_process(false);app.flight.scan_enabled=true;app.flight.presentation_blocked=false;app.flight.soundscape.blocked=false;app.flight.camera.set_as_top_level(true);app.flight.transit_overlay.hide()
	place(1800)
	check(app.orbital_scan_allowed() and int(app.flight.freight_view.selected.get("stage",-1))==0,"actual E input sees SOS target")
	await capture("freight-sos-hud");app.test_scan=true
	if not await stage(1,4):quit(1);return
	app.test_scan=false;await create_timer(.2).timeout;place(180);app.test_scan=true
	await create_timer(1.3).timeout;publish_view()
	var view: FrontierFreightSalvageView=app.flight.freight_view
	check(view.scanning and view.winch.playing and view.cable.visible,"held recovery drives winch sound and physical cable")
	check(view.models[event.id].global_position.distance_to(FrontierCrewWorld.vector(event.position))>1,"actual pod moves toward ship during recovery")
	await capture("freight-winch-hud")
	app.open_menu(app.inventory_panel);await create_timer(.2).timeout
	check(not app.orbital_scan_allowed() and not app.session.authority.inputs[1].scanning,"menu cancels actual held recovery input")
	view.update(.1,0,true);check(not view.winch.playing and view.overlay.row.is_empty(),"blocked presentation silences winch and hides cargo targeting")
	app.close_menus();app.test_scan=false;publish_view();await create_timer(.2).timeout;app.test_scan=true
	if not await stage(2,7):quit(1);return
	app.test_scan=false;publish_view()
	check(view.cradles.crew.visible and not view.overlay.carry.is_empty(),"saved cargo has actual visible ship rig and status card")
	check(view.models[event.id].global_position.distance_to(view.cradles.crew.global_position)<1,"saved pod sits in the recovery cradle")
	check(app.flight.soundscape.library.last_played.has("sfx_lotus_touchdown"),"saved clamp lock plays reused ElevenLabs cargo cue")
	app.business_panel.vessel_terminal.update_snapshot(app.session.latest)
	check(app.business_panel.vessel_terminal.freight_card.visible,"ship terminal reflects occupied external cradle")
	var ship_point:=app.flight.ship.global_position;app.flight.camera.global_position=ship_point+Vector3(105,30,145);app.flight.camera.look_at(ship_point+Vector3(0,-12,0));publish_view();await capture("freight-on-ship-game")
	# Controlled approach isolates the handover from unrelated long-distance navigation.
	place(350,true);app.test_scan=true;await create_timer(.8).timeout;publish_view();await capture("freight-handover-hud")
	if not await stage(3,4):quit(1);return
	app.test_scan=false;publish_view()
	check(not view.cradles.crew.visible and view.overlay.carry.is_empty(),"confirmed delivery empties physical rig")
	check(view.models[event.id].global_position.distance_to(FrontierCrewWorld.vector(event.receiver))<1,"single recovered pod remains on actual receiving deck")
	check(int(app.session.latest.shared_credits)==int(FrontierExpeditionBusiness.config().starting_credits)+350,"receipt payment reaches current UI snapshot")
	app.flight.camera.global_position=FrontierCrewWorld.vector(event.receiver)+Vector3(90,70,150);app.flight.camera.look_at(FrontierCrewWorld.vector(event.receiver));publish_view();await capture("freight-received-game")
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(4);app.survey_journal.refresh();await create_timer(.5).timeout
	check(app.survey_journal.selected_entry.get("kind","")=="freight_incident" and app.survey_journal.preview.visible,"J shows freight image card and actual model dossier")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("freight-journal-960")
	check(app.survey_journal.detail_column.get_global_rect().end.x<=960,"freight dossier fits narrow display")
	var scroll: ScrollContainer=app.survey_journal.detail_column.get_child(0);scroll.scroll_vertical=1000;await capture("freight-journal-receipt-960")
	check(int(app.navigation_journal.data.get("freight_stages",{}).get(event.id,0))==3,"persistent map projection reflects handover receipt")
	app.close_menus();await show_map()
	app.test_scan=false;app.queue_free();await process_frame;await process_frame
	print("FREIGHT_SALVAGE_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func place(distance: float,receiver: bool=false) -> void:
	var w: Dictionary=app.session.authority.world;var nav: Dictionary=w.crew.navigation
	event=FrontierFreightSalvage.definition(m,event.id,0)
	var point:=FrontierCrewWorld.vector(event.receiver if receiver else event.position)
	nav.system=0;nav.target=3;nav.position=FrontierExpeditionBusiness.array(point+Vector3(0,0,distance));nav.direction=[0,0,-1];nav.orbit_time=0;nav.speed=0;nav.mode="idle";nav.manual=true;nav.traffic_patrols={};nav.traffic_observers=[]
	nav.erase("freight_anchor");w.flight_position=nav.position.duplicate();w.location=event.body_id;w.navigation_target=event.body_id
	app.session._publish();app.flight.ship.global_position=FrontierCrewWorld.vector(nav.position);app.flight.ship.basis=Basis.IDENTITY;app.flight.camera.global_position=FrontierCrewWorld.vector(nav.position)+Vector3(0,4,-25);app.flight.camera.look_at(point);publish_view()
func publish_view() -> void:
	var nav: Dictionary=app.session.authority.world.crew.navigation
	var old_point:=app.flight.ship.global_position
	app.flight.ship.global_position=FrontierCrewWorld.vector(nav.position)
	app.flight.camera.global_position+=app.flight.ship.global_position-old_point
	event=FrontierFreightSalvage.definition(m,event.id,float(nav.orbit_time))
	app.session._publish();app.flight.trace_view.update(float(nav.orbit_time),false);app.flight.corporate_view.update(float(nav.orbit_time),false)
	if is_instance_valid(app.flight.traffic):app.flight.traffic.update(.1,float(nav.orbit_time),true)
	app.flight.freight_view.update(.1,float(nav.orbit_time),false)
	app.flight.soundscape.update(.1,app.flight.freight_view.scanning,float(app.flight.trace_scan.get("progress",0)))
func stage(value: int,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await create_timer(.1).timeout;publish_view()
		if int(FrontierFreightSalvage.records(app.session.authority.world).get(event.id,{}).get("stage",0))>=value:check(true,"real E input reaches freight stage "+str(value));return true
	check(false,"held freight stage "+str(value)+" "+str(app.session.authority.scans)+" stopped="+str(app.session.authority.stopped)+" allowed="+str(app.orbital_scan_allowed())+" error="+app.session.authority.error);await capture("freight-failed");return false
func show_map() -> void:
	var layer:=CanvasLayer.new();layer.layer=50;root.add_child(layer)
	var chart: Control=load("res://scripts/ui/galaxy_chart.gd").new();layer.add_child(chart);chart.size=Vector2(root.size)
	chart.manifest=m;chart.journal=app.navigation_journal;chart.system_index=0;chart.current_system=0;chart.ship_position=app.flight.camera.global_position;chart.queue_redraw()
	await capture("freight-map-receipt");layer.queue_free();await process_frame

extends "res://tests/test_solo_entry.gd"
const SAVE_FOLDER="/tmp/space-pirate-play"
var sequence:=0
func run() -> void:
	if "--crew-folder=/tmp/space-pirate-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/pirate-combat");DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("항해 전투 검수",0);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
	var world: Dictionary=core.world;var system:=0
	for index in range(1000,90000,1000):
		if FrontierSpaceCombat.tier(world,index)>=2:system=index;break
	var nav: Dictionary=world.crew.navigation;nav.erase("solar_opening");nav.mode="idle";nav.manual=true;nav.system=system;nav.target=FrontierUniverse.first_ordinal(world.manifest,system);nav.direction=[0.0,0.0,-1.0];nav.speed=0.0;nav.first_stellar_system=1
	world.location=FrontierUniverse.body_id(world.manifest,int(nav.target));world.navigation_target=world.location
	for i in range(10,60):
		var p:=Vector3(0,i*400,0)
		if FrontierSpaceCombat.clear_position(world,system,p,1200):nav.position=FrontierSpaceCombat.arr(p);break
	world.flight_position=nav.position.duplicate();world.crew.landing={}
	var profile:=FrontierPlayerProfile.new(SAVE_FOLDER+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	check(FrontierSpaceCombat.begin(world,"crew","stellar_arrival"),"prepare encounter in actual expedition")
	check(FrontierWorldStore.new(SAVE_FOLDER+"/world.json").write(world),"combat save passes full world validation")
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition loads combat",55):quit(1);return
	app.onboarding.letter.hide();app.close_menus();app.outside=true;app.exterior_view.show();app.if_flight_view();app.flight.presentation_blocked=false
	app.set_physics_process(false);app.set_process(false);app.flight.presentation_blocked=false;root.grab_focus()
	var authority: FrontierCrewAuthority=app.session.authority
	var record:=FrontierSpaceCombat.record(authority.world);record.encounter.resume=0
	if "--radio-preview" in OS.get_cmdline_user_args():
		await preview_radio(authority);return
	for i in 85:
		send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	check(FrontierSpaceCombat.record(authority.world).encounter.phase=="combat","current host advances warning into live combat")
	check(app.flight.combat_view.models.size()>=2 and app.flight.combat_view.mount!=null,"authored ships and pulse mount visible in game")
	print("VIEW_STATE ",app.flight.combat_snapshot.keys()," ",app.flight.combat_view.blocked," ",app.flight.exterior," ",app.flight.current_system," ",app.flight.navigation.mode)
	check(not app.flight.transit_overlay.presenting_arrival(),"combat arrival does not cover combat with destination title")
	await capture("live-interception")
	# Use the real application input collector once, then return to deterministic aiming.
	app.test_mode=false;app.cursor_released=false;app.mouse_resume_guard=false;app.movement_timer=0;root.grab_focus()
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;Input.parse_input_event(press)
	await process_frame;Input.flush_buffered_events();app._physics_process(.06)
	if root.has_focus():check(authority.inputs[1].flight_controls.size()==6 and authority.inputs[1].flight_controls[4]>.5,"ordinary mouse input collects the ship firing flag")
	else:
		print("SKIP focused mouse input: native window focus unavailable")
		check(authority.inputs[1].flight_controls.size()<6,"unfocused window prevents weapon-ready input")
	var release: InputEventMouseButton=press.duplicate();release.pressed=false;Input.parse_input_event(release);app.test_mode=true
	if "--collector-only" in OS.get_cmdline_user_args():
		await capture("live-input-final");await app.session.close_session();app.queue_free();await process_frame
		print("PIRATE_INPUT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	var captured:=false
	for i in range(70):
		var e: Dictionary=FrontierSpaceCombat.record(authority.world).encounter
		if e.is_empty() or e.phase!="combat":break
		var enemy: Dictionary={}
		for row in e.enemies:
			if row.hull>0:enemy=row;break
		if enemy.is_empty():break
		var current_nav: Dictionary=authority.world.crew.navigation
		var direction: Vector3=(FrontierSpaceCombat.point(enemy.position)-FrontierSpaceCombat.point(current_nav.position)).normalized();current_nav.direction=FrontierSpaceCombat.arr(direction)
		var aim: Vector3=(FrontierSpaceCombat.point(enemy.position)-(FrontierSpaceCombat.point(current_nav.position)-direction*57+Vector3.UP*16)).normalized()
		send_controls(aim,true)
		if i==8:
			await capture("live-pulse-fire");captured=true
		await create_timer(.16).timeout
	check(captured and FrontierSpaceCombat.record(authority.world).event_serial>5,"real input drives host firing and visible events")
	check(not FrontierSpaceCombat.record(authority.world).wrecks.is_empty(),"live shots produce salvage")
	var view: FrontierSpaceCombatView=app.flight.combat_view
	check(view.audio.last_played.has("sfx_gun_ship_pulse") and view.audio.last_played.has("sfx_gun_impact"),"ElevenLabs firing and impact streams actually played")
	# Menu behavior must clear shooting input and stop combat audio.
	app.session.send_input(Vector2.ZERO,Vector3.FORWARD,false,false,[0,0,0],0,false)
	view.update(.1,true);check(view.selected_wreck.is_empty() and not view.armed(),"menu blocks weapons and salvage hints")
	for player in view.audio.get_children():
		if player is AudioStreamPlayer:check(not player.playing,"menu stops active combat sound")
	view.update(.1,false)
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("live-combat-960")
	# The same current flight scene switches to the independently owned FINCH.
	var actor: String=app.session.latest.self_id
	var canonical: Dictionary=authority.world
	canonical.crew.space_combat.encounter={};canonical.crew.navigation.combat_active=false
	canonical.crew.shuttles={actor:{"state":"sortie","pad_slot":0,"progress":0.0,"factory_id":"","system":system,"location":canonical.location,"navigation_target":canonical.location,"navigation":canonical.crew.navigation.duplicate(true),"landing":{},"cargo":{"copper":3},"cargo_equipment":{},"rock":0}}
	canonical.crew.members[actor].shuttle_id=actor
	check(FrontierSpaceCombat.begin(canonical,"shuttle:"+actor,"local_transit"),"live FINCH starts local pursuit")
	app.session._publish()
	for i in 5:send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	check(app.flight.refits.hull_id=="finch" and not app.flight.combat_view.armed() and app.flight.combat_view.mount==null,"FINCH view has pursuit HUD and remains unarmed")
	await capture("live-finch-pursuit")
	authority.world.crew.shuttles[actor].navigation.hull=0
	for i in 68:send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	check(authority.world.crew.shuttles[actor].navigation.hull==35 and authority.world.crew.shuttles[actor].cargo.copper==3,"actual FINCH recovery preserves cargo and restores flight")
	var wreck: Dictionary=FrontierSpaceCombat.record(authority.world).wrecks[0]
	authority.world.crew.shuttles[actor].navigation.position=wreck.position.duplicate();authority.world.crew.shuttles[actor].navigation.speed=0;app.session._publish()
	check(app.session.send_request("space_salvage",{"id":wreck.id}),"FINCH salvage uses actual session request")
	for i in 28:send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	check(authority.world.crew.shuttles[actor].cargo.get("iron",0)==8,"physical wreck is credited to FINCH cargo through host completion")
	# Saved actor state, enemy deaths and cargo must survive the normal store close path.
	var before: Dictionary=FrontierSpaceCombat.record(authority.world).duplicate(true)
	check(await app.session.close_session(),"normal session closes with combat state")
	var saved:=FrontierWorldStore.new(SAVE_FOLDER+"/world.json").read_state()
	check(not saved.is_empty() and saved.crew.space_combat.event_serial==before.event_serial and saved.crew.space_combat.wrecks.size()==before.wrecks.size(),"reload preserves same enemy results and wrecks")
	app.queue_free();await process_frame;await process_frame
	print("PIRATE_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func send_controls(aim: Vector3,shoot: bool) -> void:
	app.session.send_input(Vector2.ZERO,aim,false,false,[0,0,0,0,1.0 if shoot else 0.0,1.0],0,false)

func preview_radio(authority: FrontierCrewAuthority) -> void:
	for i in 4:send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	await capture("radio-first-warning")
	for i in 80:send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	var view: FrontierSpaceCombatView=app.flight.combat_view
	check(not view.radio.is_empty(),"host contact arrives as a vessel radio line")
	await capture("radio-contact")
	if "--radio-still" in OS.get_cmdline_user_args():
		root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("radio-contact-960")
		await app.session.close_session();app.queue_free();await process_frame
		print("PIRATE_RADIO_STILL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	for i in 43:send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	check(view.radio.is_empty(),"radio line expires without persistent phase text")
	await capture("radio-quiet-combat")
	var record: Dictionary=FrontierSpaceCombat.record(authority.world)
	authority.world.crew.navigation.position=FrontierSpaceCombat.arr(FrontierSpaceCombat.point(record.encounter.origin)+Vector3(2500,0,0))
	for i in 43:send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	check(view.radio.get("receiver","")=="해적 편대","escape sends a short withdrawal to the pirate formation")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	await capture("radio-withdrawal-960")
	view.update(.1,true);check(view.radio.is_empty(),"opening a menu clears current radio")
	view.last_serial=-1;view.update(.1,false)
	check(view.radio.is_empty(),"snapshot history does not replay old radio on re-entry")
	await app.session.close_session();app.queue_free();await process_frame
	print("PIRATE_RADIO_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

extends "res://tests/test_solo_entry.gd"
const SAVE_FOLDER="/tmp/space-collision-play"
var sequence:=0
func run() -> void:
	if "--crew-folder=/tmp/space-collision-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../output/gameplay-physics-20260913");DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
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
	world.business=FrontierExpeditionBusiness.create();world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory()
	world.vessel=FrontierVesselRefit.create(int(world.manifest.seed),world.crew.world_id);world.vessel.hull="orion";world.vessel.hulls=["kestrel","orion"]
	world.vessel.combat_skills=FrontierVesselSkills.create()
	var profile:=FrontierPlayerProfile.new(SAVE_FOLDER+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	check(FrontierSpaceCombat.begin(world,"crew","stellar_arrival"),"prepare encounter in actual expedition")
	check(FrontierWorldStore.new(SAVE_FOLDER+"/world.json").write(world),"combat save passes full world validation")
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition loads combat",55):quit(1);return
	app.onboarding.letter.hide();app.close_menus();app.outside=true;app.exterior_view.show();app.if_flight_view();app.flight.presentation_blocked=false
	app.set_physics_process(false);app.set_process(false);app.flight.presentation_blocked=false;root.grab_focus()
	var authority: FrontierCrewAuthority=app.session.authority
	var record:=FrontierSpaceCombat.record(authority.world);record.encounter.resume=0
	record.encounter.phase="combat";authority.resolve_autonomous(true)
	world=authority.world;record=FrontierSpaceCombat.record(world);record.encounter.phase="combat";record.encounter.resume=0
	var enemy: Dictionary=record.encounter.enemies[0]
	for other in record.encounter.enemies:
		if other!=enemy:other.hull=0
	nav=world.crew.navigation
	var origin:=FrontierSpaceCombat.point(nav.position)
	enemy.position=FrontierSpaceCombat.arr(origin+Vector3.FORWARD*350);enemy.direction=[0,0,1];enemy.velocity=[0,0,70];enemy.up=[0,1,0]
	FrontierSpaceCombatPilot.initialize(enemy);FrontierSpaceCombatPilot.phase(enemy,"approach",1)
	nav.direction=[0,0,-1];nav.speed=80;nav.up=[0,1,0]
	app.session._publish()
	FrontierClientSettings.ensure(self).values.music_volume=0;FrontierClientSettings.ensure(self).apply_all()
	var recorder:=AudioEffectRecord.new();var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
	for i in 12:
		app.session.send_input(Vector2.ZERO,Vector3.FORWARD,false,false,[0,0,0,0,0,1,1,0,0,0,0,0],0,false)
		await create_timer(.05).timeout
	await capture("missile-launch-live")
	for i in 75:
		app.session.send_input(Vector2.ZERO,Vector3.FORWARD,false,false,[0,0,0,0,0,1,0,0,0,0,0,0],0,false)
		await create_timer(.05).timeout
	var view: FrontierSpaceCombatView=app.flight.combat_view
	check(view.audio.last_played.has("sfx_ship_missile_launch_v2"),"actual weapon launch plays the new missile stream")
	check(view.audio.last_played.has("sfx_ship_missile_blast_v2"),"actual missile impact plays the new blast stream")
	authority.resolve_autonomous(true);world=authority.world;nav=world.crew.navigation;record=FrontierSpaceCombat.record(world)
	var encounter: Dictionary=record.encounter
	enemy=encounter.enemies[0];enemy.hull=enemy.maximum_hull;enemy.shield=enemy.maximum_shield
	encounter.phase="combat";encounter.resume=0;encounter.projectiles=[]
	origin=FrontierSpaceCombat.point(nav.position);nav.direction=[0,0,-1];nav.up=[0,1,0];nav.speed=500;nav.hull=100;nav.impact_velocity=[0,0,0]
	record.ships.crew.shield=FrontierVesselSkills.shield_max(world)
	enemy.position=FrontierSpaceCombat.arr(origin+Vector3.FORWARD*90);enemy.direction=[0,0,1];enemy.up=[0,1,0];enemy.velocity=[0,0,500];enemy.impact_velocity=[0,0,0]
	FrontierSpaceCombatPilot.phase(enemy,"approach",1)
	record.flights.crew.position=nav.position.duplicate();app.session._publish()
	for i in 12:
		app.session.send_input(Vector2.ZERO,Vector3.FORWARD,false,false,[0,0,0,0,0,1,0,0,0,0,0,0],0,false)
		await create_timer(.025).timeout
		if i==5:await capture("hull-contact-live")
	record=FrontierSpaceCombat.record(authority.world)
	check(record.events.any(func(e):return e.kind=="collision"),"normal host flight resolves a head-on contact")
	check(view.audio.last_played.has("sfx_ship_hull_collision"),"hull contact plays its dedicated impact stream")
	await capture("hull-separated-live")
	await create_timer(1.2).timeout
	recorder.set_recording_active(false);recorder.get_recording().save_to_wav(folder+"/combat-live-sfx.wav");AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	view.update(.1,true)
	check(view.audio.get_children().all(func(p):return not (p is AudioStreamPlayer or p is AudioStreamPlayer3D) or not p.playing),"menus stop missile and collision voices")
	check(await app.session.close_session(),"modified navigation saves through the current session")
	app.queue_free();await process_frame
	print("COLLISION_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

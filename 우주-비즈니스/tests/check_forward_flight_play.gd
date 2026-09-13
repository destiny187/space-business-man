extends "res://tests/test_solo_entry.gd"
const SAVE_FOLDER="/tmp/space-forward-flight"
var combat_system:=0
func controls(throttle: float=0,roll_axis: float=0,brake: float=0,precision: float=0,shoot: float=0,missile: float=0) -> Array:
	return [throttle,0,0,0,shoot,1,missile,roll_axis,brake,precision]
func fly(input: Array,seconds: float) -> void:
	for i in ceili(seconds/.05):
		var aim: Vector3=-app.flight.camera.global_basis.z
		if input[4]>.5 or input[6]>.5:
			var encounter:=FrontierSpaceCombat.record(app.session.authority.world).get("encounter",{}) as Dictionary
			var best:=.94
			for enemy in encounter.get("enemies",[]):
				var ray: Vector3=(FrontierSpaceCombat.point(enemy.position)-app.flight.camera.global_position).normalized()
				var alignment:=ray.dot(FrontierSpaceCombat.point(app.session.authority.world.crew.navigation.direction))
				if alignment>best and enemy.hull>0:best=alignment;aim=ray
		app.session.send_input(Vector2.ZERO,aim,false,false,input)
		await create_timer(.05).timeout
func run() -> void:
	if "--crew-folder="+SAVE_FOLDER not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../output/forward-flight/play");DirAccess.make_dir_recursive_absolute(folder);DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.title="전진 비행 조작 확인"
	var owner:=FrontierPlayerProfile.new_character("비행 조작 확인",0);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
	var world: Dictionary=core.world
	for index in range(1000,90000,1000):
		if FrontierSpaceCombat.tier(world,index)>=2:combat_system=index;break
	var nav: Dictionary=world.crew.navigation;nav.erase("solar_opening");nav.mode="idle";nav.manual=true;nav.system=combat_system;nav.target=FrontierUniverse.first_ordinal(world.manifest,combat_system);nav.direction=[0,0,-1];nav.up=[0,1,0];nav.speed=0;nav.first_stellar_system=1
	world.location=FrontierUniverse.body_id(world.manifest,int(nav.target));world.navigation_target=world.location
	for i in range(10,60):
		var p:=Vector3(0,i*400,0)
		if FrontierSpaceCombat.clear_position(world,combat_system,p,2000):nav.position=FrontierSpaceCombat.arr(p);break
	world.flight_position=nav.position.duplicate();world.crew.landing={}
	var profile:=FrontierPlayerProfile.new(SAVE_FOLDER+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	check(FrontierWorldStore.new(SAVE_FOLDER+"/world.json").write(world),"write isolated flight fixture")
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition loads",50):quit(1);return
	app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.close_menus();app.outside=true;app.exterior_view.show();app.if_flight_view();app.cursor_released=false;app.mouse_resume_guard=false;app.test_mode=false;root.grab_focus()
	if not root.has_focus():check(app.collect_flight_controls()==FrontierCrewNavigation.stopped_input() and not app.orbital_scan_allowed(),"unfocused window blocks live flight and orbital input")
	# Render normal session simulation using host input. Native focus is never bypassed.
	app.test_mode=true;app.set_physics_process(false);app.set_process(false);app.flight.presentation_blocked=false
	var ship_id:=app.flight.ship.get_instance_id();var system_art_id:=app.flight.system_art.get_instance_id()
	await fly(controls(1),.8)
	var speed:=float(app.session.authority.world.crew.navigation.speed);await fly(controls(),.45)
	check(speed>40 and absf(float(app.session.authority.world.crew.navigation.speed)-speed)<1,"host throttle accelerates and release coasts")
	await fly(controls(-1),1.4);check(app.session.authority.world.crew.navigation.speed==0,"host deceleration stops without reverse")
	await fly(controls(0,1),.65)
	check(absf(app.flight.ship.basis.y.x)>.5,"host roll visibly rotates the current ship")
	check(app.flight.drive.attitude_jets.slice(6).any(func(jet):return jet.emitting) and float(app.flight.vessel_sound.gains.attitude)>.05,"roll plays attitude thrusters and existing ElevenLabs sound")
	await capture("roll-left");await fly(controls(0,-1),.35)
	check(ship_id==app.flight.ship.get_instance_id() and system_art_id==app.flight.system_art.get_instance_id(),"roll reuses ship and celestial model nodes")
	await fly(controls(-1,0,0,1),1.1)
	check(float(app.session.authority.world.crew.navigation.speed)<0 and float(app.session.authority.world.crew.navigation.speed)>=-18.01,"precision reverse is limited")
	await fly(controls(0,0,1),.4)
	app.open_menu(app.navigation_ui.pause_frame);app.test_mode=false
	check(app.collect_flight_controls()==FrontierCrewNavigation.stopped_input() and not app.orbital_scan_allowed(),"open menu blocks roll, shots and scans while braking")
	app.test_mode=true;app.close_menus();app.mouse_resume_guard=false
	# Start the ordinary host encounter at this location; no enemy transforms are animated by this check.
	var authority: FrontierCrewAuthority=app.session.authority
	nav=authority.world.crew.navigation;nav.direction=[0,0,-1];nav.up=[0,1,0];nav.speed=0
	check(FrontierSpaceCombat.begin(authority.world,"crew","local_transit"),"current expedition starts a local pirate encounter")
	var encounter: Dictionary=FrontierSpaceCombat.record(authority.world).encounter;encounter.warning=.1;encounter.resume=0;app.session._publish()
	await fly(controls(0,0,0,0,1,1),.5);await capture("forward-attack")
	await fly(controls(1),.8);await fly(controls(-1),.4)
	await fly(controls(0,0,1),.6)
	var samples: Array=[]
	for i in 40:
		if not FrontierSpaceCombat.record(authority.world).encounter.is_empty():
			var e: Dictionary=FrontierSpaceCombat.record(authority.world).encounter
			for enemy in e.enemies:samples.append({"time":e.elapsed,"id":enemy.id,"phase":enemy.get("maneuver",""),"position":enemy.position.duplicate(),"direction":enemy.direction.duplicate(),"velocity":enemy.get("velocity",[]).duplicate()})
		if i==10:await capture("banked-pass")
		await fly(controls(),.15)
	check(app.flight.combat_view.models.size()>=3 and app.flight.combat_view.audio.last_played.has("sfx_gun_ship_pulse"),"live battle renders enemy craft and plays player cannon")
	check(FrontierSpaceCombat.record(authority.world).events.any(func(event):return event.kind=="missile_launch" and event.id=="crew") and app.flight.combat_view.audio.last_played.has("sfx_ship_missile_launch"),"extended input dispatches player missiles and their sound")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("combat-960")
	FileAccess.open(folder+"/enemy-motion.json",FileAccess.WRITE).store_string(JSON.stringify(samples))
	await fly(controls(0,1),.35)
	var saved_up: Array=authority.world.crew.navigation.get("up",[]).duplicate()
	check(await app.session.close_session(),"normal close saves rolled navigation and encounter")
	var restored:=FrontierWorldStore.new(SAVE_FOLDER+"/world.json").read_state()
	check(not restored.is_empty() and restored.crew.navigation.get("up",[])==saved_up,"disk reload preserves ship orientation")
	app.queue_free();await process_frame;await process_frame
	print("FORWARD_FLIGHT_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

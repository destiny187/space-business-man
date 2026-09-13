extends "res://tests/test_solo_entry.gd"
const SAVE_FOLDER="/tmp/space-vessel-interiors"
var host: FrontierCrewSession
var owner: Dictionary

func key(code: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	app._input(event)

func run() -> void:
	if "--crew-folder="+SAVE_FOLDER not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../output/vessel-interiors/game");DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	owner=FrontierPlayerProfile.new_character("관전 호스트",0)
	var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
	var world: Dictionary=core.world
	world.crew.navigation.erase("solar_opening");world.crew.navigation.speed=0;world.crew.navigation.manual=true
	world.business=FrontierExpeditionBusiness.create()
	world.vessel=FrontierVesselRefit.create(int(world.manifest.seed),world.crew.world_id);world.vessel.hulls=FrontierSpaceStation.config().hulls.keys();world.vessel.hull="kestrel"
	var remote:=world.duplicate();remote.crew=world.crew.duplicate();remote.crew.members=world.crew.members.duplicate()
	remote.crew.members[owner.character_id]=world.crew.members[owner.character_id].duplicate();remote.crew.members[owner.character_id].shuttle_id=owner.character_id
	var shuttle: Dictionary={"navigation":world.crew.navigation.duplicate(true),"navigation_target":world.get("navigation_target",world.location),"landing":{},"cargo":{},"cargo_equipment":{},"rock":0,"location":world.location}
	shuttle.navigation.position=[120,20,-80];remote.crew.shuttles={owner.character_id:shuttle}
	var descriptor:=FrontierCrewObservation.snapshot(remote)
	check(descriptor.shuttle and descriptor.navigation.position==shuttle.navigation.position and descriptor.navigation.position!=world.crew.navigation.position,"host descriptor follows independent FINCH instead of main ship")
	shuttle.landing={"body_id":world.location};check(FrontierCrewObservation.snapshot(remote).is_empty(),"ground host emits no flight observer descriptor")
	var store:=FrontierWorldStore.new(SAVE_FOLDER+"/host-world.json")
	check(store.write(world),"isolated host world saves")
	if failures:printerr(store.last_error);quit(1);return
	var host_profile:=FrontierPlayerProfile.new(SAVE_FOLDER+"/host-profile.json");host_profile.data={"version":1,"character":owner,"sessions":{}};host_profile.save()
	for side in ["Host","Guest"]:
		var branch:=Node.new();branch.name=side;root.add_child(branch)
		var api:=SceneMultiplayer.new();set_multiplayer(api,branch.get_path())
		if side=="Host":
			var expedition:=Node.new();expedition.name="Expedition";branch.add_child(expedition)
			host=FrontierCrewSession.new();host.name="Coop";expedition.add_child(host)
		else:
			app=load("res://scenes/app/crew_expedition.tscn").instantiate();app.name="Expedition";branch.add_child(app)
	await process_frame
	host.notice.connect(func(message):print("HOST_NOTICE ",message))
	app.session.notice.connect(func(message):print("GUEST_NOTICE ",message))
	check(host.host(host_profile,store,24783,"127.0.0.1"),"local ENet host starts")
	if failures:printerr(store.last_error);quit(1);return
	host.set_physics_process(false);host.authority.phase="playing"
	var guest:=FrontierPlayerProfile.new(SAVE_FOLDER+"/profile.json");guest.data={"version":1,"character":FrontierPlayerProfile.new_character("관전 승무원",1),"sessions":{}};guest.save()
	check(app.session.join(guest,"127.0.0.1",24783),"actual guest joins host")
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"guest receives playable world and live host view",90):
		printerr("OBSERVER_ENTRY_DIAGNOSTIC ",app.session.active," ",app.session.latest.get("phase")," ",host.authority.peers," ",host.authority.error," flight=",app.flight!=null," preparing=",app.preparing_first_snapshot)
		quit(1);return
	app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.close_menus()
	app.test_camera_position=Vector3(0,1.8,3.6);app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var actor_node: int=app.actors[app.session.latest.self_id].get_instance_id()
	var station_node:=app.stations.cabin.get_instance_id()
	var solid:=app.interior.get_child(0).get_instance_id()
	var positions: Dictionary={}
	for id in host.authority.world.crew.members:positions[id]=host.authority.world.crew.members[id].position.duplicate()
	for hull in FrontierVesselInterior.config().hulls:
		host.authority.world.vessel.hull=hull;host._publish()
		if not await until(func():return app.interior.hull_id==hull,"interior changes with host hull "+hull,15):quit(1);return
		app.yaw=0;app.pitch=.04
		await capture(hull+"-front")
		check(app.interior.room.find_child("WindowPanes",true,false)!=null,"authored windows exist "+hull)
	var count: int=app.interior.rebuilds
	var moving_before: Vector3=app.interior.parts[0].position
	host._publish();await create_timer(.3).timeout
	check(app.interior.cache.size()<=12 and app.interior.parts[0].position!=moving_before,"current shell bounds material cache and animates authored gantry")
	check(count==app.interior.rebuilds and actor_node==app.actors[app.session.latest.self_id].get_instance_id() and station_node==app.stations.cabin.get_instance_id() and solid==app.interior.get_child(0).get_instance_id(),"unchanged snapshot preserves shell; swaps preserve actor/stations/collisions")
	check(positions.keys().all(func(id):return positions[id]==host.authority.world.crew.members[id].position),"hull appearance changes preserve crew save positions")
	app.test_camera_position=Vector3(0,1.8,-.8);app.yaw=PI*.5;app.pitch=.08;await capture("atlas-port")
	check(app.flight.cabin_camera and app.flight.camera.basis.is_equal_approx(app.camera.basis) and is_equal_approx(app.flight.camera.fov,app.camera.fov),"side windows share real head projection")
	app.pitch=1.13;await capture("atlas-zenith")
	app.test_camera_position=Vector3(0,1.8,1);app.pitch=0;app.yaw=PI;await capture("atlas-aft")
	app.test_camera_position=Vector3.ZERO
	var pilot: String=host.authority.world.crew.pilot_id
	var own: String=app.session.latest.self_id
	host.authority.world.crew.pilot_id=own;host._publish();await create_timer(.3).timeout
	key(KEY_F8)
	if not await until(func():return app.observer.active and not app.observer.view.navigation.is_empty(),"F8 enters host reference camera on real guest",20):quit(1);return
	app.observer.view.presentation_blocked=false;app.observer.set_process(false)
	var nav_before: Dictionary=host.authority.world.crew.navigation.duplicate(true)
	var actor_before: Array=host.authority.world.crew.members[own].position.duplicate()
	var requests: int=app.session.next_sequence
	var saved_yaw:=app.yaw
	app._mouse_look(Vector2(900,-100),.004,false)
	check(app.yaw==saved_yaw and app.mouse_steering==Vector2.ZERO and absf(app.observer.view.look_offset.x)>2,"guest freely orbits beyond rear without pilot steering")
	app.observer.look(Vector2(.5,0));app.observer.zoom(-1)
	await capture("guest-observer")
	check(not app.observer.view.combat_view.armed() and app.collect_flight_controls()==FrontierCrewObservation.neutral_input(),"delegated pilot also sends no flight, brake or attack controls while observing")
	check(app.feedback.audio.last_played.has("sfx_pickup_resource"),"camera entry reuses ElevenLabs confirmation sound")
	var rejected:=InputEventKey.new();rejected.physical_keycode=KEY_R;rejected.pressed=true;app._input(rejected)
	app._input(rejected);await create_timer(.2).timeout
	var peer: int=app.session.enet.get_unique_id()
	check(not host.authority.inputs[peer].controls_enabled and host.authority.inputs[peer].direction==Vector2.ZERO,"actual movement RPC carries disabled idle input")
	check(host.authority.inputs[peer].flight_controls.all(func(axis):return is_zero_approx(float(axis))),"observer does not send the usual menu safety brake through RPC")
	check(nav_before==host.authority.world.crew.navigation and actor_before==host.authority.world.crew.members[own].position and requests==app.session.next_sequence,"observer input changes no navigation, actor, or action requests")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("guest-observer-960")
	check(app.observer.caption.get_global_rect().position.x>=0 and app.observer.caption.get_global_rect().end.x<=960,"observer hint fits small viewport")
	key(KEY_F8);check(not app.observer.active and app.ui.visible and not app.outside,"F8 restores original cabin view")
	app.observer.set_process(true);await process_frame
	key(KEY_F8);key(KEY_ESCAPE);check(not app.observer.active,"Escape exits observer")
	key(KEY_F8)
	var unavailable: Dictionary=app.session.latest.duplicate();unavailable.host_view={};app.observer.update_snapshot(unavailable)
	check(not app.observer.active,"host landing or unavailable descriptor returns guest view")
	check(not FrontierCrewObservation.available(app.session.latest,true),"host cannot enter guest observer")
	host.authority.world.crew.pilot_id=pilot
	check(await app.session.close_session(),"guest disconnects normally")
	check(await host.close_session(),"host closes and saves normally")
	var restored:=store.read_state();check(not restored.is_empty() and not restored.has("host_view") and restored.vessel.hull=="atlas","camera state is absent from save while last hull persists")
	for child in root.get_children():child.queue_free()
	await process_frame;await process_frame
	print("VESSEL_INTERIOR_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

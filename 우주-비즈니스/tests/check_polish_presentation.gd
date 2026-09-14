extends "res://tests/test_solo_entry.gd"
const CrewStatus=preload("res://scripts/ui/crew_status.gd")
const Numbers=preload("res://scripts/actors/firearm_damage_numbers.gd")
var host: FrontierCrewSession
var results: Array=[]
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("호스트",0);var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"isolated host prepared")
	var world: Dictionary=core.world;world.crew.navigation.erase("solar_opening");world.crew.navigation.speed=0;world.crew.navigation.manual=true
	world.business=FrontierExpeditionBusiness.create();world.crew.cargo.iron=10
	var store:=FrontierWorldStore.new(folder+"/host-world.json");check(store.write(world),"host preparation validates")
	var hp:=FrontierPlayerProfile.new(folder+"/host-profile.json");hp.data={"version":1,"character":owner,"sessions":{}};hp.save()
	for side in ["Host","Guest"]:
		var branch:=Node.new();branch.name=side;root.add_child(branch);set_multiplayer(SceneMultiplayer.new(),branch.get_path())
		if side=="Host":
			var expedition:=Node.new();expedition.name="Expedition";branch.add_child(expedition);host=FrontierCrewSession.new();host.name="Coop";expedition.add_child(host)
		else:app=load("res://scenes/app/crew_expedition.tscn").instantiate();app.name="Expedition";branch.add_child(app)
	await process_frame
	host.notice.connect(func(message):print("HOST_NOTICE ",message))
	app.session.notice.connect(func(message):print("GUEST_NOTICE ",message))
	check(host.host(hp,store,24893,"127.0.0.1"),"real loopback host starts")
	host.set_physics_process(false);host.authority.phase="playing"
	var guest:=FrontierPlayerProfile.new(folder+"/profile.json");guest.data={"version":1,"character":FrontierPlayerProfile.new_character("운송 승무원",1),"sessions":{}};guest.save()
	check(app.session.join(guest,"127.0.0.1",24893),"real guest handshake begins")
	if not await until(func():return app.session.active and app.flight!=null and not app.preparing_first_snapshot,"guest receives live world",100):
		print("JOIN_DIAGNOSTIC active=",app.session.active," latest=",app.session.latest.get("active")," phase=",app.session.latest.get("phase")," flight=",app.flight!=null," preparing=",app.preparing_first_snapshot," peers=",host.authority.peers," stopped=",host.authority.stopped," error=",host.authority.error);quit(1);return
	app.onboarding.letter.hide();app.close_menus();app.set_physics_process(false)
	var settings:=FrontierClientSettings.ensure(self);settings.set_option("tutorial_mode",2);settings.set_option("music_volume",0)
	app.session.response_received.connect(func(_seq: int,result: Dictionary):results.append(result))
	var id: String=app.session.latest.self_id;var peer:=app.session.enet.get_unique_id()
	var locker:=FrontierCrewWorld.vector(FrontierCrewWorld.config().locker_position)
	host.authority.update_position(peer,locker);host._publish();await create_timer(.3).timeout
	var credits: int=host.authority.world.business.credits
	app.session.send_request("withdraw",{"resource":"iron","amount":3})
	await until(func():return not results.is_empty(),"shared cargo request returns",10)
	check(results.back().get("ok",false) and int(host.authority.world.crew.cargo.iron)==7 and int(host.authority.world.business.bags[id].iron)==3,"one confirmed shared transfer moves exact quantities")
	app.session.send_request("ready",{"value":true})
	await until(func():return app.session.latest.crew.members[id].ready,"guest readiness confirmed",10)
	app.open_menu(app.navigation_ui.crew_frame);await capture("crew-1280")
	check(app.roster.text.contains("선내") and app.navigation_ui.departure_status.text.contains("호스트"),"crew roster names location and actual departure blocker")
	var fake:=app.session.latest.duplicate(true);fake.crew.members[owner.character_id].shuttle_id=owner.character_id
	check(CrewStatus.blockers(fake).is_empty(),"independent FINCH does not block common vessel")
	var loadout: Dictionary=host.authority.world.crew.members[id].loadout.duplicate(true)
	var previous_position: Array=host.authority.world.crew.members[id].position.duplicate()
	check(await app.session.close_session(),"guest disconnects normally")
	await until(func():return id not in host.authority.peers.values(),"host observes disconnect",10)
	var disconnected_bag: Dictionary=host.authority.world.business.bags[id].duplicate()
	var recovery: Dictionary=host.authority.world.business.crates.duplicate(true)
	check(recovery.values().any(func(crate):return int(crate.inventory.get("iron",0))==3),"disconnect keeps existing recoverable freight rule")
	check(app.session.join(guest,"127.0.0.1",24893),"same saved guest rejoins")
	await until(func():return app.session.active and app.session.latest.self_id==id,"rejoin restores same identity",60)
	check(host.authority.world.crew.members[id].loadout==loadout and host.authority.world.crew.members[id].position==previous_position and host.authority.world.business.bags[id]==disconnected_bag and host.authority.world.business.crates==recovery and int(host.authority.world.crew.cargo.iron)==7 and int(host.authority.world.business.credits)==credits,"rejoin preserves equipment location freight recovery and shared ledger")
	app.onboarding.letter.hide();app.close_menus();app.open_menu(app.navigation_ui.crew_frame)
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("crew-rejoined-960")
	# Mixer checks use current ElevenLabs assets and a real SFX recording.
	var library:=FrontierAudio.new();root.add_child(library);var mix:=FrontierAudioMix.ensure(self)
	var render_count:=settings.node_applications;settings.set_option("sfx_volume",.45);settings.set_option("ambient_volume",.35)
	check(settings.node_applications==render_count and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))),.45),"effects gain changes only its audio bus")
	var population: Dictionary={"environment":{"ecology":0},"external_ambience":true,"player":{"position":[0,0]},"robots":[],"events":[],"buildings":[]}
	for i in range(15,0,-1):population.robots.append({"id":"audiorobot:"+str(i),"position":[i,0],"status":"창고로 운반"})
	library.update_world(population,false)
	check(library.emitters.size()==12 and library.emitters.has("audiorobot:1") and not library.emitters.has("audiorobot:15"),"nearest 12 industrial loops include loaded transport")
	library.update_world(population,false);check(library.emitters.size()==12,"identical snapshots reuse loop emitters")
	var recorder:=AudioEffectRecord.new();var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
	library.play("sfx_gun_carbine",Vector3.INF,1,-6,"firearm_shot");await create_timer(.25).timeout
	library.play("sfx_shield_break");await create_timer(.2).timeout
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Industry"))<0 and is_equal_approx(mix.effects_gain,.45),"warning ducks loops while retaining user effect gain")
	await create_timer(.6).timeout;recorder.set_recording_active(false)
	var recording:=recorder.get_recording();check(recording!=null and not recording.data.is_empty(),"existing gun and shield sound reaches recorded output")
	if recording!=null:recording.save_to_wav(folder+"/mix.wav")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	check(is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Industry"))),"warning mix returns to original level")
	library.update_world(population,true);check(library.emitters.values().all(func(node):return node.stream_paused),"menu pauses active machinery without queuing old events")
	library.queue_free();settings.set_option("sfx_volume",1);settings.set_option("ambient_volume",1)
	# Render existing authored body and bounded combat clocks; authority speed/contact is checked separately.
	app.close_menus();app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var actor:=preload("res://scripts/actors/creatures/bestiary_actor.gd").new();root.add_child(actor);actor.configure(FrontierEcologyCatalog.form("biota_spindle_armor_25"));actor.position=Vector3(0,0,-3)
	app.camera.position=Vector3(0,2,5);app.camera.look_at(actor.position+Vector3.UP);app.set_process(false)
	var profile: Dictionary={"pattern":"slam","windup":.7,"active":.3,"recovery":1.0,"behavior":"melee"}
	var live: Dictionary={"phase":"attack","time":.66,"serial":1}
	actor.apply_combat(live,profile,false);actor._process(.06)
	check(actor.combat_clock>.66 and actor.combat_clock<.7,"snapshot gap smooths preparation without predicting contact")
	var clock_value:=actor.combat_clock;actor.apply_combat(live,profile,false);check(actor.combat_clock==clock_value,"same snapshot does not rewind the displayed windup")
	await capture("windup-960")
	live.time=.81;actor.apply_combat(live,profile,false);actor._process(.08)
	check(actor.combat_clock<.835,"melee contact threshold waits for confirmed host clock")
	live.time=.9;actor.apply_combat(live,profile,false);actor._process(.02)
	check(actor.combat_clock>=.9 and actor.combat_clock<=.98,"confirmed contact opens active pose")
	await capture("contact-960")
	actor.apply_combat(live,profile,true);actor._process(.4);check(actor.combat_clock==.9,"paused actor does not advance combat animation")
	actor.queue_free()
	var numbers:=Numbers.new();var hud:=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);app.ui.add_child(hud)
	var targets: Array=[]
	for i in 12:targets.append({"id":"cluster:"+str(i),"anchor":[0,1,-3],"damage":10+i,"shield":2,"broken":i==0})
	numbers.add(targets);hud.draw.connect(func():numbers.draw(hud,app.camera,false));hud.queue_redraw();await capture("damage-cluster-960")
	check(numbers.last_bounds.size()==12,"clustered confirmed numbers remain distinct")
	var safe:=Rect2(24,24,912,592);var collision:=false
	for i in numbers.last_bounds.size():
		if not safe.encloses(numbers.last_bounds[i]):collision=true
		for j in i:
			if numbers.last_bounds[i].intersects(numbers.last_bounds[j]):collision=true
	check(not collision,"numbers stay in viewport without overlap")
	hud.queue_free()
	settings.open();settings.tabs.current_tab=2;await capture("audio-settings-960");settings.close()
	app.session.active=false;app.navigation_ui._session_notice("저장 실패 표시 검사")
	check(app.navigation_ui.pause_frame.visible and app.navigation_ui.session_problem.visible,"stopped session keeps visible save retry and exit controls")
	await capture("session-stopped-960");app.session.active=true;app.close_menus()
	check(await app.session.close_session(),"guest closes after presentation checks")
	check(await host.close_session(),"host persists shared final ledger")
	for node in root.get_children():node.queue_free()
	await process_frame;await process_frame
	print("POLISH_PRESENTATION checks=",checks," failures=",failures);quit(1 if failures else 0)

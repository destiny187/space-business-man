extends "review_ground_weapon_feedback.gd"
## Small, isolated real-window capture of authoritative damage numbers and cracks.
func run() -> void:
	folder="/tmp/ground-damage-numbers"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or ("--crew-folder="+folder) not in OS.get_cmdline_user_args():quit(2);return
	var owner: Dictionary
	if "--resume-fixture" in OS.get_cmdline_user_args():
		core=FrontierCrewAuthority.new();core.world=FrontierWorldStore.new(folder+"/world.json").read_state()
		owner=JSON.parse_string(FileAccess.get_file_as_string(folder+"/profile.json")).character;actor_id=owner.character_id
		for key in core.world.incidents.records:
			if core.world.incidents.records[key].template=="illuti_dormant_combat_robot":robot_key=key;source=core.world.incidents.records[key];break
	else:owner=fixture()
	if owner.is_empty():quit(1);return
	# A valid owned generator is part of this feedback fixture; crafting is not under review.
	var suit_owner: Dictionary=core.world.crew.members[actor_id]
	suit_owner.modules=FrontierSuitModules.create()
	suit_owner.modules.items["module:starter"]={"slot":"defense","tier":1,"rarity":"common","affixes":{},"seed":0,"source":"starter"}
	suit_owner.modules.equipped.defense="module:starter";suit_owner.modules.starter=true;suit_owner.modules.revision=2
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"isolated fixture saved: "+store.last_error)
	if not store.last_error.is_empty():quit(1);return
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	# Bounded view for close-range feedback review; this does not save user settings.
	FrontierClientSettings.ensure(self).values.view_distance=1200.0
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ ground loaded",90):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	core=app.session.authority
	var approach:=FrontierCrewWorld.vector(source.position)+Vector3(0,0,9);approach.y=app.surface_world.terrain.field.height(approach.x,approach.z)+.1
	app.actors[actor_id].position=approach;app.actors[actor_id].velocity=Vector3.ZERO;core.update_position(1,approach);core.motions[actor_id]=FrontierCrewLocomotion.create()
	if not await until(func():return app.surface_world.ready_at(app.actors[actor_id].position) and app.surface_world.incidents.models.has(robot_key) and core.inputs[1].get("controls_enabled",false),"ground, model and host input ready",120):
		print("READINESS ",{"ground":app.surface_world.ready_at(app.actors[actor_id].position),"models":app.surface_world.incidents.models.keys(),"expected":robot_key,"input":core.inputs.get(1,{}),"menus":app.feedback.blocked(),"position":app.actors[actor_id].position,"source":source.position})
		await capture("readiness-failure")
		quit(1);return
	await create_timer(.5).timeout
	var record:=AudioEffectRecord.new();record.format=AudioStreamWAV.FORMAT_16_BITS
	var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,record);record.set_recording_active(true);started=Time.get_ticks_msec()
	if "--own-only" in OS.get_cmdline_user_args():
		await own_shield_checks();await finish_review(record,bus);return
	reset_robot(120,30)
	var expected:=0.0
	for n in 3:
		core.world.incidents.records[robot_key].phase="waking";core.world.incidents.records[robot_key].time=0
		look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.5,0)));await create_timer(.18).timeout
		app.firearm.shoot()
		var event: Dictionary=core.world.crew.members[actor_id].weapon_event
		var targets: Array=event.get("damage_targets",[])
		check(targets.size()==1,"one actual target per shot "+str(n))
		if targets.is_empty():quit(1);return
		expected+=float(targets[0].damage)+float(targets[0].shield)
		check(app.firearm.damage_numbers.entries.size()==1 and is_equal_approx(float(app.firearm.damage_numbers.entries[0].amount),expected),"consecutive confirmed damage stacks "+str(n))
		timeline.append({"at":float(Time.get_ticks_msec()-started)/1000,"targets":targets,"stack":expected})
		await capture("stack-"+str(n))
		await create_timer(.06).timeout
	check(app.firearm.damage_numbers.entries[0].broken and app.feedback.audio.last_played.has("sfx_gun_break"),"shield transition keeps broken icon and crack audio")
	await create_timer(1.0).timeout
	check(app.firearm.damage_numbers.entries.is_empty(),"damage stack expires")
	# One shot simultaneously depletes the remaining shield and health.
	reset_robot(1,1);look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.5,0)));await create_timer(.18).timeout
	app.firearm.shoot();await capture("break-and-defeat")
	var event: Dictionary=core.world.crew.members[actor_id].weapon_event
	check(event.hits.broken and event.hits.killed and is_equal_approx(float(app.firearm.damage_numbers.entries[0].amount),2.0),"actual remaining damage excludes overkill")
	check(app.firearm.hit_kind=="kill" and app.firearm.shield_break_left>0 and app.feedback.audio.last_played.has("sfx_gun_break_down"),"simultaneous defeat preserves crack picture and sound")
	await create_timer(1.1).timeout
	for id in FrontierEquipment.config().items:
		if FrontierEquipment.config().items[id].get("firearm")=="shotgun":app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:"+id});break
	await create_timer(.3).timeout
	reset_robot(120,60);look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.5,0)));await create_timer(.18).timeout
	app.firearm.shoot();await capture("shotgun-total")
	event=core.world.crew.members[actor_id].weapon_event
	check(event.family=="shotgun" and event.rays.size()>1 and event.damage_targets.size()==1 and is_equal_approx(float(event.damage_targets[0].damage)+float(event.damage_targets[0].shield),float(event.hits.damage)+float(event.hits.shield)),"shotgun pellets coalesce into one real total")
	await create_timer(1.15).timeout
	app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:pulse_2"});await create_timer(.3).timeout
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	reset_robot(120,0);core.world.incidents.records[robot_key].phase="cooling";core.world.incidents.records[robot_key].time=0
	app.firearm.test_ads=true;look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.98,.52)));await create_timer(.22).timeout
	app.firearm.shoot();await capture("weak-960")
	check(app.firearm.damage_numbers.entries.size()==1 and app.firearm.hit_kind=="weak","weak point number on small window")
	app.open_menu(app.inventory_panel);await create_timer(.1).timeout
	check(app.firearm.damage_numbers.entries.is_empty() and app.firearm.shield_break_left==0,"menu clears all numbers and crack markers")
	app.close_menus();app.firearm.test_ads=false;app.pitch=1.2;await create_timer(.22).timeout;app.firearm.shoot()
	check(core.world.crew.members[actor_id].weapon_event.damage_targets.is_empty() and app.firearm.damage_numbers.entries.is_empty(),"miss has no number")
	await own_shield_checks();await finish_review(record,bus)

func own_shield_checks() -> void:
	# Exercise the same host vitals path used by enemy hits, with an equipped shield.
	var member: Dictionary=core.world.crew.members[actor_id]
	check(FrontierSuitModules.shield_max(member)==30,"fixture generator is equipped")
	var vitals:=FrontierCrewVitals.ensure(member);vitals.protection=0;vitals.shield=12;vitals.shield_wait=5
	await create_timer(.22).timeout
	# Authority transactions replace dictionaries, so do not retain a member across awaits.
	var at:=Time.get_ticks_msec();FrontierCrewVitals.damage(core.world.crew.members[actor_id],4)
	await until(func():return int(app.feedback.audio.last_played.get("sfx_gun_hit_shield",0))>=at,"own shield hit has its own sound",2)
	await create_timer(.2).timeout
	at=Time.get_ticks_msec();FrontierCrewVitals.damage(core.world.crew.members[actor_id],10)
	await until(func():return app.field_hud.instruments.shield_crack>0,"own shield breaks on host vitals result",2)
	await capture("own-shield-crack")
	check(int(app.feedback.audio.last_played.get("sfx_gun_break",0))>=at and core.world.crew.members[actor_id].vitals.shield==0,"own break plays crack instead of build rejection")
	timeline.append({"own_break_at":float(at-started)/1000.0})

func finish_review(record: AudioEffectRecord,bus: int) -> void:
	await create_timer(.5).timeout;record.set_recording_active(false)
	var mixed:=record.get_recording();check(mixed!=null and mixed.get_length()>.3,"actual SFX output captured")
	var prefix: String="own-" if "--own-only" in OS.get_cmdline_user_args() else ""
	if mixed!=null:mixed.save_to_wav(folder+"/"+prefix+"runtime-mix.wav")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var file:=FileAccess.open(folder+"/"+prefix+"timeline.json",FileAccess.WRITE);file.store_string(JSON.stringify(timeline,"\t"));file.close()
	check(await app.session.close_session(),"isolated updated event save closes: "+app.session.store.last_error)
	app.queue_free();await process_frame;await process_frame
	print("GROUND_DAMAGE_REVIEW ",checks," FAILURES ",failures);quit(1 if failures else 0)

func until(condition: Callable,label: String,seconds: float=60) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call():check(true,label);return true
		await create_timer(.1).timeout
	# A terrain upload can finish in the same long frame that crosses the deadline.
	var ready: bool=condition.call();check(ready,label);return ready

func capture(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label+".png")

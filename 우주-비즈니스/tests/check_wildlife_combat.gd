extends "res://tests/test_solo_entry.gd"
var owner: Dictionary
var core: FrontierCrewAuthority
var actor_id: String
var chosen: Dictionary={}
var body: Dictionary={}
var key: String
var home: Vector3
var field: FrontierTerrainField
var fixture_construction:="canid"
var animal: Node3D
func fixture() -> bool:
	owner=FrontierPlayerProfile.new_character("토착 생물 교전 확인",0);actor_id=owner.character_id
	core=FrontierCrewAuthority.new()
	if not core.start(FrontierUniverse.new_world(71503),owner,func(_world):return true):return false
	var world: Dictionary=core.world
	var count:=0
	for ordinal in world.manifest.native_biota.planets:
		var source: Dictionary=world.manifest.native_biota.planets[ordinal]
		if source.origin!="established":continue
		var suitable:=false
		for lineage in source.lineages:
			var form:=FrontierEcologyCatalog.form(lineage.form_id)
			if form.get("construction","")==fixture_construction and FrontierWildlifeCombat.profile(lineage).nature=="proactive":suitable=true
		if not suitable:continue
		body=FrontierUniverse.body(world.manifest,int(ordinal))
		var ecology:=FrontierEcology.create();var record:=FrontierEcology.ensure_planet(ecology,body)
		field=FrontierExplorationIncidents.field(body)
		for center in [Vector3(40,0,40),Vector3(130,0,60),Vector3(-90,0,90)]:
			for row in FrontierEcologyPlacement.candidates(body,record,center):
				var form:=FrontierEcologyCatalog.form(row.form_id)
				if form.get("construction","")!=fixture_construction or FrontierWildlifeCombat.profile(row).nature!="proactive" or row.layer!="surface":continue
				var at:=FrontierEcologyPlacement.ground(field,row)
				if not at.is_finite() or FrontierEcology.status(record,form,at,row.layer)!="active":continue
				row.point=at;row.home_point=at;row.status="active";row.body_id=body.id;chosen=row;break
			if not chosen.is_empty():break
		if not chosen.is_empty():break
		count+=1
	if chosen.is_empty():return false
	var nav: Dictionary=world.crew.navigation
	nav.system=body.system_ordinal;nav.target=body.ordinal;nav.mode="idle";nav.erase("solar_opening")
	nav.position=FrontierExplorationIncidents.array(FrontierCrewNavigation.center(body.ordinal,world.manifest,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+2))
	world.vessel=FrontierVesselRefit.create(int(world.manifest.seed),str(world.crew.world_id));world.vessel.navigation_refits={"kestrel":5}
	world.crew.members[actor_id].ready=true;core.phase="playing";world.crew.phase="playing"
	var reason:=FrontierCrewSurface.apply(world,actor_id,"land",{"ordinal":body.ordinal},{1:actor_id})
	check(reason.is_empty(),"natural native home landing "+reason)
	home=chosen.point;key=FrontierWildlifeCombat.key(body.id,chosen)
	var at:=home+Vector3(0,0,4);at.y=field.height(at.x,at.z)+.1
	world.crew.members[actor_id].position=FrontierExplorationIncidents.array(at)
	world.crew.members[actor_id].vitals.protection=0
	world.crew.members[actor_id].loadout.items["fixture:gun"]="pulse_2";world.crew.members[actor_id].loadout.slots[2]="fixture:gun";world.crew.members[actor_id].loadout.selected=2
	print("NATIVE_FIXTURE ",JSON.stringify({"body":body.id,"ordinal":body.ordinal,"row":chosen}))
	return true
func run() -> void:
	folder="/tmp/native-combat-play"
	DirAccess.make_dir_recursive_absolute(folder)
	check(fixture(),"naturally assigned proactive rigged "+fixture_construction)
	if chosen.is_empty():quit(1);return
	if "--play" in OS.get_cmdline_user_args():await play();return
	var world: Dictionary=core.world;var m: Dictionary=world.crew.members[actor_id]
	var info:=FrontierWildlifeCombat.profile(chosen)
	var live:=FrontierWildlifeCombat.ensure(world.crew,body.id,chosen)
	var free:=func(_actor,_row,_from,_to,_radius,_height):return true
	m.position=FrontierExplorationIncidents.array(home+Vector3(0,0,2));live.target=actor_id
	check(FrontierWildlifeCombat.choose(world,chosen,info,[actor_id],field,free)==actor_id,"proactive creature detects player without being shot")
	FrontierWildlifeCombat.set_phase(live,"warning")
	var before:=float(m.vitals.health)
	FrontierWildlifeCombat._step(world,chosen,live,info,[actor_id],field,.5,free)
	check(m.vitals.health==before and live.phase=="warning","warning gives time before damage")
	FrontierWildlifeCombat.set_phase(live,"chase")
	FrontierWildlifeCombat._step(world,chosen,live,info,[actor_id],field,.1,free)
	check(live.phase=="attack","in-range pursuit starts attack")
	FrontierWildlifeCombat._step(world,chosen,live,info,[actor_id],field,float(info.windup)+float(info.active)*.5,free)
	check(m.vitals.health<before,"telegraphed strike damages existing vitals")
	before=m.vitals.health
	FrontierWildlifeCombat._step(world,chosen,live,info,[actor_id],field,.1,free)
	check(m.vitals.health==before,"one attack hits at most once")
	live.struck=false;FrontierWildlifeCombat.set_phase(live,"attack")
	m.position=FrontierExplorationIncidents.array(home+Vector3(3,0,0))
	FrontierWildlifeCombat._step(world,chosen,live,info,[actor_id],field,float(info.windup)+.2,free)
	check(m.vitals.health==before,"sidestep escapes locked attack arc")
	m.position=FrontierExplorationIncidents.array(home+Vector3(0,0,2));live.struck=false;FrontierWildlifeCombat.set_phase(live,"attack")
	FrontierWildlifeCombat._step(world,chosen,live,info,[actor_id],field,float(info.windup)+.2,func(_a,_b,_c,_d,_e,_f):return false)
	check(m.vitals.health==before,"solid obstruction blocks melee damage")
	var cover: Dictionary={"id":"fixture:cover","type":"combat_barricade","position":FrontierExplorationIncidents.array(home+Vector3(0,0,1)),"yaw":0.0}
	FrontierCombatCover.create(cover,0);cover.assembly_left=0
	FrontierExpeditionBusiness.site(world).buildings[cover.id]=cover
	live.struck=false;FrontierWildlifeCombat.set_phase(live,"attack")
	FrontierWildlifeCombat._step(world,chosen,live,info,[actor_id],field,float(info.windup)+.2,free)
	check(m.vitals.health==before,"crafted cover blocks native strike using real cover bounds")
	FrontierExpeditionBusiness.site(world).buildings.erase(cover.id)
	FrontierSuitModules.ensure(m)
	m.modules.items["fixture:shield"]={"slot":"defense","tier":1,"rarity":"common","affixes":{},"seed":1,"source":"discovery"};m.modules.equipped.defense="fixture:shield"
	m.vitals.shield=FrontierSuitModules.shield_max(m);var shield_before:=float(m.vitals.shield)
	live.struck=false;FrontierWildlifeCombat.set_phase(live,"attack")
	FrontierWildlifeCombat._step(world,chosen,live,info,[actor_id],field,float(info.windup)+.2,free)
	check(m.vitals.shield<shield_before and m.vitals.health==before,"native attack consumes equipped shield before health")
	m.modules.items.erase("fixture:shield");m.modules.equipped.erase("defense");m.vitals.shield=0

	m.position=FrontierExplorationIncidents.array(home+Vector3(0,0,35))
	FrontierWildlifeCombat._step(world,chosen,live,info,[actor_id],field,.1,free)
	check(live.phase in ["return","calm"] and live.target=="","leash abandons chase")
	m.position=FrontierExplorationIncidents.array(home+Vector3(0,0,2))
	FrontierWildlifeCombat.hit(world,actor_id,chosen,10)
	check(live.phase=="hurt" and live.provoked,"gun impact interrupts and provokes native animal")
	var old_serial:=int(live.serial);FrontierWildlifeCombat.hit(world,actor_id,chosen,5)
	check(live.serial==old_serial,"rapid fire cannot repeatedly restart stagger")
	var pose:=FrontierWildlifeCombat.pose(field,chosen,home,0,[],world.crew,body.id)
	check(pose.point==FrontierCrewWorld.vector(live.position),"host and model use same combat position")
	check(FrontierCrewWorld.validate(world.crew).is_empty(),"combat state validates for saves")
	check(not FrontierSpecimenItems.collect(world,actor_id,chosen).is_empty(),"active threat cannot bypass combat through specimen capture")
	var calm_info:=info.duplicate();calm_info.nature="retaliatory"
	FrontierWildlifeCombat.set_phase(live,"calm");live.time=5;live.target=""
	FrontierWildlifeCombat._step(world,chosen,live,calm_info,[actor_id],field,.1,free)
	check(live.phase=="calm","retaliatory nature does not initiate a fight")
	FrontierWildlifeCombat.hit(world,actor_id,chosen,5);live.flinch=0
	calm_info.pattern="none";calm_info.nature="flee";FrontierWildlifeCombat.set_phase(live,"hurt")
	FrontierWildlifeCombat._step(world,chosen,live,calm_info,[actor_id],field,.3,free)
	check(live.phase=="flee","noncombat anatomy flees after being shot")
	core.wildlife_combat.cache={key:chosen};core.wildlife_combat.cache_time=10
	var paused_time:=float(live.time)
	core.wildlife_combat.tick(world,.1,[],free,Callable(),[actor_id])
	check(world.crew.wildlife_encounters.has(key) and live.time==paused_time,"disabled controls preserve and pause nearby encounter")

	FrontierWildlifeCombat.resume(world.crew)
	check(live.phase=="return" and live.target=="","reconnect cancels unfinished attacks")
	FrontierWildlifeCombat.hit(world,actor_id,chosen,1000)
	check(world.crew.combat[key]==0 and world.crew.wildlife_stops.has(key),"incapacitation preserves final position")
	var store:=FrontierWorldStore.new(folder+"/rules.json")
	check(store.write(world),"native combat save "+store.last_error)
	var saved:=store.read_state();check(not saved.is_empty() and saved.crew.combat[key]==0,"native health and stopped pose reload")
	print("NATIVE_COMBAT_RULES ",checks," FAILURES ",failures);quit(1 if failures else 0)
func place(at: Vector3) -> void:
	app.actors[actor_id].position=at;app.actors[actor_id].velocity=Vector3.ZERO
	core.update_position(1,at);core.motions.erase(actor_id);app.session._publish()
func aim() -> void:
	var direction: Vector3=(animal.global_position+Vector3.UP*float(FrontierWildlifeCombat.profile(chosen).height)*.5-app.camera.global_position).normalized()
	app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
func play() -> void:
	if "--crew-folder=/tmp/native-combat-play" not in OS.get_cmdline_user_args():quit(2);return
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"play fixture saved "+store.last_error)
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"native field Forward+ ready",100):quit(1);return
	core=app.session.authority;app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var at:=home+Vector3(0,0,8);at.y=field.height(at.x,at.z)+.2;place(at)
	var ecology: FrontierSurfaceEcology=app.surface_world.ecology
	if not await until(func():return ecology.actors.has(chosen.id) and ecology.actors[chosen.id].models.size()==2,"natural rigged animal loaded",60):quit(1);return
	animal=ecology.actors[chosen.id]
	var audio_record:=AudioEffectRecord.new();var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,audio_record);audio_record.set_recording_active(true)
	core.world.crew.members[actor_id].vitals.protection=0
	var before:=float(core.world.crew.members[actor_id].vitals.health)
	var phases: Dictionary={};var deadline:=Time.get_ticks_msec()+18000
	while Time.get_ticks_msec()<deadline and core.world.crew.members[actor_id].vitals.health>=before:
		aim()
		var live:=FrontierWildlifeCombat.state(core.world.crew,body.id,chosen)
		if not live.is_empty():
			if not phases.has(live.phase):
				phases[live.phase]=true
				if live.phase in ["warning","attack"]:await capture("native-"+str(live.phase))
		await create_timer(.1).timeout
	check(phases.has("warning") and phases.has("chase") and phases.has("attack"),"unprovoked warning pursuit and attack in real world")
	check(core.world.crew.members[actor_id].vitals.health<before,"real native attack reaches player")
	if not phases.has("attack"):print("NATIVE_DEBUG ",core.world.crew.get("wildlife_encounters",{})," ready ",app._weather_ready(actor_id)," field ",app._wildlife_clear(actor_id,chosen.id,animal.position+Vector3.UP,app.actors[actor_id].position+Vector3.UP,0,0))
	var live:=FrontierWildlifeCombat.state(core.world.crew,body.id,chosen)
	check(not live.is_empty() and animal.position.distance_to(FrontierCrewWorld.vector(live.position))<.3,"visible collider and host combat stay together")
	app.toggle_business();await create_timer(.15).timeout
	var clock_value:=float(FrontierWildlifeCombat.state(core.world.crew,body.id,chosen).get("time",-1));await create_timer(.4).timeout
	check(clock_value>=0 and is_equal_approx(float(FrontierWildlifeCombat.state(core.world.crew,body.id,chosen).get("time",-2)),clock_value),"solo menu pauses retained encounter")
	app.toggle_business()
	var shots:=0
	while shots<18 and int(core.world.crew.get("combat",{}).get(key,1))>0:
		aim();await process_frame;app.firearm.shoot();shots+=1;await create_timer(.23).timeout
	check(int(core.world.crew.get("combat",{}).get(key,1))==0,"equipped firearm defeats real moving native animal")
	check(core.world.crew.get("wildlife_stops",{}).has(key),"actual last position saved")
	await capture("native-down")
	audio_record.set_recording_active(false);var recording:=audio_record.get_recording();recording.save_to_wav(folder+"/native-runtime.wav");AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	print("NATIVE_AUDIO ",app.feedback.audio.last_played)
	check(app.feedback.audio.last_played.has("sfx_wildlife_warning") and app.feedback.audio.last_played.has("sfx_wildlife_strike"),"native sound cues played through live SFX bus")
	check(await app.session.close_session(),"native encounter save and close")
	var loaded:=store.read_state();check(not loaded.is_empty() and int(loaded.crew.get("combat",{}).get(key,1))==0,"incapacitation reloads")
	app.queue_free();await process_frame
	print("NATIVE_COMBAT_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

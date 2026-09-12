extends "res://tests/check_wildlife_combat.gd"
const Attacks=preload("res://scripts/domain/wildlife_attacks.gd")
var representatives: Dictionary={}
var unobstructed:=func(_actor,_row,_from,_to,_radius,_height):return true
func row_for(mode: String,tier: int) -> Dictionary:
	var row:=chosen.duplicate()
	var form: Dictionary=representatives[mode]
	row.form_id=form.id;row.look_id=FrontierEcologyCatalog.look_for_seed(form.id,0);row.combat_tier=tier
	return row
func attack(row: Dictionary,destination: Vector3) -> Dictionary:
	core.world.crew.wildlife_encounters={};core.world.crew.combat={}
	var live:=FrontierWildlifeCombat.ensure(core.world.crew,body.id,row)
	live.target=actor_id;live.aim=[0,0,1];live.yaw=0;FrontierWildlifeCombat.set_phase(live,"attack")
	Attacks.begin(live,FrontierWildlifeCombat.profile(row),destination,field,row)
	return live
func run() -> void:
	folder="/tmp/native-tier-play";DirAccess.make_dir_recursive_absolute(folder);fixture_construction="bovid"
	check(fixture(),"native planet fixture")
	if chosen.is_empty():quit(1);return
	print("NATIVE_TIER_PLANET ",body.planet_tier," ",body.id)
	if "--play" in OS.get_cmdline_user_args():await play();return
	for form in FrontierEcologyCatalog.all_forms():
		if not FrontierWildlifeCombat.Wildlife.eligible(form,{}):continue
		var info:=FrontierWildlifeCombat.profile({"form_id":form.id,"look_id":FrontierEcologyCatalog.look_for_seed(form.id,0)})
		var mode: String=info.get("behavior","flee")
		if not representatives.has(mode):representatives[mode]=form
	var same_species:=true
	var stronger:=true
	for mode in representatives:
		var previous:=FrontierWildlifeCombat.profile(row_for(mode,1))
		for tier in range(2,6):
			var info:=FrontierWildlifeCombat.profile(row_for(mode,tier))
			stronger=stronger and info.health>previous.health and info.health<=FrontierWildlifeCombat.config().maximum_health and info.speed>=previous.speed and info.get("damage",0)>=previous.get("damage",0)
			same_species=same_species and info.nature==previous.nature and info.radius==previous.radius and info.height==previous.height and info.get("windup",0)==previous.get("windup",0)
			previous=info
	check(stronger and representatives.size()==6,"T1-T5 strengthen all six ground behaviors within save bounds")
	check(same_species,"tier preserves nature body size and windup")
	check(chosen.combat_tier==body.planet_tier,"native candidates carry their own planet tier")
	var introduced:=row_for("melee",5);introduced.introduced=true
	check(FrontierWildlifeCombat.profile(introduced).tier==1,"introduced specimens do not gain destination combat strength")
	var member: Dictionary=core.world.crew.members[actor_id]
	member.vitals.shield=0;member.vitals.protection=0
	var distances: Array=[]
	for tier in [1,5]:
		var row:=chosen.duplicate();row.combat_tier=tier
		var info:=FrontierWildlifeCombat.profile(row);var live:=attack(row,home+Vector3(0,0,20))
		live.time=float(info.windup)+.2;Attacks.step(core.world,row,live,info,[],field,.1,unobstructed)
		distances.append(float(live.attack.travel))
		check(is_equal_approx(float(info.active)*float(info.charge_speed),float(info.charge_distance)),"charge duration reaches the announced distance at T%d"%tier)
	check(float(distances[1])>float(distances[0])*1.4,"T5 charge actually travels faster on terrain")
	var area_hits: Array=[];var sweep_hits: Array=[];var leap_ranges: Array=[]
	for tier in [1,5]:
		var row:=row_for("shockwave",tier);var info:=FrontierWildlifeCombat.profile(row)
		member.position=FrontierExplorationIncidents.array(home+Vector3(0,0,5.1));member.vitals.health=100
		var live:=attack(row,FrontierCrewWorld.vector(member.position));live.time=float(info.windup)+float(info.impact_delay)+.01
		Attacks.step(core.world,row,live,info,[actor_id],field,.1,unobstructed);area_hits.append(100-float(member.vitals.health))
		row=row_for("double_sweep",tier);info=FrontierWildlifeCombat.profile(row)
		member.position=FrontierExplorationIncidents.array(home+Vector3(0,0,2));member.vitals.health=100
		live=attack(row,FrontierCrewWorld.vector(member.position));live.time=float(info.windup)+.66
		Attacks.step(core.world,row,live,info,[actor_id],field,.1,unobstructed);sweep_hits.append(int(live.attack.pulses))
		row=row_for("leap",tier);live=attack(row,home+Vector3(0,0,12));leap_ranges.append(Vector2(float(live.attack.goal[0])-home.x,float(live.attack.goal[2])-home.z).length())
	print("TIER_ATTACK_RESULTS area=",area_hits," sweep=",sweep_hits," leap=",leap_ranges)
	check(area_hits[0]==0 and is_equal_approx(float(area_hits[1]),43),"T5 shockwave expands real hit radius and deals scaled damage")
	check(sweep_hits==[1,2],"T5 second sweep lands earlier")
	check(float(leap_ranges[1])>float(leap_ranges[0])*1.3,"T5 committed leap reaches farther")
	var high:=chosen.duplicate();high.combat_tier=5
	core.world.crew.combat={};core.world.crew.wildlife_encounters={}
	FrontierWildlifeCombat.hit(core.world,actor_id,high,1)
	var saved_hp:=int(core.world.crew.combat[key]);var store:=FrontierWorldStore.new(folder+"/tier-rules.json")
	check(saved_hp>300 and store.write(core.world),"high-tier health passes full world save validation")
	var loaded:=store.read_state()
	check(not loaded.is_empty() and loaded.crew.combat[key]==saved_hp and loaded.crew.wildlife_encounters[key].combat_tier==5,"high-tier health and encounter tier reload")
	core.world.crew.combat[key]=80;core.world.crew.wildlife_encounters[key].erase("combat_tier")
	FrontierWildlifeCombat.hit(core.world,actor_id,high,10)
	check(core.world.crew.combat[key]==70,"legacy wounded health is not replenished by scaling")
	core.world.crew.combat[key]=0;FrontierWildlifeCombat.resume(core.world.crew);FrontierWildlifeCombat.hit(core.world,actor_id,high,10)
	check(core.world.crew.combat[key]==0,"legacy incapacitation remains zero")
	print("NATIVE_TIER_RULES ",checks," FAILURES ",failures);quit(1 if failures else 0)
func play() -> void:
	if "--crew-folder=/tmp/native-tier-play" not in OS.get_cmdline_user_args():quit(2);return
	var store:=FrontierWorldStore.new(folder+"/world.json")
	check(store.write(core.world),"tier play fixture saved")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"tier field ready",100):quit(1);return
	core=app.session.authority;app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var at:=home+Vector3(0,0,8);at.y=field.height(at.x,at.z)+.2;place(at)
	var ecology: FrontierSurfaceEcology=app.surface_world.ecology
	if not await until(func():return ecology.actors.has(chosen.id) and ecology.actors[chosen.id].models.size()==2,"tier native model loaded",60):quit(1);return
	animal=ecology.actors[chosen.id];core.world.crew.members[actor_id].vitals.protection=0
	var initial_health:=float(core.world.crew.members[actor_id].vitals.health)
	var info:=FrontierWildlifeCombat.profile(chosen);var windup_seen:=false;var moved:=false
	var deadline:=Time.get_ticks_msec()+18000
	while Time.get_ticks_msec()<deadline and core.world.crew.members[actor_id].vitals.health>=initial_health:
		aim();await process_frame
		var live:=FrontierWildlifeCombat.state(core.world.crew,body.id,chosen)
		if live.get("phase","")!="attack":continue
		if not windup_seen and float(live.time)>=float(info.windup)*.6 and float(live.time)<float(info.windup):
			windup_seen=true
			check(animal.combat_info.tier==body.planet_tier and animal.combat_info.charge_speed==info.charge_speed,"render and host share planet-scaled attack profile")
			check(is_equal_approx(animal.combat_decal.size.z,float(info.charge_distance)+float(info.attack_front)+float(info.contact_radius)),"ground telegraph matches increased charge distance")
			app.surface_target=chosen;app.field_hud._process(0)
			check(app.field_hud.target_bar.max_value==info.health and info.health==360 and app.field_hud.target_action.text=="클릭  발사","T4 HUD shows scaled health without tactical text")
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/tier4-windup.png")
		if float(live.get("attack",{}).get("travel",0))>1:moved=true
	check(windup_seen and moved,"natural T4 charge moves in real expedition")
	check(is_equal_approx(initial_health-float(core.world.crew.members[actor_id].vitals.health),float(info.damage)),"natural T4 strike applies scaled damage")
	var max_health:=int(info.health)
	for shot in 4:
		aim();await process_frame;app.firearm.shoot();await create_timer(.23).timeout
		if int(core.world.crew.get("combat",{}).get(key,max_health))<max_health:break
	var remaining:=int(core.world.crew.get("combat",{}).get(key,max_health))
	check(remaining>0 and remaining<max_health,"equipped firearm subtracts from scaled native health")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/tier4-hit.png")
	check(app.feedback.audio.last_played.has("sfx_wildlife_warning") and app.feedback.audio.last_played.has("sfx_wildlife_strike"),"scaled attack retains native sound cues")
	check(await app.session.close_session(),"scaled encounter saved")
	var saved:=store.read_state()
	check(not saved.is_empty() and saved.crew.combat.get(key,-1)==remaining and saved.crew.wildlife_encounters[key].combat_tier==body.planet_tier,"actual T4 damage and tier reload")
	print("TIER_PLAY_STATS ",JSON.stringify({"tier":body.planet_tier,"health":info.health,"remaining":remaining,"damage":info.damage,"charge_speed":info.charge_speed,"charge_distance":info.charge_distance}))
	app.queue_free();await process_frame
	print("NATIVE_TIER_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

extends "res://tests/test_solo_entry.gd"
const SAVE_FOLDER="/tmp/space-damage-feedback-play"
var sequence:=0
func run() -> void:
	if "--crew-folder=/tmp/space-damage-feedback-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../output/space-damage-feedback");DirAccess.make_dir_recursive_absolute(SAVE_FOLDER);DirAccess.make_dir_recursive_absolute(folder)
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
	app.session.set_process(false);app.session.set_physics_process(false)
	nav.speed=0;enemy.velocity=[0,0,0];enemy.shield=32;enemy.hull=100
	app.session._publish();await create_timer(.3).timeout
	var view:FrontierSpaceCombatView=app.flight.combat_view
	var recorder:=AudioEffectRecord.new();var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
	var aim:Vector3=(FrontierSpaceCombat.point(enemy.position)-app.flight.camera.global_position).normalized()
	check(FrontierSpaceCombat.fire(world,owner.character_id,aim),"actual host cannon fires")
	app.session._publish();await create_timer(.1).timeout
	check(view.damage_numbers.entries.size()==1 and view.damage_numbers.entries[0].amount==16,"host pulse displays 16 shield damage")
	check(view.audio.last_played.has("sfx_gun_hit_shield"),"shield impact plays ElevenLabs shield cue")
	var before_serial:int=view.last_serial
	view.update(.01,false)
	check(view.damage_numbers.entries.size()==1 and view.damage_numbers.entries[0].amount==16 and view.last_serial==before_serial,"same snapshot does not replay or add damage")
	await capture("shield-hit-1280")
	await create_timer(1).timeout
	enemy.mark_left=0
	FrontierSpaceCombat.damage_enemy(world,enemy,26,origin,FrontierSpaceCombat.point(enemy.position));app.session._publish();await create_timer(.1).timeout
	check(view.damage_numbers.entries.size()==1 and view.damage_numbers.entries[0].amount==26 and view.damage_numbers.entries[0].broken,"mixed shield and hull hit shows 26 with break icon")
	check(view.audio.last_played.has("sfx_shield_break"),"shield break plays existing break cue")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	await capture("shield-break-960")
	await create_timer(1).timeout
	FrontierSpaceCombat.damage_enemy(world,enemy,18,origin,FrontierSpaceCombat.point(enemy.position));app.session._publish();await create_timer(.1).timeout
	check(view.damage_numbers.entries.size()==1 and view.damage_numbers.entries[0].amount==18,"bare hull hit shows actual hull damage")
	check(view.audio.last_played.has("sfx_gun_impact"),"hull impact plays existing armor impact cue")
	FrontierSpaceCombat.damage_enemy(world,enemy,2,origin,FrontierSpaceCombat.point(enemy.position));app.session._publish();await create_timer(.06).timeout
	check(view.damage_numbers.entries.size()==1 and view.damage_numbers.entries[0].amount==20,"successive hull hits stack per enemy")
	await capture("hull-hit-960")
	await create_timer(1.2).timeout
	enemy.hull=100;enemy.shield=0;enemy.mark_left=0
	check(FrontierSpaceCombat.launch_missile(world,owner.character_id,aim),"host launches signature missiles")
	app.session._publish()
	var hull_before:float=enemy.hull
	for i in 80:
		FrontierSpaceCombatPilot.projectiles(world,.05);app.session._publish();await create_timer(.05).timeout
		if enemy.hull<hull_before:break
	check(enemy.hull<hull_before and not view.damage_numbers.entries.is_empty() and is_equal_approx(float(view.damage_numbers.entries.back().amount),hull_before-float(enemy.hull)),"actual missile contact displays confirmed hull loss")
	check(view.audio.last_played.has("sfx_ship_missile_blast_v2"),"missile damage retains its impact sound")
	await capture("missile-hit-960")
	FrontierSpaceCombat.damage_ship(world,"crew",12,FrontierSpaceCombat.point(enemy.position));app.session._publish();await create_timer(.1).timeout
	check(view.hit_shielded and view.hit_flash>0,"own shield damage retains directional hit feedback")
	await create_timer(.8).timeout
	recorder.set_recording_active(false);recorder.get_recording().save_to_wav(folder+"/hit-feedback-sfx.wav");AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	view.update(.01,true)
	check(view.damage_numbers.entries.is_empty() and view.audio.get_children().all(func(p):return not (p is AudioStreamPlayer or p is AudioStreamPlayer3D) or not p.playing),"menu clears damage numbers and stops hit audio")
	FrontierSpaceCombat.damage_enemy(world,enemy,5,origin,FrontierSpaceCombat.point(enemy.position));app.session._publish();view.update(.01,true);view.update(.01,false)
	check(view.damage_numbers.entries.is_empty(),"damage during menu does not replay on resume")
	check(await app.session.close_session(),"current expedition saves new feedback fields")
	app.queue_free();await process_frame
	print("SPACE_DAMAGE_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

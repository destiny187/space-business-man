extends "res://tests/test_solo_entry.gd"
const SAVE_FOLDER="/tmp/mission-rescue-play"
var sequence:=0
func run() -> void:
	if "--crew-folder=/tmp/mission-rescue-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../output/active-missions");DirAccess.make_dir_recursive_absolute(SAVE_FOLDER);DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("항해 전투 검수",0);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
	var world: Dictionary=core.world;var system:=0
	for index in range(1000,90000,1000):
		if FrontierSpaceCombat.tier(world,index)>=3:system=index;break
	var nav: Dictionary=world.crew.navigation;nav.erase("solar_opening");nav.mode="idle";nav.manual=true;nav.system=system;nav.target=FrontierUniverse.first_ordinal(world.manifest,system);nav.direction=[0.0,0.0,-1.0];nav.speed=0.0;nav.first_stellar_system=1
	world.location=FrontierUniverse.body_id(world.manifest,int(nav.target));world.navigation_target=world.location
	for i in range(10,60):
		var p:=Vector3(0,i*400,0)
		if FrontierSpaceCombat.clear_position(world,system,p,1200):nav.position=FrontierSpaceCombat.arr(p);break
	world.flight_position=nav.position.duplicate();world.crew.landing={}
	world.business=FrontierExpeditionBusiness.create();world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory()
	world.vessel=FrontierVesselRefit.create(int(world.manifest.seed),world.crew.world_id);world.vessel.hull="orion";world.vessel.hulls=["kestrel","orion"]
	world.vessel.combat_skills=FrontierVesselSkills.create()
	var r:=FrontierSpaceCombat.record(world)
	for attempt in 30:
		r.serial=attempt;r.encounter={}
		if FrontierSpaceCombat.begin(world,"crew","stellar_arrival") and r.encounter.has("rescue"):break
	check(r.encounter.has("rescue"),"existing eligible space encounter creates a rescue variant")
	if not r.encounter.has("rescue"):quit(1);return
	var rescue_id:=FrontierExplorationIncidents.key(r.encounter.rescue.site)
	var escaped:=world.duplicate(true);FrontierSpaceCombat.finish(escaped,"escaped")
	check(not FrontierExplorationIncidents.records(escaped).has(rescue_id),"escaping does not award a rescued ground site")
	var profile:=FrontierPlayerProfile.new(SAVE_FOLDER+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	check(FrontierWorldStore.new(SAVE_FOLDER+"/world.json").write(world),"rescue encounter passes actual save validation")
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition loads rescue",55):quit(1);return
	app.onboarding.letter.hide();app.close_menus();app.outside=true;app.exterior_view.show();app.if_flight_view();app.flight.presentation_blocked=false
	app.set_physics_process(false);app.set_process(false);root.grab_focus()
	var authority: FrontierCrewAuthority=app.session.authority;authority.resolve_autonomous(true)
	app.session.set_process(false);app.session.set_physics_process(false)
	world=authority.world;r=FrontierSpaceCombat.record(world);r.encounter.phase="combat";r.encounter.resume=0
	var enemy: Dictionary=r.encounter.enemies[0]
	for other in r.encounter.enemies:
		if other!=enemy:other.hull=0
	nav=world.crew.navigation;var origin:=FrontierSpaceCombat.point(nav.position)
	enemy.position=FrontierSpaceCombat.arr(origin+Vector3.FORWARD*350);enemy.direction=[0,0,1];enemy.velocity=[0,0,0];enemy.up=[0,1,0];enemy.shield=0;enemy.hull=1
	FrontierSpaceCombatPilot.initialize(enemy);nav.direction=[0,0,-1];nav.speed=0;nav.up=[0,1,0]
	app.session._publish();await create_timer(1.5).timeout
	var rescue_view:Node3D
	for child in app.flight.combat_view.get_children():
		if child.get_script()==preload("res://scripts/world/mission_rescue_view.gd"):rescue_view=child
	check(rescue_view!=null and rescue_view.vessel!=null and rescue_view.vessel.visible and rescue_view.label.visible,"actual Forward+ encounter displays the rescued ship and signal")
	app.flight.camera.look_at(FrontierSpaceCombat.point(r.encounter.rescue.position));await capture("rescue-space-signal")
	var aim:Vector3=(FrontierSpaceCombat.point(enemy.position)-app.flight.camera.global_position).normalized()
	check(FrontierSpaceCombat.fire(world,owner.character_id,aim),"host cannon fires final rescue shot")
	FrontierSpaceCombat.tick(world,.05,{}, {1:owner.character_id},1)
	check(r.encounter.phase=="victory" and FrontierExplorationIncidents.records(world).has(rescue_id),"confirmed fleet defeat creates the landing mission")
	var saved_row:Dictionary=FrontierExplorationIncidents.records(world).get(rescue_id,{})
	check(saved_row.get("seen",false) and saved_row.get("template")=="freighter_rescue_chain","new rescue site is visible in incident journal")
	var count:=FrontierExplorationIncidents.records(world).size();FrontierSpaceCombat.finish(world,"victory")
	check(FrontierExplorationIncidents.records(world).size()==count,"repeated victory does not duplicate the ground site")
	app.session._publish();await create_timer(.3).timeout;await capture("rescue-space-completed")
	check(await app.session.close_session(),"rescue chain persists through session close")
	check(FrontierWorldStore.new(SAVE_FOLDER+"/world.json").read_state().get("incidents",{}).get("records",{}).has(rescue_id),"completed rescue site reloads")
	app.queue_free();await process_frame
	print("MISSION_RESCUE_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

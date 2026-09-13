extends "res://tests/test_solo_entry.gd"
const SAVE_FOLDER="/tmp/space-advanced-hulls"
var next_input:=1
func dispatch(kind: String,slot: int=0) -> bool:
	app.station_market.send(kind,slot)
	if not await until(func():return not app.station_market.pending,"station response "+kind,10):return false
	return not app.session.authority.stopped
func fly(seconds: float,slot: int=-1) -> void:
	for i in ceili(seconds/.05):
		var buttons:Array=[0,0,0,0,0,1,0,0,0,0,0,0]
		if slot==0:buttons[6]=1
		elif slot>0:buttons[9+slot]=1
		app.session.send_input(Vector2.ZERO,Vector3.FORWARD,false,false,buttons)
		await create_timer(.05).timeout
func run() -> void:
	if "--crew-folder="+SAVE_FOLDER not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../output/advanced-hulls/play");DirAccess.make_dir_recursive_absolute(folder);DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("선체·스킬 현장 확인",0);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
	var world:Dictionary=core.world;var system:=-1
	for i in range(1000,120000,1000):
		if FrontierVesselAccess.system_tier(world.manifest,i)>=4 and not FrontierSpaceStation.definition(world.manifest,i).is_empty():system=i;break
	if system<0:check(false,"high-tier station exists");quit(1);return
	var station:=FrontierSpaceStation.definition(world.manifest,system);var nav:Dictionary=world.crew.navigation
	nav.erase("solar_opening");nav.mode="idle";nav.manual=true;nav.system=system;nav.target=FrontierUniverse.first_ordinal(world.manifest,system);nav.position=FrontierSpaceCombat.arr(FrontierSpaceCombat.point(station.position)+Vector3(0,360,1050));nav.direction=[0,0,-1];nav.up=[0,1,0];nav.speed=0;nav.first_stellar_system=1
	world.location=FrontierUniverse.body_id(world.manifest,int(nav.target));world.navigation_target=world.location;world.flight_position=nav.position.duplicate();world.crew.landing={}
	world.business=FrontierExpeditionBusiness.create();world.business.credits=2000000;world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory()
	world.vessel=FrontierVesselRefit.create(int(world.manifest.seed),world.crew.world_id);world.vessel.hull="kestrel";world.vessel.hulls=["kestrel"]
	var profile:=FrontierPlayerProfile.new(SAVE_FOLDER+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	check(FrontierWorldStore.new(SAVE_FOLDER+"/world.json").write(world),"isolated playable fixture saves")
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition loads",60):quit(1);return
	app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.close_menus();app.outside=true;app.exterior_view.show();app.if_flight_view();app.test_mode=true
	await create_timer(.6).timeout;app.open_trade_station();var market:FrontierStationMarketPanel=app.station_market
	check(market.visible,"actual station opens at nearby host position")
	market.mode="ships";market.selected="hull:orion";market.rebuild();await capture("hulls-station")
	check(market.grid.get_child_count()>=7 and not market.buy.disabled,"both advanced hull bands are purchasable")
	await dispatch("station_buy")
	check("orion" in app.session.latest.vessel.hulls,"station purchase retains a real advanced hull")
	market.mode="owned";market.selected="orion";market.rebuild();await dispatch("station_equip")
	if not await until(func():return app.flight.refits.hull_id=="orion" and app.flight.refits.requested_hull.is_empty(),"advanced hull loads into current flight",12):quit(1);return
	check(int(app.session.latest.vessel_stats.navigation_tier)==5 and int(app.session.latest.crew.cargo_slots)==22,"equipped hull changes navigation and actual cargo capacity")
	market.mode="skills";market.selected="phase_lance";market.rebuild()
	var first_card_id:int=market.skill_cards.seeker_salvo.get_instance_id();var hull_node_id:int=app.flight.refits.hull_node.get_instance_id()
	var authority:FrontierCrewAuthority=app.session.authority
	var before:int=authority.world.business.credits;var save:Callable=authority.save_request;authority.save_request=func(_w):return false
	await dispatch("station_skill_buy");authority.save_request=save
	check(authority.world.business.credits==before and not FrontierVesselSkills.owned(authority.world.vessel,"phase_lance"),"rejected save cannot spend money or grant skill")
	app.status.value="" # Dismiss the deliberately injected save failure before the visual review.
	app.navigation_ui.toast_left=0;app.navigation_ui.message.hide()
	await dispatch("station_skill_buy");await dispatch("station_skill_equip",1);await dispatch("station_skill_upgrade")
	check(FrontierVesselSkills.slot_skill(app.session.latest.vessel,1)=="phase_lance" and FrontierVesselSkills.level(app.session.latest.vessel,"phase_lance")==1,"station acquires and strengthens another hull's ability")
	check(first_card_id==market.skill_cards.seeker_salvo.get_instance_id() and hull_node_id==app.flight.refits.hull_node.get_instance_id(),"one skill action retains unrelated cards and current hull model")
	await capture("skills-station")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("skills-960")
	check(market.skill_actions.get_global_rect().end.y<=640 and market.get_global_rect().end.x<=960,"two equip buttons and upgrade fit small screen")
	app.test_mode=false
	check(app.collect_flight_controls()==FrontierCrewNavigation.stopped_input(),"menu or missing focus blocks combat skill keys")
	app.test_mode=true;app.close_menus();app.set_process(false);app.set_physics_process(false);app.flight.presentation_blocked=false
	world=authority.world;nav=world.crew.navigation
	for i in range(10,80):
		var at:=Vector3(0,i*500,0)
		if FrontierSpaceCombat.clear_position(world,system,at,2000):nav.position=FrontierSpaceCombat.arr(at);break
	world.flight_position=nav.position.duplicate();nav.direction=[0,0,-1];nav.up=[0,1,0];nav.speed=0
	check(FrontierSpaceCombat.begin(world,"crew","local_transit"),"new hull enters ordinary host pirate encounter")
	var e:Dictionary=FrontierSpaceCombat.record(world).encounter;e.phase="warning";e.warning=20;e.resume=0
	var origin:=FrontierSpaceCombat.point(nav.position)
	for i in e.enemies.size():e.enemies[i].position=FrontierSpaceCombat.arr(origin+Vector3((i-1.5)*55,0,-330));e.enemies[i].hull=600;e.enemies[i].shield=150
	authority.world.vessel.combat_skills.levels["constellation"]=4
	app.session._publish();await fly(.3);await fly(.3,0);await capture("multi-lock-flight")
	check(app.flight.combat_view.locked_targets.size()==4,"flight HUD shows four separate lock targets")
	await fly(.2,1);await capture("lance-charging")
	check(app.flight.combat_view.skills.charge.visible and is_instance_valid(app.flight.combat_view.skills.charge_voice) and app.flight.combat_view.skills.charge_voice.playing,"host charge drives capacitor visual and preparation sound")
	for i in 60:
		if app.flight.combat_view.audio.last_played.has("sfx_gun_ship_pulse"):break
		await fly(.1)
	check(app.flight.combat_view.audio.last_played.has("sfx_gun_ship_pulse") and app.flight.combat_view.audio.last_played.has("sfx_ship_missile_launch"),"host-confirmed skills play existing ElevenLabs sounds")
	check(not app.flight.combat_view.skills.charge_voice.playing,"preparation sound stops when charged attack fires")
	await fly(.2,2);await capture("barrier-flight")
	check(app.flight.combat_view.skills.barrier.visible,"equipped shield displays against actual ship")
	check(app.flight.refits.moving_parts.size()>=4 and app.flight.drive.hull_sockets.size()==2,"radiator motion and exhaust connect to authored hull parts")
	await fly(.2)
	check(await app.session.close_session(),"normal session close saves skills and current hull")
	var restored:=FrontierWorldStore.new(SAVE_FOLDER+"/world.json").read_state()
	check(not restored.is_empty() and restored.vessel.hull=="orion" and FrontierVesselSkills.slot_skill(restored.vessel,1)=="phase_lance" and FrontierVesselSkills.level(restored.vessel,"phase_lance")==1,"disk reload preserves acquired loadout and upgrades")
	app.queue_free();await process_frame;await process_frame
	print("VESSEL_SKILL_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

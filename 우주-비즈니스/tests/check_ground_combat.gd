extends "res://tests/test_solo_entry.gd"
var actor_id: String
var source: Dictionary
var robot_key: String
var core: FrontierCrewAuthority
var serial:=0
func command(kind: String,args: Dictionary) -> Dictionary:
	serial+=1
	return core.request(1,{"session_id":core.session_id,"sequence":serial,"revision":core.world.crew.revision,"kind":kind,"args":args})
func fixture() -> Dictionary:
	var owner:=FrontierPlayerProfile.new_character("지상전 검수",0);actor_id=owner.character_id
	core=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_world):return true),"start isolated host")
	core.phase="playing";core.world.crew.phase="playing";core.world.crew.navigation.erase("solar_opening")
	var world: Dictionary=core.world;var planet: Dictionary={};var destination:=0
	for i in range(8,500000,997):
		var body:=FrontierUniverse.body(world.manifest,i)
		if FrontierUniverse.landable(body) and int(body.planet_tier)==3:planet=body;destination=i;break
	if planet.is_empty():check(false,"T3 fixture");return {}
	world.location=planet.id;world.navigation_target=planet.id;world.crew.navigation.system=planet.system_ordinal;world.crew.navigation.target=destination
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(destination,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
	world.vessel=FrontierVesselRefit.create(int(world.manifest.seed),str(world.crew.world_id));world.vessel.navigation_refits={"kestrel":3}
	world.crew.members[actor_id].ready=true
	var landing_error:=FrontierCrewSurface.apply(world,actor_id,"land",{},{1:actor_id})
	check(landing_error.is_empty(),"land fixture: "+landing_error)
	if not landing_error.is_empty():return {}
	var field:=FrontierExplorationIncidents.field(planet)
	for x in range(-2,3):
		for z in range(-2,3):
			for candidate in FrontierExplorationIncidents.tile(planet,field,Vector2i(x,z)):
				if candidate.template=="illuti_dormant_combat_robot":source=candidate;break
			if not source.is_empty():break
		if not source.is_empty():break
	if source.is_empty():check(false,"natural robot fixture");return {}
	robot_key=FrontierExplorationIncidents.key(source);world.incidents.records[robot_key]=FrontierExplorationIncidents.create(source)
	var member: Dictionary=world.crew.members[actor_id]
	member.loadout.inventory_slots=48
	for id in FrontierEquipment.config().items:
		if FrontierEquipment.config().items[id].has("firearm"):member.loadout.items["fixture:"+id]=id
	member.loadout.slots[2]="fixture:pulse_2";member.loadout.selected=2
	var at:=FrontierCrewWorld.vector(source.position)+Vector3(0,0,12);at.y=field.height(at.x,at.z)+.1;member.position=FrontierExplorationIncidents.array(at)
	world.business.bags[actor_id]=FrontierExpeditionBusiness.inventory();world.business.bags[actor_id].iron=40;world.business.bags[actor_id].stone=40;world.business.bags[actor_id]["combat_cover_kit"]=2
	core.input(1,1,[0,0],[0,0,-1],false,false,[],0,true)
	return owner
func aim() -> Array:
	var member: Dictionary=core.world.crew.members[actor_id]
	var direction: Vector3=(FrontierExplorationIncidents.point(source,Vector3(0,1.5,0))-FrontierCrewWorld.vector(member.position)-Vector3.UP*FrontierFirearms.eye(member)).normalized()
	return FrontierExpeditionBusiness.array(direction)
func run() -> void:
	var owner:=fixture()
	if owner.is_empty():quit(1);return
	if "--muzzle-boundary" in OS.get_cmdline_user_args():
		var result:=FrontierFirearms.fire(core.world,actor_id,{"item_id":"fixture:pulse_2","aim":aim(),"ads":false},func(_id,_origin,_aim,_reach):return .2)
		check(result.get("code")=="muzzle_blocked" and core.world.crew.members[actor_id].loadout.weapon_states["fixture:pulse_2"].ammo==24,"blocked muzzle neither fires nor spends ammo")
		result=FrontierFirearms.fire(core.world,actor_id,{"item_id":"fixture:pulse_2","aim":aim(),"ads":false},func(_id,_origin,_aim,reach):return reach)
		check(result.get("ok",false) and result.weapon.ammo==23,"clear muzzle fires normally")
		core.inputs[1]={"expires":10000.0,"controls_enabled":true}
		result=command("surface_reload",{"item_id":"fixture:pulse_2"})
		check(result.get("ok",false) and result.get("firearm_action")=="surface_reload","combat success has its own feedback context")
		core.inputs[1].controls_enabled=false;result=command("surface_stance",{"crouched":true})
		check(result.get("code")=="weapon_blocked" and result.get("firearm_action")=="surface_stance","transient rejection keeps combat feedback context")
		print("MUZZLE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	if "--diagnose-cover" in OS.get_cmdline_user_args():
		if "--saved" in OS.get_cmdline_user_args():core.world=FrontierWorldStore.new("/tmp/ground-combat-play/world.json").read_state();actor_id=core.world.crew.owner_id
		var reasons: Dictionary={};var field:=FrontierCrewSurface.field(core.world);var player:=FrontierCrewWorld.vector(core.world.crew.members[actor_id].position)
		for x in range(-9,10):
			for z in range(-9,10):
				var candidate:=Vector3(player.x+x,0,player.z+z);candidate.y=field.height(candidate.x,candidate.z)
				var reason:=FrontierExpeditionBusiness.build_reason(core.world,actor_id,"combat_barrier",candidate,{1:actor_id});reasons[reason]=int(reasons.get(reason,0))+1
		print("COVER_REASONS ",reasons);quit();return
	if "--play" in OS.get_cmdline_user_args():await play_fixture(owner);return
	var member: Dictionary=core.world.crew.members[actor_id]
	core.inputs[1]={"expires":10000.0,"controls_enabled":true}
	var args: Dictionary={"item_id":"fixture:pulse_2","aim":aim(),"ads":true}
	var before:=float(core.world.incidents.records[robot_key].shield)
	var first:=command("surface_fire",args);print("FIRST_SHOT ",first)
	if not first.get("ok",false):quit(1);return
	check(first.get("ok",false) and first.get("weapon",{}).get("ammo",-1)==23,"host consumes one round")
	check(float(core.world.incidents.records[robot_key].shield)<before,"ranged robot shield hit")
	var duplicate:=core.request(1,{"session_id":core.session_id,"sequence":serial,"revision":core.world.crew.revision,"kind":"surface_fire","args":args})
	check(duplicate==first,"same request replays without second shot")
	check(not command("surface_fire",args).get("ok",false),"early fire rejected")
	FrontierFirearms.tick(member,.2)
	core.shot_obstacle_provider=func(_actor,_origin,_aim,_reach):return 2.0
	before=float(core.world.incidents.records[robot_key].shield)
	check(command("surface_fire",args).get("ok",false) and float(core.world.incidents.records[robot_key].shield)==before,"solid obstacle blocks damage")
	core.shot_obstacle_provider=Callable()
	check(command("surface_reload",{"item_id":args.item_id}).get("reload",false),"host starts reload")
	check(not command("surface_fire",args).get("ok",false),"cannot fire while reloading")
	FrontierFirearms.tick(member,4)
	check(member.loadout.weapon_states[args.item_id].ammo==24,"reload restores magazine")
	check(not command("surface_attack",{"aim":aim()}).get("ok",false),"legacy action cannot bypass magazine")
	check(command("surface_stance",{"crouched":true}).get("ok",false) and FrontierFirearms.eye(member)<1.3,"low stance is authoritative")
	core.standing_allowed_provider=func(_id):return false
	check(not command("surface_stance",{"crouched":false}).get("ok",false) and member.loadout.crouched,"blocked headroom prevents standing")
	core.standing_allowed_provider=Callable();command("surface_stance",{"crouched":false})
	for id in FrontierEquipment.config().items:
		var definition: Dictionary=FrontierEquipment.config().items[id]
		if not definition.has("firearm"):continue
		var found:=true
		for resource in definition.cost:found=found and not FrontierCatalog.entry("resources",resource).is_empty()
		check(found,"valid production ingredients "+id)
	var cover: Dictionary={"id":"facility:combat-check","type":"combat_barrier","tier":1,"position":FrontierExplorationIncidents.array(FrontierCrewWorld.vector(member.position)+Vector3(0,0,-3)),"yaw":0.0,"enabled":true,"active":true,"status":"사용 가능","work":0.0}
	cover["region_id"]=FrontierRegionalTerraform.region_id(FrontierExpeditionBusiness.site(core.world),FrontierCrewWorld.vector(cover.position))
	if not FrontierExpeditionBusiness.site(core.world).regions.has(cover.region_id):FrontierExpeditionBusiness.site(core.world).regions[cover.region_id]=FrontierFreeTerraform.district(FrontierExpeditionBusiness.site(core.world),cover.region_id)
	FrontierCombatCover.create(cover,0);FrontierExpeditionBusiness.site(core.world).buildings[cover.id]=cover;FrontierCombatCover.tick(FrontierExpeditionBusiness.site(core.world),3)
	var origin:=FrontierCrewWorld.vector(member.position)+Vector3.UP
	var hit:=FrontierCombatCover.intercept(core.world,core.world.location,origin,Vector3.FORWARD,10)
	check(not hit.is_empty(),"low barrier intercepts chest ray")
	check(FrontierCombatCover.intercept(core.world,core.world.location,origin+Vector3.UP*.72,Vector3.FORWARD,10).is_empty(),"standing fire clears low barrier")
	FrontierCombatCover.damage(hit,1000)
	check(FrontierCombatCover.intercept(core.world,core.world.location,origin,Vector3.FORWARD,10).is_empty(),"broken cover stops protecting")
	check(FrontierCombatCover.repair(core.world,actor_id,cover).is_empty() and cover.cover_hp>0,"repair consumes personal materials")
	var loot_row:=source.duplicate(true)
	for n in 100:
		loot_row.id=source.id+":loot:"+str(n)
		if not FrontierFirearms.loot(int(core.world.manifest.seed),loot_row).is_empty():break
	check(FrontierFirearms.drop(core.world,actor_id,loot_row).is_empty() and loot_row.get("gun_claimed",false),"seeded weapon drop enters inventory")
	var count: int=member.loadout.items.size();FrontierFirearms.drop(core.world,actor_id,loot_row)
	check(member.loadout.items.size()==count,"loot cannot be claimed twice")
	check(FrontierEquipment.validate(member.loadout).is_empty(),"weapon state save validation")
	var store:=FrontierWorldStore.new("/tmp/ground-combat-rules/world.json");DirAccess.make_dir_recursive_absolute("/tmp/ground-combat-rules")
	check(store.write(core.world),"combat/cover world save: "+store.last_error)
	var saved:=store.read_state();check(not saved.is_empty() and saved.crew.members[actor_id].loadout.weapon_rolls==JSON.parse_string(JSON.stringify(member.loadout.weapon_rolls)),"weapon rarity survives reload")
	if "--play" in OS.get_cmdline_user_args():await play_fixture(owner);return
	print("GROUND_COMBAT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func play_fixture(owner: Dictionary) -> void:
	folder="/tmp/ground-combat-play"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/ground-combat-play" not in OS.get_cmdline_user_args():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"save play fixture: "+store.last_error)
	if not store.last_error.is_empty():quit(1);return
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ ground loaded",90):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	core=app.session.authority
	core.world.business.bags[actor_id]=FrontierExpeditionBusiness.inventory();core.world.business.bags[actor_id]["iron"]=40;core.world.business.bags[actor_id]["stone"]=40;core.world.business.bags[actor_id]["combat_cover_kit"]=2
	core.world.business.bags[actor_id]["reinforced_frame"]=2
	var approach:=FrontierCrewWorld.vector(source.position)+Vector3(0,0,12);approach.y=app.surface_world.terrain.field.height(approach.x,approach.z)+.1
	app.actors[actor_id].position=approach;app.actors[actor_id].velocity=Vector3.ZERO;core.update_position(1,approach);core.motions[actor_id]=FrontierCrewLocomotion.create()
	if not await until(func():return app.surface_world.ready_at(app.actors[actor_id].position) and app.surface_world.incidents.models.has(robot_key),"robot and ground streamed",55):quit(1);return
	if "--audio-review" in OS.get_cmdline_user_args():await audio_review();return
	if "--ui-feedback-review" in OS.get_cmdline_user_args():
		app.navigation_ui.toast_left=0;app.field_hud.toast_left=0;app.status.value=""
		core.inputs[1].controls_enabled=false;app.session.send_request("surface_stance",{"crouched":true})
		check(app.navigation_ui.toast_left<=0 and app.field_hud.toast_left<=0 and app.status.value.is_empty(),"transient stance rejection leaves general HUD clear")
		core.world.crew.members[actor_id].loadout.weapon_rolls={"fixture:pulse_2":{"rarity":"improved"}}
		app.session._publish();app.open_menu(app.inventory_panel)
		app.inventory_panel.selected_item="fixture:pulse_2";app.inventory_panel.selected_definition="pulse_2";app.inventory_panel.selected_resource="";app.inventory_panel.last_key=""
		root.size=Vector2i(960,640);root.content_scale_size=root.size;await create_timer(.5).timeout
		check("개량" in app.inventory_panel.category.text,"rarity stays visible above the small detail scroll")
		await capture("inventory-960-final")
		check(await app.session.close_session(),"save final feedback fixture")
		app.queue_free();await process_frame;await process_frame;print("COMBAT_FEEDBACK_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	app.session.response_received.connect(func(_seq,result):
		if not result.get("ok",false):print("PLAY_REJECTION ",result))
	var robot: Dictionary=core.world.incidents.records[robot_key]
	var at:=FrontierExplorationIncidents.point(robot,Vector3(0,1.5,0));look_at_point(at)
	await create_timer(.3).timeout
	app.firearm.shoot();await create_timer(.25).timeout
	check(not app.firearm.accepted.is_empty(),"local trigger receives host ammo outcome")
	check(app.feedback.audio.stream("sfx_gun_carbine")!=null,"ElevenLabs shot cue loaded")
	await capture("carbine-fire")
	app.firearm.reload();await create_timer(.35).timeout
	check(app.firearm.reload_left>0 and app.firearm.reload_bar.visible,"reload animation and progress visible")
	await capture("reload")
	await create_timer(2).timeout
	core.world.incidents.records[robot_key].hp=0;FrontierExplorationIncidents.set_phase(core.world.incidents.records[robot_key],"destroyed")
	for family in ([] if "--cover-review" in OS.get_cmdline_user_args() else FrontierFirearms.config().families.keys()):
		var key: String=""
		for definition in FrontierEquipment.config().items:
			if FrontierEquipment.config().items[definition].get("firearm")==family:key=definition;break
		app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:"+key});await create_timer(.2).timeout
		app.firearm.test_ads=false;look_at_point(at);await create_timer(.3).timeout
		await capture("family-"+family)
		if family in ["carbine","sniper"]:
			app.firearm.test_ads=true;await create_timer(.4).timeout;await capture("ads-"+family);app.firearm.test_ads=false
	# Build both covers through the same host request used by the B placement UI.
	for kind in ["combat_barrier","combat_barricade"]:
		var player: Vector3=app.actors[actor_id].position;var position:=Vector3.INF
		for x in range(-9,10,2):
			for z in range(-9,10,2):
				var candidate: Vector3=player+Vector3(x,0,z);candidate.y=FrontierCrewSurface.field(core.world).height(candidate.x,candidate.z)
				if candidate.is_finite() and FrontierExpeditionBusiness.build_reason(core.world,actor_id,kind,candidate,{1:actor_id}).is_empty():position=candidate;break
			if position.is_finite():break
		check(position.is_finite(),"valid cover placement "+kind)
		if not position.is_finite():print("COVER_PLAYER ",player," source ",source.position)
		if not position.is_finite():continue
		look_at_point(position+Vector3.UP)
		app.session.send_request("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(position),"yaw":app.yaw})
		await create_timer(2.7).timeout
		var matches: Array=FrontierExpeditionBusiness.site(core.world).buildings.values().filter(func(row):return row.type==kind)
		check(matches.size()==1,"build commits "+kind)
		if not matches.is_empty():
			var id: String=matches[0].id
			check(app.surface_world.business_view.nodes.has(id),"Blender cover and collision present "+kind)
			check(FrontierCombatCover.ready(matches[0]),"assembly completes "+kind)
			await capture(kind)
			FrontierCombatCover.damage({"row":FrontierExpeditionBusiness.site(core.world).buildings[id]},1000);core.gun_dirty=true
			await create_timer(1.4).timeout
			check(app.surface_world.business_view.nodes[id].get_meta("visual").scale.y<.2,"broken cover collapses "+kind)
			await capture(kind+"-broken")
			var repair_approach:=position+Vector3(0,0,3);repair_approach.y=app.surface_world.terrain.field.height(repair_approach.x,repair_approach.z)+.1
			app.actors[actor_id].position=repair_approach;app.actors[actor_id].velocity=Vector3.ZERO;core.update_position(1,repair_approach);look_at_point(position+Vector3.UP*.2)
			await create_timer(.5).timeout
			check(app.surface_world.business_view.target(app.camera,app.actors[actor_id]).get("id")==id,"F ray selects nonblocking wreck "+kind)
			app.session.send_request("business_toggle",{"building_id":id});await create_timer(2.7).timeout
			check(FrontierCombatCover.ready(FrontierExpeditionBusiness.site(core.world).buildings[id]),"paid repair restores cover "+kind)
	app.firearm.crouched=true;await create_timer(1.5).timeout
	check(core.world.crew.members[actor_id].loadout.get("crouched",false),"Ctrl posture reaches host")
	var collision: CollisionShape3D=app.actors[actor_id].get_child(0)
	check(collision.shape.height<1.4,"low collision follows posture")
	await capture("low-stance");app.firearm.crouched=false;await create_timer(.3).timeout
	var cargo:=FrontierExplorationIncidents.cargo_point(core.world.incidents.records[robot_key]);var pickup_approach:=cargo+Vector3(0,0,2.8);pickup_approach.y=app.surface_world.terrain.field.height(pickup_approach.x,pickup_approach.z)+.1
	app.actors[actor_id].position=pickup_approach;app.actors[actor_id].velocity=Vector3.ZERO;core.update_position(1,pickup_approach);look_at_point(cargo)
	await create_timer(.7).timeout;await capture("weapon-loot")
	var before_count: int=core.world.crew.members[actor_id].loadout.items.size()
	check(app.surface_world.incidents.selected.get("part")=="cargo","F points at physical weapon loot")
	app.surface_world.incidents.interact();await create_timer(.7).timeout
	check(core.world.crew.members[actor_id].loadout.items.size()>before_count,"F adds owned gun")
	app.open_menu(app.inventory_panel)
	var drop: Dictionary=core.world.incidents.records[robot_key].get("gun_drop",{})
	if not drop.is_empty():
		app.inventory_panel.selected_item=drop.item_id;app.inventory_panel.selected_definition=drop.definition;app.inventory_panel.selected_resource="";app.inventory_panel.last_key=""
	await capture("inventory-1280")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("inventory-960")
	app.close_menus();await create_timer(.3).timeout;await capture("hud-960")
	check(await app.session.close_session(),"save actual ground play")
	app.queue_free();await process_frame;await process_frame
	print("GROUND_COMBAT_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func look_at_point(target: Vector3) -> void:
	var difference: Vector3=target-app.actors[actor_id].position-Vector3.UP*(1.15 if app.firearm.crouched else 1.72)
	app.yaw=atan2(-difference.x,-difference.z);app.pitch=atan2(difference.y,Vector2(difference.x,difference.z).length())

func audio_review() -> void:
	core.world.incidents.records[robot_key].hp=0;FrontierExplorationIncidents.set_phase(core.world.incidents.records[robot_key],"destroyed")
	app.pitch=.6
	var audio: FrontierAudio=app.feedback.audio
	var record:=AudioEffectRecord.new();record.format=AudioStreamWAV.FORMAT_16_BITS
	var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,record);record.set_recording_active(true)
	var started:=Time.get_ticks_msec();var timeline: Array=[]
	for family in FrontierFirearms.config().families:
		var key: String=""
		for definition in FrontierEquipment.config().items:
			if FrontierEquipment.config().items[definition].get("firearm")==family:key=definition;break
		app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:"+key});await create_timer(.4).timeout
		var gun:=app.firearm.tool();var start:=float(Time.get_ticks_msec()-started)/1000.0
		for round_index in 3:
			app.firearm.shoot();await create_timer(maxf(.1,float(gun.interval)+.03)).timeout
		var state: Dictionary=core.world.crew.members[actor_id].loadout.get("weapon_states",{}).get(gun.item_id,{})
		check(int(state.get("ammo",gun.magazine))<int(gun.magazine) and audio.last_played.has(gun.sound),"actual firing and dedicated audio "+family)
		timeline.append({"cue":gun.sound,"from":start,"to":float(Time.get_ticks_msec()-started)/1000.0})
		if family in ["pistol","lmg"]:
			app.firearm.reload();await create_timer(.12).timeout
			var speakers: Array=audio.get_children().filter(func(node):return node.get_meta("cue","")=="sfx_gun_reload" and not node.is_queued_for_deletion())
			var aligned:=not speakers.is_empty()
			if aligned:aligned=absf(speakers[-1].stream.get_length()/speakers[-1].pitch_scale-app.firearm.reload_duration)<.06
			check(aligned,"reload sound matches host duration "+family)
			timeline.append({"cue":"reload_"+family,"from":float(Time.get_ticks_msec()-started)/1000.0,"duration":app.firearm.reload_duration})
			if family=="lmg":
				app.open_menu(app.inventory_panel);await create_timer(.1).timeout
				check(audio.get_children().all(func(node):return node.get_meta("cue","")!="sfx_gun_reload" or not node.playing),"menu stops active combat audio")
				app.close_menus()
			await create_timer(app.firearm.reload_duration+.2).timeout
	for cue in ["sfx_gun_impact","sfx_shield_break"]:
		audio.play(cue);check(audio.last_played.has(cue),"impact playback "+cue)
		timeline.append({"cue":cue,"from":float(Time.get_ticks_msec()-started)/1000.0});await create_timer(.7).timeout
	await capture("audio-game-review")
	record.set_recording_active(false);var mixed:=record.get_recording()
	check(mixed!=null and mixed.get_length()>5,"actual SFX bus captured")
	if mixed!=null:mixed.save_to_wav(folder+"/combat-runtime-mix.wav")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var file:=FileAccess.open(folder+"/combat-runtime-timeline.json",FileAccess.WRITE);file.store_string(JSON.stringify(timeline,"\t"));file.close()
	check(await app.session.close_session(),"save after audio review")
	app.queue_free();await process_frame;await process_frame
	print("GROUND_AUDIO_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

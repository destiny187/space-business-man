extends "res://tests/review_firearm_upgrade.gd"
func run() -> void:
	folder="/tmp/weapon-loot-play-20260914"
	if not "--crew-ui-test" in OS.get_cmdline_user_args() or not ("--crew-folder="+folder) in OS.get_cmdline_user_args():quit(2);return
	var owner:=fixture()
	if owner.is_empty():quit(1);return
	var member: Dictionary=core.world.crew.members[actor_id];member.loadout.weapon_rolls={}
	var mapping: Dictionary={"ember":"pulse_2","shatter":"shotgun_2","arc":"smg_2","pierce":"sniper_3"}
	for legend in mapping:
		var id: String="fixture:"+str(mapping[legend]);member.loadout.weapon_rolls[id]=FrontierWeaponLoot.roll(mapping[legend],"legendary",444,"",legend)
		var gun:=FrontierFirearms.item(member,id);FrontierFirearms.ensure(member,gun)
	var drop:=FrontierWeaponLoot.roll("smg_2","legendary",42,"","arc");drop.definition="smg_2"
	core.world.incidents.records[robot_key].gun_reward_v2=drop
	var bag:=FrontierExpeditionBusiness.bag(core.world,actor_id)
	bag.copper=20;bag.crystal=10
	for id in FrontierFirearms.config().ammunition:bag[id]=int(FrontierFirearms.config().ammunition[id].amount)
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var store:=FrontierWorldStore.new(folder+"/world.json")
	if not store.write(core.world):printerr("FIXTURE_SAVE ",store.last_error," BAG ",bag);quit(1);return
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ ground loaded",90):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	core=app.session.authority
	var approach:=FrontierCrewWorld.vector(source.position)+Vector3(0,0,10);approach.y=app.surface_world.terrain.field.height(approach.x,approach.z)+.1
	app.actors[actor_id].position=approach;app.actors[actor_id].velocity=Vector3.ZERO;core.update_position(1,approach);core.motions[actor_id]=FrontierCrewLocomotion.create()
	if not await until(func():return app.surface_world.ready_at(app.actors[actor_id].position) and app.surface_world.incidents.models.has(robot_key),"combat ground streamed",55):quit(1);return
	# Restoring an isolated surface fixture puts its disconnected cargo in a crate.
	core.resolve_autonomous(true)
	bag=FrontierExpeditionBusiness.bag(core.world,actor_id)
	for crate in core.world.business.crates.values():FrontierExpeditionBusiness.transfer(bag,crate.inventory,1);crate.inventory=FrontierExpeditionBusiness.inventory()
	core.gun_dirty=true;app.session._publish()
	if "--ui-only" in OS.get_cmdline_user_args():
		await review_inventory();return
	app.session.firearm_event_received.connect(func(e):events.append(e))
	var record:=AudioEffectRecord.new();record.format=AudioStreamWAV.FORMAT_16_BITS
	var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,record);record.set_recording_active(true)
	await create_timer(.6).timeout
	for legend in mapping:
		var definition: String=mapping[legend]
		await transaction("equipment_equip",{"slot":2,"item_id":"fixture:"+definition})
		if not await until(func():return app.firearm.tool().get("legendary_id")==legend,"legendary instance equipped "+legend,4):continue
		await create_timer(.6).timeout;core.resolve_autonomous(true);reset_target()
		app.firearm.test_ads=false;look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.45,0)))
		await create_timer(.2).timeout
		var gun:=app.firearm.tool();events.clear();app.firearm.shoot()
		await until(func():return events.any(func(e):return e.get("impact_only",false) and e.family==gun.firearm),"real ballistic impact "+legend,4)
		check(app.feedback.equipped_model==gun.model and app.feedback.parts.size()>0,"authored legendary model and moving mechanisms "+legend)
		check(app.feedback.audio.last_played.has(gun.sound),"ElevenLabs firearm playback "+legend)
		await capture(legend+"-combat")
	core.resolve_autonomous(true)
	var robot: Dictionary=core.world.incidents.records[robot_key];robot.hp=0;robot.shield=0;robot.claimed=false;robot.gun_claimed=false;FrontierExplorationIncidents.set_phase(robot,"destroyed")
	core.gun_dirty=true;app.session._publish()
	var cargo:=FrontierExplorationIncidents.cargo_point(robot);var pickup:=cargo+Vector3(0,0,2.4);pickup.y=app.surface_world.terrain.field.height(pickup.x,pickup.z)+.1
	app.actors[actor_id].position=pickup;app.actors[actor_id].velocity=Vector3.ZERO;core.update_position(1,pickup);look_at_point(cargo)
	await create_timer(.7).timeout;await capture("legendary-drop")
	check(app.surface_world.incidents.selected.get("part")=="cargo","physical loot selected by F ray")
	core.resolve_autonomous(true);app.session._publish();app.surface_world.incidents.interact()
	await until(func():return core.world.incidents.records[robot_key].get("gun_claimed",false),"F recovery creates owned legendary",5)
	var acquired: Dictionary=core.world.incidents.records[robot_key].get("gun_drop",{})
	check(acquired.get("legendary_id")=="arc" and acquired.get("affixes",[]).size()==3,"recovered exact visible three-affix legendary")
	app.open_menu(app.inventory_panel)
	if not acquired.is_empty():
		app.inventory_panel.selected_item=acquired.item_id;app.inventory_panel.selected_definition=acquired.definition;app.inventory_panel.selected_resource="";app.inventory_panel.last_key=""
	await capture("inventory-1280")
	check(app.inventory_panel.preview.model_path=="equipment/legend_arc","inventory previews actual legendary")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("inventory-960")
	check(app.inventory_panel.detail_shell.size.x<root.size.x and app.inventory_panel.size.x<=root.size.x,"small-window details remain inside panel")
	app.inventory_panel.tabs.current_tab=1;app.inventory_panel.weapon_element="cryo";app.inventory_panel.selected_definition="pulse_1";app.inventory_panel.last_key="";await capture("craft-cryo-960")
	check(app.inventory_panel.stats.find_children("*","OptionButton",true,false).size()==1,"craft UI offers attack element selection")
	check(app.firearm.gun_effects.active.is_empty(),"menu stops combat presentation")
	app.close_menus();await create_timer(.3).timeout
	record.set_recording_active(false);var mixed:=record.get_recording()
	if mixed!=null:mixed.save_to_wav(folder+"/runtime-audio.wav")
	check(mixed!=null and mixed.get_length()>3,"actual SFX bus captured")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	check(await app.session.close_session(),"new weapon roll and ammunition saved")
	app.queue_free();await process_frame;await process_frame
	print("WEAPON_LOOT_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

func review_inventory() -> void:
	app.open_menu(app.inventory_panel)
	app.inventory_panel.selected_item="fixture:smg_2";app.inventory_panel.selected_definition="smg_2";app.inventory_panel.selected_resource="";app.inventory_panel.last_key=""
	await capture("inventory-1280-final")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("inventory-960-final")
	app.inventory_panel.detail_scroll.scroll_vertical=140;await capture("inventory-options-960-final")
	app.inventory_panel.tabs.current_tab=1;app.inventory_panel.weapon_element="cryo";app.inventory_panel.selected_definition="pulse_1";app.inventory_panel.last_key="";app.inventory_panel.detail_scroll.scroll_vertical=0
	await capture("craft-cryo-960-final")
	var choices:=app.inventory_panel.stats.find_children("*","OptionButton",true,false)
	check(choices.size()==1 and app.inventory_panel.detail_scroll.get_global_rect().encloses(choices[0].get_global_rect()),"craft element selector is actually visible at 960px")
	var loadout: Dictionary=core.world.crew.members[actor_id].loadout
	var rolls: Dictionary=loadout.weapon_rolls.duplicate(true)
	var ammo: Dictionary={}
	for id in loadout.weapon_states:ammo[id]=loadout.weapon_states[id].ammo
	check(await app.session.close_session(),"save revised UI fixture")
	var restored:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not restored.is_empty() and restored.crew.members[actor_id].loadout.weapon_rolls==rolls,"load exact stored option values and legends")
	var saved: Dictionary=restored.crew.members[actor_id].loadout.weapon_states
	check(ammo.keys().all(func(id):return saved[id].ammo==ammo[id]),"load actual magazine counts")
	app.queue_free();await process_frame;await process_frame
	print("WEAPON_LOOT_UI_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

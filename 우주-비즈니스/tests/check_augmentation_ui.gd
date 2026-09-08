extends "res://tests/test_solo_entry.gd"
func press(key: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=key;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
func run() -> void:
	folder="/tmp/augmentation-a04"
	if "--crew-folder=/tmp/augmentation-a04" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var owner:=FrontierPlayerProfile.new_character("증강 탐험가",2)
	FrontierWorldStore.new(folder+"/world.json").write(FrontierUniverse.new_world(71491))
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"ship scene",60):quit(1);return
	if not app.test_mode or app.world_store.path!=folder+"/world.json" or app.session.latest.self_id!=owner.character_id:printerr("ISOLATION_MISMATCH");quit(1);return
	app.outside=false;app.exterior_view.hide();app.if_flight_view();app.close_menus();app.onboarding.letter.hide()
	var station: FrontierCrewStation=app.stations.cabin.get_node("Station_augmentation")
	var actor: CharacterBody3D=app.actors[owner.character_id]
	actor.position=station.global_position+station.global_basis.z*2.1+Vector3.UP*.1;app.session.authority.update_position(1,actor.position)
	var direction: Vector3=(station.interaction_point()-(actor.position+Vector3.UP*1.72)).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
	var world: Dictionary=app.session.authority.world
	world.business=FrontierExpeditionBusiness.create();world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory()
	for id in ["sapphire","ruby","emerald"]:world.business.bags[owner.character_id][id]=12
	world.crew.members[owner.character_id].loadout.items["test:pulse"]="pulse_1";world.crew.members[owner.character_id].loadout.slots[1]="test:pulse"
	app.session._publish();app.session._publish_surface()
	await create_timer(.4).timeout;await press(KEY_F)
	var page: FrontierAugmentationPanel=app.stations.augmentation
	check(page.is_visible_in_tree() and page.body.preview.character!=null,"F opens own rigged character and scanner")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;await capture("body-ready")
	var recording:=AudioEffectRecord.new();AudioServer.add_bus_effect(AudioServer.get_bus_index("UI"),recording);recording.set_recording_active(true)
	var before: int=page.bag().sapphire
	page.gems.sapphire.pressed.emit();await process_frame
	check(page.loaded and page.bag().sapphire==before and page.body.preview.gem!=null,"click prepares visible gem without consuming it")
	await capture("gem-prepared")
	page.action.pressed.emit();await process_frame
	check(page.phase=="success" and page.last_receipt.get("ok",false) and page.bag().sapphire==before-3,"host receipt confirms a single gem purchase")
	check(page.body.preview.effects.active.size()>0 and page.speaker.playing,"accepted growth plays success effects and ElevenLabs cue")
	var level:=FrontierCrewAugmentation.level(page.member(),"mobility");page.submit();check(FrontierCrewAugmentation.level(page.member(),"mobility")==level,"repeat click during result does not buy again")
	await capture("growth-success")
	await create_timer(1.2).timeout
	page.body.buttons.combat.pressed.emit()
	check(page.slot._can_drop_data(Vector2.ZERO,{"augmentation_gem":"ruby"}),"gem slot accepts drag payload")
	page.slot._drop_data(Vector2.ZERO,{"augmentation_gem":"sapphire"})
	check(not page.loaded and page.phase=="error","wrong gem is rejected visibly")
	page.slot._drop_data(Vector2.ZERO,{"augmentation_gem":"ruby"});page.action.pressed.emit();await create_timer(1.3).timeout
	page.body.buttons.vitality.pressed.emit();page.gems.emerald.pressed.emit();page.action.pressed.emit();await create_timer(1.3).timeout
	check(FrontierCrewAugmentation.level(page.member(),"combat")==1 and FrontierCrewAugmentation.maximum_health(page.member())==120,"combat and vitality purchases update personal stats")
	recording.set_recording_active(false);recording.get_recording().save_to_wav(folder+"/augmentation-ui-cues.wav")
	app.close_menus();app.session.send_request("equipment_select",{"slot":1});await process_frame
	check(FrontierEquipment.active(app.session.latest.crew.members[owner.character_id]).damage==roundi(float(FrontierEquipment.config().items.pulse_1.damage)*1.1),"equipped pulse damage includes purchased augmentation")
	await press(KEY_I);app.inventory_panel.tabs.current_tab=3;root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("body-inventory-960")
	check(app.inventory_panel.augmentation_readout.is_visible_in_tree() and app.inventory_panel.augmentation_readout.rows.vitality.label.text.contains("120"),"I body page retains abilities after equipment change")
	app.close_menus();await press(KEY_F);await capture("body-station-960")
	check(page.action.get_global_rect().end.x<=960 and page.message.get_global_rect().end.y<=640,"station controls fit 960 viewport")
	# A host refusal must clear local preparation without a success cue.
	page.select_field("mobility");page.prepare_gem("sapphire")
	app.session.authority.augmentation_station_provider=func(_actor: String,_id: String):return {}
	page.submit();check(page.phase=="error" and not page.loaded and page.pending_sequence==0,"host refusal clears prepared slot without success")
	app.session.authority.augmentation_station_provider=app.stations.resolve
	await capture("refused")
	# Delayed receipt fixture: keep the request pending across close, ignore unrelated replies.
	var receipt:=page.last_receipt.duplicate(true)
	receipt={"ok":true,"revision":app.session.latest.crew.revision,"augmentation":{"previous_level":0,"level":1}}
	page.sending=true;page.requested(999,"augmentation_upgrade",{});page.sending=false;page.set_phase("waiting")
	app.close_menus();page.responded(998,receipt)
	check(page.pending_sequence==999,"unrelated reply cannot complete a pending augmentation")
	page.responded(999,receipt)
	check(page.pending_sequence==0 and page.phase=="success" and not page.speaker.playing and not page.process_sound.playing,"closed panel accepts delayed receipt without playing audio")
	# Real landing applies the purchased movement/health to the controllable character.
	world=app.session.authority.world
	var destination:=FrontierCrewNavigation.first_destination(world.manifest);var planet:=FrontierUniverse.body(world.manifest,destination)
	world.crew.navigation.system=FrontierUniverse.system_index(world.manifest,destination);world.crew.navigation.target=destination
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(destination,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
	app.session.send_request("ready",{"value":true});app.session.send_request("land",{})
	if not await until(func():return app.surface_world!=null and not app.arrival.active and app.surface_world.ready_at(actor.position),"landed collision",60):quit(1);return
	app.test_direction=Vector2(1,0);await create_timer(.4).timeout;app.test_direction=Vector2.ZERO
	check(absf(Vector2(actor.velocity.x,actor.velocity.z).length()-float(FrontierCrewSurface.config().movement_speed)*1.1)<.25,"purchased mobility changes actual ground speed")
	check(app.field_hud.instruments.health.max_value==120,"purchased vitality changes actual HUD")
	await capture("purchased-ground-stats")
	check(app.session.authority.world.business.bags[owner.character_id].sapphire==9,"landing keeps unspent gems in own bag")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	verify_saved()
	print("AUGMENTATION_A04_UI ",checks," FAILURES ",failures);quit(1 if failures else 0)
func verify_saved() -> void:
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	var id: String=saved.crew.owner_id
	var own: Dictionary=saved.crew.members[id]
	check(FrontierCrewAugmentation.level(own,"mobility")==1 and FrontierCrewAugmentation.level(own,"combat")==1 and FrontierCrewAugmentation.level(own,"vitality")==1 and int(saved.business.crates.values()[0].inventory.sapphire)==9,"saved levels and departure recovery gems survive JSON number conversion")
	var resumed:=FrontierCrewAuthority.new()
	check(resumed.start(saved,own.profile,func(_world: Dictionary):return true) and FrontierCrewAugmentation.maximum_health(resumed.world.crew.members[id])==120 and FrontierCrewAugmentation.level(resumed.world.crew.members[id],"combat")==1,"host world resume retains purchased augmentation")

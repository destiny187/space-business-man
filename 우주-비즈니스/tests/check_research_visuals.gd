extends "res://tests/test_solo_entry.gd"
func press(key: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=key;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
func run() -> void:
	folder="/tmp/research-a06-ui"
	if "--crew-folder=/tmp/research-a06-ui" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	if "--layout-only" in OS.get_cmdline_user_args():await review_layout();return
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("표본 연구원",0)
	FrontierWorldStore.new(folder+"/world.json").write(FrontierUniverse.new_world(71491))
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"ship scene",60):quit(1);return
	app.outside=false;app.exterior_view.hide();app.if_flight_view();app.close_menus();app.onboarding.letter.hide()
	var bench: FrontierCrewStation=app.stations.cabin.get_node("Station_research")
	var actor: CharacterBody3D=app.actors[owner.character_id]
	actor.position=bench.global_position+bench.global_basis.z*2.1+Vector3.UP*.1;app.session.authority.update_position(1,actor.position)
	var direction: Vector3=(bench.interaction_point()-(actor.position+Vector3.UP*1.72)).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
	var world: Dictionary=app.session.authority.world
	world.business=FrontierExpeditionBusiness.create();world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory();world.business.bags[owner.character_id].merge({"sapphire":3,"reinforced_frame":1,"control_circuit":1})
	app.session._publish();await create_timer(.3).timeout;await press(KEY_F)
	var ui: FrontierExpeditionResearchPanel=app.stations.research
	check(app.stations.panel.visible and ui.visible,"F opens visual specimen bench")
	await capture("unseen")
	FrontierExpeditionResearch.record(world,world.location,"sapphire","fixture:gem",2,"extraction",owner.character_id);app.session._publish();await process_frame
	ui.slot._drop_data(Vector2.ZERO,{"research_sample":"sapphire"});ui.quantity.value=3
	check(ui.loaded and ui.preview.specimen!=null and world.business.bags[owner.character_id].sapphire==3,"drag prepares real specimen without consuming gems")
	await capture("prepared")
	var rotor: Node3D=ui.preview.model.find_child("Anim_SpecimenTurntable",true,false);var old_transform:=rotor.transform;await create_timer(.2).timeout
	check(rotor.transform!=old_transform,"Blender turntable moves during preparation")
	ui.prepare("ruby");check(ui.phase=="error" and ui.speaker.playing,"unobserved specimen shows and plays rejection")
	ui.prepare("sapphire");ui.action.pressed.emit();await process_frame
	check(ui.last_receipt.get("ok",false) and app.session.latest.expedition_research.projects.deep_mining.stage=="analyzed" and ui.phase=="success" and ui.speaker.playing,"receipt confirms analysis and ElevenLabs result sound")
	await capture("analyzed")
	await press(KEY_ESCAPE);check(not ui.process_sound.playing,"closing menu stops station audio")
	await press(KEY_J);app.session._publish();await create_timer(.2).timeout
	check(app.research_frame.visible and app.research_frame.expedition.is_visible_in_tree() and not app.research_frame.expedition.action.visible,"J shows read-only shared research in cabin across snapshot")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("journal-960")
	check(app.research_frame.expedition.get_global_rect().end.x<=960,"small research journal fits width")
	app.close_menus();world=app.session.authority.world
	var destination:=FrontierCrewNavigation.first_destination(world.manifest);var planet:=FrontierUniverse.body(world.manifest,destination)
	world.crew.navigation.system=FrontierUniverse.system_index(world.manifest,destination);world.crew.navigation.target=destination
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(destination,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
	app.session.send_request("ready",{"value":true});app.session.send_request("land",{})
	if not await until(func():return app.surface_world!=null and not app.arrival.active and app.surface_world.ready_at(actor.position),"landed factory scene",60):quit(1);return
	world=app.session.authority.world
	var site:=FrontierExpeditionBusiness.ensure_site(world);site.state="active";world.business.active=world.location
	var used: Array[Vector3]=[]
	for kind in ["factory","solar","solar"]:
		var found:=false
		for x in range(-32,33,6):
			if found:break
			for z in range(-32,33,6):
				var point:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x,z,2.4)
				if not point.is_finite() or used.any(func(other: Vector3):return other.distance_to(point)<7):continue
				if not FrontierExpeditionBusiness.placement(world,kind,point,app.session.authority.peers).is_empty():continue
				var id: String=kind if not site.buildings.has(kind) else kind+"2"
				site.buildings[id]={"id":id,"type":kind,"position":FrontierExpeditionBusiness.array(point),"yaw":0.0,"enabled":true,"active":false,"status":"전력 확인 중","work":0.0,"tier":2 if kind=="factory" else 1};used.append(point);found=true;break
	check(site.buildings.has("factory") and site.buildings.has("solar2"),"supported factory and generators fixture")
	app.session._publish_surface()
	if not await until(func():return app.surface_world.business_view.nodes.has("factory") and FrontierExpeditionBusiness.site(app.session.authority.world).buildings.factory.active,"live powered factory",20):quit(1);return
	var position:=FrontierCrewWorld.vector(FrontierExpeditionBusiness.site(app.session.authority.world).buildings.factory.position)+Vector3(0,0,5)
	position.y=app.surface_world.terrain.field.height(position.x,position.z)+.1;actor.position=position;app.session.authority.update_position(1,position);app.session._publish();app.session._publish_surface();await create_timer(.2).timeout
	app.open_station("factory","factory")
	var factory_ui: FrontierExpeditionResearchPanel=app.business_panel.tabs.get_node("시험기 조립")
	app.business_panel.tabs.current_tab=factory_ui.get_index();await process_frame
	check(factory_ui.is_visible_in_tree() and not factory_ui.action.disabled,"actual factory offers prototype assembly")
	await capture("factory-prepared-960")
	factory_ui.action.pressed.emit();await process_frame
	check(factory_ui.last_receipt.get("ok",false) and not factory_ui.assembled_id.is_empty(),"factory receipt creates real prototype")
	if factory_ui.assembled_id.is_empty():print(factory_ui.message.text);quit(1);return
	await capture("factory-complete-960")
	var item: String=factory_ui.assembled_id
	app.close_menus();app.session.send_request("equipment_equip",{"item_id":item,"slot":1});app.session.send_request("equipment_select",{"slot":1});await create_timer(.3).timeout
	check(app.feedback.equipped_model=="equipment/miner_probe" and not app.feedback.parts.is_empty(),"prototype loads handheld mesh and motion pivots")
	await capture("probe-equipped")
	# Existing cargo path preserves the actual equipment, not a research-only token.
	var base:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(3,0,0);base.y=app.surface_world.terrain.field.height(base.x,base.z)+.1;actor.position=base;app.session.authority.update_position(1,base);app.session._publish()
	app.session.send_request("deposit",{"item_id":item});check(not app.session.latest.crew.members[owner.character_id].loadout.items.has(item),"probe stored through actual ship cargo request")
	app.session.send_request("withdraw",{"item_id":item});check(app.session.latest.crew.members[owner.character_id].loadout.items.get(item)=="miner_probe","probe retrieved through actual ship cargo request")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	var saved_world:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(saved_world.expedition_research.projects.deep_mining.stage=="prototyped" and saved_world.crew.members[owner.character_id].loadout.items[item]=="miner_probe","save reload keeps prototype and shared stage")
	print("RESEARCH_VISUALS_A06 ",checks," FAILURES ",failures);quit(1 if failures else 0)

func review_layout() -> void:
	folder="/tmp/research-a06-ui"
	if "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not has_meta("startup_loader") and not app.arrival.active,"saved field scene",60):quit(1);return
	app.onboarding.letter.hide();app.close_menus()
	var world: Dictionary=app.session.authority.world;var actor: CharacterBody3D=app.actors[app.session.latest.self_id]
	var factory: Dictionary=FrontierExpeditionBusiness.site(world).buildings.factory
	var pos:=FrontierCrewWorld.vector(factory.position)+Vector3(0,0,5);pos.y=app.surface_world.terrain.field.height(pos.x,pos.z)+.1;actor.position=pos;app.session.authority.update_position(1,pos);app.session._publish();app.session._publish_surface();await create_timer(.5).timeout
	app.open_station("factory","factory")
	var ui: FrontierExpeditionResearchPanel=app.business_panel.tabs.get_node("시험기 조립");app.business_panel.tabs.current_tab=ui.get_index();await create_timer(.3).timeout
	await capture("factory-compact-960")
	check(ui.action.get_global_rect().end.y<616 and ui.message.get_global_rect().end.y<616,"factory action and outcome fit 960x640 without scrolling")
	# Review unassembled model/connection silhouettes from the same saved scene.
	world=app.session.authority.world;world.expedition_research.projects.deep_mining.stage="analyzed";world.expedition_research.projects.deep_mining.prototype={};app.session._publish()
	await capture("factory-exploded-960")
	world=app.session.authority.world
	world.business.bags[app.session.latest.self_id].reinforced_frame=1;world.business.bags[app.session.latest.self_id].control_circuit=1;app.session._publish();await process_frame
	ui.refresh();print("ASSEMBLY_READY ",ui.action.disabled," ",ui.hint.text);ui.action.pressed.emit();await create_timer(.15).timeout
	print("ASSEMBLY_RESULT ",ui.last_receipt," ",ui.preview.separation)
	check(ui.last_receipt.get("ok",false) and ui.preview.separation>0 and ui.preview.separation<1,"host success drives physical head assembly")
	await create_timer(.6).timeout
	check(ui.preview.separation==0,"head finishes in assembled pose")
	await capture("factory-success-960")
	print("RESEARCH_A06_LAYOUT ",checks," FAILURES ",failures)
	# This branch uses only the isolated world produced by the full visual check.
	quit(1 if failures else 0)

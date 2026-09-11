extends "res://tests/check_lotus_play.gd"
func run() -> void:
	folder="/tmp/xenofauna-play"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/xenofauna-play" not in OS.get_cmdline_user_args():quit(2);return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/fixture.json"))
	var owner:=FrontierPlayerProfile.new_character("새 생물 현장 확인",2);var id: String=owner.character_id
	var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"isolated host start")
	var world: Dictionary=core.world;world.crew.phase="playing"
	# This fixture begins after departure; an unfinished fresh-world opening blocks Q.
	if world.crew.navigation.has("solar_opening"):world.crew.navigation.solar_opening.elapsed=world.crew.navigation.solar_opening.duration
	var body:=FrontierUniverse.body(world.manifest,int(fixture.ordinal));var field:=FrontierExplorationIncidents.field(body)
	var at:=FrontierCrewWorld.vector(fixture.encounter.point)
	var form:=FrontierEcologyCatalog.form(fixture.encounter.form_id)
	var height: float=(float(form.geometry.near.max[1])-float(form.geometry.near.floor_y))*float(FrontierEcologyCatalog.look(form.id,fixture.encounter.look_id).scale)
	var eye:=at+field.normal(at)*maxf(.35,height*.5)
	var approach:=at+Vector3(0,0,3.1);var best:=INF
	for i in 16:
		var p:=at+Vector3.RIGHT.rotated(Vector3.UP*1.0,float(i)*TAU/16)*3.1;p.y=field.height(p.x,p.z)+.1
		var delta:=absf(p.y-at.y)
		if delta<best and FrontierCrewSurface.visible_in_field(field,p+Vector3.UP*1.72,eye):approach=p;best=delta
	world.location=body.id;world.navigation_target=body.id;world.crew.navigation.system=body.system_ordinal;world.crew.navigation.target=body.ordinal
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(int(body.ordinal),world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
	world.crew.members[id].ready=true
	check(FrontierCrewSurface.apply(world,id,"land",{},{1:id}).is_empty(),"land on naturally inhabited T1/T2 planet")
	world.crew.members[id].position=FrontierExpeditionBusiness.array(approach);world.business.bags[id]=FrontierExpeditionBusiness.inventory()
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(world),"save natural-position fixture "+store.last_error)
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ actual surface ready",90):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var actor: CharacterBody3D=app.actors[id];look(actor,approach,eye);app.session._publish()
	if not await until(func():return app.surface_world.ecology.actors.has(fixture.encounter.id),"new natural animal loaded with ground support",35):quit(1);return
	var creature: Node3D=app.surface_world.ecology.actors[fixture.encounter.id]
	check(creature.definition.id==form.id and creature.models.size()==2,"correct Blender species and both LODs")
	var joint: Node3D=creature.joints[0].Anim_Body.node;var start_pose: Transform3D=joint.transform
	await create_timer(1.1).timeout
	var moving:=not joint.transform.is_equal_approx(start_pose)
	if not moving:
		var pose_before: Array=[]
		for part in creature.joints[0].values():pose_before.append(part.node.transform)
		await create_timer(.6).timeout
		var index:=0
		for part in creature.joints[0].values():moving=moving or not part.node.transform.is_equal_approx(pose_before[index]);index+=1
	check(moving,"new anatomical idle motion active")
	var output:=ProjectSettings.globalize_path("res://../docs/production/media/xenofauna")
	var save_folder:=folder;folder=output;await capture("field-encounter")
	app.test_scan=true
	var scanned:=await until(func():return app.session.authority.world.ecology.observations.has(body.id+":"+form.id),"held E scans new species via host",12)
	app.test_scan=false
	if not scanned:print("XENO_SCAN_DEBUG ",app.session.authority.scans," aim ",app.surface_target);quit(1);return
	# Existing ElevenLabs call is emitted from this real living actor through the current soundscape.
	var soundscape: Node=app.surface_world.presence.sounds
	soundscape._event("creature",at,-18)
	var peak:=-100.0
	for i in 8:
		await create_timer(.08).timeout;peak=maxf(peak,AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Ambience"),0))
	check(peak> -75,"ElevenLabs creature playback reaches game audio bus")
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(2);app.survey_journal.refresh()
	if not await until(func():return app.survey_journal.selected_entry.get("kind","")=="biology","new discovery journal entry",6):quit(1);return
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("journal-960")
	check(app.survey_journal.preview.model_path==FrontierEcologyCatalog.model_key(form),"journal resolves actual new model path")
	check(app.feedback.blocked(),"menu blocks field controls")
	app.close_menus();look(actor,approach,eye);await create_timer(.4).timeout
	var key:=InputEventKey.new();key.physical_keycode=KEY_Q;key.pressed=true;app._unhandled_input(key)
	check(await until(func():return not app.session.authority.world.ecology.specimens.is_empty(),"Q collects the real specimen",6),"physical new species collection")
	check(await app.session.close_session(),"new species state saved")
	var reloaded:=FrontierWorldStore.new(save_folder+"/world.json");var restored:=reloaded.read_state()
	check(not restored.is_empty() and restored.ecology.observations.has(body.id+":"+form.id),"new species and observation reload")
	FileAccess.open(output+"/play-check.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"form":form.id,"body":body.id,"ordinal":body.ordinal,"audio_peak_db":peak,"scope":"자연 배치 위치 준비 후 실제 현장 모델·E/Q·J·음원·저장 확인"},"  "))
	app.queue_free();await process_frame;await process_frame
	print("XENO_PLAY CHECKS ",checks," FAILURES ",failures);quit(0 if failures==0 else 1)

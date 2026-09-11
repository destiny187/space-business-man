extends "res://tests/check_lotus_play.gd"
func view_position(field: FrontierTerrainField,fixture: Dictionary) -> Dictionary:
	var at:=FrontierCrewWorld.vector(fixture.encounter.point);var form:=FrontierEcologyCatalog.form(fixture.encounter.form_id)
	var height: float=(float(form.geometry.near.max[1])-float(form.geometry.near.floor_y))*float(FrontierEcologyCatalog.look(form.id,fixture.encounter.look_id).scale)
	var eye:=at+field.normal(at)*maxf(.35,height*.5);var approach:=at+Vector3(0,0,3.0);var best:=INF
	for i in 16:
		var p:=at+Vector3.RIGHT.rotated(Vector3.UP,float(i)*TAU/16)*3.0;p.y=field.height(p.x,p.z)+.1
		var difference:=absf(p.y-at.y)
		if difference<best and FrontierCrewSurface.visible_in_field(field,p+Vector3.UP*1.72,eye):approach=p;best=difference
	return {"at":approach,"eye":eye}
func run() -> void:
	folder="/tmp/xenoflora-play"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/xenoflora-play" not in OS.get_cmdline_user_args():quit(2);return
	var fixtures: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/fixtures.json"))
	check(fixtures.plant.body_id==fixtures.microbe.body_id,"natural plant and microbe share focused planet")
	var owner:=FrontierPlayerProfile.new_character("식물·군락 현장 검수",2);var id: String=owner.character_id
	var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"isolated host start")
	var world: Dictionary=core.world;world.crew.phase="playing"
	if world.crew.navigation.has("solar_opening"):world.crew.navigation.solar_opening.elapsed=world.crew.navigation.solar_opening.duration
	var body:=FrontierUniverse.body(world.manifest,int(fixtures.plant.ordinal));var field:=FrontierExplorationIncidents.field(body)
	world.location=body.id;world.navigation_target=body.id;world.crew.navigation.system=body.system_ordinal;world.crew.navigation.target=body.ordinal
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(int(body.ordinal),world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
	world.crew.members[id].ready=true;check(FrontierCrewSurface.apply(world,id,"land",{},{1:id}).is_empty(),"land on natural T1 ecology")
	world.crew.members[id].position=FrontierExpeditionBusiness.array(view_position(field,fixtures.plant).at);world.business.bags[id]=FrontierExpeditionBusiness.inventory()
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(world),"save prepared approach "+store.last_error)
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"actual Forward+ surface ready",90):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var actor: CharacterBody3D=app.actors[id];var output:=ProjectSettings.globalize_path("res://../docs/production/media/xenoflora");var save_folder:=folder;folder=output
	var played: Array=[];var expected_specimens:=0
	for category in ["plant","microbe"]:
		root.size=Vector2i(1280,800);root.content_scale_size=root.size
		var fixture: Dictionary=fixtures[category];var form:=FrontierEcologyCatalog.form(fixture.encounter.form_id);var view:=view_position(field,fixture)
		look(actor,view.at,view.eye);app.session._publish()
		if not await until(func():return app.surface_world.ecology.actors.has(fixture.encounter.id),category+" naturally placed model loaded",30):quit(1);return
		var living: Node3D=app.surface_world.ecology.actors[fixture.encounter.id]
		check(living.definition.id==form.id and living.models.size()==2,category+" correct Blender source and LODs")
		var before: Array=[]
		for part in living.joints[0].values():before.append(part.node.transform)
		await create_timer(.9).timeout;var index:=0;var moving:=false
		for part in living.joints[0].values():moving=moving or not part.node.transform.is_equal_approx(before[index]);index+=1
		check(moving,category+" organic pose active");await capture(category+"-field")
		app.test_scan=true
		var scanned:=await until(func():return app.session.authority.world.ecology.observations.has(body.id+":"+form.id),category+" held E host scan",10)
		app.test_scan=false
		if not scanned:quit(1);return
		check(app.feedback.audio.last_played.has("ui_discovery"),category+" accepted discovery audio")
		app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(2)
		app.survey_journal.search.text=form.name;app.survey_journal.refresh()
		if not await until(func():return app.survey_journal.selected_entry.get("row",{}).get("form_id","")==form.id,category+" journal search returns observed species",6):quit(1);return
		root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture(category+"-journal-960")
		check(app.survey_journal.preview.model_path==FrontierEcologyCatalog.model_key(form),category+" journal actual model")
		check(app.feedback.blocked(),category+" menu blocks tools")
		app.close_menus();look(actor,view.at,view.eye);await create_timer(.4).timeout
		var key:=InputEventKey.new();key.physical_keycode=KEY_Q;key.pressed=true;app._unhandled_input(key);expected_specimens+=1
		check(await until(func():return app.session.authority.world.ecology.specimens.size()==expected_specimens,category+" Q specimen",6),category+" physical sample")
		var peak:=-100.0
		for i in 7:await create_timer(.07).timeout;peak=maxf(peak,AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("SFX"),0))
		check(app.feedback.audio.last_played.has("sfx_pickup_resource") and peak> -75,category+" accepted pickup playback")
		played.append({"category":category,"form":form.id,"audio_peak_db":peak})
	check(await app.session.close_session(),"save both observations and carried specimens")
	var restored:=FrontierWorldStore.new(save_folder+"/world.json").read_state()
	check(not restored.is_empty() and restored.ecology.observations.size()==2 and restored.ecology.specimens.size()==2,"reload both categories")
	FileAccess.open(output+"/play-check.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"body":body.id,"ordinal":body.ordinal,"played":played,"scope":"자연종의 준비된 접근 위치에서 실제 E/Q/J·모션·음원·저장 확인"},"  "))
	app.queue_free();await process_frame;await process_frame;print("XENOFLORA_PLAY ",checks," failures=",failures);quit(0 if failures==0 else 1)

extends "res://tests/check_biota_surface.gd"
## A natural home, actual weighted model, deterministic host scan and landing sample.
func set_phase(living: Node3D,candidate: Dictionary,field: FrontierTerrainField,phase: float) -> void:
	var seed_phase: float=float(FrontierUniverse.derive(int(field.seed_value),"flight:"+str(candidate.id))%48000)/1000.0
	app.session.authority.world.crew.navigation.orbit_time=480.0+phase-seed_phase
	app.session._publish();app.surface_world.ecology.sync_clock(float(app.session.authority.world.crew.navigation.orbit_time))
	app.surface_world.ecology._update_flights()

func center_of(living: Node3D) -> Vector3:
	var form: Dictionary=living.definition
	var height: float=(float(form.geometry.near.max[1])-float(form.geometry.near.floor_y))*living.base_scale
	return living.global_position+living.global_basis.y*maxf(.35,height*.5)

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--crew-ui-test" not in args or "--crew-folder=/tmp/biota-avian-play" not in args:quit(2);return
	var fixture_mode: bool="--recipe-fixture" in args
	if fixture_mode:load("res://tests/native_biota_fixture.gd").prepare()
	var destination:="/tmp/biota-avian-play";DirAccess.make_dir_recursive_absolute(destination)
	folder=ProjectSettings.globalize_path("res://../docs/production/media/biota/flight");DirAccess.make_dir_recursive_absolute(folder)
	var owner:=FrontierPlayerProfile.new_character("조류 비행 검수",2);var id: String=owner.character_id
	var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"create native avian galaxy")
	var world: Dictionary=core.world;var body: Dictionary={};var fixture: Dictionary={};var field: FrontierTerrainField
	for ordinal in world.manifest.native_biota.planets:
		var home: Dictionary=world.manifest.native_biota.planets[ordinal]
		if home.origin!="established" or int(home.tier)>2:continue
		if not home.lineages.any(func(row):return FrontierEcologyCatalog.form(row.form_id).get("construction","")=="avian"):continue
		var option:=FrontierUniverse.body(world.manifest,int(ordinal));var record:=FrontierEcology.ensure_planet(world.ecology,option);var terrain_field:=FrontierExplorationIncidents.field(option)
		for location in [Vector3(70,0,70),Vector3(-70,0,70),Vector3(70,0,-70),Vector3(140,0,70),Vector3(-140,0,70),Vector3(0,0,140)]:
			for candidate in FrontierEcologyPlacement.candidates(option,record,location):
				var form:=FrontierEcologyCatalog.form(candidate.form_id)
				if form.get("construction","")!="avian" or not form.has("lods"):continue
				var point:=FrontierEcologyPlacement.ground(terrain_field,candidate)
				if not point.is_finite() or FrontierEcology.status(record,form,point,"surface")!="active":continue
				candidate.point=FrontierExpeditionBusiness.array(point);fixture={"encounter":candidate};body=option;field=terrain_field;break
			if not fixture.is_empty():break
		if not fixture.is_empty():break
	check(not fixture.is_empty(),"established avian home and landing site exist on actual terrain")
	if fixture.is_empty():quit(1);return
	var form:=FrontierEcologyCatalog.form(fixture.encounter.form_id);var home_point:=FrontierCrewWorld.vector(fixture.encounter.point)
	var pressure: float=FrontierEcology.profile(body).pressure
	check(pressure>=float(form.flight.minimum_pressure_kpa),"native atmosphere supports authored wing flight")
	var incompatible:=FrontierEcology.profile(body);incompatible.pressure=0.0
	check(not FrontierEcology.unsuitable(form,incompatible,"surface").is_empty(),"vacuum cannot support the avian form")
	world.crew.phase="playing"
	if world.crew.navigation.has("solar_opening"):world.crew.navigation.solar_opening.elapsed=world.crew.navigation.solar_opening.duration
	world.location=body.id;world.navigation_target=body.id;world.crew.navigation.system=body.system_ordinal;world.crew.navigation.target=body.ordinal
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(int(body.ordinal),world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
	world.crew.members[id].ready=true;check(FrontierCrewSurface.apply(world,id,"land",{},{1:id}).is_empty(),"land at native avian home")
	var approach:=view_position(field,fixture);world.crew.members[id].position=FrontierExpeditionBusiness.array(approach.at)
	world.business.bags[id]=FrontierExpeditionBusiness.inventory()
	var store:=FrontierWorldStore.new(destination+"/world.json");check(store.write(world),"save prepared native approach "+store.last_error)
	var profile:=FrontierPlayerProfile.new(destination+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"actual Forward+ avian home ready",90):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var player: CharacterBody3D=app.actors[id];look(player,approach.at,approach.eye);app.session._publish()
	if not await until(func():return app.surface_world.ecology.actors.has(fixture.encounter.id) and app.surface_world.ecology.actors[fixture.encounter.id].models.size()==2,"native avian weighted model loaded",30):quit(1);return
	var living: Node3D=app.surface_world.ecology.actors[fixture.encounter.id]
	check(living.definition.id==form.id and living.anatomical_skeletons.size()==2,"actual avian source and two LOD skeletons")
	for part in ["Anim_WingShoulder_L0","Anim_WingElbow_L0","Anim_WingWrist_L0","Anim_AvianHip_L"]:check(form.rig.hinges.has(part),"dedicated articulated "+part)
	for phase in [{"time":3.0,"name":"rest"},{"time":14.5,"name":"takeoff"},{"time":25.0,"name":"flight"},{"time":45.5,"name":"landing"}]:
		set_phase(living,fixture.encounter,field,phase.time);await create_timer(.2).timeout
		aim_at(player,center_of(living));await create_timer(.2).timeout
		var expected:=FrontierEcologyPlacement.flight_pose(field,app.surface_world.ecology.encounters[fixture.encounter.id],home_point,float(app.session.authority.world.crew.navigation.orbit_time))
		check(living.position.distance_to(expected.point)<.25,phase.name+" host and visible position agree")
		check(field.density(living.position+Vector3.UP*.15)<0,phase.name+" body clears terrain")
		await capture(phase.name)
	set_phase(living,fixture.encounter,field,22.0);await create_timer(.3).timeout
	var prior:=living.position;var shoulder: Node3D=living.joints[0].Anim_WingShoulder_L0.node;var wing_before:=shoulder.transform
	await create_timer(.35).timeout
	check(living.position.distance_to(prior)>.12 and not shoulder.transform.is_equal_approx(wing_before),"moves through air while the wing joint flaps")
	app.test_scan=true
	var scan_deadline:=Time.get_ticks_msec()+9000
	while Time.get_ticks_msec()<scan_deadline and not app.session.authority.world.ecology.observations.has(body.id+":"+form.id):
		aim_at(player,center_of(living));await process_frame
	app.test_scan=false
	check(app.session.authority.world.ecology.observations.has(body.id+":"+form.id),"hold E while tracking airborne animal")
	check(await until(func():return app.feedback.audio.last_played.has("ui_discovery"),"confirmed scan reaches client audio",2),"host-confirmed airborne scan audio")
	set_phase(living,fixture.encounter,field,45.5);await create_timer(3.0).timeout
	check(living.position.distance_to(home_point)<.10 and living.flight_blend<.01,"lands back at the same physical home point")
	look(player,approach.at,center_of(living));await create_timer(.5).timeout;aim_at(player,center_of(living));await create_timer(.2).timeout
	await capture("landed-sample")
	var key:=InputEventKey.new();key.physical_keycode=KEY_Q;key.pressed=true;app._unhandled_input(key)
	check(await until(func():return app.session.authority.world.ecology.specimens.size()==1,"Q after natural landing",5),"landed specimen recorded")
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(2);app.survey_journal.search.text=form.name;app.survey_journal.refresh()
	check(await until(func():return app.survey_journal.selected_entry.get("row",{}).get("form_id","")==form.id,"J finds observed bird",6),"avian journal entry")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("journal-960")
	check(app.survey_journal.preview.model_path==FrontierEcologyCatalog.model_key(form),"J uses actual avian model")
	check(await app.session.close_session(),"save flight discovery and landing specimen")
	var restored:=FrontierWorldStore.new(destination+"/world.json").read_state()
	check(not restored.is_empty() and restored.ecology.observations.has(body.id+":"+form.id) and restored.ecology.specimens.size()==1,"avian source and collected sample reload")
	FileAccess.open(folder+"/play-check.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"body":body.id,"form":form.id,"recipe_fixture":fixture_mode,"scope":"실제 원산지에서 휴식·이륙·비행·착륙·이동 표적 E·착지 Q·J·저장"},"  "))
	app.queue_free();await process_frame;print("AVIAN_FLIGHT_CHECKS ",checks," FAILURES ",failures);quit(0 if failures==0 else 1)

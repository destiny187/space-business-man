extends "res://tests/check_xenoflora_play.gd"
## Prepared approach positions; all species still come from their unique native home.
func aim_at(actor: CharacterBody3D,target: Vector3) -> void:
	var delta:=target-actor.position-Vector3.UP*1.72
	app.yaw=atan2(-delta.x,-delta.z);app.pitch=atan2(delta.y,Vector2(delta.x,delta.z).length())
func live_focus(living: Node3D,form: Dictionary,look_id: String) -> Vector3:
	var height: float=(float(form.geometry.near.max[1])-float(form.geometry.near.floor_y))*float(FrontierEcologyCatalog.look(form.id,look_id).scale)
	return living.global_position+living.global_basis.y*maxf(.35,height*.5)
func observable(record: Dictionary,form: Dictionary,at: Vector3) -> bool:
	if not at.is_finite():return false
	var state:=FrontierEcology.status(record,form,at,"surface")
	return state=="active" or (state=="dormant" and form.category!="animal")
func surface_home(world: Dictionary,tier: int,midpoint: bool) -> int:
	var required: Array=["animal"] if midpoint else (["plant","microbe"] if tier==1 else ["animal","plant"])
	var addresses: Array=world.manifest.native_biota.planets.keys();addresses.sort()
	for address in addresses:
		var native: Dictionary=world.manifest.native_biota.planets[address]
		if int(native.tier)!=tier or native.origin=="sterile":continue
		var available: Array=[]
		for lineage in native.lineages:
			var form:=FrontierEcologyCatalog.form(lineage.form_id)
			if form.get("collection","")!="biota-7000":continue
			if midpoint and (not form.has("replacement") or form.get("locomotion_medium","")!="ground"):continue
			available.append(form.category)
		if not required.all(func(category):return category in available):continue
		var body:=FrontierUniverse.body(world.manifest,int(address));var record:=FrontierEcology.ensure_planet(FrontierEcology.create(),body)
		if not FrontierUniverse.landable(body):continue
		var field:=FrontierExplorationIncidents.field(body)
		var found: Array=[]
		for center in [Vector3(70,0,70),Vector3(-70,0,70),Vector3(70,0,-70),Vector3(140,0,70),Vector3(-140,0,70),Vector3(0,0,140)]:
			for candidate in FrontierEcologyPlacement.candidates(body,record,center):
				var form:=FrontierEcologyCatalog.form(candidate.form_id)
				if form.get("collection","")!="biota-7000" or candidate.layer!="surface":continue
				if midpoint and (not form.has("replacement") or form.get("locomotion_medium","")!="ground"):continue
				var at:=FrontierEcologyPlacement.ground(field,candidate)
				if observable(record,form,at):found.append(form.category)
			if required.all(func(category):return category in found):return int(address)
	return -1
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--crew-ui-test" not in args or "--crew-folder=/tmp/biota-surface-play" not in args:quit(2);return
	var fixture_mode: bool="--recipe-fixture" in args
	var midpoint: bool="--midpoint-only" in args
	if fixture_mode:load("res://tests/native_biota_fixture.gd").prepare()
	var tier:=1 if "--surface-tier=1" in args else 2
	var destination:="/tmp/biota-surface-play";DirAccess.make_dir_recursive_absolute(destination)
	folder=ProjectSettings.globalize_path("res://../docs/production/media/biota")
	if midpoint:folder+="/midpoints/field";DirAccess.make_dir_recursive_absolute(folder)
	var owner:=FrontierPlayerProfile.new_character("고유 생물 현장 검수",2);var id: String=owner.character_id
	var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"create native surface galaxy")
	var world: Dictionary=core.world
	var ordinal:=surface_home(world,tier,midpoint)
	if ordinal<0:printerr("No compatible active natural surface home for the requested categories in T",tier);quit(1);return
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var record:=FrontierEcology.ensure_planet(world.ecology,body);var field:=FrontierExplorationIncidents.field(body)
	check(record.profile.origin!="sterile" and int(body.planet_tier)<=2,"prepared home is a naturally assigned T1/T2 biosphere")
	for row in record.lineages:
		if not FrontierEcologyCatalog.form(row.form_id).has("lods"):printerr("WAITING_FOR_FIELD_ASSET ",row.form_id);quit(2);return
	if int(body.planet_tier)==2:
		var natives: Array=record.lineages.map(func(row):return row.form_id)
		var passive:=FrontierNativeIncidents.candidates(body,"scavenger")
		check(not passive.is_empty() and passive.all(func(row):return row.form_id in natives),"passive incidents use only this planet's actual anatomy")
		check(FrontierNativeIncidents.candidates(body,"guardian").all(func(row):return FrontierEcologyCatalog.form(row.form_id).get("collection","")!="biota-7000"),"new noncombat species do not gain unauthored attacks")
		var sterile:=body.duplicate(true);sterile.native_ecology.origin="sterile";sterile.native_ecology.lineages=[]
		check(FrontierNativeIncidents.candidates(sterile,"scavenger").is_empty(),"incident cache distinguishes same address with different native ecology")
	var fixtures: Dictionary={}
	for center in [Vector3(70,0,70),Vector3(-70,0,70),Vector3(70,0,-70),Vector3(140,0,70),Vector3(-140,0,70),Vector3(0,0,140)]:
		for candidate in FrontierEcologyPlacement.candidates(body,record,center):
			var form:=FrontierEcologyCatalog.form(candidate.form_id)
			if midpoint and (not form.has("replacement") or form.get("locomotion_medium","")!="ground"):continue
			if form.get("collection","")!="biota-7000" or fixtures.has(form.category) or candidate.layer!="surface":continue
			var at:=FrontierEcologyPlacement.ground(field,candidate)
			if not observable(record,form,at):continue
			candidate.point=FrontierExpeditionBusiness.array(at);fixtures[form.category]={"encounter":candidate}
	var categories: Array=["plant","microbe"] if int(body.planet_tier)==1 else ["animal","plant"]
	if midpoint:categories=["animal"]
	check(categories.all(func(c):return fixtures.has(c)),"native structures fit actual terrain and climate")
	if not categories.all(func(c):return fixtures.has(c)):printerr("FIXTURES ",fixtures.keys());quit(1);return
	world.crew.phase="playing"
	if world.crew.navigation.has("solar_opening"):world.crew.navigation.solar_opening.elapsed=world.crew.navigation.solar_opening.duration
	world.location=body.id;world.navigation_target=body.id;world.crew.navigation.system=body.system_ordinal;world.crew.navigation.target=body.ordinal
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(ordinal,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
	world.crew.members[id].ready=true;check(FrontierCrewSurface.apply(world,id,"land",{},{1:id}).is_empty(),"land on actual native home")
	world.crew.members[id].position=FrontierExpeditionBusiness.array(view_position(field,fixtures[categories[0]]).at);world.business.bags[id]=FrontierExpeditionBusiness.inventory()
	var store:=FrontierWorldStore.new(destination+"/world.json");check(store.write(world),"save prepared natural approach "+store.last_error)
	var profile:=FrontierPlayerProfile.new(destination+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"actual Forward+ native surface ready",90):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var actor: CharacterBody3D=app.actors[id];var played: Array=[];var expected_specimens:=0
	for category in categories:
		root.size=Vector2i(1280,800);root.content_scale_size=root.size
		var fixture: Dictionary=fixtures[category];var form:=FrontierEcologyCatalog.form(fixture.encounter.form_id);var view:=view_position(field,fixture)
		look(actor,view.at,view.eye);app.session._publish()
		if not await until(func():return app.surface_world.ecology.actors.has(fixture.encounter.id) and app.surface_world.ecology.actors[fixture.encounter.id].models.size()==2,category+" native model loaded",30):quit(1);return
		var living: Node3D=app.surface_world.ecology.actors[fixture.encounter.id]
		check(living.definition.id==form.id and living.anatomical_skeletons.size()==2,category+" correct type rig and LODs")
		# Offline wildlife intentionally pauses when this actual window loses focus.
		root.grab_focus()
		if not await until(func():return root.has_focus() and not living.paused,category+" visible game window resumes animal motion",6):quit(1);return
		var skeleton: Skeleton3D=living.anatomical_skeletons[0];var before: Array=[]
		for bone in skeleton.get_bone_count():before.append(skeleton.get_bone_pose(bone))
		await create_timer(.9).timeout;var moving:=false
		for bone in skeleton.get_bone_count():moving=moving or not skeleton.get_bone_pose(bone).is_equal_approx(before[bone])
		check(moving,category+" weighted anatomy animates on the planet")
		# The density surface can lie below the analytic height used for teleporting.
		# Aim from the player's settled position, as a player does with the mouse.
		aim_at(actor,live_focus(living,form,fixture.encounter.look_id));await create_timer(.25).timeout
		await capture("t%d-%s-field"%[int(body.planet_tier),category])
		app.test_scan=true
		var scanned:=await until(func():
			aim_at(actor,live_focus(living,form,fixture.encounter.look_id))
			return app.session.authority.world.ecology.observations.has(body.id+":"+form.id),category+" held E host scan",10)
		app.test_scan=false
		if not scanned:
			print("BIOTA_SCAN_DEBUG ",{"view":view,"actor":actor.position,"native_target":FrontierCrewSurface.target(app.session.authority.world,id,-actor.get_node("Camera3D").global_basis.z) if actor.has_node("Camera3D") else {},"scans":app.session.authority.scans,"input":app.session.authority.inputs.get(1,{}),"member":app.session.authority.world.crew.members[id].position})
			await capture("t%d-%s-scan-failed"%[int(body.planet_tier),category]);quit(1);return
		check(app.feedback.audio.last_played.has("ui_discovery"),category+" confirmed discovery audio")
		root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("t%d-%s-observed-960"%[int(body.planet_tier),category])
		if category==categories[0]:
			app.field_hud.environment.toggle_details();await capture("t%d-observed-environment-960"%int(body.planet_tier))
			check(not app.field_hud.scan_card.get_global_rect().intersects(app.field_hud.environment.get_global_rect()),"expanded environment leaves the specimen report readable")
			app.field_hud.environment.toggle_details()
		app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(2);app.survey_journal.search.text=form.name;app.survey_journal.refresh()
		if not await until(func():return app.survey_journal.selected_entry.get("row",{}).get("form_id","")==form.id,category+" J finds the native species",6):quit(1);return
		root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("t%d-%s-journal-960"%[int(body.planet_tier),category])
		check(app.survey_journal.preview.model_path==FrontierEcologyCatalog.model_key(form),category+" J uses actual species model")
		check(app.survey_journal.detail_scroll.get_global_rect().encloses(app.survey_journal.preview.get_global_rect()) and app.survey_journal.preview.size.y>=170,category+" small journal shows the complete preview panel")
		app.survey_journal.detail_scroll.ensure_control_visible(app.surface_panel.visit);await process_frame
		check(app.survey_journal.detail_scroll.get_global_rect().encloses(app.surface_panel.visit.get_global_rect()),category+" small journal scroll reaches specimen actions")
		await capture("t%d-%s-journal-actions-960"%[int(body.planet_tier),category])
		check(app.feedback.blocked(),category+" journal blocks tools")
		app.close_menus()
		# A roaming animal can leave its original approach point while J is open.
		# Prepare the player near its current terrain position; never move the animal.
		var current_encounter: Dictionary=fixture.encounter.duplicate();current_encounter.point=FrontierExpeditionBusiness.array(living.global_position)
		var current_view:=view_position(field,{"encounter":current_encounter})
		look(actor,current_view.at,live_focus(living,form,fixture.encounter.look_id));app.session._publish()
		await create_timer(.6).timeout
		# Wait for the current camera/host snapshot, not a fixed delay while the
		# animal can walk away. Press Q only once after the real target is in range.
		var sample_target: Dictionary={}
		var sample_ready:=await until(func():
			aim_at(actor,live_focus(living,form,fixture.encounter.look_id))
			sample_target.clear();sample_target.merge(FrontierCrewSurface.target(app.session.authority.world,id,-app.camera.global_basis.z))
			var position:=FrontierCrewWorld.vector(app.session.authority.world.crew.members[id].position)
			return app.surface_target.get("id","")==fixture.encounter.id and sample_target.get("id","")==fixture.encounter.id and position.distance_to(sample_target.point)<float(FrontierCrewSurface.config().sample_distance),category+" current moving target is within Q range",6)
		if not sample_ready:
			print("BIOTA_SAMPLE_DEBUG ",{"actor":actor.position,"living":living.global_position,"local":app.surface_target,"host":sample_target,"status":app.status.value})
			await capture("t%d-%s-sample-approach-failed"%[int(body.planet_tier),category]);quit(1);return
		var key:=InputEventKey.new();key.physical_keycode=KEY_Q;key.pressed=true;app._unhandled_input(key);expected_specimens+=1
		check(await until(func():return app.session.authority.world.ecology.specimens.size()==expected_specimens,category+" Q physical specimen",6),category+" sample recorded")
		check(app.feedback.audio.last_played.has("sfx_pickup_resource"),category+" confirmed sample audio")
		played.append({"category":category,"form":form.id,"archetype":body.traits.id,"state":FrontierEcology.status(record,form,view.eye,"surface")})
	check(await app.session.close_session(),"save observations and carried samples")
	var restored:=FrontierWorldStore.new(destination+"/world.json").read_state()
	check(not restored.is_empty() and restored.ecology.observations.size()==categories.size() and restored.ecology.specimens.size()==categories.size(),"native observations and specimens reload")
	FileAccess.open(folder+"/t%d-surface-check.json"%int(body.planet_tier),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"body":body.id,"played":played,"recipe_fixture":fixture_mode,"scope":"원산 행성의 실제 지형에 선정된 접근 위치에서 E/Q/J·스킨 모션·기존 음원·저장 확인"},"  "))
	app.queue_free();await process_frame;await process_frame;print("BIOTA_SURFACE_CHECKS ",checks," FAILURES ",failures);quit(0 if failures==0 else 1)

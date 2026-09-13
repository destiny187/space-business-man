extends "res://tests/check_target_identity_ui.gd"
func press_named(root_node: Node,text: String) -> bool:
	for node in root_node.find_children("*","Button",true,false):
		if node.text==text and node.is_visible_in_tree():node.pressed.emit();return true
	return false
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	check(fixture(),"natural animal fixture")
	if chosen.is_empty():quit(1);return
	var best_time:=0.0;var best_height:=-2.0
	for sample in range(0,20001,80):
		var sky:=FrontierPlanetaryCycles.sky_state(body,float(sample),{})
		if sky.sun_height>best_height:best_height=sky.sun_height;best_time=float(sample)
	core.world.crew.navigation.orbit_time=best_time
	# Keep the real animal present without forcing a melee encounter during reading.
	var at:=home+Vector3(0,0,13);at.y=field.height(at.x,at.z)+.2
	core.world.crew.members[actor_id].position=FrontierExplorationIncidents.array(at)
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"isolated world saved")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ field ready",100):quit(1);return
	core=app.session.authority;app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	place(at)
	if not await until(func():return app.surface_world.ecology.actors.has(chosen.id) and app.surface_world.ready_at(at),"natural target loaded",60):quit(1);return
	animal=app.surface_world.ecology.actors[chosen.id]

	app.test_scan=true
	if not await until(func():aim();return app.field_hud.scan_card.visible,"actual E scan completes",18):quit(1);return
	app.test_scan=false
	var names: Dictionary=core.world.ecology.species_names
	var code: String=names[chosen.form_id].code
	check(code=="ANI-001" and app.field_hud.scan_card.title.text==code,"first scan shows category code rather than catalogue name")
	var legacy:=core.world.duplicate(true);legacy.ecology.erase("species_names");legacy.ecology.erase("naming_revision")
	var old_store:=FrontierWorldStore.new(folder+"/legacy.json")
	check(old_store.write(legacy),"legacy observation remains valid")
	var migrated:=old_store.read_state()
	check(migrated.ecology.species_names[chosen.form_id].code==code and migrated.ecology.observations==legacy.ecology.observations,"legacy load assigns code and preserves observations")
	var first_identity: Dictionary=names[chosen.form_id].duplicate()
	FrontierEcology.scan(core.world.ecology,body.id,chosen)
	check(core.world.ecology.species_names[chosen.form_id]==first_identity,"repeat scan does not consume another number")
	var second_animal:=""
	for row in core.world.ecology.planets[body.id].lineages:
		var category: String=FrontierEcologyCatalog.form(row.form_id).category
		if row.form_id==chosen.form_id:continue
		if category=="animal" and not second_animal.is_empty():continue
		FrontierEcology.scan(core.world.ecology,body.id,row)
		if category=="animal":second_animal=row.form_id
	check(not second_animal.is_empty() and core.world.ecology.species_names[second_animal].code=="ANI-002","second animal follows discovery order")
	check(FrontierSpeciesNames.validate(core.world.ecology).is_empty(),"category codes are unique and observations match")
	core.world.crew.revision+=1;app.session._publish();app.session._publish_surface()
	var original: String=FrontierEcologyCatalog.form(chosen.form_id).name
	app.toggle_research();app.research_frame.tabs.current_tab=1
	var journal:=app.survey_journal;journal.category.select(2);journal.search.text=code;journal.refresh()
	await until(func():return journal.selected_entry.get("row",{}).get("form_id","")==chosen.form_id,"journal selects discovered code",5)
	check(press_named(journal.details,"이름 바꾸기"),"journal has name edit action")
	journal.rename_input.text="은빛 발자국"
	journal.refresh();await process_frame
	check(journal.editing_name and journal.rename_input.text=="은빛 발자국","background page refresh preserves name being typed")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	await capture("01-name-editor-960")
	check(journal.detail_scroll.get_global_rect().encloses(journal.rename_save.get_global_rect()),"name controls fit inside small window scroll area")
	journal.rename_save.pressed.emit();await process_frame
	await until(func():return journal.selected_entry.get("name","")=="은빛 발자국","host confirms edited journal name",5)
	check(core.world.ecology.species_names[chosen.form_id].code==code and FrontierEcologyCatalog.form(chosen.form_id).name==original,"rename preserves code and internal catalogue name")
	check(FrontierDiscoveryIndex.page(core.world,code,"biology","",0).total==1 and FrontierDiscoveryIndex.page(core.world,"은빛 발자국","biology","",0).total==1,"journal searches both permanent code and custom name")
	check(app.session.species_name(chosen.form_id)=="은빛 발자국","published names reach client view")
	var sample_key:=FrontierSpecimenItems.resource({"form_id":chosen.form_id,"look_id":chosen.look_id,"source_body":body.id,"id":(body.id+":"+chosen.id).sha256_text()})
	check(app.session.resource_name(sample_key)=="은빛 발자국 표본","specimen label shares discovered name")
	check(not FrontierSpeciesNames.rename(core.world.ecology,{"form_id":chosen.form_id,"name":"다른 이름","previous_name":""}).is_empty(),"stale concurrent name change is rejected")
	check(not FrontierSpeciesNames.rename(core.world.ecology,{"form_id":"unknown","name":"임의 이름","previous_name":""}).is_empty(),"undiscovered species cannot be renamed")
	await capture("02-renamed-journal-960")
	check(press_named(journal.details,"이름 바꾸기") and press_named(journal.details,"번호로 되돌리기"),"reset action is available")
	await until(func():return journal.selected_entry.get("name","")==code,"reset restores code without renumbering",5)
	press_named(journal.details,"이름 바꾸기");journal.rename_input.text="은빛 발자국";journal.rename_save.pressed.emit();await process_frame
	app.close_menus();await track(.4);app.test_scan=true;await track(.5);app.test_scan=false
	check(app.field_hud.scan_card.title.text=="은빛 발자국" and app.field_hud.scan_card.visible,"repeat E result uses custom name")
	await capture("03-renamed-scan")
	await track(4.2)
	check(not app.field_hud.scan_card.visible and not app.field_hud.context.visible,"custom names never become passive target labels")
	check(await app.session.close_session(),"edited names saved on session close")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not saved.is_empty() and saved.ecology.species_names[chosen.form_id]=={"code":code,"name":"은빛 발자국"},"save reload preserves custom name and immutable number")
	var resumed:=FrontierCrewAuthority.new()
	check(resumed.start(saved,owner,func(_world):return true) and FrontierDiscoveryIndex.page(resumed.world,code,"biology","",0).entries[0].name=="은빛 발자국","reopened authority serves renamed discovery")
	app.queue_free();await process_frame
	print("SPECIES_NAMES_CHECK ",checks," FAILURES ",failures);quit(1 if failures else 0)

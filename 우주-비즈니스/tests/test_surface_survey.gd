extends "res://tests/test_solo_entry.gd"
func aim_at(point: Vector3) -> void:
	var p: Vector3=app.actors[app.session.latest.self_id].position+Vector3.UP*1.72
	var direction: Vector3=(point-p).normalized()
	app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
func scan_at(point: Vector3,seconds: float) -> void:
	app.test_scan=true
	for i in ceili(seconds/.1):aim_at(point);await create_timer(.1).timeout
	app.test_scan=false
func find_biology() -> Dictionary:
	var core:=app.session.authority
	var body:=app.surface_world.body;var terrain:=FrontierCrewSurface.field(core.world)
	for candidate in FrontierEcologyPlacement.candidates(body,core.world.ecology.planets[body.id],Vector3.ZERO):
		if candidate.layer!="surface":continue
		var point:=FrontierEcologyPlacement.ground(terrain,candidate)
		if not point.is_finite():continue
		var form:=FrontierEcologyCatalog.form(candidate.form_id)
		var height: float=(form.geometry.near.max[1]-form.geometry.near.floor_y)*FrontierEcologyCatalog.look(form.id,candidate.look_id).scale
		for angle in 8:
			var observer:=point+Vector3(sin(angle*TAU/8)*2.2,0,cos(angle*TAU/8)*2.2)
			observer.y=terrain.height(observer.x,observer.z)
			core.update_position(1,observer)
			var center:=point+terrain.normal(point)*maxf(.35,height*.5)
			var target:=FrontierSurfaceSurvey.target(core.world,core.peers[1],(center-observer-Vector3.UP*1.72).normalized())
			if target.get("id")==candidate.id:target.observer=observer;target.center=center;return target
	return {}
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.world_store.write(FrontierUniverse.new_world(112052220));app.start_solo(true)
	if not await until(func():return app.session.active,"solo starts",15):quit(1);return
	app.travel_action("land")
	if not await until(func():return app.surface_world!=null and app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"surface ready",60):quit(1);return
	var id: String=app.session.latest.self_id;var core:=app.session.authority
	var actor: CharacterBody3D=app.actors[id]
	var vein:=FrontierExpeditionBusiness.find_vein(app.surface_world.body,"vein:0")
	var point:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,vein.position[0],vein.position[2])
	actor.position=point+Vector3(2.2,.2,0);actor.velocity=Vector3.ZERO;core.update_position(1,actor.position)
	await scan_at(point+Vector3.UP,.4);await create_timer(.5).timeout
	check(core.world.crew.get("survey",{}).is_empty(),"released partial mineral scan creates no record")
	await scan_at(point+Vector3.UP,2.2);await create_timer(.25).timeout
	check(core.world.crew.get("survey",{}).size()==1,"sustained input scans mineral before business registration")
	check(app.field_hud.scan_card.displayed.get("kind")=="mineral","host result displays mineral card")
	check(app.field_hud.scan_card.displayed.get("capacity")==int(vein.capacity),"scan uses actual deposit data")
	await capture("mineral-scan")
	var count: int=core.world.crew.get("survey",{}).size()
	await scan_at(point+Vector3.UP,.4)
	check(core.world.crew.get("survey",{}).size()==count,"repeat inspection does not duplicate discovery")
	var origin:=actor.position+Vector3.UP*1.72
	check(FrontierSurfaceSurvey.target(core.world,id,Vector3.UP).is_empty(),"looking away cannot scan deposit")
	app.toggle_inventory();app.test_scan=true;await create_timer(.6).timeout
	check(core.scans.is_empty(),"inventory blocks scan input")
	app.test_scan=false;app.inventory_panel.hide()
	var sample:=find_biology()
	check(not sample.is_empty(),"reachable living sample fixture")
	if sample.is_empty():quit(1);return
	actor.position=sample.observer;actor.velocity=Vector3.ZERO;core.update_position(1,actor.position)
	await scan_at(sample.center,2.3);await create_timer(.25).timeout
	check(core.world.ecology.observations.has(app.surface_world.body.id+":"+sample.form_id),"biology scan still records host observation")
	check(app.field_hud.scan_card.displayed.get("kind")=="biology","biology card explains actual uses")
	check(not core.world.ecology.research.has(FrontierEcologyCatalog.form(sample.form_id).environment),"scan itself grants no unearned engineering bonus")
	await capture("biology-scan")
	app.toggle_research();await create_timer(.5).timeout
	check(app.survey_journal.grid.get_child_count()>=2 and app.survey_journal.preview.model!=null,"journal has mineral and real biological model")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await capture("survey-journal-960")
	check(app.research_frame.get_global_rect().end.x<=960,"journal stays inside small screen")
	check(await app.session.close_session(),"survey world saves")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not saved.is_empty() and saved.crew.survey.size()==count,"mineral records survive reload")
	var malformed: Dictionary=saved.crew.duplicate(true);malformed.survey[malformed.survey.keys()[0]].tier=99
	check(not FrontierCrewWorld.validate(malformed).is_empty(),"malformed discovery is rejected")
	print("SURVEY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

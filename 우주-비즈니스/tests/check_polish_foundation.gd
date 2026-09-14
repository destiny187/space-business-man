extends "res://tests/test_solo_entry.gd"
const Draft=preload("res://scripts/persistence/world_draft.gd")
const Snapshot=preload("res://scripts/persistence/world_snapshot.gd")
func run() -> void:
	var source_folder:="";var industry_folder:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
		if arg.begins_with("--source-folder="):source_folder=arg.trim_prefix("--source-folder=")
		if arg.begins_with("--industry-folder="):industry_folder=arg.trim_prefix("--industry-folder=")
	assert(not folder.is_empty() and not source_folder.is_empty() and folder!=source_folder)
	DirAccess.make_dir_recursive_absolute(folder)
	for file in ["world.json","profile.json"]:assert(DirAccess.copy_absolute(source_folder+"/"+file,folder+"/"+file)==OK)
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;app.start_solo()
	if not await until(func():return app.session.active and not app.preparing_first_snapshot and app.surface_world!=null,"isolated actual surface ready",120):quit(1);return
	var settings:=FrontierClientSettings.ensure(self)
	settings.open()
	var before:=settings.node_applications;var saves:=settings.save_count
	for i in 10:settings.set_option("sensitivity",1.1+i*.01)
	check(settings.node_applications==before,"sensitivity changes no viewport/render properties")
	check(settings.save_count==saves,"slider values coalesce before disk write")
	settings.flush_settings();check(settings.save_count==saves+1,"one final settings write")
	settings.load_settings();check(is_equal_approx(settings.values.sensitivity,1.19),"final sensitivity persists")
	var keys: Dictionary={}
	check(FrontierPlayInput.rebind(keys,"forward",KEY_Z).is_empty(),"walking key rebind accepted")
	check(FrontierPlayInput.code("forward")==KEY_Z and FrontierPlayInput.code("flight_forward")==KEY_W,"flight and walking mappings independent")
	check(not FrontierPlayInput.rebind(keys,"backward",KEY_Z).is_empty(),"same context duplicate rejected")
	check(FrontierPlayInput.hint("W 전진  Space 제동","flight")=="W 전진  Space 제동","flight hint keeps its mapping")
	check(FrontierPlayInput.hint("W 전진","ground")=="Z 전진","ground hint reads action mapping")
	check(FrontierPlayInput.state("test",true,true,true),"toggle turns on")
	check(not FrontierPlayInput.state("test",true,false,true) and not FrontierPlayInput.state("test",true,true,true),"blocked held key cannot reactivate toggle")
	FrontierPlayInput.configure(settings.bindings)
	settings.set_option("resolution",1)
	settings.set_option("volume",.6);settings.flush_settings()
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(settings.path))
	check(disk.resolution==0,"unconfirmed display excluded from unrelated save")
	settings._revert_display();check(settings.values.resolution==0,"display cancel restores prior mode")
	settings.set_option("water_quality",0);settings.set_option("water_quality",1)
	settings.set_option("fov",88)
	await process_frame
	check(is_equal_approx(app.camera.fov,88),"firearm presentation respects configured FOV")
	settings.set_option("ui_scale",1.3);settings.tabs.current_tab=3
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	await capture("keys-960-large")
	check(settings.tabs.get_global_rect().end.y<640 and settings.overlay.visible,"large controls remain in scrollable small window")
	settings.tabs.current_tab=2;await capture("settings-960-large")
	settings.set_option("ui_scale",1.0);settings.set_option("fov",76);settings.close()
	# Compare actual industry with frozen prior state; unrelated history must stay shared.
	var industry_store:=FrontierWorldStore.new(industry_folder+"/world.json")
	var source:=industry_store.read_state()
	check(not source.is_empty(),"industry fixture validates")
	if not source.is_empty():
		source.manifest=Snapshot.own_manifest(source.manifest)
		var original:=Snapshot.copy(source);Snapshot._freeze(source)
		var start:=Time.get_ticks_usec();var full:=Snapshot.copy(source);var full_us:=Time.get_ticks_usec()-start
		start=Time.get_ticks_usec();var local:=Draft.industry(source);var local_us:=Time.get_ticks_usec()-start
		for value in [full,local]:
			FrontierLotusSupport.tick(value,1.0)
			for id in value.business.sites:
				if FrontierPlanetSupply.operating(value.business.sites[id]):FrontierExpeditionIndustry.tick(FrontierPlanetSupply.context(value,id),1.0)
			FrontierShuttles.manufacture(value,1.0)
		check(local==full and source==original,"industry output matches full copy and preserves source")
		check(is_same(local.ecology,source.ecology) and is_same(local.terrain_edits,source.terrain_edits),"industry shares unrelated biology and geology read-only")
		print("INDUSTRY_DRAFT_US full=",full_us," scoped=",local_us)
		var history:=Snapshot.copy(source)
		# Read-only history stress isolates the cost that this patch actually removes.
		history.terrain_edits["audit_only"]=[]
		for i in 10000:history.terrain_edits.audit_only.append({"position":[i,0,0],"depth":1.0})
		start=Time.get_ticks_usec();var history_full:=Snapshot.copy(history);full_us=Time.get_ticks_usec()-start
		start=Time.get_ticks_usec();var history_local:=Draft.industry(history);local_us=Time.get_ticks_usec()-start
		check(history_full==history_local,"large unrelated history preserved by scoped draft")
		print("INDUSTRY_HISTORY_10000_US full=",full_us," scoped=",local_us)
	check(await app.session.close_session(),"actual world saves after settings changes")
	print("POLISH_FOUNDATION checks=",checks," failures=",failures)
	quit(1 if failures else 0)

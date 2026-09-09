extends "res://tests/test_solo_entry.gd"
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;Input.parse_input_event(event)
	await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	var title: Node=load("res://scenes/app/main.tscn").instantiate();root.add_child(title);current_scene=title
	await process_frame
	var settings:=FrontierClientSettings.current(self)
	check(settings!=null and title.find_child("Settings",true,false)!=null,"title exposes shared settings")
	title.find_child("Settings",true,false).pressed.emit()
	check(settings.is_open() and settings.tabs.get_tab_count()==3,"three accessible settings tabs")
	settings.set_quality("view_distance",2)
	settings.controls.scale.value=75
	check(settings.values.preset==3 and is_equal_approx(root.scaling_3d_scale,.75),"custom controls immediately affect actual 3D viewport")
	settings.quality_controls.anti_aliasing.select(0);settings.quality_controls.anti_aliasing.item_selected.emit(0)
	check(root.msaa_3d==Viewport.MSAA_DISABLED,"MSAA dropdown changes actual renderer")
	settings.set_quality("effects",0)
	settings.set_option("shadows",false)
	settings.set_option("local_shadows",false)
	settings.set_option("fog",0)
	settings.controls.volume.value=0
	check(AudioServer.is_bus_mute(0),"zero volume really mutes audio")
	settings.load_settings()
	check(settings.values.view_distance==4800 and settings.values.scale==.75 and not settings.values.ssao,"settings survive disk reload")
	var future:=Node3D.new();root.add_child(future)
	var viewport:=SubViewport.new();future.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.fog_enabled=true;future.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.shadow_enabled=true;future.add_child(sun)
	var lamp:=OmniLight3D.new();lamp.shadow_enabled=true;future.add_child(lamp)
	var camera:=Camera3D.new();future.add_child(camera)
	await process_frame;await process_frame
	check(is_equal_approx(viewport.scaling_3d_scale,.75) and viewport.msaa_3d==0,"new flight SubViewports inherit preferences")
	check(not environment.environment.ssao_enabled and not environment.environment.fog_enabled,"new environments inherit effects")
	check(not sun.shadow_enabled and not lamp.shadow_enabled,"new lights respect independent shadow switches")
	check(camera.far>=4800*1.6,"camera includes far ring corners")
	settings.set_option("upscaler",1);settings.set_option("sharpness",.4);settings.set_option("taa",true);settings.set_option("local_shadow_size",1024)
	check(viewport.scaling_3d_mode==1 and is_equal_approx(viewport.fsr_sharpness,.4) and viewport.use_taa and viewport.positional_shadow_atlas_size==1024,"upscaler, TAA and local atlas apply to actual subviewports")
	settings._preset(2)
	check(sun.shadow_enabled and lamp.shadow_enabled and environment.environment.ssao_enabled,"high preset restores supported effects and shadows")
	settings.set_option("window_mode",1)
	check(not settings.display_previous.is_empty(),"display mode requires visible confirmation")
	settings.display_deadline=Time.get_ticks_msec()-1
	await process_frame;await process_frame
	check(settings.display_previous.is_empty() and settings.values.window_mode==0,"unconfirmed display mode automatically rolls back")
	DisplayServer.window_set_size(Vector2i(960,640));root.size=Vector2i(960,640)
	await capture("settings-960")
	check(settings.tabs.size.y>250 and settings.quality_controls.view_distance.is_visible_in_tree(),"settings remain usable at 960 by 640")
	await key(KEY_ESCAPE);check(not settings.is_open(),"Escape closes settings")
	future.queue_free()
	title.find_child("SoloStart",true,false).pressed.emit()
	if not await until(func():return current_scene is FrontierCrewExpedition and current_scene.surface_world!=null,"resume landed solo with settings",90):quit(1);return
	app=current_scene
	if not await until(func():return app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"surface collision ready",90):quit(1);return
	check(app.find_child("Settings",true,false)!=null,"game toolbar exposes settings")
	var config_before:=JSON.stringify(app.session.manifest.settings)
	settings.set_option("view_distance",600)
	var near_bounds: AABB=app.surface_world.distant.terrain_bounds()
	settings.set_option("view_distance",8000)
	var far_bounds: AABB=app.surface_world.distant.terrain_bounds()
	check(far_bounds.size.x>=16000 and near_bounds.size.x<=1201,"view distance changes generated terrain extent from 600 to 8000m")
	check(JSON.stringify(app.session.manifest.settings)==config_before,"graphics leave seeded simulation manifest unchanged")
	settings.set_option("fog",0);await process_frame
	check(app.surface_world.environment.fog_density==0 and not app.surface_world.environment.fog_enabled,"surface updates preserve disabled fog")
	settings.set_option("fov",90)
	check(app.camera.fov==90,"surface camera receives selected FOV")
	app.find_child("Settings",true,false).pressed.emit()
	var position_before: Vector3=app.actors[app.session.latest.self_id].position
	app.test_direction=Vector2(1,0);await create_timer(.4).timeout;app.test_direction=Vector2.ZERO
	check(Vector2(app.actors[app.session.latest.self_id].position.x-position_before.x,app.actors[app.session.latest.self_id].position.z-position_before.z).length()<.1,"settings block accidental movement while world keeps running")
	await key(KEY_TAB);check(not app.navigation_frame.visible,"settings prevent background navigation shortcuts")
	await key(KEY_F10);check(not settings.is_open(),"F10 closes settings in game")
	await capture("terrain-long-distance")
	# Every far ring segment must have both triangles, regardless of rough height chords.
	var field:=FrontierTerrainField.new();field.configure(4219)
	var distant:=FrontierDistantTerrain.new();root.add_child(distant)
	distant.rebuild(field,Vector3i(20,0,20),2,StandardMaterial3D.new(),4800)
	var arrays:=distant.mesh.surface_get_arrays(0)
	var perimeter:=int((2+.5)*field.span)*4
	var expected: int=(arrays[Mesh.ARRAY_VERTEX].size()/perimeter-1)*perimeter*6
	check(arrays[Mesh.ARRAY_INDEX].size()==expected,"rough far terrain contains every ring triangle")
	distant.rebuild_fallback(field,Vector3i.ZERO,2,{})
	check(distant.get_node("StreamingFallback").mesh!=null,"unloaded fine terrain receives temporary visible coverage")
	var loaded: Dictionary={}
	for x in range(-3,4):
		for y in range(-4,5):
			for z in range(-3,4):loaded[Vector3i(x,y,z)]=true
	distant.rebuild_fallback(field,Vector3i.ZERO,2,loaded)
	check(distant.get_node("StreamingFallback").mesh==null,"temporary coverage disappears once fine chunks exist")
	distant.queue_free()
	settings._preset(1);settings.set_option("volume",.8);settings.set_option("fov",76)
	check(await app.session.close_session(),"settings test saves solo successfully")
	print("CLIENT_SETTINGS_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

extends "res://tests/test_solo_entry.gd"
var report: Dictionary={}
func frames(count: int=15) -> void:
	for i in count:await process_frame
	await RenderingServer.frame_post_draw
func callbacks(culled: bool) -> float:
	var ecology: FrontierSurfaceEcology=app.surface_world.ecology
	var notifiers: Dictionary={}
	if not culled:
		for actor in ecology.actors.values():notifiers[actor]=actor.visibility_notifier;actor.visibility_notifier=null
	var start:=Time.get_ticks_usec()
	for i in 100:
		for actor in ecology.actors.values():actor._process(.001)
	var value: float=(Time.get_ticks_usec()-start)/100000.0
	if not culled:
		for actor in ecology.actors.values():actor.visibility_notifier=notifiers[actor]
	return value
func sample(enabled: bool) -> Dictionary:
	root.use_occlusion_culling=enabled
	await frames(25)
	var elapsed:=0.0;var draws:=0.0;var count:=120
	var previous:=Time.get_ticks_usec()
	for i in count:
		await process_frame
		var now:=Time.get_ticks_usec();elapsed+=(now-previous)/1000.0;previous=now
		draws+=root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var hidden:=0
	for actor in app.surface_world.ecology.actors.values():
		if not FrontierFieldVisibility.active(actor.visibility_notifier):hidden+=1
	return {"occlusion":enabled,"frame_ms":elapsed/count,"draw_calls":draws/count,"hidden_creatures":hidden}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active,"saved field ready",120):quit(1);return
	app.onboarding.letter.hide();app.close_menus()
	var settings:=FrontierClientSettings.ensure(self);settings._preset(1);settings.values.fps=0;settings.values.vsync=false;settings.apply_all()
	if not await until(func():return app.surface_world.business_view.pending_models.is_empty() and app.surface_world.ecology.pending.is_empty(),"field models loaded",30):quit(1);return
	if not await until(func():return app.surface_world.presence.assets_ready and app.surface_world.surface_details.presentation_ready(),"field scenery loaded",30):quit(1);return
	await frames(60)
	check(root.use_occlusion_culling,"live field enables local viewport occlusion")
	var world_time: float=app.session.latest.crew.navigation.orbit_time
	var data: Array=[]
	for angle in [0.0,PI]:
		app.yaw=angle;app.pitch=-.1;await frames()
		var row: Dictionary={"yaw":angle,"samples":[]}
		for enabled in [false,true,true,false]:row.samples.append(await sample(enabled))
		root.use_occlusion_culling=true;await frames()
		row.callback_without_visibility_ms=callbacks(false)
		row.callback_with_visibility_ms=callbacks(true)
		data.append(row)
		await capture("field-"+str(data.size()))
	check(float(app.session.latest.crew.navigation.orbit_time)>world_time,"host world time continues while local visuals sleep")
	var terrain: FrontierTerrainStreamer=app.surface_world.terrain
	var p: Vector3=app.actors[app.session.latest.self_id].position+Vector3(10,0,0);p.y=terrain.field.height(p.x,p.z)
	var edit:=terrain.dig(p,2.6)
	check(not edit.is_empty(),"field excavation starts")
	if not await until(func():return terrain.batch.is_empty(),"excavation replaces geometry and occluders",30):quit(1);return
	var paired:=true
	var occluders:=0
	for chunk in terrain.chunks.values():
		var node: Node3D=chunk.node
		var occluder:=node.get_node_or_null("TerrainOccluder") as OccluderInstance3D
		if int(chunk.triangles)>0:
			paired=paired and occluder!=null and occluder.occluder.indices.size()==int(chunk.triangles)*3;occluders+=1
		else:paired=paired and occluder==null
	check(paired and occluders>0,"all live chunk occluders match current geometry including dug holes")
	report={"scope":"Same live session; ABBA toggles native occlusion only. Creature callback comparison separately bypasses visibility, keeping LOD optimization. Not a full old/new build benchmark.","samples":data,"creatures":app.surface_world.ecology.actors.size(),"business_objects":app.surface_world.business_view.nodes.size(),"occluder_chunks":occluders,"checks":checks,"failures":failures}
	FileAccess.open(folder+"/field-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await app.session.close_session();app.queue_free();await frames()
	check(not root.use_occlusion_culling,"leaving live field restores viewport")
	print("FIELD PLAY checks ",checks," failures ",failures);quit(1 if failures else 0)

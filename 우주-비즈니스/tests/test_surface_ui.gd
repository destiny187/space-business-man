extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+message)
func wait_geometry(app: FrontierPlanetExploration) -> bool:
	var until:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<until:
		await process_frame
		if app.terrain.jobs.is_empty() and app.terrain.chunks.size()==app.terrain.wanted.size() and app.terrain.batch.is_empty():return true
	return false
func run() -> void:
	root.size=Vector2i(1280,800)
	var store:=FrontierWorldStore.new("user://test_exploration_ui.json")
	check(store.write(FrontierUniverse.new_world(71491)),"isolated initial world")
	var flight: FrontierSpaceFlight=load("res://scenes/app/exploration.tscn").instantiate()
	root.add_child(flight);current_scene=flight
	flight.set_physics_process(false)
	check(not flight.land(),"landing requires an orbital approach")
	flight.start_travel()
	for i in 2000:
		flight.step_flight(.05)
		if not flight.autopilot:break
	check(flight.land(),"orbital approach hands off to same planet surface")
	for i in 40:
		await process_frame
		if current_scene is FrontierPlanetExploration:break
	var app:=current_scene as FrontierPlanetExploration
	check(app!=null,"actual surface scene loaded")
	if app==null:quit(1);return
	var ready: bool=await wait_geometry(app)
	check(ready,"bounded worker stream finishes initial chunks")
	if not ready:quit(1);return
	await create_timer(.5).timeout
	check(app.player.is_on_floor(),"player stands on generated mesh collision")
	var path:=ProjectSettings.globalize_path("res://../test-results/surface")
	DirAccess.make_dir_recursive_absolute(path)
	await capture(path,"landing")
	await walk_to(app,82.0)
	check(app.player.position.x>=82 and app.player.position.y<-12,"physical movement traverses surface, chunk boundaries and underground slope")
	check(await wait_geometry(app),"subsurface interest streaming completes")
	await create_timer(.3).timeout
	await capture(path,"underground")
	# Dig into the side wall, keeping the passage floor walkable.
	app.head.rotation.x=0
	app.player.rotation.y=-PI
	await physics_frame
	var before: int=app.state.terrain_edits.get(app.body_id,[]).size()
	check(app.dig(),"in-range excavation hits terrain collider")
	check(await wait_geometry(app),"all affected mesh/collision chunks swap as one edit batch")
	check(app.state.terrain_edits[app.body_id].size()==before+1,"excavation records one persistent delta")
	await capture(path,"excavation")
	app.save_surface()
	var saved: Dictionary=store.read_state()
	check(saved.mode=="surface" and saved.terrain_edits[app.body_id].size()==before+1,"surface position and carve survive save")
	var restore:=FrontierTerrainField.new();restore.configure(int(app.body.streams.terrain),saved.terrain_edits[app.body_id])
	var edit: Dictionary=saved.terrain_edits[app.body_id][-1]
	check(restore.density(Vector3(edit.center[0],edit.center[1],edit.center[2]))<0,"replayed carve stays empty")
	var saved_position:=app.player.position
	app.queue_free();await process_frame
	var reopened: FrontierSpaceFlight=load("res://scenes/app/exploration.tscn").instantiate()
	root.add_child(reopened);current_scene=reopened
	for i in 40:
		await process_frame
		if current_scene is FrontierPlanetExploration:break
	app=current_scene as FrontierPlanetExploration
	check(app!=null,"opening a surface save resumes actual surface scene")
	if app==null:quit(1);return
	check(await wait_geometry(app),"restored surface geometry and collision finish")
	check(app.player.position.distance_to(saved_position)<3,"saved underground position survives scene reload")
	await walk_to(app,0.0)
	check(app.player.position.x<=1 and app.player.position.y>1,"excavated passage remains physically traversable back to landing")
	check(await wait_geometry(app),"return to landing region rebuilds only nearby chunks")
	await create_timer(.5).timeout
	app.return_to_orbit()
	for i in 30:
		await process_frame
		if current_scene is FrontierSpaceFlight:break
	check(current_scene is FrontierSpaceFlight,"ship departure returns to 3D orbit")
	if current_scene:current_scene.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(store.path+suffix):DirAccess.remove_absolute(store.path+suffix)
	print("SURFACE_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
func capture(path: String,id: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path.path_join(id+".png"))==OK,"capture "+id)

func walk_to(app: FrontierPlanetExploration,target: float) -> void:
	var sign_value: float=1.0 if target>app.player.position.x else -1.0
	app.movement_input=Vector2(0,-1)
	var until:=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<until and (target-app.player.position.x)*sign_value>0:
		var ahead: float=app.player.position.x+4*sign_value
		var t: float=clampf((ahead-14)/82,0,1)
		var direction:=Vector2(4*sign_value,sin(t*PI)*5-app.player.position.z).normalized()
		app.player.rotation.y=atan2(-direction.x,-direction.y)
		await physics_frame
	app.movement_input=Vector2.ZERO
	print("SURFACE_WALK target=",target," position=",app.player.position," floor=",app.player.is_on_floor())

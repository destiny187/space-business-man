extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+message)
func run() -> void:
	if "--exploration-test" not in OS.get_cmdline_user_args():printerr("FAIL: isolated test flag required");quit(1);return
	var path: String="user://test_exploration_ui.json"
	var world:=FrontierUniverse.new_world(71491)
	world.ecology=FrontierEcology.create()
	FrontierEcology.ensure_planet(world.ecology,FrontierUniverse.body_from_id(world.manifest,world.location))
	var bad:=world.duplicate(true);bad.ecology.catalog_hash="unsupported-catalog-version"
	var payload:=JSON.stringify(bad)
	for suffix in ["",".bak"]:
		var file:=FileAccess.open(path+suffix,FileAccess.WRITE);file.store_string(payload);file.close()
	for scene in ["res://scenes/app/exploration.tscn","res://scenes/app/planet_exploration.tscn"]:
		var app: Node=load(scene).instantiate();root.add_child(app);current_scene=app
		await process_frame;await process_frame
		check(app.state.is_empty() and not app.is_processing() and not app.is_physics_processing(),"incompatible ecology stops world loading instead of silently creating a new seed")
		check(FileAccess.get_file_as_string(path)==payload and FileAccess.get_file_as_string(path+".bak")==payload,"failed load preserves primary and backup bytes")
		var labels: Array[Node]=app.find_children("*","Label",true,false)
		check(labels.size()==1 and labels[0].text.contains("보존"),"load failure explains preservation in visible Korean UI")
		app.queue_free();await process_frame
	var store:=FrontierWorldStore.new(path)
	check(store.has_history() and store.read_state().is_empty() and store.last_error.contains("생태"),"store reports incompatible ecology rather than missing history")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print("ECOLOGY_RECOVERY_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)

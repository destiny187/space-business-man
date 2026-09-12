extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;printerr("FAIL ",label)
func run() -> void:
	var previous:="7eb12e6cf41e8d1c0690bd937c3eceee6b2036760f59deaf7e68f636a68abc48"
	check(FrontierEcologyCatalog.extension_compatible(FrontierEcologyCatalog.extension_signature()),"current catalogue accepted")
	check(FrontierEcologyCatalog.extension_compatible(previous),"reviewed pre-rig catalogue accepted")
	check(not FrontierEcologyCatalog.extension_compatible("unreviewed-catalogue"),"unknown catalogue remains rejected")
	# Optional existing isolated save reproduces the actual load failure without touching its file.
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--save="):continue
		var path:=arg.trim_prefix("--save=")
		var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var store:=FrontierWorldStore.new(path)
		var state:=store.read_state()
		check(not state.is_empty() and store.last_error.is_empty(),"pre-rig world loads: "+store.last_error)
		if state.is_empty():continue
		check(state.manifest==before.manifest and state.ecology==before.ecology and state.crew.combat==before.crew.combat,"saved origins ecology and health remain identical")
		var output:=FrontierWorldStore.new("/tmp/ground-locomotion/catalog-save.json")
		DirAccess.make_dir_recursive_absolute("/tmp/ground-locomotion")
		check(output.write(state),"legacy world can save after visual upgrade: "+output.last_error)
		var restored:=output.read_state()
		check(not restored.is_empty() and restored.manifest==before.manifest and restored.crew.combat==before.crew.combat,"legacy catalogue and damage survive another reload")
	print("GROUND_CATALOG_COMPATIBILITY ",checks," FAILURES ",failures);quit(1 if failures else 0)

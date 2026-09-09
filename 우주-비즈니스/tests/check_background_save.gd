extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 var folder:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var store:=FrontierWorldStore.new(folder+"/save-check.json")
 var world:=FrontierUniverse.new_world(71491)
 check(store.write(world),"initial validated save")
 world.flight_position[0]=10
 check(store.begin_checkpoint(world),"checkpoint queued")
 world.flight_position[0]=20
 check(store.finish_pending(),"worker joined")
 check(store.read_state().flight_position[0]==10,"queued snapshot isolated from live mutations")
 check(store.begin_checkpoint(world),"second checkpoint queued")
 world.flight_position[0]=30
 check(store.write(world),"transaction waits for checkpoint then commits")
 check(store.read_state().flight_position[0]==30,"older checkpoint cannot overwrite transaction")
 check(JSON.parse_string(FileAccess.get_file_as_string(store.path+".bak")).flight_position[0]==20,"backup contains preceding valid checkpoint")
 FileAccess.open(store.path,FileAccess.WRITE).store_string("damaged")
 check(store.read_state().flight_position[0]==20,"corrupt current restores verified backup")
 check(store.write(world),"recovery save preserves damaged current")
 check(FileAccess.get_file_as_string(store.path+".bak").begins_with("{"),"good backup not replaced by damaged file")
 var broken:=FrontierWorldStore.new(folder+"/missing/subfolder/world.json")
 check(broken.begin_checkpoint(world),"I/O failure occurs in worker")
 check(not broken.finish_pending() and not broken.last_error.is_empty(),"I/O failure reported at completion")
 world.version=-1
 check(not store.begin_checkpoint(world),"invalid snapshot rejected before scheduling")
 print("BACKGROUND SAVE failures ",failures);quit(1 if failures else 0)

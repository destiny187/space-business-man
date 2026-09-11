extends SceneTree
const Snapshot=preload("res://scripts/persistence/world_snapshot.gd")
var failures:=0
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run()->void:
 var folder:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var world:=FrontierUniverse.new_world(71503)
 var original: Dictionary=world.manifest
 world.manifest=Snapshot.own_manifest(original)
 check(not is_same(original,world.manifest) and not original.is_read_only(),"caller manifest remains independently mutable")
 check(world.manifest.is_read_only() and world.manifest.settings.is_read_only() and world.manifest.settings.tier_weights[0].is_read_only(),"nested generation rules are frozen")
 var draft:=Snapshot.copy(world)
 check(is_same(draft.manifest,world.manifest),"draft shares immutable generation data")
 draft.flight_position[0]=35
 check(world.flight_position[0]!=35,"draft mutation cannot change live progress")
 var encoded:=Snapshot.encode(draft,Snapshot.manifest_json(draft))
 check(JSON.parse_string(encoded)==JSON.parse_string(JSON.stringify(draft,"",true,true)),"cached encoding preserves the complete JSON state")
 check(FrontierUniverse.validate_world(draft).is_empty(),"shared draft passes normal domain validation")
 var tampered:=draft.duplicate(true)
 tampered.manifest=original.duplicate(true);tampered.manifest.seed+=1
 check(not FrontierUniverse.validate_world(tampered).is_empty(),"mutable replacement cannot reuse a cached hash")
 var fallback:=Snapshot.copy(tampered)
 fallback.manifest.seed+=1
 check(fallback.manifest.seed!=tampered.manifest.seed,"unregistered data keeps deep-copy isolation")
 var store:=FrontierWorldStore.new(folder+"/snapshot-world.json")
 var owner:=FrontierPlayerProfile.new_character("스냅샷 확인")
 var authority:=FrontierCrewAuthority.new()
 check(authority.start(world,owner,store.write),"session adopts immutable manifest and saves")
 authority.phase="playing"
 var request:Dictionary={"session_id":authority.session_id,"sequence":1,"revision":authority.world.crew.revision,"kind":"ready","args":{"value":true}}
 var result:=authority.request(1,request)
 check(result.get("ok",false) and store.read_state().crew.members[owner.character_id].ready,"acknowledged transaction is already durable")
 var before:=JSON.stringify(authority.world)
 authority.save_world=func(_state: Dictionary)->bool:return false
 request.sequence=2;request.revision=authority.world.crew.revision;request.args.value=false
 result=authority.request(1,request)
 check(not result.get("ok",true) and JSON.stringify(authority.world)==before,"failed save leaves live state and receipts unchanged")
 check(store.begin_checkpoint(authority.world),"immutable checkpoint queued")
 authority.world.crew.members[owner.character_id].ready=false
 check(store.finish_pending() and store.read_state().crew.members[owner.character_id].ready,"checkpoint owns mutable progress despite manifest sharing")
 var old_started:=Time.get_ticks_usec()
 for i in 30:var ignored:=world.duplicate(true)
 var old_usec:=Time.get_ticks_usec()-old_started
 var new_started:=Time.get_ticks_usec()
 for i in 30:var ignored:=Snapshot.copy(world)
 var new_usec:=Time.get_ticks_usec()-new_started
 print("COPY_30_USEC original=",old_usec," shared=",new_usec," manifest_bytes=",JSON.stringify(world.manifest).length())
 for i in Snapshot.CACHE_LIMIT:Snapshot.own_manifest({"seed":i})
 check(Snapshot.manifest_json(world).is_empty() and not is_same(Snapshot.copy(world).manifest,world.manifest),"cache eviction safely falls back to independent copy")
 print("WORLD SNAPSHOT failures ",failures);quit(1 if failures else 0)

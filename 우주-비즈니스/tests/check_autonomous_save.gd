extends SceneTree
const Snapshot=preload("res://scripts/persistence/world_snapshot.gd")
var failures:=0
class BatchAuthority extends FrontierCrewAuthority:
 func _step_surface(_delta: float) -> void:
  for i in 2:
   var draft:=WorldSnapshot.copy(world)
   draft.flight_position[0]+=1
   if not save_world.call(draft):stopped=true;return
   world=draft
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func attach(authority: FrontierCrewAuthority,store: FrontierWorldStore) -> void:
 authority.save_autonomous=store.begin_commit
 authority.poll_autonomous=func():
  if not store.poll_checkpoint():return -1
  return 0 if store.has_pending() else 1
 authority.finish_autonomous=func():return 1 if store.finish_pending() else -1
func run() -> void:
 var folder:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var store:=FrontierWorldStore.new(folder+"/autonomous.json")
 var world:=FrontierUniverse.new_world(71503)
 world.manifest=Snapshot.own_manifest(world.manifest)
 check(store.write(world),"initial durable state")
 world.flight_position[0]=10
 check(store.begin_checkpoint(world),"periodic job precedes mandatory commit")
 world.flight_position[0]=20
 check(store.begin_commit(world),"mandatory commit queues behind periodic job")
 world.flight_position[0]=30
 check(store.finish_pending() and store.read_state().flight_position[0]==20,"mandatory state is isolated and never dropped")
 check(JSON.parse_string(FileAccess.get_file_as_string(store.path+".bak")).flight_position[0]==10,"ordered backup retains preceding checkpoint")
 check(store.begin_commit(world),"another mandatory commit queued")
 world.flight_position[0]=40
 check(store.write(world) and store.read_state().flight_position[0]==40,"transaction joins and supersedes mandatory commit")
 var owner:=FrontierPlayerProfile.new_character("자동 저장 검사")
 var authority:=BatchAuthority.new()
 check(authority.start(world,owner,store.write),"authority starts")
 authority.phase="playing";attach(authority,store)
 var writes: Array=[0]
 authority.save_autonomous=func(value: Dictionary):writes[0]+=1;return store.begin_commit(value)
 authority.step_surface(.1)
 check(writes[0]==1 and authority.autonomous_pending(),"two automatic saves become one mandatory job")
 check(authority.can_simulate_member(owner.character_id),"unaffected crew may keep moving during disk work")
 authority.update_position(1,Vector3(3,4,5))
 check(authority.autonomous_world.crew.members[owner.character_id].position==[3.0,4.0,5.0],"newer movement survives pending result publication")
 check(authority.world.flight_position[0]==40,"uncommitted results stay out of live world and snapshots")
 check(authority.resolve_autonomous(true) and authority.world.flight_position[0]==42,"completion publishes both changes")
 check(store.read_state().flight_position[0]==42,"published result is already durable")
 authority.step_surface(.1)
 var request: Dictionary={"session_id":authority.session_id,"sequence":1,"revision":authority.world.crew.revision,"kind":"ready","args":{"value":true}}
 var result:=authority.request(1,request)
 check(result.get("ok",false) and not authority.autonomous_pending() and store.read_state().flight_position[0]==44,"player transaction drains pending production before drafting")
 var broken:=FrontierWorldStore.new(folder+"/missing/sub/world.json")
 attach(authority,broken);authority.step_surface(.1)
 check(authority.autonomous_pending() and not authority.resolve_autonomous(true) and authority.stopped,"worker failure stops authority")
 check(authority.world.flight_position[0]==44,"failed production remains unpublished")
 var invalid:=world.duplicate(true);invalid.version=-1
 check(not store.begin_commit(invalid) and not store.has_pending(),"invalid mandatory snapshot rejected before worker")
 var moving:=BatchAuthority.new();moving.world=Snapshot.copy(authority.world)
 moving.world.rovers={"vehicles":{"test_rover":{"position":[0.0,0.0,0.0]}},"jobs":{}}
 moving.save_world=func(_value):return true
 moving.save_autonomous=func(_value):return true
 moving.poll_autonomous=func():return 0
 moving.finish_autonomous=func():return 1
 moving.step_surface(.1)
 check(moving.can_simulate_vehicle("test_rover"),"unchanged rover may keep driving while save completes")
 moving.world.rovers.vehicles.test_rover.position[0]=7.0
 check(moving.resolve_autonomous(true) and moving.world.rovers.vehicles.test_rover.position[0]==7.0,"newer rover position survives result publication")
 var sig:=FrontierExpeditionBusiness.signature()
 var catalog:=FrontierCatalog.all();var original_name: String=catalog.resources.iron.name
 catalog.resources.iron.name=original_name+" test"
 check(FrontierExpeditionBusiness.signature()!=sig,"rules signature cache detects in-memory catalogue changes")
 catalog.resources.iron.name=original_name
 check(FrontierExpeditionBusiness.signature()==sig,"rules signature remains byte-compatible after restoration")
 print("AUTONOMOUS_SAVE failures ",failures);quit(1 if failures else 0)

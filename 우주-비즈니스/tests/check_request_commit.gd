extends SceneTree
const Draft=preload("res://scripts/persistence/world_draft.gd")
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 var source_folder:="";var folder:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--source-folder="):source_folder=arg.trim_prefix("--source-folder=")
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if source_folder.is_empty() or folder.is_empty() or folder.simplify_path()==source_folder.simplify_path():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var source:=FrontierWorldStore.new(source_folder+"/world.json")
 var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_folder+"/profile.json")).character
 var store:=FrontierWorldStore.new(folder+"/world.json")
 var a:=FrontierCrewAuthority.new();check(a.start(source.read_state(),profile,store.write),"authority starts from isolated save")
 a.phase="playing";var actor: String=a.peers[1];a.world.crew.members[actor].aboard=false
 var calls: Array=[0,0]
 a.save_world=func(value):calls[0]+=1;return store.write(value)
 a.save_request=func(value):calls[1]+=1;return store.begin_commit(value)
 a.poll_autonomous=func():return -1 if not store.poll_checkpoint() else (0 if store.has_pending() else 1)
 a.finish_autonomous=func():return 1 if store.finish_pending() else -1
 var timings: Array=[];var request: Dictionary={}
 for i in 3:
  var before: Dictionary=a.world.duplicate(true)
  request={"session_id":a.session_id,"sequence":int(a.world.crew.members[actor].last_sequence)+1,"revision":a.world.crew.revision,"kind":"equipment_select","args":{"slot":(i+1)%4}}
  var start:=Time.get_ticks_usec();var result:=a.request(1,request);timings.append((Time.get_ticks_usec()-start)/1000.0)
  check(result.get("pending",false) and before==a.world,"selection waits for durable result without publishing")
  check(a.request(1,request).get("pending",false) and calls[1]==i+1,"pending duplicate schedules no second commit")
  check(a.can_simulate_member(actor),"loadout transaction allows character movement")
  var p:=FrontierCrewWorld.vector(a.world.crew.members[actor].position)+Vector3(.1,0,0);a.update_position(1,p)
  check(a.resolve_autonomous(true),"selection commit finishes")
  check(a.world.crew.members[actor].position==[p.x,p.y,p.z] and int(a.world.crew.members[actor].loadout.selected)==(i+1)%4,"new movement and confirmed tool both survive")
  check(int(store.read_state().crew.members[actor].loadout.selected)==(i+1)%4,"confirmed selection is already on disk")
 check(calls[0]==0 and calls[1]==3,"ordinary selection never invokes synchronous write")
 var writes:=int(calls[1]);check(a.request(1,request).get("ok",false) and calls[1]==writes,"completed replay reuses receipt")
 # Hold completion deterministically while two more inputs arrive.
 a.poll_autonomous=func():return 0
 request=request.duplicate(true);request.sequence+=1;request.revision=a.world.crew.revision;request.args.slot=0
 check(a.request(1,request).get("pending",false),"queue scenario has a pending commit")
 var queued:=request.duplicate(true);queued.sequence+=1;queued.args.slot=1
 check(a.request(1,queued).get("pending",false) and a.queued_requests.size()==1,"next input queues without waiting for disk")
 check(a.request(1,queued).get("pending",false) and a.queued_requests.size()==1,"queued duplicate is bounded")
 check(a.resolve_autonomous(true),"first queued scenario commits")
 a.pump_requests()
 check(a.queued_requests.is_empty() and not a.completed_requests.back().result.ok and calls[1]==writes+1,"stale queued input is rejected without rebasing costs or saving")
 # Isolate original data on worker failure, including the changed loadout.
 a.completed_requests.clear()
 a.save_request=func(_value):return true
 a.finish_autonomous=func():return -1
 var before: Dictionary=a.world.duplicate(true)
 request.sequence=int(a.world.crew.members[actor].last_sequence)+1;request.revision=a.world.crew.revision;request.args.slot=2
 var failed_submit:=a.request(1,request)
 check(failed_submit.get("pending",false),"failed-save scenario submits")
 var resolved:=a.resolve_autonomous(true)
 check(not resolved and a.stopped and a.world==before,"failed commit preserves original world and selected tool")
 check(a.completed_requests.size()==1 and not a.completed_requests[0].result.ok,"failed commit returns no success feedback")
 print("REQUEST_COMMIT ",JSON.stringify({"submit_ms":timings,"synchronous_writes":calls[0],"failures":failures}))
 var file:=FileAccess.open(folder+"/metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify({"submit_ms":timings,"failures":failures},"  "));file.close()
 quit(1 if failures else 0)

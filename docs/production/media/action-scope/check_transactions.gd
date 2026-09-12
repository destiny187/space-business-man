extends SceneTree
const Snapshot=preload("res://scripts/persistence/world_snapshot.gd")
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 var base:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--audit-folder="):base=arg.trim_prefix("--audit-folder=")
 if base.is_empty():quit(2);return
 var source:=FrontierWorldStore.new(base+"/before/world.json")
 var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base+"/before/profile.json")).character
 var store:=FrontierWorldStore.new(base+"/transaction-world.json")
 var a:=FrontierCrewAuthority.new();check(a.start(source.read_state(),profile,store.write),"isolated authority starts")
 a.phase="playing";var actor: String=a.peers[1];a.world.crew.members[actor].aboard=false
 var writes: Array=[]
 a.save_world=func(draft: Dictionary):
  var start:=Time.get_ticks_usec();var ok:=store.write(draft);writes.append((Time.get_ticks_usec()-start)/1000.0);return ok
 var body:=FrontierUniverse.body_from_id(a.world.manifest,a.world.location)
 var timings: Array=[]
 var prior: Dictionary=a.world.duplicate(true)
 var rover_before: Dictionary=a.rover_runtime
 var last: Dictionary={}
 for i in 3:
  last={"session_id":a.session_id,"sequence":int(a.world.crew.members[actor].last_sequence)+1,"revision":a.world.crew.revision,"kind":"equipment_select","args":{"slot":(i+1)%4}}
  var start:=Time.get_ticks_usec();var result:=a.request(1,last);timings.append((Time.get_ticks_usec()-start)/1000.0)
  check(result.get("ok",false),"equipment select succeeds")
 check(prior.ecology==a.world.ecology and prior.terrain_edits==a.world.terrain_edits and prior.business==a.world.business,"slot selection preserves ecology terrain and business values")
 check(is_same(rover_before,a.rover_runtime),"non-rover command retains rover runtime")
 var before_writes:=writes.size();var revision:=int(a.world.crew.revision)
 check(a.request(1,last).get("ok",false) and writes.size()==before_writes and a.world.crew.revision==revision,"replay performs no second save or mutation")
 a.save_world=func(_draft):return false
 var before: Dictionary=a.world.duplicate(true);last=last.duplicate(true);last.sequence+=1;last.revision=revision;last.args.slot=0
 check(not a.request(1,last).get("ok",false) and before==a.world,"failed synchronous save preserves entire original")
 var f: Dictionary={"selection_ms":timings,"selection_save_ms":writes,"save_bytes":FileAccess.get_file_as_bytes(store.path).size()}
 var cache:=FrontierExpeditionBusiness
 var points: Array=[Vector3(40,0,40),Vector3(-161,0,159),Vector3(161,0,-161)]
 for p in points:check(cache.clearance_veins(body,p)==cache.veins(body,p),"cached geology matches full generation across cell boundaries")
 for i in 15:cache.clearance_veins(body,Vector3(i*700,0,i*500))
 check(cache._clearance_regions.size()<=65,"clearance region cache stays bounded while travelling")
 var other: Dictionary=body.duplicate(true);other.streams.resource=int(other.streams.resource)+1
 check(cache.clearance_veins(other,Vector3.ZERO)==cache.veins(other,Vector3.ZERO),"new seed invalidates clearance cache")
 check(cache.clearance_veins(body,Vector3.ZERO)==cache.veins(body,Vector3.ZERO),"returning to original body restores exact geology")
 print("TRANSACTION_SCOPE ",JSON.stringify(f))
 var file:=FileAccess.open(base+"/transactions.json",FileAccess.WRITE);file.store_string(JSON.stringify(f,"  "));file.close()
 quit(1 if failures else 0)

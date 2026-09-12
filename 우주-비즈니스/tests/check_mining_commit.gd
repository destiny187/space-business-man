extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 var source_folder:="";var output_folder:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--source-folder="):source_folder=arg.trim_prefix("--source-folder=")
  if arg.begins_with("--crew-folder="):output_folder=arg.trim_prefix("--crew-folder=")
 if not "--crew-ui-test" in OS.get_cmdline_user_args() or source_folder.is_empty() or output_folder.is_empty() or source_folder.simplify_path()==output_folder.simplify_path():quit(2);return
 DirAccess.make_dir_recursive_absolute(output_folder)
 var source:=FrontierWorldStore.new(source_folder+"/world.json")
 var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_folder+"/profile.json")).character
 var store:=FrontierWorldStore.new(output_folder+"/commit-world.json")
 var a:=FrontierCrewAuthority.new();check(a.start(source.read_state(),profile,store.write),"isolated authority starts")
 a.phase="playing";var actor: String=a.peers[1]
 var body:=FrontierUniverse.body_from_id(a.world.manifest,a.world.location)
 var vein: Dictionary=FrontierExpeditionBusiness.starter_veins(body)[0]
 var point:=FrontierMineralWorld.point(FrontierCrewSurface.field(a.world),vein)+Vector3.UP
 a.world.crew.members[actor].position=FrontierExpeditionBusiness.array(point)
 a.world.crew.members[actor].loadout=FrontierEquipment.create(profile)
 a.world.crew.members[actor].loadout.items["crafted:1"]="miner_3"
 check(FrontierExpeditionBusiness.find_vein(body,vein.id)==vein,"starter lookup retains exact resource capacity and position")
 check(FrontierExpeditionBusiness.find_vein(body,"missing").is_empty(),"unknown deposit is rejected")
 var submitted: Array=[0]
 a.save_autonomous=func(draft: Dictionary):submitted[0]+=1;return store.begin_commit(draft)
 a.poll_autonomous=func():return -1 if not store.poll_checkpoint() else (0 if store.has_pending() else 1)
 a.finish_autonomous=func():return 1 if store.finish_pending() else -1
 var before: Dictionary=a.world.business.duplicate(true)
 var before_seq:=int(a.world.crew.members[actor].last_sequence)
 var envelope: Dictionary={"session_id":a.session_id,"sequence":before_seq+1,"kind":"business_mine","args":{"vein_id":vein.id},"revision":a.world.crew.revision}
 check(a.request(1,envelope).get("pending",false),"mining queues durable commit")
 check(a.world.business==before and a.world.crew.members[actor].last_sequence==before_seq,"pending result gives no inventory or acknowledged sequence")
 check(a.request(1,envelope).get("pending",false) and submitted[0]==1,"duplicate pending request schedules no second extraction")
 check(a.can_simulate_member(actor),"miner can keep moving during storage")
 a.update_position(1,point+Vector3(.2,0,0))
 check(a.resolve_autonomous(true),"mining disk commit completes")
 check(a.world.crew.members[actor].position==FrontierExpeditionBusiness.array(point+Vector3(.2,0,0)),"newer movement survives mining publication")
 var saved:=store.read_state()
 check(saved.business==JSON.parse_string(JSON.stringify(a.world.business,"",true,true)) and int(saved.crew.members[actor].last_sequence)==before_seq+1,"confirmed materials and request receipt already exist on disk")
 check(a.completed_requests.size()==1 and a.completed_requests[0].result.ok,"one successful asynchronous reply")
 var confirmed: Dictionary=a.world.business.duplicate(true)
 check(a.request(1,envelope).get("ok",false) and a.world.business==confirmed and submitted[0]==1,"committed replay never duplicates materials")
 a.completed_requests.clear();a.now+=5
 a.save_autonomous=func(_draft):return true
 a.finish_autonomous=func():return -1
 envelope=envelope.duplicate(true);envelope.sequence+=1;envelope.revision=a.world.crew.revision
 check(a.request(1,envelope).get("pending",false),"failure scenario reaches pending state")
 check(not a.resolve_autonomous(true) and a.stopped,"storage failure stops authority")
 check(a.world.business==confirmed and int(a.world.crew.members[actor].last_sequence)==before_seq+1,"failed mining preserves inventory depletion and sequence")
 check(a.completed_requests.size()==1 and not a.completed_requests[0].result.ok,"storage failure replies without success")
 var legacy: Dictionary={"business":{"sites":{"old":{"buildings":{"one":{"type":"factory","tier":1},"two":{"type":"solar","tier":2}}}}}}
 var rows: Dictionary=legacy.business.sites.old.buildings.duplicate(true)
 FrontierFacilityResearch.migrate(legacy)
 check(legacy.business.sites.old.buildings==rows and legacy.business.facility_research==["solar"],"migration preserves old facilities and grants owned upgrade license")
 print("MINING_COMMIT failures ",failures);quit(1 if failures else 0)

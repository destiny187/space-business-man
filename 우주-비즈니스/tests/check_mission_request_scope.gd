extends "res://tests/check_active_missions.gd"
func run() -> void:
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/tmp/active-missions/fixtures.json"));actor=data.owner.character_id;owner=data.owner;sources=data.sources
 core=FrontierCrewAuthority.new();check(core.start(data.world,owner,persist),"restore request fixture");core.phase="playing";core.world.crew.phase="playing"
 var row:=install("cliff_relay_run");var id:=FrontierExplorationIncidents.key(row);var target: Dictionary=Mission.targets(row)[0];var p: Vector3=target.point+Vector3(0,-1.1,2)
 core.world.crew.members[actor].aboard=false;core.world.crew.members[actor].area="surface";core.world.crew.members[actor].position=Mission.arr(p)
 var args: Dictionary={"id":id,"part":target.part,"aim":Mission.arr((target.point-p-Vector3.UP*1.72).normalized()),"expected_mission_revision":0}
 var e:=envelope(core,1,"surface_incident",args);core.world.crew.revision+=3
 var result:=core.request(1,e);check(result.ok,"unrelated world revisions do not reject unchanged mission")
 var before: Dictionary=core.world.incidents.records[id].duplicate(true)
 check(core.request(1,e)==result and core.world.incidents.records[id]==before,"same receipt cannot rotate twice")
 var stale:=envelope(core,1,"surface_incident",args);check(not core.request(1,stale).ok and core.world.incidents.records[id]==before,"changed target rejects stale mission revision")
 args.expected_mission_revision=int(before.mission.revision);e=envelope(core,1,"surface_incident",args);disk_ok=false
 check(not core.request(1,e).ok and core.world.incidents.records[id]==before,"scoped revision path preserves failed save");disk_ok=true
 args.expected_mission_revision=int(before.mission.revision);core.world.crew.members[actor].position=Mission.arr(p+Vector3(50,0,0))
 check(not core.request(1,envelope(core,1,"surface_incident",args)).ok,"scoped revision cannot bypass actual range/aim")
 row=install("freighter_rescue_chain");act(row,"crate_0");row=live(row)
 core.world.crew.members[actor].position=Mission.arr(Mission.vec(row.relay)+Vector3(3,0,3))
 check(request(core,1,"surface_incident",{"id":FrontierExplorationIncidents.key(row),"part":"drop"}).ok,"drop carried rescue crate")
 row=live(row);var dropped:=Mission.targets(row)
 check(dropped.size()==1 and dropped[0].part=="crate_0" and dropped[0].point==Mission.vec(row.cargo_ground),"dropped crate remains only recoverable cargo at actual position")
 act(row,"crate_0");act(live(row),"delivery");row=live(row)
 check(int(row.mission.steps[0])==1 and int(row.mission.steps[1])==0 and int(row.mission.cargo_index)==-1,"recovered cargo advances its own delivery once")
 print("MISSION_REQUEST_SCOPE ",checks," FAILURES ",failures);quit(1 if failures else 0)

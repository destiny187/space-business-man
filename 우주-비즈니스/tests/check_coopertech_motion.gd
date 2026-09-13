extends "res://tests/check_coopertech_squads.gd"
const Motion=preload("res://scripts/domain/coopertech_motion.gd")
func run() -> void:
 var owner:=squad_fixture()
 if owner.is_empty():quit(1);return
 var world: Dictionary=core.world
 var f:=FrontierCrewSurface.field(world)
 var original: Dictionary=world.incidents.records[robot_key]
 original.phase="patrol";original.drive_actor="";original.move_velocity=[0,0,0]
 var at:=FrontierCrewWorld.vector(original.position)
 var member_at:=at+Vector3(0,0,20);member_at.y=f.height(member_at.x,member_at.z)
 world.crew.members[actor_id].position=FrontierSpaceCombat.arr(member_at)
 for id in world.incidents.records:
  if id!=robot_key:world.incidents.records[id].phase="idle"
 var before:=original.duplicate(true)
 var first:=Motion.step(world,.05,[actor_id],Callable())
 check(not is_same(first,world),"motion owns a new top-level draft")
 check(is_same(first.crew,world.crew) and is_same(first.business,world.business) and is_same(first.terrain_edits,world.terrain_edits),"motion shares read-only crew, inventory, terrain")
 check(original==before,"20 Hz movement cannot mutate the previously published row")
 var row: Dictionary=first.incidents.records[robot_key]
 var speed:=FrontierCrewWorld.vector(row.move_velocity).length()
 var nominal: float=FrontierCooperTechSquads.spec(row).speed
 check(speed>0 and speed<nominal*.3,"first step accelerates instead of jumping to full speed")
 var next:=first
 for i in 12:next=Motion.step(next,.05,[actor_id],Callable())
 check(FrontierCrewWorld.vector(next.incidents.records[robot_key].position).distance_to(at)>.1,"independent movement continues between decision ticks")
 var blocked:=Motion.step(next,.05,[actor_id],func(_a,_o,_d,_r):return 0.0)
 check(blocked.incidents.records[robot_key].position==next.incidents.records[robot_key].position,"motion stops before a physical blocker")
 check(FrontierCrewWorld.vector(blocked.incidents.records[robot_key].move_velocity).is_zero_approx(),"blocked snapshot clears predicted velocity")
 check(is_same(Motion.step(next,.05,[],Callable()),next),"no active crew causes no copy or movement")
 # New floating-point motion fields must survive actual JSON, not just a Dictionary duplicate.
 var decoded: Dictionary=JSON.parse_string(JSON.stringify(next))
 check(FrontierExplorationIncidents.validate(decoded).is_empty(),"motion snapshot survives JSON validation")
 check(FrontierUniverse.validate_world(decoded).is_empty(),"whole fixture including saved opening remains reloadable")
 var old:=row.duplicate();old.erase("move_velocity");old.erase("motion_clock");old.erase("drive_actor")
 check(FrontierCooperTechSquads.validate(old),"old squad records remain accepted without motion fields")
 print("COOPERTECH_MOTION ",checks," FAILURES ",failures);quit(1 if failures else 0)

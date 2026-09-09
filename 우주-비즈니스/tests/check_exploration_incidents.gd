extends "res://tests/check_exploration_discoveries.gd"
var incident_core: FrontierCrewAuthority
var incident_actor: String
func act(row_id: String,part_name: String,tool: bool=true) -> bool:
 var row: Dictionary=FrontierExplorationIncidents.records(incident_core.world)[row_id]
 var target_point:=Vector3.ZERO
 for t in FrontierExplorationIncidents.targets(row):
  if t.part==part_name:target_point=t.point;break
 if target_point==Vector3.ZERO:check(false,"missing part "+part_name);return false
 var m: Dictionary=incident_core.world.crew.members[incident_actor]
 var mode: String=FrontierExplorationIncidents.definition(row.template).mode
 var p:=target_point+Vector3(0,0,2.0).rotated(Vector3.UP,float(row.yaw))-Vector3.UP*.7
 if mode not in ["seismic","carry"]:p.y=FrontierCrewSurface.field(incident_core.world).height(p.x,p.z)+.1
 m.position=FrontierExplorationIncidents.array(p)
 var aim: Vector3=(target_point-p-Vector3.UP*1.72).normalized()
 var tool_id: String="pulse_2" if part_name in ["robot","drone"] else ("miner_2" if part_name=="gems" else "terrain_1")
 m.loadout.items["fixture:incident"]=tool_id;m.loadout.slots[0]="fixture:incident";m.loadout.selected=0
 incident_core.now+=2.0
 var result:=request(incident_core,1,"surface_incident_tool" if tool else "surface_incident",{"id":row_id,"part":part_name,"aim":FrontierExplorationIncidents.array(aim)})
 check(result.ok,"action "+row.template+" "+part_name+": "+str(result.get("error","")))
 return result.ok
func run() -> void:
 var owner:=FrontierPlayerProfile.new_character("사건 검사",0);incident_actor=owner.character_id
 incident_core=FrontierCrewAuthority.new();var core:=incident_core
 check(core.start(FrontierUniverse.new_world(71491),owner,persist),"start "+core.error)
 check(request(core,1,"start_game").ok,"start game")
 var found: Dictionary={};var ordinals: Dictionary={}
 for ordinal in range(1,1000):
  var body:=FrontierUniverse.body(core.world.manifest,ordinal)
  if not FrontierUniverse.landable(body) or int(body.planet_tier)>2:continue
  var f:=FrontierExplorationIncidents.field(body)
  for x in range(-2,3):
   for z in range(-2,3):
    for row in FrontierExplorationIncidents.tile(body,f,Vector2i(x,z)):
     if not found.has(row.template):found[row.template]=row;ordinals[row.template]=ordinal
  if found.size()==8:break
 check(found.size()==8,"natural T1/T2 pool: "+str(found.keys()));print("INCIDENT_POOL ",found.keys())
 for template in found:
  if not land_fixture(core,ordinals[template]):continue
  var source: Dictionary=found[template];FrontierExplorationIncidents.ensure(core.world)
  var id:=FrontierExplorationIncidents.key(source);core.world.incidents.records[id]=FrontierExplorationIncidents.create(source)
  var row: Dictionary=core.world.incidents.records[id];var mode: String=FrontierExplorationIncidents.definition(template).mode
  core.world.business.bags[incident_actor]=FrontierExpeditionBusiness.inventory();core.world.business.bags[incident_actor].copper=10;core.world.crew.members[incident_actor].aboard=false
  if mode in ["wreck","power"]:
   if mode=="power":act(id,"repair",false)
   if mode=="power" or int(row.tier)>=2:act(id,"battery",false);act(id,"socket",false)
   for i in 3:if not act(id,"hatch"):break
   act(id,"cargo",false)
  elif mode=="ice":
   for i in 4:if not act(id,"ice"):break
   act(id,"cargo",false)
  elif mode=="robot":
   core.world.crew.members[incident_actor].position=FrontierExplorationIncidents.array(FrontierExplorationIncidents.point(row,Vector3(0,0,6)))
   FrontierExplorationIncidents.tick(core.world,.25,[incident_actor]);check(row.phase=="waking","approach wakes robot")
   FrontierExplorationIncidents.tick(core.world,3.1,[incident_actor]);check(row.phase=="cooling","wake finishes")
   for i in 15:
    if core.world.incidents.records[id].hp<=0:break
    if not act(id,"robot"):break
   act(id,"cargo",false)
  elif mode=="drone":
   for i in 3:if not act(id,"drone"):break
   act(id,"cargo",false);check(FrontierExplorationIncidents.carriers(core.world,incident_actor),"physical carry drone");act(id,"delivery",false)
  elif mode=="carry":act(id,"cargo",false);check(FrontierExplorationIncidents.carriers(core.world,incident_actor),"physical carry cliff");act(id,"delivery",false)
  elif mode=="scavenger":
   var before:=FrontierExplorationIncidents.moving_point(row);row.age+=2;check(before!=FrontierExplorationIncidents.moving_point(row),"creature follows trail");act(id,"cargo",false)
  elif mode=="seismic":
   core.world.crew.members[incident_actor].position=row.relay.duplicate()
   FrontierExplorationIncidents.tick(core.world,.25,[incident_actor]);check(row.phase=="quake","cave entry triggers quake")
   FrontierExplorationIncidents.tick(core.world,4.1,[incident_actor]);check(row.open and row.materialized,"quake carves actual passage")
   check(FrontierCrewSurface.field(core.world).density(FrontierCrewWorld.vector(row.position))<0,"new chamber is empty terrain")
   for i in 6:if not act(id,"gems"):break
  check(core.world.incidents.records[id].claimed,"complete "+template)
  check(FrontierExplorationIncidents.validate(core.world).is_empty(),"incident state validation")
  print("INCIDENT_PLAYED ",template)
 check(FrontierUniverse.validate_world(core.world).is_empty(),"world integrity: "+FrontierUniverse.validate_world(core.world))
 var restored:=FrontierCrewAuthority.new();check(restored.start(saved,owner,persist),"saved reload: "+restored.error)
 var folder:="/tmp/exploration-incident-play";DirAccess.make_dir_recursive_absolute(folder)
 FileAccess.open(folder+"/fixture.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":found,"ordinals":ordinals},"  "))
 print("INCIDENT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

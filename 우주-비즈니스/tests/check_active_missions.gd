extends "res://tests/test_crew_surface.gd"
const Mission=preload("res://scripts/domain/active_missions.gd")
var core: FrontierCrewAuthority
var actor: String
var sources: Dictionary={}
var body: Dictionary
var field: FrontierTerrainField
var owner: Dictionary
func fixture() -> bool:
 owner=FrontierPlayerProfile.new_character("활동형 미션 확인",0);actor=owner.character_id
 core=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71503),owner,persist),"start")
 core.phase="playing";core.world.crew.phase="playing";core.world.crew.navigation.erase("solar_opening")
 for ordinal in core.world.manifest.native_biota.planets:
  var source: Dictionary=core.world.manifest.native_biota.planets[ordinal]
  if source.origin!="established":continue
  var suitable:=false
  for lineage in source.lineages:
   if FrontierEcologyCatalog.form(lineage.form_id).get("locomotion_medium","")=="surface_air":suitable=true;break
  if not suitable:continue
  var candidate:=FrontierUniverse.body(core.world.manifest,int(ordinal))
  if int(candidate.planet_tier)==3 and FrontierUniverse.landable(candidate):body=candidate;break
 if body.is_empty():check(false,"native T3 aerial home");return false
 var w: Dictionary=core.world;w.location=body.id;w.navigation_target=body.id
 w.crew.navigation.system=body.system_ordinal;w.crew.navigation.target=body.ordinal
 w.crew.navigation.position=FrontierExplorationIncidents.array(FrontierCrewNavigation.center(body.ordinal,w.manifest,float(w.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
 w.vessel=FrontierVesselRefit.create(int(w.manifest.seed),str(w.crew.world_id));w.vessel.navigation_refits={"kestrel":5};w.crew.members[actor].ready=true
 var reason:=FrontierCrewSurface.apply(w,actor,"land",{},{1:actor});check(reason.is_empty(),"land natural T3 home "+reason)
 if not reason.is_empty():return false
 w.crew.members[actor].aboard=false;w.crew.members[actor].area="surface";w.crew.members[actor].loadout.inventory_slots=48
 field=FrontierCrewSurface.field(w)
 for id in Mission.config().templates:
  for x in range(1,5):
   for z in range(1,5):
    var rows:=Mission.spawn(body,field,Vector2i(x,z),[],id)
    if not rows.is_empty():sources[id]=rows;break
   if sources.has(id):break
 check(sources.size()==7,"seven host-generated mission fixtures, including native bird")
 w.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 return sources.size()==7
func install(id: String) -> Dictionary:
 core.world.incidents.records.clear()
 for source in sources[id]:core.world.incidents.records[FrontierExplorationIncidents.key(source)]=FrontierExplorationIncidents.create(source)
 return core.world.incidents.records[FrontierExplorationIncidents.key(sources[id][0])]
func act(row: Dictionary,part: String,tool: bool=false) -> bool:
 var target: Dictionary={}
 for t in Mission.targets(row):
  if t.part==part:target=t;break
 if target.is_empty():check(false,"target exists "+part);return false
 var member: Dictionary=core.world.crew.members[actor];var p: Vector3=target.point+Vector3(0,-1.1,2)
 member.position=Mission.arr(p)
 member.loadout.items["fixture:tool"]="miner_3" if part.begins_with("mine_") else "terrain_1";member.loadout.slots[0]="fixture:tool";member.loadout.selected=0
 core.now+=1
 var direction: Vector3=(target.point-p-Vector3.UP*1.72).normalized()
 var result:=request(core,1,"surface_incident_tool" if tool else "surface_incident",{"id":FrontierExplorationIncidents.key(row),"part":part,"aim":Mission.arr(direction)})
 check(result.ok==disk_ok,row.template+" "+part+" "+str(result.get("error","")));return result.ok
func live(row: Dictionary) -> Dictionary:return core.world.incidents.records[FrontierExplorationIncidents.key(row)]
func run() -> void:
 if not fixture():quit(1);return
 DirAccess.make_dir_recursive_absolute("/tmp/active-missions")
 var file:=FileAccess.open("/tmp/active-missions/fixtures.json",FileAccess.WRITE);file.store_string(JSON.stringify({"world":core.world,"sources":sources,"owner":owner}));file.close()
 for t in range(1,6):check(Mission.allowed("cliff_relay_run",t)==(t in [2,3]),"relay exclusive T2/T3")
 for id in sources:
  var row:=install(id);var cfg:=Mission.rules(row)
  check(Mission.validate(row),id+" schema")
  if id=="cliff_relay_run":
   for i in 3:
    for turn in 8:
     if int(live(row).mission.steps[i])>0:break
     if not act(live(row),"rotate_"+str(i)):break
   act(live(row),"finish")
  elif id=="runaway_convoy_intercept":
   var before:=Mission.vec(row.mission.moving);row.age+=1;Mission.tick(core.world,row,1,[actor],field,Callable());check(before!=Mission.vec(row.mission.moving),"convoy actually moves")
   var hits:=preload("res://scripts/domain/firearm_targets.gd").candidates(core.world,actor).filter(func(r):return r.kind=="mission")
   check(hits.size()==1,"convoy exposed drive enters actual firearm shapes")
   var outcome:=FrontierFirearms._damage(core.world,actor,{"kind":"mission","id":FrontierExplorationIncidents.key(row)},10000,{"kind":"pulse"},false)
   check(row.open and outcome.killed,"host projectile damage stops convoy")
   act(live(row),"cargo");act(live(row),"delivery")
  elif id=="coopertech_relay_raid":
   for i in row.mission.steps.size():act(live(row),"power_"+str(i))
   check(live(row).open,"power opens physical vault")
   act(live(row),"cargo");act(live(row),"delivery")
  elif id=="vent_field_extraction":
   core.world.crew.members[actor].position=row.mission.anchors[0].duplicate();FrontierCrewVitals.ensure(core.world.crew.members[actor]);core.world.crew.members[actor].vitals.protection=0
   row.age=float(cfg.hazard_period)-.7
   var hp:=float(core.world.crew.members[actor].vitals.health)
   Mission.tick(core.world,row,.2,[actor],field,Callable());check(float(core.world.crew.members[actor].vitals.health)<hp or float(core.world.crew.members[actor].modules.get("shield",0))>0,"local vent damage")
   for i in row.mission.steps.size():act(live(row),"mine_"+str(i),true)
   act(live(row),"finish")
  elif id=="aerial_sensor_recovery":
   core.world.crew.members[actor].position=Mission.arr(Mission.bird_point(row)+Vector3(12,0,0))
   Mission.tick(core.world,row,float(cfg.observe_seconds),[actor],field,Callable())
   check(float(row.mission.observed)>=float(cfg.observe_seconds),"native bird observation progresses")
   row.age=float(cfg.bird_rest)+(float(cfg.bird_period)-float(cfg.bird_rest))*.5
   act(live(row),"cargo");act(live(row),"delivery")
  elif id=="stranded_survey_rover":
   for i in row.mission.steps.size():
    for n in int(cfg.blocker_hits):act(live(row),"clear_"+str(i),true)
   act(live(row),"battery");act(live(row),"socket");act(live(row),"rover_toggle")
   row=live(row)
   for i in 500:
    if row.open:break
    core.world.crew.members[actor].position=Mission.arr(Mission.vec(row.mission.moving)+Vector3(0,0,4));row.age+=.1;Mission.tick(core.world,row,.1,[actor],field,Callable())
   check(row.open,"repaired rover traverses actual route to safe beacon");act(live(row),"finish")
  elif id=="freighter_rescue_chain":
   for i in row.mission.steps.size():act(live(row),"crate_"+str(i));act(live(row),"delivery")
   act(live(row),"finish")
  row=live(row);check(row.claimed,id+" completes once")
  var before: Dictionary=core.world.business.bags[actor].duplicate();var result:=request(core,1,"surface_incident",{"id":FrontierExplorationIncidents.key(row),"part":"finish","aim":[0,0,-1]})
  check(not result.ok and core.world.business.bags[actor]==before,id+" duplicate reward rejected")
  check(FrontierExplorationIncidents.validate(core.world).is_empty(),id+" validates after actions")
 var row:=install("cliff_relay_run");var original:=row.duplicate(true);var id:=FrontierExplorationIncidents.key(row)
 var unrelated:=FrontierExplorationIncidents.create(sources.runaway_convoy_intercept[0]);core.world.incidents.records[FrontierExplorationIncidents.key(unrelated)]=unrelated
 var draft:=preload("res://scripts/persistence/world_draft.gd").request(core.world,actor,"surface_incident",{"id":id})
 check(not is_same(draft.incidents.records[id],row) and is_same(draft.incidents.records[FrontierExplorationIncidents.key(unrelated)],unrelated),"one action only deep copies target incident")
 disk_ok=false;act(row,"rotate_0");disk_ok=true
 check(core.world.incidents.records[id]==original,"failed persistence preserves mission progress")
 var restored: Dictionary=JSON.parse_string(JSON.stringify(core.world));check(FrontierUniverse.validate_world(restored).is_empty(),"save roundtrip")
 print("ACTIVE_MISSION_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

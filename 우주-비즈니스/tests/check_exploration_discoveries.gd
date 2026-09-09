extends "res://tests/test_crew_surface.gd"
func land_fixture(core: FrontierCrewAuthority,ordinal: int) -> bool:
 var world: Dictionary=core.world
 world.crew.landing={}
 var planet:=FrontierUniverse.body(world.manifest,ordinal)
 world.location=planet.id;world.navigation_target=planet.id
 world.crew.navigation.system=planet.system_ordinal;world.crew.navigation.target=ordinal
 world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(ordinal,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
 for m in world.crew.members.values():m.aboard=true;m.area="cabin";m.ready=true
 var result:=request(core,1,"land",{})
 check(result.ok,"fixture land: "+str(result.get("error","")))
 return result.ok
func point_actor(core: FrontierCrewAuthority,row: Dictionary,index: int) -> Vector3:
 var at:=FrontierExplorationDiscoveries.work_point(row,index)
 var field:=FrontierCrewSurface.field(core.world)
 var member: Dictionary=core.world.crew.members[core.peers[1]]
 for i in 16:
  var pos:=at+Vector3(sin(i*TAU/16)*2.2,0,cos(i*TAU/16)*2.2);pos.y=field.height(pos.x,pos.z)+.1
  member.position=FrontierExpeditionBusiness.array(pos)
  var aim: Vector3=(at-pos-Vector3.UP*1.72).normalized()
  if FrontierExplorationDiscoveries.target(core.world,core.peers[1],aim).get("id")==row.id:return aim
 return Vector3.ZERO
func run() -> void:
 if "--retirement-only" in OS.get_cmdline_user_args():
  retirement();print("DISCOVERY_RETIREMENT ",checks," FAILURES ",failures);quit(1 if failures else 0);return
 var owner:=FrontierPlayerProfile.new_character("발견 검사",0);var actor: String=owner.character_id
 var core:=FrontierCrewAuthority.new()
 check(core.start(FrontierUniverse.new_world(71491),owner,persist),"start "+core.error)
 check(request(core,1,"start_game").ok,"start game")
 var found: Dictionary={};var bodies: Dictionary={};var landable: Array=[]
 for ordinal in range(1,2000):
  var body:=FrontierUniverse.body(core.world.manifest,ordinal)
  if not FrontierUniverse.landable(body) or int(body.planet_tier)>2:continue
  var field:=FrontierTerrainField.new();field.configure(int(body.seed),[],2048,body.get("traits",{}))
  # Use the exact native surface field and its ecology traits.
  var fixture:=core.world.duplicate(true);fixture.location=body.id;fixture.crew.landing={"body_id":body.id,"epoch":1}
  if not fixture.has("terrain_settings"):fixture.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
  FrontierEcology.ensure_planet(fixture.ecology,body);field=FrontierCrewSurface.field(fixture)
  for x in range(-2,3):
   for z in range(-2,3):
    var rows:=FrontierExplorationDiscoveries.tile(body,field,Vector2i(x,z))
    check(rows.size()<=int(FrontierExplorationDiscoveries.config().density[str(int(body.planet_tier))]),"density cap")
    for row in rows:
     check(int(FrontierExplorationDiscoveries.definition(row.template).tier)<=int(body.planet_tier),"tier cap")
     if not found.has(row.template):found[row.template]=row;bodies[row.template]=ordinal
  if ordinal%25==0:print("SEARCH ",ordinal," ",found.keys())
  if found.size()==20:break
 check(found.size()==20,"all twenty occur naturally: "+str(found.keys()))
 var played: Array=[]
 for template in found:
  if not land_fixture(core,int(bodies[template])):continue
  var row: Dictionary=found[template];var d:=FrontierExplorationDiscoveries.definition(template)
  if not core.world.business.bags.has(actor):core.world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
  for resource in core.world.business.bags[actor].keys():
   if not FrontierSpecimenItems.is_item(resource):core.world.business.bags[actor][resource]=0
  core.world.business.bags[actor].iron=10;core.world.business.bags[actor].copper=10
  var m: Dictionary=core.world.crew.members[actor]
  m.loadout.items["fixture:terrain"]="terrain_1";m.loadout.slots[1]="fixture:terrain"
  var complete:=true
  for index in d.stages.size():
   m=core.world.crew.members[actor];m.loadout.selected=1 if d.stages[index].tool=="terrain" else 0
   var aim:=point_actor(core,row,index)
   check(aim!=Vector3.ZERO,"reachable "+template+":"+str(index))
   if aim==Vector3.ZERO:complete=false;break
   var args: Dictionary={"id":row.id,"stage":index,"aim":FrontierExpeditionBusiness.array(aim)}
   check(not request(core,1,"surface_discovery",args).ok,"requires scan "+template)
   FrontierExplorationDiscoveries.scan(core.world,row,actor)
   if d.mode=="pulse":core.world.crew.navigation.orbit_time=8.0-fmod(float(row.yaw)*3,8.0)+4.0
   var packet:=envelope(core,1,"surface_discovery",args)
   var result:=core.request(1,packet)
   check(result.ok,"work "+template+":"+str(index)+" "+str(result.get("error","")))
   if not result.ok:complete=false;break
   check(core.request(1,packet).ok and FrontierExplorationDiscoveries.stage(core.world,row)==index+1,"idempotent step "+template)
  if complete:
   check(FrontierExplorationDiscoveries.progress(core.world,row).claimed,"reward once "+template);played.append(template)
 check(played.size()==20,"complete all twenty "+str(played))
 check(FrontierUniverse.validate_world(core.world).is_empty(),"world save: "+FrontierUniverse.validate_world(core.world))
 var restored:=FrontierCrewAuthority.new();check(restored.start(saved,owner,persist),"reload discoveries "+restored.error)
 var dir:="/tmp/exploration-discovery-play";DirAccess.make_dir_recursive_absolute(dir)
 FrontierWorldStore.new(dir+"/world.json").write(core.world)
 FileAccess.open(dir+"/fixture.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":found,"ordinals":bodies,"played":played},"  "))
 print("DISCOVERY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

func retirement() -> void:
 var planet:=FrontierPlanetFactory.make("basalt","retire-test",73,1)
 check(planet.events.all(func(event):return event.kind!="civilization"),"no newly inhabited village")
 var event: Dictionary={"id":"old-village","kind":"civilization","choice":"destroy_pending","reward":"past reward"}
 planet.events.append(event);planet.conflict=event.id;planet.conflict_order="destroy"
 var state: Dictionary={"planet":planet,"profile":{"credits":789},"checkpoint":{"planet":planet.duplicate(true)}}
 FrontierCampaign._retire_villages(state)
 check(state.planet.retired_civilizations.size()==1 and not state.planet.events.any(func(e):return e.kind=="civilization"),"archive legacy village")
 check(state.planet.conflict=="" and not state.planet.has("conflict_order") and state.profile.credits==789,"cancel obsolete order, preserve assets")
 check(state.checkpoint.planet.retired_civilizations.size()==1,"checkpoint migration")
 FrontierCampaign._retire_villages(state)
 check(state.planet.retired_civilizations.size()==1,"migration is idempotent")

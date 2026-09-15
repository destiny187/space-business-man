extends "res://tests/check_exploration_discoveries.gd"
func run() -> void:
 var owner:=FrontierPlayerProfile.new_character("초반 수정 검사",0)
 var core:=FrontierCrewAuthority.new()
 check(core.start(FrontierUniverse.new_world(61739),owner,persist),"new world starts: "+core.error)
 check(request(core,1,"start_game").ok,"start expedition")
 FrontierSolarOpening.step(core.world,30)
 var m: Dictionary=core.world.manifest
 var ordinal:=FrontierCrewNavigation.first_destination(m)
 var body:=FrontierUniverse.body(m,ordinal)
 var report:=FrontierOrbitalSurvey.report(body)
 check(report.water>=30 and report.air>=30 and report.difficulty=="낮음","starter water/air and low difficulty")
 var resources: Array=[]
 for vein in FrontierGroundProgression.starter(body):resources.append(vein.resource)
 check(["iron","ice","copper"].all(func(id):return id in resources and id in report.resources),"three minerals exist in scan and actual starter veins")
 var old:=m.duplicate(true);old.settings.erase("starter_planet_ordinal");old.settings.erase("starter_planet_rules")
 check(not FrontierUniverse.body(old,ordinal).get("starter_planet",false),"legacy manifest keeps original generation")
 var nav: Dictionary=core.world.crew.navigation
 nav.mode="approach";nav.speed=100
 FrontierCrewNavigation.steer(core.world,FrontierCrewNavigation.stopped_input(),.016)
 check(nav.mode=="approach","menu neutral brake cannot cancel approach")
 var inputs: Array=[0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,1.]
 FrontierCrewNavigation.steer(core.world,inputs,.016)
 check(nav.mode=="idle" and nav.manual,"movement key cancels approach")
 nav.mode="jump"
 FrontierCrewNavigation.steer(core.world,inputs,.016)
 check(nav.mode=="jump","movement does not cancel interstellar transit")
 nav.mode="idle"
 var station: Dictionary={}
 for index in range(1,100):
  station=FrontierSpaceStation.definition(m,index)
  if not station.is_empty():nav.system=index;break
 nav.position=station.position.duplicate();nav.speed=0;nav.mode="idle"
 var transport_actor: String=core.peers[1]
 core.world.crew.members[transport_actor].aboard=true
 var level:=FrontierRovers.research(core.world.crew.members[transport_actor])
 if not core.world.has("business"):core.world.business=FrontierExpeditionBusiness.create()
 core.world.business.bags[transport_actor]=FrontierExpeditionBusiness.inventory()
 var transport_cost: Dictionary=FrontierRovers.config().transport.research_cost if level==1 else FrontierRovers.config().research_cost
 for id in transport_cost:core.world.business.bags[transport_actor][id]=int(transport_cost[id])
 var upgrade:=FrontierSpaceStation.apply(core.world,transport_actor,"station_logistics",{"station":station.id,"expected_level":level},{1:transport_actor})
 check(upgrade.is_empty() and FrontierRovers.research(core.world.crew.members[transport_actor])==level+1,"station transportation upgrade: "+upgrade)
 check(not FrontierSpaceStation.apply(core.world,transport_actor,"station_logistics",{"station":station.id,"expected_level":level},{1:transport_actor}).is_empty(),"stale upgrade cannot charge twice")
 if not land_fixture(core,ordinal):quit(1);return
 var actor: String=core.peers[1]
 var member: Dictionary=core.world.crew.members[actor];member.aboard=false;member.area="surface"
 var found: Dictionary={}
 var field:=FrontierCrewSurface.field(core.world)
 for x in range(-3,4):
  for z in range(-3,4):
   for source in FrontierExplorationIncidents.tile(body,field,Vector2i(x,z)):
    if not FrontierActiveMissions.enabled(source) and FrontierExplorationIncidents.definition(source.template).mode in ["wreck","ice","power"] and not source.has("native"):found=source;break
   if not found.is_empty():break
  if not found.is_empty():break
 check(not found.is_empty(),"recoverable cargo fixture")
 if found.is_empty():quit(1);return
 var row:=FrontierExplorationIncidents.create(found,int(m.seed));row.open=true;row.powered=true
 row.gun_reward_v2=FrontierWeaponLoot.roll("pulse_1","improved",71,"shock");row.gun_reward_v2.definition="pulse_1"
 FrontierExplorationIncidents.ensure(core.world);core.world.incidents.records[FrontierExplorationIncidents.key(row)]=row
 var bag:=FrontierExpeditionBusiness.bag(core.world,actor)
 for id in bag:bag[id]=0
 var count: int=member.loadout.items.size()
 bag.stone=maxi(0,FrontierItemInventory.capacity(member)-count-3)*FrontierItemInventory.stack_size("stone")
 check(FrontierItemInventory.capacity(member)-FrontierItemInventory.used(bag,count)==3,"exactly three free slots before gun")
 var err:=FrontierExplorationIncidents.take_loot(core.world,actor,row,"gun")
 check(err.is_empty() and member.loadout.items.size()==count+1 and not row.claimed,"take only gun without other cargo: "+err)
 check(not FrontierExplorationIncidents.take_loot(core.world,actor,row,"gun").is_empty() and member.loadout.items.size()==count+1,"duplicate gun recovery rejected")
 check(FrontierExplorationIncidents.loot_contents(int(m.seed),row).size()>0,"remaining cargo stays available")
 var saved:=JSON.parse_string(JSON.stringify(row)) as Dictionary
 check(FrontierExplorationIncidents.loot_contents(int(m.seed),saved)==FrontierExplorationIncidents.loot_contents(int(m.seed),row),"partial cargo survives serialization")
 var draft:=preload("res://scripts/persistence/world_draft.gd").request(core.world,actor,"surface_incident",{"id":FrontierExplorationIncidents.key(row),"loot_key":"module"})
 check(not is_same(draft.incidents.records[FrontierExplorationIncidents.key(row)],row),"cargo transaction isolates its incident")
 print("EARLY_PLAY_FIXES ",checks," failures ",failures)
 quit(1 if failures else 0)

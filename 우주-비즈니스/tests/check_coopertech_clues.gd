extends "res://tests/check_exploration_incidents.gd"
func run() -> void:
 var owner:=FrontierPlayerProfile.new_character("CooperTech 좌표 검사",0);incident_actor=owner.character_id
 incident_core=FrontierCrewAuthority.new();var core:=incident_core
 check(core.start(FrontierUniverse.new_world(61739),owner,persist),"start host");core.phase="playing"
 var m: Dictionary=core.world.manifest;var trace:=FrontierCorporateTraces.definition(m,"trace:corp_2805_0")
 var old:=core.world.duplicate(true);old.manifest.settings.corporate_space.erase("coopertech_links");FrontierCooperTechClues.capture(old,trace)
 check(FrontierCooperTechClues.records(old).is_empty(),"old saves do not gain retroactive ground links")
 var nav: Dictionary=core.world.crew.navigation;nav.system=2805;nav.target=trace.body;nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(trace.position)+Vector3(0,0,450));nav.direction=[0,0,-1];nav.speed=0;nav.mode="idle"
 core.world.location=trace.body_id;core.world.navigation_target=trace.body_id
 for i in 48:
  core.now+=.1;core.input(1,i+1,[0,0],[0,0,-1],true);core.step_surface(.1)
 check(int(FrontierCorporateTraces.records(core.world).get(trace.id,0))==2,"actual held input completes orbital evidence")
 var link:=FrontierCooperTechClues.describe(core.world,trace.id)
 if link.is_empty():check(false,"recoverable seeded coordinate");quit(1);return
 check(link.stage==0 and int(link.body)/8==2805 and int(FrontierUniverse.body(m,link.body).planet_tier)>=2,"coordinate leads to same system actual robot-capable planet")
 var candidate:=FrontierCooperTechClues.candidate(core.world,trace)
 check(FrontierExplorationIncidents.key(candidate.row)==link.incident,"clue uses canonical generated incident ID")
 var count:=FrontierExplorationIncidents.records(core.world).size();FrontierCooperTechClues.capture(core.world,trace)
 check(FrontierExplorationIncidents.records(core.world).size()==count,"repeat source inspection cannot duplicate robot")
 check(FrontierUniverse.validate_world(core.world).is_empty(),"orbital link world validates: "+FrontierUniverse.validate_world(core.world))
 check(FrontierDiscoveryIndex.page(core.world,"CooperTech","incident","",0).total==1,"J exposes coordinate before ground discovery")
 if not land_fixture(core,int(link.body)):quit(1);return
 core.world.crew.members[incident_actor].aboard=false
 var row: Dictionary=core.world.incidents.records[link.incident]
 core.world.crew.members[incident_actor].position=FrontierExplorationIncidents.array(FrontierExplorationIncidents.point(row,Vector3(0,0,6)))
 FrontierExplorationIncidents.tick(core.world,.25,[incident_actor]);check(row.phase=="waking" and FrontierCooperTechClues.describe(core.world,trace.id).stage==1,"approach awakens original robot and records field discovery")
 check(FrontierExplorationIncidents.snapshot(core.world,incident_actor).records.has(link.incident),"ground actor receives same physical encounter")
 FrontierExplorationIncidents.tick(core.world,3.1,[incident_actor])
 for i in 20:
  if core.world.incidents.records[link.incident].hp<=0:break
  if not act(link.incident,"robot"):break
 check(core.world.incidents.records[link.incident].hp<=0 and FrontierCooperTechClues.describe(core.world,trace.id).stage==1,"combat defeats robot but clue remains open until actual recovery")
 act(link.incident,"cargo",false)
 check(FrontierCooperTechClues.describe(core.world,trace.id).stage==2,"real ground recovery closes orbital clue")
 var revision: int=core.world.crew.revision;var denied:=request(core,1,"surface_incident",{"id":link.incident,"part":"cargo","aim":[0,0,-1]})
 check(not denied.ok and core.world.crew.revision==revision,"duplicate salvage cannot pay or close again")
 var store:=FrontierWorldStore.new("/tmp/corporations-sp11/world.json")
 check(store.write(core.world),"completed linked incident saves: "+FrontierUniverse.validate_world(core.world))
 var restored:=store.read_state();check(not restored.is_empty() and FrontierCooperTechClues.describe(restored,trace.id).stage==2,"reload keeps source to same completed encounter")
 print("COOPERTECH_CLUE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

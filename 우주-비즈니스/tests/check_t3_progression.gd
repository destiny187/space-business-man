extends "res://tests/check_exploration_discoveries.gd"
func run() -> void:
 var owner:=FrontierPlayerProfile.new_character("T3 경로 확인",0);var actor: String=owner.character_id
 var core:=FrontierCrewAuthority.new()
 check(core.start(FrontierUniverse.new_world(71503),owner,persist),"start")
 check(request(core,1,"start_game").ok,"playing")
 var m: Dictionary=core.world.manifest
 var station: Dictionary={};var station_index:=1
 while station.is_empty():
  station=FrontierSpaceStation.definition(m,station_index)
  if station.is_empty():station_index+=1
 var nav: Dictionary=core.world.crew.navigation;nav.system=station_index;nav.mode="idle";nav.speed=0
 nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(station.position)+Vector3(0,0,1100));core.world.flight_position=nav.position.duplicate()
 var original_market:=FrontierSpaceStation.market(m,station_index)
 core.world.station_markets={str(station_index):original_market.stock.duplicate(true)}
 var market_hash:=FrontierUniverse.fingerprint(core.world.station_markets)
 core.world.business=FrontierExpeditionBusiness.create()
 var credits:=int(core.world.business.credits)
 check(core.snapshot().station.blueprints.size()==6,"six guaranteed offers alongside unchanged legacy market")
 var packet:=envelope(core,1,"station_blueprint",{"item":"facility_factory_mk3"})
 var result:=core.request(1,packet);check(result.ok,"buy factory blueprint: "+str(result))
 var committed:=FrontierUniverse.fingerprint(core.world)
 check(core.request(1,packet).ok and FrontierUniverse.fingerprint(core.world)==committed,"retry does not charge twice")
 check(int(core.world.business.credits)==credits-1200,"listed price charged once")
 check(not request(core,1,"station_blueprint",{"item":"facility_factory_mk3"}).ok and FrontierUniverse.fingerprint(core.world)==committed,"owned design rejected atomically")
 disk_ok=false
 check(not request(core,1,"station_blueprint",{"item":"facility_source_control_mk3"}).ok and FrontierUniverse.fingerprint(core.world)==committed,"failed save keeps funds and license unchanged")
 disk_ok=true
 check(FrontierUniverse.fingerprint(core.world.station_markets)==market_hash,"existing market stock preserved")
 check(not request(core,1,"station_blueprint",{"item":"facility_source_control_mk3","amount":2}).ok,"invalid quantity rejected")
 var guest:=FrontierPlayerProfile.new_character("승무원",1)
 check(core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and core.acknowledge(2,core.session_id).ok,"guest joins")
 check(not request(core,2,"station_blueprint",{"item":"facility_source_control_mk3"}).ok,"guest cannot spend shared funds")
 core.disconnect_member(2)
 if not land_fixture(core,206387):quit(1);return
 var body:=FrontierUniverse.body(m,206387);var field:=FrontierCrewSurface.field(core.world)
 var archives: Array=[]
 for x in range(-2,3):
  for z in range(-2,3):
   for row in FrontierExplorationDiscoveries.tile(body,field,Vector2i(x,z)):
    if row.template=="lost_technology_archive":archives.append(row)
 check(not archives.is_empty(),"natural T3 archive generated independently")
 if archives.is_empty():quit(1);return
 archives.sort_custom(func(a,b):return FrontierCrewWorld.vector(a.position).length()<FrontierCrewWorld.vector(b.position).length())
 var archive: Dictionary=archives[0];var design:=FrontierFacilityBlueprints.archive_blueprint(core.world,archive)
 # A naturally chosen design, with only T2 recovery inputs prepared.
 if FrontierFacilityBlueprints.owned(core.world,design):core.world.expedition_research.licenses.erase(design)
 core.world.business.bags[actor]=FrontierExpeditionBusiness.inventory();core.world.business.bags[actor]["control_circuit"]=1;core.world.business.bags[actor]["refined_copper"]=2
 var before_archive: Dictionary=core.world.duplicate(true)
 for stage in 3:
  var aim:=point_actor(core,archive,stage);check(aim!=Vector3.ZERO,"reachable stage "+str(stage))
  var args: Dictionary={"id":archive.id,"stage":stage,"aim":FrontierExpeditionBusiness.array(aim)}
  check(not request(core,1,"surface_discovery",args).ok,"scan prerequisite "+str(stage))
  FrontierExplorationDiscoveries.scan(core.world,archive,actor)
  if stage==2:
   var before:=FrontierUniverse.fingerprint(core.world);disk_ok=false
   check(not request(core,1,"surface_discovery",args).ok and before==FrontierUniverse.fingerprint(core.world),"failed save rolls back archive award")
   disk_ok=true
  var response:=request(core,1,"surface_discovery",args)
  check(response.ok,"restore archive stage "+str(stage)+": "+str(response))
 check(FrontierFacilityBlueprints.owned(core.world,design),"actual recovery grants common license")
 check(FrontierExplorationDiscoveries.progress(core.world,archive).claimed,"archive completion persisted")
 check(FrontierUniverse.validate_world(JSON.parse_string(JSON.stringify(core.world))).is_empty(),"archive and licenses reload")
 # Export an uncompleted natural archive for the actual render/input check.
 var folder:="/tmp/t3-progression-play";DirAccess.make_dir_recursive_absolute(folder)
 var pos:=FrontierExplorationDiscoveries.work_point(archive,0)+Vector3(0,0,4)
 pos.y=field.height(pos.x,pos.z)+.1
 before_archive.crew.members[actor].position=FrontierExpeditionBusiness.array(pos)
 check(FrontierWorldStore.new(folder+"/world.json").write(before_archive),"isolated play fixture saves")
 var file:=FileAccess.open(folder+"/fixture.json",FileAccess.WRITE);file.store_string(JSON.stringify({"archive":archive,"ordinal":206387,"design":design}));file.close()
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 batch_check()
 print("T3_PROGRESSION ",checks," CHECKS / ",failures," FAILURES");quit(1 if failures else 0)
func batch_check() -> void:
 var recipe:=FrontierProductionTier2.product("neutralizer_pack")
 var site: Dictionary={"inventory":FrontierExpeditionBusiness.inventory(),"buildings":{},"jobs":{}}
 var factory: Dictionary={"id":"batch","type":"factory","tier":3,"active":true,"production":{"product":"neutralizer_pack","progress":0.0,"remaining":3,"total":3},"position":[0,0,0]}
 site.buildings.batch=factory
 # Existing one-batch saves remain accepted and each cycle yields exactly one recipe.
 check(FrontierProductionTier2.validate_building(factory),"batch job valid")
 FrontierProductionTier2.tick(site,6)
 check(int(site.inventory.neutralizer_pack)==4 and int(factory.production.remaining)==2,"first batch produces four and keeps remaining work")
 var restored: Dictionary=JSON.parse_string(JSON.stringify(site));FrontierProductionTier2.tick(restored,6);FrontierProductionTier2.tick(restored,6)
 check(int(restored.inventory.neutralizer_pack)==12 and restored.buildings.batch.production.is_empty(),"saved batch finishes without duplication")

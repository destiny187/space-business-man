extends "res://tests/test_crew_surface.gd"
func run() -> void:
 var core:=FrontierCrewAuthority.new();var profile:=FrontierPlayerProfile.new_character("지역 확인",0)
 var legacy_world:=FrontierUniverse.new_world(71491);legacy_world.manifest.settings.regional_rules.erase("free_placement");legacy_world.manifest.settings.regional_rules.version=2
 check(core.start(legacy_world,profile,persist),"start fresh world")
 core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
 core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
 var actor: String=profile.character_id
 var body: Dictionary={}
 for ordinal in range(8,2000):
  var candidate:=FrontierUniverse.body(core.world.manifest,ordinal)
  if FrontierUniverse.landable(candidate) and int(candidate.planet_tier)==2 and FrontierGroundExploration.inputs(candidate).size()==2:body=candidate;break
 check(not body.is_empty(),"T2 supply candidate")
 if body.is_empty():quit(1);return
 core.world.location=body.id;core.world.navigation_target=body.id;core.world.crew.navigation.target=body.ordinal;core.world.crew.navigation.system=body.system_ordinal
 core.world.crew.landing={"body_id":body.id,"epoch":1};core.world.crew.members[actor].aboard=false;core.world.crew.members[actor].area="surface"
 FrontierEcology.ensure_planet(core.world.ecology,body)
 var site:=FrontierExpeditionBusiness.ensure_site(core.world)
 check(site.regions.size()==3,"T2 has independent work regions")
 var legacy:=body.duplicate(true);legacy.erase("regional_rules")
 var before: Array=[];var after: Array=[]
 for row in FrontierMineralWorld.region(legacy,8,7):
  if row.underground:before.append(row)
 for row in FrontierMineralWorld.region(body,8,7):
  if row.underground:after.append(row)
 check(before==after,"surface generator preserves complete underground deposits")
 var cluster:=FrontierSurfaceRegions.cluster(body,2,2)
 var tile:=Vector2i(floori(cluster.center.x/80),floori(cluster.center.y/80))
 var deposits:=FrontierSurfaceRegions.surface(body,tile.x,tile.y)
 check(not deposits.is_empty(),"supply cluster exists in mapped tile")
 for row in deposits:
  check(FrontierExpeditionBusiness.find_vein(body,row.id)==row,"cluster deposit ID resolves for mining and reload")
  break
 var owner: Dictionary=core.world.crew.members[actor]
 var region: Dictionary=site.regions["region:1"]
 owner.position=region.center.duplicate()
 core.world.business.bags[actor]={"iron":60,"copper":60,"stone":60,"ice":20,"crystal":0}
 # Same real construction transaction as the game; only stock/position are fixtures.
 var facade:=FrontierRegionalTerraform.facade(site,"region:1")
 core.world.business.sites[body.id]=facade
 var where:=Vector3.INF
 for x in range(-35,36,5):
  if where.is_finite():break
  for z in range(-35,36,5):
   var at:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(core.world),region.center[0]+x,region.center[2]+z,2)
   if at.is_finite() and FrontierExpeditionBusiness.placement(core.world,"storage",at,core.peers).is_empty():where=at;break
 core.world.business.sites[body.id]=site
 check(where.is_finite(),"external worksite supports construction")
 if not where.is_finite():quit(1);return
 owner.position=FrontierExpeditionBusiness.array(where+Vector3(0,0,5))
 check(FrontierExpeditionBusiness.build_reason(core.world,actor,"storage",where,core.peers).is_empty(),"external build preview uses local context")
 var err:=FrontierExpeditionBusiness.apply(core.world,actor,"business_build",{"building":"storage","position":FrontierExpeditionBusiness.array(where),"yaw":0.0},core.peers)
 check(err.is_empty(),"build external storage: "+err)
 err=FrontierExpeditionBusiness.apply(core.world,actor,"business_deposit",{"resource":"ice","amount":10},core.peers)
 check(err.is_empty(),"deliver input at external storage: "+err)
 check(int(site.regions["region:1"].inventory.ice)==10 and int(site.regions["region:0"].inventory.ice)==0,"transport credits only destination inventory")
 check(FrontierExpeditionBusiness.validate(core.world.business,core.world.manifest).is_empty(),"regional state validates after transactions: "+FrontierExpeditionBusiness.validate(core.world.business,core.world.manifest))
 var saved_other: Dictionary=site.regions["region:2"].duplicate(true)
 var local:=FrontierRegionalTerraform.facade(site,"region:1")
 local.buildings["check:air"]={"id":"check:air","type":"atmosphere","tier":1,"position":region.center.duplicate(),"active":true,"enabled":true,"work":0.0,"status":"가동 중","yaw":0.0,"region_id":"region:1"}
 var original: float=local.cells[0].environment.pressure
 FrontierRegionalTerraform.environment(core.world,local,1)
 check(float(local.cells[0].environment.pressure)!=original,"facility updates covered cells")
 check(site.regions["region:2"]==saved_other,"other region remains unchanged")
 var distant: Dictionary=local.buildings["check:air"];distant.position=[region.center[0]+150,region.center[1],region.center[2]]
 var frozen: Array=local.cells.duplicate(true);FrontierRegionalTerraform.environment(core.world,local,1)
 check(local.cells==frozen,"facility outside coverage cannot restore cells")
 local.buildings.erase("check:air")
 FrontierRegionalTerraform.merge(site,local)
 var credit_before: int=core.world.business.credits
 for cell in region.cells:
  cell.environment={"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":80.0,"ecology":70.0,"stable_seconds":30.0};cell.restoration2.salinity=0.0;cell.restoration2.soil=100.0
 FrontierRegionalTerraform.tick(core.world,0)
 var reward:=FrontierRegionalTerraform.paid(site)
 check(reward>0 and int(core.world.business.credits)==credit_before+reward,"region achievement pays once")
 FrontierRegionalTerraform.tick(core.world,0)
 check(int(core.world.business.credits)==credit_before+reward,"repeat tick cannot duplicate reward")
 check(not FrontierRegionalTerraform.settlement_reason(site).is_empty(),"one restored region cannot settle whole project")
 var decoded: Dictionary=JSON.parse_string(JSON.stringify(core.world.business))
 var validation:=FrontierExpeditionBusiness.validate(decoded,core.world.manifest)
 check(validation.is_empty(),"roundtrip region inventories and cells: "+validation)
 var total:=FrontierCoopWorkload.reward(site,int(body.planet_tier))
 check(FrontierPlanetSupply.settlement_payment(site,2,false)+reward==total,"final payment deducts previous regional reward")
 check(FrontierPlanetSupply.settlement_payment(site,2,true)+reward==floori(total*float(FrontierPlanetSupply.config().retained_reward_ratio)),"retained settlement deducts previous regional reward")
 var factory: Dictionary={"type":"factory","tier":2}
 check(not FrontierFacilityBlueprints.reason(core.world,factory,3).is_empty(),"new expedition gates Mk3 behind blueprint")
 check(FrontierFacilityBlueprints.register(core.world,"facility_factory_mk3","exploration","test:discovery"),"host discovery adapter registers blueprint")
 check(not FrontierFacilityBlueprints.register(core.world,"facility_factory_mk3","station","test:station"),"duplicate blueprint does not grant twice")
 check(FrontierFacilityBlueprints.reason(core.world,factory,3).is_empty(),"owned blueprint unlocks Mk3 gate")
 check(FrontierFacilityBlueprints.valid("facility_factory_mk3",JSON.parse_string(JSON.stringify(core.world.expedition_research.licenses.facility_factory_mk3))),"blueprint provenance survives JSON save")
 var old: Dictionary=core.world.duplicate(true);old.manifest.settings.erase("regional_rules")
 check(FrontierFacilityBlueprints.reason(old,factory,3).is_empty(),"legacy world retains previous upgrade rules")
 print("REGIONAL_RESULT checks=",checks," failures=",failures," body=",body.ordinal)
 quit(1 if failures else 0)

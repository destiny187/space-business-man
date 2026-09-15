extends SceneTree
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run():
 var world:=FrontierWorldStore.new("/tmp/playtest-field-research/world.json").read_state()
 if world.is_empty():quit(2);return
 var actor: String=world.crew.owner_id
 world.crew.members[actor].position=FrontierCrewSurface.config().ship_position.duplicate()
 world.business.credits=20000;world.business.bags[actor]=FrontierExpeditionBusiness.inventory();world.business.bags[actor].iron=300;world.business.bags[actor].stone=400
 world.business.facility_research=[];world.discoveries={"version":1,"records":{}};world.incidents={"version":1,"records":{}}
 var counts: Dictionary={"discoveries":0,"incidents":0};var all_ok:=true;var index: Dictionary={}
 for key in FrontierDiscoveryExhibits.config().items:
  var d: Dictionary=FrontierDiscoveryExhibits.config().items[key];counts[d.source]+=1
  all_ok=all_ok and not FrontierDiscoveryIndustry.proof(world,key) and not FrontierFacilityResearch.construction_unlocked(world.business,key)
  var credits_before: int=world.business.credits
  all_ok=all_ok and not FrontierFacilityResearch.apply(world,actor,{"research":key}).is_empty() and credits_before==world.business.credits
  var record: Dictionary={"template":d.template,"body_id":world.location,"position":[0.,0.,0.],"claimed":false}
  world[d.source].records[key]=record
  all_ok=all_ok and not FrontierDiscoveryIndustry.proof(world,key)
  record.claimed=true
  var evidence: Dictionary={};FrontierDiscoveryIndustry.collect_evidence(record,d.source,evidence)
  all_ok=all_ok and evidence.has(key) and FrontierDiscoveryIndustry.proof({d.source:{"research_evidence":evidence}},key)
  var draft:=preload("res://scripts/persistence/world_draft.gd").request(world,actor,"business_facility_research",{"research":key})
  all_ok=all_ok and is_same(draft[d.source],world[d.source]) and FrontierFacilityResearch.apply(draft,actor,{"research":key}).is_empty() and world.business.credits==credits_before
  all_ok=all_ok and FrontierFacilityResearch.apply(world,actor,{"research":key}).is_empty() and FrontierFacilityResearch.construction_unlocked(world.business,key)
  var after: int=world.business.credits
  all_ok=all_ok and not FrontierFacilityResearch.apply(world,actor,{"research":key}).is_empty() and world.business.credits==after
  var b: Dictionary={"type":key,"tier":1,"work":0.,"active":false}
  all_ok=all_ok and FrontierProductionTier2.upgrade_definition(b).is_empty() and FrontierProductionTier2.validate_building(b) and FrontierCatalog.entry("buildings",key).power==0
  all_ok=all_ok and FrontierDiscoveryExhibits.usage(d.template,d.source,true).contains("생산 / 능력치 효과 없음")
 check(counts=={"discoveries":21,"incidents":22},"every existing POI and incident has exactly one researched exhibit")
 check(all_ok,"all 43 licenses require completed proof, charge once, share safely, build, have journal usage and no upgrade or power")
 check(FrontierFacilityResearch.valid(world.business.facility_research),"43 licenses fit existing save validation")
 check(FrontierDiscoveryExhibits.usage("dew_basin","discoveries",true).contains("4kW") and FrontierDiscoveryExhibits.usage("thermal_chimneys","discoveries",true).contains("48m"),"journal describes real output and operating conditions")
 var site:=FrontierExpeditionBusiness.site(world);site.buildings={}
 var deco: Dictionary={"id":"display","type":"exhibit_thermal_chimneys","tier":1,"position":[999.,0.,999.],"yaw":0.,"enabled":true,"active":true,"working":true,"status":"","work":0.}
 site.buildings.display=deco
 var inventory: Dictionary=site.inventory.duplicate(true);var environment: Dictionary=site.environment.duplicate(true)
 FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryIndustry.tick(site,120.)
 check(not deco.active and not deco.working and site.inventory==inventory and site.environment==environment and site.power_supply<=2 and site.power_demand==0,"display has no power, resource or environment effect and does not run machinery")
 check(FrontierDiscoveryIndustry.heat_sources({"location":world.location,"discoveries":{"records":{}}}).is_empty(),"decorative chimney is never a geothermal source")
 print("DISCOVERY_EXHIBITS failures ",failures);quit(1 if failures else 0)

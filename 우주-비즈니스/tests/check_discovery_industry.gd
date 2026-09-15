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
 world.business.credits=5000;world.business.bags[actor].iron=100;world.business.bags[actor].copper=100
 world.business.facility_research=[];world.discoveries={"version":1,"records":{}}
 check(not FrontierFacilityResearch.construction_unlocked(world.business,"dew_condenser"),"unresearched discovery building hidden")
 var cost_before: int=world.business.credits
 check(not FrontierFacilityResearch.apply(world,actor,{"research":"dew_condenser"}).is_empty() and world.business.credits==cost_before,"no discovery proof cannot purchase or spend")
 var row: Dictionary={"id":"poi:test:dew","template":"dew_basin","body_id":world.location,"position":[30.,0.,30.],"yaw":0.0}
 FrontierExplorationDiscoveries.scan(world,row,actor)
 check(FrontierDiscoveryIndustry.proof(world,"dew_condenser") and not FrontierDiscoveryIndustry.proof(world,"geothermal_generator"),"completed dew observation opens only its research")
 check(FrontierExplorationDiscoveries.result(world,row).condition.contains("응결 집수기"),"scan result explains actual building use")
 var public:=FrontierExplorationDiscoveries.snapshot(world,"different-body")
 check(public.records.is_empty() and public.research_evidence.dew_condenser,"research evidence travels without copying other planet POIs")
 var draft:=preload("res://scripts/persistence/world_draft.gd").request(world,actor,"business_facility_research",{"research":"dew_condenser"})
 check(FrontierFacilityResearch.apply(draft,actor,{"research":"dew_condenser"}).is_empty() and world.business.credits==cost_before and world.business.bags[actor].iron==100 and is_same(draft.discoveries,world.discoveries),"research draft changes only candidate costs and license; discovery evidence stays read only")
 check(FrontierFacilityResearch.apply(world,actor,{"research":"dew_condenser"}).is_empty() and world.business.credits==cost_before-350,"shared paid discovery research succeeds")
 var after: int=world.business.credits
 check(not FrontierFacilityResearch.apply(world,actor,{"research":"dew_condenser"}).is_empty() and world.business.credits==after,"duplicate research cannot charge again")
 check(FrontierFacilityResearch.construction_unlocked(world.business,"dew_condenser"),"researched design enters build cards")
 var site:=FrontierExpeditionBusiness.site(world);site.buildings={};site.base_deployed=true;site.inventory=FrontierExpeditionBusiness.inventory()
 var field:=FrontierCrewSurface.field(world);var p:=Vector3.INF
 for x in range(-32,33,4):
  for z in range(-32,33,4):
   var q:=FrontierExpeditionBusiness.ground(field,x,z,2.3)
   if q.is_finite():p=q;break
  if p.is_finite():break
 if not p.is_finite():check(false,"fixture has stable ground");quit(1);return
 var generator: Dictionary={"id":"generator","type":"geothermal_generator","tier":1,"position":FrontierExpeditionBusiness.array(p),"yaw":0.,"enabled":true,"active":false,"working":false,"status":"","work":0.}
 site.buildings.generator=generator
 FrontierExpeditionIndustry.power(world,site)
 check(not generator.active and site.power_supply<=2.,"generator without surveyed source produces no power")
 var vent: Dictionary={"id":"poi:test:vent","template":"thermal_chimneys","body_id":world.location,"position":FrontierExpeditionBusiness.array(p+Vector3(20,0,0)),"yaw":0.0,"claimed":true}
 world.discoveries.records.vent=vent
 FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryIndustry.tick(site,1.)
 check(generator.active and generator.working and site.power_supply>=18.,"nearby surveyed hydrothermal source supplies real local power")
 vent.position=FrontierExpeditionBusiness.array(p+Vector3(49,0,0));FrontierExpeditionIndustry.power(world,site)
 check(not generator.active and generator.status.contains("48"),"outside source radius stops generation with reason")
 vent.position=FrontierExpeditionBusiness.array(p+Vector3(20,0,0))
 var condenser: Dictionary=generator.duplicate(true);condenser.id="condenser";condenser.type="dew_condenser";condenser.work=0.;site.buildings.condenser=condenser
 var cfg: Dictionary=FrontierDiscoveryIndustry.config().condenser;var original:=cfg.duplicate()
 cfg.minimum_moisture=0.;cfg.minimum_pressure=0.;site.environment.temperature=20.
 FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryIndustry.tick(site,12.)
 check(condenser.active and site.inventory.ice==1,"powered suitable condenser produces usable warehouse ice")
 var before: int=site.inventory.ice
 cfg.minimum_moisture=1.1;FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryIndustry.tick(site,24.)
 check(not condenser.active and not condenser.working and site.inventory.ice==before and condenser.status.contains("습도"),"dry conditions halt output and animation")
 cfg.minimum_moisture=0.;site.environment.temperature=80.;FrontierExpeditionIndustry.power(world,site)
 check(not condenser.active and condenser.status.contains("온도"),"local heat blocks condenser")
 site.environment.temperature=20.;generator.enabled=false;FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryIndustry.tick(site,24.)
 check(not condenser.active and site.inventory.ice==before,"insufficient real power cannot create water")
 generator.enabled=true;condenser.tier=2;FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryIndustry.tick(site,8.)
 check(site.inventory.ice==before+1 and FrontierDiscoveryIndustry.name(condenser).begins_with("강화"),"single enhancement improves throughput with enhancement label")
 check(FrontierProductionTier2.upgrade_definition(condenser).is_empty(),"no hidden third upgrade")
 site.base_deployed=false;site.inventory=FrontierExpeditionBusiness.inventory();FrontierDiscoveryIndustry.tick(site,60.)
 check(site.inventory.ice==0 and not condenser.working,"no warehouse prevents output accumulation")
 for key in original:cfg[key]=original[key]
 check(FrontierProductionTier2.validate_building(condenser),"new building state fits existing persistence validation")
 print("DISCOVERY_INDUSTRY failures ",failures);quit(1 if failures else 0)

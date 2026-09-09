extends "res://tests/test_crew_surface.gd"
func run() -> void:
 var core:=FrontierCrewAuthority.new();var profile:=FrontierPlayerProfile.new_character("T3 확인",0)
 var legacy_world:=FrontierUniverse.new_world(71503);legacy_world.manifest.settings.regional_rules.erase("free_placement");legacy_world.manifest.settings.regional_rules.version=2
 check(core.start(legacy_world,profile,persist),"new world")
 core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
 var chosen: String="acid_water"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--t3-profile="):chosen=arg.trim_prefix("--t3-profile=")
 var actor: String=profile.character_id;var body: Dictionary={};var variants: Dictionary={}
 for ordinal in range(8,1000000,997):
  var candidate:=FrontierUniverse.body(core.world.manifest,ordinal)
  if FrontierUniverse.landable(candidate) and int(candidate.planet_tier)==3:
   variants[FrontierTerraformTier3.profile_id(candidate)]=true
   if body.is_empty() and FrontierTerraformTier3.profile_id(candidate)==chosen:body=candidate
   if variants.size()==2:break
 check(variants.size()==2,"both seeded problem profiles")
 if body.is_empty():quit(1);return
 core.world.location=body.id;core.world.navigation_target=body.id;core.world.crew.navigation.target=body.ordinal;core.world.crew.navigation.system=body.system_ordinal
 core.world.crew.landing={"body_id":body.id,"epoch":1};core.world.crew.members[actor].aboard=false;core.world.crew.members[actor].area="surface"
 FrontierEcology.ensure_planet(core.world.ecology,body)
 var site:=FrontierExpeditionBusiness.ensure_site(core.world)
 check(site.regions.size()==4 and site.has("tier3"),"four independent T3 worksites")
 check(FrontierExpeditionBusiness.validate(core.world.business,core.world.manifest).is_empty(),"initial save: "+FrontierExpeditionBusiness.validate(core.world.business,core.world.manifest))
 var old:=body.duplicate(true);old.regional_rules.erase("tier3");old.regional_rules.tiers.erase("3")
 check(not FrontierTerraformTier3.enabled(old) and FrontierSurfaceRegions.zones(old).is_empty(),"previous regional manifest keeps legacy T3 contract")
 var region: Dictionary=site.regions["region:1"];var owner: Dictionary=core.world.crew.members[actor]
 var at:=Vector3.INF
 for x in range(-30,31,5):
  if at.is_finite():break
  for z in range(-30,31,5):
   var p:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(core.world),region.center[0]+x,region.center[2]+z,2.5)
   owner.position=FrontierExpeditionBusiness.array(p+Vector3(0,0,6)) if p.is_finite() else region.center
   var local:=FrontierRegionalTerraform.facade(site,"region:1");core.world.business.sites[body.id]=local
   var reason:=FrontierExpeditionBusiness.placement(core.world,"source_control",p,core.peers) if p.is_finite() else "ground"
   core.world.business.sites[body.id]=site
   if reason.is_empty():at=p;break
 check(at.is_finite(),"source control has supported accessible placement")
 if not at.is_finite():quit(1);return
 owner.position=FrontierExpeditionBusiness.array(at+Vector3(0,0,6));core.world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 FrontierExpeditionBusiness.transfer(core.world.business.bags[actor],FrontierTerraformTier3.config().buildings.source_control.cost,1)
 check(not FrontierExpeditionBusiness.build_reason(core.world,actor,"source_control",at,core.peers).is_empty(),"source control requires owned blueprint")
 for id in FrontierFacilityBlueprints.definitions():FrontierFacilityBlueprints.register(core.world,id,"exploration","fixture:t3")
 var error:=FrontierExpeditionBusiness.apply(core.world,actor,"business_build",{"building":"source_control","position":FrontierExpeditionBusiness.array(at),"yaw":0.0},core.peers)
 check(error.is_empty(),"actual source construction: "+error)
 var controller: Dictionary={}
 for row in site.buildings.values():
  if row.type=="source_control":controller=row
 check(not controller.is_empty() and int(controller.get("tier",0))==3,"source starts at blueprint tier")
 # The following environment and powered machines are isolated processing fixtures.
 var native: Array=site.regions["region:0"].cells.duplicate(true)
 var starting:=FrontierTerraformTier3.mass(site)
 FrontierTerraformTier3.begin(core.world,site,10)
 check(FrontierTerraformTier3.mass(site)>starting and float(site.tier3.suppression)==0,"unpowered source continues actual inflow")
 check(site.regions["region:0"].cells==native,"inflow only reaches declared regions")
 var supply_item: String=site.tier3.rules.profiles[site.tier3.profile].item
 region.inventory[supply_item]=4
 # Power fixture is a real catalog solar generator on the same validated footprint.
 for n in 4:
  var id: String="t3:power:%d"%n
  site.buildings[id]={"id":id,"type":"solar","tier":2,"position":controller.position.duplicate(),"active":true,"enabled":true,"work":0.0,"status":"확인","yaw":0.0,"region_id":"region:1"}
 FrontierTerraformTier3.begin(core.world,site,10)
 check(float(site.tier3.suppression)>.9 and int(region.inventory[supply_item])==3,"powered source consumes destination supplies and suppresses inflow")
 var restock: int=region.inventory[supply_item];controller.enabled=false
 FrontierTerraformTier3.begin(core.world,site,2)
 check(float(site.tier3.suppression)==0 and int(region.inventory[supply_item])==restock,"disabled source stops consuming and resumes inflow")
 controller.enabled=true
 var local:=FrontierRegionalTerraform.facade(site,"region:2")
 var treatment: String=site.tier3.rules.profiles[site.tier3.profile].treatment
 var machine: Dictionary={"id":"t3:treat","type":treatment,"tier":2,"position":local.center.duplicate(),"active":true,"enabled":true,"work":0.0,"status":"확인","yaw":0.0,"region_id":"region:2"}
 local.buildings[machine.id]=machine;local.inventory[supply_item]=10
 var before:=FrontierTerraformTier3.mass(site)
 FrontierTerraformTier3.process(core.world,local,5)
 check(is_equal_approx(before,FrontierTerraformTier3.mass(site)),"Mk2 cannot remove the specialized pollutant")
 machine.tier=3;FrontierTerraformTier3.process(core.world,local,5)
 check(FrontierTerraformTier3.mass(site)<before,"matching Mk3 process removes pollutant with a conserved budget")
 var used_before:=FrontierTerraformTier3.mass(site);machine.type="atmosphere" if treatment=="water" else "water"
 FrontierTerraformTier3.process(core.world,local,5)
 check(is_equal_approx(used_before,FrontierTerraformTier3.mass(site)),"wrong chemical method cannot substitute")
 machine.type=treatment;FrontierRegionalTerraform.merge(site,local)
 var validation:=FrontierExpeditionBusiness.validate(JSON.parse_string(JSON.stringify(core.world.business)),core.world.manifest)
 check(validation.is_empty(),"T3 host/JSON state including mass ledger: "+validation)
 var total:=FrontierCoopWorkload.reward(site,3);var credits: int=core.world.business.credits
 # Native climate and supplied installations are fixtures; pollutant removal and
 # colonization progress are advanced by the actual runtime, never forced stable.
 for zone in site.regions.values():
  zone.inventory[supply_item]=30;zone.inventory.pioneer_culture=30;zone.inventory.ice=100;zone.inventory.soil_base=30
  for cell in zone.cells:
   cell.environment={"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":85.0,"ecology":30.0,"stable_seconds":0.0};cell.restoration2={"salinity":20.0,"soil":80.0}
  if zone.role in ["water","air","recovery"]:
   var id: String="t3:complete:"+str(zone.id)
   site.buildings[id]={"id":id,"type":treatment,"tier":3,"position":zone.center.duplicate(),"active":true,"enabled":true,"work":0.0,"status":"확인","yaw":0.0,"region_id":zone.id}
  if zone.role=="recovery":
   site.buildings["t3:pioneer"]={"id":"t3:pioneer","type":"biolab","tier":3,"position":zone.center.duplicate(),"active":true,"enabled":true,"work":0.0,"status":"확인","yaw":0.0,"region_id":zone.id}
 var elapsed:=0
 for step in 1000:
  FrontierTerraformTier3.begin(core.world,site,1)
  for zone_id in site.regions:
   var facade:=FrontierRegionalTerraform.facade(site,zone_id)
   FrontierRegionalTerraform.environment(core.world,facade,1);FrontierRegionalTerraform.merge(site,facade)
  elapsed=step+1
  if FrontierRegionalTerraform.settlement_reason(site).is_empty():break
 check(FrontierRegionalTerraform.settlement_reason(site).is_empty(),"runtime inflow → treatment → colonization → stable in %ds: "%elapsed+FrontierRegionalTerraform.settlement_reason(site))
 check(FrontierTerraformTier3.valid(site,body),"full treatment preserves pollution mass across all regions")
 FrontierRegionalTerraform.tick(core.world,0)
 check(FrontierRegionalTerraform.paid(site)==floori(total*.15)*3,"three bounded stage payments")
 FrontierRegionalTerraform.tick(core.world,0)
 check(int(core.world.business.credits)==credits+FrontierRegionalTerraform.paid(site),"stages cannot pay twice")
 owner.position=FrontierCrewSurface.config().ship_position.duplicate();core.world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 var remaining:=FrontierPlanetSupply.settlement_payment(site,3,false)
 error=FrontierExpeditionBusiness.apply(core.world,actor,"business_settle",{"retain":false},core.peers)
 check(error.is_empty(),"actual T3 contract settlement: "+error)
 check(int(core.world.business.credits)==credits+total and remaining+FrontierRegionalTerraform.paid(site)==total,"settlement pays exactly the contract total")
 check(not FrontierExpeditionBusiness.apply(core.world,actor,"business_settle",{"retain":false},core.peers).is_empty(),"settlement cannot repeat")
 print("T3_RESULT checks=",checks," failures=",failures," body=",body.ordinal," profile=",site.tier3.profile," simulated_seconds=",elapsed)
 quit(1 if failures else 0)

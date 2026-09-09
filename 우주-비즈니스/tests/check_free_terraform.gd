extends "res://tests/test_crew_surface.gd"
func run() -> void:
 var core:=FrontierCrewAuthority.new();var profile:=FrontierPlayerProfile.new_character("자유 복원 확인",0)
 check(core.start(FrontierUniverse.new_world(71503),profile,persist),"new world")
 core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
 var actor: String=profile.character_id;var ordinal:=259228 if "--gas" in OS.get_cmdline_user_args() else 206387
 var body:=FrontierUniverse.body(core.world.manifest,ordinal)
 core.world.location=body.id;core.world.navigation_target=body.id;core.world.crew.navigation.target=body.ordinal;core.world.crew.navigation.system=body.system_ordinal
 core.world.crew.landing={"body_id":body.id,"epoch":1};core.world.crew.members[actor].aboard=false;core.world.crew.members[actor].area="surface"
 FrontierEcology.ensure_planet(core.world.ecology,body)
 var site:=FrontierExpeditionBusiness.ensure_site(core.world)
 check(FrontierFreeTerraform.active(site) and site.regions.size()==1,"free footprint, no four restoration checkpoints")
 check(FrontierExpeditionBusiness.validate(core.world.business,core.world.manifest).is_empty(),"initial save: "+FrontierExpeditionBusiness.validate(core.world.business,core.world.manifest))
 site.state="active";core.world.business.active=body.id;FrontierCoopWorkload.activate(site,body,1)
 FrontierRegionalTerraform.tick(core.world,1.0)
 check(FrontierFreeTerraform.valid(site,body),"first flow and save")
 var at:=Vector3.INF
 for x in range(950,1100,5):
  if at.is_finite():break
  for z in range(200,300,5):
   var p:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(core.world),x,z,2)
   if not p.is_finite():continue
   core.world.crew.members[actor].position=FrontierExpeditionBusiness.array(p+Vector3(0,0,7))
   var local:=FrontierRegionalTerraform.facade(site,FrontierRegionalTerraform.region_id(site,p));core.world.business.sites[body.id]=local
   var reason:=FrontierExpeditionBusiness.placement(core.world,"water",p,core.peers);core.world.business.sites[body.id]=site
   if reason.is_empty():at=p;break
 check(at.is_finite(),"arbitrary remote terrain placement")
 if not at.is_finite():quit(1);return
 core.world.business.bags[actor]=FrontierExpeditionBusiness.inventory();FrontierExpeditionBusiness.transfer(core.world.business.bags[actor],FrontierCatalog.entry("buildings","water").cost,1)
 var error:=FrontierExpeditionBusiness.apply(core.world,actor,"business_build",{"building":"water","position":FrontierExpeditionBusiness.array(at)},core.peers)
 check(error.is_empty(),"actual remote build: "+error)
 check(site.regions.size()==2,"separate remote supply inventory")
 var remote:=FrontierRegionalTerraform.facade(site,FrontierRegionalTerraform.region_id(site,at))
 check(int(remote.inventory.ice)==0,"home supplies are not remote inventory")
 var b: Dictionary=remote.buildings.values()[0];b.active=true;remote.inventory.ice=100
 FrontierFreeTerraform.ensure_cells(site,body,Vector2(at.x,at.z),64)
 var before:=0.0
 for c in site.free_terraform.cells.values():before+=float(c.environment.water)
 FrontierFreeTerraform.process(core.world,remote,8)
 var after:=0.0;var changed:=0
 for c in site.free_terraform.cells.values():
  after+=float(c.environment.water)
  if c.treated:changed+=1
 check(after>before and changed>1,"one water budget distributed across many cells")
 check(100-int(remote.inventory.ice)==2,"water consumption is once per machine")
 b.active=false;b.submerged=true;var frozen: int=remote.inventory.ice;FrontierFreeTerraform.process(core.world,remote,8)
 check(remote.inventory.ice==frozen,"flood-disabled machine consumes nothing")
 FrontierRegionalTerraform.merge(site,remote)
 var source: Array=site.free_terraform.source;var p:=Vector2(source[0],source[2])
 check(FrontierFreeTerraform.in_pollution(site,p) and not FrontierFreeTerraform.in_pollution(site,p+Vector2(121,0)),"pollution installation boundary")
 var control: Dictionary={"id":"probe","type":"source_control","tier":3,"position":[p.x+130,0,p.y],"active":true,"work":0.0,"status":"","enabled":true}
 var supply: String=site.tier3.rules.profiles[site.tier3.profile].item;remote.inventory[supply]=10
 var stock: int=remote.inventory[supply];FrontierFreeTerraform.specialized(remote,control,[],10)
 check(remote.inventory[supply]==stock and float(site.tier3.suppression)==0,"outside control cannot consume or suppress")
 control.position[0]=p.x;FrontierFreeTerraform.specialized(remote,control,FrontierFreeTerraform.covered(site,control),10)
 check(float(site.tier3.suppression)>.9 and int(remote.inventory[supply])<stock,"inside control consumes actual packs")
 var air: Array=site.free_terraform.air;var index:=FrontierFreeTerraform.air_index(site,Vector2.ZERO)
 var sum_before:=0.0
 air[index][0]=minf(1,float(air[index][0])+.1)
 for row in air:sum_before+=float(row[0])
 FrontierFreeTerraform.finish(site,1)
 var sum_after:=0.0
 for row in air:sum_after+=float(row[0])
 check(absf(sum_after-sum_before)<.00001,"spherical atmosphere exchanges conserve mass")
 check(FrontierFreeTerraform.valid(site,body),"sparse pollution and atmosphere ledger validates")
 var snapshot: Dictionary=JSON.parse_string(JSON.stringify(site))
 check(FrontierFreeTerraform.valid(snapshot,body),"JSON roundtrip")
 check(not FrontierFreeTerraform.settlement_reason(site).is_empty(),"one remote facility cannot complete contract")
 # Soil overlap and distribution use runtime winner selection, not installation bonuses.
 var soil: Dictionary={"id":"soil:a","type":"biolab","tier":2,"position":b.position.duplicate(),"active":true,"enabled":true,"work":0.0,"status":"","yaw":0.0,"region_id":b.region_id}
 var second: Dictionary=soil.duplicate(true);second.id="soil:b"
 remote.buildings={soil.id:soil,second.id:second};remote.inventory.soil_base=50
 var supply_before: int=remote.inventory.soil_base
 site.free_terraform.soil_winners={}
 for key in site.free_terraform.cells:site.free_terraform.soil_winners[key]={"id":soil.id,"strength":1.0}
 var soil_cells:=FrontierFreeTerraform.covered(remote,soil)
 var duplicate_cells:=FrontierFreeTerraform.covered(remote,second)
 check(not soil_cells.is_empty() and duplicate_cells.is_empty(),"duplicate soil footprint has no double work")
 FrontierFreeTerraform.local_machine(core.world,remote,body,soil,soil_cells,30)
 var consumed:=supply_before-int(remote.inventory.soil_base)
 FrontierFreeTerraform.local_machine(core.world,remote,body,second,duplicate_cells,30)
 check(consumed>0 and supply_before-int(remote.inventory.soil_base)==consumed,"overlap consumes one soil budget")
 # Full contract runtime with prepared climate, structures and stocks. No stability/colony flags are injected.
 core.world.business.sites.erase(body.id)
 site=FrontierExpeditionBusiness.ensure_site(core.world);site.state="active";core.world.business.active=body.id;FrontierCoopWorkload.activate(site,body,1)
 p=Vector2(site.free_terraform.source[0],site.free_terraform.source[2])
 var field:=FrontierCrewSurface.field(core.world)
 var treatment: String=site.tier3.rules.profiles[site.tier3.profile].treatment
 for n in 8:
  var angle:=n*TAU/8;var center:=p+Vector2(cos(angle),sin(angle))*75
  var ground:=Vector3.INF
  for dx in range(-48,49,4):
   if ground.is_finite():break
   for dz in range(-48,49,4):
    var candidate:=FrontierExpeditionBusiness.ground(field,center.x+dx,center.y+dz,3)
    if candidate.is_finite() and FrontierFreeTerraform.in_pollution(site,Vector2(candidate.x,candidate.z)):ground=candidate;break
  if not ground.is_finite():continue
  fixture(site,"plant:%d"%n,treatment,3,ground)
  fixture(site,"soil:%d"%n,"biolab",3,ground)
  fixture(site,"solar:%d"%n,"solar",2,ground)
  fixture(site,"solar:b:%d"%n,"solar",2,ground)
  if not site.buildings.has("control"):fixture(site,"control","source_control",3,ground)
  FrontierFreeTerraform.ensure_cells(site,body,Vector2(ground.x,ground.z),96)
 for n in 3:
  var remote_point:=Vector3.INF
  for x in range(950+n*180,1100+n*180,5):
   if remote_point.is_finite():break
   for z in range(200,350,5):
    var candidate:=FrontierExpeditionBusiness.ground(field,x,z,3)
    if candidate.is_finite():remote_point=candidate;break
  check(remote_point.is_finite(),"distributed habitat fixture %d"%n)
  if not remote_point.is_finite():continue
  fixture(site,"habitat:%d"%n,"biolab",3,remote_point);fixture(site,"habitat_power:%d"%n,"solar",2,remote_point)
  FrontierFreeTerraform.ensure_cells(site,body,Vector2(remote_point.x,remote_point.z),64)
 for region in site.regions.values():
  for item in region.inventory:region.inventory[item]=1000
  for item in FrontierProductionTier2.config().products:region.inventory[item]=1000
 for c in site.free_terraform.cells.values():
  c.environment.temperature=18.0;c.environment.water=85.0;c.environment.ecology=30.0;c.restoration2.soil=80.0;c.restoration2.salinity=0.0
 for row in site.free_terraform.air:row[0]=.21;row[1]=1.0;row[2]=0.0
 var elapsed:=0.0
 print("FREE_FLOW_FIXTURE buildings=",site.buildings.size())
 for n in (1 if "--inspect" in OS.get_cmdline_user_args() else 1400):
  FrontierRegionalTerraform.tick(core.world,2);elapsed+=2
  if n%200==0:print("FREE_FLOW ",n," ",FrontierFreeTerraform.detail(site))
  if FrontierFreeTerraform.settlement_reason(site).is_empty():break
 check(FrontierFreeTerraform.settlement_reason(site).is_empty(),"runtime full T3: "+FrontierFreeTerraform.detail(site))
 check(FrontierFreeTerraform.valid(site,body),"full contract pollution mass and area validate")
 check(site.regional_paid.size()==2,"area stages awarded once")
 var paid:=FrontierRegionalTerraform.paid(site);var credits: int=core.world.business.credits
 FrontierRegionalTerraform.tick(core.world,2)
 check(core.world.business.credits==credits,"no repeat area payout")
 core.world.crew.members[actor].position=FrontierCrewSurface.config().ship_position.duplicate()
 var settle:=FrontierExpeditionBusiness.apply(core.world,actor,"business_settle",{"retain":false},core.peers)
 check(settle.is_empty(),"actual settlement: "+settle)
 check(int(site.settlement.get("payment",-1))+paid==FrontierCoopWorkload.reward(site,3),"stage plus final payout total")
 check(FrontierExpeditionBusiness.validate(core.world.business,core.world.manifest).is_empty(),"final business save: "+FrontierExpeditionBusiness.validate(core.world.business,core.world.manifest))
 print("FREE_RESULT checks=%d failures=%d profile=%s simulated_seconds=%.0f"%[checks,failures,site.tier3.profile,elapsed]);quit(1 if failures else 0)
func fixture(site: Dictionary,id: String,kind: String,tier: int,p: Vector3) -> void:
 var region:=FrontierFreeTerraform.district_id(site,p)
 if not site.regions.has(region):site.regions[region]=FrontierFreeTerraform.district(site,region)
 site.buildings[id]={"id":id,"type":kind,"tier":tier,"position":FrontierExpeditionBusiness.array(p),"active":true,"enabled":true,"work":0.0,"status":"fixture","yaw":0.0,"region_id":region}

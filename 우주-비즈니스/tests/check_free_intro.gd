extends "res://tests/test_crew_surface.gd"
func run() -> void:
 var core:=FrontierCrewAuthority.new();var profile:=FrontierPlayerProfile.new_character("입문 면적 확인",0)
 check(core.start(FrontierUniverse.new_world(71503),profile,persist),"start")
 core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
 core.world.business=FrontierExpeditionBusiness.create()
 var found: Dictionary={}
 for ordinal in range(8,1000000,37):
  var body:=FrontierUniverse.body(core.world.manifest,ordinal)
  if not FrontierUniverse.landable(body) or not FrontierFreeTerraform.enabled(body) or int(body.planet_tier) not in [1,2] or found.has(str(int(body.planet_tier))):continue
  found[str(int(body.planet_tier))]=body
  if found.size()==2:break
 for tier in ["1","2"]:
  var body: Dictionary=found[tier];core.world.location=body.id;core.world.crew.landing={"body_id":body.id,"epoch":1};core.world.business.active=body.id
  var site:=FrontierExpeditionBusiness.ensure_site(core.world);site.state="active";FrontierCoopWorkload.activate(site,body,1)
  var r:=FrontierFreeTerraform.radius(site,{"type":"biolab"})
  check((r==32 if tier=="1" else FrontierFreeTerraform.goal(site)>PI*r*r),"T"+tier+" footprint/area progression")
  # Prepared climate and existing basic materials; actual soil/ecology/stability runtime below.
  for a in site.free_terraform.air:a[0]=.21;a[1]=1.0;a[2]=0.0
  var local:=FrontierRegionalTerraform.facade(site,"region:0");local.inventory.ice=1000;local.inventory["soil_base"]=1000;local.inventory["soil_activation_pack"]=1000
  var count:=1 if tier=="1" else 4
  for n in count:
   var point:=Vector2(120+n*160,90)
   FrontierFreeTerraform.ensure_cells(site,body,point,r)
   var b: Dictionary={"id":"intro:%d"%n,"type":"biolab","tier":int(tier),"position":[point.x,0,point.y],"active":true,"enabled":true,"work":0.0,"status":"fixture","region_id":"region:0","yaw":0.0}
   local.buildings[b.id]=b
  for c in site.free_terraform.cells.values():c.environment.temperature=18.0;c.environment.water=85.0;c.restoration2.salinity=0.0
  for step in 500:
   site.free_terraform.soil_winners={}
   for key in site.free_terraform.cells:
    var c: Dictionary=site.free_terraform.cells[key]
    for b in local.buildings.values():
     if Vector2(c.position[0]-b.position[0],c.position[2]-b.position[2]).length()<r:site.free_terraform.soil_winners[key]={"id":b.id,"strength":1.0}
   FrontierFreeTerraform.process(core.world,local,2);FrontierFreeTerraform.finish(site,2)
   if FrontierFreeTerraform.settlement_reason(site).is_empty():break
  check(FrontierFreeTerraform.settlement_reason(site).is_empty(),"T"+tier+" runtime habitat: "+FrontierFreeTerraform.detail(site))
  check(FrontierFreeTerraform.valid(site,body),"T"+tier+" new save validates")
  site.state="supply";site.production_lease=true
 print("FREE_INTRO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

extends "res://tests/test_crew_surface.gd"
func flood(world: Dictionary,row: Dictionary,level: float) -> void:
 var water:=FrontierSurfaceWater.create();var p:=FrontierCrewWorld.vector(row.position)
 for x in range(floori(p.x)-5,ceili(p.x)+6):
  for z in range(floori(p.z)-5,ceili(p.z)+6):
   for y in range(floori(p.y),ceili(level)):
    water.cells[FrontierSurfaceWater.key(Vector3i(x,y,z))]=[minf(1,level-y),0.0]
 world.surface_water={world.location:water}
func run() -> void:
 var row: Dictionary={"type":"factory","position":[0,0,0],"tier":2,"yaw":0.0}
 var box:=FrontierFacilityFlooding.bounds(row)
 check(not FrontierFacilityFlooding.enclosed(row,func(p: Vector3):return p.y<box.end.y-.1),"partially wet factory stays available")
 check(FrontierFacilityFlooding.enclosed(row,func(p: Vector3):return p.y<box.end.y+.2),"water above whole model disables facility")
 check(not FrontierFacilityFlooding.enclosed(row,func(p: Vector3):return p.y>box.end.y-.1),"water sheet above a dry interior is not immersion")
 check(not FrontierFacilityFlooding.enclosed(row,func(p: Vector3):return p.x<box.end.x-.05),"dry roof corner prevents full immersion")
 var core:=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("침수 검증",0)
 check(core.start(FrontierUniverse.new_world(71491),owner,persist),"host starts")
 core.phase="playing"
 var ordinal:=FrontierUniverse.first_ordinal(core.world.manifest,23)
 while not FrontierUniverse.landable(FrontierUniverse.body(core.world.manifest,ordinal)):ordinal+=1
 var body:=FrontierUniverse.body(core.world.manifest,ordinal)
 var nav: Dictionary=core.world.crew.navigation
 nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
 var at:=FrontierCrewNavigation.center(ordinal,core.world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
 nav.position=[at.x,at.y,at.z];nav.direction=[0,0,-1];core.world.location=body.id
 ready_all(core)
 var landing:=request(core,1,"land");check(landing.ok,"host lands: "+str(landing))
 if not landing.ok:quit(1);return
 check(request(core,1,"business_register").ok,"host site registers")
 var site:=FrontierExpeditionBusiness.site(core.world);var terrain:=FrontierCrewSurface.field(core.world)
 row={"id":"facility:1","type":"factory","position":[0,terrain.height(0,0),0],"yaw":0.0,"tier":2,"enabled":true,"active":true,"working":false,"status":"가동 중","work":0.0,"production":{"product":"refined_iron","progress":1.0}}
 site.buildings[row.id]=row
 site.buildings["facility:2"]={"id":"facility:2","type":"solar","position":[12,terrain.height(12,0),0],"yaw":0.0,"enabled":true,"active":false,"status":"전력 확인 중","work":0.0}
 core.world.business.counter=2
 var position:=FrontierCrewWorld.vector(row.position)
 core.update_position(1,position+Vector3(0,0,5))
 flood(core.world,row,position.y+box.end.y+.2)
 FrontierExpeditionIndustry.tick(core.world,1)
 check(row.get("submerged",false) and not row.active and not row.get("working",false) and row.status==FrontierFacilityFlooding.STATUS,"immersed factory loses power and work state")
 check(row.production.progress==1 and row.enabled,"production and switch choice survive immersion")
 var before:=FrontierUniverse.fingerprint(core.world)
 for kind in ["business_toggle","business_produce","business_facility_upgrade","business_craft","business_research_prototype"]:
  var result:=request(core,1,kind,{"building_id":row.id,"facility_id":row.id,"product":"refined_iron"})
  check(not result.ok and "침수" in result.get("error",result.get("message","")),"host rejects flooded use: "+kind)
 var base_world:=core.world.duplicate(true);var base_site:=FrontierExpeditionBusiness.site(base_world)
 var base_row: Dictionary={"type":"storage","position":base_site.center}
 flood(base_world,base_row,float(base_site.center[1])+FrontierFacilityFlooding.bounds(base_row).end.y+.2)
 FrontierFacilityFlooding.refresh_base(base_world,base_site)
 check(base_site.get("base_submerged",false) and not FrontierExpeditionBusiness.near_warehouse(base_site,FrontierCrewWorld.vector(base_site.center)),"default field warehouse also locks when fully submerged")
 check(before==FrontierUniverse.fingerprint(core.world),"rejected use spends no inventory or progression")
 check(FrontierUniverse.validate_world(core.world).is_empty(),"submerged state passes save validation")
 var packet:=FrontierCrewSurfaceReplica.packet(core.world,owner.character_id)
 check(packet.business.sites[core.world.location].buildings[row.id].submerged and not FrontierCrewSurfaceReplica.decode(FrontierCrewSurfaceReplica.encode(packet),core.world.manifest).is_empty(),"submerged state replicates with validated surface packet")
 core.world.surface_water.clear();FrontierExpeditionIndustry.tick(core.world,1)
 check(not row.submerged and row.active and row.production.progress>1,"drainage resumes existing production")
 row.enabled=false;flood(core.world,row,position.y+box.end.y+.2);FrontierExpeditionIndustry.tick(core.world,1)
 core.world.surface_water.clear();FrontierExpeditionIndustry.tick(core.world,1)
 check(not row.enabled and not row.active,"drainage respects player's disabled switch")
 var solar: Dictionary=site.buildings["facility:2"];var solar_pos:=FrontierCrewWorld.vector(solar.position)
 flood(core.world,solar,solar_pos.y+FrontierFacilityFlooding.bounds(solar).end.y+.2);FrontierExpeditionIndustry.power(core.world,site)
 check(solar.submerged and site.power_supply==2,"submerged generator contributes no power")
 var storage: Dictionary={"id":"store","type":"storage","position":[40,3,0],"submerged":true}
 site.buildings.store=storage
 check(not FrontierExpeditionBusiness.near_warehouse(site,Vector3(40,3,0)),"submerged warehouse is not an access point")
 print("FACILITY_FLOODING ",checks," FAILURES ",failures);quit(1 if failures else 0)

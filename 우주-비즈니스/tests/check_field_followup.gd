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
 var site:=FrontierExpeditionBusiness.site(world)
 var member: Dictionary=world.crew.members[actor]
 var before: int=member.loadout.items.size()
 check(not FrontierEquipment.apply(world,actor,"equipment_craft",{"definition":"pulse_1"}).is_empty() and member.loadout.items.size()==before,"equipment crafting requires physical workbench")
 for id in ["metalworks","equipment_workbench"]:
  check(FrontierFacilityResearch.construction_unlocked(world.business,id),id+" is buildable with basic technology")
  site.buildings[id]={"id":id,"type":id,"tier":1,"position":member.position.duplicate(),"yaw":0.0,"enabled":true,"active":true,"work":0.0,"status":"가동 중"}
 world.business.bags[actor].iron=100;world.business.bags[actor].copper=100;world.business.bags[actor].stone=50;world.business.bags[actor].crystal=20
 var crafting:=FrontierEquipment.apply(world,actor,"equipment_craft",{"definition":"pulse_1"})
 check(crafting.is_empty() and member.loadout.items.size()==before+1,"workbench crafts actual weapon into backpack: "+crafting)
 var position_before: Array=member.position.duplicate();member.position[0]+=30
 check(not FrontierEquipment.apply(world,actor,"equipment_craft",{"definition":"pulse_1"}).is_empty(),"remote workbench request rejected")
 member.position=position_before
 site.base_deployed=true
 site.inventory.iron=20
 var recipe:=FrontierProductionTier2.product("refined_iron")
 check(FrontierProductionTier2.recipe_reason(site,"metalworks",recipe,FrontierUniverse.body_from_id(world.manifest,world.location)).is_empty(),"metalworks accepts ore refining")
 site.buildings.factory={"id":"factory","type":"factory","tier":2,"position":member.position.duplicate(),"yaw":0.0,"enabled":true,"active":true,"work":0.0,"status":"가동 중"}
 check(not FrontierProductionTier2.recipe_reason(site,"factory",recipe,FrontierUniverse.body_from_id(world.manifest,world.location)).is_empty(),"assembly factory no longer starts metal refining")
 var result:=FrontierProductionTier2.apply(world,actor,"business_produce",{"building_id":"metalworks","product":"refined_iron"})
 check(result.is_empty(),"metal factory reserves recipe once: "+result)
 var stock: int=site.inventory.get("refined_iron",0)
 FrontierProductionTier2.tick(site,4.)
 check(site.inventory.get("refined_iron",0)==stock+2 and site.buildings.metalworks.production.is_empty(),"metalworks completes into warehouse")
 check(FrontierProductionTier2.validate_building(site.buildings.metalworks),"new facility persists")
 var nav: Dictionary=world.crew.navigation;nav.mode="approach";nav.speed=700;nav.boosting=false;nav.hull=100
 check(is_equal_approx(FrontierCrewNavigation.approach_speed(world,700,100000,95,.1),700),"F cruise keeps 700 away from arrival")
 check(FrontierCrewNavigation.approach_speed(world,700,1,95,.1)<20,"arrival still brakes safely")
 var jump: Dictionary={"mode":"jump","transit":{"progress":.5}}
 var label:=FrontierFlightTelemetry.speed_label(jump)
 check(label.contains("추정") and label.contains("c") and not label.contains("%") and not label.contains("초"),"transit displays estimated FTL speed")
 var a:=FrontierCrewAuthority.new();a.world=world;a.now=10
 var info: Dictionary={"kind":"discovery","id":"test","name":"노래하는 돌기둥","point":[0,0,0],"icon":"scan","subtitle":"탐험 발견","notes":[],"condition":"기록"}
 a.staged_autonomous=true;a._complete_scan(1,info,"test")
 check(not a._presented_scan(1).get("known",false),"scan success is hidden until durable confirmation")
 a.autonomous_world=world.duplicate();a.finish_autonomous=func():return 1
 a.resolve_autonomous(true)
 a.scans.erase(1)
 check(a._presented_scan(1).get("known",false),"released scan survives snapshot cadence after commit")
 var serial: int=a._presented_scan(1).get("receipt",0)
 a.staged_autonomous=false;a._complete_scan(1,info,"test")
 check(a._presented_scan(1).receipt>serial,"explicit rescan gets fresh result receipt")
 a.now=20;a.scans.erase(1)
 check(a._presented_scan(1).is_empty(),"scan receipt expires")
 check(FrontierSharedPlayGuide.KEYS.has("supply_requested"),"supply request is shared milestone")
 check(not FrontierSharedPlayGuide.report(world.crew,{"steps":["supply_requested"]}).is_empty(),"client guide claim cannot fake successful supply")
 var canonical:=FrontierContentTextIdentity.canonical(FrontierCatalog.all())
 var changed:=FrontierCatalog.all().duplicate(true);changed.buildings.solar.cost.iron+=1
 check(FrontierContentTextIdentity.canonical(changed)!=canonical,"text identity compatibility never bypasses a real cost change")
 site.inventory.iron=20
 var draft:=preload("res://scripts/persistence/world_draft.gd").request(world,actor,"business_produce",{"building_id":"metalworks","product":"refined_iron"})
 check(FrontierProductionTier2.apply(draft,actor,"business_produce",{"building_id":"metalworks","product":"refined_iron"}).is_empty(),"scoped manufacturing candidate accepts production")
 check(site.inventory.iron==20 and site.buildings.metalworks.production.is_empty() and is_same(draft.ecology,world.ecology),"production affects its candidate site without rewriting ecology or published stock")
 world.crew.play_guide={}
 member.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(3,0,3))
 member.position[1]=FrontierCrewSurface.field(world).height(member.position[0],member.position[2])+.1
 FrontierLotusSupport.ensure(world);world.lotus.next_request=0;world.lotus.free_remaining=3;world.lotus.crates={}
 var invalid:=FrontierLotusSupport.apply(world,actor,"lotus_request",{"resource":"invalid"})
 check(not invalid.is_empty() and not world.crew.play_guide.get("supply_requested",false),"failed supply request does not graduate guide")
 var supply:=FrontierLotusSupport.apply(world,actor,"lotus_request",{"resource":"iron"})
 check(supply.is_empty() and world.crew.play_guide.get("supply_requested",false),"successful supply transaction records shared milestone: "+supply)
 print("FIELD_FOLLOWUP failures ",failures);quit(1 if failures else 0)

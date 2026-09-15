extends SceneTree
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func row(kind: String,at: Vector3=Vector3.ZERO) -> Dictionary:
 return {"id":kind,"type":kind,"tier":1,"position":FrontierExpeditionBusiness.array(at),"yaw":0.,"enabled":true,"active":true,"working":false,"status":"","work":0.}
func run():
 var world:=FrontierWorldStore.new("/tmp/playtest-field-research/world.json").read_state()
 if world.is_empty():quit(2);return
 var actor: String=world.crew.owner_id
 world.crew.members[actor].position=FrontierCrewSurface.config().ship_position.duplicate()
 world.business.credits=10000;world.business.bags[actor]={"iron":100,"copper":100}
 world.discoveries={"version":1,"records":{}};var ok:=true
 for key in FrontierDiscoveryUtilities.config().buildings:
  world.business.facility_research.erase(key)
  ok=ok and not FrontierFacilityResearch.apply(world,actor,{"research":key}).is_empty()
  var template: String=FrontierDiscoveryUtilities.config().projects[key].discoveries[0]
  world.discoveries.records[key]={"template":template,"claimed":true}
  ok=ok and FrontierFacilityResearch.apply(world,actor,{"research":key}).is_empty() and FrontierFacilityResearch.construction_unlocked(world.business,key)
  ok=ok and FrontierDiscoveryExhibits.usage(template,"discoveries",true).contains("실용 설비") and FrontierProductionTier2.upgrade_definition(row(key)).is_empty()
 check(ok,"four proof-gated shared licenses, journal usage and no invented upgrades")
 var site:=FrontierExpeditionBusiness.site(world);site.buildings={}
 var b:=row("luminous_vivarium");site.buildings[b.id]=b;world.crew.members[actor].position=[0.,0.,0.]
 var form: Dictionary=FrontierEcologyCatalog.choose_diverse(12,"wetland","microbe",1)[0]
 print("FORM ",form)
 var sample: Dictionary={"id":"utilitytest".sha256_text(),"source_body":world.location,"form_id":form.form_id,"look_id":form.look_id,"state":"cargo"}
 var key:=FrontierSpecimenItems.resource(sample)
 world.ecology.specimens={sample.id:sample};world.ecology.item_storage_version=1;world.crew.cargo={};world.business.bags[actor]={key:1}
 check(not FrontierDiscoveryUtilities.conditions(site,b).ready,"empty culture has no illumination")
 var draft:=preload("res://scripts/persistence/world_draft.gd").request(world,actor,"business_discovery_use",{"building_id":b.id})
 var reason:=FrontierDiscoveryUtilities.apply(draft,actor,{"building_id":b.id,"action":"install","specimen":key})
 print("INSTALL ",reason," decoded ",FrontierSpecimenItems.decode(key))
 check(reason.is_empty() and world.business.bags[actor].has(key) and not b.has("specimen_stock") and is_same(world.ecology,draft.ecology),"install draft isolates local building and bag without copying ecology")
 world=draft;site=FrontierExpeditionBusiness.site(world);b=site.buildings[b.id]
 check(FrontierSpecimenItems.validate(world).is_empty() and FrontierDiscoveryUtilities.valid(b) and not FrontierDiscoveryUtilities.apply(world,actor,{"building_id":b.id,"action":"install","specimen":key}).is_empty(),"installed real sample stays unique and duplicate install rejected")
 site.environment.temperature=20
 check(FrontierDiscoveryUtilities.conditions(site,b).ready,"culture supports temperate site")
 site.environment.temperature=60
 check(not FrontierDiscoveryUtilities.conditions(site,b).ready,"culture stops outside temperature range")
 reason=FrontierExpeditionBusiness.apply_local(world,actor,"business_demolish",{"building_id":b.id},{1:actor})
 check(reason.contains("표본"),"occupied culture cannot be demolished")
 check(FrontierDiscoveryUtilities.apply(world,actor,{"building_id":b.id,"action":"remove"}).is_empty() and world.business.bags[actor].has(key) and FrontierSpecimenItems.validate(world).is_empty(),"sample recovery preserves specimen identity")
 var alarm:=row("flood_sentinel");var target:=row("storage",Vector3(5,0,0));var far:=row("storage",Vector3(40,0,0));far.id="far"
 check(FrontierDiscoveryUtilities.wet_targets({target.id:target,far.id:far},alarm,func(p: Vector3):return p.y<.2)==target.id and FrontierDiscoveryUtilities.wet_targets({far.id:far},alarm,func(_p: Vector3):return true).is_empty(),"foundation wetness triggers within 30m only")
 var shell:=row("shell_refuge");shell.yaw=PI/2;site.buildings={shell.id:shell}
 check(FrontierPlanetWeather.canopy(world,Vector3(0,1,1.8)) and not FrontierPlanetWeather.canopy(world,Vector3(2.5,1,0)),"shell shelter respects roof footprint and rotation")
 var garden:=row("resonance_garden");site.buildings[garden.id]=garden
 check(FrontierDiscoveryUtilities.apply(world,actor,{"building_id":garden.id,"action":"mute"}).is_empty() and garden.muted and FrontierDiscoveryUtilities.apply(world,actor,{"building_id":garden.id,"action":"tone"}).is_empty() and garden.resonance_tone==2 and FrontierDiscoveryUtilities.valid(garden),"mute and three-pitch state validate")
 print("DISCOVERY_UTILITIES failures ",failures);quit(1 if failures else 0)

extends "res://tests/test_crew_surface.gd"
class OpenField extends FrontierTerrainField:
 func density(_point: Vector3) -> float:return -1.0
func run() -> void:
 var manifest:=FrontierUniverse.new_world(71491)
 var samples: Dictionary={};var large: Dictionary={};var differences: Dictionary={}
 for ordinal in range(8,1000000,313):
  var body:=FrontierUniverse.body(manifest.manifest,ordinal)
  if not FrontierUniverse.landable(body) or FrontierEcology.profile(body).origin!="established":continue
  for template in FrontierExplorationIncidents.config().items:
   var kind:=FrontierNativeIncidents.role(template)
   if kind.is_empty() or int(body.planet_tier)<int(FrontierNativeIncidents.config().roles[kind].tier):continue
   var row: Dictionary={"id":"native-check:"+kind,"template":template,"body_id":body.id,"tier":body.planet_tier,"position":[100,0,100],"relay":[100,0,155],"yaw":0.0,"battery_position":[100,0,100],"path":[[100,0,100],[100,0,155]]}
   var native:=FrontierNativeIncidents.choose(body,row)
   if native.is_empty():continue
   row.native=native
   if not samples.has(kind):samples[kind]={"row":FrontierExplorationIncidents.create(row),"body":body}
   differences[native.form_id]=true
   if float(native.factor)>1.25:large[kind]=true
  if samples.size()==5 and differences.size()>8:break
 check(samples.size()==5,"all five roles find native eligible lineages")
 check(differences.size()>1,"different planets use different actual species")
 check(not large.is_empty(),"exceptional adults exceed native scale")
 for kind in samples:
  var row: Dictionary=samples[kind].row;var body: Dictionary=samples[kind].body
  var natives: Array=FrontierEcology.ensure_planet({"planets":{}},body).lineages
  check(natives.any(func(n):return n.form_id==row.native.form_id and n.look_id==row.native.look_id),kind+" belongs to local lineage")
  check(row.native==FrontierNativeIncidents.choose(body,row),kind+" deterministic individual")
  var copy: Dictionary=JSON.parse_string(JSON.stringify(row))
  var world:=manifest.duplicate(true);var actor:=FrontierCrewWorld.member(FrontierPlayerProfile.new_character("local",0),"local",0);actor.area="surface";world.crew={"members":{"owner":actor}};world.incidents={"version":1,"records":{FrontierExplorationIncidents.key(copy):copy}}
  check(FrontierNativeIncidents.validate(world,copy),kind+" individual JSON survives")
  copy.native.factor+=.1;check(not FrontierNativeIncidents.validate(world,copy),kind+" rejects forged scale");copy.native.factor-=.1
  row.native_observed=false;row.native_walked=0
  check(not FrontierNativeIncidents.available(row),kind+" no reward before observation")
  check(FrontierNativeIncidents.look(row.native).palette==row.native.palette,kind+" appearance palette")
  for resource in FrontierNativeIncidents.reward(row):check(not FrontierCatalog.entry("resources",resource).is_empty(),kind+" real reward resource "+resource)
  if kind=="giant":check(is_equal_approx(float(row.native.factor),4.0),"giant is four times the native linear size")
 var site: Dictionary=samples.scavenger;var r: Dictionary=site.row
 var owner:=FrontierPlayerProfile.new_character("현지 개체 확인",0);var core:=FrontierCrewAuthority.new();check(core.start(manifest,owner,func(_w):return true),"host starts")
 var actor_id: String=owner.character_id
 var m: Dictionary=core.world.crew.members[actor_id];m.area="surface";m.aboard=false;m.position=[100,0,150]
 core.world.location=site.body.id;core.world.crew.landing={"body_id":site.body.id};core.world.incidents={"version":1,"records":{FrontierExplorationIncidents.key(r):r}}
 if not core.world.has("business"):core.world.business=FrontierExpeditionBusiness.create()
 core.world.business.bags[actor_id]=FrontierExpeditionBusiness.inventory()
 var id:=FrontierExplorationIncidents.key(r)
 check(not FrontierExplorationIncidents.recover(core.world,actor_id,r).is_empty(),"host refuses premature loot")
 FrontierNativeIncidents.observe(core.world,id)
 check(core.world.ecology.observations.has(site.body.id+":"+r.native.form_id),"native analysis records real lineage")
 check(not FrontierNativeIncidents.available(r),"scavenger must lead player")
 r.native_walked=FrontierNativeIncidents.path_length(r)
 check(FrontierExplorationIncidents.recover(core.world,actor_id,r).is_empty(),"observed trail grants actual resources and module")
 check(not FrontierExplorationIncidents.recover(core.world,actor_id,r).is_empty(),"same place does not duplicate loot")
 var guard: Dictionary=samples.guardian.row.duplicate(true)
 guard.native_observed=false;guard.native_alert=0;guard.native_wait=0;guard.native_distance=0
 var at:=FrontierNativeIncidents.position(guard)
 m.position=FrontierExplorationIncidents.array(at+Vector3.RIGHT*(FrontierNativeIncidents.radius(guard.native)+.5))
 var health_before: float=m.vitals.health
 FrontierNativeIncidents.tick(core.world,guard,[actor_id],1.0,OpenField.new())
 check(m.vitals.health==health_before and guard.native_alert>0,"guardian warns before damage")
 FrontierNativeIncidents.tick(core.world,guard,[actor_id],1.1,OpenField.new())
 check(m.vitals.health<health_before and int(guard.native_attack)==1,"guardian confirmed defensive hit")
 m.position=FrontierExplorationIncidents.array(at+Vector3.RIGHT*20)
 health_before=m.vitals.health
 FrontierNativeIncidents.tick(core.world,guard,[actor_id],4.0,OpenField.new())
 check(m.vitals.health==health_before and guard.native_alert==0,"retreat avoids guardian follow-up")
 guard.native_observed=true;var before: float=guard.native_distance
 for i in 40:FrontierNativeIncidents.tick(core.world,guard,[actor_id],.25,OpenField.new())
 check(guard.native_distance>before,"observed guardian leaves nest for feeding")
 var legacy:=r.duplicate(true);legacy.erase("native")
 check(FrontierNativeIncidents.validate(core.world,legacy),"legacy scavenger preserved")
 DirAccess.make_dir_recursive_absolute("/tmp/native-incidents")
 var out:=FileAccess.open("/tmp/native-incidents/samples.json",FileAccess.WRITE);out.store_string(JSON.stringify(samples))
 print("NATIVE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

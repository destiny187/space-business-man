class_name FrontierNativeIncidents
extends RefCounted
## Seeded exceptional individuals of the planet's own authored lineages.
static var _config: Dictionary={}
static var _candidates: Dictionary={}
static var _picks: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_incidents.json"))
 return _config
static func role(template: String) -> String:return str(FrontierExplorationIncidents.definition(template).get("native_role",""))
static func candidates(body: Dictionary,kind: String) -> Array:
 var id: String=body.id+":"+kind
 if _candidates.has(id):return _candidates[id]
 var result: Array=[];var rule: Dictionary=config().roles[kind]
 if FrontierEcology.profile(body).origin=="established":
  var ecology: Dictionary={"planets":{}}
  for lineage in FrontierEcology.ensure_planet(ecology,body).lineages:
   var form:=FrontierEcologyCatalog.form(lineage.form_id)
   if form.category!="animal" or form.family not in rule.families:continue
   if (form.environment=="cave")!=(rule.layer=="cave"):continue
   var look:=FrontierEcologyCatalog.look(lineage.form_id,lineage.look_id)
   var height: float=(float(form.geometry.near.ceiling_y)-float(form.geometry.near.floor_y))*float(look.scale)
   if height>float(rule.max_height):continue
   if kind=="giant":
    var dimensions:=FrontierCrewWorld.vector(form.geometry.near.max)-FrontierCrewWorld.vector(form.geometry.near.min)
    if height*float(rule.scale)>float(rule.max_height) or maxf(dimensions.x,dimensions.z)*float(look.scale)*float(rule.scale)>float(rule.get("max_length",config().max_length)):continue
   result.append(lineage.duplicate(true))
 result.sort_custom(func(a,b):return a.form_id<b.form_id)
 if _candidates.size()>128:_candidates.clear()
 _candidates[id]=result;return result
static func choose(body: Dictionary,row: Dictionary) -> Dictionary:
 var kind:=role(row.template);var cache: String=body.id+":"+row.id
 if _picks.has(cache):return _picks[cache].duplicate(true)
 var pool:=candidates(body,kind)
 if pool.is_empty():return {}
 var seed_value:=FrontierUniverse.derive(int(body.streams.ecology),"native-event-v1:"+str(row.id))
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var selected: Dictionary=pool[rng.randi_range(0,pool.size()-1)]
 var form:=FrontierEcologyCatalog.form(selected.form_id);var base:=FrontierEcologyCatalog.look(selected.form_id,selected.look_id)
 var weight: Array=config().weights[str(int(body.planet_tier))];var chance:=rng.randi_range(1,100);var variant: String="ordinary"
 for i in weight.size():
  chance-=int(weight[i])
  if chance<=0:variant=config().variants.keys()[i];break
 if kind=="rare":variant="rare"
 var rule: Dictionary=config().roles[kind];var v: Dictionary=config().variants[variant]
 var dimensions:=FrontierCrewWorld.vector(form.geometry.near.max)-FrontierCrewWorld.vector(form.geometry.near.min)
 var factor:=rng.randf_range(float(v.scale[0]),float(v.scale[1]))*float(rule.scale)
 if kind=="giant":factor=float(rule.scale)
 factor=minf(factor,minf(float(rule.max_height)/(dimensions.y*float(base.scale)),float(rule.get("max_length",config().max_length))/(maxf(dimensions.x,dimensions.z)*float(base.scale))))
 factor=snappedf(factor,.001)
 var palette: Array=base.palette.duplicate()
 if variant=="rare":
  # Preserve lineage identity; a bounded pigment shift marks this individual only.
  for i in palette.size():
   var color:=Color(palette[i]);palette[i]=Color.from_hsv(fmod(color.h+.15,.999),clampf(color.s+.12,0,1),clampf(color.v*1.10,0,1)).to_html(false)
 var result:=selected.duplicate(true)
 result["track"]="groove" if form.family in ["coil","slug","ribbon_colony"] else ("claw" if form.family in ["carapace","mantid","asym_pincer","burrower"] else "paw")
 result.merge({"version":1,"role":kind,"variant":variant,"factor":factor,"seed":seed_value,"palette":palette,"height":snappedf(dimensions.y*float(base.scale)*factor,.001),"width":snappedf(dimensions.x*float(base.scale)*factor,.001),"length":snappedf(dimensions.z*float(base.scale)*factor,.001),"speed":snappedf(float(rule.speed)/sqrt(factor),.001)})
 if _picks.size()>256:_picks.clear()
 _picks[cache]=result;return result.duplicate(true)
static func look(native: Dictionary) -> Dictionary:
 var result:=FrontierEcologyCatalog.look(native.form_id,native.look_id).duplicate(true)
 result.scale=float(result.scale)*float(native.factor);result.palette=native.palette.duplicate();return result
static func title(native: Dictionary) -> String:
 return str(config().variants[native.variant].name)+" · "+str(FrontierEcologyCatalog.form(native.form_id).name)
static func reward(row: Dictionary) -> Dictionary:
 if not row.has("native"):return FrontierExplorationIncidents.definition(row.template).reward
 var native: Dictionary=row.native;var result: Dictionary={}
 for resource in config().roles[native.role].reward:
  result[resource]=maxi(1,roundi(float(config().roles[native.role].reward[resource])*float(config().variants[native.variant].reward)))
 return result
static func radius(native: Dictionary) -> float:return maxf(maxf(float(native.width),float(native.length))*.45,.45)
static func walkable_surface(row: Dictionary,f: FrontierTerrainField) -> bool:
 var native: Dictionary=row.native;var reach:=radius(native)
 var tolerance:=maxf(.6,float(native.height)*.22)
 for point_value in row.path:
  var p:=FrontierCrewWorld.vector(point_value)
  if FrontierSurfaceDrainage.liquid(f.traits) and p.y< -2.5:return false
  for offset in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
   var q: Vector3=p+offset*reach
   if absf(f.height(q.x,q.z)-p.y)>tolerance:return false
 return true
static func path_length(row: Dictionary) -> float:
 var distance:=0.0
 for i in range(1,row.path.size()):distance+=FrontierCrewWorld.vector(row.path[i-1]).distance_to(FrontierCrewWorld.vector(row.path[i]))
 return distance
static func position(row: Dictionary) -> Vector3:
 var distance:=float(row.get("native_distance",0))
 for i in range(1,row.path.size()):
  var a:=FrontierCrewWorld.vector(row.path[i-1]);var b:=FrontierCrewWorld.vector(row.path[i]);var segment:=a.distance_to(b)
  if distance<=segment:return a.lerp(b,clampf(distance/maxf(.001,segment),0,1))
  distance-=segment
 return FrontierCrewWorld.vector(row.path.back()) if not row.path.is_empty() else FrontierCrewWorld.vector(row.position)
static func initialize(row: Dictionary) -> void:
 row.native_observed=false;row.native_distance=0.0 if row.native.role=="guardian" else path_length(row);row.native_forward=false;row.native_alert=0.0;row.native_attack=0;row.native_wait=0.0;row.native_walked=0.0
static func tick(world: Dictionary,row: Dictionary,present: Array,delta: float,f: FrontierTerrainField) -> bool:
 var native: Dictionary=row.native;var at:=position(row);var nearest:=INF;var closest: String=""
 for actor in present:
  var p:=FrontierCrewWorld.vector(world.crew.members[actor].position)
  var distance:=p.distance_to(at)
  if distance<nearest and FrontierCrewSurface.visible_in_field(f,at+Vector3.UP*float(native.height)*.5,p+Vector3.UP):nearest=distance;closest=actor
 var changed:=false
 row.native_wait=maxf(0,float(row.native_wait)-delta)
 var danger:=radius(native)+float(config().retreat_distance)
 if native.role=="guardian" and not row.native_observed and nearest<danger:
  if row.native_alert==0:row.serial+=1;changed=true
  row.native_alert+=delta
  if row.native_alert>=float(config().guard_warning) and row.native_wait<=0 and closest!="":
   # Warning precedes the host-confirmed defensive hit; leaving its reach avoids damage.
   if nearest<radius(native)+1.6:FrontierExplorationIncidents.hurt(world,closest,float(config().guard_damage))
   row.native_attack+=1;row.native_wait=float(config().guard_cooldown);row.serial+=1;changed=true
 else:
  if row.native_alert>0:row.serial+=1;changed=true
  row.native_alert=0.0
 var walking: bool=row.native_observed or nearest<float(config().trigger_distance)+radius(native)
 if native.role=="guardian" and not row.native_observed:walking=false
 if row.native_wait>0 or not walking:return changed
 var total:=path_length(row);var before:=float(row.native_distance)
 var speed:=float(native.speed)*(1.6 if native.role=="rare" and nearest<danger else 1.0)
 row.native_distance=clampf(before+delta*speed*(1 if row.native_forward else -1),0,total)
 row.native_walked+=absf(float(row.native_distance)-before)
 if row.native_distance==0 or row.native_distance==total:
  row.native_forward=not row.native_forward;row.native_wait=2.0;row.serial+=1
 return changed or int(before/5.0)!=int(float(row.native_distance)/5.0)
static func available(row: Dictionary) -> bool:
 if not row.has("native"):return true
 if not row.native_observed:return false
 if row.native.role=="scavenger":return float(row.native_walked)>=path_length(row)*.65
 return position(row).distance_to(FrontierExplorationIncidents.cargo_point(row))>radius(row.native)+2.0
static func scan_target(world: Dictionary,actor: String,aim: Vector3) -> Dictionary:
 var origin:=FrontierCrewWorld.vector(world.crew.members[actor].position)+Vector3.UP*1.72
 var nearest:=INF;var selected: Dictionary={}
 for id in FrontierExplorationIncidents.records(world):
  var row: Dictionary=world.incidents.records[id]
  if not row.has("native") or row.claimed or not FrontierExplorationIncidents.is_present(world,actor,row):continue
  var center:=position(row)+Vector3.UP*float(row.native.height)*.5;var delta:=center-origin
  if delta.dot(aim)<=0 or delta.length()>float(FrontierEcologyCatalog.config().scan_range)+radius(row.native) or delta.length()>nearest or (delta-aim*delta.dot(aim)).length()>radius(row.native):continue
  if not FrontierCrewSurface.visible_in_field(FrontierCrewSurface.field(FrontierShuttles.context(world,actor)),origin,center):continue
  if row.native.role in ["guardian","rare"] and delta.length()<radius(row.native)+float(config().retreat_distance):continue
  selected={"kind":"native_incident","id":id,"point":center,"form_id":row.native.form_id,"look_id":row.native.look_id};nearest=delta.length()
 return selected
static func observe(world: Dictionary,id: String) -> void:
 var row: Dictionary=world.incidents.records[id]
 if row.native_observed:return
 row.native_observed=true;row.native_alert=0.0;row.serial+=1
 FrontierEcology.ensure_planet(world.ecology,FrontierUniverse.body_from_id(world.manifest,row.body_id))
 # Record the native lineage, keeping its event-specific size/pigment in the incident.
 FrontierEcology.scan(world.ecology,row.body_id,{"form_id":row.native.form_id,"look_id":row.native.look_id})
static func info(world: Dictionary,target: Dictionary) -> Dictionary:
 var row: Dictionary=world.incidents.records[target.id]
 return {"kind":"native_incident","name":title(row.native),"subtitle":"현지 서식종 · %.2fm · 기본 개체의 %.0f%%"%[float(row.native.height),float(row.native.factor)*100],"icon":FrontierResourceIcons.specimen_id(FrontierEcologyCatalog.form(row.native.form_id)),"action":"분석 완료 · 생물과 거리를 두고 탈락물/은닉품 회수" if row.native_observed else "E 유지 · 현지 특이 개체 분석","id":target.id,"point":FrontierExplorationIncidents.array(target.point),"notes":[],"condition":FrontierExplorationIncidents.definition(row.template).hint}
static func validate(world: Dictionary,row: Dictionary) -> bool:
 if not row.has("native"):return FrontierExplorationIncidents.definition(row.template).mode!="native"
 if not row.native is Dictionary or role(row.template).is_empty():return false
 var expected:=choose(FrontierUniverse.body_from_id(world.manifest,row.body_id),row)
 if expected.is_empty() or JSON.parse_string(JSON.stringify(expected))!=JSON.parse_string(JSON.stringify(row.native)):return false
 for id in ["native_distance","native_alert","native_wait","native_walked","native_attack"]:
  if not FrontierUniverse._finite(row.get(id),0,9007199254740000):return false
 return row.get("native_observed") is bool and row.get("native_forward") is bool and float(row.native_distance)<=path_length(row)+.01

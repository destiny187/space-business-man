extends RefCounted
## A distress variant of the existing crew-space encounter, followed by a saved landing site.
static func begin(world: Dictionary,e: Dictionary) -> void:
 if e.carrier!="crew" or FrontierSpaceCombat.tier(world,int(e.system))<3:return
 var seed_value:=FrontierUniverse.derive(int(world.manifest.seed),"rescue:"+str(e.id))
 if seed_value%3!=0:return
 var origin:=FrontierSpaceCombat.point(e.origin);var heading:=FrontierSpaceCombat.point(e.heading)
 var side:=heading.cross(Vector3.UP).normalized()
 if side.length()<.1:side=Vector3.RIGHT
 var ship_point:=origin+heading*170+side*180
 if not FrontierSpaceCombat.clear_position(world,int(e.system),ship_point,70):return
 var start:=FrontierUniverse.first_ordinal(world.manifest,int(e.system))
 for i in FrontierUniverse.body_count(world.manifest,int(e.system)):
  var body:=FrontierUniverse.body(world.manifest,start+i)
  if not FrontierUniverse.landable(body) or int(body.planet_tier)<3:continue
  var f:=FrontierExplorationIncidents.field(body)
  for attempt in 4:
   var cell:=Vector2i(1+int((seed_value+attempt)%4),1+int((seed_value/7+attempt)%4))
   var occupied:=FrontierExplorationIncidents.tile(body,f,cell).duplicate()
   for existing in FrontierExplorationIncidents.records(world).values():
    if existing.body_id==body.id:occupied.append(existing)
   var rows:=FrontierActiveMissions.spawn(body,f,cell,occupied,"freighter_rescue_chain")
   if rows.is_empty():continue
   var row: Dictionary=rows[0];row.id+="/"+str(e.id);row.mission.rescue_id=e.id
   var blocked:=false
   for building in world.get("business",{}).get("sites",{}).get(body.id,{}).get("buildings",{}).values():
    if FrontierCrewWorld.vector(building.position).distance_to(FrontierCrewWorld.vector(row.position))<100:blocked=true;break
   if blocked:continue
   e.rescue={"position":FrontierSpaceCombat.arr(ship_point),"body_id":body.id,"ordinal":start+i,"site":row}
   return
static func finish(world: Dictionary,e: Dictionary,outcome: String) -> void:
 if not e.has("rescue") or outcome!="victory":return
 var source: Dictionary=e.rescue.site;var id:=FrontierExplorationIncidents.key(source)
 FrontierExplorationIncidents.ensure(world)
 if FrontierExplorationIncidents.records(world).has(id):return
 var row:=FrontierExplorationIncidents.create(source,int(world.manifest.seed));row.seen=true;row.discoverer=world.crew.pilot_id
 world.incidents.records[id]=row
static func valid(e: Dictionary) -> bool:
 if not e.has("rescue"):return true
 var r: Variant=e.rescue
 return r is Dictionary and FrontierUniverse._vector3_array(r.get("position")) and r.get("body_id") is String and FrontierExpeditionBusiness.integer(r.get("ordinal"),0,999999) and r.get("site") is Dictionary and FrontierActiveMissions.validate(r.site)

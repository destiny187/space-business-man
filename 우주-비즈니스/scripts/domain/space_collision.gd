class_name FrontierSpaceCollision
extends RefCounted
## Local host-only swept hull contacts. No world draft, mesh loading or save per pair.
static func config() -> Dictionary:return FrontierSpaceCombat.config().collision
static func shape(kind: String) -> Dictionary:return config().hulls.get(kind,config().hulls.kestrel)
static func drift(row: Dictionary) -> Vector3:return FrontierSpaceCombat.point(row.get("impact_velocity",[0,0,0]))
static func contact(a: Vector3,b: Vector3,da: Vector3,db: Vector3,radius: float) -> float:
 var offset:=a-b;var shift:=da-db;var c:=offset.length_squared()-radius*radius
 if c<=0:return 0.0
 var aa:=shift.length_squared();var bb:=offset.dot(shift)
 if aa<.000001 or bb>=0:return -1.0
 var disc:=bb*bb-aa*c
 if disc<0:return -1.0
 var t:=(-bb-sqrt(disc))/aa
 return t if t>=0 and t<=1 else -1.0
static func body(id: String,row: Dictionary,kind: String,start: Vector3,velocity: Vector3,player: bool) -> Dictionary:
 var def:=shape(kind);var offset:=FrontierCrewNavigation.orientation(row)*FrontierSpaceCombat.point(def.center)
 return {"id":id,"row":row,"system":int(row.get("system",-1)),"kind":kind,"player":player,"offset":offset,"start":start+offset,"end":FrontierSpaceCombat.point(row.position)+offset,"velocity":velocity,"mass":float(def.mass),"radius":float(def.radius),"touched":false}
static func step(world: Dictionary,delta: float,starts: Dictionary) -> bool:
 var r:=FrontierSpaceCombat.record(world);var e: Dictionary=r.encounter
 var bodies: Array[Dictionary]=[]
 var ids: Array=["crew"]
 for actor in world.crew.get("shuttles",{}):
  if world.crew.shuttles[actor].state=="sortie":ids.append("shuttle:"+str(actor))
 for id in ids:
  var local:=FrontierSpaceCombat.local_world(world,id);var nav: Dictionary=local.crew.navigation
  if nav.mode!="idle" or FrontierCrewSurface.landed(local) or nav.has("station_docked") or FrontierSolarOpening.active(nav) or nav.get("combat_recovery",false):continue
  var v:=FrontierSpaceCombat.point(nav.direction)*float(nav.speed)+drift(nav)
  var start: Vector3=starts.get(id,FrontierSpaceCombat.point(nav.position))
  bodies.append(body(id,nav,"finch" if id!="crew" else str(world.get("vessel",{}).get("hull","kestrel")),start,v,true))
 for enemy in e.get("enemies",[]):
  if enemy.hull<=0 or e.phase not in ["warning","combat"]:continue
  var enemy_body:=body(str(enemy.id),enemy,str(enemy.kind),starts.get(str(enemy.id),FrontierSpaceCombat.point(enemy.position)),FrontierSpaceCombat.point(enemy.get("velocity",[0,0,0])),false)
  enemy_body.system=int(e.system);bodies.append(enemy_body)
 var damaged:=false
 var previous: Dictionary=r.get("hull_contacts",{});var active: Dictionary={}
 # Earliest swept contact first. Follow-up overlap resolution handles a compact multi-craft pile-up.
 var pairs: Array=[]
 for i in bodies.size():
  for j in range(i+1,bodies.size()):
   var a: Dictionary=bodies[i];var b: Dictionary=bodies[j]
   if a.system!=b.system:continue
   var t:=contact(a.start,b.start,Vector3(a.end)-Vector3(a.start),Vector3(b.end)-Vector3(b.start),a.radius+b.radius)
   if t>=0:pairs.append({"a":i,"b":j,"time":t})
 pairs.sort_custom(func(a,b):return a.time<b.time)
 for pair in pairs:
  var a: Dictionary=bodies[pair.a];var b: Dictionary=bodies[pair.b]
  var t:=contact(a.start,b.start,Vector3(a.end)-Vector3(a.start),Vector3(b.end)-Vector3(b.start),a.radius+b.radius)
  if t<0:continue
  var pa: Vector3=Vector3(a.start).lerp(a.end,t);var pb: Vector3=Vector3(b.start).lerp(b.end,t)
  var normal: Vector3=(pa-pb).normalized()
  if normal.length_squared()<.5:normal=Vector3.RIGHT
  var closing:=maxf(0,-(Vector3(a.velocity)-Vector3(b.velocity)).dot(normal))
  var inverse: float=1.0/a.mass+1.0/b.mass
  var impulse: float=(1+float(config().restitution))*closing/inverse
  a.velocity+=normal*impulse/a.mass;b.velocity-=normal*impulse/b.mass
  var depth:=maxf(0,float(a.radius+b.radius)-pa.distance_to(pb))+float(config().skin)
  pa+=normal*depth/(a.mass*inverse);pb-=normal*depth/(b.mass*inverse)
  # Resolve at contact, then carry both craft with their post-impact velocity.
  a.end=pa+Vector3(a.velocity)*delta*(1-t);b.end=pb+Vector3(b.velocity)*delta*(1-t)
  a.start=pa;b.start=pb;a.touched=true;b.touched=true
  var key:=str(a.id)+"|"+str(b.id);active[key]=true
  if closing>float(config().damage_threshold) and not previous.has(key):
   var loss: float=.5*(1.0-float(config().restitution)*float(config().restitution))*closing*closing/inverse
   var damage_a:=minf(float(config().maximum_damage),loss/a.mass*float(config().damage_scale))
   var damage_b:=minf(float(config().maximum_damage),loss/b.mass*float(config().damage_scale))
   apply_damage(world,a,damage_a,pb);apply_damage(world,b,damage_b,pa);damaged=true
   FrontierSpaceCombat.emit(r,"collision",int(a.system),pa,pb,str(a.id)+"|"+str(b.id))
 for iteration in 6:
  for i in bodies.size():
   for j in range(i+1,bodies.size()):
    var a: Dictionary=bodies[i];var b: Dictionary=bodies[j];var d: Vector3=a.end-b.end
    if a.system!=b.system:continue
    var depth: float=a.radius+b.radius+float(config().skin)-d.length()
    if depth<=0:continue
    var n:=d.normalized() if d.length()>.001 else Vector3.RIGHT
    var inverse: float=1/a.mass+1/b.mass
    a.end+=n*depth/(a.mass*inverse);b.end-=n*depth/(b.mass*inverse);a.touched=true;b.touched=true
    active[str(a.id)+"|"+str(b.id)]=true
 # Keep a contact latched until actual separation, preventing repeated damage at rest.
 for i in bodies.size():
  for j in range(i+1,bodies.size()):
   var a: Dictionary=bodies[i];var b: Dictionary=bodies[j];var key:=str(a.id)+"|"+str(b.id)
   if a.system==b.system and previous.has(key) and Vector3(a.end).distance_to(b.end)<float(a.radius+b.radius)+2:active[key]=true
 r.hull_contacts=active
 for b in bodies:
  if not b.touched:continue
  var row: Dictionary=b.row
  var p: Vector3=b.end-b.offset
  # Celestial geometry remains a blocker for collision displacement too.
  var old:=FrontierSpaceCombat.point(row.position);var shift:=p-old
  if not FrontierSpaceCombat.clear_position(world,int(b.system),p,float(b.radius)) or (shift.length()>.001 and FrontierSpaceCombat.blocked_distance(world,int(b.system),old,shift.normalized(),shift.length()+float(b.radius))<shift.length()+float(b.radius)):
   p=Vector3(b.start)-Vector3(b.offset)
  row.position=FrontierSpaceCombat.arr(p)
  row.contact_serial=int(row.get("contact_serial",0))+1
  if b.player:
   var facing:=FrontierSpaceCombat.point(row.direction)
   row.speed=maxf(0,Vector3(b.velocity).dot(facing))
   row.impact_velocity=FrontierSpaceCombat.arr(Vector3(b.velocity)-facing*float(row.speed))
   if row.get("impact_recovery_left",0)>0:row.speed=0;row.impact_velocity=[0,0,0]
   var local:=FrontierSpaceCombat.local_world(world,b.id);local.crew.navigation=row;local.flight_position=row.position.duplicate();FrontierSpaceCombat.commit(world,local,b.id)
   if r.flights.has(b.id):r.flights[b.id].position=row.position.duplicate()
  else:
   row.impact_velocity=FrontierSpaceCombat.arr(drift(row)+Vector3(b.velocity)-FrontierSpaceCombat.point(row.get("velocity",[0,0,0])))
   row.velocity=FrontierSpaceCombat.arr(b.velocity)
 return damaged
static func apply_damage(world: Dictionary,b: Dictionary,amount: float,source: Vector3) -> void:
 if b.player:
  FrontierSpaceCombat.damage_ship(world,b.id,amount,source)
  b.row.hull=FrontierSpaceCombat.local_world(world,b.id).crew.navigation.hull
  if b.row.hull<=0 and not FrontierSpaceCombat.engagement(world,b.id):
   b.row.impact_recovery_left=float(FrontierSpaceCombat.config().recovery_seconds);b.row.combat_recovery=true
 else:FrontierSpaceCombat.damage_enemy(world,b.row,amount,source,Vector3(b.end)-Vector3(b.offset))

static func valid_motion(row: Dictionary) -> bool:
 if row.has("impact_velocity") and (not FrontierUniverse._vector3_array(row.impact_velocity) or FrontierSpaceCombat.point(row.impact_velocity).length()>20000):return false
 if not FrontierUniverse._finite(row.get("impact_recovery_left",0),0,60):return false
 return FrontierExpeditionBusiness.integer(row.get("contact_serial",0),0,9007199254740000)

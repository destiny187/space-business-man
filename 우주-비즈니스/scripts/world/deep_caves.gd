extends RefCounted
## A separately seeded descent preserves the shallow graph. Density bins bound per-sample work.
const BIN=24.0
static func build(system: Dictionary,key: Vector2i,rules: Dictionary,surface: Callable,seed_value: int) -> Dictionary:
 if not rules.has("deep") or system.nodes.is_empty():return {}
 var cfg:Dictionary=rules.deep
 if FrontierUniverse.derive(seed_value,"deep-cave-v1:"+str(key))%10000>=int(float(cfg.occupancy)*10000):return {}
 var first:Vector3=system.nodes[0];var last:Vector3=system.nodes[-1]
 var direction:=Vector3(last.x-first.x,0,last.z-first.z).normalized();var side:=Vector3(-direction.z,0,direction.x)
 var origin:=Vector3(key.x*float(rules.region_size),0,key.y*float(rules.region_size))
 var center:=origin+direction*100+side*30
 var previous:=last-Vector3.UP*float(system.floor_offset)
 var result:Dictionary={"segments":[],"bins":{},"nodes":[previous],"floor":Vector3.ZERO,"rules":cfg}
 var target:=center+direction*float(cfg.radius);target.y=previous.y-Vector2(target.x-previous.x,target.z-previous.z).length()*.14
 result.segments.append({"a":previous,"b":target});result.nodes.append(target);previous=target
 for i in range(1,int(cfg.segments)+1):
  var angle:=float(i)*TAU/16.0
  var next:=center+(direction*cos(angle)+side*sin(angle))*float(cfg.radius)
  next.y=target.y-float(i)*float(cfg.drop_per_segment)
  result.segments.append({"a":previous,"b":next});result.nodes.append(next);previous=next
 # Reject a deep branch that would expose the surface, leave its owner, or approach bedrock.
 var checks:Array=result.nodes.duplicate()
 for segment in result.segments:
  for i in range(1,9):checks.append(segment.a.lerp(segment.b,float(i)/9.0))
 for p in checks:
  var depth:float=float(surface.call(p.x,p.z))-p.y
  if depth<12 or depth>float(cfg.maximum_floor_depth):return {}
  if maxf(absf(p.x-origin.x),absf(p.z-origin.z))>float(rules.region_size)*.5-30:return {}
 var final_depth:float=float(surface.call(previous.x,previous.z))-previous.y
 if final_depth<float(cfg.minimum_floor_depth):return {}
 result.floor=previous
 for segment in result.segments:
  var lo:Vector3=segment.a.min(segment.b)-Vector3(float(cfg.width)+1,1,float(cfg.width)+1)
  var hi:Vector3=segment.a.max(segment.b)+Vector3(float(cfg.width)+1,float(cfg.floor_offset)+float(cfg.width)*float(cfg.ceiling)+1,float(cfg.width)+1)
  insert(result,lo,hi,{"kind":"segment","segment":segment})
 var r:float=cfg.room_radius
 insert(result,previous-Vector3(r,1,r),previous+Vector3(r,r*.7+6,r),{"kind":"room"})
 return result
static func insert(result:Dictionary,lo:Vector3,hi:Vector3,item:Dictionary)->void:
 var a:Vector3i=(lo/BIN).floor();var b:Vector3i=(hi/BIN).floor()
 for x in range(a.x,b.x+1):
  for y in range(a.y,b.y+1):
   for z in range(a.z,b.z+1):
    var key:=Vector3i(x,y,z)
    if not result.bins.has(key):result.bins[key]=[]
    result.bins[key].append(item)
static func density(deep:Dictionary,p:Vector3)->float:
 if deep.is_empty():return INF
 var key:Vector3i=(p/BIN).floor();var value:=INF;var cfg:Dictionary=deep.rules
 var items:Array=deep.bins.get(key,[])
 if items.is_empty():return INF
 var room:=false
 for item in items:
  if item.kind=="room":
   room=true
   var offset:Vector3=p-deep.floor-Vector3.UP*6;offset.y/=.7
   value=minf(value,maxf(offset.length()-float(cfg.room_radius),float(deep.floor.y)-p.y))
  else:
   var segment:Dictionary=item.segment;var flat:=Vector3(segment.b.x-segment.a.x,0,segment.b.z-segment.a.z)
   var t:float=Vector3(p.x-segment.a.x,0,p.z-segment.a.z).dot(flat)/flat.length_squared()
   var center:Vector3=segment.a.lerp(segment.b,clampf(t,0,1))
   var floor_y:float=lerpf(segment.a.y,segment.b.y,t)
   var offset:=p-Vector3(center.x,floor_y+float(cfg.floor_offset),center.z);offset.y/=float(cfg.ceiling)
   value=minf(value,maxf(offset.length()-float(cfg.width),floor_y-p.y))
 if room:
  var floor_y:float=deep.floor.y;var closest:=INF
  for item in items:
   if item.kind!="segment":continue
   var segment:Dictionary=item.segment;var flat:=Vector3(segment.b.x-segment.a.x,0,segment.b.z-segment.a.z)
   var t:float=clampf(Vector3(p.x-segment.a.x,0,p.z-segment.a.z).dot(flat)/flat.length_squared(),0,1)
   var near:Vector3=segment.a.lerp(segment.b,t)
   var distance:=Vector2(p.x-near.x,p.z-near.z).length()
   if distance<closest:
    closest=distance;floor_y=lerpf(float(deep.floor.y),near.y,1-smoothstep(float(cfg.width)*.6,float(cfg.width)+1,distance))
  value=maxf(value,floor_y-p.y)
 return value

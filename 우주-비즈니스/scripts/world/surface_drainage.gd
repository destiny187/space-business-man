class_name FrontierSurfaceDrainage
extends RefCounted
## Deterministic downhill drainage over the unchanged saved terrain field.
## Water surfaces have no solid collision; terrain, caves and edits stay authoritative.
static func liquid(traits: Dictionary) -> bool:
 return float(traits.get("water",0))>15 and float(traits.get("pressure",0))>.08 and float(traits.get("temperature",-100))>0 and float(traits.get("temperature",100))<100
static func source(field: FrontierTerrainField,key: Vector2i,index: int,cfg: Dictionary) -> Vector3:
 var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(field.seed_value,"drainage-v1:%d:%d:%d"%[key.x,key.y,index])
 var best:=Vector3(0,-INF,0)
 for i in 8:
  var q:=Vector3((key.x+rng.randf())*float(cfg.tile_size),0,(key.y+rng.randf())*float(cfg.tile_size));q.x=snappedf(q.x,float(cfg.step_meters));q.z=snappedf(q.z,float(cfg.step_meters));q.y=field.height(q.x,q.z)
  if q.y>best.y and Vector2(q.x,q.z).length()>75:best=q
 return best
static func advance(field: FrontierTerrainField,at: Vector3,cfg: Dictionary) -> Vector3:
 var step_value:=float(cfg.step_meters)
 var dx:=field.height(at.x+step_value,at.z)-field.height(at.x-step_value,at.z)
 var dz:=field.height(at.x,at.z+step_value)-field.height(at.x,at.z-step_value)
 var downhill:=Vector3(-dx,0,-dz).normalized()
 if downhill.length_squared()>.5:
  var q:=at+downhill*step_value;q.y=field.height(q.x,q.z)
  if q.y<at.y-.002:return q
 var best:=at;var slope:=0.0
 for i in 8:
  var direction:=Vector2(cos(i*TAU/8.0),sin(i*TAU/8.0))
  var q:=at+Vector3(direction.x,0,direction.y)*step_value;q.y=field.height(q.x,q.z)
  var drop: float=at.y-q.y
  if drop>slope+.002:best=q;slope=drop
 return best
static func section(field: FrontierTerrainField,at: Vector3,direction: Vector3,level: float,cfg: Dictionary) -> PackedVector3Array:
 var side:=Vector3(-direction.z,0,direction.x).normalized()
 if side.length_squared()<.5:side=Vector3.RIGHT
 var edge:=PackedVector3Array()
 for sign_value in [-1.0,1.0]:
  var width:=.15
  for i in 8:
   var distance_value:=float(cfg.river_half_width)*(i+1)/8.0
   var p: Vector3=at+side*distance_value*float(sign_value)
   if field.height(p.x,p.z)>level:break
   width=distance_value
  edge.append(Vector3(at.x,level,at.z)+side*width*sign_value)
 return edge

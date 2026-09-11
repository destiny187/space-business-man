extends RefCounted
const Bounds=preload("res://scripts/domain/surface_content_bounds.gd")
static var cached: Dictionary={}
static func config() -> Dictionary:
 if cached.is_empty():cached=JSON.parse_string(FileAccess.get_file_as_string("res://data/remote_incidents.json"))
 return cached
static func spawn(body: Dictionary,f: FrontierTerrainField,cell: Vector2i,occupied: Array) -> Dictionary:
 var cfg:=config();var span:float=FrontierExplorationIncidents.config().tile_size
 var lower:float=cfg.legacy_extent;var limit:=Bounds.extent(body)-float(cfg.boundary_margin)
 var lo:=Vector2(cell.x*span,cell.y*span);var hi:=lo+Vector2.ONE*span
 if limit<=lower or maxf(maxf(absf(lo.x),absf(hi.x)),maxf(absf(lo.y),absf(hi.y)))<=lower:return {}
 if lo.x>limit or hi.x< -limit or lo.y>limit or hi.y< -limit:return {}
 var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(body.streams.discovery),"remote-incidents-v1:"+str(cell))
 if rng.randf()>float(cfg.chance):return {}
 var pool:Array=[]
 for id in cfg.templates:
  if int(FrontierExplorationIncidents.definition(id).tier)<=int(body.planet_tier):pool.append(id)
 if pool.is_empty():return {}
 var template:String=pool[rng.randi()%pool.size()]
 for attempt in 56:
  var at:=Vector3(rng.randf_range(maxf(lo.x,-limit),minf(hi.x,limit)),0,rng.randf_range(maxf(lo.y,-limit),minf(hi.y,limit)))
  if maxf(absf(at.x),absf(at.z))<=lower:continue
  at.y=f.height(at.x,at.z)
  if FrontierSurfaceDrainage.liquid(f.traits) and at.y< -2.5:continue
  if occupied.any(func(row):return FrontierCrewWorld.vector(row.position).distance_to(at)<120):continue
  var yaw:=rng.randf()*TAU;var flat:=true
  for offset in [Vector3(0,0,8),Vector3(0,0,-8),Vector3(6,0,0),Vector3(-6,0,0)]:
   var p:Vector3=at+offset.rotated(Vector3.UP,yaw)
   if absf(f.height(p.x,p.z)-at.y)>1.2:flat=false;break
  if not flat:continue
  var row:Dictionary={"id":"incident:%d:%d:remote_%s"%[cell.x,cell.y,template],"template":template,"body_id":body.id,"position":FrontierExplorationIncidents.array(at),"yaw":yaw,"tier":int(body.planet_tier),"path":[]}
  var relay:=FrontierExplorationIncidents.point(row,Vector3(0,0,55));relay.y=f.height(relay.x,relay.z)
  var battery:=FrontierExplorationIncidents.point(row,Vector3(28,0,16));battery.y=f.height(battery.x,battery.z)
  row.relay=FrontierExplorationIncidents.array(relay);row.battery_position=FrontierExplorationIncidents.array(battery)
  for i in 13:
   var p:Vector3=at.lerp(relay,float(i)/12);p.y=f.height(p.x,p.z)+.35;row.path.append(FrontierExplorationIncidents.array(p))
  return row
 return {}

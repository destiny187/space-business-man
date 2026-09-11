extends RefCounted
static var cached: Dictionary={}
static func config() -> Dictionary:
 if cached.is_empty():cached=JSON.parse_string(FileAccess.get_file_as_string("res://data/storm_archive.json"))
 return cached
static func enabled(row: Dictionary) -> bool:return row.get("template")==config().id
static func grounded(row: Dictionary) -> bool:return row.get("powered",false) and row.get("battery_installed",false)
static func phase(row: Dictionary) -> String:
 if grounded(row) or row.get("claimed",false):return "grounded"
 var t:=fposmod(float(row.age),float(config().period))
 if t>=float(config().strike_at) and t<float(config().strike_at)+float(config().strike_seconds):return "strike"
 return "warning" if t>=float(config().warning_start) and t<float(config().strike_at) else "calm"
static func spawn(body: Dictionary,f: FrontierTerrainField,cell: Vector2i,occupied: Array) -> Dictionary:
 if int(body.planet_tier)<3:return {}
 var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(body.streams.discovery),"storm-archive-v1:"+str(cell))
 if rng.randf()>float(config().tile_chance):return {}
 var span: float=FrontierExplorationIncidents.config().tile_size
 for attempt in 28:
  var at:=Vector3((cell.x+rng.randf_range(.15,.85))*span,0,(cell.y+rng.randf_range(.15,.85))*span);at.y=f.height(at.x,at.z)
  if Vector2(at.x,at.z).length()<110 or maxf(absf(at.x),absf(at.z))>8000:continue
  if FrontierSurfaceDrainage.liquid(f.traits) and at.y< -2.5:continue
  if occupied.any(func(row):return at.distance_to(FrontierCrewWorld.vector(row.position))<120):continue
  var yaw:=rng.randf()*TAU;var flat:=true
  for offset in [Vector3(0,0,8),Vector3(0,0,-8),Vector3(6,0,0),Vector3(-6,0,0)]:
   var p: Vector3=at+offset.rotated(Vector3.UP,yaw)
   if absf(f.height(p.x,p.z)-at.y)>1.2:flat=false;break
  if not flat:continue
  var row:Dictionary={"id":"incident:%d:%d:%s"%[cell.x,cell.y,config().id],"template":config().id,"body_id":body.id,"position":FrontierExplorationIncidents.array(at),"yaw":yaw,"tier":int(body.planet_tier),"path":[]}
  var relay:=FrontierExplorationIncidents.point(row,Vector3(0,0,55));relay.y=f.height(relay.x,relay.z)
  var battery:=FrontierExplorationIncidents.point(row,Vector3(28,0,16));battery.y=f.height(battery.x,battery.z)
  row.relay=FrontierExplorationIncidents.array(relay);row.battery_position=FrontierExplorationIncidents.array(battery)
  return row
 return {}
static func sheltered(row: Dictionary,at: Vector3) -> bool:
 # The intact authored wreck roof covers its rear cargo compartment.
 var p: Vector3=(at-FrontierCrewWorld.vector(row.position)).rotated(Vector3.UP,-float(row.yaw))
 return AABB(FrontierCrewWorld.vector(config().roof_min),FrontierCrewWorld.vector(config().roof_max)-FrontierCrewWorld.vector(config().roof_min)).has_point(p)
static func tick(world: Dictionary,row: Dictionary,delta: float,present: Array,obstacle: Callable) -> bool:
 if not enabled(row) or grounded(row):return false
 var before: float=float(row.age)-delta;var after: float=row.age
 if floori((before-float(config().strike_at))/float(config().period))>=floori((after-float(config().strike_at))/float(config().period)):return false
 row.storm_strikes=int(row.get("storm_strikes",0))+1
 for actor in present:
  var at:=FrontierCrewWorld.vector(world.crew.members[actor].position)+Vector3.UP
  var offset:=at-FrontierCrewWorld.vector(row.position)
  if Vector2(offset.x,offset.z).length()>float(config().radius) or absf(offset.y)>8 or sheltered(row,at):continue
  if obstacle.is_valid() and float(obstacle.call(actor,at,Vector3.UP,30.0))<29.5:continue
  FrontierExplorationIncidents.hurt(world,actor,float(config().damage),"blast")
 return true
static func blueprint(world: Dictionary,row: Dictionary) -> String:
 var options: Array=config().blueprints
 return options[FrontierUniverse.derive(int(world.manifest.seed),"storm-blueprint:"+FrontierExplorationIncidents.key(row))%options.size()]
static func recover(world: Dictionary,actor: String,row: Dictionary) -> String:
 var id:=blueprint(world,row);var duplicate:=FrontierFacilityBlueprints.owned(world,id)
 if duplicate:
  var error:=FrontierExplorationIncidents.reward(world,actor,config().duplicate_reward)
  if not error.is_empty():return error
 elif not FrontierFacilityBlueprints.register(world,id,"exploration",FrontierExplorationIncidents.key(row)):return "복원한 연구선의 설계도를 등록하지 못했습니다."
 row.blueprint=id;row.blueprint_duplicate=duplicate
 return ""
static func validate(world: Dictionary,row: Dictionary) -> bool:
 if not enabled(row):return true
 if int(row.tier)<3 or not FrontierExpeditionBusiness.integer(row.get("storm_strikes",0),0,1000000000000):return false
 if row.has("blueprint"):
  return row.claimed and row.blueprint==blueprint(world,row) and row.get("blueprint_duplicate") is bool and FrontierFacilityBlueprints.owned(world,row.blueprint)
 return not row.claimed

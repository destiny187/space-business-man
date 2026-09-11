extends RefCounted
## Seeded short routes use the same terrain and clock for presentation and host scans.
## The cache contains derived routes only; no ancestry or save state is changed.
static var _config: Dictionary={}
static var routes: Dictionary={}
const CACHE_LIMIT:=256
static func config()->Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/wildlife_behavior.json"))
 return _config
static func eligible(form: Dictionary,candidate: Dictionary)->bool:
 return form.get("category")=="animal" and FrontierEcologyCatalog.ground_form(form) and form.get("locomotion_medium","") not in ["surface_air","atmosphere"] and not candidate.get("introduced",false)
static func route(field: FrontierTerrainField,row: Dictionary,home: Vector3)->Array[Vector3]:
 var key:=str(field.get_instance_id())+":"+str(field.revision)+":"+str(row.id)+":"+str(row.look_id)+":"+str(home)
 if routes.has(key):return routes[key]
 var cfg:=config()
 var group: String=str(row.form_id)+":"+str(floori(home.x/float(cfg.group_span)))+":"+str(floori(home.z/float(cfg.group_span)))
 var heading: float=float(FrontierUniverse.derive(field.seed_value,"herd:"+group)%10000)/10000.0*TAU
 var best: Array[Vector3]=[home]
 for turn in [0.0,PI*.5,-PI*.5,PI]:
  var points: Array[Vector3]=[home]
  var forward:=Vector3(sin(heading+turn),0,cos(heading+turn))
  var facing:=atan2(-forward.x,-forward.z)
  var start:=row.duplicate();start.yaw=facing
  if not FrontierEcologyPlacement.fits(field,start,home):continue
  for step in range(1,1+floori(float(cfg.route_length)/float(cfg.route_step))):
   var candidate:=row.duplicate();candidate.point=home+forward*float(step)*float(cfg.route_step);candidate.yaw=facing
   var at:=FrontierEcologyPlacement.ground(field,candidate)
   if not at.is_finite() or absf(at.y-points[-1].y)>float(cfg.maximum_step_height):break
   points.append(at)
  if points.size()>best.size():best=points
  if best.size()>1:break
 if routes.size()>=CACHE_LIMIT:routes.erase(routes.keys()[0])
 routes[key]=best
 return best
static func pose(field: FrontierTerrainField,row: Dictionary,home: Vector3,time: float,observers: Array[Vector3]=[],stopped: Dictionary={})->Dictionary:
 var normal:=field.normal(home)
 var result: Dictionary={"point":home,"basis":FrontierEcologyPlacement.surface_basis(normal,float(row.yaw)),"state":"idle","phase":"rest","alert":false,"clock":time}
 if not stopped.is_empty():
  var at:=FrontierCrewWorld.vector(stopped.position)
  result.point=at;result.basis=FrontierEcologyPlacement.surface_basis(field.normal(at),float(stopped.yaw))
  result.state="dormant";result.phase="incapacitated";return result
 var form:=FrontierEcologyCatalog.form(row.form_id)
 if not eligible(form,row) or row.get("status","active")!="active":
  if row.get("status")=="dormant":result.state="dormant"
  return result
 var cfg:=config()
 var walk: float=cfg.walk_seconds
 var cycle: float=walk*2+float(cfg.feed_seconds)+float(cfg.rest_seconds)
 var group: String=str(row.form_id)+":"+str(floori(home.x/float(cfg.group_span)))+":"+str(floori(home.z/float(cfg.group_span)))
 var clock: float=time+float(FrontierUniverse.derive(field.seed_value,"herd-clock:"+group)%10000)/10000.0*cycle
 var phase:=fposmod(clock,cycle)
 var points:=route(field,row,home)
 var fraction:=0.0;var forward:=true
 if phase<walk:
  fraction=smoothstep(0.0,walk,phase);result.state="move";result.phase="wander"
 elif phase<walk+float(cfg.feed_seconds):
  fraction=1.0;result.state="feed";result.phase="feed"
 elif phase<walk*2+float(cfg.feed_seconds):
  fraction=1.0-smoothstep(walk+float(cfg.feed_seconds),walk*2+float(cfg.feed_seconds),phase);forward=false;result.state="move";result.phase="wander"
 result.clock=clock
 if points.size()<2:
  result.state="feed" if result.state=="feed" else "idle";return result
 var axis: Vector3=(points[-1]-home).normalized()
 var current: Vector3=home.lerp(points[-1],fraction)
 var bias:=0.0
 for observer in observers:
  var distance:=observer.distance_to(current)
  if distance>=float(cfg.avoid_radius):continue
  var weight:=1.0-smoothstep(1.0,float(cfg.avoid_radius),distance)
  bias+=clampf((current-observer).dot(axis)/2.0,-1.0,1.0)*weight
  result.alert=true
 if result.alert:
  bias=clampf(bias,-1,1)*float(cfg.avoid_fraction)
  fraction=clampf(fraction+bias,0,1)
  forward=bias>=0
  result.state="move" if fraction>0.01 and fraction<.99 else "stressed"
  result.phase="avoid"
 var progress:=fraction*float(points.size()-1)
 var index:=mini(floori(progress),points.size()-2)
 var at: Vector3=points[index].lerp(points[index+1],progress-float(index))
 var direction: Vector3=(points[index+1]-points[index])*(1.0 if forward else -1.0)
 result.point=at
 result.basis=FrontierEcologyPlacement.surface_basis(field.normal(at),atan2(-direction.x,-direction.z))
 return result

static func observers(world: Dictionary,active: Dictionary,body_id: String)->Array[Vector3]:
 var result: Array[Vector3]=[]
 var ids: Array=active.values();ids.sort()
 for id in ids:
  if not world.crew.members.has(id):continue
  var member: Dictionary=world.crew.members[id]
  if member.area=="surface" and not member.aboard and FrontierShuttles.area_key(world,id)=="surface:"+body_id:result.append(FrontierCrewWorld.vector(member.position))
 return result

static func stopped(crew: Dictionary,body_id: String,row: Dictionary,home: Vector3)->Dictionary:
 var key:=body_id+"/"+str(row.id)
 if int(crew.get("combat",{}).get(key,1))!=0:return {}
 return crew.get("wildlife_stops",{}).get(key,{"position":[home.x,home.y,home.z],"yaw":float(row.yaw)})

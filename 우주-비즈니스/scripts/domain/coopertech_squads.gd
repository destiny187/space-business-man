class_name FrontierCooperTechSquads
extends RefCounted
## Independent encounter seed; original incident layout and recorded singleton IDs stay intact.
static var _config: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/coopertech_squads.json"))
 return _config
static func enabled(row: Dictionary) -> bool:return row.get("squad_version",0)==1
static func spec(row: Dictionary) -> Dictionary:
 var result: Dictionary=config().roles.get(row.get("robot_role","sentry"),config().roles.sentry).duplicate()
 var tier: Dictionary=config().tiers[str(int(row.tier))]
 for stat in ["health","damage","speed","shield"]:result[stat]=float(result[stat])*float(tier[stat])
 result.speed=minf(float(result.speed),float(result.stride)/float(result.gait_seconds)*float(result.max_gait_rate))
 result.aim_seconds*=float(tier.aim)
 return result
static func spawn(body: Dictionary,f: FrontierTerrainField,cell: Vector2i,existing: Array) -> Array:
 var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(body.streams.discovery),"coopertech-squad-v1:"+str(cell))
 if rng.randf()>float(config().tile_chance):return []
 var count:=int(config().tiers[str(int(body.planet_tier))].count)
 var span:=float(FrontierExplorationIncidents.config().tile_size)
 for attempt in 22:
  var center:=Vector3((cell.x+rng.randf_range(.12,.88))*span,0,(cell.y+rng.randf_range(.12,.88))*span);center.y=f.height(center.x,center.z)
  if Vector2(center.x,center.z).length()<150 or maxf(absf(center.x),absf(center.z))>7950:continue
  if existing.any(func(r):return FrontierCrewWorld.vector(r.position).distance_to(center)<115):continue
  var path: Array=[];var fits:=true
  for i in 13:
   var angle:=TAU*float(i)/12.0;var p:=center+Vector3(cos(angle)*16,0,sin(angle)*16);p.y=f.height(p.x,p.z)
   if (FrontierSurfaceDrainage.liquid(f.traits) and p.y< -2.5) or absf(p.y-center.y)>2.3:fits=false;break
   # Validate the actual traversal corridor, including between corners.
   if not path.is_empty():
    var previous:=FrontierCrewWorld.vector(path[-1])
    for j in range(1,9):
     var q:=previous.lerp(p,float(j)/8);var height:=f.height(q.x,q.z)
     if absf(height-q.y)>.5:fits=false;break
   path.append(FrontierExplorationIncidents.array(p))
  if not fits:continue
  var formation: Array=[];var start_mode: String="dormant" if rng.randf()<.5 else "patrol"
  var group_id: String="coopertech:%d:%d"%[cell.x,cell.y]
  var elite: String="bastion" if rng.randf()<.5 else "raptor"
  for i in count:
   var role: String=elite if i==0 else ("sentry" if i==1 else ("raptor" if i%2==0 else "bastion"))
   var index:=floori(float(i)*12/count);var p: Array=path[index].duplicate()
   var row: Dictionary={"squad_version":1,"squad_id":group_id,"robot_role":role,"start_mode":start_mode,"id":group_id+":"+str(i),"template":config().roles[role].template,"body_id":body.id,"position":p,"home":FrontierExplorationIncidents.array(center),"yaw":0.0,"tier":int(body.planet_tier),"relay":FrontierExplorationIncidents.array(center),"battery_position":p.duplicate(),"path":path.duplicate(true),"patrol_index":(index+1)%12}
   formation.append(row)
  return formation
 return []
static func initialize(row: Dictionary) -> void:
 var cfg:=spec(row)
 row.hp=float(cfg.health);row.hp_max=float(cfg.health);row.shield_max=float(cfg.shield);row.shield=row.shield_max
 row.phase="patrol" if row.start_mode=="patrol" else "idle";row.travel=0.0;row.burst=0;row.alarmed=false;row.attack_serial=0;row.shot_start=[];row.shot_end=[]
static func alert(world: Dictionary,row: Dictionary) -> void:
 if not enabled(row):return
 row.alarmed=true
 # Bounded group wake-up; a shot cannot awaken unrelated incidents or other planets.
 for other in FrontierExplorationIncidents.records(world).values():
  if not enabled(other) or other.body_id!=row.body_id or other.squad_id!=row.squad_id or other.hp<=0:continue
  other.alarmed=true
  if other.phase=="idle":FrontierExplorationIncidents.set_phase(other,"waking")
static func clear_line(world: Dictionary,row: Dictionary,f: FrontierTerrainField,actor: String,start: Vector3,end: Vector3,obstacle: Callable) -> bool:
 if not FrontierCrewSurface.visible_in_field(f,start,end):return false
 var distance:=start.distance_to(end)
 if distance<.05:return true
 if not FrontierCombatCover.intercept(world,row.body_id,start,(end-start)/distance,distance).is_empty():return false
 return not obstacle.is_valid() or float(obstacle.call(actor,start,(end-start)/distance,distance))>=distance-.4
static func move(world: Dictionary,row: Dictionary,f: FrontierTerrainField,destination: Vector3,delta: float,actor: String,obstacle: Callable,factor: float=1.0) -> bool:
 var cfg:=spec(row);var start:=FrontierCrewWorld.vector(row.position);var flat:=destination-start;flat.y=0
 var velocity:=FrontierCrewWorld.vector(row.get("move_velocity",[0,0,0]));velocity.y=0
 var local_direction:=flat.normalized().rotated(Vector3.UP,-float(row.yaw))
 var gait_factor:=lerpf(1.0,float(config().motion.side_stride_factor),absf(local_direction.x))
 if local_direction.z>0:gait_factor*=lerpf(1.0,float(config().motion.back_stride_factor),local_direction.z)
 var wanted:=flat.normalized()*minf(float(cfg.speed)*factor*gait_factor,flat.length()/maxf(.001,delta))
 velocity=velocity.move_toward(wanted,float(cfg.acceleration)*delta)
 var distance:=minf(flat.length(),velocity.length()*delta)
 if distance<.001:row.move_velocity=[0,0,0];return false
 var direction:=velocity.normalized();var end:=start+direction*distance;end.y=f.height(end.x,end.z)
 if absf(end.y-start.y)>maxf(.35,distance*.65) or (FrontierSurfaceDrainage.liquid(f.traits) and end.y< -2.5):row.move_velocity=[0,0,0];return false
 # Terrain support, authored cover and physical world props all block travel.
 if not clear_line(world,row,f,actor,start+Vector3.UP*.8,end+direction*float(cfg.radius)+Vector3.UP*.8,obstacle):row.move_velocity=[0,0,0];return false
 for other in FrontierExplorationIncidents.records(world).values():
  if other.id==row.id or other.body_id!=row.body_id or other.hp<=0 or FrontierExplorationIncidents.definition(other.template).mode!="robot":continue
  if end.distance_to(FrontierCrewWorld.vector(other.position))<float(cfg.radius)+(.8 if not enabled(other) else float(spec(other).radius)):row.move_velocity=[0,0,0];return false
 row.move_velocity=FrontierExplorationIncidents.array((end-start)/maxf(.001,delta))
 row.position=FrontierExplorationIncidents.array(end);row.yaw=fposmod(atan2(-direction.x,-direction.z),TAU);row.travel+=distance
 return true
static func maneuver(world: Dictionary,row: Dictionary,f: FrontierTerrainField,actor: String,delta: float,obstacle: Callable) -> bool:
 var cfg:=spec(row);var at:=FrontierCrewWorld.vector(row.position)
 var target:=FrontierCrewWorld.vector(world.crew.members[actor].position);var radial:=target-at;radial.y=0
 var distance:=radial.length()
 if distance<.1:return false
 radial/=distance
 var lateral:=Vector3(-radial.z,0,radial.x)
 var phase: float=(float(row.get("motion_clock",row.age))+float(absi(str(row.id).hash())%100)*.037)/float(config().maneuver.side_seconds)
 var side:=sin(phase*PI)
 var advance:=clampf((distance-float(cfg.combat_distance))/float(config().maneuver.distance_deadband),-1,1)
 var home:=FrontierCrewWorld.vector(row.home)
 # Exactly two local alternatives. Keep collision, slope, water and group spacing checks.
 for sign_value in [side,-side]:
  var drive: Vector3=radial*advance+lateral*sign_value*.85
  var intensity:=minf(1.0,drive.length())
  var direction: Vector3=drive.normalized()
  if at.distance_to(home)>float(config().leash)-3:direction=(home-at).normalized()
  if move(world,row,f,at+direction*4,delta,actor,obstacle,float(cfg.combat_move_factor)*intensity):
   var facing: Vector3=target-FrontierCrewWorld.vector(row.position)
   row.yaw=fposmod(atan2(-facing.x,-facing.z),TAU)
   return true
 return false
static func aim_at(world: Dictionary,row: Dictionary,actor: String) -> void:
 var cfg:=spec(row);var member: Dictionary=world.crew.members[actor]
 var at:=FrontierCrewWorld.vector(member.position)
 if cfg.attack!="mortar":at+=Vector3.UP*(.85 if member.loadout.get("crouched",false) else 1.3)
 row.aim=FrontierExplorationIncidents.array(at);row.target=actor
 var toward:=at-FrontierCrewWorld.vector(row.position);row.yaw=fposmod(atan2(-toward.x,-toward.z),TAU)
 FrontierExplorationIncidents.set_phase(row,"aiming")
static func shoot(world: Dictionary,row: Dictionary,f: FrontierTerrainField,present: Array,obstacle: Callable,resolve: bool=true) -> void:
 var cfg:=spec(row);var start:=FrontierExplorationIncidents.point(row,FrontierCrewWorld.vector(cfg.muzzle));var end:=FrontierCrewWorld.vector(row.aim)
 if row.phase=="projectile":start=FrontierCrewWorld.vector(row.shot_start);end=FrontierCrewWorld.vector(row.shot_end)
 var direction: Vector3=(end-start).normalized();var distance:=start.distance_to(end)
 var cover:=FrontierCombatCover.intercept(world,row.body_id,start,direction,distance)
 var physical:=float(obstacle.call(present[0],start,direction,distance)) if obstacle.is_valid() else distance
 if not cover.is_empty() and float(cover.distance)<=physical+.15 and FrontierCrewSurface.visible_in_field(f,start,cover.point):
  if resolve:FrontierCombatCover.damage(cover,float(cfg.damage))
  end=cover.point
 elif physical<distance-.15:end=start+direction*maxf(0,physical)
 elif not FrontierCrewSurface.visible_in_field(f,start,end):
  # Stop the visible projectile at the first terrain obstruction, never show a through-wall shot.
  for i in range(1,ceili(distance/.4)+1):
   var p:=start+direction*minf(distance,i*.4)
   if f.density(p)>0:end=p;break
 row.shot_start=FrontierExplorationIncidents.array(start);row.shot_end=FrontierExplorationIncidents.array(end);row.attack_serial+=1
 if not resolve:return
 for actor in present:
  var member: Dictionary=world.crew.members[actor];var at:=FrontierCrewWorld.vector(member.position)+Vector3.UP*(.8 if member.loadout.get("crouched",false) else 1.3)
  var hit:=false
  if cfg.attack=="mortar":
   hit=at.distance_to(end+Vector3.UP*.65)<float(cfg.blast_radius) and clear_line(world,row,f,actor,end+Vector3.UP*.6,at,obstacle)
  else:
   var line:=end-start;var t:=clampf((at-start).dot(line)/maxf(.01,line.length_squared()),0,1)
   hit=at.distance_to(start+line*t)<(.42 if member.loadout.get("crouched",false) else .62) and clear_line(world,row,f,actor,start,at,obstacle)
  if hit:FrontierExplorationIncidents.hurt(world,actor,float(cfg.damage),"blast" if cfg.attack=="mortar" else "combat")
static func tick(world: Dictionary,row: Dictionary,delta: float,present: Array,f: FrontierTerrainField,obstacle: Callable,defer_motion: bool=false) -> bool:
 var cfg:=spec(row);var at:=FrontierCrewWorld.vector(row.position);var target: String="";var nearest:=float(cfg.range)
 row.shield_wait=maxf(0,float(row.shield_wait)-delta)
 if row.shield_wait<=0:row.shield=minf(float(row.shield_max),float(row.shield)+float(row.shield_max)*.12*delta)
 for actor in present:
  var member: Dictionary=world.crew.members[actor];var p:=FrontierCrewWorld.vector(member.position);var d:=p.distance_to(at)
  if d<nearest and clear_line(world,row,f,actor,at+Vector3.UP*float(cfg.center),p+Vector3.UP*1.2,obstacle):nearest=d;target=actor
 row.drive_actor=target
 if not defer_motion and not target.is_empty() and row.phase in ["aiming","firing","cooling","projectile"]:
  if cfg.attack!="mortar" or row.phase in ["aiming","cooling"]:maneuver(world,row,f,target,delta,obstacle)
 if row.phase=="idle":
  if row.alarmed or (not target.is_empty() and nearest<float(cfg.wake_distance)):alert(world,row);return true
  return false
 if row.phase=="waking":
  if row.time>=float(cfg.wake_seconds):FrontierExplorationIncidents.set_phase(row,"cooling");return true
  return false
 if row.phase=="patrol":
  if not target.is_empty():alert(world,row);FrontierExplorationIncidents.set_phase(row,"pursuing");return true
  var destination:=FrontierCrewWorld.vector(row.path[int(row.patrol_index)])
  if at.distance_to(destination)<1.1:row.patrol_index=(int(row.patrol_index)+1)%12
  elif not defer_motion and not move(world,row,f,destination,delta,present[0],obstacle):row.patrol_index=(int(row.patrol_index)+1)%12
  return false
 if row.phase=="pursuing":
  var home:=FrontierCrewWorld.vector(row.home)
  if target.is_empty() or at.distance_to(home)>float(config().leash):
   if not defer_motion:move(world,row,f,home,delta,present[0],obstacle)
   if row.time>3:row.alarmed=false;FrontierExplorationIncidents.set_phase(row,"patrol");return true
  elif nearest>(16.0 if cfg.attack=="burst" else 24.0) and row.time<2.2:
   if not defer_motion:move(world,row,f,FrontierCrewWorld.vector(world.crew.members[target].position),delta,target,obstacle)
  else:row.burst=0;aim_at(world,row,target);return true
  return false
 var aim_duration: float=cfg.burst_aim_seconds if cfg.attack=="burst" and row.burst>0 else cfg.aim_seconds
 if row.phase=="aiming" and row.time>=aim_duration:
  # The final marked point is locked throughout the warning. No last-frame tracking.
  shoot(world,row,f,present,obstacle,cfg.attack!="mortar");FrontierExplorationIncidents.set_phase(row,"projectile" if cfg.attack=="mortar" else "firing");return true
 if row.phase=="projectile" and row.time>=.75:
  shoot(world,row,f,present,obstacle);FrontierExplorationIncidents.set_phase(row,"firing");return true
 if row.phase=="firing" and row.time>=float(cfg.fire_seconds):
  row.burst+=1
  if cfg.attack=="burst" and row.burst<(2 if int(row.tier)<3 else 3) and not target.is_empty():aim_at(world,row,target)
  else:FrontierExplorationIncidents.set_phase(row,"cooling")
  return true
 if row.phase=="cooling" and row.time>=float(cfg.cool_seconds):FrontierExplorationIncidents.set_phase(row,"pursuing");return true
 # Continuous motion follows the existing patrol snapshot path, without a disk save per step.
 return false
static func validate(row: Dictionary) -> bool:
 if not enabled(row):return not row.has("squad_version")
 if not config().roles.has(row.get("robot_role")) or row.template!=config().roles[row.robot_role].template:return false
 if not row.get("squad_id") is String or row.get("start_mode") not in ["dormant","patrol"]:return false
 var cfg:=spec(row)
 if row.has("move_velocity") and not FrontierUniverse._vector3_array(row.move_velocity):return false
 if row.has("motion_clock") and not FrontierUniverse._finite(row.motion_clock,0,9007199254740000):return false
 if row.has("drive_actor") and not row.drive_actor is String:return false
 if not FrontierUniverse._finite(row.get("hp_max"),float(cfg.health),float(cfg.health)):return false
 if not FrontierUniverse._finite(row.get("travel"),0,9007199254740000) or not FrontierExpeditionBusiness.integer(row.get("patrol_index"),0,11):return false
 if not FrontierExpeditionBusiness.integer(row.get("burst"),0,3) or not FrontierExpeditionBusiness.integer(row.get("attack_serial"),0,9007199254740000) or not row.get("alarmed") is bool:return false
 if not FrontierUniverse._vector3_array(row.get("home")) or row.path.size()!=13:return false
 for key in ["shot_start","shot_end"]:
  if not row.get(key) is Array or (not row[key].is_empty() and not FrontierUniverse._vector3_array(row[key])):return false
 return true

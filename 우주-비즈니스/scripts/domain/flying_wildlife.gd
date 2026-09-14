extends RefCounted
## Host-owned, bounded surface-air combat. Position is the actual airborne root.
static func eligible(form: Dictionary,row: Dictionary) -> bool:
 return form.get("category","")=="animal" and form.get("locomotion_medium","")=="surface_air" and not row.get("introduced",false)
static func config() -> Dictionary:return FrontierWildlifeCombat.config().flight
static func basis(live: Dictionary) -> Basis:
 return Basis.from_euler(Vector3(float(live.get("flight_pitch",0)),float(live.yaw),0))
static func floor_at(field: FrontierTerrainField,at: Vector3) -> float:return field.height(at.x,at.z)+.08
static func pose(live: Dictionary) -> Dictionary:
 return {"point":FrontierCrewWorld.vector(live.position),"basis":basis(live),"state":"dormant" if live.phase=="down" else "move","phase":live.phase,"alert":live.phase=="warning","clock":live.time,"combat":live,"blend":float(live.get("flight_blend",1.))}
static func open_segment(world: Dictionary,row: Dictionary,info: Dictionary,field: FrontierTerrainField,a: Vector3,b: Vector3,obstacle: Callable,target: String) -> bool:
 if FrontierWildlifeCombat.Attacks._enters_safe_zone(a,b):return false
 var radius: float=minf(float(info.radius),1.2)
 for offset in [Vector3.UP*.15,Vector3.UP*float(info.height)*.7,Vector3(radius,.4,0),Vector3(-radius,.4,0),Vector3(0,.4,radius),Vector3(0,.4,-radius)]:
  if not FrontierCrewSurface.visible_in_field(field,a+offset,b+offset):return false
 return FrontierWildlifeCombat.Attacks.corridor(world,row,a,b,info,obstacle,target)
static func move(world: Dictionary,row: Dictionary,live: Dictionary,info: Dictionary,destination: Vector3,field: FrontierTerrainField,delta: float,obstacle: Callable,actor: String,requested: float) -> bool:
 var at:=FrontierCrewWorld.vector(live.position);var goal:=destination
 goal.y=clampf(goal.y,floor_at(field,goal),float(FrontierCrewWorld.vector(live.home).y)+float(config().maximum_height))
 var vector:=goal-at;var distance:=vector.length()
 if distance<.03:live.move_speed=0.;return true
 var heading:=atan2(-vector.x,-vector.z);var turn:=wrapf(heading-float(live.yaw),-PI,PI)
 var limit:=float(config().turn_rate)*delta
 live.yaw=wrapf(float(live.yaw)+clampf(turn,-limit,limit),-PI,PI)
 live.flight_pitch=move_toward(float(live.get("flight_pitch",0)),clampf(atan2(vector.y,Vector2(vector.x,vector.z).length()),-.65,.65),delta*1.8)
 var accel: float=config().acceleration
 var desired:=minf(requested,sqrt(2.*accel*distance))*maxf(.18,cos(turn))
 live.move_speed=move_toward(float(live.get("move_speed",0)),desired,accel*delta)
 var forward: Vector3=-basis(live).z
 var next:=at+forward*minf(distance,float(live.move_speed)*delta)
 next.y=maxf(next.y,floor_at(field,next))
 var ok:=open_segment(world,row,info,field,at,next,obstacle,actor)
 if not ok:
  # A local climb is a bounded fallback; no full-world path search or teleport.
  next=at+Vector3.UP*float(config().climb_speed)*delta
  if next.y>FrontierCrewWorld.vector(live.home).y+float(config().maximum_height) or not open_segment(world,row,info,field,at,next,obstacle,actor):live.move_speed=0.;return false
 live.position=FrontierExplorationIncidents.array(next)
 live.flight_blend=clampf((next.y-floor_at(field,next))/.8,0,1)
 return true
static func step(world: Dictionary,row: Dictionary,live: Dictionary,info: Dictionary,actors: Array,field: FrontierTerrainField,delta: float,obstacle: Callable) -> void:
 var at:=FrontierCrewWorld.vector(live.position);var home:=FrontierCrewWorld.vector(live.home)
 if live.phase=="down":
  live.flight_pitch=move_toward(float(live.get("flight_pitch",0)),0.,delta*2.)
  if at.y<=floor_at(field,at)+.01:live.flight_fall=0.;live.flight_blend=0.;return
  live.flight_fall=float(live.get("flight_fall",0))+float(FrontierWildlifeCombat.config().fall_gravity)*delta
  at.y=maxf(floor_at(field,at),at.y-float(live.flight_fall)*delta);live.position=FrontierExplorationIncidents.array(at)
  live.flight_blend=0. if at.y<=floor_at(field,at)+.01 else 1.
  world.crew.wildlife_stops[FrontierWildlifeCombat.key(row.body_id,row)]={"position":live.position.duplicate(),"yaw":live.yaw}
  return
 var target: String=live.target
 var allowed:=target in actors and not FrontierWildlifeCombat.safe(world.crew.members[target])
 var goal:=FrontierCrewWorld.vector(world.crew.members[target].position)+Vector3.UP if allowed else home
 var leash: float=config().leash_radius
 if not allowed or Vector2(goal.x-home.x,goal.z-home.z).length()>leash or goal.y-home.y>float(config().maximum_height) or at.distance_to(home)>leash*1.8:
  if live.phase!="return":live.target="";live.provoked=false;FrontierWildlifeCombat.set_phase(live,"return")
 if live.phase in ["return","calm"]:
  var patrol:=FrontierEcologyPlacement.flight_pose(field,row,home,float(world.crew.navigation.orbit_time))
  move(world,row,live,info,patrol.point,field,delta,obstacle,actors[0],float(info.speed))
  if at.distance_to(patrol.point)<.35:live.flight_resume=true
  return
 if live.phase=="hurt":
  if live.time>=float(FrontierWildlifeCombat.config().flinch_seconds):
   FrontierWildlifeCombat.set_phase(live,"flee" if info.nature=="flee" or int(world.crew.combat.get(FrontierWildlifeCombat.key(row.body_id,row),info.health))<float(info.health)*float(FrontierWildlifeCombat.config().flee_health_fraction) else "warning")
  return
 if live.phase=="flee":
  var away:=at-goal;away.y=0
  if away.length()<.1:away=Vector3.RIGHT
  var escape:=home+away.normalized()*leash*.7+Vector3.UP*float(config().escape_height)
  move(world,row,live,info,escape,field,delta,obstacle,target,float(info.speed)*float(config().flee_multiplier))
  if live.time>float(FrontierWildlifeCombat.config().give_up_seconds):live.target="";FrontierWildlifeCombat.set_phase(live,"return")
  return
 var direction:=goal-at
 if live.phase=="warning":
  live.yaw=wrapf(lerp_angle(float(live.yaw),atan2(-direction.x,-direction.z),minf(1.,delta*float(config().turn_rate))),-PI,PI)
  if live.time>=float(FrontierWildlifeCombat.config().warning_seconds):FrontierWildlifeCombat.set_phase(live,"chase")
  return
 if live.phase=="chase":
  var visible:=FrontierWildlifeCombat.clear(world,row,target,field,at+Vector3.UP,goal,obstacle)
  live.lost=0. if visible else float(live.lost)+delta
  if live.lost>float(FrontierWildlifeCombat.config().give_up_seconds):live.target="";FrontierWildlifeCombat.set_phase(live,"return");return
  if at.y>floor_at(field,at)+.9 and direction.length()<float(info.start_range) and visible and (-basis(live).z).dot(direction.normalized())>.65:
   FrontierWildlifeCombat.set_phase(live,"attack")
   var aim: Vector3=(goal-(at+Vector3.UP*float(info.height)*.5)).normalized()
   live.aim=FrontierExplorationIncidents.array(aim)
   live.attack={"mode":"aerial","origin":live.position.duplicate(),"goal":FrontierExplorationIncidents.array(at+aim*minf(float(config().attack_distance),direction.length()+3.)),"hits":{},"pulses":0,"blocked":false,"travel":0.}
  else:
   move(world,row,live,info,goal+Vector3.UP*float(config().approach_height),field,delta,obstacle,target,float(info.speed))
  return
 if live.phase!="attack":return
 if not live.has("attack"):FrontierWildlifeCombat.set_phase(live,"chase");return
 var attack: Dictionary=live.attack;var elapsed:=float(live.time)-float(info.windup)
 if elapsed<0:return
 if elapsed<float(info.active) and not attack.blocked:
  if attack.pulses==0:FrontierWildlifeCombat.Attacks.pulse(live)
  var aim:=FrontierCrewWorld.vector(live.aim)
  var remaining:=FrontierCrewWorld.vector(attack.origin).distance_to(FrontierCrewWorld.vector(attack.goal))-float(attack.travel)
  var distance:=minf(maxf(0,remaining),float(info.flight_attack_speed)*delta)
  var steps:=maxi(1,ceili(distance/.3))
  for i in steps:
   var from:=FrontierCrewWorld.vector(live.position);var next:=from+aim*distance/steps
   if next.y<floor_at(field,next) or not open_segment(world,row,info,field,from,next,obstacle,target):attack.blocked=true;break
   live.position=FrontierExplorationIncidents.array(next);attack.travel+=distance/steps
   for actor in actors:
    var member: Dictionary=world.crew.members[actor]
    if FrontierWildlifeCombat.safe(member) or attack.hits.has(actor):continue
    var center:=FrontierCrewWorld.vector(member.position)+Vector3.UP*.9
    var offset:=Vector3.UP*float(info.height)*.5
    var closest:=Geometry3D.get_closest_point_to_segment(center,from+offset,next+offset+aim*float(info.attack_front))
    if closest.distance_to(center)>float(config().contact_radius)+minf(float(info.radius),.8):continue
    if not FrontierWildlifeCombat.clear(world,row,actor,field,closest,center,obstacle):continue
    attack.hits[actor]=1;FrontierExplorationIncidents.hurt(world,actor,float(info.damage));attack.blocked=true;break
 elif elapsed>=float(info.active):
  var away:=FrontierCrewWorld.vector(live.aim);away.y=0
  move(world,row,live,info,at+away*3.+Vector3.UP*2.,field,delta,obstacle,target,float(info.speed))
 if elapsed>=float(info.active)+float(info.recovery):FrontierWildlifeCombat.set_phase(live,"chase")

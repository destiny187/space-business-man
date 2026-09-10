class_name FrontierSolarOpening
extends RefCounted
## A new world's one-shot, host-owned opening. Stored paths never reposition an existing save.
static func config() -> Dictionary:return FrontierUniverse.presentation().solar_opening
static func active(nav: Dictionary) -> bool:
 var shot: Dictionary=nav.get("solar_opening",{})
 return not shot.is_empty() and float(shot.elapsed)<float(shot.duration)
static func valid(shot: Variant) -> bool:
 if not shot is Dictionary or shot.get("version")!=1:return false
 for key in ["start","finish","focus","start_focus"]:
  if not FrontierUniverse._vector3_array(shot.get(key)):return false
 for key in ["hold","move_end","turn_start","turn_end"]:
  if not FrontierUniverse._finite(shot.get(key),0,30):return false
 if not FrontierUniverse._finite(shot.get("duration"),1,30) or not FrontierUniverse._finite(shot.get("elapsed"),0,float(shot.duration)):return false
 return FrontierUniverse._finite(shot.get("hold"),0,float(shot.move_end)) and FrontierUniverse._finite(shot.get("move_end"),float(shot.hold)+.1,float(shot.duration)) and FrontierUniverse._finite(shot.get("turn_start"),0,float(shot.turn_end)) and FrontierUniverse._finite(shot.get("turn_end"),float(shot.turn_start)+.1,float(shot.duration))
static func create(manifest: Dictionary) -> Dictionary:
 var cfg:=config()
 var points: Array[Vector3]=[]
 var radii: Array[float]=[]
 var focus:=Vector3.ZERO
 for ordinal in 8:
  var point:=FrontierUniverse.position(manifest,ordinal,float(cfg.duration))
  points.append(point);radii.append(FrontierUniverse.navigation_radius(FrontierUniverse.body(manifest,ordinal)))
  focus+=point/8.0
 focus*=float(cfg.focus_fraction)
 var start_focus:=FrontierUniverse.position(manifest,2)
 var best:=-INF
 var finish:=Vector3(0,30000,30000)
 for elevation in cfg.elevations:
  for radius in cfg.view_radii:
   for index in int(cfg.view_samples):
    var angle:=TAU*float(index)/float(cfg.view_samples)
    var eye:=Vector3(cos(angle)*float(radius),float(elevation),sin(angle)*float(radius))
    var start:=start_focus+(eye-start_focus).normalized()*float(cfg.start_distance)
    if not _clear_path(start,eye,points,radii,float(cfg.clearance)):continue
    var score:=_score(eye,focus,points,radii)
    if score>best:best=score;finish=eye
 return {"version":1,"elapsed":0.0,"duration":cfg.duration,"hold":cfg.hold,"move_end":cfg.move_end,"turn_start":cfg.turn_start,"turn_end":cfg.turn_end,"start_focus":FrontierExpeditionBusiness.array(start_focus),"start":FrontierExpeditionBusiness.array(start_focus+(finish-start_focus).normalized()*float(cfg.start_distance)),"finish":FrontierExpeditionBusiness.array(finish),"focus":FrontierExpeditionBusiness.array(focus)}
static func _clear_path(start: Vector3,finish: Vector3,points: Array[Vector3],radii: Array[float],clearance: float) -> bool:
 if Geometry3D.get_closest_point_to_segment(Vector3.ZERO,start,finish).length()<float(FrontierUniverse.presentation().star_warning_radius)+clearance:return false
 for i in points.size():
  if Geometry3D.get_closest_point_to_segment(points[i],start,finish).distance_to(points[i])<radii[i]+clearance:return false
 return true
static func _score(eye: Vector3,focus: Vector3,points: Array[Vector3],radii: Array[float]) -> float:
 var basis:=Basis.looking_at((focus-eye).normalized())
 var score:=0.0
 var projections: Array[Vector2]=[]
 for i in points.size():
  var offset:=points[i]-eye
  var local:=basis.inverse()*offset
  if local.z>=0 or absf(local.x/-local.z)>.72 or absf(local.y/-local.z)>.45:continue
  var hidden:=false
  for j in points.size():
   if i==j:continue
   var along: float=(points[j]-eye).dot(offset.normalized())
   if along>0 and along<offset.length() and (points[j]-eye-offset.normalized()*along).length()<radii[j]:hidden=true;break
  var sun_along:=(-eye).dot(offset.normalized())
  if sun_along>0 and sun_along<offset.length() and (-eye-offset.normalized()*sun_along).length()<float(FrontierUniverse.presentation().star_radius):hidden=true
  if hidden:continue
  var projected:=Vector2(local.x/-local.z,local.y/-local.z)
  var separated:=true
  for other in projections:
   if other.distance_to(projected)<.045:separated=false
  projections.append(projected)
  score+=10.0 if separated else 1.0
  score+=minf(3,float(radii[i])/offset.length()*100.0)
  # Mars is part of the panorama, never the forced starting aim.
  if i==3 and projected.length()<.14:score-=12
 return score
static func pose(shot: Dictionary,elapsed: float) -> Dictionary:
 var pull:=smoothstep(float(shot.hold),float(shot.move_end),elapsed)
 var turn:=smoothstep(float(shot.turn_start),float(shot.turn_end),elapsed)
 var start:=FrontierCrewWorld.vector(shot.start)
 var finish:=FrontierCrewWorld.vector(shot.finish)
 var point:=start.lerp(finish,pull)
 var target: Vector3=(FrontierCrewWorld.vector(shot.focus)-finish).normalized()
 target=target.rotated(target.cross(Vector3.UP).normalized(),.15)
 var rotation:=Basis.looking_at((FrontierCrewWorld.vector(shot.start_focus)-start).normalized()).get_rotation_quaternion().slerp(Basis.looking_at(target).get_rotation_quaternion(),turn)
 return {"position":point,"direction":-Basis(rotation).z,"rotation":rotation,"turn":turn,"pull":pull}
static func step(world: Dictionary,delta: float) -> bool:
 var nav: Dictionary=world.crew.navigation
 if not active(nav):return false
 var shot: Dictionary=nav.solar_opening
 var before:=FrontierCrewWorld.vector(nav.position)
 shot.elapsed=minf(float(shot.duration),float(shot.elapsed)+delta)
 nav.orbit_time=float(nav.orbit_time)+delta
 var frame:=pose(shot,float(shot.elapsed))
 nav.position=FrontierExpeditionBusiness.array(frame.position);nav.direction=FrontierExpeditionBusiness.array(frame.direction)
 nav.speed=-minf(9000.0,before.distance_to(frame.position)/maxf(.001,delta)) if active(nav) else 0.0
 nav.manual=true;nav.boosting=false;world.flight_position=nav.position.duplicate()
 return true

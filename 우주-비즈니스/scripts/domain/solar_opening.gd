class_name FrontierSolarOpening
extends RefCounted
## A new world's one-shot, host-owned opening. Stored paths never reposition an existing save.
static func config() -> Dictionary:return FrontierUniverse.presentation().solar_opening
static func active(nav: Dictionary) -> bool:
 var shot: Dictionary=nav.get("solar_opening",{})
 return not shot.is_empty() and float(shot.elapsed)<float(shot.duration)
static func valid(shot: Variant) -> bool:
 if not shot is Dictionary or not FrontierExpeditionBusiness.integer(shot.get("version"),1,2):return false
 for key in ["start","finish","focus","start_focus"]:
  if not FrontierUniverse._vector3_array(shot.get(key)):return false
 for key in ["hold","move_end","turn_start","turn_end"]:
  if not FrontierUniverse._finite(shot.get(key),0,30):return false
 if shot.get("version")==2 and not FrontierUniverse._finite(shot.get("move_start"),float(shot.hold),float(shot.move_end)-.1):return false
 if not FrontierUniverse._finite(shot.get("duration"),1,30) or not FrontierUniverse._finite(shot.get("elapsed"),0,float(shot.duration)):return false
 return FrontierUniverse._finite(shot.get("hold"),0,float(shot.move_end)) and FrontierUniverse._finite(shot.get("move_end"),float(shot.hold)+.1,float(shot.duration)) and FrontierUniverse._finite(shot.get("turn_start"),0,float(shot.turn_end)) and FrontierUniverse._finite(shot.get("turn_end"),float(shot.turn_start)+.1,float(shot.duration))
static func create(manifest: Dictionary) -> Dictionary:
 var cfg:=config()
 var earth:=FrontierUniverse.position(manifest,2)
 var radial:=Vector3(earth.x,0,earth.z).normalized()
 var view:=FrontierCrewWorld.vector(cfg.earth_view)
 var away: Vector3=(radial*view.x+radial.cross(Vector3.UP)*view.y+Vector3.UP*view.z).normalized()
 # Keep the complete route in Earth's immediate vicinity. No panorama search.
 var start:=earth+away*float(cfg.start_distance)
 var finish:=earth+away*float(cfg.finish_distance)
 return {"version":2,"elapsed":0.0,"duration":cfg.duration,"hold":cfg.hold,"move_start":cfg.move_start,"move_end":cfg.move_end,"turn_start":cfg.turn_start,"turn_end":cfg.turn_end,"start_focus":FrontierExpeditionBusiness.array(earth),"start":FrontierExpeditionBusiness.array(start),"finish":FrontierExpeditionBusiness.array(finish),"focus":FrontierExpeditionBusiness.array(finish+away*float(cfg.finish_distance))}
static func pose(shot: Dictionary,elapsed: float) -> Dictionary:
 var pull:=smoothstep(float(shot.get("move_start",shot.hold)),float(shot.move_end),elapsed)
 var turn:=smoothstep(float(shot.turn_start),float(shot.turn_end),elapsed)
 var start:=FrontierCrewWorld.vector(shot.start)
 var finish:=FrontierCrewWorld.vector(shot.finish)
 var point:=start.lerp(finish,pull)
 var target: Vector3=(FrontierCrewWorld.vector(shot.focus)-finish).normalized()
 if int(shot.version)==1:target=target.rotated(target.cross(Vector3.UP).normalized(),.15)
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
 var displacement: Vector3=frame.position-before
 nav.speed=clampf(displacement.dot(frame.direction)/maxf(.001,delta),-9000.0,9000.0) if active(nav) else 0.0
 if int(shot.version)==1:nav.speed=-minf(9000.0,displacement.length()/maxf(.001,delta)) if active(nav) else 0.0
 else:nav.up=FrontierExpeditionBusiness.array(Basis(frame.rotation).y)
 nav.manual=true;nav.boosting=false;world.flight_position=nav.position.duplicate()
 return true

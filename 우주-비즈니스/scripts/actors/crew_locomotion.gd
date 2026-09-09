class_name FrontierCrewLocomotion
extends RefCounted
## Shared collision movement. Only the host commits vitals and motion events.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_locomotion.json"))
	return _config
static func create() -> Dictionary:
	return {"velocity":[0.0,0.0,0.0],"grounded":false,"state":"fall","jump_serial":0,"land_serial":0,"impact":0.0,"phase":0.0,"coyote":0.0,"buffer":0.0,"takeoff":0.0,"landing":0.0,"jump_request":0,"input_ack":0,"yaw":0.0,"water_depth":0.0,"water_serial":0,"water_kind":"","water_impact":0.0,"water_ready":false,"water_wet":false,"swim_phase":0.0}
static func valid(value: Variant) -> bool:
	if not value is Dictionary or not FrontierUniverse._vector3_array(value.get("velocity")) or not value.get("grounded") is bool or value.get("state") not in ["idle","walk","run","takeoff","rise","fall","land","swim","tread"]:return false
	for key in ["jump_serial","land_serial","impact","phase","coyote","buffer","takeoff","landing","jump_request","input_ack"]:
		if not FrontierUniverse._finite(value.get(key),0,9007199254740000):return false
	for key in ["water_depth","water_serial","water_impact","swim_phase"]:
		if not FrontierUniverse._finite(value.get(key,0),0,9007199254740000):return false
	if value.get("water_kind","") not in ["","enter","exit"] or not value.get("water_ready",false) is bool or not value.get("water_wet",false) is bool:return false
	var shot: Variant=value.get("water_shot",{})
	if not shot is Dictionary:return false
	if not shot.is_empty() and (not FrontierUniverse._finite(shot.get("serial"),0,9007199254740000) or not FrontierUniverse._vector3_array(shot.get("point")) or not shot.get("entering") is bool):return false
	return FrontierUniverse._finite(value.get("yaw"),-TAU,TAU)
static func step(body: CharacterBody3D,motion: Dictionary,direction: Vector2,speed: float,gravity: float,jump_request: int,delta: float,enabled: bool=true,water_depth: float=0.0,swim_vertical: float=0.0,jump_factor: float=1.0) -> void:
	var c:=config()
	var was_grounded: bool=motion.grounded
	var old_depth:=float(motion.get("water_depth",0))
	var swimming:=water_depth>float(c.swim_exit_depth) if motion.state in ["swim","tread"] else water_depth>float(c.swim_enter_depth)
	var wet_before: bool=motion.get("water_wet",old_depth>float(c.water_leave_depth))
	var wet_now:=water_depth>float(c.water_leave_depth if wet_before else c.water_contact_depth)
	if motion.get("water_ready",false) and wet_before!=wet_now:
		motion.water_serial=int(motion.get("water_serial",0))+1
		motion.water_kind="enter" if wet_now else "exit"
		motion.water_impact=clampf(absf(body.velocity.y)+Vector2(body.velocity.x,body.velocity.z).length()*.25,.3,12)
	motion.water_ready=true;motion.water_wet=wet_now;motion.water_depth=maxf(0,water_depth)
	if swimming:motion.coyote=0.0;motion.takeoff=0.0
	var start:=body.position
	motion.coyote=float(c.coyote_seconds) if was_grounded else maxf(0,float(motion.coyote)-delta)
	motion.buffer=maxf(0,float(motion.buffer)-delta)
	motion.landing=maxf(0,float(motion.landing)-delta)
	if jump_request>int(motion.jump_request):
		motion.jump_request=jump_request
		motion.buffer=float(c.jump_buffer_seconds) if enabled else 0.0
	if not enabled:motion.buffer=0.0;motion.takeoff=0.0;direction=Vector2.ZERO;swim_vertical=0.0
	if not swimming and motion.buffer>0 and motion.coyote>0 and motion.takeoff<=0:
		motion.takeoff=float(c.takeoff_seconds);motion.buffer=0.0;motion.coyote=0.0
	var launched:=false
	if motion.takeoff>0:
		motion.takeoff=maxf(0,float(motion.takeoff)-delta)
		if motion.takeoff<=0:
			body.velocity.y=float(c.jump_speed)*sqrt(jump_factor);motion.jump_serial+=1;motion.landing=0.0;motion.coyote=0.0;launched=true
	var immersion:=clampf(water_depth/1.5,0,1)
	var water_cfg:=FrontierSurfaceWater.config()
	if swimming:motion.takeoff=0.0
	var target:=direction*speed*lerpf(1.0,float(water_cfg.water_speed_multiplier),immersion)
	var acceleration: float=c.acceleration if was_grounded else c.air_acceleration
	body.velocity.x=move_toward(body.velocity.x,target.x,acceleration*delta)
	body.velocity.z=move_toward(body.velocity.z,target.y,acceleration*delta)
	if not launched:
		if not was_grounded or immersion>.7:body.velocity.y-=gravity*delta
		else:body.velocity.y=-1.0
	if immersion>0:
		body.velocity.y+=gravity*float(water_cfg.buoyancy)*immersion*delta
		body.velocity.y*=exp(-float(water_cfg.water_drag)*immersion*delta)
		if enabled and water_depth>1.0 and motion.buffer>0:
			body.velocity.y=3.0;motion.buffer=0.0
	if swimming and enabled and absf(swim_vertical)>.05:
		body.velocity.y=move_toward(body.velocity.y,clampf(swim_vertical,-1,1)*float(c.swim_vertical_speed),delta*5.0)
	body.floor_snap_length=float(c.floor_snap) if body.velocity.y<=0 and not swimming else 0.0
	var impact:=maxf(0,-body.velocity.y)
	body.move_and_slide()
	# A jump consumes grace even while the previous frame was on the floor.
	if launched:motion.coyote=0.0
	motion.grounded=body.is_on_floor()
	if motion.grounded and not was_grounded and impact>1.5 and water_depth<.5:
		motion.land_serial+=1;motion.impact=impact;motion.landing=float(c.landing_seconds)
	var travel:=Vector2(body.position.x-start.x,body.position.z-start.z)
	var horizontal_speed:=travel.length()/maxf(delta,.001)
	if horizontal_speed>.12:
		motion.yaw=wrapf(lerp_angle(float(motion.yaw),atan2(-travel.x,-travel.y),minf(delta*12,1)),-PI,PI)
	if motion.grounded:
		var stride: float=c.run_stride if speed>float(FrontierCrewSurface.config().movement_speed)*1.1 else c.walk_stride
		motion.phase=fposmod(float(motion.phase)+travel.length()/stride*TAU,TAU)
	motion.velocity=[body.velocity.x,body.velocity.y,body.velocity.z]
	if swimming:motion.swim_phase=fposmod(float(motion.get("swim_phase",0))+delta*TAU/float(c.swim_stroke_seconds)*(1.0 if horizontal_speed>.15 else .45),TAU)
	if swimming:motion.state="swim" if horizontal_speed>.15 else "tread"
	elif motion.takeoff>0:motion.state="takeoff"
	elif not motion.grounded:motion.state="rise" if body.velocity.y>0 else "fall"
	elif motion.landing>0:motion.state="land"
	elif horizontal_speed>.12:motion.state="run" if speed>float(FrontierCrewSurface.config().movement_speed)*1.1 else "walk"
	else:motion.state="idle"

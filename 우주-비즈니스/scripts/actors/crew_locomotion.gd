class_name FrontierCrewLocomotion
extends RefCounted
## Shared collision movement. Only the host commits vitals and motion events.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_locomotion.json"))
	return _config
static func create() -> Dictionary:
	return {"velocity":[0.0,0.0,0.0],"grounded":false,"state":"fall","jump_serial":0,"land_serial":0,"impact":0.0,"phase":0.0,"coyote":0.0,"buffer":0.0,"takeoff":0.0,"landing":0.0,"jump_request":0,"input_ack":0,"yaw":0.0}
static func valid(value: Variant) -> bool:
	if not value is Dictionary or not FrontierUniverse._vector3_array(value.get("velocity")) or not value.get("grounded") is bool or value.get("state") not in ["idle","walk","run","takeoff","rise","fall","land"]:return false
	for key in ["jump_serial","land_serial","impact","phase","coyote","buffer","takeoff","landing","jump_request","input_ack"]:
		if not FrontierUniverse._finite(value.get(key),0,9007199254740000):return false
	return FrontierUniverse._finite(value.get("yaw"),-TAU,TAU)
static func step(body: CharacterBody3D,motion: Dictionary,direction: Vector2,speed: float,gravity: float,jump_request: int,delta: float,enabled: bool=true) -> void:
	var c:=config()
	var was_grounded: bool=motion.grounded
	var start:=body.position
	motion.coyote=float(c.coyote_seconds) if was_grounded else maxf(0,float(motion.coyote)-delta)
	motion.buffer=maxf(0,float(motion.buffer)-delta)
	motion.landing=maxf(0,float(motion.landing)-delta)
	if jump_request>int(motion.jump_request):
		motion.jump_request=jump_request
		motion.buffer=float(c.jump_buffer_seconds) if enabled else 0.0
	if not enabled:motion.buffer=0.0;motion.takeoff=0.0;direction=Vector2.ZERO
	if motion.buffer>0 and motion.coyote>0 and motion.takeoff<=0:
		motion.takeoff=float(c.takeoff_seconds);motion.buffer=0.0;motion.coyote=0.0
	var launched:=false
	if motion.takeoff>0:
		motion.takeoff=maxf(0,float(motion.takeoff)-delta)
		if motion.takeoff<=0:
			body.velocity.y=float(c.jump_speed);motion.jump_serial+=1;motion.landing=0.0;motion.coyote=0.0;launched=true
	var target:=direction*speed
	var acceleration: float=c.acceleration if was_grounded else c.air_acceleration
	body.velocity.x=move_toward(body.velocity.x,target.x,acceleration*delta)
	body.velocity.z=move_toward(body.velocity.z,target.y,acceleration*delta)
	if not launched:
		if not was_grounded:body.velocity.y-=gravity*delta
		else:body.velocity.y=-1.0
	body.floor_snap_length=float(c.floor_snap) if body.velocity.y<=0 else 0.0
	var impact:=maxf(0,-body.velocity.y)
	body.move_and_slide()
	# A jump consumes grace even while the previous frame was on the floor.
	if launched:motion.coyote=0.0
	motion.grounded=body.is_on_floor()
	if motion.grounded and not was_grounded and impact>1.5:
		motion.land_serial+=1;motion.impact=impact;motion.landing=float(c.landing_seconds)
	var travel:=Vector2(body.position.x-start.x,body.position.z-start.z)
	var horizontal_speed:=travel.length()/maxf(delta,.001)
	if horizontal_speed>.12:
		motion.yaw=wrapf(lerp_angle(float(motion.yaw),atan2(-travel.x,-travel.y),minf(delta*12,1)),-PI,PI)
	if motion.grounded:
		var stride: float=c.run_stride if speed>float(FrontierCrewSurface.config().movement_speed)*1.1 else c.walk_stride
		motion.phase=fposmod(float(motion.phase)+travel.length()/stride*TAU,TAU)
	motion.velocity=[body.velocity.x,body.velocity.y,body.velocity.z]
	if motion.takeoff>0:motion.state="takeoff"
	elif not motion.grounded:motion.state="rise" if body.velocity.y>0 else "fall"
	elif motion.landing>0:motion.state="land"
	elif horizontal_speed>.12:motion.state="run" if speed>float(FrontierCrewSurface.config().movement_speed)*1.1 else "walk"
	else:motion.state="idle"

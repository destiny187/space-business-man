class_name FrontierLandingWalk
extends Node3D
## Local presentation of the owner's existing suit; authority stays at the approved spawn.
var model: Node3D
var pose: FrontierCrewPose
var points: Array[Vector3]=[]
var lengths: Array[float]=[]
var distance:=0.0
var duration:=3.2
var phase:=0.0
var surface: FrontierCrewSurfaceScene
var elapsed:=0.0
func configure(app: FrontierCrewExpedition,finch: bool) -> void:
	surface=app.surface_world
	model=app.visuals[app.session.latest.self_id].model.duplicate();model.visible=true;add_child(model)
	pose=FrontierCrewPose.new();add_child(pose);pose.configure(model);pose.reset()
	var ship:=surface.landing_ship
	if finch:points=[ship.to_global(Vector3(0,1.95,-.45)),ship.to_global(Vector3(-1.15,.68,-.86)),ship.to_global(Vector3(-2.1,0,-.86))]
	else:points=[ship.to_global(Vector3(0,-.92,7.18)),ship.to_global(Vector3(0,-2.49,10.8))]
	var finish: Vector3=app.actors[app.session.latest.self_id].position
	var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_arrival.json"))
	var route:=FrontierCrewWorld.vector(FrontierCrewSurface.config().landing_spawn_positions[0])+FrontierCrewWorld.vector(cfg.boarding_route_offset)
	route.y=surface.terrain.field.height(route.x,route.z)+.03
	points.append(route);points.append(finish)
	for i in range(points.size()-1):
		var length_value:=points[i].distance_to(points[i+1]);lengths.append(length_value);distance+=length_value
	duration=clampf(distance/float(cfg.walk_speed),float(cfg.walk_seconds_range[0]),float(cfg.walk_seconds_range[1]));global_position=points[0]
func walk(delta: float,t: float,blocked: bool) -> void:
	if blocked:
		for p in pose.speakers:p.stream_paused=true
		return
	for p in pose.speakers:p.stream_paused=false
	var along:=distance*smoothstep(0,1,t);var point:=points[-1];var direction:=Vector3.FORWARD;var segment:=points.size()-2
	for i in lengths.size():
		if along<=lengths[i]:
			var f:=along/maxf(.001,lengths[i]);point=points[i].lerp(points[i+1],f);direction=(points[i+1]-points[i]).normalized();segment=i;break
		along-=lengths[i]
	if segment>=points.size()-3:point.y=maxf(point.y,surface.terrain.field.height(point.x,point.z)+.03)
	var velocity: Vector3=(point-global_position)/maxf(delta,.001);global_position=point
	phase+=Vector2(velocity.x,velocity.z).length()*delta*2.8
	var motion:=FrontierCrewLocomotion.create();motion.velocity=[velocity.x,velocity.y,velocity.z];motion.state="walk" if t<.98 else "idle";motion.grounded=true;motion.phase=phase;motion.yaw=atan2(-direction.x,-direction.z)
	pose.animate(motion,delta,true,segment>=points.size()-3)

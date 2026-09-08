class_name FrontierRoverActor
extends CharacterBody3D
## Host-authoritative kinematic chassis. Visual wheel travel never decides ownership.
var headlights: Array[SpotLight3D]=[]
var visual: FrontierRoverVisual
var drive: AudioStreamPlayer3D
var effects: AudioStreamPlayer3D
var work: AudioStreamPlayer3D
var last_event: int=-1
var last_distance:=0.0
var last_speed:=0.0
var collision_cooldown:=0.0
var door_time:=0.0
var compression: Array=[0.0,0.0,0.0,0.0]
func _ready() -> void:
	collision_layer=9;collision_mask=11;floor_snap_length=.25
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2.5,1.9,3.7);shape.shape=box;shape.position.y=1.55;add_child(shape)
	visual=FrontierRoverVisual.new();add_child(visual)
	for x in [-.94,.94]:
		var light:=SpotLight3D.new();light.position=Vector3(x,1.20,-2.10);light.rotation.x=-.06
		light.light_color=Color("fff0c7");light.spot_range=52;light.spot_angle=35;light.spot_attenuation=.65;light.shadow_enabled=true;light.light_energy=float(FrontierPlanetaryCycles.config().presentation.rover_headlight_energy)
		add_child(light);headlights.append(light);light.hide()
	drive=speaker("sfx_rover_drive",true,-8);effects=speaker("",false,-5);work=speaker("sfx_rover_winch",true,-8)
func speaker(id: String,loop: bool,volume: float) -> AudioStreamPlayer3D:
	var player:=AudioStreamPlayer3D.new();player.bus="SFX";player.max_distance=55;player.unit_size=5;player.volume_db=volume;add_child(player)
	if not id.is_empty():
		var stream: AudioStreamWAV=load("res://assets/audio/"+id+".wav").duplicate()
		if loop:stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=stream.data.size()/2
		player.stream=stream
	return player
func sound(id: String) -> void:
	effects.stream=load("res://assets/audio/"+id+".wav");effects.play()
func ground(p: Vector3,exclude: Array[RID]=[]) -> Dictionary:
	exclude=exclude.duplicate();exclude.append(get_rid())
	var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*3,p-Vector3.UP*6,1,exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)
func drive_host(r: Dictionary,control: Array,delta: float,terrain: Node,exclude: Array[RID]=[]) -> void:
	var c:=FrontierRovers.config();var powered: bool=float(r.health)>0 and float(r.battery)>0 and not r.overturned
	var throttle:=float(control[0]) if powered else 0.0
	var brake: bool=float(control[2])>.5 or not powered
	var steering:=move_toward(float(r.steering),float(control[1]),delta*3)
	var speed:=move_toward(float(r.speed),0.0 if brake else throttle*(float(FrontierRovers.stats(r).speed) if throttle>=0 else float(c.reverse_speed)),delta*(float(c.braking) if brake or is_zero_approx(throttle) else float(c.acceleration)))
	var yaw:=rotation.y-speed*tan(steering*float(c.steer_angle))/float(c.wheelbase)*delta
	var basis_y:=Basis(Vector3.UP,yaw)
	var next:=position-basis_y.z*speed*delta
	if terrain==null or not terrain.ready_at(position) or not terrain.ready_at(next):r.speed=0.0;velocity=Vector3.ZERO;return
	var heights: Array[float]=[];var slope:=0.0
	for offset in c.wheel_points:
		var hit:=ground(next+basis_y*FrontierCrewWorld.vector(offset),exclude)
		if hit.is_empty():continue
		heights.append(hit.position.y);slope=maxf(slope,rad_to_deg(hit.normal.angle_to(Vector3.UP)))
	var pitch:=rotation.x;var roll:=rotation.z
	if heights.size()==4 and not r.overturned:
		pitch=atan2((heights[0]+heights[1]-heights[2]-heights[3])*.5,2.7)
		roll=atan2((heights[1]+heights[3]-heights[0]-heights[2])*.5,2.68)
		if slope>float(c.slope_degrees) and (heights[0]+heights[1]+heights[2]+heights[3])*.25>position.y+.05:speed=0.0
		var ground_y: float=(heights[0]+heights[1]+heights[2]+heights[3])*.25
		velocity=-basis_y.z*speed;velocity.y=clampf((ground_y+.03-position.y)*12,-10,10)
		for i in 4:compression[i]=clampf(heights[i]-ground_y,-.18,.18)
		if absf(pitch)>1.0 or absf(roll)>1.0:r.overturned=true;r.speed=0.0
	else:
		velocity=-basis_y.z*speed;velocity.y-=9.8*delta
		if velocity.y < -7:roll=move_toward(roll,PI*.55,delta)
		if absf(roll)>1.0:r.overturned=true
	if r.overturned:velocity.x=0;velocity.z=0;speed=0
	rotation=Vector3(lerp_angle(rotation.x,pitch,1-exp(-delta*8)),yaw,lerp_angle(rotation.z,roll,1-exp(-delta*8)))
	var before:=position;var impact:=velocity.length();move_and_slide()
	collision_cooldown=maxf(0,collision_cooldown-delta)
	if get_slide_collision_count()>0:
		for i in get_slide_collision_count():
			var hit:=get_slide_collision(i)
			if hit.get_normal().y<.65 and impact>4 and collision_cooldown<=0:
				r.health=maxf(0,float(r.health)-(impact-4)*6);r.event="fault";r.event_serial+=1;collision_cooldown=1.0;speed=0;break
	var distance:=Vector2(position.x-before.x,position.z-before.z).length()
	if absf(speed)<.01:distance=0.0
	r.distance+=distance;r.battery=maxf(0,float(r.battery)-distance*float(c.battery_per_metre)-(float(c.battery_per_second)*delta if absf(speed)>.1 else 0.0))
	r.position=FrontierExpeditionBusiness.array(position);r.rotation=FrontierExpeditionBusiness.array(rotation);r.speed=speed;r.steering=steering
func present(r: Dictionary,delta: float,audible: bool,task: Dictionary={}) -> void:
	var speed:=absf(float(r.speed));var serial:=int(r.event_serial)
	if last_event>=0 and serial>last_event:
		if r.event=="door":door_time=.7
		if audible:sound(str(FrontierRovers.config().audio.get(r.event,"sfx_rover_start")))
	last_event=serial
	if audible and speed>.2:
		if not drive.playing:
			if last_speed<=.2:sound("sfx_rover_start")
			drive.play()
		drive.pitch_scale=.7+speed/float(FrontierRovers.stats(r).speed)*.65
	else:
		if audible and drive.playing and last_speed>1:sound("sfx_rover_brake")
		drive.stop()
	if audible and not task.is_empty():
		if not work.playing:work.play()
	else:work.stop()
	if not audible:effects.stop()
	door_time=maxf(0,door_time-delta)
	visual.pose(float(r.distance)-last_distance,float(r.steering)*.48,compression,Vector2.ONE*minf(1,door_time*3),minf(1,door_time*3))
	last_distance=float(r.distance);last_speed=speed

func set_headlights(active: bool) -> void:
	for light in headlights:light.visible=active

class_name FrontierCrewPose
extends Node3D
## Articulated armor, soft joint gaskets and terrain-aware two-bone legs.
var model: Node3D
var skeleton: Skeleton3D
var bones: Dictionary={}
var rest: Dictionary={}
var global_rest: Dictionary={}
var phase:=0.0
var blend:=0.0
var air:=0.0
var compression:=0.0
var foot_heights: Dictionary={"L":0.0,"R":0.0}
var last_jump: int=-1
var last_land: int=-1
var last_step: int=-1
var speakers: Array[AudioStreamPlayer3D]=[]
var elapsed:=0.0
signal landed(point: Vector3,strength: float)

func configure(value: Node3D) -> void:
	model=value
	var found:=model.find_children("*","Skeleton3D",true,false)
	if found.is_empty():push_error("Surveyor skeleton missing");return
	skeleton=found[0]
	for i in skeleton.get_bone_count():
		var bone:=skeleton.get_bone_name(i);bones[bone]=i;rest[bone]=skeleton.get_bone_rest(i);global_rest[bone]=skeleton.get_bone_global_rest(i)
	for i in 3:
		var player:=AudioStreamPlayer3D.new();player.bus="SFX";player.max_distance=22;player.unit_size=3;player.volume_db=-15;add_child(player);speakers.append(player)
func reset() -> void:
	last_jump=-1;last_land=-1;last_step=-1;compression=0;air=0;blend=0
	foot_heights={"L":0.0,"R":0.0}
	if skeleton!=null:skeleton.reset_bone_poses()
func _rotate(bone: String,angles: Vector3,weight: float) -> void:
	if not bones.has(bone):return
	var i: int=bones[bone]
	var basis: Basis=global_rest[bone].basis.orthonormalized()
	var rotation:=basis.inverse()*Basis.from_euler(angles)*basis
	var target: Quaternion=rest[bone].basis.get_rotation_quaternion()*rotation.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(i,skeleton.get_bone_pose_rotation(i).slerp(target,weight))
func _ground(point: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.55,point-Vector3.UP*.65,1)
	return get_world_3d().direct_space_state.intersect_ray(query)
func _play(id: String,pitch: float=1.0) -> void:
	var path: String="res://assets/audio/"+id+".wav"
	if not ResourceLoader.exists(path):return
	for player in speakers:
		if not player.playing:
			player.stream=load(path);player.pitch_scale=pitch;player.play();return
func animate(motion: Dictionary,delta: float,audible: bool=true,terrain: bool=true) -> void:
	if skeleton==null or motion.is_empty():return
	elapsed+=delta
	var c:=FrontierCrewLocomotion.config()
	var velocity:=FrontierCrewWorld.vector(motion.velocity)
	var speed:=Vector2(velocity.x,velocity.z).length()
	var weight:=1.0-exp(-delta*18)
	var grounded: bool=motion.grounded
	var moving: bool=grounded and motion.state in ["walk","run"]
	blend=lerpf(blend,clampf(speed/2.0,0,1) if moving else 0.0,weight)
	air=lerpf(air,0.0 if grounded else 1.0,weight)
	phase=float(motion.phase)
	model.rotation.y=lerp_angle(model.rotation.y,float(motion.yaw),weight)
	var jump: int=int(motion.jump_serial);var land: int=int(motion.land_serial)
	if last_jump>=0 and jump>last_jump and audible:_play("sfx_suit_jump")
	if last_land>=0 and land>last_land:
		compression=clampf(float(motion.impact)/14,.22,.8)
		if audible:_play("sfx_suit_land");landed.emit(global_position,compression)
	last_jump=jump;last_land=land
	compression=move_toward(compression,0,delta*3)
	if motion.state=="takeoff":compression=maxf(compression,.35)
	var step:=int(floor(fposmod(phase,TAU)/PI))
	if last_step>=0 and step!=last_step and moving and audible:_play("sfx_suit_step",.96 if step==0 else 1.04)
	last_step=step
	if not audible:
		for player in speakers:player.stop()
	var run:=1.0 if motion.state=="run" else 0.0
	var pelvis_drop:=.012+.12*compression+.068*blend
	var lean:=.055*blend+.10*run+.16*compression
	var offsets: Dictionary={}
	var slopes: Dictionary={}
	for side in ["L","R"]:
		var cycle:=fposmod(phase/TAU+(0.0 if side=="L" else .5),1.0)
		var reach:=float(c.foot_reach)+run*.02
		var stride: float=c.run_stride if run>0 else c.walk_stride
		var stance:=2.0*reach/stride
		var z:=lerpf(-reach,reach,cycle/stance) if cycle<stance else lerpf(reach,-reach,smoothstep(0,1,(cycle-stance)/(1-stance)))
		var lift:=0.0 if cycle<stance else sin((cycle-stance)/(1-stance)*PI)*float(c.foot_lift)*(1+run*.4)
		var local:=Vector3(-.18 if side=="L" else .18,0,z*blend)
		var height:=0.0
		var slope:=0.0
		if grounded and terrain:
			var hit:=_ground(model.to_global(local))
			if not hit.is_empty():
				height=clampf(model.to_local(hit.position).y,-.20,.24)
				var normal: Vector3=model.global_basis.inverse()*hit.normal
				slope=clampf(atan2(normal.z,normal.y),-.45,.45)
		foot_heights[side]=lerpf(float(foot_heights[side]),height,weight)
		offsets[side]=Vector2(z*blend,float(foot_heights[side])+lift*blend)
		slopes[side]=slope
	pelvis_drop+=maxf(0,-minf(float(foot_heights.L),float(foot_heights.R)))
	var pelvis: int=bones.pelvis
	var rest_position: Vector3=rest.pelvis.origin
	skeleton.set_bone_pose_position(pelvis,rest_position+Vector3(0,-pelvis_drop*(1-air),0))
	_rotate("pelvis",Vector3(0,sin(phase)*.045*blend,cos(phase)*.025*blend),weight)
	_rotate("spine",Vector3(lean, -sin(phase)*.07*blend,0),weight)
	_rotate("head",Vector3(-lean*.65,0,0),weight)
	for side in ["L","R"]:
		var sign_value:=1.0 if side=="L" else -1.0
		var swing:=sin(phase)*sign_value
		var foot: Vector2=offsets[side]
		var y: float=-.71+pelvis_drop+foot.y
		var distance:=clampf(Vector2(y,foot.x).length(),.18,.708)
		var thigh:=atan2(-foot.x,-y)+acos(clampf((.42*.42+distance*distance-.29*.29)/(2*.42*distance),-1,1))
		var knee:=-(PI-acos(clampf((.42*.42+.29*.29-distance*distance)/(2*.42*.29),-1,1)))
		var ankle: float=-thigh-knee+float(slopes[side])
		var falling: bool=motion.state=="fall"
		thigh=lerpf(thigh,(.15 if falling else .35)+sign_value*.12,air)
		knee=lerpf(knee,(-.38 if falling else -.72)-sign_value*.16,air)
		ankle=lerpf(ankle,.18,air)
		_rotate("thigh_"+side,Vector3(thigh,0,0),weight)
		_rotate("shin_"+side,Vector3(knee,0,0),weight)
		_rotate("foot_"+side,Vector3(ankle,0,0),weight)
		_rotate("upper_arm_"+side,Vector3(-swing*.32*blend-air*.24,0,sign_value*(.055+air*.12)),weight)
		_rotate("forearm_"+side,Vector3(.18+run*.38+air*.38+maxf(0,swing)*.15*blend,0,0),weight)

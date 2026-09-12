extends "res://scripts/actors/creatures/ground_locomotion.gd"
## Authored skeletal animation plus local terrain correction; never changes the authority root.
var art: Dictionary={}
var players: Array[AnimationPlayer]=[]
var clip_names: Array[Dictionary]=[]
var authored_poses: Array[Array]=[]
var clips: Array[String]=[]
var clip_times: Array[float]=[]
var socket_nodes: Array[Dictionary]=[]
var authored_limbs: Array[Dictionary]=[]
var planted: Dictionary={}
var released_feet: Dictionary={}
var ground_samples: Dictionary={}
var gait:="move_loop"
var wanted_clip:="idle_loop"
var pose_clock:=0.0
var pose_step:=0.0
var grounded_error:=0.0
var reach_debug: Dictionary={}

func configure(owner: Node3D,display: Node3D) -> void:
	actor=owner;visual=display;art=owner.remodel;profile=art.motion_profile
	enabled=true;kind=art.kind
	var bounds: Dictionary=art.lods.near
	body_length=maxf(.2,float(bounds.max[2])-float(bounds.min[2]))
	var total:=0.0
	var skeleton: Skeleton3D=actor.anatomical_skeletons[0]
	for key in art.sockets:
		var socket: Dictionary=art.sockets[key]
		if not str(socket.bone).ends_with("_foot"):continue
		var name: String=str(socket.bone).trim_suffix("_foot")
		var foot:=skeleton.find_bone(socket.bone)
		var lower:=skeleton.get_bone_parent(foot);var upper:=skeleton.get_bone_parent(lower)
		var h:=skeleton.get_bone_global_rest(upper).origin;var k:=skeleton.get_bone_global_rest(lower).origin;var f:=skeleton.get_bone_global_rest(foot).origin
		var length_value:=h.distance_to(k)+k.distance_to(f);total+=length_value
		authored_limbs.append({"name":name,"socket":key,"foot":str(socket.bone),"lower":skeleton.get_bone_name(lower),"upper":skeleton.get_bone_name(upper),"length":length_value,"sole":maxf(.025,float(socket.point[1])-float(bounds.min[1]))})
	leg_length=total/authored_limbs.size() if not authored_limbs.is_empty() else body_length*.22
	for i in actor.models.size():install(i)

func install(lod: int) -> void:
	var model: Node3D=actor.models[lod]
	var found:=model.find_children("*","AnimationPlayer",true,false)
	assert(not found.is_empty(),"Remodel requires authored AnimationPlayer")
	var player:=found[0] as AnimationPlayer
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var names: Dictionary={}
	for name in art.clips:
		# Godot's scene importer consumes the _loop suffix; direct GLTF loading preserves it.
		var imported: String=name if player.has_animation(name) else str(name).trim_suffix("_loop")
		assert(player.has_animation(imported),"Missing authored clip "+name)
		names[name]=imported
		if str(name).ends_with("_loop") or name=="feed":player.get_animation(imported).loop_mode=Animation.LOOP_LINEAR
	clip_names.append(names)
	players.append(player);clips.append("");clip_times.append(-1.);authored_poses.append([])
	var nodes: Dictionary={}
	# Explicit markers are driven from the live skin, avoiding glTF bone-empty offset differences.
	for key in art.sockets:
		var marker:=Node3D.new();marker.name="Live_"+key;model.add_child(marker);nodes[key]=marker
	socket_nodes.append(nodes)
	actor.mouth_markers[lod]=nodes.get("Socket_Muzzle")

func reset() -> void:
	super.reset();planted.clear();released_feet.clear();ground_samples.clear()

func drive(target: Transform3D,delta: float,sampler: Callable,stopped: bool,interval: float=0.,revision: int=-1) -> void:
	if initialized and point.distance_to(target.origin)>maxf(3.,body_length*actor.base_scale*float(config().teleport_lengths)):
		planted.clear();released_feet.clear();ground_samples.clear()
	super.drive(target,delta,sampler,stopped,interval,revision)

func ground_sample(key: String,at: Vector3,reach: float) -> Dictionary:
	var cache: Dictionary=ground_samples.get(key,{})
	if contact_interval>0 and not cache.is_empty() and cache.revision==ground_revision and idle_clock-float(cache.time)<contact_interval and not cache.hit.get("missing",false):
		var hit: Dictionary=cache.hit.duplicate();var up: Vector3=hit.normal
		hit.point=at-up*(at-Vector3(hit.point)).dot(up)
		return hit
	var hit: Dictionary=probe.call(at,reach)
	ground_samples[key]={"hit":hit,"time":idle_clock,"revision":ground_revision}
	return hit

func preview(delta: float) -> void:
	if driven or actor.paused:return
	dt=minf(delta,.15);point=actor.global_position;frame=actor.global_basis.orthonormalized();initialized=true
	var nominal: float=natural(profile)*actor.base_scale*actor.movement_rate
	advance(nominal*dt if actor.state=="move" else 0.0,dt)

func advance(travel: float,delta: float) -> void:
	idle_clock+=delta;sound_left=maxf(0,sound_left-delta)
	travel_speed=travel/maxf(.001,delta);speed=travel_speed
	if actor.paused:return
	var local_speed: float=travel_speed/maxf(.001,actor.base_scale)
	if gait=="move_loop" and local_speed>natural(profile)*1.45:gait="run_loop";planted.clear();released_feet.clear()
	elif gait=="run_loop" and local_speed<natural(profile)*1.18:gait="move_loop";planted.clear();released_feet.clear()
	var data: Dictionary=profile.run if gait=="run_loop" else profile
	var previous_cycle:=floori(phase)
	phase+=local_speed*delta/(float(data.stride)/float(data.stance))
	if driven and authored_limbs.is_empty() and not contacts_suspended and local_speed>.025 and previous_cycle!=floori(phase) and sound_left<=0:
		footfalls.append(point);sound_left=float(config().footstep_seconds)
	running=1.0 if gait=="run_loop" else 0.0

static func natural(data: Dictionary) -> float:
	return float(data.stride)/float(data.stance)/float(data.period)

func tick(delta: float) -> void:
	if actor.paused:return
	var moving: bool=actor.state=="move" and (velocity.length() if driven else travel_speed)>.025
	var next: String=gait if moving else ("feed" if actor.state=="feed" else "idle_loop")
	if actor.combat_override:
		if actor.combat_phase=="hurt":next="hurt"
		elif actor.combat_phase=="down":next="hurt"
		elif actor.combat_phase in ["attack","warning"]:next="attack"
	elif actor.state=="attack":next="attack"
	if next=="idle_loop" and wanted_clip in ["move_loop","run_loop"]:next="stop"
	elif next=="idle_loop" and wanted_clip=="stop" and pose_clock<.59:next="stop"
	if not moving and next=="idle_loop" and absf(turn_speed)>.20:next="turn_left" if turn_speed<0 else "turn_right"
	if next!=wanted_clip:
		wanted_clip=next;pose_clock=0;planted.clear();released_feet.clear()
	var old_clock:=pose_clock
	if next in ["move_loop","run_loop"]:
		var data: Dictionary=profile.run if next=="run_loop" else profile
		pose_clock=fposmod(phase,2.)*float(data.period)
		pose_step=delta*travel_speed/maxf(.001,actor.base_scale)/natural(data)
	elif next=="attack":
		pose_clock=attack_clock();pose_step=maxf(0,pose_clock-old_clock)
	elif actor.combat_override and actor.combat_phase=="down":pose_clock=.40;pose_step=0
	elif actor.combat_override and actor.combat_phase=="hurt":pose_clock=minf(.79,actor.combat_clock);pose_step=maxf(0,pose_clock-old_clock)
	else:
		pose_step=delta*(.18 if actor.state=="dormant" else 1.0);pose_clock+=pose_step

func attack_clock() -> float:
	# Piecewise retiming maps the existing host windup/contact/recovery to the authored clip.
	# This is dormant infrastructure for the enabled non-attacking species, not new host damage.
	var start: float=profile.prepare
	var end: float=profile.active_end
	if actor.combat_override and actor.combat_phase=="warning":return start*(.82+.08*sin(actor.combat_clock*4))
	var t: float=actor.combat_clock if actor.combat_override else actor.elapsed
	if t<actor.windup_seconds:return start*t/maxf(.001,actor.windup_seconds)
	if t<actor.windup_seconds+actor.active_seconds:return lerpf(start,end,(t-actor.windup_seconds)/maxf(.001,actor.active_seconds))
	return lerpf(end,float(profile.duration),clampf((t-actor.windup_seconds-actor.active_seconds)/maxf(.001,actor.recovery_seconds),0,1))

func pose_authored(visible_only: bool=false) -> void:
	grounded_error=0
	for lod in players.size():
		if visible_only and not actor.models[lod].visible:continue
		var player:=players[lod]
		var skeleton: Skeleton3D=actor.anatomical_skeletons[lod]
		# Import optimization can remove constant tracks; terrain edits must never accumulate there.
		for bone in authored_poses[lod].size():
			var before: Transform3D=authored_poses[lod][bone]
			skeleton.set_bone_pose_position(bone,before.origin)
			skeleton.set_bone_pose_rotation(bone,before.basis.orthonormalized().get_rotation_quaternion())
			skeleton.set_bone_pose_scale(bone,before.basis.get_scale())
		if clips[lod]!=wanted_clip:
			clips[lod]=wanted_clip;player.play(clip_names[lod][wanted_clip],.12)
			player.seek(pose_clock,true);player.advance(0)
		elif absf(clip_times[lod]-pose_clock)>.00001:
			# Reconcile hidden LODs and host seeks, preserving normal transition blending.
			if absf(clip_times[lod]+pose_step-pose_clock)>.08:player.seek(pose_clock,true);player.advance(0)
			else:player.advance(pose_step)
		else:
			# Authored keys reset the previous terrain correction even when the animation is still.
			player.seek(pose_clock,true);player.advance(0)
		clip_times[lod]=pose_clock
		authored_poses[lod].clear()
		for bone in skeleton.get_bone_count():authored_poses[lod].append(skeleton.get_bone_pose(bone))
		skeleton.force_update_all_bone_transforms()
		if driven and probe.is_valid() and not actor.paused and not contacts_suspended:terrain_pose(skeleton,lod)
		skeleton.force_update_all_bone_transforms()
		for key in socket_nodes[lod]:
			socket_nodes[lod][key].global_position=socket_point(skeleton,art.sockets[key])

func socket_point(skeleton: Skeleton3D,socket: Dictionary) -> Vector3:
	var bone:=skeleton.find_bone(socket.bone)
	return skeleton.global_transform*(skeleton.get_bone_global_pose(bone)*skeleton.get_bone_global_rest(bone).affine_inverse()*v(socket.point))

func limb_phase(name: String) -> float:
	if kind=="quadruped":
		return {"fore-1":0.,"fore1":.5,"hind-1":.5 if gait=="run_loop" else .75,"hind1":0. if gait=="run_loop" else .25}.get(name,0.)
	if kind=="hexapod":return fposmod((0. if "-1" in name else .5)+(int(name[3])%2)*.5,1.)
	if kind in ["tripod","annular","cantilever"]:return float(name.right(1))/3.
	if kind=="radial":return float(int(name.right(1))*2%5)/5.
	return 0.

func terrain_pose(skeleton: Skeleton3D,lod: int) -> void:
	if actor.state=="dormant" or actor.state=="attack" or (actor.combat_override and actor.combat_phase in ["hurt","down","attack"]):
		planted.clear();return
	if authored_limbs.is_empty():
		terrain_tail(skeleton)
		return
	var moving:=wanted_clip in ["move_loop","run_loop"]
	var data: Dictionary=profile.run if gait=="run_loop" else profile
	# Leave modest knee compression for uneven ground instead of locking fully extended limbs.
	if not authored_limbs.is_empty() and kind!="hopper":
		var root_bone:=skeleton.find_bone("root")
		var root_pose:=skeleton.get_bone_global_pose(root_bone)
		root_pose.origin.y-=leg_length*.075
		set_global_pose(skeleton,root_bone,root_pose)
	for limb in authored_limbs:
		var foot:=skeleton.find_bone(limb.foot);var lower:=skeleton.find_bone(limb.lower);var upper:=skeleton.find_bone(limb.upper)
		var original:=skeleton.global_transform*skeleton.get_bone_global_pose(foot).origin
		var hit: Dictionary=ground_sample(limb.name,original,float(limb.length)*actor.base_scale)
		if hit.get("missing",false):planted.erase(limb.name);continue
		var fraction:=fposmod(phase+limb_phase(limb.name),1.)
		var cycle:=floori(phase+limb_phase(limb.name))
		var stance_now: bool=not moving or fraction<float(data.stance)
		if kind=="hopper" and moving:stance_now=fraction<.27 or fraction>=.80
		if wanted_clip.begins_with("turn_") or wanted_clip=="stop":stance_now=false
		var sole: float=float(limb.sole)*actor.base_scale
		var destination:=original
		# A local ground delta preserves the authored foot lift and whole-body hop.
		var rest_world:=skeleton.global_transform*(skeleton.get_bone_global_rest(foot).origin)
		var local_ground: Vector3=hit.point
		var ground_offset: float=(local_ground-rest_world).dot(visual.global_basis.y)+sole
		destination+=visual.global_basis.y*clampf(ground_offset,-float(limb.length)*.24*actor.base_scale,float(limb.length)*.24*actor.base_scale)
		if wanted_clip=="stop":destination+=visual.global_basis.y*maxf(0,sin(pose_clock/.6*TAU-limb_phase(limb.name)*TAU))*leg_length*.065*actor.base_scale
		if stance_now:
			if not planted.has(limb.name):
				planted[limb.name]=local_ground+visual.global_basis.y*sole
				if lod==0 and moving and sound_left<=0:footfalls.append(local_ground);sound_left=float(config().footstep_seconds)
			destination=planted[limb.name]
			# A foot releases if a discontinuity/teleport or tight turn exceeds its real reach.
			if destination.distance_to(original)>float(limb.length)*actor.base_scale*.42:
				destination=local_ground+visual.global_basis.y*sole;planted[limb.name]=destination
		else:planted.erase(limb.name)
		var hip_world:=skeleton.global_transform*skeleton.get_bone_global_pose(upper).origin
		var actual_reach: float=(skeleton.get_bone_global_pose(upper).origin.distance_to(skeleton.get_bone_global_pose(lower).origin)+skeleton.get_bone_global_pose(lower).origin.distance_to(skeleton.get_bone_global_pose(foot).origin))*actor.base_scale
		# Release a trailing foot before the joint reaches its physical limit. Replant next cycle.
		if moving and stance_now and hip_world.distance_to(destination)>actual_reach*.975:
			if not released_feet.has(limb.name) or released_feet[limb.name].cycle!=cycle:
				released_feet[limb.name]={"cycle":cycle,"phase":phase,"from":destination}
		if moving and released_feet.has(limb.name) and released_feet[limb.name].cycle==cycle:
			stance_now=false;planted.erase(limb.name)
			var release: Dictionary=released_feet[limb.name]
			var progress:=clampf((phase-float(release.phase))/.20,0,1)
			var free_target:=original+visual.global_basis.y*clampf(ground_offset,-float(limb.length)*.24*actor.base_scale,float(limb.length)*.24*actor.base_scale)
			destination=Vector3(release.from).lerp(free_target,smoothstep(0,1,progress))+visual.global_basis.y*sin(progress*PI)*leg_length*.09*actor.base_scale
		var goal:=skeleton.global_transform.affine_inverse()*destination
		var h:=skeleton.get_bone_global_pose(upper).origin;var k:=skeleton.get_bone_global_pose(lower).origin;var f:=skeleton.get_bone_global_pose(foot).origin
		var reach:=h.distance_to(k)+k.distance_to(f)
		if stance_now and h.distance_to(goal)-reach>float(reach_debug.get("excess",0)):
			reach_debug={"limb":limb.name,"excess":h.distance_to(goal)-reach,"length":reach,"target":goal,"hip":h,"fraction":fraction,"phase":phase,"clip":wanted_clip}
		ik(skeleton,upper,lower,foot,goal)
		if stance_now:grounded_error=maxf(grounded_error,(skeleton.global_transform*skeleton.get_bone_global_pose(foot).origin).distance_to(destination))

func ik(skeleton: Skeleton3D,upper: int,lower: int,foot: int,target: Vector3) -> void:
	var a:=skeleton.get_bone_global_pose(upper);var b:=skeleton.get_bone_global_pose(lower);var c:=skeleton.get_bone_global_pose(foot)
	var length_a:=a.origin.distance_to(b.origin);var length_b:=b.origin.distance_to(c.origin)
	var axis:=target-a.origin;var distance:=clampf(axis.length(),absf(length_a-length_b)+.001,(length_a+length_b)*.999)
	if axis.length()<.001:return
	axis=axis.normalized()
	var bend:=b.origin-a.origin; bend-=axis*bend.dot(axis)
	if bend.length()<.001:bend=axis.cross(Vector3.RIGHT if absf(axis.x)<.9 else Vector3.UP)
	bend=bend.normalized()
	var along: float=(length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	var knee:=a.origin+axis*along+bend*sqrt(maxf(0,length_a*length_a-along*along))
	rotate_bone_toward(skeleton,upper,b.origin-a.origin,knee-a.origin)
	b=skeleton.get_bone_global_pose(lower)
	var current_foot:=skeleton.get_bone_global_pose(foot).origin
	rotate_bone_toward(skeleton,lower,current_foot-b.origin,target-b.origin)
	var foot_pose:=skeleton.get_bone_global_pose(foot);foot_pose.basis=c.basis
	set_global_pose(skeleton,foot,foot_pose)

func rotate_bone_toward(skeleton: Skeleton3D,bone: int,from: Vector3,to: Vector3) -> void:
	if from.length()<.001 or to.length()<.001:return
	var value:=skeleton.get_bone_global_pose(bone)
	value.basis=Basis(Quaternion(from.normalized(),to.normalized()))*value.basis
	set_global_pose(skeleton,bone,value)

func set_global_pose(skeleton: Skeleton3D,bone: int,value: Transform3D) -> void:
	var parent:=skeleton.get_bone_parent(bone)
	var local: Transform3D=skeleton.get_bone_global_pose(parent).affine_inverse()*value if parent>=0 else value
	skeleton.set_bone_pose_position(bone,local.origin)
	skeleton.set_bone_pose_rotation(bone,local.basis.orthonormalized().get_rotation_quaternion())
	skeleton.set_bone_pose_scale(bone,local.basis.get_scale())
	skeleton.force_update_all_bone_transforms()

func terrain_tail(skeleton: Skeleton3D) -> void:
	# Keep the authored serpentine wave; add only local relief relative to the support plane.
	var poses: Dictionary={}
	for bone in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone).begins_with("tail"):poses[bone]=skeleton.get_bone_global_pose(bone)
	for bone in poses:
		var value: Transform3D=poses[bone]
		var original:=skeleton.global_transform*value.origin
		var hit: Dictionary=ground_sample(skeleton.get_bone_name(bone),original,leg_length*actor.base_scale)
		if hit.get("missing",false):continue
		var shift: float=clampf((Vector3(hit.point)-visual.global_position).dot(visual.global_basis.y),-body_length*.04*actor.base_scale,body_length*.04*actor.base_scale)
		value.origin+=skeleton.global_basis.inverse()*visual.global_basis.y*shift
		set_global_pose(skeleton,bone,value)

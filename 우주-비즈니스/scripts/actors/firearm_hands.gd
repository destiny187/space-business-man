extends Node3D
## Blender upper arm, forearm, wrist and fingers. Analytic elbow IK keeps
## shoulders attached to the camera while hands follow authored gun contacts.
var right: Node3D
var left: Node3D
var skeletons: Dictionary={}
var cache: Dictionary={}
var camera: Camera3D
var grip_error:=0.0
func configure(held: Node3D) -> void:
	held.add_child(self)
	camera=get_viewport().get_camera_3d()
	for side in ["right","left"]:
		var model: Node3D=load("res://assets/models/equipment/firearm_hand_"+side+".glb").instantiate()
		add_child(model);FrontierInkStyle.apply(model,cache)
		for mesh in model.find_children("*","GeometryInstance3D",true,false):mesh.layers=FrontierExpeditionFeedback.HANDHELD_LAYER
		var bones:=model.find_children("*","Skeleton3D",true,false)
		if not bones.is_empty():skeletons[side]=bones[0]
		if side=="right":right=model
		else:left=model
func pose(gun: Dictionary,parts: Array[Node],phase: float,reloading: bool,kick: float,heat: float=0.0) -> void:
	var motion: Dictionary=gun.hand_motion
	var out:=float(gun.reload_out);var insert:=float(gun.reload_insert);var latch:=float(gun.reload_charge)
	var pull:=smoothstep(out,out+.15,phase)*(1-smoothstep(insert-.16,insert,phase)) if reloading else 0.0
	var offset:=FrontierCrewWorld.vector(motion.eject)*pull
	var charge:=sin(clampf((phase-latch+.08)/.16,0,1)*PI) if reloading else 0.0
	var charging:=Vector3(0,0,charge*float(motion.charge_travel))
	var magazine_contact:=FrontierCrewWorld.vector(motion.magazine_contact)
	var grasp_offset:=Vector3(.13,.13,-.10)
	for part in parts:
		if part.name.begins_with("Anim_Magazine"):
			part.position=part.get_meta("rest")+offset
			part.rotation.z=pull*(-.28 if gun.firearm=="lmg" else .18 if gun.firearm=="plasma" else 0.0)
			if not part.has_meta("grasp_center"):
				var bounds:=AABB();var first:=true
				for mesh in part.find_children("*","MeshInstance3D",true,false):
					var local_bounds: AABB=part.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
					bounds=local_bounds if first else bounds.merge(local_bounds);first=false
				part.set_meta("grasp_center",bounds.get_center())
			magazine_contact=to_local(part.to_global(part.get_meta("grasp_center")))-grasp_offset
		elif part.name.begins_with("Anim_Bolt") or part.name.begins_with("Anim_Pump"):
			part.position=part.get_meta("rest")+charging+Vector3(0,0,kick*.075)
		elif part.name.begins_with("Anim_Heat"):
			part.rotation.z=heat*.8
	var support:=FrontierCrewWorld.vector(motion.support)
	var contact:=smoothstep(.03,out,phase)*(1-smoothstep(insert+.02,insert+.10,phase)) if reloading else 0.0
	# Contacts specify the wrist, with palm/fingers extending into the grip.
	var wrist:=Vector3(-.13,-.25,-.10)+support
	wrist=wrist.lerp(magazine_contact,contact)
	wrist=wrist.lerp(FrontierCrewWorld.vector(motion.charge)-grasp_offset+charging,charge)
	_arm("right",Vector3(.13,-.35,.30),1.0)
	_arm("left",wrist,-1.0)
	_fingers("right",0,kick)
	_fingers("left",(1-contact)*sin(phase*PI)*.35 if reloading else 0.0,0)
func _arm(side: String,target: Vector3,sign_value: float) -> void:
	if not skeletons.has(side):return
	var skeleton: Skeleton3D=skeletons[side]
	var upper:=skeleton.find_bone("upper_arm");var lower:=skeleton.find_bone("forearm");var wrist:=skeleton.find_bone("wrist")
	if upper<0 or lower<0 or wrist<0:return
	var a:=skeleton.get_bone_global_rest(upper);var b:=skeleton.get_bone_global_rest(lower);var c:=skeleton.get_bone_global_rest(wrist)
	var shoulder:=skeleton.to_local(camera.to_global(Vector3(sign_value*.20,-.30,-.23))) if is_instance_valid(camera) else a.origin
	var end:=skeleton.to_local(to_global(target));var direction: Vector3=end-shoulder
	var l1:=a.origin.distance_to(b.origin);var l2:=b.origin.distance_to(c.origin)
	# A bounded clavicle reach keeps long handguards inside the arm chain.
	# The shoulder remains in the camera frame; bone lengths never stretch.
	shoulder+=direction.normalized()*clampf(direction.length()-l1-l2+.02,0,.32)
	direction=end-shoulder
	var distance:=clampf(direction.length(),absf(l1-l2)+.001,l1+l2-.001);direction=direction.normalized()
	var bend:=Vector3(sign_value*.8,-1,.25);bend=(bend-direction*bend.dot(direction)).normalized()
	var along: float=(l1*l1-l2*l2+distance*distance)/(2*distance)
	var elbow:=shoulder+direction*along+bend*sqrt(maxf(0,l1*l1-along*along))
	var reached:=shoulder+direction*distance
	_set_global(skeleton,upper,Transform3D(Basis(Quaternion((b.origin-a.origin).normalized(),(elbow-shoulder).normalized()))*a.basis,shoulder))
	_set_global(skeleton,lower,Transform3D(Basis(Quaternion((c.origin-b.origin).normalized(),(reached-elbow).normalized()))*b.basis,elbow))
	_set_global(skeleton,wrist,Transform3D(c.basis,reached))
	grip_error=reached.distance_to(end)
func _set_global(skeleton: Skeleton3D,bone: int,value: Transform3D) -> void:
	var parent:=skeleton.get_bone_parent(bone)
	var relative:=value if parent<0 else skeleton.get_bone_global_pose(parent).affine_inverse()*value
	var pose:=relative
	skeleton.set_bone_pose_position(bone,pose.origin);skeleton.set_bone_pose_rotation(bone,pose.basis.get_rotation_quaternion())
func _fingers(side: String,opened: float,trigger: float) -> void:
	if not skeletons.has(side):return
	var skeleton: Skeleton3D=skeletons[side]
	for index in skeleton.get_bone_count():
		var bone:=skeleton.get_bone_name(index)
		if not bone.begins_with("finger_"):continue
		var rotation: float=-opened
		if bone.begins_with("finger_0_"):rotation+=trigger*.12
		skeleton.set_bone_pose_rotation(index,skeleton.get_bone_rest(index).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,rotation))

extends Node3D
## Blender skeletons; left glove follows the actual removable magazine contact.
var right: Node3D
var left: Node3D
var skeletons: Dictionary={}
var cache: Dictionary={}
func configure(held: Node3D) -> void:
	held.add_child(self)
	for side in ["right","left"]:
		var model: Node3D=load("res://assets/models/equipment/firearm_hand_"+side+".glb").instantiate()
		add_child(model);FrontierInkStyle.apply(model,cache)
		for mesh in model.find_children("*","GeometryInstance3D",true,false):mesh.layers=FrontierExpeditionFeedback.HANDHELD_LAYER
		var bones:=model.find_children("*","Skeleton3D",true,false)
		if not bones.is_empty():skeletons[side]=bones[0]
		if side=="right":right=model
		else:left=model
func pose(gun: Dictionary,parts: Array[Node],phase: float,reloading: bool,kick: float) -> void:
	var tilt:=sin(phase*PI) if reloading else 0.0
	var pull:=0.0
	if reloading:
		pull=smoothstep(.19,.36,phase)*(1-smoothstep(.47,.64,phase))
	var magazine_offset:=Vector3(0,-float(gun.reload_pull)*pull,.16*pull)
	var charge:=sin(clampf((phase-.74)/.20,0,1)*PI) if reloading and phase>.74 else 0.0
	for part in parts:
		if part.name.begins_with("Anim_Magazine"):
			part.position=part.get_meta("rest")+magazine_offset
			part.rotation.z=sin(phase*TAU)*pull*.18 if gun.firearm=="plasma" else 0.0
		elif part.name.begins_with("Anim_Bolt") or part.name.begins_with("Anim_Pump"):
			part.position=part.get_meta("rest")+Vector3(0,0,kick*.075+charge*.12)
	var grip:=Vector3(0,0,float(gun.support_z))
	var contact:=smoothstep(.03,.18,phase)*(1-smoothstep(.66,.78,phase)) if reloading else 0.0
	left.position=grip.lerp(Vector3(.015,-.12,.08)+magazine_offset,contact)
	left.position+=Vector3(.22,.32,.26)*charge
	left.rotation=Vector3(0,charge*-.25,-tilt*.08)
	_fingers("right",0,kick)
	_fingers("left",maxf(0,tilt-contact)*.5,0)
func _fingers(side: String,opened: float,trigger: float) -> void:
	if not skeletons.has(side):return
	var skeleton: Skeleton3D=skeletons[side]
	for index in skeleton.get_bone_count():
		var bone:=skeleton.get_bone_name(index)
		if not bone.begins_with("finger_"):continue
		var rotation: float=-opened
		if bone.begins_with("finger_0_"):rotation+=trigger*.12
		skeleton.set_bone_pose_rotation(index,Quaternion(Vector3.RIGHT,rotation))

extends "res://tests/render_xenofauna.gd"
func _initialize() -> void:
	destination="res://../docs/production/media/biota/"
	catalogue="res://data/bestiary/biota_preview_forms.json" if "--preview" in OS.get_cmdline_user_args() else "res://data/bestiary/biota_forms.json"
	if "--imported" in OS.get_cmdline_user_args():catalogue="res://data/bestiary/biota_review_forms.json"
	collection_title="BIOTA"
	run.call_deferred()
func verify_actor(actor: Node3D,form: Dictionary) -> void:
	if actor.anatomical_skeletons.size()!=2:failures.append(form.id+" missing near/far skeletons");return
	for skeleton in actor.anatomical_skeletons:
		if skeleton==null:failures.append(form.id+" missing skeletal skin");continue
		for bone in form.rig.scaffold:
			if skeleton.find_bone(bone)<0:failures.append(form.id+" missing tissue bone "+bone)
		for marker in form.rig.hinges:
			if skeleton.find_bone(form.rig.hinges[marker])<0:failures.append(form.id+" missing hinge bone "+marker)
		var skins:=0
		for mesh in skeleton.get_parent().find_children("*","MeshInstance3D",true,false):
			if mesh.skin!=null:skins+=1
		if skins==0:failures.append(form.id+" no weighted mesh bound to skeleton")
func verify_pose(actor: Node3D,form: Dictionary,state: String) -> void:
	var near: Skeleton3D=actor.anatomical_skeletons[0];var far: Skeleton3D=actor.anatomical_skeletons[1]
	if near==null or far==null:return
	for marker in form.rig.hinges:
		var a:=near.find_bone(form.rig.hinges[marker]);var b:=far.find_bone(form.rig.hinges[marker])
		if a<0 or b<0:continue
		var delta:=near.get_bone_rest(a).affine_inverse()*near.get_bone_pose(a)
		var rotation:=delta.basis.orthonormalized().get_rotation_quaternion()
		var angle_limit: float=2.6 if form.get("construction","")=="avian" and (marker.begins_with("Anim_Wing") or marker.begins_with("Anim_Avian")) else .4
		if form.has("replacement") and marker.begins_with("Anim_Gait"):angle_limit=1.4
		if 2*acos(clampf(absf(rotation.w),0,1))>angle_limit or delta.origin.length()>.035:
			failures.append(form.id+" "+state+" authored hinge axis lost: "+marker)
		if not near.get_bone_pose(a).is_equal_approx(far.get_bone_pose(b)):failures.append(form.id+" "+state+" hinge LOD pose mismatch: "+marker)
	var deformed:=false
	for bone in form.rig.scaffold:
		var a:=near.find_bone(bone);var b:=far.find_bone(bone)
		if a<0 or b<0:continue
		if not near.get_bone_pose(a).is_equal_approx(far.get_bone_pose(b)):failures.append(form.id+" "+state+" skin LOD pose mismatch")
		deformed=deformed or not near.get_bone_pose(a).is_equal_approx(near.get_bone_rest(a))
	if not deformed:failures.append(form.id+" "+state+" tissue skeleton did not animate")

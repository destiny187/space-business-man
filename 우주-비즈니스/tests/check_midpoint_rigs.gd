extends SceneTree
## Focused checks for the newly authored articulated anatomy and planted feet.
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var failures: Array[String]=[]
var checks:=0
func _initialize():run.call_deferred()
func check(value: bool,label: String):
	checks+=1
	if not value and failures.size()<80:failures.append(label)
func run():
	var file:="res://data/bestiary/biota_review_forms.json" if "--imported" in OS.get_cmdline_user_args() else "res://data/bestiary/biota_preview_forms.json"
	var all: Array=JSON.parse_string(FileAccess.get_file_as_string(file)).forms
	var forms: Array=all.filter(func(form):return form.has("replacement"))
	if "--representatives" in OS.get_cmdline_user_args():forms=forms.filter(func(form):return form.organ_system=="armor")
	check(forms.size()==28 if "--representatives" in OS.get_cmdline_user_args() else forms.size()==196,"replacement anatomy inventory")
	for form in forms:
		var actor:=Actor.new();root.add_child(actor);actor.set_process(false);actor.paused=true;actor.configure(form)
		var skeleton: Skeleton3D=actor.anatomical_skeletons[0]
		check(skeleton!=null,form.id+" exported weighted skeleton")
		if skeleton==null:actor.free();continue
		var limbs: Dictionary=form.get("gait",{}).get("limbs",{})
		var rests: Dictionary={}
		actor.set_state("idle");actor.elapsed=0;actor.pose()
		for label in limbs:
			var data: Dictionary=limbs[label];var bones: Array=[]
			for marker in [data.hip,data.knee,data.ankle]:bones.append(skeleton.find_bone(form.rig.hinges[marker]))
			check(not -1 in bones,form.id+" complete three-joint leg "+label)
			if -1 in bones:continue
			check(skeleton.get_bone_parent(bones[1])==bones[0] and skeleton.get_bone_parent(bones[2])==bones[1],form.id+" actual connected hierarchy "+label)
			var positions: Array=[]
			for bone in bones:positions.append(skeleton.get_bone_global_pose(bone).origin)
			rests[label]={"bones":bones,"height":positions[2].y,"upper":positions[0].distance_to(positions[1]),"lower":positions[1].distance_to(positions[2]),"basis":skeleton.get_bone_global_pose(bones[2]).basis}
		for step in 16:
			actor.set_state("move");actor.elapsed=float(step)/16*TAU/float(form.get("gait",{}).get("rate",2.4));actor.pose()
			for label in rests:
				var rest: Dictionary=rests[label];var data: Dictionary=limbs[label];var poses: Array=[]
				for bone in rest.bones:poses.append(skeleton.get_bone_global_pose(bone))
				check(absf(poses[0].origin.distance_to(poses[1].origin)-rest.upper)<.004 and absf(poses[1].origin.distance_to(poses[2].origin)-rest.lower)<.004,form.id+" articulated limb lengths "+label)
				check(poses[2].origin.y>=rest.height-.04 and poses[2].origin.y<=rest.height+float(data.lift)+.08,form.id+" foot support plane "+label)
				var rotation: Quaternion=(rest.basis.inverse()*poses[2].basis).get_rotation_quaternion()
				check(2*acos(clampf(absf(rotation.w),0,1))<.08,form.id+" stable ankle orientation "+label)
		if form.anatomical_type in ["wader","owl"]:
			check(form.flight.wing_pairs==1 and form.rig.hinges.has("Anim_WingWrist_L0") and form.rig.hinges.has("Anim_AvianKnee_L"),form.id+" wing and landing chains")
		if form.anatomical_type=="serpent":check(form.rig.scaffold.size()==9 and limbs.is_empty(),form.id+" continuous limbless spine")
		actor.free();await process_frame
	var result:={"forms":forms.size(),"checks":checks,"failures":failures,"scope":"실제 가져온 골격의 부모 계층·보행 한 주기의 사지 길이·발 지지 높이·발목 방향, 비행/뱀 전용 골격"}
	FileAccess.open("res://../docs/production/media/biota/midpoints/rig-check.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("MIDPOINT_RIG_CHECK ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

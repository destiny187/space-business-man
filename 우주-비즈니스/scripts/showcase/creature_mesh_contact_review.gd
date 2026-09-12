extends "res://scripts/showcase/creature_batch_review.gd"
## Targeted skin/terrain reproduction, separate from the ordinary evidence files.
func review_batch(form: Dictionary) -> void:
	folder=ProjectSettings.globalize_path("res://../output/creature-remodel/mesh-contact")
	DirAccess.make_dir_recursive_absolute(folder)
	if "--knee-support" in OS.get_cmdline_user_args():form.motion_profile.knee_clearance=.16
	if "--body-support" in OS.get_cmdline_user_args():
		var prototype: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/prototype-profiles.json"))[form.id]
		form.motion_profile=prototype.get("motion_profile",prototype)
		form.body_support_version=int(prototype.get("version",2))
	if "--full-motion" in OS.get_cmdline_user_args():
		folder+="/full-motion";DirAccess.make_dir_recursive_absolute(folder)
		await super.review_batch(form)
		return
	var actor:=make_actor(form);var motion=actor.ground_motion
	var original:=FrontierEcologyCatalog.form(form.source_id)
	var host:=FrontierWildlifeCombat.profile({"form_id":original.id,"look_id":FrontierEcologyCatalog.look_for_seed(original.id,0),"combat_tier":5})
	var at:=Vector3(0,height(0,0),0)
	actor.drive_ground(at,frame_at(at,0),1./30.,probe,false,0);actor._process(1./30.);actor.set_state("move")
	var steps:=111
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mesh-steps="):steps=int(arg.trim_prefix("--mesh-steps="))
	for i in steps:
		var speed: float=motion.natural(form.motion_profile)
		if i>=45:speed=lerpf(speed,float(host.speed),smoothstep(45,65,i))
		at.z+=speed/30.;at.y=height(at.x,at.z)
		actor.drive_ground(at,frame_at(at,0),1./30.,probe,false,0);actor._process(1./30.)
	center_camera(actor,form);title.text=form.name;caption.text="실제 스킨과 경사면 접촉 확인"
	await photograph(form.id,"run")
	var samples: Array=[];var by_bone: Dictionary={}
	var skeleton: Skeleton3D=actor.anatomical_skeletons[0]
	var limb_positions: Array=[]
	for limb in motion.authored_limbs:
		var points: Dictionary={"name":limb.name,"sole":limb.sole}
		for key in ["upper","lower","foot"]:
			var point: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(limb[key])).origin
			points[key]=[point.x,point.y,point.z];points[key+"_clearance"]=point.y-height(point.x,point.z)
		limb_positions.append(points)
	for node in actor.models[0].find_children("*","MeshInstance3D",true,false):
		var instance: MeshInstance3D=node
		if instance.skin==null:continue
		var baked: ArrayMesh=instance.bake_mesh_from_current_skeleton_pose()
		for surface in baked.get_surface_count():
			var vertices: PackedVector3Array=baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var original_arrays: Array=instance.mesh.surface_get_arrays(surface)
			var weights: PackedFloat32Array=original_arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array=original_arrays[Mesh.ARRAY_BONES]
			var influences: int=weights.size()/vertices.size()
			for index in vertices.size():
				var point: Vector3=instance.global_transform*vertices[index]
				var penetration:=height(point.x,point.z)-point.y
				if penetration<=.005:continue
				var greatest:=0.0;var owner:=""
				for weight in influences:
					if weights[index*influences+weight]>greatest:
						greatest=weights[index*influences+weight]
						var bind: int=bones[index*influences+weight]
						owner=instance.skin.get_bind_name(bind)
						if owner.is_empty():owner=skeleton.get_bone_name(instance.skin.get_bind_bone(bind))
				samples.append({"penetration":penetration,"bone":owner,"weight":greatest,"point":[point.x,point.y,point.z],"surface":surface,"mesh":instance.name})
				by_bone[owner]=maxf(float(by_bone.get(owner,0.)),penetration)
	samples.sort_custom(func(a,b):return float(a.penetration)>float(b.penetration))
	var count:=samples.size();samples.resize(mini(20,count))
	report.append({"id":form.id,"penetrating_vertices":count,"deepest":samples,"by_bone":by_bone,"foot_error":motion.grounded_error,"body_error":motion.body_contact_error,"joint_error":motion.joint_contact_error,"limbs":limb_positions,"base_scale":actor.base_scale})
	print("MESH_CONTACT ",form.id,"; bones=",JSON.stringify(by_bone),"; foot=",motion.grounded_error,"; knee=",motion.joint_contact_error);actor.free()

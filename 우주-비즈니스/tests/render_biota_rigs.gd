extends "res://tests/render_xenofauna.gd"
## Debug overlay of actual Skeleton3D bone poses, separate from gameplay visuals.
func run() -> void:
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/biota_preview_forms.json")).forms
	var ids: Array=["biota_chain_armor_01","biota_radial_siphons_09","biota_plant_fern_01","biota_microbe_scroll_50"]
	var destination_path:="res://../docs/production/media/biota/rigs/";DirAccess.make_dir_recursive_absolute(destination_path)
	studio=load("res://scripts/showcase/ink_samples.gd").new();root.add_child(studio);studio.helper.hide()
	root.content_scale_size=Vector2i(1440,1200)
	for id in ids:
		var found: Array=rows.filter(func(r):return r.id==id)
		if found.is_empty():quit(2);return
		var form: Dictionary=found[0]
		studio.samples=[{"id":form.id,"title":"유형별 골격 · "+form.family_name,"name":"실제 스킨 본 위치 · "+str(form.rig.bone_count)+"개 본 · "+str(form.rig.layout),"foliage":form.category=="plant","model":"res://"+str(form.lods.near.path).trim_prefix("우주-비즈니스/")}]
		studio.select_sample(0);var original: Node3D=studio.subject;studio.stage.remove_child(original);original.free()
		var actor:=Actor.new();actor.load_far=false;actor.show_effects=false;studio.stage.add_child(actor);studio.subject=actor;actor.configure(form);actor.paused=true;actor.set_process(false);actor.set_state("feed");actor.elapsed=.9;actor.pose()
		await draw()
		var skeleton: Skeleton3D=actor.anatomical_skeletons[0]
		var overlay:=Node3D.new();actor.add_child(overlay)
		var line_material:=StandardMaterial3D.new();line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;line_material.albedo_color=Color("17e4cf");line_material.no_depth_test=true;line_material.render_priority=20
		var dot_material:=line_material.duplicate();dot_material.albedo_color=Color("e95723")
		var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var radius: float=maxf(.014,(float(form.geometry.near.max[1])-float(form.geometry.near.min[1]))*.014)
		var sphere:=SphereMesh.new();sphere.radius=radius;sphere.height=radius*2;sphere.radial_segments=8;sphere.rings=4
		for bone in skeleton.get_bone_count():
			var point: Vector3=overlay.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin)
			var bead:=MeshInstance3D.new();bead.mesh=sphere;bead.material_override=dot_material;bead.position=point;overlay.add_child(bead)
			var parent:=skeleton.get_bone_parent(bone)
			if parent<0:continue
			mesh.surface_add_vertex(point);mesh.surface_add_vertex(overlay.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(parent).origin))
		mesh.surface_end();var lines:=MeshInstance3D.new();lines.mesh=mesh;lines.material_override=line_material;overlay.add_child(lines)
		await draw();await draw();root.get_texture().get_image().save_png(destination_path+id+".png")
		print("BIOTA_RIG_VIEW ",id," ",skeleton.get_bone_count())
	quit()

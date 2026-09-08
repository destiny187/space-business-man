extends "res://tests/render_ink_followups.gd"
func capture_followups() -> void:
	var base:="res://../docs/production/media/ink-life/"
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base+"baseline.json")).render_style
	var next:=FrontierInkStyle.config()
	for mode in ["before","after"]:
		var values:Dictionary=original if mode=="before" else next
		var folder:String=base+"lines-"+mode+"/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		for key in ["inner_width","crease_depth_floor","distant_ink_strength"]:contour.set_shader_parameter(key,values[key])
		contour.set_shader_parameter("small_feature_strength",1.0 if mode=="before" else values.small_feature_strength)
		# capture_mixed configures the actual game distance fades; override per variant below.
		await capture_mixed(folder,values)
		if mode=="before":
			for child in stage.get_children():stage.remove_child(child);child.queue_free()
			subject=Node3D.new();stage.add_child(subject)
	print("INK_READABILITY_COMPLETE")
	get_tree().quit()

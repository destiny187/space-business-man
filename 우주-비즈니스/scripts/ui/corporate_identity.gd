class_name FrontierCorporateIdentity
extends RefCounted
## One visual language for operator and manufacturer; an unknown role has no borrowed logo.
static func frame_preview(preview: FrontierEquipmentPreview,asset_id: String) -> void:
	var extent:=0.0
	var bounds:=AABB();var first:=true
	for node in preview.model.find_children("*","MeshInstance3D",true,false):
		var box: AABB=node.global_transform*node.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	extent=bounds.size.length()
	preview.camera.size=extent*(.50 if asset_id in ["space_y_port","space_y_earth_port"] else .82)
	preview.camera.position=Vector3(1,.55,1.65 if asset_id in ["mine_miner","coopertech_robot","space_y_port","space_y_earth_port"] else -1.65).normalized()*extent*3
	preview.camera.look_at(Vector3.ZERO)
	var weak:=preview.model.find_child("Anim_Weak",true,false)
	if weak!=null:weak.hide()
	preview.request_render()
static func add_to(parent: Control,asset_id: String) -> void:
	var group:=VBoxContainer.new();parent.add_child(group)
	for role in FrontierCorporations.affiliations(asset_id):
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);group.add_child(row)
		var icon:=TextureRect.new();icon.custom_minimum_size=Vector2(28,28);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not FrontierCorporations.company(role.id).is_empty():icon.texture=load(FrontierCorporations.icon_path(role.id))
		else:icon.texture=load("res://assets/ui/interface/crew.svg") if role.id=="crew" and ResourceLoader.exists("res://assets/ui/interface/crew.svg") else null
		row.add_child(icon)
		FrontierInterfaceStyle.label(row,role.role+"  "+role.name,14,FrontierInterfaceStyle.MUTED if role.id=="" else FrontierInterfaceStyle.TEXT)

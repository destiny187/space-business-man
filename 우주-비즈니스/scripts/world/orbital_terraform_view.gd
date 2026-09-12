class_name FrontierOrbitalTerraformView
extends RefCounted
static func material(mat: ShaderMaterial,summary: Dictionary,airmap: Texture2D=null) -> void:
	var cfg:=FrontierOrbitalTerraform.config()
	var points:=PackedVector4Array();var values:=PackedVector4Array()
	for patch in summary.get("patches",[]):
		var p: Array=patch.point;var v: Array=patch.values
		points.append(Vector4(p[0],p[1],p[2],p[3]));values.append(Vector4(v[0],v[1],v[2],v[3]))
	var count:=points.size();points.resize(16);values.resize(16)
	mat.set_shader_parameter("terraform_count",count)
	mat.set_shader_parameter("terraform_points",points);mat.set_shader_parameter("terraform_values",values)
	mat.set_shader_parameter("terraform_land",Color(cfg.land_color));mat.set_shader_parameter("terraform_highland",Color(cfg.highland_color))
	mat.set_shader_parameter("terraform_sea",Color(cfg.sea_color));mat.set_shader_parameter("terraform_air",Color(cfg.atmosphere_color))
	mat.set_shader_parameter("terraform_sea_level",cfg.restored_sea_level);mat.set_shader_parameter("terraform_cloud_coverage",cfg.cloud_coverage)
	mat.set_shader_parameter("terraform_airmap_enabled",not summary.get("air_cells",[]).is_empty())
	if airmap!=null:mat.set_shader_parameter("terraform_airmap",airmap)
static func apply(node: Node,body: Dictionary,summary: Dictionary,airmap: Texture2D=null) -> void:
	if not FrontierUniverse.landable(body):return
	if airmap==null:
		var size: Array=summary.get("air_size",[1,1]);var pixels:=Image.create(int(size[0]),int(size[1]),false,Image.FORMAT_RGF);pixels.fill(Color(0,0,0,1))
		for cell in summary.get("air_cells",[]):pixels.set_pixel(int(cell[0])%int(size[0]),int(cell[0])/int(size[0]),Color(float(cell[1]),float(cell[2]),0,1))
		airmap=ImageTexture.create_from_image(pixels)
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var mat: ShaderMaterial=node.material_override
		if mat.shader.resource_path in ["res://assets/materials/space/planet.gdshader","res://assets/materials/space/atmosphere.gdshader","res://assets/materials/space/cloud_shell.gdshader"]:
			material(mat,summary,airmap)
			if node.name=="OrbitalAtmosphere":node.visible=not summary.is_empty() or float(mat.get_shader_parameter("density"))>.005
	for child in node.get_children():apply(child,body,summary,airmap)

static func preview_shells(node: Node3D,body: Dictionary) -> void:
	if node is MeshInstance3D:
		var atmosphere:=MeshInstance3D.new();atmosphere.mesh=node.mesh;atmosphere.scale=Vector3.ONE*1.018
		var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/atmosphere.gdshader")
		mat.set_shader_parameter("tint",Color(body.traits.sea).lightened(.35))
		atmosphere.material_override=mat;atmosphere.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_child(atmosphere)
	var presentation:=FrontierOrbitalPresentation.new();presentation._decorate(node,body,1.0);presentation.free()
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.name=="OrbitalAtmosphere":mesh.material_override.set_shader_parameter("space_sun",Vector3(-50,40,70))

static func focus_preview(node: Node3D,summary: Dictionary) -> void:
	if summary.get("patches",[]).is_empty():return
	var p: Array=summary.patches[0].point
	node.quaternion=Quaternion(Vector3(p[0],p[1],p[2]).normalized(),Vector3(0,.1,1).normalized())

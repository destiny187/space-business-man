class_name FrontierInkStyle
extends RefCounted
## Production ink-v1. Game and catalogue must use this same adapter and shaders.
const CEL = preload("res://assets/materials/ink/cel.gdshader")
const CONTOUR = preload("res://assets/materials/ink/contour.gdshader")
static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/render_style.json"))
	return _config

static func material(original: StandardMaterial3D, cache: Dictionary) -> Material:
	# Transparent construction ghosts, vapour and additive effects retain their blending.
	if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return original
	var key := original.get_instance_id()
	if cache.has(key): return cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = CEL
	mat.resource_name = original.resource_name
	var roughness := original.roughness
	var label := original.resource_name.to_lower()
	if label.contains("edge steel"): roughness = .27
	elif label.contains("graphite"): roughness = .52
	elif label.contains("ceramic enamel"): roughness = .34
	mat.set_shader_parameter("base_color",original.albedo_color)
	mat.set_shader_parameter("rough",roughness)
	mat.set_shader_parameter("metal",original.metallic)
	mat.set_shader_parameter("use_vertex_color",original.vertex_color_use_as_albedo)
	mat.set_shader_parameter("emission_color",original.emission)
	mat.set_shader_parameter("emission_strength",original.emission_energy_multiplier if original.emission_enabled else 0.)
	cache[key] = mat
	return mat

static func apply(node: Node, cache: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(surface)
			if original is StandardMaterial3D:
				node.set_surface_override_material(surface,material(original,cache))
	for child in node.get_children(): apply(child,cache)

static func attach(parent: Node3D, studio: bool = false) -> ShaderMaterial:
	var quad := MeshInstance3D.new()
	quad.name = "InkContours"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2,2)
	quad.mesh = mesh
	quad.extra_cull_margin = 1000
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = CONTOUR
	mat.render_priority = 100
	mat.set_shader_parameter("strength",1.0)
	for key in ["outer_width","inner_width","reference_height","crease_depth_floor","distant_ink_strength"]:
		mat.set_shader_parameter(key,float(config()[key]))
	var fade: Array = config().crease_fade
	mat.set_shader_parameter("crease_fade",Vector2(1000,2000) if studio else Vector2(fade[0],fade[1]))
	var outer_fade: Array = config().outline_fade
	mat.set_shader_parameter("outline_fade",Vector2(1000,2000) if studio else Vector2(outer_fade[0],outer_fade[1]))
	mat.set_shader_parameter("ink",Color(config().ink))
	quad.material_override = mat
	parent.add_child(quad)
	return mat

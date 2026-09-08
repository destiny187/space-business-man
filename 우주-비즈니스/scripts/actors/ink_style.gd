class_name FrontierInkStyle
extends RefCounted
## Production ink-v1. Game and catalogue must use this same adapter and shaders.
const CEL = preload("res://assets/materials/ink/cel.gdshader")
const CONTOUR = preload("res://assets/materials/ink/contour.gdshader")
static var _config: Dictionary = {}
static var _material_roles: Dictionary = {}

static func material_role(label: String) -> Dictionary:
	if _material_roles.is_empty():
		var preset: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ink_materials.json"))
		for role in preset.roles:
			var spec: Dictionary = preset.roles[role]
			_material_roles["INK::"+role] = spec
			for alias in spec.legacy_names: _material_roles[alias] = spec
	return _material_roles.get(label,{})

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
	# Exact industrial roles only: preserve species colours, process signals and paint data.
	var role := material_role(original.resource_name)
	if not role.is_empty() and not original.vertex_color_use_as_albedo and not label.ends_with("_vertex_paint") and not original.emission_enabled:
		var rgb: Array = role.color_linear
		mat.set_shader_parameter("base_color",Color(rgb[0],rgb[1],rgb[2],original.albedo_color.a).linear_to_srgb())
		mat.set_shader_parameter("rough",float(role.roughness))
		mat.set_shader_parameter("metal",float(role.metallic))
		mat.set_shader_parameter("highlight_strength",float(role.highlight_strength))
	mat.set_shader_parameter("use_vertex_color",original.vertex_color_use_as_albedo or label.ends_with("_vertex_paint"))
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
	# Composite opaque ink before transparent ghosts, particles and labels.
	# The screen texture does not contain transparent draws; a late pass erases them.
	mat.render_priority = -128
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

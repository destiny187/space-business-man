extends SceneTree
## Regression: a rubber tyre must not inherit the legacy graphite metal highlight.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var original := StandardMaterial3D.new()
	original.resource_name="Soft graphite tyre";original.roughness=.9
	var tyre := FrontierInkStyle.material(original,{}) as ShaderMaterial
	assert(is_equal_approx(tyre.get_shader_parameter("rough"),.9))
	assert(is_equal_approx(tyre.get_shader_parameter("highlight_strength"),.1))
	var imported: Node3D=load("res://assets/models/vehicles/scout_rover.glb").instantiate()
	FrontierInkStyle.apply(imported,{})
	var count := 0
	for mesh in imported.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var mat: Material=mesh.get_active_material(i)
			if mat.resource_name=="INK::rubber":
				assert(is_equal_approx(mat.get_shader_parameter("rough"),.9))
				assert(is_equal_approx(mat.get_shader_parameter("highlight_strength"),.1));count+=1
	assert(count==4,"Every exported wheel retains its independent rubber surface")
	var cream := StandardMaterial3D.new();cream.resource_name="Ceramic enamel"
	var painted := FrontierInkStyle.material(cream,{}) as ShaderMaterial
	var expected := Color(.70,.73,.60).linear_to_srgb()
	assert((painted.get_shader_parameter("base_color") as Color).is_equal_approx(expected))
	# Authored signals, vertex paint and transparency are outside the industrial remap.
	cream.emission_enabled=true;cream.albedo_color=Color.RED
	assert(FrontierInkStyle.material(cream,{}).get_shader_parameter("base_color")==Color.RED)
	cream.emission_enabled=false;cream.vertex_color_use_as_albedo=true
	assert(FrontierInkStyle.material(cream,{}).get_shader_parameter("base_color")==Color.RED)
	cream.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	assert(FrontierInkStyle.material(cream,{})==cream)
	imported.free();print("INK_MATERIAL_ROLES_OK / rubber, imported roles, linear colour, signal/vertex/alpha preservation");quit()

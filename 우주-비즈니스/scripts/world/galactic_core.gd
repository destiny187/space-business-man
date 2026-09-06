class_name FrontierGalacticCore
extends Node3D
## Stylized black hole; no claim of physical gravitational lensing simulation.
func _ready() -> void:
	var model: Node3D=load("res://assets/models/galactic-core/central_black_hole.glb").instantiate()
	add_child(model);FrontierInkStyle.apply(model,{})
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material=mesh.get_active_material(surface)
			if String(mesh.name).begins_with("Event_horizon"):
				if original is ShaderMaterial:original.set_shader_parameter("highlight_strength",0.0);original.set_shader_parameter("base_color",Color.BLACK)
				continue
			var effect:=ShaderMaterial.new()
			effect.shader=load("res://assets/materials/galactic-core/plasma.gdshader" if String(mesh.name).begins_with("Polar") else "res://assets/materials/galactic-core/accretion.gdshader")
			effect.set_shader_parameter("lens",String(mesh.name).begins_with("Lensed"))
			effect.set_shader_parameter("energy",1.1 if String(mesh.name).contains("-1") else 2.6)
			mesh.set_surface_override_material(surface,effect)

static func preview(parent: Node,size_value: int=256,transparent: bool=false) -> SubViewport:
	var viewport:=SubViewport.new();viewport.size=Vector2i(size_value,size_value);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA;viewport.transparent_bg=transparent;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;parent.add_child(viewport)
	var core:=FrontierGalacticCore.new();viewport.add_child(core)
	var stars:=MultiMeshInstance3D.new();var cloud:=MultiMesh.new();cloud.transform_format=MultiMesh.TRANSFORM_3D;cloud.use_colors=true
	var star_mesh:=SphereMesh.new();star_mesh.radius=.009;star_mesh.height=.018;star_mesh.radial_segments=8;star_mesh.rings=4
	var star_mat:=StandardMaterial3D.new();star_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;star_mat.vertex_color_use_as_albedo=true;star_mesh.material=star_mat;cloud.mesh=star_mesh;cloud.instance_count=320
	var rng:=RandomNumberGenerator.new();rng.seed=830711
	for i in cloud.instance_count:
		var transform:=Transform3D.IDENTITY.scaled(Vector3.ONE*rng.randf_range(.5,1.8));transform.origin=Vector3(rng.randf_range(-9,9),rng.randf_range(-9,9),-8)
		cloud.set_instance_transform(i,transform);cloud.set_instance_color(i,Color("c2dded") if i%3 else Color("ddbf93"))
	stars.multimesh=cloud;viewport.add_child(stars)
	var camera:=Camera3D.new();camera.position=Vector3(0,2.7,13);camera.look_at_from_position(camera.position,Vector3.ZERO);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=11.2;camera.near=.05;viewport.add_child(camera);camera.current=true
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-20,0);viewport.add_child(light)
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("02040a");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=.2;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.glow_enabled=true;env.glow_intensity=1.1;env.glow_bloom=.12;world.environment=env;viewport.add_child(world)
	return viewport

class_name FrontierSystemLandmarks
extends Node3D
var moon_nodes: Array=[]
var belt: Node3D
static func mesh_from(path: String) -> Mesh:
	var scene: Node=load(path).instantiate()
	var meshes:=scene.find_children("*","MeshInstance3D",true,false)
	var result: Mesh=scene.mesh if scene is MeshInstance3D else meshes[0].mesh
	scene.free();return result
static func material(color: Color) -> ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=load("res://assets/materials/ink/cel.gdshader")
	result.set_shader_parameter("base_color",color);result.set_shader_parameter("rough",.95);result.set_shader_parameter("highlight_strength",.08)
	return result
func configure(manifest: Dictionary,index: int,planets: Dictionary) -> void:
	var layout:=FrontierUniverse.system_layout(manifest,index)
	if not manifest.settings.has("system_rules") or index==0:return
	var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(manifest.seed),"landmark-v1:%d"%index)
	var moon_mesh:=mesh_from("res://assets/models/planet-variants/cratered.glb")
	for entry in planets.values():
		var body: Dictionary=entry.body
		if body.get("rings",false):
			var rings:=MeshInstance3D.new();rings.name="PlanetRings";rings.mesh=mesh_from("res://assets/models/system-landmarks/planet_rings.glb")
			rings.material_override=material(Color(body.traits.dust).lightened(.18));rings.rotation_degrees=Vector3(rng.randf_range(18,38),0,rng.randf_range(-15,15));entry.node.add_child(rings)
		for i in int(body.get("moons",0)):
			var moon:=MeshInstance3D.new();moon.name="Moon_%d"%i;moon.mesh=moon_mesh;moon.scale=Vector3.ONE*FrontierUniverse.moon_radius(body,i)/FrontierUniverse.radius(body)
			var lunar:=ShaderMaterial.new();lunar.shader=load("res://assets/materials/space/planet.gdshader")
			lunar.set_shader_parameter("authored_relief",true);lunar.set_shader_parameter("land_color",Color("aaa498"));lunar.set_shader_parameter("rock_color",Color("535564"));lunar.set_shader_parameter("cloud_amount",0.0);lunar.set_shader_parameter("sea_level",0.0);lunar.set_shader_parameter("highlight_strength",.05)
			moon.material_override=lunar;entry.node.add_child(moon)
			moon_nodes.append({"node":moon,"body":body,"index":i})
	if float(layout.belt_radius)>0:
		belt=Node3D.new();belt.name="AsteroidBelt";add_child(belt)
		var kinds: Array=["asteroid_ridge","asteroid_split","asteroid_flat"]
		for kind in kinds:
			var field:=MultiMeshInstance3D.new();var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh_from("res://assets/models/system-landmarks/"+kind+".glb")
			multi.instance_count=int(manifest.settings.system_rules.asteroid_instances)/3;field.multimesh=multi;field.material_override=material(Color("918475"));belt.add_child(field)
			for i in multi.instance_count:
				var angle:=rng.randf_range(0,TAU);var radius: float=layout.belt_radius+rng.randf_range(-750,750)
				var position:=Vector3(cos(angle)*radius,rng.randf_range(-180,180),sin(angle)*radius)
				var basis:=Basis.from_euler(Vector3(rng.randf_range(0,TAU),rng.randf_range(0,TAU),rng.randf_range(0,TAU))).scaled(Vector3.ONE*rng.randf_range(65,210))
				multi.set_instance_transform(i,Transform3D(basis,position))
	update_epoch(0)
func update_epoch(elapsed: float) -> void:
	for entry in moon_nodes:
		entry.node.position=FrontierUniverse.moon_offset(entry.body,entry.index,elapsed)/FrontierUniverse.radius(entry.body)
	if belt!=null:belt.rotation.y=fmod(elapsed*.000015,TAU)

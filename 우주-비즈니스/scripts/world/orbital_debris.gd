class_name FrontierOrbitalDebris
extends Node3D
## Deterministic local cells: geometry recycles outside the visible radius only.
var flight: FrontierSpaceFlight
var fields: Array[MultiMeshInstance3D]=[]
var cell:=Vector3i(2147483647,0,0)
var ring_target: Node3D
var kind: String=""
var system_seed:=0
var belt_radius:=0.0
var settings: Dictionary={}
var field_origin:=Transform3D.IDENTITY
var ring_radius:=0.0
func configure(view: FrontierSpaceFlight) -> void:
	settings=FrontierOrbitalPresentation.config().debris
	flight=view;system_seed=FrontierUniverse.derive(int(view.state.manifest.seed),"orbital-detail:%d"%view.current_system)
	belt_radius=FrontierUniverse.system_layout(view.state.manifest,view.current_system).belt_radius
	for id in ["orbital_rock","orbital_ice"]:
		var field:=MultiMeshInstance3D.new();field.name=id;var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=FrontierSystemLandmarks.mesh_from(settings.ice_model if id=="orbital_ice" else settings.rock_model);multi.instance_count=int(settings.max_fragments);multi.visible_instance_count=0
		field.multimesh=multi
		var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/debris.gdshader")
		mat.set_shader_parameter("base_color",Color("a6cbd3") if id=="orbital_ice" else Color("93816e"));mat.set_shader_parameter("highlight_strength",.25 if id=="orbital_ice" else .08)
		mat.set_shader_parameter("fade_near",settings.fade_near);mat.set_shader_parameter("fade_far",minf(float(settings.fade_far),float(settings.cell_size)*5.0))
		field.material_override=mat;field.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(field);fields.append(field)
func _process(_delta: float) -> void:
	if flight==null or flight.camera==null:return
	var camera_point:=flight.camera.global_position
	var selected: Dictionary={};var closest:=INF
	for ring in flight.orbital_presentation.rings:
		if not is_instance_valid(ring.node) or not ring.node.is_visible_in_tree():continue
		var p: Vector3=ring.node.global_basis.orthonormalized().inverse()*(camera_point-ring.planet.global_position)
		var radius: float=ring.radius
		var gap:=maxf(0,absf(Vector2(p.x,p.z).length()-radius*1.78)-radius*.48)
		var distance:=Vector2(gap,p.y).length()
		if distance<closest:selected=ring;closest=distance
	var next_kind: String=""
	if closest<float(settings.ring_activation_distance):next_kind="ring"
	elif belt_radius>0 and absf(Vector2(camera_point.x,camera_point.z).length()-belt_radius)<1700 and absf(camera_point.y)<1200:next_kind="belt"
	if next_kind.is_empty():
		for field in fields:field.hide()
		kind="";return
	var next_target: Node3D=selected.node if next_kind=="ring" else null
	if next_kind!=kind or next_target!=ring_target:cell=Vector3i(2147483647,0,0)
	kind=next_kind;ring_target=next_target
	field_origin=Transform3D(ring_target.global_basis.orthonormalized(),selected.planet.global_position) if kind=="ring" else Transform3D.IDENTITY
	ring_radius=float(selected.radius) if kind=="ring" else belt_radius
	global_transform=field_origin
	var local_point:=to_local(camera_point)
	var cell_size:=float(settings.cell_size)
	var next:=Vector3i(floor(local_point.x/cell_size),0,floor(local_point.z/cell_size))
	if next!=cell:cell=next;_rebuild(cell_size)
	for i in fields.size():
		fields[i].visible=(i==1 if kind=="ring" else i==0)
		var mat: ShaderMaterial=fields[i].material_override
		mat.set_shader_parameter("space_lighting",true);mat.set_shader_parameter("space_sun",flight.to_global(Vector3.ZERO))
		mat.set_shader_parameter("space_sun_radius",flight.orbital_presentation.star_radius)
		var occluders:=PackedVector4Array();occluders.resize(8)
		if kind=="ring":
			var p: Vector3=selected.planet.global_position;occluders[0]=Vector4(p.x,p.y,p.z,ring_radius);mat.set_shader_parameter("space_occluder_count",1)
		else:mat.set_shader_parameter("space_occluder_count",0)
		mat.set_shader_parameter("space_occluders",occluders)
func _rebuild(cell_size: float) -> void:
	var multi:=fields[1 if kind=="ring" else 0].multimesh
	var count:=0
	for z in range(-5,6):
		for x in range(-5,6):
			var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(system_seed,"%s:%d:%d"%[kind,cell.x+x,cell.z+z])
			for i in 5:
				var p:=Vector3((cell.x+x+rng.randf())*cell_size,rng.randf_range(-18,18) if kind=="ring" else rng.randf_range(-260,260),(cell.z+z+rng.randf())*cell_size)
				var radius:=Vector2(p.x,p.z).length()
				if kind=="ring" and (radius<ring_radius*1.3 or radius>ring_radius*2.25):continue
				if kind=="belt" and absf(radius-belt_radius)>1000:continue
				var scale_value:=rng.randf_range(1.2,7.0) if kind=="ring" else rng.randf_range(3.0,16.0)
				var basis:=Basis.from_euler(Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU)).scaled(Vector3.ONE*scale_value)
				if count<multi.instance_count:multi.set_instance_transform(count,Transform3D(basis,p));count+=1
	multi.visible_instance_count=count

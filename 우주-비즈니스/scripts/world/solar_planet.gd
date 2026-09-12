class_name FrontierSolarPlanet
extends Node3D
## Blender bodies, rings and cloud shells; appearance never changes world generation.
const ASSETS := ["mercury","venus","earth","mars","jupiter","saturn","uranus","neptune"]
var detail: Node3D
var distant: Node3D
var surfaces: Array[Node3D]=[]
var clouds: Array[Node3D]=[]
var body_radius:=1.0
var index:=0
var cache: Dictionary={}
func configure(ordinal: int,radius: float,body: Dictionary={}) -> void:
	index=ordinal;body_radius=radius
	var restored:=FrontierUniverse.restored_mars(body)
	var asset: String="mars_restored" if restored else ASSETS[index]
	for suffix in ["","_lod1"]:
		var model: Node3D=load("res://assets/models/solar-system/"+asset+suffix+".glb").instantiate()
		model.scale=Vector3.ONE*radius;add_child(model);FrontierInkStyle.apply(model,cache)
		if suffix.is_empty():detail=model
		else:distant=model;model.hide()
		for node in model.find_children("Anim_Surface","Node3D",true,false):surfaces.append(node)
		for node in model.find_children("Anim_Clouds","Node3D",true,false):clouds.append(node)
	# Reuse each Blender body's actual oblate/tilted mesh for its atmospheric shell.
	# A separate spherical shell floats above Saturn's flattened poles.
	if index in [1,2,3,4,5,6,7]:
		for surface in surfaces:
			var shell:=MeshInstance3D.new();shell.mesh=surface.mesh;shell.scale=Vector3.ONE*1.012
			var air:=ShaderMaterial.new();air.shader=load("res://assets/materials/space/atmosphere.gdshader")
			air.set_shader_parameter("tint",Color("679dd0") if restored or index in [2,6,7] else Color("c7ab80"));shell.material_override=air;shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;surface.add_child(shell)
	for model in [detail,distant]:
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var mat: Material=mesh.get_active_material(surface)
				if mat is ShaderMaterial and mat.shader==FrontierInkStyle.CEL:
					mat.set_shader_parameter("highlight_strength",.08)
					if "_vertex_paint" in mat.resource_name:mat.set_shader_parameter("use_vertex_color",true)

	# Only the body paint receives orbital detail; rings/structures retain their materials.
	for surface in surfaces:
		var mat:=surface.get_active_material(0).duplicate() as ShaderMaterial
		mat.shader=load("res://assets/materials/space/solar_planet.gdshader")
		FrontierOrbitalSurface.configure(mat,asset,true)
		mat.set_shader_parameter("orbital_gaseous",index==1 or index>=4)
		surface.material_override=mat

func set_epoch(elapsed: float,body: Dictionary={}) -> void:
	if body.get("astro",{}).get("enabled",false):
		# Replace the source's illustrative tilt; do not add a second obliquity.
		for model in [detail,distant]:
			if str(model.name).begins_with("Solar_"):model.rotation=Vector3.ZERO
			for pivot in model.find_children("Solar_*","Node3D",true,false):pivot.rotation=Vector3.ZERO
		basis=FrontierPlanetaryCycles.orientation(body,elapsed)
		for surface in surfaces:surface.rotation=Vector3.ZERO
		for cloud in clouds:cloud.rotation.y=fposmod(elapsed*.001,TAU)
		return
	# Illustrative spin is shared across clients; no real-time ephemeris claim.
	var speed:=.006 if index not in [1,6] else -.003
	for surface in surfaces:surface.rotation.y=fmod(elapsed*speed,TAU)
	for cloud in clouds:cloud.rotation.y=fmod(elapsed*(speed+.001),TAU)
func _process(_delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if camera==null or detail==null:return
	var far_away: bool=camera.global_position.distance_to(global_position)>body_radius*12
	detail.visible=not far_away;distant.visible=far_away

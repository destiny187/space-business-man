class_name FrontierOrbitalPresentation
extends Node
## Visual-only atmosphere, celestial shadows and galaxy orientation.
static var rules: Dictionary={}
var view: FrontierSpaceFlight
var receivers: Array=[]
var spheres: Array=[]
var rings: Array=[]
var elapsed:=0.0
var refresh_left:=0.0
var ship_refresh:=0.0
var star_radius:=1500.0
static func config() -> Dictionary:
	if rules.is_empty():rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_polish.json"))
	return rules
func configure(flight: FrontierSpaceFlight) -> void:
	view=flight;receivers.clear();spheres.clear();rings.clear()
	star_radius=FrontierUniverse.system_layout(view.state.manifest,view.current_system).star_radius
	for entry in view.planets.values():
		var radius:=FrontierUniverse.radius(entry.body)
		spheres.append({"node":entry.node,"radius":radius})
		_decorate(entry.node,entry.body,radius)
		collect(entry.node,entry.node,entry.node)
	if is_instance_valid(view.landmarks):
		for moon in view.landmarks.moon_nodes:
			spheres.append({"node":moon.node,"radius":FrontierUniverse.moon_radius(moon.body,moon.index)})
	if is_instance_valid(view.system_art):collect(view.system_art,null,null)
	collect(view.ship,null,null)
	_configure_sky()
	update(0.1,view.orbit_time)
func _decorate(node: Node3D,body: Dictionary,radius: float) -> void:
	if node.has_meta("orbital_polish"):return
	node.set_meta("orbital_polish",true)
	var t: Dictionary=body.get("traits",{})
	var solar: bool=body.get("origin","")=="solar_reference"
	var ordinal:=int(body.ordinal) if solar else -1
	var pressure: float=[0.0,8.0,1.0,.012,5.0,5.0,4.0,4.0][ordinal] if solar else float(t.get("pressure",0.0))
	var coverage: float=(.65 if ordinal==2 else 0.0) if solar else float(t.get("cloud",0))
	var restored:=FrontierCorporateOrbital.restored(body)
	if restored:pressure=float(body.management.pressure);coverage=float(body.management.cloud)
	var density:=clampf(pressure*float(config().atmosphere.pressure_scale),0,float(config().atmosphere.maximum_density))
	var surfaces: Array=[]
	if node is FrontierSolarPlanet:
		surfaces.assign(node.surfaces)
		for old in node.clouds:old.hide()
	else:surfaces.append(node)
	for surface in surfaces:
		var surface_material: Material=surface.material_override
		if surface_material==null and surface is MeshInstance3D:surface_material=surface.get_active_material(0)
		if surface_material is ShaderMaterial:
			surface_material.set_shader_parameter("separate_clouds",coverage>0)
			surface_material.set_shader_parameter("cloud_coverage",coverage)
			surface_material.set_shader_parameter("cloud_wind",config().clouds.wind_speed)
			surface_material.set_shader_parameter("cloud_seed",float(t.get("pattern_seed",body.seed%1000)))
			surface_material.set_shader_parameter("cloud_shadow_strength",config().clouds.shadow_strength)
			surface_material.set_shader_parameter("city_strength",float(body.management.city_strength) if restored else (.7 if ordinal==2 else 0.0))
		for child in surface.get_children():
			if child is MeshInstance3D and child.material_override is ShaderMaterial and child.material_override.shader==load("res://assets/materials/space/atmosphere.gdshader"):
				child.name="OrbitalAtmosphere";child.visible=density>.005
				child.scale=Vector3.ONE*(1.0+float(config().atmosphere.shell_height)*minf(density,1.0))
				child.material_override.set_shader_parameter("density",density)
		if coverage<=.01:continue
		var cloud:=MeshInstance3D.new();cloud.name="OrbitalCloudLayer";cloud.mesh=surface.mesh;cloud.scale=Vector3.ONE*(1.0+float(config().clouds.height))
		var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/cloud_shell.gdshader")
		mat.set_shader_parameter("cloud_coverage",coverage);mat.set_shader_parameter("cloud_seed",float(t.get("pattern_seed",body.seed%1000)))
		mat.set_shader_parameter("cloud_wind",config().clouds.wind_speed);mat.set_shader_parameter("planet_radius",radius)
		mat.set_shader_parameter("storm_strength",.6 if pressure>.4 else 0.0)
		mat.set_shader_parameter("highlight_strength",.04)
		cloud.material_override=mat;cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;surface.add_child(cloud)
func collect(node: Node,owner_body: Node3D=null,planet: Node3D=null) -> void:
	if node.name=="Anim_Clouds":return
	if str(node.name).begins_with("Moon_"):owner_body=node
	if node is MeshInstance3D:
		var is_ring:=str(node.name).to_lower().contains("ring")
		if is_ring and planet!=null:
			var ring_material:=ShaderMaterial.new();ring_material.shader=load("res://assets/materials/space/rings.gdshader")
			var original: Material=node.get_active_material(0)
			if original is ShaderMaterial:
				var color: Variant=original.get_shader_parameter("base_color")
				if color is Color:ring_material.set_shader_parameter("base_color",color)
			node.material_override=ring_material
			var radius: float=planet.global_basis.get_scale().abs().x
			if planet is FrontierSolarPlanet:radius=planet.body_radius
			rings.append({"node":node,"planet":planet,"radius":radius})
		var materials: Array=[]
		if node.material_override!=null:materials.append(node.material_override)
		elif node.mesh!=null:
			for i in node.mesh.get_surface_count():materials.append(node.get_active_material(i))
		for mat in materials:
			if not mat is ShaderMaterial:continue
			var path: String=mat.shader.resource_path
			if not (path.ends_with("cel.gdshader") or path.ends_with("planet.gdshader") or path.ends_with("atmosphere.gdshader") or path.ends_with("cloud_shell.gdshader") or path.ends_with("rings.gdshader")):continue
			var duplicate:=false
			for r in receivers:
				if r.mat==mat:duplicate=true;break
			if not duplicate:receivers.append({"mat":mat,"node":node,"owner":null if is_ring else owner_body,"planet":planet,"ring":is_ring})
	for child in node.get_children():collect(child,owner_body,planet)
func _configure_sky() -> void:
	var system:=FrontierUniverse.system(view.state.manifest,view.current_system)
	var map:=Vector2(float(system.map_position[0]),float(system.map_position[1]))
	var inward:=Vector3(-map.x,0,-map.y).normalized()
	var strength:=lerpf(float(config().sky.minimum_stars),float(config().sky.maximum_stars),float(system.progress))
	view.sky_material.set_shader_parameter("core_direction",inward)
	view.sky_material.set_shader_parameter("star_density",strength)
	view.sky_material.set_shader_parameter("nebula_strength",config().sky.nebula_strength)
	# Coherent galactic structure, with slow palette changes between sectors.
	view.sky_material.set_shader_parameter("sector_hue",fposmod(atan2(map.y,map.x)/TAU+1.0,1.0))
func update(delta: float,time_value: float) -> void:
	if view==null:return
	elapsed=time_value;refresh_left-=delta;ship_refresh-=delta
	if ship_refresh<=0:
		receivers=receivers.filter(func(r: Dictionary):return is_instance_valid(r.node))
		collect(view.ship,null,null);ship_refresh=1.0
	if refresh_left>0:return
	refresh_left=float(config().lighting.update_seconds)
	var sun:=view.to_global(Vector3.ZERO)
	for receiver in receivers:
		if not is_instance_valid(receiver.node):continue
		var mat: ShaderMaterial=receiver.mat
		mat.set_shader_parameter("space_lighting",true);mat.set_shader_parameter("space_sun",sun);mat.set_shader_parameter("space_sun_radius",star_radius)
		var candidates: Array=[]
		var point: Vector3=receiver.node.global_position
		for sphere in spheres:
			if sphere.node==receiver.owner or not is_instance_valid(sphere.node):continue
			var offset: Vector3=sphere.node.global_position-point
			# Order by angular size, so nearby moons outrank distant giants.
			candidates.append({"sphere":sphere,"size":float(sphere.radius)/maxf(1.0,offset.length())})
		candidates.sort_custom(func(a: Dictionary,b: Dictionary):return a.size>b.size)
		var occluders:=PackedVector4Array();occluders.resize(8)
		var count:=mini(candidates.size(),8)
		for i in count:
			var s: Dictionary=candidates[i].sphere;var p: Vector3=s.node.global_position
			occluders[i]=Vector4(p.x,p.y,p.z,s.radius)
		mat.set_shader_parameter("space_occluders",occluders);mat.set_shader_parameter("space_occluder_count",count)
		mat.set_shader_parameter("space_ring_radii",Vector2.ZERO)
		if not receiver.ring:
			var closest: Dictionary={};var distance:=INF
			for ring in rings:
				var d: float=ring.planet.global_position.distance_squared_to(point)
				if d<distance:closest=ring;distance=d
			if not closest.is_empty():
				mat.set_shader_parameter("space_ring_center",closest.planet.global_position)
				mat.set_shader_parameter("space_ring_normal",closest.node.global_basis.y.normalized())
				mat.set_shader_parameter("space_ring_radii",Vector2(1.3,2.25)*float(closest.radius))
		if receiver.planet!=null:
			mat.set_shader_parameter("body_center",receiver.planet.global_position)
			mat.set_shader_parameter("local_sun_direction",receiver.node.global_basis.inverse()*(sun-point).normalized())
		mat.set_shader_parameter("cloud_time",fposmod(elapsed,100000.0))

class_name FrontierSpaceCombatEffects
extends Node3D
## Short, bounded effects: moving tracers, directional shield waves and authored debris.
var items: Array=[]
var materials: Dictionary={}
const BLAST=preload("res://assets/materials/space/combat_blast.gdshader")
const SHIELD=preload("res://assets/materials/space/combat_shield.gdshader")
const LIMIT=180
var blast_pool: Array[MeshInstance3D]=[]
var blast_quad:=QuadMesh.new()
var line_mesh:=CylinderMesh.new()
var spark_mesh:=SphereMesh.new()
func _ready() -> void:
	blast_quad.size=Vector2.ONE
	line_mesh.top_radius=.45;line_mesh.bottom_radius=1;line_mesh.height=1;line_mesh.radial_segments=6
	spark_mesh.radius=1;spark_mesh.height=2;spark_mesh.radial_segments=8;spark_mesh.rings=4
	var blast_material:=ShaderMaterial.new();blast_material.shader=BLAST
	# Allocate the bounded burst resources while preparing the flight scene.
	for i in LIMIT:
		var node:=MeshInstance3D.new();node.mesh=blast_quad;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.material_override=blast_material;add_child(node);node.hide();blast_pool.append(node)
func release(row: Dictionary) -> void:
	if row.has("blast"):row.node.hide();blast_pool.append(row.node)
	else:row.node.queue_free()
func material(color: Color) -> StandardMaterial3D:
	if materials.has(color):return materials[color]
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=color
	if color.a<1:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=1.5
	materials[color]=m;return m
func mesh_node(mesh: Mesh,color: Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material(color);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node
func add(node: Node3D,life: float,velocity:=Vector3.ZERO,growth:=0.0,spin:=Vector3.ZERO) -> Dictionary:
	var row: Dictionary={"node":node,"life":life,"age":0.0,"velocity":velocity,"growth":growth,"spin":spin}
	items.append(row)
	while items.size()>LIMIT:release(items.pop_front())
	return row
func step(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	for i in range(items.size()-1,-1,-1):
		var row: Dictionary=items[i]
		row.age+=delta
		if row.age<0:continue
		row.node.show()
		if row.age>=row.life:release(row);items.remove_at(i);continue
		if is_instance_valid(row.get("follow")):row.node.global_transform=row.follow.global_transform
		row.node.position+=row.velocity*delta
		if row.spin.length_squared()>0:row.node.rotate_object_local(row.spin.normalized(),row.spin.length()*delta)
		row.node.scale+=Vector3.ONE*row.growth*delta
		if row.has("shield"):row.shield.set_shader_parameter("age",row.age)
		elif row.has("blast"):
			if camera!=null:
				var angle: float=row.angle
				if row.axis!=Vector3.ZERO:
					var axis: Vector3=camera.global_basis.inverse()*row.axis;angle=atan2(axis.y,axis.x)
				row.node.global_basis=camera.global_basis*Basis(Vector3.BACK,angle)
			var progress: float=row.age/row.life
			row.node.scale=Vector3(row.size.x,row.size.y,1)*lerpf(row.start_scale,row.end_scale,1.0-pow(1.0-progress,3))
			row.node.set_instance_shader_parameter("age",progress)
		elif row.node is GeometryInstance3D:row.node.transparency=smoothstep(row.life*.35,row.life,row.age)
		elif row.has("debris"):row.debris.transparency=smoothstep(row.life*.65,row.life,row.age)
func clear() -> void:
	for row in items:release(row)
	items.clear()
func line(source: Vector3,target: Vector3,color: Color,radius: float=.35,life: float=.1) -> void:
	var length:=source.distance_to(target)
	if length<.01:return
	var node:=mesh_node(line_mesh,color);node.scale=Vector3(radius,length,radius);node.position=(source+target)*.5;node.quaternion=Quaternion(Vector3.UP,(target-source).normalized());add(node,life)
func tracer(source: Vector3,target: Vector3,color: Color) -> void:
	var direction: Vector3=(target-source).normalized();var distance:=source.distance_to(target)
	# A bright head travels down a brief faint discharge, instead of a solid tube hanging in space.
	line(source,target,Color(color,.22),.15,.075)
	var mesh:=CylinderMesh.new();mesh.top_radius=.3;mesh.bottom_radius=.65;mesh.height=minf(23,distance);mesh.radial_segments=6
	var node:=mesh_node(mesh,color);node.position=source;node.quaternion=Quaternion(Vector3.UP,direction)
	add(node,minf(.13,distance/2800),direction*2800)
func spark(position: Vector3,color: Color,size: float,life: float,velocity:=Vector3.ZERO) -> void:
	var node:=mesh_node(spark_mesh,color);node.scale=Vector3.ONE*size;node.position=position;add(node,life,velocity,size*size*1.7)
func shield(position: Vector3,source: Vector3,radius: float,broken: bool=false,follow: Node3D=null) -> void:
	var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=40;mesh.rings=20
	var node:=MeshInstance3D.new();node.mesh=mesh;add_child(node);node.position=position
	var m:=ShaderMaterial.new();m.shader=SHIELD;m.set_shader_parameter("impact_direction",(source-position).normalized())
	m.set_shader_parameter("tint",Color("abfff0") if broken else Color("47cbbb"));m.set_shader_parameter("strength",1.5 if broken else 1.0)
	node.material_override=m;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var row:=add(node,.65);row.shield=m
	if is_instance_valid(follow):
		row.follow=follow;node.global_transform=follow.global_transform
		m.set_shader_parameter("impact_direction",follow.global_basis.inverse()*(source-position).normalized())
	if broken:
		for i in 12:
			var direction:=Vector3(cos(i*2.4),sin(i*1.7)*.6,sin(i*2.4)).normalized()
			line(position+direction*radius*.8,position+direction*radius*1.25,Color("81f3e5"),.35,.3)
func impact(position: Vector3,source: Vector3,seed_value: int) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var normal: Vector3=(source-position).normalized()
	blast(position,Vector2(9,9),.13,Vector3.ZERO,1,rng.randf()*20)
	blast(position,Vector2(5,3),.28,normal*8,0,rng.randf()*20,.02,normal)
	for i in 8:
		var ray: Vector3=(normal+Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))).normalized()
		var mesh:=CylinderMesh.new();mesh.top_radius=.12;mesh.bottom_radius=.24;mesh.height=rng.randf_range(1.2,3.5);mesh.radial_segments=5
		var node:=mesh_node(mesh,Color("ffc57f"));node.position=position;node.quaternion=Quaternion(Vector3.UP,ray)
		add(node,rng.randf_range(.25,.6),ray*rng.randf_range(15,45))
func missile_burst(position: Vector3,source: Vector3,seed_value: int) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var size:=float(FrontierSpaceCombat.config().missile.blast_size)
	var normal: Vector3=(source-position).normalized()
	blast(position,Vector2.ONE*size*2,.16,Vector3.ZERO,1,rng.randf()*20)
	blast(position,Vector2(size,size*.85),.55,normal*4,0,rng.randf()*20,.02)
	for i in 4:
		var axis:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		blast(position+axis*1.5,Vector2(size*.7,size*.3),.5,axis*17,0,rng.randf()*20,.03+i*.025,axis)
		blast(position,Vector2(size*.65,size*.55),.9,axis*7,3,rng.randf()*20,.18,axis)
	for i in 10:
		var axis:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		blast(position,Vector2(5,.4),.6,axis*rng.randf_range(25,55),2,rng.randf()*20,0,axis)
func rocket_trail(position: Vector3,velocity: Vector3,seed_value: int) -> void:
	var direction: Vector3=velocity.normalized()
	blast(position,Vector2(4.8,1.25),.22,-direction*18,0,float(seed_value%31),0,direction)
	blast(position,Vector2(3.5,2.5),.55,-direction*5,3,float(seed_value%23),.08)
func blast(position: Vector3,size: Vector2,life: float,velocity: Vector3,kind: int,variation: float,delay: float=0.0,axis:=Vector3.ZERO) -> void:
	if blast_pool.is_empty():release(items.pop_front())
	var node: MeshInstance3D=blast_pool.pop_back()
	node.set_instance_shader_parameter("kind",kind);node.set_instance_shader_parameter("variation",variation);node.set_instance_shader_parameter("age",0.0)
	node.position=position;node.hide()
	var row:=add(node,life,velocity);row.age=-delay;row.blast=true;row.angle=variation;row.axis=axis;row.size=size
	row.start_scale=.35 if kind in [0,1] else .7;row.end_scale=1.0 if kind in [1,2] else 1.6

func vent(position: Vector3,velocity: Vector3,seed_value: int) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var axis:=Vector3(rng.randf_range(-1,1),rng.randf_range(-.5,.5),rng.randf_range(-1,1)).normalized()
	blast(position,Vector2(6,3),.42,velocity*.45+axis*8,0,rng.randf()*20,0,axis)
	blast(position,Vector2(3,.35),.35,velocity*.45+axis*25,2,rng.randf()*20,0,axis)

func explosion(model: Node3D,velocity: Vector3,seed_value: int) -> void:
	var p:=model.global_position;var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var cfg: Dictionary=FrontierSpaceCombat.config().presentation.explosion
	# Reuse the actual authored hull/wing meshes and rotate each about its own centre.
	var pieces:=model.find_children("*","MeshInstance3D",true,false);var count:=0
	for piece in pieces:
		if not piece.is_visible_in_tree() or piece.mesh==null or piece.mesh.get_aabb().size.length()<1.0:continue
		var pivot:=Node3D.new();add_child(pivot)
		var center: Vector3=piece.mesh.get_aabb().get_center()
		pivot.global_transform=piece.global_transform;pivot.global_position=piece.global_transform*center
		var node:=MeshInstance3D.new();node.mesh=piece.mesh;node.material_override=piece.material_override
		for i in piece.mesh.get_surface_count():node.set_surface_override_material(i,piece.get_surface_override_material(i))
		pivot.add_child(node);node.position=-center;node.layers=piece.layers
		var out: Vector3=(pivot.global_position-p+Vector3(rng.randf_range(-10,10),rng.randf_range(-8,8),rng.randf_range(-10,10))).normalized()
		var row:=add(pivot,rng.randf_range(2.3,float(cfg.debris_seconds)),velocity*.55+out*rng.randf_range(14,36),0,Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)))
		row.debris=node;count+=1
		if count>=int(cfg.debris_limit):break
	var drift:=velocity*.45;var size:=float(cfg.size)
	blast(p,Vector2.ONE*size*2.3,float(cfg.flash_seconds),drift,1,rng.randf()*20)
	blast(p,Vector2(size*1.15,size),float(cfg.plasma_seconds),drift,0,rng.randf()*20,.025)
	# Unequal delays and directions make one tearing burst instead of ten simultaneous balls.
	for i in int(cfg.plumes):
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(-.65,.65),rng.randf_range(-1,1)).normalized()
		var origin:=p+direction*rng.randf_range(2,7)
		blast(origin,Vector2(size*.8,size*.3),rng.randf_range(.5,.85),drift+direction*rng.randf_range(18,32),0,rng.randf()*20,rng.randf_range(.04,.16),direction)
		blast(origin,Vector2(size*.7,size*.5),1.3,drift+direction*13,3,rng.randf()*20,.2,direction)
	for i in int(cfg.streaks):
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		blast(p+direction*4,Vector2(rng.randf_range(5,11),rng.randf_range(.2,.65)),rng.randf_range(.55,1.15),drift+direction*rng.randf_range(32,85),2,rng.randf()*20,rng.randf_range(0,.12),direction)

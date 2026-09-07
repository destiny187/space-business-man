class_name FrontierEffects
extends Node3D

const LIMIT := 160
var active: Array[Dictionary] = []
var pool: Array[MeshInstance3D] = []
var emitted: Dictionary = {"suction":0,"pulse":0,"impact":0,"construction":0}
var material: ShaderMaterial
var chip: SphereMesh
var bolt: CylinderMesh
var ring: TorusMesh
var running: bool = true

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://assets/materials/effect.gdshader")
	chip = SphereMesh.new()
	chip.radius = 1; chip.height = 2; chip.radial_segments = 5; chip.rings = 2
	bolt = CylinderMesh.new()
	bolt.top_radius = 0.035; bolt.bottom_radius = 0.065; bolt.height = 1; bolt.radial_segments = 6
	ring = TorusMesh.new()
	ring.inner_radius = 0.91; ring.outer_radius = 1.0; ring.rings = 24; ring.ring_segments = 6

func clear() -> void:
	for e in active: e.node.visible = false; pool.append(e.node)
	active.clear()

func _spawn(kind: String,start: Vector3,finish: Vector3,color: Color,life: float,scale_value: float) -> Dictionary:
	if active.size() >= LIMIT: return {}
	var node: MeshInstance3D
	if pool.is_empty():
		node = MeshInstance3D.new()
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	else: node = pool.pop_back()
	node.mesh = ring if kind == "ring" else (bolt if kind == "shot" else chip)
	node.position = start; node.rotation = Vector3.ZERO; node.scale = Vector3.ONE*scale_value; node.visible = true
	node.set_instance_shader_parameter("effect_color",color)
	var e: Dictionary = {"node":node,"kind":kind,"start":start,"end":finish,"color":color,"age":0.0,"life":life,"scale":scale_value,"seed":randf()*TAU,"velocity":Vector3(randf_range(-2,2),randf_range(1,3),randf_range(-2,2))}
	active.append(e)
	return e

func suction(origin: Vector3,intake: Node3D,resource: String,amount: int) -> void:
	emitted.suction += 1
	var color: Color = Color(FrontierCatalog.entry("resources",resource).color)
	for i in range(clampi(amount/2,4,10)):
		var start: Vector3 = origin+Vector3(randf_range(-0.35,0.35),randf_range(-0.15,0.35),randf_range(-0.35,0.35))
		var e: Dictionary = _spawn("suction",start,intake.global_position,color,randf_range(0.55,0.85),randf_range(0.028,0.075))
		if not e.is_empty(): e.intake = intake

func burst(position_value: Vector3,color: Color,count: int = 12) -> void:
	emitted.impact += 1
	for i in range(count): _spawn("spark",position_value,Vector3.ZERO,color,randf_range(0.25,0.65),randf_range(0.025,0.065))
	_spawn("ring",position_value,Vector3.ZERO,color,0.32,0.18)

func pulse(origin: Vector3,destination: Vector3) -> void:
	emitted.pulse += 1
	for i in range(5): _spawn("spark",origin,Vector3.ZERO,Color("ffcf83"),0.10,0.035)
	_spawn("shot",origin,destination,Color("ffe0a2"),0.12,1)

func construction(position_value: Vector3) -> void:
	emitted.construction += 1
	var e: Dictionary = _spawn("ring",position_value+Vector3.UP*0.1,Vector3.ZERO,Color("82f5d2"),1.0,0.3)
	if not e.is_empty(): e.construction = true
	for i in range(24):
		var a: float = float(i)*TAU/24
		var shard: Dictionary = _spawn("spark",position_value+Vector3(cos(a)*2,0.2,sin(a)*2),Vector3.ZERO,Color("a5ffe0"),0.8,0.04)
		if not shard.is_empty(): shard.velocity = Vector3(0,3,0)

func _process(delta: float) -> void:
	if not running: return
	var impacts: Array[Vector3] = []
	for i in range(active.size()-1,-1,-1):
		var e: Dictionary = active[i]
		e.age += delta
		var t: float = minf(1,e.age/e.life)
		var node: MeshInstance3D = e.node
		var color: Color = e.color
		color.a = minf(1,(1-t)*4)
		node.set_instance_shader_parameter("effect_color",color)
		match e.kind:
			"suction":
				if is_instance_valid(e.get("intake")) and e.intake.is_inside_tree(): e.end = e.intake.to_global(e.intake.get_meta("intake_offset",Vector3(0,1.2,0)))
				var direction: Vector3 = (e.end-e.start).normalized()
				var side: Vector3 = direction.cross(Vector3.UP).normalized()
				var up: Vector3 = side.cross(direction).normalized()
				var spiral: Vector3 = (side*cos(t*TAU*1.2+e.seed)+up*sin(t*TAU*1.2+e.seed))*sin(t*PI)*0.20
				node.position = e.start.lerp(e.end,t*t)+spiral
				node.scale = Vector3.ONE*e.scale*(1-t*0.8)
				node.rotate_x(delta*7); node.rotate_z(delta*9)
			"spark":
				node.position = e.start+e.velocity*e.age+Vector3.DOWN*3*e.age*e.age
				node.rotate_x(delta*8)
			"shot":
				node.position = e.start.lerp(e.end,t)
				if node.position.distance_to(e.end) > 0.01:
					node.look_at(e.end,Vector3.UP)
					node.rotate_object_local(Vector3.RIGHT,PI/2)
				node.scale = Vector3(1,minf(1.5,e.start.distance_to(e.end)*0.25),1)
			"ring":
				node.scale = Vector3.ONE*(e.scale+t*(3.5 if e.get("construction",false) else 1.0))
		if t >= 1:
			if e.kind == "shot": impacts.append(e.end)
			node.visible = false; pool.append(node); active.remove_at(i)
	for point in impacts: burst(point,Color("ffc487"),14)

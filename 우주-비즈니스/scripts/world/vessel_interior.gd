class_name FrontierVesselInterior
extends Node3D
## Only the authored shell changes; actor, station and collision identities survive.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/vessel_interiors.json"))
	return _config
static func definition(hull: String) -> Dictionary:
	return config().hulls.get(hull,config().hulls[config().fallback])
var hull_id: String=""
var room: Node3D
var cache: Dictionary={}
var lamps: Array[OmniLight3D]=[]
var parts: Array[Node3D]=[]
var window_material: ShaderMaterial
var clock:=0.0
var rebuilds:=0
var active:=false

static func build_collisions(parent: Node3D) -> void:
	for row in config().collisions:
		var body:=StaticBody3D.new();body.position=FrontierCrewWorld.vector(row.position)
		var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=FrontierCrewWorld.vector(row.size)
		collision.shape=shape;body.add_child(collision);parent.add_child(body)

func _ready() -> void:
	window_material=ShaderMaterial.new();window_material.shader=load("res://assets/materials/space/cabin_window.gdshader")
	build_collisions(self)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("152b39")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("89aaa8");env.ambient_light_energy=.42
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=env;add_child(environment)
	for z in [-5,0,5]:
		var lamp:=OmniLight3D.new();lamp.position=Vector3(0,3.6,z);lamp.light_energy=1.35;lamp.omni_range=7;lamp.shadow_enabled=true
		add_child(lamp);lamps.append(lamp)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-28,-30,0);sun.light_energy=.25;sun.light_color=Color("c8e5ed");add_child(sun)
	update_hull("kestrel")

func bind_exterior(texture: Texture2D) -> void:
	window_material.set_shader_parameter("exterior",texture)
	if room!=null:_windows(room)

func update_hull(id: String) -> void:
	if not config().hulls.has(id):id=str(config().fallback)
	if id==hull_id:return
	var next: Node3D=load(definition(id).model).instantiate()
	if room!=null:remove_child(room);room.queue_free()
	cache.clear()
	room=next;room.name="Interior_"+id;add_child(room);FrontierInkStyle.apply(room,cache)
	if window_material.get_shader_parameter("exterior")!=null:_windows(room)
	parts.clear()
	for part in room.find_children("Anim_*","Node3D",true,false):
		parts.append(part);part.set_meta("rest",part.transform)
	for lamp in lamps:
		lamp.light_color=Color(definition(id).light_color);lamp.position.y=float(definition(id).height)-.85
	hull_id=id;clock=0;rebuilds+=1

func _windows(node: Node) -> void:
	var panes:=node.find_child("WindowPanes",true,false)
	if panes==null:return
	for mesh in panes.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=window_material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	if not active or not is_visible_in_tree():return
	clock+=delta
	for part in parts:
		var rest: Transform3D=part.get_meta("rest")
		if str(part.name).begins_with("Anim_GantryTrolley"):part.position=rest.origin+Vector3(0,0,sin(clock*.18)*.5)
		else:part.basis=rest.basis*Basis(Vector3.UP,clock*.09)

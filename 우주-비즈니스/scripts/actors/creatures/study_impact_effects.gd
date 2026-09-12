extends Node3D
## Impact marks and trails are driven by contact events, with bounded pools.
const Ink=preload("res://scripts/actors/ink_style.gd")
const Existing=preload("res://scripts/actors/firearm_effects.gd")
var accents: Node3D
var camera: Camera3D
var particles: Array=[]
var pool: Array[MeshInstance3D]=[]
var materials: Dictionary={}
var ball: SphereMesh
var shard: PrismMesh
var audio_count:=0
var audio_enabled:=true
var terrain_probe: Callable
var ground_level:=0.0
var voices: Array=[]

func _ready() -> void:
	accents=Existing.new();add_child(accents);accents.camera=camera;accents.set_process(false)
	ball=SphereMesh.new();ball.radius=1;ball.height=2;ball.radial_segments=12;ball.rings=6
	shard=PrismMesh.new();shard.size=Vector3.ONE

func mat(color: Color) -> Material:
	var key:=color.to_html()
	if not materials.has(key):
		var source:=StandardMaterial3D.new();source.albedo_color=color;source.roughness=.67;materials[key]=Ink.material(source,{})
	return materials[key]

func piece(shape: String,at: Vector3,velocity: Vector3,size: Vector3,color: Color,life: float,gravity: float=0) -> void:
	if particles.size()>=96:return
	var node: MeshInstance3D
	if pool.is_empty():node=MeshInstance3D.new();add_child(node)
	else:node=pool.pop_back()
	node.mesh=shard if shape=="shard" else ball
	node.material_override=mat(color);node.position=at;node.rotation=Vector3.ZERO;node.scale=size;node.show()
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.append({"node":node,"shape":shape,"start":at,"velocity":velocity,"size":size,"age":0.0,"life":life,"gravity":gravity,"floor":ground_level+.012})

func sound(id: String,at: Vector3,pitch: float=1.0,volume: float=-5) -> void:
	if not audio_enabled or voices.size()>=12:return
	var voice:=AudioStreamPlayer3D.new();voice.stream=load("res://assets/audio/"+id+".wav");voice.pitch_scale=pitch;voice.volume_db=volume;voice.unit_size=12;voice.max_distance=35;add_child(voice);voice.global_position=at;voice.play();voices.append(voice);audio_count+=1

func preparation(at: Vector3,kind: String) -> void:
	sound("sfx_wildlife_warning",at,.80 if kind=="mortar" else 1.08,-12)

func launch(at: Vector3,kind: String) -> void:
	sound("sfx_water_shot_v1" if kind=="acid" else "sfx_wildlife_strike",at,1.30 if kind in ["dart","slash"] else .86,-9)
	if kind in ["mortar","acid"]:
		for i in 4:piece("blob",at,Vector3((i-1.5)*.35,.25,.5),Vector3(.025,.025,.055),Color("b1b976"),.16)

func trail(a: Vector3,b: Vector3,color: Color,width: float) -> void:
	if a.distance_to(b)<.02:return
	var e: Dictionary=accents.spawn("spark",b,color,.10,width)
	if not e.is_empty():e.velocity=(b-a).normalized()*1.2

func impact(event: Dictionary,kind: String,strength: float=1.0) -> void:
	var point: Vector3=event.point;var normal: Vector3=event.normal
	if terrain_probe.is_valid():
		var hit: Dictionary=terrain_probe.call(point,3.)
		ground_level=float(hit.point.y) if not hit.get("missing",false) else point.y-3.
	# Organic impacts use a brief pointed mark and physical fragments, without
	# the warm circular puff or expanding ground ring. Shield arcs remain cyan.
	if event.kind=="shield":accents.impact({"kind":event.kind,"point":[point.x,point.y,point.z],"normal":[normal.x,normal.y,normal.z]})
	var contact: Dictionary=accents.spawn("contact",point+normal*.04,Color("e4f7ed") if event.kind=="shield" else Color("dbe4d8"),.09,.38 if kind in ["ram","slam","mortar"] else .28)
	if not contact.is_empty():contact.spin=.45 if kind=="slash" else -.25
	if event.kind=="shield":
		sound("sfx_gun_hit_shield",point,1.02,-4)
		for i in 7:
			var a: float=i*TAU/7;piece("shard",point,normal*.5+Vector3(cos(a),sin(a),0)*1.8,Vector3(.035,.09,.015),Color("8fe5e5"),.24)
		return
	if event.kind=="organic":sound("sfx_wildlife_hurt",point,.94,-5)
	else:sound("sfx_water_shot_v1" if kind=="acid" else "sfx_wildlife_strike",point,.64 if kind=="slam" else .88,-7)
	var color:=Color("aeb871") if kind=="acid" else Color("ad9b7c")
	var count:=12 if kind in ["slam","mortar"] else 6
	for i in count:
		var a: float=i*2.399;var speed: float=.65+float(i%4)*.27
		var velocity: Vector3=Vector3(cos(a),.45+float(i%3)*.13,sin(a))*speed*strength
		piece("blob" if kind=="acid" else "shard",point+normal*.025,velocity,Vector3(.035,.060,.028) if kind!="acid" else Vector3(.055,.025,.055),color,.32+float(i%3)*.06,3)
	if kind=="acid":piece("blob",point+normal*.022,Vector3.ZERO,Vector3(.17,.007,.13),color,.85)

func step(delta: float) -> void:
	accents._process(delta)
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary=particles[i];p.age+=delta;var t: float=p.age/p.life
		if t>=1:p.node.hide();pool.append(p.node);particles.remove_at(i);continue
		p.node.position=p.start+p.velocity*p.age+Vector3.DOWN*p.gravity*p.age*p.age
		p.node.position.y=maxf(float(p.floor),p.node.position.y)
		p.node.scale=p.size*(1-t*t)
		if p.shape=="shard":p.node.rotate_x(delta*4.5);p.node.rotate_z(delta*3)
	for i in range(voices.size()-1,-1,-1):
		if not voices[i].playing:voices[i].queue_free();voices.remove_at(i)

func clear() -> void:
	for p in particles:p.node.hide();pool.append(p.node)
	particles.clear();accents.clear()
	for voice in voices:voice.queue_free()
	voices.clear()

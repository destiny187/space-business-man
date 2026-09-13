class_name FrontierFirearmEffects
extends Node3D
## Short, pooled presentation only. Contacts come from host-confirmed pellet results.
static var settings: Dictionary = {}
static func config() -> Dictionary:
	if settings.is_empty():settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/firearm_feedback.json"))
	return settings

var active: Array[Dictionary] = []
var pool: Array[MeshInstance3D] = []
var camera: Camera3D
var flash_material: ShaderMaterial
var line_material: ShaderMaterial
var quad: QuadMesh
var line: CylinderMesh
var hoop: TorusMesh
var shard: ArrayMesh
var rng:=RandomNumberGenerator.new()
var emitted: Dictionary={"muzzle":0,"tracer":0,"impact":0}

func _ready() -> void:
	process_priority=6
	rng.randomize()
	flash_material=ShaderMaterial.new();flash_material.shader=load("res://assets/materials/firearm_flash.gdshader")
	line_material=ShaderMaterial.new();line_material.shader=load("res://assets/materials/effect.gdshader")
	quad=QuadMesh.new();quad.size=Vector2.ONE
	line=CylinderMesh.new();line.top_radius=.18;line.bottom_radius=.5;line.height=1;line.radial_segments=5
	hoop=TorusMesh.new();hoop.inner_radius=.93;hoop.outer_radius=1;hoop.rings=24;hoop.ring_segments=4
	shard=ArrayMesh.new()
	var vertices:=PackedVector3Array([Vector3(-.5,-.35,0),Vector3(0,.65,0),Vector3(.5,-.2,0)])
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK])
	shard.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func clear(preserve_rounds: bool=false) -> void:
	for index in range(active.size()-1,-1,-1):
		var e: Dictionary=active[index]
		if preserve_rounds and e.kind=="ballistic":continue
		e.node.hide();pool.append(e.node);active.remove_at(index)

func spawn(kind: String,point: Vector3,color: Color,life: float,size: float) -> Dictionary:
	if active.size()>=int(config().particle_limit):return {}
	var node: MeshInstance3D
	if pool.is_empty():
		node=MeshInstance3D.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
	else:node=pool.pop_back()
	node.mesh=quad if kind in ["flash","dust","contact","arc"] else hoop if kind=="ring" else shard if kind=="shard" else line
	node.material_override=flash_material if node.mesh==quad else line_material
	node.position=point;node.rotation=Vector3.ZERO;node.scale=Vector3.ONE*size;node.show()
	node.set_instance_shader_parameter("phase",0.0);node.set_instance_shader_parameter("shape",{"dust":1.0,"contact":2.0,"arc":3.0}.get(kind,0.0))
	node.set_instance_shader_parameter("tint",color);node.set_instance_shader_parameter("effect_color",color)
	if node.mesh==quad and is_instance_valid(camera):node.basis=camera.global_basis.scaled(Vector3.ONE*size)
	var e: Dictionary={"node":node,"kind":kind,"start":point,"color":color,"age":0.0,"life":life,"size":size,"velocity":Vector3.ZERO,"fresh":true}
	active.append(e);return e

func muzzle(origin: Vector3,_direction: Vector3,family: String,socket: Node3D=null) -> void:
	var style: Dictionary=config().families.get(family,config().families.carbine)
	var flash:=spawn("flash",origin,Color(style.color),float(style.flash_time),float(style.flash_size)*2)
	if not flash.is_empty():flash.socket=socket;flash.spin=rng.randf_range(-.35,.35)
	emitted.muzzle+=1

func shot(origin: Vector3,event: Dictionary,near_clip: float=0.0) -> void:
	var style: Dictionary=config().families.get(event.family,config().families.carbine)
	if event.get("impact_only",false):
		for e in active:
			if e.get("shot_id","")==str(event.get("actor",""))+":"+str(event.get("shot_serial",-1)) and e.get("round_index",0) in event.get("retired",[0]):e.age=e.life
	if not event.get("projectiles",[]).is_empty():
		for bullet in event.projectiles:
			var velocity:=FrontierCrewWorld.vector(bullet.velocity)
			var e:=spawn("ballistic",FrontierCrewWorld.vector(event.origin),Color(style.color),float(bullet.range)/maxf(1,velocity.length()),1)
			if e.is_empty():continue
			e.velocity=velocity;e.gravity=float(bullet.gravity);e.width=float(style.trace_width);e.length=float(style.trace_length);e.shot_id=str(event.get("actor",""))+":"+str(event.serial)
			e.round_index=bullet.get("index",0)
			e.near_clip=near_clip;emitted.tracer+=1
	for end in ([] if event.get("ballistic",false) else event.rays):
		var point:=FrontierCrewWorld.vector(end);var distance:=origin.distance_to(point)
		if distance<.05:continue
		var start:=origin.move_toward(point,minf(near_clip,distance*.75))
		distance=start.distance_to(point)
		var travel:=clampf(distance/float(style.trace_speed),.025,.10)
		var e:=spawn("tracer",start,Color(style.color),travel+.025,1)
		if e.is_empty():continue
		e.end=point;e.direction=(point-start)/distance;e.distance=distance;e.travel=travel
		e.width=float(style.trace_width);e.length=minf(float(style.trace_length),distance*.45)
		segment(e.node,start,start+e.direction*minf(e.length,distance*.15),e.width)
		emitted.tracer+=1
	for hit in event.get("contacts",[]):impact(hit)
	if event.get("effect","")=="splash" and not event.get("contacts",[]).is_empty():
		var point:=FrontierCrewWorld.vector(event.contacts[0].point)
		spawn("contact",point,Color(style.color),.08,.42)
		spawn("arc",point,Color(style.color),.22,.85)

func impact(contact: Dictionary) -> void:
	var kind: String=contact.get("kind","surface")
	if not config().impacts.has(kind):return
	var style: Dictionary=config().impacts[kind]
	var point:=FrontierCrewWorld.vector(contact.point)
	var normal:=FrontierCrewWorld.vector(contact.normal).normalized()
	if normal.length_squared()<.5:normal=Vector3.UP
	point+=normal*.018
	var color:=Color(style.color);var size:=float(style.size)
	var contact_flash:=spawn("contact",point,color,.065 if kind!="break" else .09,size*2.0)
	if not contact_flash.is_empty():contact_flash.spin=rng.randf_range(-PI,PI)
	var side:=normal.cross(Vector3.UP).normalized()
	if side.length_squared()<.5:side=Vector3.RIGHT
	var up:=side.cross(normal).normalized()
	var soft_contact: bool=kind in ["surface","organic"]
	if soft_contact:
		# One low-opacity irregular puff, separate from the sharp instant of contact.
		var puff:=spawn("dust",point,color,float(style.life),size*.9)
		if not puff.is_empty():puff.velocity=normal*.22;puff.spin=rng.randf_range(-PI,PI)
	for i in int(style.sparks):
		var a:=rng.randf()*TAU
		var direction: Vector3=(normal*rng.randf_range(.25,.6)+(side*cos(a)+up*sin(a))*rng.randf_range(.6,1.0)).normalized()
		var e:=spawn("shard" if soft_contact else "spark",point,color,float(style.life)*rng.randf_range(.7,1.1),rng.randf_range(.018,.034) if soft_contact else .017)
		if not e.is_empty():e.velocity=direction*float(style.speed)*rng.randf_range(.6,1.0);e.spin=a
	if kind in ["shield","break"]:
		var arc:=spawn("arc",point,color,float(style.life),size*2.8)
		if not arc.is_empty():arc.spin=rng.randf_range(-PI,PI)
	if kind=="break":
		for i in 5:
			var a:=float(i)*TAU/5+rng.randf_range(-.15,.15)
			var outward:=side*cos(a)+up*sin(a)
			var piece:=spawn("shard",point+outward*.06,color,.24,rng.randf_range(.04,.085))
			if not piece.is_empty():piece.velocity=outward*rng.randf_range(.7,1.3)+normal*.2;piece.spin=a
	emitted.impact+=1

func segment(node: MeshInstance3D,start: Vector3,finish: Vector3,width: float) -> void:
	var delta:=finish-start;var length:=delta.length()
	node.position=(start+finish)*.5
	if length>.0001:node.quaternion=Quaternion(Vector3.UP,delta/length)
	node.scale=Vector3(width,maxf(.001,length),width)

func _process(delta: float) -> void:
	for i in range(active.size()-1,-1,-1):
		var e: Dictionary=active[i]
		# A short flash must survive its first rendered frame even after a streaming hitch.
		if e.fresh:e.fresh=false
		else:e.age+=delta
		var t:=clampf(float(e.age)/float(e.life),0,1)
		var node: MeshInstance3D=e.node;var color: Color=e.color;color.a*=1-t*t
		node.set_instance_shader_parameter("phase",t);node.set_instance_shader_parameter("tint",color);node.set_instance_shader_parameter("effect_color",color)
		match e.kind:
			"flash","contact","arc":
				if is_instance_valid(e.get("socket")):node.position=e.socket.global_position
				if is_instance_valid(camera):node.basis=camera.global_basis;node.rotate_object_local(Vector3.BACK,float(e.get("spin",0)))
				node.scale=Vector3.ONE*float(e.size)*(1-t*(.65 if e.kind=="flash" else .20 if e.kind=="contact" else 0.0))
			"dust":
				node.position=e.start+e.velocity*e.age;node.scale=Vector3.ONE*float(e.size)*(1+t*.8)
				if is_instance_valid(camera):
					node.basis=camera.global_basis;node.rotate_object_local(Vector3.BACK,float(e.get("spin",0)))
					node.scale=Vector3.ONE*float(e.size)*(1+t*.8)
			"tracer":
				var front:=minf(float(e.distance),maxf(minf(float(e.length)*.7,float(e.distance)*.25),float(e.distance)*e.age/e.travel))
				var back:=maxf(0,front-float(e.length)*(1-t*.6))
				segment(node,e.start+e.direction*back,e.start+e.direction*front,float(e.width)*(1-t*.45))
			"ballistic":
				var time:=float(e.age)
				var front: Vector3=e.start+e.velocity*time+Vector3.DOWN*float(e.gravity)*time*time*.5
				var velocity: Vector3=e.velocity+Vector3.DOWN*float(e.gravity)*time
				node.visible=front.distance_to(e.start)>float(e.get("near_clip",0))
				segment(node,front-velocity.normalized()*minf(float(e.length),time*velocity.length()),front,float(e.width))
			"spark":
				var point: Vector3=e.start+e.velocity*e.age+Vector3.DOWN*2*e.age*e.age
				segment(node,point-e.velocity*.022,point,float(e.size)*(1-t*.8))
			"shard":
				node.position=e.start+e.velocity*e.age
				if is_instance_valid(camera):node.basis=camera.global_basis;node.rotate_object_local(Vector3.BACK,float(e.spin)+t*1.8)
				node.scale=Vector3.ONE*float(e.size)*(1-t*.75)
			"ring":node.scale=Vector3.ONE*(float(e.size)+float(e.get("growth",.3))*t)
		if t>=1:node.hide();pool.append(node);active.remove_at(i)

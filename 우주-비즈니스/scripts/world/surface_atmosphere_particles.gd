extends Node3D
## Camera-local visual samples of the authoritative atmosphere. No weather gameplay state.
var surface: Node3D
var camera: Camera3D
var layers: Dictionary={}
var rng:=RandomNumberGenerator.new()
var wind:=Vector3.RIGHT
var timer:=0.0
var phase:=0.0
var cfg: Dictionary
var exposure:=0.0

func configure(owner_surface: Node3D,view: Camera3D) -> void:
	surface=owner_surface;camera=view;cfg=surface.atmosphere.config().particles
	rng.seed=int(surface.body.get("seed",0))
	phase=rng.randf()*TAU;wind=Vector3(cos(phase),0,sin(phase))
	for kind in cfg.layers:
		var rule: Dictionary=cfg.layers[kind]
		var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/space/surface_mote.gdshader")
		material.set_shader_parameter("softness",3.0 if kind=="mist" else 1.0)
		var quad:=QuadMesh.new();quad.material=material
		var mesh:=MultiMesh.new();mesh.transform_format=MultiMesh.TRANSFORM_3D;mesh.use_colors=true;mesh.mesh=quad;mesh.instance_count=int(rule.count)
		var node:=MultiMeshInstance3D.new();node.multimesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
		var points: Array[Vector3]=[]
		for index in mesh.instance_count:
			points.append(camera.global_position+Vector3(rng.randf_range(-cfg.radius,cfg.radius),rng.randf_range(-2,cfg.height),rng.randf_range(-cfg.radius,cfg.radius)))
			mesh.set_instance_color(index,Color(1,1,1,0))
		layers[kind]={"node":node,"mesh":mesh,"material":material,"points":points}

func _process(delta: float) -> void:
	if surface==null:return
	timer-=delta;phase+=delta*.35
	var refresh: bool=timer<=0
	var center: Vector3=camera.global_position
	if refresh:
		timer=float(cfg.ground_refresh_seconds)
		# Also suppress under overhangs, where altitude alone does not detect shelter.
		exposure=0.0 if surface.terrain.field.density(center+Vector3.UP*3)>0 or surface.terrain.field.height(center.x,center.z)>center.y else 1.0
	var radius: float=cfg.radius
	for kind in layers:
		var layer: Dictionary=layers[kind];var rule: Dictionary=cfg.layers[kind]
		var strength: float=float(surface.atmosphere.current[kind])*exposure
		layer.node.visible=strength>.001
		layer.material.set_shader_parameter("strength",strength)
		var tint: Color=surface.atmosphere.current.dust_color if kind=="dust" else (Color("d5ecf5") if kind=="ice" else surface.atmosphere.current.cloud_color)
		tint.a=float(rule.opacity);layer.material.set_shader_parameter("tint",tint)
		if not layer.node.visible:continue
		for index in layer.points.size():
			var point: Vector3=layer.points[index]
			point+=(wind*float(rule.speed)*(1.0+.25*sin(phase+float(index)))+Vector3.DOWN*float(rule.fall))*minf(delta,.1)
			point.x=center.x+wrapf(point.x-center.x,-radius,radius)
			point.z=center.z+wrapf(point.z-center.z,-radius,radius)
			point.y=center.y+wrapf(point.y-center.y,-2,float(cfg.height))
			layer.points[index]=point
			if refresh:
				var height: float=surface.terrain.field.height(point.x,point.z)
				var alpha: float=smoothstep(height+.1,height+1.2,point.y)
				alpha*=smoothstep(-2.,0.,point.y-center.y)*(1.0-smoothstep(float(cfg.height)-2.,float(cfg.height),point.y-center.y))
				layer.mesh.set_instance_color(index,Color(1,1,1,alpha))
			var size: float=float(rule.size)*(.75+.5*float(index%7)/6.0)
			layer.mesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),point))

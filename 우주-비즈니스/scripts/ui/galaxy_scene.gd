extends RefCounted
## Spatial galaxy rendering; navigation coordinates remain the saved galaxy's coordinates.
var viewport: SubViewport
var root: Node3D
var camera: Camera3D
var yaw:=0.0
var tilt:=.83
var clouds: Array[Node3D]=[]
var haze: Array[Node3D]=[]
var render_key: String=""
var local_stars: MultiMeshInstance3D
var last_stars:=PackedVector2Array()
var last_star_scale: float=-1
func setup(owner: Control) -> void:
 viewport=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(800,600);viewport.msaa_3d=Viewport.MSAA_2X;owner.add_child(viewport)
 root=Node3D.new();viewport.add_child(root)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.01;camera.far=100;root.add_child(camera)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("040812");env.environment.glow_enabled=true;env.environment.glow_intensity=.6;root.add_child(env)
 for i in 3:
  var plane:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(2.25,2.25);plane.mesh=mesh;plane.position.y=(i-2)*.012
  var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/galaxy_disk.gdshader");mat.set_shader_parameter("layer",float(i)*.3);plane.material_override=mat;root.add_child(plane);haze.append(plane)
 var core:=FrontierGalacticCore.new();core.scale=Vector3.ONE*.008;core.position.y=.075;root.add_child(core)
 for suffix in ["_far","_medium",""]:
  var cloud: Node3D=load("res://assets/models/space/galaxy_map"+suffix+".glb").instantiate();root.add_child(cloud);clouds.append(cloud)
  for child in cloud.find_children("*","MeshInstance3D",true,false):
   var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("9abce5");child.material_override=material
 local_stars=MultiMeshInstance3D.new();root.add_child(local_stars)
 var prototype: Node3D=load("res://assets/models/space/navigation_star.glb").instantiate()
 var meshes:=prototype.find_children("*","MeshInstance3D",true,false)
 local_stars.multimesh=MultiMesh.new();local_stars.multimesh.transform_format=MultiMesh.TRANSFORM_3D;local_stars.multimesh.mesh=meshes[0].mesh
 var star_material:=StandardMaterial3D.new();star_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;star_material.albedo_color=Color("b2e5ee");local_stars.material_override=star_material;prototype.free()
func update(size_value: Vector2,zoom: float,pan: Vector2,nearby: bool=false) -> void:
 viewport.size=Vector2i(maxi(1,int(size_value.x)),maxi(1,int(size_value.y)))
 camera.size=2.55/zoom
 camera.position=Vector3(sin(yaw)*cos(tilt),sin(tilt),cos(yaw)*cos(tilt))*4
 camera.look_at(Vector3.ZERO)
 var focus: Vector3=(-camera.basis.x*pan.x+camera.basis.y*pan.y)/maxf(1,size_value.y)*camera.size
 camera.position+=focus
 for i in clouds.size():clouds[i].visible=not nearby and zoom<8 and i==(0 if zoom<2 else (1 if zoom<5 else 2))
 for plane in haze:plane.visible=not nearby and zoom<8
 var key:=str([size_value,zoom,pan,yaw,tilt,nearby])
 if key!=render_key:render_key=key;request_render()
func project(point: Vector2) -> Vector2:return camera.unproject_position(Vector3(point.x,0,point.y))

func set_stars(coordinates: PackedVector2Array) -> void:
 var scale_value:=camera.size*.002
 if coordinates==last_stars and is_equal_approx(scale_value,last_star_scale):return
 last_stars=coordinates;last_star_scale=scale_value
 var mesh:=local_stars.multimesh;mesh.instance_count=coordinates.size()
 for i in coordinates.size():mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),Vector3(coordinates[i].x,0,coordinates[i].y)))
 request_render()

func request_render() -> void:
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 if not RenderingServer.frame_post_draw.is_connected(_rendered):RenderingServer.frame_post_draw.connect(_rendered,CONNECT_ONE_SHOT)
func _rendered() -> void:
 if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

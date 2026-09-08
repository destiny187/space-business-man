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
var star_glow: MultiMeshInstance3D
var last_stars:=PackedVector2Array()
var last_star_scale: float=-1
var last_origin:=Vector2.INF
var last_range: float=-1
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
 local_stars.multimesh=MultiMesh.new();local_stars.multimesh.transform_format=MultiMesh.TRANSFORM_3D;local_stars.multimesh.use_colors=true;local_stars.multimesh.mesh=meshes[0].mesh
 var star_material:=ShaderMaterial.new();star_material.shader=load("res://assets/materials/space/map_star.gdshader");local_stars.material_override=star_material;prototype.free()
 local_stars.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 star_glow=MultiMeshInstance3D.new();root.add_child(star_glow)
 star_glow.multimesh=MultiMesh.new();star_glow.multimesh.transform_format=MultiMesh.TRANSFORM_3D;star_glow.multimesh.use_colors=true
 var quad:=QuadMesh.new();quad.size=Vector2(2,2);star_glow.multimesh.mesh=quad
 var glow_material:=ShaderMaterial.new();glow_material.shader=load("res://assets/materials/space/map_star_glow.gdshader");star_glow.material_override=glow_material
 star_glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update(size_value: Vector2,zoom: float,pan: Vector2,nearby: bool=false) -> void:
 viewport.size=Vector2i(maxi(1,int(size_value.x)),maxi(1,int(size_value.y)))
 camera.size=2.55/zoom
 camera.position=Vector3(sin(yaw)*cos(tilt),sin(tilt),cos(yaw)*cos(tilt))*4
 camera.look_at(Vector3.ZERO)
 var focus: Vector3=(-camera.basis.x*pan.x+camera.basis.y*pan.y)/maxf(1,size_value.y)*camera.size
 camera.position+=focus
 for i in clouds.size():clouds[i].visible=not nearby and zoom<8 and i==(0 if zoom<2 else (1 if zoom<5 else 2))
 for plane in haze:
  plane.visible=true
  plane.material_override.set_shader_parameter("detail_mix",smoothstep(3.0,16.0,zoom))
 var key:=str([size_value,zoom,pan,yaw,tilt,nearby])
 if key!=render_key:render_key=key;request_render()
func project(point: Vector2) -> Vector2:return camera.unproject_position(Vector3(point.x,0,point.y))
# Display depth only; host distances and saved coordinates remain untouched.
func star_position(point: Vector2) -> Vector3:
 var height: float=(sin(point.dot(Vector2(17213.7,9137.1)))*.0022+sin(point.dot(Vector2(5391.3,21319.7)))*.0011)*(1.0-clampf(point.length(),0,1)*.5)
 return Vector3(point.x,height,point.y)
func project_star(point: Vector2) -> Vector2:return camera.unproject_position(star_position(point))

func set_stars(coordinates: PackedVector2Array,origin: Vector2=Vector2.ZERO,reach: float=INF) -> void:
 var scale_value:=camera.size*lerpf(.002,.006,smoothstep(.3,1.0,1.0-camera.size/2.55))
 if coordinates==last_stars and is_equal_approx(scale_value,last_star_scale) and origin==last_origin and reach==last_range:return
 last_stars=coordinates;last_star_scale=scale_value;last_origin=origin;last_range=reach
 var mesh:=local_stars.multimesh;mesh.instance_count=coordinates.size()
 star_glow.multimesh.instance_count=coordinates.size()
 for i in coordinates.size():
  var p:=coordinates[i]
  var tint:=.5+.5*sin(p.dot(Vector2(7341.1,15317.9)))
  var color:=Color("9bbff2").lerp(Color("ffe3ac"),tint)
  if p.distance_to(origin)>reach+.000001:color=Color(color.r*.28,color.g*.28,color.b*.28,1)
  var radius:=scale_value*lerpf(.8,1.25,tint)
  mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*radius),star_position(p)))
  mesh.set_instance_color(i,color)
  star_glow.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*radius*3.0),star_position(p)))
  star_glow.multimesh.set_instance_color(i,color)
 request_render()

func request_render() -> void:
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 if not RenderingServer.frame_post_draw.is_connected(_rendered):RenderingServer.frame_post_draw.connect(_rendered,CONNECT_ONE_SHOT)
func _rendered() -> void:
 if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

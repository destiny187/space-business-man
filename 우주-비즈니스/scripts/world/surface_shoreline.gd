extends Node3D
## A small tiled waterline mesh from real terrain/sea intersections; no depth-buffer fetch.
var hydro: FrontierSurfaceHydrology
var tiles: Dictionary={}
var pending: Array[Vector2i]=[]
var anchor:=Vector2i(99999,99999)
var job: Dictionary={}
var material: ShaderMaterial
var elapsed:=0.0
func configure(owner_hydro: FrontierSurfaceHydrology) -> void:
 hydro=owner_hydro
 material=ShaderMaterial.new();material.shader=load("res://assets/materials/space/shoreline.gdshader")
 hydro.surface.terrain.geometry_changed.connect(invalidate)
func invalidate() -> void:
 for node in tiles.values():node.queue_free()
 tiles.clear();pending.clear();job={};anchor=Vector2i(99999,99999)
func update(delta: float) -> void:
 elapsed+=delta;material.set_shader_parameter("flow_time",elapsed)
 var p: Vector3=hydro.surface.viewer.position
 var center:=Vector2i(floori(p.x/64),floori(p.z/64))
 if center!=anchor:
  anchor=center
  for key in tiles.keys():
   var d: Vector2i=key-anchor
   if maxi(absi(d.x),absi(d.y))>1:tiles[key].queue_free();tiles.erase(key)
  pending.clear()
  for x in range(center.x-1,center.x+2):
   for z in range(center.y-1,center.y+2):
    var key:=Vector2i(x,z)
    if not tiles.has(key) and (job.is_empty() or job.key!=key):pending.append(key)
 if job.is_empty():
  if pending.is_empty():return
  job={"key":pending.pop_front(),"row":0,"vertices":PackedVector3Array(),"colors":PackedColorArray(),"heights":{}}
 var z:=int(job.row);var key: Vector2i=job.key
 for x in 16:
  var corners: Array[Vector3]=[]
  for offset in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
   var q:=Vector3(key.x*64+(x+offset.x)*4,0,key.y*64+(z+offset.y)*4)
   var sample_key:=Vector2i(x+offset.x,z+offset.y)
   if not job.heights.has(sample_key):job.heights[sample_key]=hydro.surface.terrain.field.height(q.x,q.z)
   q.y=job.heights[sample_key];corners.append(q)
  _triangle([corners[0],corners[1],corners[2]])
  _triangle([corners[2],corners[1],corners[3]])
 job.row+=1
 if job.row<16:return
 var node:=MeshInstance3D.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.material_override=material;add_child(node)
 if not job.vertices.is_empty():
  var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=job.vertices;arrays[Mesh.ARRAY_COLOR]=job.colors
  var normals:=PackedVector3Array();normals.resize(job.vertices.size());normals.fill(Vector3.UP);arrays[Mesh.ARRAY_NORMAL]=normals
  var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=mesh
 tiles[key]=node;job={}
func _clip(points: Array,level: float,above: bool) -> Array:
 var result: Array=[]
 if points.is_empty():return result
 var previous: Vector3=points[-1];var previous_inside: bool=previous.y>=level if above else previous.y<=level
 for current: Vector3 in points:
  var inside: bool=current.y>=level if above else current.y<=level
  if inside!=previous_inside:result.append(previous.lerp(current,(level-previous.y)/(current.y-previous.y)))
  if inside:result.append(current)
  previous=current;previous_inside=inside
 return result
func _triangle(points: Array) -> void:
 var sea:=float(hydro.cfg.sea_level)
 var polygon:=_clip(_clip(points,sea-.5,true),sea-.025,false)
 for i in range(1,polygon.size()-1):
  for q: Vector3 in [polygon[0],polygon[i],polygon[i+1]]:
   job.vertices.append(Vector3(q.x,sea+.018,q.z));job.colors.append(Color(clampf((sea-q.y)/.5,0,1),1,1,1))

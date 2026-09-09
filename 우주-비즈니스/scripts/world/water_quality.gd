class_name FrontierWaterQuality
extends RefCounted
## Local presentation only; shared cached ocean meshes and identical mean water level.
static var meshes: Dictionary={}
static func level(tree: SceneTree) -> int:return int(FrontierClientSettings.ensure(tree).values.water_quality)
static func apply(material: ShaderMaterial,quality: int) -> void:
 material.set_shader_parameter("water_quality",quality)
 material.set_shader_parameter("rough",.65 if quality==0 else .32)
 material.set_shader_parameter("highlight_strength",.35 if quality==0 else .65 if quality==1 else 1.0)
static func ocean_mesh(quality: int) -> Mesh:
 if meshes.has(quality):return meshes[quality]
 if quality==0:
  var plane:=PlaneMesh.new();plane.size=Vector2(24576,24576);meshes[quality]=plane;return plane
 # Dense close rings, rapidly coarser distant rings; one continuous surface without overlays.
 var segments:=128 if quality==2 else 64
 var rings:=64 if quality==2 else 40
 var close_rings:=48 if quality==2 else 24
 var vertices:=PackedVector3Array([Vector3.ZERO]);var normals:=PackedVector3Array([Vector3.UP]);var indices:=PackedInt32Array()
 for ring in range(1,rings+1):
  var radius:=float(ring)*2 if ring<=close_rings else lerpf(float(close_rings)*2,12288,pow(float(ring-close_rings)/float(rings-close_rings),2.5))
  for n in segments:
   var angle:=n*TAU/segments
   vertices.append(Vector3(cos(angle)*radius,0,sin(angle)*radius));normals.append(Vector3.UP)
   var b:=1+(ring-1)*segments+n;var c:=1+(ring-1)*segments+(n+1)%segments
   if ring==1:indices.append_array(PackedInt32Array([0,b,c]))
   else:
    var a:=b-segments;var d:=c-segments
    indices.append_array(PackedInt32Array([a,b,c,a,c,d]))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);meshes[quality]=mesh;return mesh

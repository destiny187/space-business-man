extends SceneTree
## Focused geometry/collision parity and streaming reuse checks. No normal saves.
const OUT="/tmp/terrain-optimization-20260909"
var checks:=0
var failures:=0
var report: Dictionary={}
class LegacyField extends FrontierTerrainField:
 func normal(p: Vector3,_surface_height: float=NAN) -> Vector3:
  var e:=.15
  var gradient:=Vector3(density(p+Vector3(e,0,0))-density(p-Vector3(e,0,0)),density(p+Vector3(0,e,0))-density(p-Vector3(0,e,0)),density(p+Vector3(0,0,e))-density(p-Vector3(0,0,e)))
  return -gradient.normalized() if gradient.length_squared()>.000001 else Vector3.UP
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func settle(node: FrontierDistantTerrain) -> bool:
 var deadline:=Time.get_ticks_msec()+30000
 while node.task_id!=-1 or not node.queued.is_empty():
  if Time.get_ticks_msec()>deadline:return false
  await process_frame
 return true
func field_for(legacy: bool=false) -> FrontierTerrainField:
 var field: FrontierTerrainField=LegacyField.new() if legacy else FrontierTerrainField.new()
 var world:=FrontierUniverse.new_world(71491)
 var body:=FrontierUniverse.body(world.manifest,8)
 field.configure(71491,[],24,body.traits)
 return field
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUT)
 var old_mesher=load(OUT+"/legacy_mesher.gd")
 var old_distant=load(OUT+"/legacy_distant.gd")
 if old_mesher==null or old_distant==null:quit(2);return
 var field:=field_for();var old_field:=field_for(true)
 var rows: Array=[]
 for key in [Vector3i.ZERO,Vector3i(1,-1,0)]:
  var t:=Time.get_ticks_usec();var old: Dictionary=old_mesher.new().build(old_field,key);var old_ms: float=(Time.get_ticks_usec()-t)/1000.0
  t=Time.get_ticks_usec();var current:=FrontierTerrainMesher.new().build(field,key);var new_ms: float=(Time.get_ticks_usec()-t)/1000.0
  check(old.vertices==current.vertices and old.normals==current.normals and old.indices==current.indices and old.colors==current.colors,"exact original seeded surface/cave mesh "+str(key))
  var mesh:=FrontierTerrainMesher.mesh(old)
  if not old.indices.is_empty():
   var collider:=mesh.create_trimesh_shape()
   check(collider.get_faces()==current.collision_faces,"worker collision triangles equal the old mesh collider "+str(key))
  rows.append({"key":str(key),"old_ms":old_ms,"new_ms":new_ms,"triangles":current.indices.size()/3})
 var edit: Dictionary={"center":[24,1,12],"radius":3.2}
 old_field.add_edit(edit);field.add_edit(edit)
 var old: Dictionary=old_mesher.new().build(old_field,Vector3i.ZERO)
 var current:=FrontierTerrainMesher.new().build(field,Vector3i.ZERO)
 check(old.vertices==current.vertices and old.normals==current.normals and old.indices==current.indices,"border dig retains exact meshing and normals")
 report.chunks=rows
 var near:=FrontierDistantTerrain.new();root.add_child(near)
 var material:=StandardMaterial3D.new()
 near.request_rebuild(field,Vector3i.ZERO,2,material,600)
 check(await settle(near),"initial tiled terrain completes")
 var identities: Dictionary={}
 for key in near.tiles:identities[key]=near.tiles[key].node.mesh
 near.request_rebuild(field,Vector3i(1,0,0),2,material,600)
 check(await settle(near),"one chunk movement completes")
 var reused:=0
 for key in near.tiles:
  if identities.get(key)==near.tiles[key].node.mesh:reused+=1
 check(reused>0 and near.last_built_tiles<near.tiles.size(),"movement reuses distant tile mesh resources")
 # Every old coarse triangle is still present; extra outer tiles are allowed.
 var original: Array=old_distant._arrays(field,Vector3i(1,0,0),2,600)
 var triangles: Dictionary={}
 for row in near.tiles.values():
  var a: Array=row.node.mesh.surface_get_arrays(0)
  for i in range(0,a[Mesh.ARRAY_INDEX].size(),3):
   triangles[_triangle(a,i)]=true
 var center:=Vector2(36,12);var inner:=60.0
 var low: Vector2=((center-Vector2.ONE*inner)/16).floor()*16-Vector2.ONE*16
 var high: Vector2=((center+Vector2.ONE*inner)/16).ceil()*16+Vector2.ONE*16
 var join:=Rect2(low,high-low)
 var complete:=true;var count:=0
 for i in range(0,original[Mesh.ARRAY_INDEX].size(),3):
  var a: Vector3=original[Mesh.ARRAY_VERTEX][original[Mesh.ARRAY_INDEX][i]]
  var b: Vector3=original[Mesh.ARRAY_VERTEX][original[Mesh.ARRAY_INDEX][i+1]]
  var c: Vector3=original[Mesh.ARRAY_VERTEX][original[Mesh.ARRAY_INDEX][i+2]]
  var mid: Vector3=(a+b+c)/3
  if absf((b-a).cross(c-a).y)>.001 and not join.has_point(Vector2(mid.x,mid.z)):
   count+=1
   if not triangles.has(_triangle(original,i)):complete=false
 check(complete and count>0,"tiled coarse surface contains every original triangle without new holes")
 var fine:=FrontierDistantTerrain._arrays(field,Vector3i(1,0,0),2,600,{},false)
 check(near.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==fine[Mesh.ARRAY_VERTEX],"near transition ring remains exact")
 identities.clear()
 for key in near.tiles:identities[key]=near.tiles[key].node.mesh
 field.add_edit({"center":[85,field.height(85,12),12],"radius":5})
 near.request_rebuild(field,Vector3i(1,0,0),2,material,600)
 check(await settle(near) and near.last_built_tiles==0,"dig updates near cutout while reusing unedited coarse tiles")
 # Queue a move during generation, then a quality switch and a negative-coordinate jump.
 near.request_rebuild(field,Vector3i(2,0,0),2,material,2400)
 near.request_rebuild(field,Vector3i(-23,0,24),2,material,4800)
 check(await settle(near) and near.rendered_anchor==Vector3i(-23,0,24),"latest queued position and quality win")
 check(near.terrain_bounds().size.x>=9600 and near.prepared_tiles.is_empty(),"high distance coverage and upload batch release")
 near.request_rebuild(field,Vector3i.ZERO,2,material,600)
 check(await settle(near) and near.tiles.size()<=16,"lowering view distance removes obsolete tiles")
 near.free()
 # Compare warmed 2,400m CPU generation, excluding initial terrain creation.
 var samples: Dictionary={}
 old_distant._arrays(field,Vector3i.ZERO,2,2400,samples)
 var t:=Time.get_ticks_usec();old_distant._arrays(field,Vector3i(1,0,0),2,2400,samples)
 report.old_warm_distant_ms=(Time.get_ticks_usec()-t)/1000.0
 near=FrontierDistantTerrain.new();root.add_child(near)
 near.request_rebuild(field,Vector3i.ZERO,2,material,2400);await settle(near)
 near.request_rebuild(field,Vector3i(1,0,0),2,material,2400);await settle(near)
 report.new_warm_distant_ms=near.last_build_ms;report.rebuilt_tiles=near.last_built_tiles;report.total_tiles=near.tiles.size();report.max_tile_upload_ms=near.max_upload_ms;report.commit_ms=near.last_commit_ms
 near.free()
 # Check real physics before/after an atomic multi-chunk dig.
 var stream:=FrontierTerrainStreamer.new();stream.configure(71491,[],material);root.add_child(stream)
 stream.config.active_radius=1;stream.config.vertical_radius=0;stream.update_interests([Vector3(23,2,12)])
 var deadline:=Time.get_ticks_msec()+20000
 while not stream.ready_for([Vector3(23,2,12)]) and Time.get_ticks_msec()<deadline:await process_frame
 check(stream.ready_for([Vector3(23,2,12)]),"phased mesh/collision streamer becomes ready")
 await physics_frame;await physics_frame
 var query:=PhysicsRayQueryParameters3D.create(Vector3(23,15,12),Vector3(23,-5,12))
 check(not root.world_3d.direct_space_state.intersect_ray(query).is_empty(),"installed terrain supports a real physics ray")
 stream.dig(Vector3(24,1,12),4)
 var revisions: Dictionary={}
 for key in stream.batch:revisions[key]=stream.chunks[key].revision if stream.chunks.has(key) else -1
 var atomic:=true;deadline=Time.get_ticks_msec()+20000
 while not stream.batch.is_empty() and Time.get_ticks_msec()<deadline:
  for key in revisions:
   if stream.chunks.has(key) and int(stream.chunks[key].revision)!=int(revisions[key]):atomic=false
  await process_frame
 check(stream.batch.is_empty() and atomic,"old collision revisions stay until the entire dig commits")
 await physics_frame;await physics_frame
 check(root.world_3d.direct_space_state.intersect_ray(query).is_empty(),"dig removes the previously solid ray surface")
 report.max_visual_ms=stream.max_visual_ms;report.max_collision_ms=stream.max_collision_ms;report.max_commit_ms=stream.max_commit_ms
 stream.queue_free();await process_frame
 report.checks=checks;report.failures=failures
 FileAccess.open(OUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("TERRAIN_OPTIMIZATION ",JSON.stringify(report));quit(1 if failures else 0)
func _triangle(a: Array,i: int) -> String:
 return str([a[Mesh.ARRAY_VERTEX][a[Mesh.ARRAY_INDEX][i]],a[Mesh.ARRAY_VERTEX][a[Mesh.ARRAY_INDEX][i+1]],a[Mesh.ARRAY_VERTEX][a[Mesh.ARRAY_INDEX][i+2]]])

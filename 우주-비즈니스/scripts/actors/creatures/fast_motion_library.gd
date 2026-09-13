extends RefCounted
## Blender-local bone delta library, shared by identical actor/LOD paths. No world mutations.
static var libraries: Dictionary={}
static var profiles: Dictionary={}

static func install(actor: Node3D,player: AnimationPlayer,skeleton: Skeleton3D) -> Dictionary:
 var id: String=actor.definition.id
 var path: String="res://assets/animations/creatures/"+id+".motion"
 assert(FileAccess.file_exists(path),"Required fast motion asset missing: "+id)
 if not FileAccess.file_exists(path):return {}
 var skeleton_path: String=str(player.get_node(player.root_node).get_path_to(skeleton))
 var key:=id+":"+skeleton_path
 if not libraries.has(key):
  var packed:=FileAccess.get_file_as_bytes(path)
  var raw:=packed.decompress_dynamic(16000000,FileAccess.COMPRESSION_GZIP)
  var data: Dictionary=JSON.parse_string(raw.get_string_from_utf8())
  assert(int(data.version)==1 and data.species_id==id and int(data.profile.bone_count)==skeleton.get_bone_count(),"Fast motion skeleton mismatch: "+id)
  var library:=AnimationLibrary.new()
  for name in data.clips:
   var clip: Dictionary=data.clips[name];var animation:=Animation.new();animation.length=clip.duration;animation.loop_mode=Animation.LOOP_LINEAR
   for bone_name in clip.tracks:
    var bone:=skeleton.find_bone(bone_name);assert(bone>=0,"Fast motion missing bone: "+bone_name)
    var parent:=skeleton.get_bone_parent(bone)
    assert((skeleton.get_bone_name(parent) if parent>=0 else "")==str(data.parents[bone_name] if data.parents[bone_name]!=null else ""),"Fast motion parent mismatch")
    var rest:=skeleton.get_bone_rest(bone);var track_path:=NodePath(skeleton_path+":"+bone_name)
    var pos:=animation.add_track(Animation.TYPE_POSITION_3D);animation.track_set_path(pos,track_path)
    var rot:=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(rot,track_path)
    var scale_track:=animation.add_track(Animation.TYPE_SCALE_3D);animation.track_set_path(scale_track,track_path)
    var frames: Array=clip.tracks[bone_name]
    for i in frames.size():
     var v: Array=frames[i]
     var basis:=Basis(Quaternion(v[3],v[4],v[5],v[6])).scaled(Vector3(v[7],v[8],v[9]))
     var pose:=rest*Transform3D(basis,Vector3(v[0],v[1],v[2]))
     var time:=float(clip.duration)*i/(frames.size()-1)
     animation.position_track_insert_key(pos,time,pose.origin)
     animation.rotation_track_insert_key(rot,time,pose.basis.orthonormalized().get_rotation_quaternion())
     animation.scale_track_insert_key(scale_track,time,pose.basis.get_scale())
   library.add_animation(name,animation)
  libraries[key]=library;profiles[id]=data.profile
  # Existing players retain their library reference when the lookup cache evicts old species.
  if libraries.size()>96:libraries.erase(libraries.keys()[0])
 if not player.has_animation_library("fast"):player.add_animation_library("fast",libraries[key])
 return profiles[id]

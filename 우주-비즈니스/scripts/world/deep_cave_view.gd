extends Node3D
## One nearby authored gallery. No remote models are instantiated.
const MODEL="res://assets/models/underground/deep_strata.glb"
var surface:Node3D
var model:Node3D
var current:String=""
var requested:=false
var packed:PackedScene
var cache:Dictionary={}
var delay:=0.0
var checked_revision:=-1
func configure(owner_surface:Node3D)->void:surface=owner_surface
func _process(dt:float)->void:
 delay-=dt
 if delay>0:return
 delay=.3
 if surface.terrain.field.caves==null:return
 var at:Vector3=surface.viewer.position;var system:Dictionary=surface.terrain.field.caves.system_at(at.x,at.z);var deep:Dictionary=system.get("deep",{})
 var near:bool=not deep.is_empty() and at.distance_to(deep.floor)<85
 if not near:
  if model!=null:model.queue_free();model=null;current=""
  return
 if packed==null:
  if not requested:
   requested=true;ResourceLoader.load_threaded_request(MODEL)
  if ResourceLoader.load_threaded_get_status(MODEL)!=ResourceLoader.THREAD_LOAD_LOADED:return
  packed=ResourceLoader.load_threaded_get(MODEL)
 if model==null or current!=system.id:
  if model!=null:model.queue_free()
  model=packed.instantiate();add_child(model);model.position=deep.floor;current=system.id;checked_revision=-1
  FrontierInkStyle.apply(model,cache)
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   var solid:=StaticBody3D.new();mesh.add_child(solid);var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();solid.add_child(shape)
 if checked_revision!=surface.terrain.field.revision:
  checked_revision=surface.terrain.field.revision
  # Remove the whole gallery if excavation takes away either structural foot.
  var supported:=true
  for offset in [Vector3(-7.5,0,-2),Vector3(7.5,0,-2)]:
   if surface.terrain.field.density(deep.floor+offset-Vector3.UP*.4)<=0:supported=false
  model.visible=supported
  for solid in model.find_children("*","StaticBody3D",true,false):solid.collision_layer=1 if supported else 0

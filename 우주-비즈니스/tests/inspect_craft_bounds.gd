extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var models: Dictionary={}
 for key in FrontierSpaceStation.config().hulls:models[key]=FrontierSpaceStation.config().hulls[key].get("model","res://assets/models/ships/kestrel.glb")
 models.finch=FrontierShuttles.config().model
 for key in FrontierSpaceCombat.config().enemy:models[key]=FrontierSpaceCombat.config().enemy[key].model
 var report: Dictionary={}
 for key in models:
  var node: Node3D=load(models[key]).instantiate();root.add_child(node)
  var box:=AABB();var first:=true
  for mesh in node.find_children("*","MeshInstance3D",true,false):
   var b: AABB=mesh.global_transform*mesh.mesh.get_aabb()
   box=b if first else box.merge(b);first=false
  report[key]={"center":FrontierSpaceCombat.arr(box.get_center()),"size":FrontierSpaceCombat.arr(box.size),"radius":box.size.length()*.5+1.0}
  node.free()
 FileAccess.open("res://../output/gameplay-physics-20260913/bounds.json",FileAccess.WRITE).store_string(JSON.stringify(report," "))
 print(report);quit()

extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var result: Dictionary={"version":1,"submerge_margin":0.05,"bounds":{}}
 for kind in FrontierCatalog.table("buildings"):
  var model: Node3D=load("res://assets/models/"+str(FrontierCatalog.entry("buildings",kind).model)+".glb").instantiate();root.add_child(model)
  var tiers: Dictionary={}
  for tier in [1,2,3]:
   if tier==3 and kind!="factory":continue
   if tier==2 and not FrontierProductionTier2.config().facility_upgrades.has(kind):continue
   if tier==2:
    var pack: Node3D=load("res://assets/models/products/retrofit_pack.glb").instantiate();model.add_child(pack);pack.position=Vector3(.75,1.2,.7);pack.rotation.y=PI;pack.scale=Vector3.ONE*1.25
   if tier==3:
    var core: Node3D=load("res://assets/models/products/control_circuit.glb").instantiate();model.add_child(core);core.position=Vector3(1.12,2,1.34);core.rotation=Vector3(PI/2,0,0);core.scale=Vector3.ONE*.65
   var bounds:=AABB();var first:=true
   for mesh in model.find_children("*","MeshInstance3D",true,false):
    var box: AABB=(model.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
    bounds=box if first else bounds.merge(box);first=false
   tiers[str(tier)]={"min":[bounds.position.x,bounds.position.y,bounds.position.z],"max":[bounds.end.x,bounds.end.y,bounds.end.z]}
  result.bounds[kind]=tiers;model.free()
 FileAccess.open("res://data/facility_water_bounds.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("Exported bounds for ",result.bounds.size()," existing facility models");quit()

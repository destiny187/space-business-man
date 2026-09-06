extends SceneTree
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var forms: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/forms.json")).forms
 var actor:=Actor.new();root.add_child(actor);actor.set_process(false)
 var checked:=0;var failed:=0
 var seen: Dictionary={}
 for i in range(forms.size()):
  if seen.has(forms[i].family):continue
  seen[forms[i].family]=true
  var form: Dictionary=forms[i]
  var original: Node3D=load("res://"+str(form.lods.near.path).trim_prefix("우주-비즈니스/")).instantiate()
  actor.configure(form)
  for mesh in original.find_children("*","MeshInstance3D",true,false):
   for surface in range(mesh.mesh.get_surface_count()):
    var material: StandardMaterial3D=mesh.get_active_material(surface)
    var slot: String=material.resource_name.trim_prefix("Bio_")
    if slot not in ["main","secondary","accent"]:continue
    for applied in actor.material_slots.get(slot,[]):
     var color: Color=applied.get_shader_parameter("base_color")
     var difference: Vector3=Vector3(color.r-material.albedo_color.r,color.g-material.albedo_color.g,color.b-material.albedo_color.b)
     checked+=1
     if difference.length()>.002:failed+=1;push_error("GLB / runtime palette differs: "+form.id+" "+slot)
  original.free()
 var dest:=ProjectSettings.globalize_path("res://../docs/production/media/bestiary/color-verification.json")
 FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify({"checks":checked,"failures":failed,"scope":"Imported GLB color versus runtime default palette, all body families"},"  "))
 print("BESTIARY_COLOR_CHECKS ",checked," FAILURES ",failed);actor.free();quit(0 if failed==0 else 1)

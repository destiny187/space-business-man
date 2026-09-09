extends "res://scripts/showcase/ink_samples.gd"
const Creature=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var cases: Dictionary={}
func _ready() -> void:
 cases=JSON.parse_string(FileAccess.get_file_as_string("/tmp/native-incidents/samples.json"))
 samples=[]
 for kind in cases:samples.append({"id":kind})
 super._ready()
func select_sample(which: int) -> void:
 index=which
 if is_instance_valid(subject):stage.remove_child(subject);subject.queue_free()
 subject=Node3D.new();stage.add_child(subject)
 var row: Dictionary=cases[samples[index].id].row;var native: Dictionary=row.native
 var form:=FrontierEcologyCatalog.form(native.form_id)
 var spacing:=maxf(float(native.width),float(native.length))*.7
 for special in [false,true]:
  var creature:=Creature.new();creature.load_far=false;creature.configure(form,FrontierNativeIncidents.look(native) if special else FrontierEcologyCatalog.look(native.form_id,native.look_id));subject.add_child(creature)
  creature.position.x=spacing if special else -spacing;creature.set_state("stressed" if native.role=="guardian" and special else "idle")
 var box:=bounds(subject);var center:=box.get_center();camera.position=center+Vector3(1,.45,2).normalized()*box.size.length()*2.4;camera.look_at(center);camera.size=box.size.length()*1.1;camera.far=200;target=center
 studio_ground.position.y=box.position.y-.02;studio_ground.scale=Vector3.ONE*maxf(1,box.size.length()*.2)
 title.text="NATIVE LIFE / "+str(FrontierNativeIncidents.config().roles[native.role].name)
 subtitle.text="왼쪽 현지 기본 개체 · 오른쪽 사건 개체 %.0f%% / %.2fm\n%s"%[float(native.factor)*100,float(native.height),form.name]
func capture_all() -> void:
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/native-incidents/");DirAccess.make_dir_recursive_absolute(out)
 await get_tree().process_frame;helper.hide()
 for i in samples.size():
  select_sample(i);await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(out+samples[i].id+".png")
 print("NATIVE_RENDER_OK");get_tree().quit()

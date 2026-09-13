extends SceneTree
const Registry=preload("res://scripts/actors/creatures/remodel_registry.gd")
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
const Preview=preload("res://scripts/ui/equipment_preview.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var signatures: Array=[FrontierEcologyCatalog.signature(),FrontierEcologyCatalog.extension_signature(),FrontierEcologyCatalog.flora_signature(),FrontierEcologyCatalog.biota_signature()]
 var animal_count:=0;var other_count:=0
 for form in FrontierEcologyCatalog.all_forms():
  var row:=Registry.entry(form)
  if form.category=="animal":
   animal_count+=1;check(not row.is_empty(),str(form.id)+" has required anatomy")
   for lod in ["near","far"]:
    check(not FileAccess.file_exists("res://"+str(form.lods[lod].path).trim_prefix("우주-비즈니스/")),"retired animal source absent")
  else:other_count+=1;check(row.is_empty(),"plant/microbe presentation preserved")
  for lod in ["near","far"]:check(ResourceLoader.exists(Registry.path(form,lod)),str(form.id)+" "+lod+" imported resource exists")
 check(animal_count==5600 and other_count==2400,"complete animal/plant/microbe census")
 print("RETIREMENT_PATHS 5600 animals and 2400 plants/microbes; 16000 current LODs available")
 var ids: Array=["bio_quill_amphora_01","bio_hinge_book_01","biota_amphora_antennal_fans_01","biota_amphora_antennal_fans_25","biota_amphora_antennal_fans_09","bio_accordion_shell_01"]
 for category in ["plant","microbe"]:
  for form in FrontierEcologyCatalog.all_forms():
   if form.category==category:ids.append(form.id);break
 root.size=Vector2i(1120,720);root.content_scale_size=root.size
 var grid:=GridContainer.new();grid.columns=4;grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(grid)
 var previews: Array=[];var specimens: Array=[]
 for id in ids:
  var form:=FrontierEcologyCatalog.form(id)
  var sample: Dictionary={"form_id":id,"look_id":FrontierEcologyCatalog.look_for_seed(id,23),"source_body":"retirement-check","id":("retirement-check:"+str(id)).sha256_text()}
  var original:=JSON.stringify(form)
  var item_key:=FrontierSpecimenItems.resource(sample)
  var item:=FrontierSpecimenItems.entry(item_key)
  check(FrontierSpecimenItems.decode(item_key)==sample,"existing specimen identity round trip")
  if item.is_empty():quit(1);return
  check(item.model==FrontierEcologyCatalog.model_key(form),"inventory uses current presentation")
  var actor:=Actor.new();actor.defer_far=true;actor.configure(form);root.add_child(actor);actor.set_process(false)
  check(actor.models.size()==1 and actor.finish_lods() and actor.models.size()==2,"near plus deferred far loads")
  if form.category=="animal":
   check(actor.remodel.source_id==id and actor.anatomical_skeletons[0]!=null,"current rig installed")
   var incident:=FrontierNativeIncidentView.make_actor({"form_id":id},{});root.add_child(incident)
   check(incident.remodel.source_id==id,"native incident retains new anatomy");incident.free()
  actor.free()
  var column:=VBoxContainer.new();column.custom_minimum_size=Vector2(275,350);grid.add_child(column)
  var label:=Label.new();label.text=id;label.add_theme_font_size_override("font_size",12);column.add_child(label)
  var preview:=Preview.new();preview.custom_minimum_size=Vector2(275,315);column.add_child(preview);preview.show_specimen(sample)
  check(preview.model!=null and preview.model_path==item.model,"journal/sample preview loads current asset")
  check(JSON.stringify(form)==original,"catalogue row unchanged")
  previews.append(preview);specimens.append(sample)
 var peer_node: int=previews[1].model.get_instance_id()
 var first_node: int=previews[0].model.get_instance_id()
 previews[0].show_specimen(specimens[0]);previews[0].show_specimen(specimens[0])
 check(previews[0].model.get_instance_id()==first_node and previews[1].model.get_instance_id()==peer_node,"repeat selection reuses model and leaves other preview intact")
 previews[1].hide();previews[1]._process(0)
 check(previews[1].viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"hidden preview stays inactive")
 previews[1].show()
 check(signatures==[FrontierEcologyCatalog.signature(),FrontierEcologyCatalog.extension_signature(),FrontierEcologyCatalog.flora_signature(),FrontierEcologyCatalog.biota_signature()],"save compatibility signatures preserved")
 if "--render" in OS.get_cmdline_user_args():
  for i in 5:await process_frame
  for preview in previews:preview.request_render();preview._process(0)
  RenderingServer.force_draw(false);await process_frame;RenderingServer.force_draw(false)
  var folder:=ProjectSettings.globalize_path("res://../output/asset-retirement")
  DirAccess.make_dir_recursive_absolute(folder)
  root.get_texture().get_image().save_png(folder+"/current-previews.png")
 print("RETIREMENT_RUNTIME 6 animal batches, plant, microbe; preview/LOD/native/sample/scope; failures=",failures)
 grid.queue_free();await process_frame
 quit(1 if failures else 0)

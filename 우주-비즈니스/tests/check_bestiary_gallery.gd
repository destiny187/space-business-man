extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label);push_error(label)
func key(code: Key) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.pressed=true;Input.parse_input_event(event)
 await process_frame
 event=InputEventKey.new();event.keycode=code;event.pressed=false;Input.parse_input_event(event)
 await process_frame
func run() -> void:
 var gallery: Node3D=load("res://scenes/showcase/bestiary.tscn").instantiate();root.add_child(gallery)
 await process_frame
 check(gallery.forms.size()==600 and gallery.appearances.size()==12000,"Catalogue counts")
 await key(KEY_RIGHT);check(gallery.selected==1,"Keyboard selects next form")
 await key(KEY_UP);check(gallery.variant==1,"Keyboard selects next appearance")
 gallery.family_picker.select(10);gallery.family_picker.item_selected.emit(10)
 check(gallery.forms[gallery.selected].family=="ray","Family filter uses selected family")
 check(gallery.attack_button.disabled,"Peaceful family disables attack")
 gallery.family_picker.select(7);gallery.family_picker.item_selected.emit(7)
 check(gallery.forms[gallery.selected].family=="mantid","Attack family selection")
 gallery.attack_button.pressed.emit()
 check(gallery.actor.state=="attack","Attack button triggers animation")
 await key(KEY_SPACE);check(gallery.actor.paused,"Pause key")
 gallery.actor.elapsed=.68;gallery.actor.pose()
 var effects_on:=false
 for effect in gallery.actor.effect_nodes:effects_on=effects_on or effect.visible
 check(effects_on,"Active attack has effects")
 for button in gallery.find_children("*","Button",true,false):
  if button.text=="효과 켜기/끄기":button.pressed.emit()
 var effects_off:=true
 for effect in gallery.actor.effect_nodes:effects_off=effects_off and not effect.visible
 check(effects_off,"Effect toggle updates even while paused")
 for button in gallery.find_children("*","Button",true,false):
  if button.text=="근거리 / 원거리 모델":button.pressed.emit()
 await process_frame
 check(gallery.actor.models[1].visible and not gallery.actor.models[0].visible,"LOD control switches visible geometry")
 for button in gallery.find_children("*","Button",true,false):
  if button.text=="근거리 / 원거리 모델":button.pressed.emit()
 gallery.change_state("attack")
 var original_light: Vector3=gallery.light.rotation
 gallery.light_button.pressed.emit();check(not gallery.light.rotation.is_equal_approx(original_light),"Light control changes illumination")
 var original_camera: Vector3=gallery.camera.position
 await key(KEY_R)
 await create_timer(.15).timeout
 check(not gallery.camera.position.is_equal_approx(original_camera),"Orbit control moves camera")
 gallery.filter_family(gallery.families.find("blind_harp"))
 check(gallery.selected==500 and gallery.info.text.contains("눈 0개"),"Eyeless collection selectable and labelled")
 gallery.filter_family(gallery.families.find("eye_orchard"))
 check(gallery.info.text.contains("눈 5개"),"Multiple-eye anatomy labelled")
 gallery.orbit=false
 gallery.light_index=2
 gallery.cycle_light()
 await process_frame
 await process_frame
 var dest:=ProjectSettings.globalize_path("res://../docs/production/media/bestiary/")
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(dest+"gallery-ui.png")
 FileAccess.open(dest+"gallery-verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("BESTIARY_GALLERY_CHECKS ",checks," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)

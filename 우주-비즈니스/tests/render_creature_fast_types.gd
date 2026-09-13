extends "res://tests/render_creature_speed_audit.gd"
## Representative additional anatomies: actual imported near/far models and runtime gait selection.
func _initialize() -> void:
 folder=ProjectSettings.globalize_path("res://../output/creature-fast-motion/types")
 super._initialize()
func run() -> void:
 root.size=Vector2i(1280,600);root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(folder)
 var selection: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../tools/creature_remodel/fast_motion_review.json")).additional
 for id in selection:
  var form:=FrontierEcologyCatalog.form(id);panels=[]
  for i in 2:
   var p:=panel(1,form);p.holder.position.x=i*640;p.label.position.x=i*640+18
   p.actor.free()
   var actor:=Actor.new();actor.lod_override=i;actor.show_effects=false
   actor.configure(form,{"scale":1.,"palette":form.palette});p.camera.get_parent().add_child(actor);actor.set_process(false)
   actor.models[0].visible=i==0;actor.models[1].visible=i==1;actor.visible_model=i
   p.actor=actor;p.previous={};panels.append(p)
  var art: Dictionary=panels[0].actor.remodel;var fp: Dictionary=panels[0].actor.ground_motion.fast_profile
  assert(not fp.is_empty(),"Missing fast type: "+id)
  var out: String=folder+"/"+str(id);DirAccess.make_dir_recursive_absolute(out)
  var seen: Dictionary={};var max_contact:=0.;var max_body:=0.
  var airborne: bool=fp.mode in ["flight","swim","float"]
  for frame in 150:
   var t:=frame/30.;var fast: bool=t>=1.2 and t<3.2
   var speed: float=panels[0].actor.ground_motion.natural(art.motion_profile) if t<1.2 else float(fp.natural_speed)*1.18
   if t>=3.2:speed*=clampf((4.-t)/.8,0,1)
   for i in 2:
    var p: Dictionary=panels[i];var actor=p.actor;var m=actor.ground_motion
    p.at.z+=speed/30.
    actor.state="move" if speed>.02 else "idle"
    if airborne:
     actor.position=p.at;actor.movement_rate=speed/m.natural(art.motion_profile)
     if art.get("air_motion",false):
      actor.flight_speed=speed;actor.flight_blend=1.;actor.flight_clock=float(form.flight.rest_seconds)+float(form.flight.transition_seconds)+t
     m.preview(1./30.)
    else:
     if frame%3==0:p.snapshot=p.at
     actor.locomotion_stamp=float((frame/3)*3)/30.
     actor.drive_ground(p.snapshot,Basis.IDENTITY,1./30.,probe,false,0)
    m.tick(1./30.);actor.pose(true);seen[m.wanted_clip]=true
    max_contact=maxf(max_contact,m.grounded_error);max_body=maxf(max_body,m.body_contact_error)
    var bounds: Dictionary=art.lods.near
    var low:=Vector3(bounds.min[0],bounds.min[1],bounds.min[2]);var high:=Vector3(bounds.max[0],bounds.max[1],bounds.max[2])
    var extent: float=(high-low).length();var center: Vector3=m.point+(low+high)*.5
    p.camera.size=maxf(2.5,extent*1.2);p.camera.far=extent*8+30;p.camera.position=center+Vector3(1.2,.65,-1.0).normalized()*extent*2.5;p.camera.look_at(center)
    p.label.text="%s · %s\n%s · %s\n%.2f m/s · %s"%[art.name,"근거리" if i==0 else "원거리",fp.mode,"고속" if fast else ("정지" if speed<=.02 else "전환"),speed,m.wanted_clip]
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/frame-%03d.png"%frame)
  assert(seen.has("sprint_loop"),"Fast clip never selected: "+id)
  report.append({"species_id":id,"kind":art.kind,"mode":fp.mode,"bones":fp.bone_count,"seen_clips":seen.keys(),"max_ground_error":max_contact,"max_body_error":max_body})
  for p in panels:p.holder.free();p.label.free()
  print("FAST_TYPE_RENDER ",id," ",fp.mode," contacts=",max_contact)
 FileAccess.open(folder+"/evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"fps":30,"scope":"Imported near/far LOD speed selection, authored high-speed demand and transitions. Flight/swim/float demand is a preview, not new AI.","species":report},"  "))
 quit()

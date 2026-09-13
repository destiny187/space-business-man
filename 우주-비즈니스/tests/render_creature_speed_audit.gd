extends SceneTree
## Isolated A/B research: same current campaign actor, speed and ground; no save or balance writes.
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
const IDS=["biota_spindle_armor_25","biota_lobopod_armor_26","bio_quill_amphora_01","biota_chain_armor_26","biota_ribbon_armor_26"]
class WalkOnly:
 extends "res://scripts/actors/creatures/remodel_motion.gd"
 func advance(travel: float,delta: float) -> void:
  idle_clock+=delta;sound_left=maxf(0,sound_left-delta)
  travel_speed=travel/maxf(.001,delta);speed=lerpf(speed,travel_speed,1-exp(-delta/.12))
  if actor.paused:return
  # Keep contact state intact; forcing gait AFTER super.advance would clear it every frame.
  gait="move_loop";running=0.
  phase+=travel/maxf(.001,actor.base_scale)/(float(profile.stride)/float(profile.stance))
var folder:=ProjectSettings.globalize_path("res://../output/creature-speed-audit-20260913")
var panels: Array=[]
var report: Array=[]
func _initialize() -> void:run.call_deferred()
func probe(at: Vector3,_reach: float) -> Dictionary:return {"point":Vector3(at.x,0,at.z),"normal":Vector3.UP}
func panel(index: int,form: Dictionary) -> Dictionary:
 var holder:=SubViewportContainer.new();root.add_child(holder);holder.position=Vector2(index*640,0);holder.size=Vector2(640,600)
 var viewport:=SubViewport.new();viewport.size=Vector2i(640,600);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;holder.add_child(viewport)
 var stage:=Node3D.new();viewport.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("ced7d0");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("bdccce");env.environment.ambient_light_energy=.52;stage.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.shadow_enabled=true;sun.directional_shadow_max_distance=28;stage.add_child(sun)
 var floor:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(200,200);floor.mesh=mesh;stage.add_child(floor)
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("b7c1ae");floor.material_override=FrontierInkStyle.material(mat,{})
 var stripe_mat:=StandardMaterial3D.new();stripe_mat.albedo_color=Color("829686")
 for z in range(-5,100):
  var mark:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(12,.006,.025);mark.mesh=box;mark.material_override=FrontierInkStyle.material(stripe_mat,{});stage.add_child(mark);mark.position=Vector3(0,.004,z)
 var actor:=Actor.new();actor.load_far=false;actor.lod_override=0;actor.show_effects=false;actor.configure(form,{"scale":1.,"palette":form.palette});stage.add_child(actor);actor.set_process(false)
 if index==0:
  actor.ground_motion=WalkOnly.new();actor.ground_motion.configure(actor,actor.visual_root)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.8;camera.near=.05;camera.far=35;camera.current=true;stage.add_child(camera);FrontierInkStyle.attach(stage,true)
 var label:=Label.new();root.add_child(label);label.position=holder.position+Vector2(18,16);label.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"));label.add_theme_font_size_override("font_size",20);label.add_theme_color_override("font_color",Color("203a36"))
 return {"holder":holder,"actor":actor,"camera":camera,"label":label,"previous":{},"trace":[],"at":Vector3.ZERO,"snapshot":Vector3.ZERO}
func record(p: Dictionary,frame: int,section: String,requested: float) -> void:
 var m=p.actor.ground_motion;var skeleton: Skeleton3D=p.actor.anatomical_skeletons[0]
 var feet: Array=[]
 for limb in m.authored_limbs:
  var actual: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(limb.foot)).origin
  var planted: bool=m.planted.has(limb.name)
  var previous: Dictionary=p.previous.get(limb.name,{})
  var slip: float=actual.distance_to(previous.at) if planted and previous.get("planted",false) else -1.
  feet.append({"name":limb.name,"planted":planted,"slip_m":slip,"height_m":actual.y-float(limb.sole),"target_error_m":actual.distance_to(m.planted[limb.name]) if planted else -1.})
  p.previous[limb.name]={"at":actual,"planted":planted}
 var data: Dictionary=m.gait_data()
 p.trace.append({"frame":frame,"section":section,"requested_mps":requested,"visual_mps":m.travel_speed,"clip":m.wanted_clip,"phase":m.phase,"cycle_hz":m.travel_speed/(float(data.stride)/float(data.stance)),"clip_rate":m.travel_speed/m.natural(data),"root_error_m":p.actor.global_position.distance_to(p.snapshot),"feet":feet,"body_error_m":m.body_contact_error})
func run() -> void:
 root.size=Vector2i(1280,600);root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(folder)
 var filter:=Array(OS.get_cmdline_user_args())
 var smooth:=filter.has("--smooth")
 if smooth:filter.erase("--smooth");folder+="/smooth";DirAccess.make_dir_recursive_absolute(folder)
 for id in IDS:
  if not filter.is_empty() and id not in filter:continue
  var form:=FrontierEcologyCatalog.form(id)
  panels=[panel(0,form),panel(1,form)]
  var art: Dictionary=panels[1].actor.remodel;var profile: Dictionary=art.motion_profile
  var look_id:=FrontierEcologyCatalog.look_for_seed(id,0)
  var info:=FrontierWildlifeCombat.profile({"form_id":id,"look_id":look_id,"combat_tier":5})
  var walk: float=panels[1].actor.ground_motion.natural(profile);var run_speed: float=panels[1].actor.ground_motion.natural(profile.run)
  var out:=folder+"/"+str(art.id);DirAccess.make_dir_recursive_absolute(out)
  for frame in 360:
   var t:=frame/30.0;var speed:=walk;var section:="걷기 기준";var phase:="chase";var clock:=t
   if t>=2 and t<4:speed=run_speed;section="달리기 제작 기준"
   elif t>=4 and t<7:speed=float(info.speed);section="T5 추격" if info.pattern!="none" else "T5 도주";phase="chase" if info.pattern!="none" else "flee"
   elif t>=7 and t<9:
    if info.get("behavior","")=="charge":speed=float(info.charge_speed);section="T5 돌진 속도 · 지속 비교";phase="attack";clock=float(info.windup)+fposmod(t-7,float(info.active)*.9)
    else:speed=float(info.speed);section="피격 후 180도 도주";phase="flee"
   elif t>=9 and t<10:speed=float(info.speed)*(1-(t-9));section="감속"
   elif t>=10:speed=0;section="정지";phase="return"
   var yaw:=PI if t>=7 and info.get("behavior","")!="charge" else 0.
   for i in 2:
    var p: Dictionary=panels[i];var actor=p.actor;var m=actor.ground_motion
    p.at+=Vector3(sin(yaw),0,cos(yaw))*speed/30.
    if smooth or frame%3==0:p.snapshot=p.at
    actor.apply_combat({"phase":phase,"time":clock,"motion_clock":float(frame if smooth else (frame/3)*3)/30.,"attack":{},"air_height":0.},info,false)
    actor.drive_ground(p.snapshot,Basis(Vector3.UP,yaw),1./30.,probe,false,0)
    if i==0:
     # Counterfactual only: keep the walking geometry and retime it to the same travel.
     actor.combat_override=false;actor.state="move" if speed>0 else "idle"
    m.tick(1./30.);actor.pose(true)
    record(p,frame,section,speed)
    var center: Vector3=m.point+Vector3.UP*1.25
    p.camera.position=center+Vector3(7,2.8,-4);p.camera.look_at(center)
    var data: Dictionary=m.gait_data()
    p.label.text="%s · %s\n%s\n%.2f m/s · 클립 %.1f배"%[art.name,"걷기만 배속" if i==0 else "현재 런타임",section,speed,m.travel_speed/m.natural(data)]
   await process_frame;await RenderingServer.frame_post_draw
   if not smooth or frame in [45,90,165,230,320]:root.get_texture().get_image().save_png(out+"/frame-%03d.png"%frame)
  var row: Dictionary={"species_id":id,"art_id":art.id,"kind":art.kind,"scale":1.,"walk_mps":walk,"authored_run_mps":run_speed,"combat":info,"source":art.get("source",""),"lod":art.lods.near,"panels":[]}
  for i in 2:
   var p: Dictionary=panels[i]
   FileAccess.open(out+("/walk-only.json" if i==0 else "/runtime.json"),FileAccess.WRITE).store_string(JSON.stringify(p.trace))
   row.panels.append({"mode":"walk-only" if i==0 else "runtime","samples":p.trace.size()})
   p.holder.free();p.label.free()
  report.append(row);print("CREATURE_SPEED_AUDIT ",art.id," walk=",walk," authored_run=",run_speed," combat=",info.speed)
 FileAccess.open(folder+"/evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"fps":30,"snapshot_hz":30 if smooth else 10,"scale":1.,"scope":"Isolated flat-ground campaign actors. Sustained charge stress comparison; no damage/save/network session test.","species":report},"  "))
 quit()

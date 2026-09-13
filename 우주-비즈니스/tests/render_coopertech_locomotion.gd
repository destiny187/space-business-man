extends SceneTree
const Driver=preload("res://scripts/world/coopertech_squad_view.gd")
var panels: Array=[]
var folder:=ProjectSettings.globalize_path("res://../output/gameplay-physics-20260913")
func _initialize() -> void:run.call_deferred()
func panel(role: String,index: int) -> Dictionary:
 var holder:=SubViewportContainer.new();root.add_child(holder);holder.position=Vector2(index*480,0);holder.size=Vector2(480,540)
 var viewport:=SubViewport.new();viewport.size=Vector2i(480,540);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;holder.add_child(viewport)
 var stage:=Node3D.new();viewport.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("97a8b6");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("bdc7d5");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.shadow_enabled=true;stage.add_child(light)
 var floor:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(150,150);floor.mesh=mesh;stage.add_child(floor)
 var material:=StandardMaterial3D.new();material.albedo_color=Color("989784");floor.material_override=FrontierInkStyle.material(material,{})
 for i in range(-70,71,2):
  var mark:=MeshInstance3D.new();var line:=BoxMesh.new();line.size=Vector3(150,.01,.025);mark.mesh=line;stage.add_child(mark);mark.position=Vector3(0,.005,i);mark.material_override=FrontierInkStyle.material(material,{})
 var mount:=Node3D.new();stage.add_child(mount)
 var cfg: Dictionary=FrontierCooperTechSquads.config().roles[role]
 var model: Node3D=load("res://assets/models/incidents/"+str(cfg.model)+".glb").instantiate();mount.add_child(model);FrontierInkStyle.apply(model,{})
 var parts:=model.find_children("Anim_*","Node3D",true,false)
 for part in parts:part.set_meta("rest",part.transform)
 var view:=FrontierIncidentView.new();view.attack_effects=preload("res://scripts/world/coopertech_attack_effects.gd").new()
 var row: Dictionary={"id":"review","robot_role":role,"tier":5,"position":[0,0,0],"yaw":0.0,"hp":100.0,"phase":"patrol","time":0.0,"age":0.0,"travel":0.0,"attack_serial":0,"shot_start":[],"shot_end":[]}
 var nodes: Dictionary={"root":mount,"main":model,"relay":Node3D.new(),"parts":parts,"beam":null};mount.add_child(nodes.relay);Driver.build(view,row,nodes)
 var camera:=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.8 if role!="raptor" else 4.1;camera.current=true
 FrontierInkStyle.attach(stage)
 var label:=Label.new();root.add_child(label);label.position=holder.position+Vector2(15,15)
 return {"view":view,"row":row,"nodes":nodes,"camera":camera,"label":label,"at":Vector3.ZERO,"velocity":Vector3.ZERO,"speed":float(FrontierCooperTechSquads.spec(row).speed),"slip":0.0,"planted_rotation":0.0,"stance_samples":0,"previous":{},"last_speed":0.0,"max_acceleration":0.0,"worst":{},"air_frames":0,"trace":[]}
func run() -> void:
 root.size=Vector2i(1440,540);root.content_scale_size=root.size
 for i in 3:panels.append(panel(["sentry","bastion","raptor"][i],i))
 var report: Dictionary={}
 for frame in 600:
  for p in panels:
   var segment:=frame/120
   var desired: Vector3=Vector3.FORWARD*p.speed*(.35 if segment==0 else 1.0)
   if segment==2:desired=Vector3.RIGHT*p.speed*.52
   elif segment==3:desired=Vector3.BACK*p.speed*.72
   elif segment==4:desired=Vector3.ZERO
   p.velocity=Vector3(p.velocity).move_toward(desired,float(FrontierCooperTechSquads.spec(p.row).acceleration)/60)
   p.at+=Vector3(p.velocity)/60.0
   if frame%6==0:p.row.position=FrontierSpaceCombat.arr(p.at);p.row.move_velocity=FrontierSpaceCombat.arr(p.velocity);p.row.motion_clock=float(frame)/60
   if segment==4:p.row.yaw=minf(PI,float(frame-480)/60*2.0)
   Driver.update(p.view,p.row,p.nodes,1.0/60,false)
   var motion: RefCounted=p.nodes.locomotion
   if motion.limbs.all(func(l):return l.swing):p.air_frames+=1
   p.trace.append({"frame":frame,"speed":motion.velocity.length(),"phase":motion.phase,"feet":motion.limbs.map(func(l):return {"swing":l.swing,"target_error":motion.pose(l.foot).origin.distance_to(l.position)})})
   for i in motion.limbs.size():
    var limb: Dictionary=motion.limbs[i];var actual: Vector3=motion.pose(limb.foot).origin
    if not limb.swing and p.previous.has(i) and not p.previous[i].swing:
     var slip:=actual.distance_to(p.previous[i].position)
     if slip>p.slip:p.worst={"frame":frame,"limb":i,"error":actual.distance_to(limb.position),"rest":FrontierSpaceCombat.arr(limb.rest),"upper":limb.upper,"lower":limb.lower}
     p.slip=maxf(p.slip,slip);p.stance_samples+=1
     p.planted_rotation=maxf(p.planted_rotation,motion.pose(limb.foot).basis.orthonormalized().get_rotation_quaternion().angle_to(p.previous[i].rotation))
    p.previous[i]={"position":actual,"swing":limb.swing,"rotation":motion.pose(limb.foot).basis.orthonormalized().get_rotation_quaternion()}
   var target: Vector3=p.nodes.root.global_position+Vector3.UP*(1.7 if p.row.robot_role=="bastion" else 1.35 if p.row.robot_role=="sentry" else .75)
   p.camera.global_position=target+Vector3(6,2.5,-5);p.camera.look_at(target)
   p.label.text="%s · %s\n%.2f m/s"%[p.row.robot_role,["slow","fast","strafe","reverse","stop / turn"][segment],motion.velocity.length()]
  await process_frame
  if frame in [80,180,290,410,570]:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder+"/motion-%03d.png"%frame)
 for p in panels:
  report[p.row.robot_role]={"max_planted_frame_displacement_m":p.slip,"stance_samples":p.stance_samples,"planted_rotation_rad":p.planted_rotation,"worst":p.worst,"air_frames":p.air_frames}
  FileAccess.open(folder+"/gait-"+str(p.row.robot_role)+".json",FileAccess.WRITE).store_string(JSON.stringify(p.trace))
  p.view.attack_effects.free();p.view.free()
 FileAccess.open(folder+"/render-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MOTION_RENDER_DONE ",report);quit()

extends RefCounted
## Reuses production INK models and ElevenLabs effects, with host phase/attack clocks.
static func build(view: FrontierIncidentView,row: Dictionary,nodes: Dictionary) -> void:
 nodes.relay.hide()
 var player: AnimationPlayer=nodes.main.find_child("AnimationPlayer",true,false)
 nodes.robot_animation=player;nodes.robot_clip="";nodes.robot_step=0.0;nodes.robot_attack=int(row.attack_serial);nodes.robot_phase=row.phase;nodes.robot_pose_clock=float(row.time);nodes.robot_travel=float(row.travel)
 nodes.robot_weapon={}
 var sampler: Callable
 if view.surface!=null:sampler=func(at: Vector3):return {"height":view.surface.terrain.field.height(at.x,at.z)}
 nodes.locomotion=preload("res://scripts/world/coopertech_locomotion.gd").new()
 nodes.locomotion.configure(nodes,row,sampler)
 if player!=null and player.has_animation("fire"):
  var fire: Animation=player.get_animation("fire")
  for track in fire.get_track_count():
   var path:=fire.track_get_path(track)
   if fire.track_get_type(track)!=Animation.TYPE_POSITION_3D or path.get_subname_count()==0 or str(path.get_subname(0))!="weapon":continue
   var skeleton: Skeleton3D=player.get_node(player.root_node).get_node(NodePath(path.get_concatenated_names()))
   if skeleton!=null:nodes.robot_weapon={"skeleton":skeleton,"bone":skeleton.find_bone("weapon"),"track":track,"animation":fire}
 var audio:=AudioStreamPlayer3D.new();audio.stream=load("res://assets/audio/sfx_robot_move.wav");audio.bus="SFX";audio.volume_db=-19;audio.unit_size=7;audio.max_distance=40;nodes.root.add_child(audio);nodes.robot_motor=audio
static func dispose(_nodes: Dictionary) -> void:
 pass
static func update(view: FrontierIncidentView,row: Dictionary,nodes: Dictionary,delta: float,stopped: bool) -> void:
 var cfg:=FrontierCooperTechSquads.spec(row);var root: Node3D=nodes.root
 nodes.locomotion.update_position(row,delta,stopped)
 var moving: bool=nodes.locomotion.moving
 if not stopped:nodes.robot_travel+=nodes.locomotion.travel
 if not stopped:nodes.robot_pose_clock=float(row.time) if row.phase!=nodes.robot_phase else maxf(float(row.time),float(nodes.robot_pose_clock)+delta)
 var player: AnimationPlayer=nodes.robot_animation
 if player!=null:
  var clip: String="cool" if row.phase=="cooling" else ("ready" if moving else ("idle" if row.phase=="idle" else ("wake" if row.phase=="waking" else ("destroyed" if row.hp<=0 else ("fire" if row.phase in ["projectile","firing"] else ("cool" if row.phase=="cooling" else "ready"))))))
  if player.has_animation(clip):
   if nodes.robot_clip!=clip:player.play(clip,.12);nodes.robot_clip=clip
   player.pause()
   if not stopped:
    var duration:=player.get_animation(clip).length
    var progress: float=clampf(float(nodes.robot_pose_clock)/float(cfg.wake_seconds),0,1) if clip=="wake" else (clampf(float(nodes.robot_pose_clock)/float(cfg.fire_seconds),0,1) if clip=="fire" else (clampf(float(nodes.robot_pose_clock),0,1) if clip=="destroyed" else 0.0))
    player.seek(progress*duration,true)
 if moving and row.phase in ["projectile","firing"] and not nodes.robot_weapon.is_empty():
  var upper: Dictionary=nodes.robot_weapon
  var time:=clampf(float(nodes.robot_pose_clock)/float(cfg.fire_seconds),0,1)*float(upper.animation.length)
  upper.skeleton.set_bone_pose_position(upper.bone,upper.animation.position_track_interpolate(upper.track,time))
 nodes.locomotion.feet(row,delta,stopped)
 var motor: AudioStreamPlayer3D=nodes.robot_motor;motor.stream_paused=stopped
 if moving:
  motor.pitch_scale=(.7 if row.robot_role=="bastion" else 1.05)*lerpf(.8,1.15,clampf(nodes.locomotion.velocity.length()/float(cfg.speed),0,1))
  if not motor.playing:motor.play()
 elif not moving and not stopped:motor.stop()
 # Consume each authoritative attack once, including while menus suppress presentation.
 var new_attack: bool=int(row.attack_serial)>int(nodes.robot_attack)
 if not stopped and row.hp>0 and new_attack and not row.shot_start.is_empty():
  var start:=FrontierCrewWorld.vector(row.shot_start);var finish:=FrontierCrewWorld.vector(row.shot_end)
  if cfg.attack=="mortar":
   if row.phase=="projectile":view.attack_effects.launch(str(row.id),start,finish)
   else:view.attack_effects.impact(str(row.id),finish)
  else:view.attack_effects.shot(start,finish,str(row.robot_role))
 nodes.robot_attack=int(row.attack_serial)
 if not stopped and row.hp>0 and row.phase=="projectile" and not row.shot_start.is_empty():
  view.attack_effects.shell(str(row.id),FrontierCrewWorld.vector(row.shot_start),FrontierCrewWorld.vector(row.shot_end),float(row.time),delta)
 else:view.attack_effects.shells.erase(str(row.id))
 if row.phase!=nodes.robot_phase and not stopped:
  if row.phase=="waking":view.audio.play("sfx_incident_robot_wake",root.global_position)
  elif row.phase=="aiming":view.audio.play("sfx_gun_charge",root.global_position)
 nodes.robot_phase=row.phase
 if nodes.beam!=null:nodes.beam.visible=false

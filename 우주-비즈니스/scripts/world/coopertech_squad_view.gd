extends RefCounted
## Reuses production INK models and ElevenLabs effects, with host phase/attack clocks.
static func build(view: FrontierIncidentView,row: Dictionary,nodes: Dictionary) -> void:
 var cfg:=FrontierCooperTechSquads.spec(row)
 nodes.relay.hide()
 var player: AnimationPlayer=nodes.main.find_child("AnimationPlayer",true,false)
 nodes.robot_animation=player;nodes.robot_clip="";nodes.robot_step=0.0;nodes.robot_attack=int(row.attack_serial);nodes.robot_phase=row.phase;nodes.robot_travel=float(row.travel)
 var marker:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=maxf(.1,float(cfg.blast_radius)-.10);ring.outer_radius=maxf(.2,float(cfg.blast_radius)+.10);ring.rings=48;ring.ring_segments=6;marker.mesh=ring
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("ef7b29");marker.material_override=material;view.add_child(marker);marker.hide();nodes.robot_marker=marker
 var projectile:=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=.11;ball.height=.22;projectile.mesh=ball;projectile.material_override=material;view.add_child(projectile);projectile.hide();nodes.robot_projectile=projectile
 var audio:=AudioStreamPlayer3D.new();audio.stream=load("res://assets/audio/sfx_robot_move.wav");audio.bus="SFX";audio.volume_db=-19;audio.unit_size=7;audio.max_distance=40;nodes.root.add_child(audio);nodes.robot_motor=audio
static func dispose(nodes: Dictionary) -> void:
 for key in ["robot_marker","robot_projectile"]:
  if nodes.has(key):nodes[key].queue_free()
static func update(view: FrontierIncidentView,row: Dictionary,nodes: Dictionary,delta: float,stopped: bool) -> void:
 var cfg:=FrontierCooperTechSquads.spec(row);var root: Node3D=nodes.root
 var before:=root.global_position
 if not stopped:
  root.global_position=root.global_position.lerp(FrontierCrewWorld.vector(row.position),1-exp(-delta*16));root.rotation.y=lerp_angle(root.rotation.y,float(row.yaw),1-exp(-delta*14))
 var moving: bool=not stopped and row.hp>0 and row.phase in ["patrol","pursuing"] and root.global_position.distance_to(before)>.001
 if not stopped:nodes.robot_travel+=root.global_position.distance_to(before)
 var player: AnimationPlayer=nodes.robot_animation
 if player!=null:
  var clip: String="walk" if moving else ("idle" if row.phase=="idle" else ("wake" if row.phase=="waking" else ("destroyed" if row.hp<=0 else ("fire" if row.phase in ["projectile","firing"] else ("cool" if row.phase=="cooling" else "ready")))))
  if player.has_animation(clip):
   if nodes.robot_clip!=clip:player.play(clip);nodes.robot_clip=clip
   player.pause()
   if not stopped:
    var duration:=player.get_animation(clip).length
    var progress: float=fposmod(float(nodes.robot_travel)/(2.4 if row.robot_role=="bastion" else 2.1),1.0) if clip=="walk" else (clampf(float(row.time)/float(cfg.wake_seconds),0,1) if clip=="wake" else (clampf(float(row.time)/.35,0,1) if clip=="fire" else 0.0))
    player.seek(progress*duration,true)
 if row.robot_role=="sentry":
  nodes.main.rotation.y=PI
  for part in nodes.parts:
   if str(part.name).begins_with("Anim_Leg_") and part.has_meta("rest"):
    part.transform=part.get_meta("rest");part.rotation.x=sin(float(nodes.robot_travel)*TAU/2.0+(PI if str(part.name).ends_with("-1") else 0))*.22 if moving else 0.0
 var motor: AudioStreamPlayer3D=nodes.robot_motor;motor.stream_paused=stopped
 if moving and not motor.playing:motor.pitch_scale=.7 if row.robot_role=="bastion" else 1.18;motor.play()
 elif not moving and not stopped:motor.stop()
 nodes.robot_marker.visible=not stopped and cfg.attack=="mortar" and row.phase in ["aiming","projectile"] and not row.aim.is_empty()
 if nodes.robot_marker.visible:
  nodes.robot_marker.global_position=FrontierCrewWorld.vector(row.aim)+Vector3.UP*.08;nodes.robot_marker.scale=Vector3.ONE*(1+sin(view.elapsed*12)*.025)
 nodes.robot_projectile.visible=not stopped and row.phase=="projectile" and not row.shot_start.is_empty()
 if nodes.robot_projectile.visible:nodes.robot_projectile.global_position=FrontierCrewWorld.vector(row.shot_start).lerp(FrontierCrewWorld.vector(row.shot_end),clampf(float(row.time)/.75,0,1))
 if row.phase!=nodes.robot_phase and not stopped:
  if row.phase=="waking":view.audio.play("sfx_incident_robot_wake",root.global_position)
  elif row.phase=="aiming":view.audio.play("sfx_gun_charge",root.global_position)
  elif row.phase in ["projectile","firing"]:
   view.audio.play("sfx_gun_plasma" if cfg.attack=="mortar" else "sfx_combat_pulse",root.global_position)
   if row.phase=="firing" and not row.shot_end.is_empty():view.app.feedback.effects.burst(FrontierCrewWorld.vector(row.shot_end),Color("ffb269"),7 if cfg.attack=="mortar" else 3)
  nodes.robot_phase=row.phase
 if nodes.beam!=null:nodes.beam.visible=false
 if not stopped and cfg.attack!="mortar" and row.phase in ["aiming","firing"] and not row.aim.is_empty():
  if nodes.beam==null or nodes.get("beam_serial",-1)!=row.serial:
   if nodes.beam!=null:nodes.beam.queue_free()
   var start:=FrontierExplorationIncidents.point(row,FrontierCrewWorld.vector(cfg.muzzle));var end:=FrontierCrewWorld.vector(row.shot_end) if row.phase=="firing" and not row.shot_end.is_empty() else FrontierCrewWorld.vector(row.aim)
   nodes.beam=view.beam(start,end,Color("ff692d") if row.phase=="firing" else Color("dca14e"),.07 if row.phase=="firing" else .015,view);nodes.beam_serial=row.serial
  nodes.beam.visible=true

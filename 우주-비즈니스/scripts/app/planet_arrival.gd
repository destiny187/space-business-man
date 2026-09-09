extends CanvasLayer
## Presentation begins only after an accepted host landing snapshot.
var vessel_overlay: SubViewportContainer
var flow: ColorRect
var flow_material: ShaderMaterial
var entry_view: Transform3D
var entry_fov:=65.0
var app: FrontierCrewExpedition
var warm_frames:=0
var prepared:=false
var active:=false
var phase: String=""
var age:=0.0
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_arrival.json"))
var curtain: ColorRect
var caption: Label
var bars: Array[ColorRect]=[]
var cover: ShaderMaterial
var start: Vector3
var finish: Vector3
var ship_home: Vector3
var landing_camera: Camera3D
var engine: AudioStreamPlayer
var audio: FrontierAudio
var dust: GPUParticles3D
var drive: FrontierVesselDriveEffects
var unboard: Button
var exit_position: Vector3
var exit_rotation: Quaternion
var approach_rotation: Quaternion
var handover_position: Vector3
var handover_rotation: Quaternion
var landing_audio: FrontierLandingAudio
var effects: FrontierLandingSurfaceEffects
var walker: FrontierLandingWalk
var profile: Dictionary={}
var finch:=false
var hatch_open:=0.0
var compression:=0.0
var entry_camera: Transform3D
var clock_value:=0.0
var paused:=false
var ship_rotation:=Vector3.ZERO

func configure(owner_app: FrontierCrewExpedition) -> void:
 app=owner_app;layer=90
 curtain=ColorRect.new();curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(curtain)
 cover=ShaderMaterial.new();cover.shader=load("res://assets/materials/space/arrival_cloud.gdshader");curtain.material=cover
 flow=ColorRect.new();flow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);flow.mouse_filter=Control.MOUSE_FILTER_IGNORE
 flow_material=ShaderMaterial.new();flow_material.shader=load("res://assets/materials/space/arrival_flow.gdshader");flow.material=flow_material;add_child(flow)
 for bottom in [false,true]:
  var bar:=ColorRect.new();bar.color=Color("10191f");add_child(bar)
  bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
  if bottom:bar.offset_top=-54
  else:bar.offset_bottom=54
  bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;bars.append(bar)
 caption=Label.new();caption.theme=app.ui_theme;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(caption)
 caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_top=-45;caption.offset_bottom=-8
 audio=FrontierAudio.new();add_child(audio)
 landing_audio=FrontierLandingAudio.new();add_child(landing_audio);engine=landing_audio.layers.thruster
 unboard=Button.new();unboard.text="탑승 취소";unboard.theme=app.ui_theme;add_child(unboard)
 unboard.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);unboard.offset_left=-150;unboard.offset_top=-100;unboard.offset_right=-24;unboard.offset_bottom=-60
 unboard.pressed.connect(func():app.session.send_request("surface_unboard",{}));unboard.hide()
 RenderingServer.frame_post_draw.connect(_frame_drawn)
 hide()

func _frame_drawn() -> void:
 if active and phase in ["warming","escape_loading"]:warm_frames+=1

func begin() -> void:
 vessel_overlay=load("res://scripts/ui/arrival_vessel.gd").new();add_child(vessel_overlay);move_child(vessel_overlay,1);vessel_overlay.configure({"hull":"finch"} if not app.session.latest.get("local_shuttle","").is_empty() else app.session.latest.get("vessel",{}));vessel_overlay.hide()
 active=true;prepared=false;warm_frames=0;phase="approach";age=0;hatch_open=0;compression=0;clock_value=0;show()
 app.cancel_placement()
 for panel in [app.navigation_frame,app.research_frame,app.inventory_panel,app.business_panel,app.shipyard_panel]:panel.hide()
 var flight:=app.flight
 flight.set_process(false);flight.transit_overlay.hide();flight.vessel_sound.suspend()
 start=flight.ship.position;approach_rotation=flight.ship.quaternion;entry_camera=flight.camera.transform
 var nav: Dictionary=app.session.latest.crew.navigation
 var body:=FrontierUniverse.body(app.session.manifest,int(nav.target))
 var center:=FrontierCrewNavigation.center(int(nav.target),app.session.manifest,float(nav.get("orbit_time",0)))
 finish=center+(start-center).normalized()*(FrontierUniverse.navigation_radius(body)+12)
 finch=not app.session.latest.get("local_shuttle","").is_empty()
 profile=FrontierLandingSurfaceEffects.profile(body);landing_audio.begin(profile,finch)
 for material in [cover,flow_material]:material.set_shader_parameter("atmosphere",profile.air)
 caption.text=body.name+"  ·  궤도 이탈"
 cover.set_shader_parameter("tint",Color(body.get("traits",{}).get("dust","a6afb8")))
 flow_material.set_shader_parameter("tint",Color(body.get("traits",{}).get("dust","a6afb8")))
 cover.set_shader_parameter("cover",0.0)
 # Entry airflow fades in only on worlds with an atmosphere.
 app.session.send_input(Vector2.ZERO,Vector3.FORWARD,false,false,[0.0,0.0,0.0])

func tick(delta: float) -> void:
 if not active:return
 if not app.session.active:cancel();return
 paused=not app.get_window().has_focus() and not app.test_mode
 for p in landing_audio.layers.values():p.stream_paused=paused
 for p in landing_audio.events:
  if is_instance_valid(p):p.stream_paused=paused
 if is_instance_valid(drive):drive.set_motion(Vector2.ZERO,0,paused)
 if is_instance_valid(vessel_overlay):vessel_overlay.drive.set_motion(Vector2.ZERO,0,paused)
 if paused:
  if is_instance_valid(walker):walker.walk(0,0,true)
  if is_instance_valid(effects):effects.update(100,0,hatch_open,true)
  return
 clock_value+=delta
 for material in [cover,flow_material]:material.set_shader_parameter("flow_time",clock_value)
 if prepared and is_instance_valid(app.surface_world) and phase in ["loading","warming","descent"]:
  var sky=app.surface_world.atmosphere
  var target_tint: Color=sky.current.get("cloud_color",profile.tint)
  target_tint=target_tint*lerpf(.10,1.0,sky.daylight);target_tint.a=1.0
  for material in [cover,flow_material]:
   var old_tint: Color=material.get_shader_parameter("tint")
   material.set_shader_parameter("tint",old_tint.lerp(target_tint,1-exp(-delta*2)))
 flow_material.set_shader_parameter("heat",(smoothstep(.35,.85,age/float(config.approach_seconds)) if phase=="approach" else (1-smoothstep(0,.35,age/float(config.descent_seconds)) if phase=="descent" else .6))*profile.air)
 if phase in ["boarding","ascent","escape_loading","escape","exit_handover"]:
  _tick_launch(delta);return
 if app.session.latest.get("crew",{}).get("landing",{}).is_empty():cancel();return
 age+=delta
 app.reticle.hide();app.field_hud.hide();app.surface_status.hide();app.help_text.hide()
 app.navigation_toggle.get_parent().hide()
 if phase=="approach":
  var t:=clampf(age/float(config.approach_seconds),0,1)
  app.outside=true;app.exterior_view.show();app.space_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  app.flight.ship.position=start.lerp(finish,t*t*(3-2*t))
  var facing: Vector3=(finish-start).normalized()
  app.flight.ship.quaternion=approach_rotation.slerp(app.flight._flight_basis(facing).get_rotation_quaternion(),smoothstep(0,.55,t))
  var target_camera:=Transform3D(Basis.from_euler(Vector3(-.15,0,0)),Vector3(0,3.5,12) if finch else Vector3(0,12,44))
  app.flight.camera.transform=entry_camera.interpolate_with(target_camera,smoothstep(0,1,t))
  app.flight.orbital_presentation.update(delta,app.flight.orbit_clock)
  app.flight.drive.set_thrust(.65,false)
  cover.set_shader_parameter("cover",smoothstep(.45,1,t))
  var strength:=smoothstep(.45,.65,t)
  vessel_overlay.match_view(app.flight.ship.get_child(0),app.flight.camera)
  vessel_overlay.match_space_light(app.flight.ship,delta)
  _show_vessel(strength>0,strength)
  app.flight.ship.get_child(0).visible=strength<=0
  if t>=1:
   entry_view=vessel_overlay.camera.transform;entry_fov=vessel_overlay.camera.fov
   phase="loading";age=0;caption.text="대기층 통과 중" if profile.air>.03 else "착륙 접근 중"
 elif phase=="loading":
  # Keep an animated opaque cover until authoritative edits and local collision are ready.
  app.outside=false;app.exterior_view.hide();app.space_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
  cover.set_shader_parameter("cover",1.0)
  _show_vessel(true,1.0)
  if app.surface_world!=null and not prepared:_prepare_descent()
  if prepared:
   vessel_overlay.match_view(app.surface_world.landing_ship,landing_camera)
   vessel_overlay.match_surface_light(app.surface_world,delta)
   var target: Transform3D=vessel_overlay.camera.transform
   vessel_overlay.camera.transform=entry_view.interpolate_with(target,smoothstep(0,1,clampf(age/1.5,0,1)))
   vessel_overlay.camera.fov=lerpf(entry_fov,landing_camera.fov,smoothstep(0,1,clampf(age/1.5,0,1)))
  if _surface_ready() and age>=1.5:phase="warming";age=0;warm_frames=0;caption.text="착륙 시야 준비 중"
  elif age>15:caption.text="착륙 지형 준비 중 · 호스트 기록과 지형을 기다립니다"
 elif phase=="warming":
  # Draw the actual initial descent camera behind the opaque curtain.
  # Restart the barrier if a terrain edit or resource request arrives meanwhile.
  if not _surface_ready():phase="loading";age=0;warm_frames=0
  else:_warm_camera()
  if phase=="warming" and warm_frames>=int(config.get("warmup_frames",8)) and age>=float(config.get("warmup_seconds",.5)):_begin_descent()
 elif phase=="descent":
  var t:=clampf(age/float(config.descent_seconds),0,1)
  var rest:=pow(1-t,1.85)
  app.surface_world.landing_ship.position=ship_home+Vector3(0,float(config.descent_height),0)*rest+FrontierCrewWorld.vector(config.descent_offset)*pow(1-t,3.0)
  app.surface_world.landing_ship.rotation=ship_rotation+Vector3(-.10*sin(t*PI),0,0)
  var ship: Vector3=app.surface_world.landing_ship.position
  var camera_offset:=Vector3(34,18,42).lerp(Vector3(17,8,24),smoothstep(0,1,t))*(.38 if finch else 1.0)
  landing_camera.position=ship+app.surface_world.landing_ship.basis*camera_offset
  landing_camera.position+=Vector3(sin(clock_value*21),sin(clock_value*29),0)*profile.air*(1-t)*.12
  landing_camera.look_at(ship+Vector3.UP*(1 if finch else 0))
  cover.set_shader_parameter("cover",1-smoothstep(0,.3,t))
  app.surface_world.refits.landing_override={"deployment":smoothstep(.05,.65,t),"hatch":0.0,"compression":0.0}
  var in_cloud:=t<.3
  vessel_overlay.match_view(app.surface_world.landing_ship,landing_camera)
  vessel_overlay.set_entry_direction(true)
  vessel_overlay.match_surface_light(app.surface_world,delta)
  _show_vessel(in_cloud,1-smoothstep(0,.3,t))
  app.surface_world.landing_ship.visible=not in_cloud
  drive.set_thrust(.4+sin(t*PI)*.2+smoothstep(.7,.94,t)*.22,false)
  if t>=1:
   phase="touchdown";age=0;caption.text=app.surface_world.body.name+"  ·  착륙"
   drive.set_thrust(.5,false)
 elif phase=="touchdown":
  var t:=clampf(age/float(config.touchdown_seconds),0,1)
  compression=(.09 if finch else .18)*sin(minf(age*7.0,PI))*exp(-age*1.8)
  app.surface_world.landing_ship.position=ship_home-Vector3.UP*compression
  app.surface_world.landing_ship.rotation=ship_rotation+Vector3(sin(age*12)*exp(-age*5)*.014,0,0)
  hatch_open=smoothstep(.22,1.0,t)
  app.surface_world.refits.landing_override={"deployment":1.0,"hatch":hatch_open,"compression":compression}
  drive.set_thrust(.5*(1-t),false)
  if t>=1:
   phase="disembark";age=0;caption.text="탐사 준비"
   walker=FrontierLandingWalk.new();app.add_child(walker);walker.configure(app,finch)
   handover_position=landing_camera.position;handover_rotation=landing_camera.quaternion
 elif phase=="disembark":
  var t:=clampf(age/walker.duration,0,1);hatch_open=1.0
  walker.walk(delta,t,false)
  var desired:=walker.global_position+app.surface_world.landing_ship.basis*FrontierCrewWorld.vector(config.finch_camera_follow_offset if finch else config.camera_follow_offset)
  landing_camera.position=landing_camera.position.lerp(desired,1-exp(-delta*3))
  landing_camera.look_at(walker.global_position+Vector3.UP)
  if t>=1:phase="handover";age=0;handover_position=landing_camera.position;handover_rotation=landing_camera.quaternion
 elif phase=="handover":
  var t:=smoothstep(0,1,clampf(age/float(config.handover_seconds),0,1))
  landing_camera.position=handover_position.lerp(app.camera.position,t)
  landing_camera.quaternion=handover_rotation.slerp(app.camera.quaternion,t)
  if is_instance_valid(walker):walker.visible=t<.85
  for bar in bars:bar.modulate.a=1-t
  caption.modulate.a=1-t
  if t>=1:cancel()
 if active:_update_landing_layers(delta)

func _update_landing_layers(delta: float) -> void:
 var height:=100.0
 if prepared and is_instance_valid(app.surface_world):height=maxf(0,app.surface_world.landing_ship.position.y-ship_home.y)
 var progress:=clampf(age/float(config.descent_seconds if phase=="descent" else (config.touchdown_seconds if phase=="touchdown" else config.approach_seconds)),0,1)
 landing_audio.update(delta,phase,progress,height,hatch_open,effects.ground_kind if is_instance_valid(effects) else "dust",false)
 if is_instance_valid(effects):effects.update(height,drive.thrust,hatch_open,false)

func _show_vessel(enabled: bool,strength: float) -> void:
 vessel_overlay.visible=enabled
 flow_material.set_shader_parameter("strength",strength)
 if enabled:
  var uv: Vector2=vessel_overlay.camera.unproject_position(Vector3.ZERO)/Vector2(vessel_overlay.viewport.size)
  flow_material.set_shader_parameter("vessel_uv",uv)


func _surface_ready() -> bool:
 if app.surface_world==null or not app.actors.has(app.session.latest.self_id):return false
 var surface:=app.surface_world
 return prepared and surface.landing_view_ready()

func _prepare_descent() -> void:
 if not app.surface_world.refits.requested_hull.is_empty():return
 app.surface_world.seat_vessel()
 prepared=true
 ship_home=app.surface_world.landing_ship.position;ship_rotation=app.surface_world.landing_ship.rotation
 landing_camera=Camera3D.new();app.add_child(landing_camera);landing_camera.far=app.camera.far;landing_camera.fov=65;landing_camera.make_current()
 drive=FrontierVesselDriveEffects.new();app.surface_world.landing_ship.add_child(drive)
 if not app.session.latest.get("local_shuttle","").is_empty():drive.set_finch(true)
 drive.set_landing(true)
 app.surface_world.refits.landing_override={"deployment":0.0,"hatch":0.0,"compression":0.0}
 if app.surface_world.landing_effects==null:
  effects=FrontierLandingSurfaceEffects.new();app.surface_world.add_child(effects);effects.configure(app.surface_world,finch);app.surface_world.landing_effects=effects
 else:effects=app.surface_world.landing_effects
 dust=effects.emitters[0]

 var initial_ship:=ship_home+Vector3(0,float(config.descent_height),0)+FrontierCrewWorld.vector(config.descent_offset)
 app.surface_world.landing_ship.position=initial_ship
 landing_camera.position=initial_ship+app.surface_world.landing_ship.basis*Vector3(34,18,42)*(.38 if finch else 1.0);landing_camera.look_at(initial_ship)
 app.surface_world.business_view.labels_enabled=false
 var points: Array[Vector3]=[app.actors[app.session.latest.self_id].position]
 for t in [0.0,.5,1.0]:
  var p: Vector3=ship_home+FrontierCrewWorld.vector(config.descent_offset)*t+app.surface_world.landing_ship.basis*Vector3(34,0,42)*(.38 if finch else 1.0)
  p.y=app.surface_world.terrain.field.height(p.x,p.z)+1
  points.append(p)
 app.surface_world.prepare_landing_view(points)

func _warm_camera() -> void:
 if warm_frames<2:
  var ship: Vector3=ship_home+Vector3(0,float(config.descent_height),0)+FrontierCrewWorld.vector(config.descent_offset)
  landing_camera.position=ship+app.surface_world.landing_ship.basis*Vector3(34,18,42)*(.38 if finch else 1.0);landing_camera.look_at(ship)
 elif warm_frames<4:
  landing_camera.position=ship_home+Vector3(34,18,42);landing_camera.look_at(ship_home+Vector3(0,1,-4))
 elif warm_frames<6:
  landing_camera.transform=app.camera.transform
 else:
  var ship: Vector3=ship_home+Vector3(0,float(config.descent_height),0)+FrontierCrewWorld.vector(config.descent_offset)
  landing_camera.position=ship+app.surface_world.landing_ship.basis*Vector3(34,18,42)*(.38 if finch else 1.0);landing_camera.look_at(ship)

func _begin_descent() -> void:
 phase="descent";age=0;caption.text=app.surface_world.body.name+"  ·  착륙 지점으로 하강"

func cancel() -> void:
 var leaving:=phase in ["ascent","escape_loading","escape","exit_handover"]
 active=false;phase="";hide();landing_audio.finish();unboard.hide()
 if is_instance_valid(walker):walker.queue_free();walker=null
 if is_instance_valid(effects):effects.update(0,0,0 if leaving else 1,false)
 if app.surface_world!=null:app.surface_world.refits.landing_override.clear()
 flow_material.set_shader_parameter("strength",0.0)
 if is_instance_valid(vessel_overlay):vessel_overlay.release()
 if app.flight!=null:app.flight.ship.get_child(0).show()
 if app.surface_world!=null:app.surface_world.landing_ship.show()
 if is_instance_valid(landing_camera):landing_camera.queue_free()
 dust=null
 if is_instance_valid(drive):drive.queue_free()
 if app.surface_world!=null:app.surface_world.finish_landing_view();app.surface_world.business_view.labels_enabled=true
 if app.surface_world!=null and ship_home!=Vector3.ZERO:app.surface_world.landing_ship.position=ship_home;app.surface_world.landing_ship.rotation=ship_rotation
 app.camera.make_current()
 if app.flight!=null:app.flight.set_process(true);app.flight.transit_overlay.show();app.flight.drive.set_thrust(0,false)
 for bar in bars:bar.modulate.a=1
 caption.modulate.a=1;ship_home=Vector3.ZERO
 app.help_text.show();app.field_hud.show()
 app._sync_surface_view()
 if leaving and app.session.active and app.session.latest.crew.get("landing",{}).is_empty():
  app.outside=true;app.exterior_view.show();app.if_flight_view();app.cursor_released=false;app.mouse_steering=Vector2.ZERO;app._sync_mouse_capture()

func begin_boarding() -> void:
 if app.surface_world==null:return
 active=true;phase="boarding";age=0;show();app.close_menus()
 cover.set_shader_parameter("cover",0.0);flow_material.set_shader_parameter("strength",0.0)
 ship_home=app.surface_world.landing_ship.position;ship_rotation=app.surface_world.landing_ship.rotation
 landing_camera=Camera3D.new();app.add_child(landing_camera);landing_camera.fov=65;landing_camera.far=app.camera.far
 landing_camera.position=ship_home+Vector3(28,14,36);landing_camera.look_at(ship_home+Vector3.UP*2);landing_camera.make_current()
 unboard.show()
 app.session.send_input(Vector2.ZERO,Vector3.FORWARD,false,false,[0.0,0.0,0.0])

func begin_launch() -> void:
 # Called only when the host snapshot actually clears the landing state.
 unboard.hide()
 active=true;phase="ascent";age=0;warm_frames=0;show();app.close_menus()
 vessel_overlay=load("res://scripts/ui/arrival_vessel.gd").new();add_child(vessel_overlay);move_child(vessel_overlay,1);vessel_overlay.configure({"hull":"finch"} if not app.session.latest.get("local_shuttle","").is_empty() else app.session.latest.get("vessel",{}));vessel_overlay.hide()
 app.flight.set_process(false);app.flight.transit_overlay.hide();app.flight.vessel_sound.suspend()
 var nav: Dictionary=app.session.latest.crew.navigation
 exit_position=FrontierCrewWorld.vector(nav.position)
 exit_rotation=app.flight._flight_basis(FrontierCrewWorld.vector(nav.direction)).get_rotation_quaternion()
 var body:=FrontierUniverse.body(app.session.manifest,int(nav.target))
 var center:=FrontierCrewNavigation.center(int(nav.target),app.session.manifest,float(nav.orbit_time))
 start=center+(exit_position-center).normalized()*(FrontierUniverse.navigation_radius(body)+12)
 finch=not app.session.latest.get("local_shuttle","").is_empty();profile=FrontierLandingSurfaceEffects.profile(body);landing_audio.begin(profile,finch)
 for material in [cover,flow_material]:material.set_shader_parameter("atmosphere",profile.air)
 caption.text=body.name+"  ·  이륙"
 for material in [cover,flow_material]:material.set_shader_parameter("tint",Color(body.traits.dust))
 cover.set_shader_parameter("cover",0.0)
 if is_instance_valid(landing_camera):landing_camera.queue_free()
 landing_camera=null
 if app.surface_world!=null:
  _prepare_descent()
  app.surface_world.landing_ship.position=ship_home
  landing_camera.position=ship_home+Vector3(34,18,42);landing_camera.look_at(ship_home+Vector3(0,1,-4))
 else:
  phase="escape_loading";cover.set_shader_parameter("cover",1.0)
  _prepare_escape()
 audio.play("sfx_vessel_boost");engine.pitch_scale=.7;engine.volume_db=-22;engine.play()
 app.session.send_input(Vector2.ZERO,Vector3.FORWARD,false,false,[0.0,0.0,0.0])

func _prepare_escape() -> void:
 app._sync_surface_view()
 app.outside=true;app.exterior_view.show();app.if_flight_view()
 app.space_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 app.flight.ship.position=start;app.flight.ship.quaternion=exit_rotation
 app.flight.camera.position=Vector3(0,16,57);app.flight.camera.rotation=Vector3(-.15,0,0)
 app.flight.ship.get_child(0).hide()
 # If there was no local surface (e.g. a slow joining client), start with this view.
 if not vessel_overlay.visible:
  vessel_overlay.match_view(app.flight.ship.get_child(0),app.flight.camera)
  entry_view=vessel_overlay.camera.transform;entry_fov=vessel_overlay.camera.fov
 _show_vessel(true,1.0)
 vessel_overlay.set_entry_direction(false)

func _tick_launch(delta: float) -> void:
 age+=delta
 app.reticle.hide();app.field_hud.hide();app.surface_status.hide();app.help_text.hide()
 app.navigation_toggle.get_parent().hide()
 if phase=="boarding":
  if not app.session.latest.crew.members[app.session.latest.self_id].aboard:cancel();return
  var boarded:=0;var total:=0
  for member in app.session.latest.crew.members.values():
   if member.get("connected",true):
    total+=1
    if member.aboard:boarded+=1
  caption.text=("조종석 · " if app.session.latest.self_id==app.session.latest.crew.pilot_id else "탑승 완료 · ")+"승무원 %d/%d · 전원 탑승 시 자동 이륙"%[boarded,total]
 elif phase=="ascent":
  var t:=clampf(age/float(config.ascent_seconds),0,1)
  var rise:=t*t
  var ship:=app.surface_world.landing_ship
  ship.position=ship_home+Vector3(0,float(config.descent_height),0)*rise-FrontierCrewWorld.vector(config.descent_offset)*rise
  ship.rotation.x=.18*sin(t*PI)
  landing_camera.position=ship.position+Vector3(34,18,42);landing_camera.look_at(ship.position+Vector3(0,1,-4))
  var strength:=smoothstep(.35,.95,t)
  cover.set_shader_parameter("cover",strength)
  vessel_overlay.match_view(ship,landing_camera);vessel_overlay.set_entry_direction(true);_show_vessel(strength>0,strength)
  ship.visible=strength<=0
  effects.update(float(config.descent_height)*rise,1-t,0,false);drive.set_thrust(lerpf(.2,1,t),false)
  app.surface_world.refits.landing_override={"deployment":1-smoothstep(.2,.8,t),"hatch":0.0}
  engine.pitch_scale=lerpf(.7,1.2,t);engine.volume_db=lerpf(-22,-17,t)
  if t>=1:
   entry_view=vessel_overlay.camera.transform;entry_fov=vessel_overlay.camera.fov
   phase="escape_loading";age=0;warm_frames=0;caption.text="대기층 상승 · 우주 시야 준비 중"
   cover.set_shader_parameter("cover",1.0)
   if profile.get("air",0.0)>.03:audio.play("sfx_atmosphere_entry")
   _prepare_escape()
 elif phase=="escape_loading":
  # Render the actual system behind the opaque atmosphere before revealing it.
  cover.set_shader_parameter("cover",1.0)
  vessel_overlay.match_view(app.flight.ship.get_child(0),app.flight.camera)
  var target: Transform3D=vessel_overlay.camera.transform
  var t:=smoothstep(0,1,clampf(age/1.5,0,1))
  vessel_overlay.camera.transform=entry_view.interpolate_with(target,t)
  vessel_overlay.camera.fov=lerpf(entry_fov,app.flight.camera.fov,t)
  _show_vessel(true,1.0)
  if warm_frames>=int(config.warmup_frames) and age>=maxf(1.5,float(config.warmup_seconds)) and app.flight.current_system==int(app.session.latest.crew.navigation.system):
   phase="escape";age=0;caption.text="대기권 이탈"
 elif phase=="escape":
  var t:=clampf(age/float(config.escape_seconds),0,1)
  app.flight.ship.position=start.lerp(exit_position,smoothstep(0,1,t))
  app.flight.ship.quaternion=exit_rotation;app.flight.drive.set_thrust(.85,false)
  var strength:=1-smoothstep(.15,.65,t)
  cover.set_shader_parameter("cover",strength)
  vessel_overlay.match_view(app.flight.ship.get_child(0),app.flight.camera);_show_vessel(strength>0,strength)
  app.flight.ship.get_child(0).visible=strength<=0
  engine.pitch_scale=lerpf(1.2,.8,t);engine.volume_db=lerpf(-17,-25,t)
  if t>=1:
   phase="exit_handover";age=0;engine.stop()
   caption.text="직접 조종 · W/S 추진 · 마우스 방향" if app.session.latest.self_id==app.session.latest.crew.pilot_id else "우주 비행 · 호스트 조종"
 elif phase=="exit_handover":
  var t:=clampf(age/float(config.escape_handover_seconds),0,1)
  for bar in bars:bar.modulate.a=1-t
  caption.modulate.a=1-t
  if t>=1:cancel()

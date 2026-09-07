extends CanvasLayer
## Presentation begins only after an accepted host landing snapshot.
var app: FrontierCrewExpedition
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
var approach_rotation: Quaternion
var handover_position: Vector3
var handover_rotation: Quaternion

func configure(owner_app: FrontierCrewExpedition) -> void:
 app=owner_app;layer=90
 curtain=ColorRect.new();curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(curtain)
 cover=ShaderMaterial.new();cover.shader=load("res://assets/materials/space/arrival_cloud.gdshader");curtain.material=cover
 for bottom in [false,true]:
  var bar:=ColorRect.new();bar.color=Color("10191f");add_child(bar)
  bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
  if bottom:bar.offset_top=-54
  else:bar.offset_bottom=54
  bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;bars.append(bar)
 caption=Label.new();caption.theme=app.ui_theme;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(caption)
 caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_top=-45;caption.offset_bottom=-8
 audio=FrontierAudio.new();add_child(audio)
 engine=AudioStreamPlayer.new();engine.bus="SFX";engine.stream=audio.stream("sfx_landing_thrusters",true);engine.volume_db=-20;add_child(engine)
 hide()

func begin() -> void:
 active=true;phase="approach";age=0;show()
 app.cancel_placement()
 for panel in [app.navigation_frame,app.research_frame,app.inventory_panel,app.business_panel,app.shipyard_panel]:panel.hide()
 var flight:=app.flight
 flight.set_process(false);flight.transit_overlay.hide();flight.engine.stop()
 start=flight.ship.position;approach_rotation=flight.ship.quaternion
 var nav: Dictionary=app.session.latest.crew.navigation
 var body:=FrontierUniverse.body(app.session.manifest,int(nav.target))
 var center:=FrontierCrewNavigation.center(int(nav.target),app.session.manifest,float(nav.get("orbit_time",0)))
 finish=center+(start-center).normalized()*(FrontierUniverse.navigation_radius(body)+12)
 caption.text=body.name+"  ·  궤도 이탈"
 cover.set_shader_parameter("tint",Color(body.get("traits",{}).get("dust","a6afb8")))
 cover.set_shader_parameter("cover",0.0)
 audio.play("sfx_atmosphere_entry");engine.pitch_scale=1;engine.volume_db=-22;engine.play()
 app.session.send_input(Vector2.ZERO,Vector3.FORWARD,false,false,[0.0,0.0,0.0])

func tick(delta: float) -> void:
 if not active:return
 if not app.session.active or app.session.latest.get("crew",{}).get("landing",{}).is_empty():cancel();return
 age+=delta
 app.reticle.hide();app.field_hud.hide();app.surface_status.hide();app.help_text.hide()
 app.navigation_toggle.get_parent().hide()
 if phase=="approach":
  var t:=clampf(age/float(config.approach_seconds),0,1)
  app.outside=true;app.exterior_view.show();app.space_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  app.flight.ship.position=start.lerp(finish,t*t*(3-2*t))
  var facing: Vector3=(finish-start).normalized()
  app.flight.ship.quaternion=approach_rotation.slerp(app.flight._flight_basis(facing).get_rotation_quaternion(),smoothstep(0,.55,t))
  app.flight.camera.position=Vector3(0,16,57);app.flight.camera.rotation=Vector3(-.15,0,0)
  app.flight.drive.set_thrust(.65,false)
  cover.set_shader_parameter("cover",smoothstep(.45,1,t))
  if t>=1:phase="loading";age=0;caption.text="진입 항로 확보 중"
 elif phase=="loading":
  # Keep an animated opaque cover until authoritative edits and local collision are ready.
  app.outside=false;app.exterior_view.hide();app.space_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
  if _surface_ready():_begin_descent()
  elif age>15:caption.text="착륙 지형 준비 중 · 호스트 기록과 지형을 기다립니다"
 elif phase=="descent":
  var t:=clampf(age/float(config.descent_seconds),0,1)
  var rest:=pow(1-t,2.0)
  app.surface_world.landing_ship.position=ship_home+Vector3(0,float(config.descent_height),0)*rest+FrontierCrewWorld.vector(config.descent_offset)*rest
  app.surface_world.landing_ship.rotation.x=-.12*sin(t*PI)
  var ship: Vector3=app.surface_world.landing_ship.position
  landing_camera.position=ship+Vector3(34,18,42)
  landing_camera.look_at(ship+Vector3(0,1,-4))
  cover.set_shader_parameter("cover",1-smoothstep(0,.3,t))
  engine.pitch_scale=lerpf(1.1,.65,t);engine.volume_db=lerpf(-18,-24,t)
  dust.emitting=t>.70
  drive.set_thrust(lerpf(.65,.12,t),false)
  if t>=1:
   phase="touchdown";age=0;caption.text=app.surface_world.body.name+"  ·  착륙"
   audio.play("sfx_landing_touchdown");drive.set_thrust(0,false);engine.stop()
 elif phase=="touchdown":
  dust.emitting=false
  if age>=float(config.touchdown_seconds):
   phase="handover";age=0;handover_position=landing_camera.position;handover_rotation=landing_camera.quaternion
 elif phase=="handover":
  var t:=smoothstep(0,1,clampf(age/float(config.handover_seconds),0,1))
  landing_camera.position=handover_position.lerp(app.camera.position,t)
  landing_camera.quaternion=handover_rotation.slerp(app.camera.quaternion,t)
  for bar in bars:bar.modulate.a=1-t
  caption.modulate.a=1-t
  if t>=1:cancel()

func _surface_ready() -> bool:
 if app.surface_world==null or not app.actors.has(app.session.latest.self_id):return false
 var surface:=app.surface_world
 return surface.ready_at(app.actors[app.session.latest.self_id].position) and surface.ready_at(surface.landing_ship.position)

func _begin_descent() -> void:
 phase="descent";age=0;caption.text=app.surface_world.body.name+"  ·  착륙 지점으로 하강"
 ship_home=app.surface_world.landing_ship.position
 landing_camera=Camera3D.new();app.add_child(landing_camera);landing_camera.far=app.camera.far;landing_camera.fov=65;landing_camera.make_current()
 drive=FrontierVesselDriveEffects.new();app.surface_world.landing_ship.add_child(drive)
 for jet in drive.jets:jet.process_material.direction=Vector3.DOWN
 dust=GPUParticles3D.new();dust.amount=100;dust.lifetime=1.4;dust.emitting=false;dust.position=Vector3(ship_home.x,app.surface_world.terrain.field.height(ship_home.x,ship_home.z)+.15,ship_home.z)
 var motion:=ParticleProcessMaterial.new();motion.direction=Vector3.UP;motion.spread=85;motion.gravity=Vector3(0,-.3,0);motion.initial_velocity_min=3;motion.initial_velocity_max=7;motion.scale_min=.3;motion.scale_max=1.3;motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_RING;motion.emission_ring_radius=5;motion.emission_ring_inner_radius=2;motion.emission_ring_height=.2;motion.color=Color(app.surface_world.body.get("traits",{}).get("dust","b8a080"));dust.process_material=motion
 var mesh:=QuadMesh.new();mesh.size=Vector2(1,1)
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/landing_dust.gdshader");mat.set_shader_parameter("tint",motion.color);mesh.material=mat;dust.draw_pass_1=mesh
 app.surface_world.add_child(dust)

func cancel() -> void:
 active=false;phase="";hide();engine.stop()
 if is_instance_valid(landing_camera):landing_camera.queue_free()
 if is_instance_valid(dust):dust.queue_free()
 if is_instance_valid(drive):drive.queue_free()
 if app.surface_world!=null and ship_home!=Vector3.ZERO:app.surface_world.landing_ship.position=ship_home;app.surface_world.landing_ship.rotation=Vector3.ZERO
 app.camera.make_current()
 if app.flight!=null:app.flight.set_process(true);app.flight.transit_overlay.show();app.flight.drive.set_thrust(0,false)
 for bar in bars:bar.modulate.a=1
 caption.modulate.a=1;ship_home=Vector3.ZERO
 app.help_text.show();app.field_hud.show()
 app._sync_surface_view()

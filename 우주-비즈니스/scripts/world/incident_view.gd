class_name FrontierIncidentView
extends Node3D
const Creature=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var surface: FrontierCrewSurfaceScene
var camera: Camera3D
var app: FrontierCrewExpedition
var models: Dictionary={}
var scenes: Dictionary={}
var requests: Dictionary={}
var materials: Dictionary={}
var rows: Dictionary={}
var selected: Dictionary={}
var audio: FrontierAudio
var hint: Label
var signal_bar: ProgressBar
var signal_label: Label
var refresh_time:=0.0
var elapsed:=0.0
var beep_time:=0.0
var event_serial:=0
var native_warning:=""
func configure(owner_surface: FrontierCrewSurfaceScene,eye: Camera3D) -> void:
 surface=owner_surface;camera=eye;app=surface.session.get_parent() as FrontierCrewExpedition
 audio=FrontierAudio.new();add_child(audio)
 var layer:=CanvasLayer.new();add_child(layer)
 var clue_overlay: Control=load("res://scripts/ui/coopertech_clue_overlay.gd").new();clue_overlay.incident=self;layer.add_child(clue_overlay)
 hint=Label.new();hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hint.add_theme_color_override("font_shadow_color",Color.BLACK);hint.add_theme_constant_override("shadow_offset_x",2);hint.add_theme_constant_override("shadow_offset_y",2);layer.add_child(hint)
 signal_bar=ProgressBar.new();signal_bar.show_percentage=false;signal_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(signal_bar)
 signal_label=Label.new();signal_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;signal_label.add_theme_color_override("font_shadow_color",Color.BLACK);signal_label.add_theme_constant_override("shadow_offset_x",2);signal_label.add_theme_constant_override("shadow_offset_y",2);layer.add_child(signal_label)
func blocked() -> bool:return app==null or app.feedback==null or app.feedback.blocked() or (not app.test_mode and not get_window().has_focus())
func _exit_tree() -> void:
 if is_instance_valid(camera):camera.h_offset=0;camera.v_offset=0
func scene_for(id: String) -> PackedScene:
 var path: String="res://assets/models/incidents/"+id+".glb"
 if scenes.has(path):return scenes[path]
 if not requests.has(path):ResourceLoader.load_threaded_request(path);requests[path]=true
 if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:return null
 scenes[path]=ResourceLoader.load_threaded_get(path);return scenes[path]
func add_model(id: String,parent_node: Node3D,at: Vector3,collision:=false) -> Node3D:
 var scene:=scene_for(id)
 if scene==null:return null
 var model: Node3D=scene.instantiate();parent_node.add_child(model);model.position=at;FrontierInkStyle.apply(model,materials)
 if collision:
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   var solid:=StaticBody3D.new();mesh.add_child(solid);var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();solid.add_child(shape)
 return model
func beam(a: Vector3,b: Vector3,color: Color,radius: float,parent_node: Node3D) -> MeshInstance3D:
 var node:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=maxf(.01,a.distance_to(b));mesh.radial_segments=8;node.mesh=mesh
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;node.material_override=material;parent_node.add_child(node)
 node.position=(a+b)*.5
 var up: Vector3=(b-a).normalized();var right: Vector3=up.cross(Vector3.FORWARD).normalized()
 if right.length()<.1:right=Vector3.RIGHT
 node.basis=Basis(right,up,right.cross(up)).orthonormalized();return node
func make(row: Dictionary) -> Dictionary:
 var mode: String=FrontierExplorationIncidents.definition(row.template).mode
 var ids: Array=[{"wreck":"wreck","power":"wreck","carry":"cliff","ice":"ice","robot":"robot","drone":"drone","scavenger":"nest","native":"nest","seismic":"gems"}[mode],"cargo","beacon"]
 if mode in ["power","wreck"]:ids.append_array(["battery","generator"])
 if mode=="scavenger":ids.append("battery")
 if row.has("native") and row.native.role!="scavenger":ids.append("gems")
 for id in ids:
  if scene_for(id)==null:return {}
 var root_node:=Node3D.new();add_child(root_node);root_node.position=FrontierCrewWorld.vector(row.position);root_node.rotation.y=float(row.yaw)
 var main:=add_model(ids[0],root_node,Vector3.ZERO,mode in ["wreck","power","carry","ice","seismic"])
 var cargo:=add_model("cargo",root_node,Vector3.ZERO)
 var relay:=add_model("beacon",root_node,root_node.to_local(FrontierCrewWorld.vector(row.relay)))
 var result: Dictionary={"root":root_node,"main":main,"cargo":cargo,"relay":relay,"parts":main.find_children("Anim_*","Node3D",true,false),"serial":int(row.serial),"phase":str(row.phase),"beam":null}
 if mode in ["wreck","power"]:
  result.battery=add_model("battery",root_node,Vector3.ZERO)
  if mode=="power":
   result.generator=add_model("generator",root_node,root_node.to_local(FrontierCrewWorld.vector(row.battery_position)+Vector3(0,0,-2)))
   var start:=FrontierCrewWorld.vector(row.battery_position);var end:=FrontierExplorationIncidents.point(row,Vector3(2.2,0,2.8))
   var previous:=start
   for i in range(1,25):
    var p:=start.lerp(end,float(i)/24.0);p.y=surface.terrain.field.height(p.x,p.z)+.06
    beam(root_node.to_local(previous),root_node.to_local(p),Color("d58835"),.045,root_node);previous=p
 if row.has("native"):
  FrontierNativeIncidentView.build(self,row,result)
 elif mode=="scavenger":
  var ecology: Dictionary={"planets":{}}
  var natives:=FrontierEcology.ensure_planet(ecology,surface.body)
  for lineage in natives.lineages:
   var form:=FrontierEcologyCatalog.form(lineage.form_id)
   if form.category!="animal" or form.environment=="cave":continue
   var creature:=Creature.new();creature.load_far=false;creature.configure(form,FrontierEcologyCatalog.look(lineage.form_id,lineage.look_id));root_node.add_child(creature);creature.set_state("move");result.creature=creature
   result.stolen=add_model("battery",creature,Vector3(0,.6,-.3));result.stolen.scale=Vector3.ONE*.35;break
 if mode=="robot":
  var bubble:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=1.15;sphere.height=3.0;bubble.mesh=sphere;root_node.add_child(bubble);bubble.position=Vector3(0,1.5,0)
  var shield_material:=StandardMaterial3D.new();shield_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shield_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;shield_material.albedo_color=Color(.2,.65,1,.12);shield_material.cull_mode=BaseMaterial3D.CULL_DISABLED;bubble.material_override=shield_material;result.shield=bubble
  var solid:=StaticBody3D.new();root_node.add_child(solid);var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.6;capsule.height=2.7;shape.shape=capsule;shape.position.y=1.35;solid.add_child(shape);result.robot_solid=solid
 if mode=="seismic":
  main.position=Vector3(0,-7.6,-1);cargo.hide();relay.hide()
  var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=float(FrontierExplorationIncidents.config().seismic.blast_radius)-.08;torus.outer_radius=torus.inner_radius+.16;torus.rings=48;torus.ring_segments=6;ring.mesh=torus
  var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("ff762c");ring.material_override=material;root_node.add_child(ring);ring.position=Vector3(0,-7.5,0);result.danger_ring=ring
 if preload("res://scripts/domain/storm_archive.gd").enabled(row):preload("res://scripts/world/storm_archive_view.gd").build(self,row,result)
 return result
func refresh() -> void:
 rows=surface.session.latest.get("incidents",{}).get("records",{})
 for id in models.keys():
  if rows.has(id):continue
  if models[id].beam!=null:models[id].beam.queue_free()
  preload("res://scripts/world/storm_archive_view.gd").dispose(models[id])
  models[id].root.queue_free();models.erase(id)
 for id in rows:
  if models.has(id):continue
  var made:=make(rows[id])
  if not made.is_empty():models[id]=made
func _process(delta: float) -> void:
 if surface==null or surface.session.latest.is_empty():return
 elapsed+=delta;refresh_time-=delta
 if refresh_time<=0:refresh_time=.25;refresh()
 var stopped:=blocked();hint.visible=not stopped;signal_label.visible=not stopped;signal_bar.visible=not stopped
 for speaker in audio.get_children():
  if speaker is AudioStreamPlayer or speaker is AudioStreamPlayer3D:speaker.stream_paused=stopped
 camera.h_offset=0;camera.v_offset=0;selected={}
 native_warning=""
 var nearest:=float(FrontierExplorationIncidents.config().tool_distance);var signal_row: Dictionary={};var signal_distance:=150.0;var delivery: Dictionary={}
 var actor_id: String=surface.session.latest.self_id
 for id in models:
  if not rows.has(id):continue
  var row: Dictionary=rows[id];var mode: String=FrontierExplorationIncidents.definition(row.template).mode;var nodes: Dictionary=models[id]
  var at:=FrontierCrewWorld.vector(row.position);var distance_value:=surface.viewer.position.distance_to(at)
  if row.carrier==actor_id or row.battery_carrier==actor_id:delivery=row
  if mode in ["wreck","power"] and not row.claimed and distance_value<signal_distance:signal_distance=distance_value;signal_row=row
  var main: Node3D=nodes.main
  nodes.cargo.visible=not row.claimed and mode!="seismic" and (row.open if mode in ["wreck","power","ice","drone"] else (row.hp<=0 if mode=="robot" else true))
  nodes.cargo.scale=Vector3.ONE
  nodes.cargo.global_position=FrontierExplorationIncidents.cargo_point(row)-Vector3.UP*.35
  if row.carrier!="" and app.actors.has(row.carrier):nodes.cargo.global_position=app.actors[row.carrier].position+Vector3(0,1,-.75).rotated(Vector3.UP,app.actors[row.carrier].rotation.y)
  if row.carrier==actor_id:
   nodes.cargo.global_transform=Transform3D(camera.global_basis.scaled(Vector3.ONE*.24),camera.to_global(Vector3(-.42,-.4,-1)))
  if nodes.has("battery"):
   nodes.battery.scale=Vector3.ONE
   nodes.battery.visible=not row.battery_installed and not row.claimed and (mode=="power" or int(row.tier)>=2)
   nodes.battery.global_position=FrontierCrewWorld.vector(row.battery_ground)
   if row.battery_carrier!="" and app.actors.has(row.battery_carrier):nodes.battery.global_position=app.actors[row.battery_carrier].position+Vector3(0,1,-.6).rotated(Vector3.UP,app.actors[row.battery_carrier].rotation.y)
  if nodes.has("battery") and row.battery_carrier==actor_id:
   nodes.battery.global_transform=Transform3D(camera.global_basis.scaled(Vector3.ONE*.3),camera.to_global(Vector3(-.46,-.4,-.9)))
  if mode=="drone":
   main.global_position=main.global_position.lerp(FrontierExplorationIncidents.moving_point(row),1-exp(-delta*12)) if not row.open else FrontierExplorationIncidents.cargo_point(row)+Vector3.UP
   if not row.open:nodes.cargo.visible=true;nodes.cargo.global_position=main.global_position-Vector3.UP*1.0
  if row.has("native"):
   FrontierNativeIncidentView.update(self,row,nodes,delta,stopped)
  elif nodes.has("creature"):
   var creature: Node3D=nodes.creature;var previous:=creature.global_position;creature.global_position=creature.global_position.lerp(FrontierExplorationIncidents.moving_point(row)-Vector3.UP*.35,1-exp(-delta*12))
   var motion:=creature.global_position-previous
   if motion.length()>.005:creature.rotation.y=atan2(-motion.x,-motion.z)-float(row.yaw)
   creature.paused=stopped;nodes.stolen.visible=not row.claimed
   if creature.mouth_marker!=null:nodes.stolen.global_position=creature.mouth_marker.global_position
  if nodes.has("storm_ring"):
   var warning: String=preload("res://scripts/world/storm_archive_view.gd").update(self,row,nodes,stopped)
   if not warning.is_empty():native_warning=warning
  if mode=="robot":nodes.shield.visible=float(row.get("shield",0))>0 and row.hp>0 and row.phase!="idle"
  for part in nodes.parts:
   if not part.has_meta("rest"):part.set_meta("rest",part.transform)
   var rest: Transform3D=part.get_meta("rest")
   if str(part.name).begins_with("Anim_Hatch") or str(part.name).begins_with("Anim_Ice"):
    part.visible=not row.open
    for shape in part.find_children("*","CollisionShape3D",true,false):shape.set_deferred("disabled",row.open)
    if not row.open:part.position=rest.origin+Vector3(sin(elapsed*13)*float(row.hits)*.008,0,0)
   elif str(part.name).begins_with("Anim_Rotor") and not stopped and not row.open:part.rotation.y+=delta*32
   elif str(part.name).begins_with("Anim_Torso"):
    var folded:=1.0 if row.phase in ["idle","destroyed"] else (1.0-clampf(float(row.time)/float(FrontierExplorationIncidents.config().robot.wake_seconds),0,1) if row.phase=="waking" else 0.0)
    part.transform=rest;part.rotation.x+=folded*1.0;part.position.y-=folded*.3
    if row.phase in ["aiming","firing"] and not row.aim.is_empty():
     var toward:=FrontierCrewWorld.vector(row.aim)-at;part.rotation.y=atan2(toward.x,toward.z)-float(row.yaw)
   elif str(part.name).begins_with("Anim_Weak"):part.visible=row.phase=="cooling"
   elif str(part.name).begins_with("Anim_Gem_"):part.visible=int(str(part.name).trim_prefix("Anim_Gem_"))>=int(row.gems)
  if nodes.has("robot_solid"):nodes.robot_solid.collision_layer=1 if row.hp>0 else 0
  if nodes.beam!=null:nodes.beam.visible=false
  if mode=="robot" and row.phase in ["aiming","firing"] and not stopped and not row.aim.is_empty():
   if nodes.beam==null or nodes.get("beam_serial",-1)!=row.serial:
    if nodes.beam!=null:nodes.beam.queue_free()
    nodes.beam=beam(FrontierExplorationIncidents.point(row,Vector3(0,1.5,0)),FrontierCrewWorld.vector(row.aim)+Vector3.UP,Color("ff562c") if row.phase=="firing" else Color("d29b3b"),.10 if row.phase=="firing" else .018,self);nodes.beam_serial=row.serial
   nodes.beam.visible=true
  if mode=="seismic":
   main.visible=row.open
   nodes.danger_ring.visible=row.phase in ["warning","blast"] and not stopped
   nodes.danger_ring.scale=Vector3.ONE*(1+sin(elapsed*14)*.025)
   if not stopped and row.phase in ["quake","warning","blast"]:
    var effect_at:=FrontierCrewWorld.vector(row.relay) if not row.open else FrontierExplorationIncidents.point(row,Vector3(0,-6.5,0))
    if surface.viewer.position.distance_to(effect_at)<25:
     if row.phase in ["quake","blast"] and FrontierClientSettings.ensure(get_tree()).values.incident_shake:camera.h_offset=sin(elapsed*31)*.045;camera.v_offset=cos(elapsed*39)*.035
     if fmod(elapsed,.2)<delta:app.feedback.effects.burst(effect_at,Color("ffaf58") if row.phase!="quake" else Color("ac9875"),4)
  if int(row.serial)!=int(nodes.serial):
   if not stopped:
    if row.phase!=nodes.phase:
     var sound: String="sfx_incident_quake" if row.phase in ["quake","blast"] else ("sfx_incident_robot_wake" if row.phase=="waking" else ("sfx_combat_pulse" if row.phase=="firing" else ("sfx_creature_call" if row.has("native") else "sfx_discovery_excavate")))
     audio.play(sound,FrontierCrewWorld.vector(row.relay) if mode=="seismic" else at)
    app.feedback.effects.burst(at+Vector3.UP,Color("cbb5ff"),8);event_serial+=1
   nodes.serial=int(row.serial);nodes.phase=str(row.phase)
  if stopped:continue
  for part in FrontierExplorationIncidents.targets(row):
   var difference: Vector3=part.point-camera.global_position;var along: float=difference.dot(-camera.global_basis.z)
   if along<=0 or difference.length()>nearest or (difference+camera.global_basis.z*along).length()>(1.3 if part.part=="robot" else .9):continue
   if not FrontierCrewSurface.visible_in_field(surface.terrain.field,camera.global_position,part.point):continue
   if app._shot_obstacle_distance(actor_id,camera.global_position,difference.normalized(),difference.length())<difference.length()-.7:continue
   nearest=difference.length();selected={"id":id,"part":part.part,"action":part.action,"point":part.point,"template":row.template}
 if stopped:return
 var size:=get_viewport().get_visible_rect().size
 hint.size=Vector2(minf(520,size.x-40),72);hint.position=Vector2((size.x-hint.size.x)*.5,size.y*.59)
 hint.text="" if selected.is_empty() else str(FrontierExplorationIncidents.definition(selected.template).name)+"\n"+str(selected.action)
 if not selected.is_empty() and rows[selected.id].has("native"):
  hint.text=FrontierNativeIncidents.title(rows[selected.id].native)+"\n"+str(selected.action)
 if not selected.is_empty() and selected.part=="robot":hint.text+=" · 냉각 중 약점 노출" if rows[selected.id].phase=="cooling" else " · 조준선에서 벗어나기"
 if not native_warning.is_empty():hint.text=native_warning
 signal_bar.position=Vector2(24,size.y*.4);signal_bar.size=Vector2(130,7);signal_label.position=Vector2(24,size.y*.4-28)
 signal_bar.visible=not signal_row.is_empty();signal_label.visible=signal_bar.visible
 if not signal_row.is_empty():
  var direction:=FrontierCrewWorld.vector(signal_row.position)-camera.global_position
  var alignment:=maxf(.1,(-camera.global_basis.z).dot(direction.normalized()))
  signal_bar.value=clampf((1-signal_distance/170.0)*alignment*100,0,100)
  signal_label.text="구조 신호  "+("◀" if direction.dot(camera.global_basis.x)<0 else "▶")
  beep_time-=delta
  if beep_time<=0:beep_time=lerpf(2.7,.6,signal_bar.value/100);audio.play("sfx_incident_beacon")
 if not delivery.is_empty():
  var destination: Vector3=FrontierCrewWorld.vector(delivery.relay) if delivery.carrier==actor_id else FrontierExplorationIncidents.point(delivery,Vector3(2.2,1,2.8))
  var direction:=destination-camera.global_position;signal_bar.visible=false;signal_label.show()
  signal_label.text=("회수 신호기 " if delivery.carrier==actor_id else "전원 소켓 ")+("◀ " if direction.dot(camera.global_basis.x)<0 else "▶ ")+str(roundi(direction.length()))+"m"
 if FrontierExplorationIncidents.carriers(surface.session.latest,actor_id):
  if hint.text.is_empty():hint.text="화물 운반 중 · 회수 신호기로 이동 · X 내려놓기"
func interact() -> bool:
 if blocked() or selected.is_empty():return false
 surface.session.send_request("surface_incident",{"id":selected.id,"part":selected.part,"aim":FrontierExplorationIncidents.array(-camera.global_basis.z)});return true
func use_tool() -> bool:
 if blocked() or selected.is_empty() or selected.part not in ["hatch","ice","robot","drone","gems"]:return false
 surface.session.send_request("surface_incident_tool",{"id":selected.id,"part":selected.part,"aim":FrontierExplorationIncidents.array(-camera.global_basis.z)});return true

func _unhandled_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_X or blocked():return
 var actor: String=surface.session.latest.self_id
 for id in rows:
  if rows[id].carrier==actor or rows[id].battery_carrier==actor:
   surface.session.send_request("surface_incident",{"id":id,"part":"drop"});get_viewport().set_input_as_handled();return

func presentation_ready(at: Vector3) -> bool:
 for id in surface.session.latest.get("incidents",{}).get("records",{}):
  var row: Dictionary=surface.session.latest.incidents.records[id]
  if minf(at.distance_to(FrontierCrewWorld.vector(row.position)),at.distance_to(FrontierCrewWorld.vector(row.relay)))<35 and not models.has(id):return false
 return true

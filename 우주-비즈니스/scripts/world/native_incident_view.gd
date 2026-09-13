class_name FrontierNativeIncidentView
extends RefCounted
## Native identity and host clocks are preserved; displayed anatomy supplies local collision bounds.
const Creature=preload("res://scripts/actors/creatures/bestiary_actor.gd")
const IncidentMotion=preload("res://scripts/actors/creatures/incident_motion.gd")
static func make_actor(native: Dictionary,look: Dictionary,ready_scenes: Array=[]) -> Node3D:
 var actor:=Creature.new();actor.load_far=false;actor.configure(FrontierEcologyCatalog.form(native.form_id),look,ready_scenes)
 return actor
static func displayed_dimensions(actor: Node3D,native: Dictionary) -> Vector3:
 if actor.remodel.is_empty():return Vector3(float(native.width),float(native.height),float(native.length))
 var bounds: Dictionary=actor.remodel.lods.near
 return (Vector3(bounds.max[0],bounds.max[1],bounds.max[2])-Vector3(bounds.min[0],bounds.min[1],bounds.min[2]))*actor.base_scale
static func displayed_center(actor: Node3D,native: Dictionary) -> Vector3:
 if actor.remodel.is_empty():return Vector3(0,float(native.height)*.5,0)
 var bounds: Dictionary=actor.remodel.lods.near
 return Vector3((float(bounds.max[0])+float(bounds.min[0]))*.5,(float(bounds.max[1])-float(bounds.min[1]))*.5,(float(bounds.max[2])+float(bounds.min[2]))*.5)*actor.base_scale
static func build(view: FrontierIncidentView,row: Dictionary,nodes: Dictionary) -> void:
 var native: Dictionary=row.native;var root: Node3D=nodes.root
 nodes.relay.hide()
 var creature:=make_actor(native,FrontierNativeIncidents.look(native));root.add_child(creature);creature.set_state("idle");nodes.creature=creature
 var dimensions:=displayed_dimensions(creature,native)
 creature.global_position=FrontierNativeIncidents.position(row)
 nodes.ground_probe=func(at: Vector3,reach: float):return Creature.GroundMotion.sample(view.surface.terrain.field,at,reach)
 nodes.native_attack=int(row.native_attack);nodes.native_footstep=0.0
 var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=minf(FrontierNativeIncidents.radius(native),float(native.height)*.45) if creature.remodel.is_empty() else minf(minf(dimensions.x,dimensions.z)*.48,dimensions.y*.45);capsule.height=maxf(dimensions.y,capsule.radius*2)
 var solid:=StaticBody3D.new();root.add_child(solid);solid.add_child(shape);shape.shape=capsule;shape.position=displayed_center(creature,native);nodes.native_solid=solid;solid.global_position=creature.global_position
 if native.role=="giant":
  var box:=BoxShape3D.new();box.size=dimensions;shape.shape=box
 nodes.main.scale=Vector3.ONE*clampf(FrontierNativeIncidents.radius(native)/1.5,.7,2.0)
 if native.role=="scavenger":
  nodes.stolen=view.add_model("battery",creature,Vector3(0,.6,-.3));nodes.stolen.scale=Vector3.ONE*clampf(float(native.height)*.16,.12,.45)
 else:
  nodes.native_sample=view.add_model("gems",root,Vector3.ZERO);nodes.native_sample.scale=Vector3.ONE*.22
  nodes.native_sample.global_position=FrontierExplorationIncidents.cargo_point(row)-Vector3.UP*.4
 if native.role=="guardian":
  nodes.young=[]
  for side in [-1,1]:
   var look:=FrontierNativeIncidents.look(native);look.scale*=float(FrontierNativeIncidents.config().young_scale)
   var young:=make_actor(native,look);root.add_child(young);young.position=Vector3(side*dimensions.x*.35,0,.8);young.set_state("feed");nodes.young.append(young)
 # Authored creature geometry supplies scale; sparse ground marks are temporary field cues.
 var track_mat:=StandardMaterial3D.new();track_mat.albedo_color=Color("45423b");track_mat.roughness=1.0
 var track_radius:=clampf(FrontierNativeIncidents.radius(native)*.15,.07,.35)
 for i in range(1,row.path.size()-1):
  var a:=FrontierCrewWorld.vector(row.path[i-1]);var b:=FrontierCrewWorld.vector(row.path[i]);var forward:=(b-a).normalized();var side:=Vector3(forward.z,0,-forward.x)
  for sign_value in ([0] if native.track=="groove" else [-1,1]):
   var mark:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=track_radius;mesh.bottom_radius=track_radius;mesh.height=.015;mesh.radial_segments=3 if native.track=="claw" else 12;mark.mesh=mesh;mark.material_override=track_mat;root.add_child(mark)
   mark.global_position=b+side*sign_value*float(native.width)*.25+Vector3.UP*.018;mark.scale.z=3.0 if native.track=="groove" else 1.6;mark.rotation.y=atan2(forward.x,forward.z)
static func update(view: FrontierIncidentView,row: Dictionary,nodes: Dictionary,delta: float,stopped: bool) -> void:
 var native: Dictionary=row.native;var creature: Node3D=nodes.creature;var previous:=creature.global_position;var goal:=FrontierNativeIncidents.position(row)
 var motion:=goal-previous
 if motion.length()>.002:nodes.native_motion_hold=.35
 elif not stopped:nodes.native_motion_hold=maxf(0,float(nodes.get("native_motion_hold",0.0))-delta)
 var facing: Basis=creature.global_basis
 if motion.length()>.002:facing=FrontierEcologyPlacement.surface_basis(view.surface.terrain.field.normal(goal),atan2(motion.x,motion.z))
 creature.paused=stopped
 creature.incident_pose=IncidentMotion.sample(creature,row)
 if int(row.native_attack)>int(nodes.native_attack):
  if creature.remodel.is_empty():creature.set_state("attack");creature.elapsed=creature.windup_seconds;creature.pose()
  nodes.native_attack=int(row.native_attack)
  if not stopped:voice(view,creature.global_position,native)
 elif creature.state!="attack":
  var wanted: String="stressed" if float(row.native_alert)>0 else ("move" if float(nodes.get("native_motion_hold",0.0))>0 or creature.ground_motion.velocity.length()>.08 else "feed")
  if creature.state!=wanted:creature.set_state(wanted)
 creature.drive_ground(goal,facing,delta,nodes.ground_probe,stopped)
 nodes.native_solid.global_position=creature.global_position
 nodes.native_solid.global_rotation=creature.global_rotation
 if nodes.has("young"):
  for young in nodes.young:
   young.paused=stopped;young.drive_ground(young.global_position,young.global_basis,delta,nodes.ground_probe,stopped)
 if nodes.has("stolen"):
  nodes.stolen.visible=not row.claimed
  if creature.mouth_marker!=null:nodes.stolen.global_position=creature.mouth_marker.global_position
 if nodes.has("native_sample"):nodes.native_sample.visible=FrontierNativeIncidents.available(row) and not row.claimed
 nodes.cargo.visible=native.role=="scavenger" and FrontierNativeIncidents.available(row) and not row.claimed
 if not stopped:nodes.native_footstep+=delta
 if not stopped and motion.length()>.002 and nodes.native_footstep>1.8:
  nodes.native_footstep=0.0
  if native.role in ["giant","cave"] and view.surface.viewer.position.distance_to(goal)<20:voice(view,goal,native)
 var footfall: Vector3=creature.ground_motion.take_footfall()
 if not stopped and footfall.is_finite() and view.surface.viewer.position.distance_to(footfall)<20:
  view.surface._wildlife_cue(footfall,"step")
 if not stopped and float(row.native_alert)>0 and view.surface.viewer.position.distance_to(goal)<FrontierNativeIncidents.radius(native)+6:
  view.native_warning="둥지 보호 개체가 경고합니다 · 뒤로 물러나세요"

static func voice(view: FrontierIncidentView,at: Vector3,native: Dictionary) -> void:
 var count:=view.audio.get_child_count();view.audio.play("sfx_creature_call",at)
 if view.audio.get_child_count()>count:
  var speaker:=view.audio.get_child(view.audio.get_child_count()-1)
  if speaker is AudioStreamPlayer3D:speaker.pitch_scale=clampf(1.0/sqrt(maxf(.6,float(native.height)/1.5)),.65,1.25)

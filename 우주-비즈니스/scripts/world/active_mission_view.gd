extends RefCounted
const Mission=preload("res://scripts/domain/active_missions.gd")
static func bulb(parent: Node3D,p: Vector3) -> MeshInstance3D:
 var n:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.11;mesh.height=.22;mesh.radial_segments=12;mesh.rings=6;n.mesh=mesh
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("efa341");n.material_override=mat;parent.add_child(n);n.position=p;return n
static func solid(parent: Node3D,size: Vector3,center: Vector3,target: bool=false) -> StaticBody3D:
 var body:=StaticBody3D.new();parent.add_child(body)
 if target:body.set_meta("firearm_target",true)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;shape.position=center;body.add_child(shape);return body
static func build(view: FrontierIncidentView,row: Dictionary) -> Dictionary:
 var model: String=Mission.config().templates[row.template].model
 var ids: Array=[model,"cargo","beacon","mission_switch"]
 if row.template in ["cliff_relay_run","aerial_sensor_recovery"]:ids.append_array(["mission_platform","mission_bluff"])
 if row.template=="stranded_survey_rover":ids.append_array(["mission_blocker","battery"])
 if row.template=="freighter_rescue_chain":ids.append("mission_vent")
 for id in ids:
  if view.scene_for(id)==null:return {}
 var root:=Node3D.new();view.add_child(root);root.position=Mission.vec(row.position)
 var main:=Node3D.new();root.add_child(main)
 var cargo:=view.add_model("cargo",root,Vector3.ZERO)
 var relay:=view.add_model("beacon",root,root.to_local(Mission.vec(row.relay)))
 var nodes: Dictionary={"root":root,"main":main,"cargo":cargo,"relay":relay,"parts":[],"beam":null,"serial":int(row.serial),"phase":str(row.phase),"units":[],"lights":[],"lines":[],"motor_age":0.0}
 var m: Dictionary=row.mission
 match row.template:
  "cliff_relay_run":
   for i in m.anchors.size():
    var anchor:=Mission.vec(m.anchors[i]);var local:=root.to_local(anchor)
    view.add_model("mission_platform",root,local,true)
    if i>0:
     var height:=anchor.y-root.position.y
     var bluff:=view.add_model("mission_bluff",root,Vector3(local.x,-.3,local.z),true);bluff.scale.y=height/6.
     # Authored rock collisions scale with its layers; decks retain a level landing.
    var unit:=view.add_model("mission_relay",root,local)
    nodes.units.append(unit);nodes.lights.append(bulb(root,local+Vector3(0,1.55,1)))
   for i in 3:
    var line:=view.beam(root.to_local(Mission.vec(m.anchors[i])+Vector3.UP*2.1),root.to_local(Mission.vec(m.anchors[i+1])+Vector3.UP*2.1),Color("75c3b0"),.017,root);nodes.lines.append(line)
  "runaway_convoy_intercept","stranded_survey_rover":
   var vehicle:=view.add_model(model,main,Vector3.ZERO);nodes.vehicle=vehicle;nodes.wheels=vehicle.find_children("Anim_Wheel_*","Node3D",true,false)
   solid(main,Vector3(2.2,1.7,3.5),Vector3(0,1,0),true)
   if row.template=="runaway_convoy_intercept":
    nodes.control=view.add_model("mission_switch",root,root.to_local(Mission.vec(row.path[0])+Vector3(3,0,0)))
    nodes.gate=Node3D.new();root.add_child(nodes.gate);nodes.gate.position=root.to_local(Mission.vec(row.path[0]))+Vector3(3,1,0)
    view.beam(Vector3.ZERO,Vector3(-6,0,0),Color("e4a24a"),.09,nodes.gate)
    nodes.lights.append(bulb(nodes.control,Vector3(0,1.25,.4)))
   else:
    nodes.battery=view.add_model("battery",root,root.to_local(Mission.vec(row.battery_ground)))
    for p in m.anchors:
     var rock:=view.add_model("mission_blocker",root,root.to_local(Mission.vec(p)),true);nodes.units.append(rock)
  "coopertech_relay_raid":
   nodes.vault=view.add_model(model,root,Vector3.ZERO,true)
   nodes.gates=nodes.vault.find_children("Anim_Gate","Node3D",true,false)
   for p in m.anchors:
    var unit:=view.add_model("mission_switch",root,root.to_local(Mission.vec(p)));nodes.units.append(unit);nodes.lights.append(bulb(unit,Vector3(0,1.2,.42)))
    var a:=Mission.vec(p);var b:=root.global_position+Vector3(3,0,3);var previous:=a
    for j in range(1,10):
     var q:=a.lerp(b,float(j)/9);q.y=view.surface.terrain.field.height(q.x,q.z)+.07
     view.beam(root.to_local(previous),root.to_local(q),Color("d69045"),.035,root);previous=q
  "vent_field_extraction":
   for p in m.anchors:
    var unit:=view.add_model(model,root,root.to_local(Mission.vec(p)));nodes.units.append(unit);nodes.lights.append(bulb(unit,Vector3(0,.2,0)))
  "aerial_sensor_recovery":
   var anchor:=Mission.vec(m.anchors[0]);var local:=root.to_local(anchor)
   var rock:=view.add_model("mission_bluff",root,Vector3(0,-.3,0),true);rock.scale=Vector3(.7,8./6.,.7)
   view.add_model("mission_platform",root,local,true)
   nodes.perch=view.add_model(model,root,local-Vector3.UP*1.85)
   var creature:=FrontierIncidentView.Creature.new();creature.load_far=false
   creature.configure(FrontierEcologyCatalog.form(m.bird.form_id),FrontierEcologyCatalog.look(m.bird.form_id,m.bird.look_id));root.add_child(creature);nodes.creature=creature
  "freighter_rescue_chain":
   nodes.lander=view.add_model(model,root,Vector3.ZERO,true)
   for p in m.anchors:
    var unit:=view.add_model("cargo",root,root.to_local(Mission.vec(p)));nodes.units.append(unit)
    view.add_model("mission_vent",root,root.to_local(Mission.vec(p))-Vector3.UP*.15)
    nodes.lights.append(bulb(root,root.to_local(Mission.vec(p))+Vector3.UP*.15))
 return nodes
static func visible_unit(unit: Node3D,value: bool) -> void:
 if unit.visible==value:return
 unit.visible=value
 for shape in unit.find_children("*","CollisionShape3D",true,false):shape.set_deferred("disabled",not value)
static func update(view: FrontierIncidentView,row: Dictionary,nodes: Dictionary,delta: float,stopped: bool) -> void:
 var m: Dictionary=row.mission;var cfg:=Mission.rules(row);var actor: String=view.surface.session.latest.self_id
 nodes.cargo.visible=not row.claimed and (row.carrier!="" or not row.cargo_ground.is_empty() or row.template in ["cliff_relay_run","coopertech_relay_raid"] or (row.template=="runaway_convoy_intercept" and row.open))
 nodes.cargo.scale=Vector3.ONE;nodes.cargo.global_position=Mission.cargo_point(row)-Vector3.UP*.35
 if row.carrier!="" and view.app.actors.has(row.carrier):nodes.cargo.global_position=view.app.actors[row.carrier].position+Vector3(0,1,-.75).rotated(Vector3.UP,view.app.actors[row.carrier].rotation.y)
 if row.carrier==actor:nodes.cargo.global_transform=Transform3D(view.camera.global_basis.scaled(Vector3.ONE*.24),view.camera.to_global(Vector3(-.42,-.4,-1)))
 if nodes.has("vehicle"):
  var before: Vector3=nodes.main.global_position
  nodes.main.global_position=Mission.vec(m.moving) if before.distance_to(Mission.vec(m.moving))>5 else before.lerp(Mission.vec(m.moving),1-exp(-delta*14))
  nodes.main.rotation.y=lerp_angle(nodes.main.rotation.y,float(m.moving_yaw),1-exp(-delta*12))
  if not stopped:
   var distance:=before.distance_to(nodes.main.global_position)
   for wheel in nodes.wheels:wheel.rotation.x+=distance/.52
   if distance>.003:
    nodes.motor_age+=delta
    if float(nodes.motor_age)>2.5:view.audio.play("sfx_robot_work",nodes.main.global_position);nodes.motor_age=0.0
  for payload in nodes.vehicle.find_children("Anim_Payload","Node3D",true,false):payload.visible=not row.open and not row.claimed
 if nodes.has("gate"):
  nodes.gate.rotation.z=lerpf(nodes.gate.rotation.z,0.0 if m.running else PI*.48,1-exp(-delta*8))
  nodes.lights[0].material_override.albedo_color=Color("81d8c2") if m.running else Color("eda64c")
 if nodes.has("battery"):
  nodes.battery.visible=not row.battery_installed
  nodes.battery.global_position=Mission.vec(row.battery_ground);nodes.battery.scale=Vector3.ONE
  if row.battery_carrier!="" and view.app.actors.has(row.battery_carrier):nodes.battery.global_position=view.app.actors[row.battery_carrier].position+Vector3(0,1,-.6).rotated(Vector3.UP,view.app.actors[row.battery_carrier].rotation.y)
  if row.battery_carrier==actor:nodes.battery.global_transform=Transform3D(view.camera.global_basis.scaled(Vector3.ONE*.3),view.camera.to_global(Vector3(-.46,-.4,-.9)))
 match row.template:
  "cliff_relay_run":
   for i in 3:
    var pivot: Node3D=nodes.units[i].find_child("Anim_Dish",true,false)
    if pivot:pivot.rotation.y=lerp_angle(pivot.rotation.y,float(m.angles[i]),1-exp(-delta*9))
    nodes.lights[i].material_override.albedo_color=Color("83d9c5") if int(m.steps[i])>0 else Color("eab15b")
    nodes.lines[i].visible=int(m.steps[i])>0
   nodes.lights[3].material_override.albedo_color=Color("83d9c5") if row.claimed else Color("eab15b")
  "coopertech_relay_raid":
   for gate in nodes.gates:visible_unit(gate,not row.open)
   for i in nodes.units.size():
    var lever: Node3D=nodes.units[i].find_child("Anim_Lever",true,false)
    if lever:lever.rotation.x=lerpf(lever.rotation.x,1.1 if int(m.steps[i])>0 else 0.,1-exp(-delta*8))
    nodes.lights[i].material_override.albedo_color=Color("83d9c5") if int(m.steps[i])>0 else Color("eab15b")
   for payload in nodes.vault.find_children("Anim_Payload","Node3D",true,false):visible_unit(payload,false)
  "stranded_survey_rover":
   for i in nodes.units.size():visible_unit(nodes.units[i],int(m.steps[i])<int(cfg.blocker_hits))
  "vent_field_extraction","freighter_rescue_chain":
   for i in nodes.units.size():
    var phase:=Mission.hazard(row,i);var done:=int(m.steps[i])>0
    nodes.lights[i].visible=not done and not row.claimed
    nodes.lights[i].material_override.albedo_color=Color("ffc45c") if phase=="warning" else Color("fff0aa") if phase=="blast" else Color("495760")
    nodes.lights[i].scale=Vector3.ONE*(1.6+sin(view.elapsed*12)*.4 if phase=="warning" else 1.0)
    if row.template=="vent_field_extraction":
     var crystals: Node3D=nodes.units[i].find_child("Anim_Crystal",true,false)
     if crystals:crystals.visible=not done
    else:nodes.units[i].visible=not done and int(m.cargo_index)!=i
    if not stopped and not done and phase=="warning" and fmod(view.elapsed,.3)<delta:
     view.app.feedback.effects.burst(Mission.vec(m.anchors[i])+Vector3.UP*.2,Color("e3b879"),2)
  "aerial_sensor_recovery":
   var creature: Node3D=nodes.creature;var previous:=creature.global_position
   creature.global_position=Mission.bird_point(row);var motion:=creature.global_position-previous
   creature.paused=stopped;creature.set_state("move" if Mission.bird_away(row) else "idle")
   if motion.length()>.01:creature.rotation.y=atan2(-motion.x,-motion.z)
   nodes.perch.visible=not row.claimed and row.carrier=="" and row.cargo_ground.is_empty()
 if int(nodes.serial)!=int(row.serial):
  if not stopped:
   var sound: String={"rotate":"sfx_incident_beacon","connect":"sfx_orbital_complete","switch":"sfx_discovery_excavate","carry":"sfx_discovery_excavate","work":"sfx_discovery_excavate","stop":"sfx_incident_robot_wake","hit":"sfx_gun_carbine","blast":"sfx_incident_quake","complete":"sfx_factory_complete"}.get(str(m.event),"sfx_discovery_excavate")
   view.audio.play(sound,Mission.vec(m.event_point))
   if m.event in ["work","blast","connect","complete"]:view.app.feedback.effects.burst(Mission.vec(m.event_point)+Vector3.UP*.4,Color("e8bd70") if m.event in ["work","blast"] else Color("83d9c5"),6)
   view.event_serial+=1
  nodes.serial=int(row.serial);nodes.phase=str(row.phase)

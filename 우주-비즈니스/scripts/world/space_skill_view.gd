class_name FrontierSpaceSkillView
extends Node3D
## Prepared/active/impact presentation follows authoritative skill state.
var combat: FrontierSpaceCombatView
var objects: Dictionary={}
var cache: Dictionary={}
var scenes: Dictionary={}
var emitter: Node3D
var capacitors: Array=[]
var barrier: MeshInstance3D
var barrier_material: ShaderMaterial
var charge: MeshInstance3D
var charge_material: StandardMaterial3D
var charge_voice: AudioStreamPlayer3D
var clock:=0.0
func configure(owner_view: FrontierSpaceCombatView) -> void:
	combat=owner_view
	for id in ["combat_decoy","combat_mine","combat_skill_emitter"]:scenes[id]=load("res://assets/models/ships/"+id+".glb")
	barrier=MeshInstance3D.new();var shell:=SphereMesh.new();shell.radius=22;shell.height=44;shell.radial_segments=32;shell.rings=16;barrier.mesh=shell
	barrier_material=ShaderMaterial.new();barrier_material.shader=preload("res://assets/materials/space/skill_barrier.gdshader");barrier_material.set_shader_parameter("tint",Color("83d9c5"));barrier.material_override=barrier_material
	barrier.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(barrier);barrier.hide()
	charge=MeshInstance3D.new();var orb:=SphereMesh.new();orb.radius=1;orb.height=2;orb.radial_segments=20;orb.rings=10;charge.mesh=orb
	charge_material=StandardMaterial3D.new();charge_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;charge_material.albedo_color=Color("91efef");charge_material.emission_enabled=true;charge_material.emission=Color("91efef");charge_material.emission_energy_multiplier=2
	charge.material_override=charge_material;add_child(charge);charge.hide()
	for cue in ["sfx_shield_break","sfx_vessel_boost","sfx_gun_ship_pulse","ui_discovery"]:combat.audio.stream(cue)
func clear() -> void:
	for node in objects.values():node.queue_free()
	objects.clear();barrier.hide();charge.hide()
	if is_instance_valid(emitter):emitter.hide()
	if is_instance_valid(charge_voice):charge_voice.stop()
func update(delta: float) -> void:
	if combat.blocked or not combat.view.exterior:clear();return
	clock+=delta
	var ship: Node3D=combat.view.ship;var vessel: Dictionary=combat.view.refits.vessel
	if combat.id()=="crew" and not combat.data().is_empty():
		if not is_instance_valid(emitter):
			emitter=scenes.combat_skill_emitter.instantiate();FrontierInkStyle.apply(emitter,cache);emitter.set_meta("vessel_attachment",true);ship.add_child(emitter);emitter.position=Vector3(0,1.55,-5.4)
			for part in emitter.find_children("Anim_Capacitor_*","Node3D",true,false):capacitors.append({"node":part,"rest":part.transform})
		emitter.visible=false
		for slot in [0,1,2]:
			if FrontierVesselSkills.definition(FrontierVesselSkills.slot_skill(vessel,slot)).get("kind","") in ["lance","spears","pulse","mark","snare"]:emitter.visible=true
	var state: Dictionary=combat.data().get("ships",{}).get(combat.id(),{})
	var charging: Dictionary=state.get("charge",{})
	charge.visible=not charging.is_empty() and combat.relevant() and combat.id()=="crew"
	if charge.visible:
		var total:=float(FrontierVesselSkills.definition(charging.id).get("charge",1))
		var progress:=1.0-float(charging.left)/total
		charge.position=ship.global_transform*Vector3(0,3.7,-5.4);charge.scale=Vector3.ONE*(.6+1.8*progress)
		if not is_instance_valid(charge_voice):
			charge_voice=AudioStreamPlayer3D.new();charge_voice.stream=combat.audio.stream("sfx_robot_charge",true);charge_voice.bus="SFX";charge_voice.volume_db=-24;charge_voice.max_db=-18;charge_voice.max_distance=1500;charge_voice.unit_size=150;add_child(charge_voice)
		charge_voice.global_position=combat.view.camera.global_position;charge_voice.pitch_scale=lerpf(.8,1.3,progress)
		if not charge_voice.playing:charge_voice.play();combat.audio.last_played["sfx_robot_charge"]=Time.get_ticks_msec()
	elif is_instance_valid(charge_voice):charge_voice.stop()
	for row in capacitors:
		if is_instance_valid(row.node):row.node.transform=row.rest;row.node.rotate_object_local(Vector3.FORWARD,(.65 if charge.visible else 0.0)*(-1 if str(row.node.name).ends_with("L") else 1))
	barrier.visible=combat.relevant() and (float(state.get("barrier_left",0))>0 or float(state.get("bulwark_left",0))>0)
	if barrier.visible:
		barrier.global_transform=ship.global_transform;barrier_material.set_shader_parameter("coverage_dot",-1.1 if float(state.get("bulwark_left",0))>0 else .3)
	var present: Dictionary={}
	if combat.relevant():
		for item in combat.encounter().get("deployables",[]):
			var key:=str(item.id);present[key]=true
			if not objects.has(key):
				var node: Node3D=scenes["combat_mine" if item.kind=="mine" else "combat_decoy"].instantiate();FrontierInkStyle.apply(node,cache);add_child(node);node.scale=Vector3.ONE*4;objects[key]=node
			objects[key].position=FrontierSpaceCombat.point(item.position);objects[key].rotation=Vector3(0,clock*.6,.15*sin(clock))
	for id in objects.keys():
		if not present.has(id):objects[id].queue_free();objects.erase(id)
func event(row: Dictionary) -> void:
	var source:=FrontierSpaceCombat.point(row.origin);var target:=FrontierSpaceCombat.point(row.target)
	var cue: String="";var fx:=combat.fx
	match str(row.kind):
		"skill_lance":
			fx.line(source,target,Color("d9ffff"),1.6 if row.id=="phase_lance" else .85,.2);fx.spark(source,Color("b5ffed"),3,.18);cue="sfx_gun_ship_pulse"
		"skill_spears":cue="sfx_gun_ship_pulse"
		"skill_spear_launch":fx.spark(source,Color("80c7ff"),1.8,.10)
		"skill_pulse","skill_mark":
			var radius:=FrontierVesselSkills.value(combat.view.refits.vessel,str(row.id),"range",240)
			for i in 12:
				var a:=Vector3(cos(i*TAU/12),0,sin(i*TAU/12));fx.line(source+a*14,source+a*radius,Color("83d9c5"),.3,.32)
			fx.shield(combat.view.ship.position,source+combat.view.ship.global_basis.y*10,28);cue="sfx_shield_break"
		"skill_tether":fx.line(source,target,Color("a3deef"),.38,.52)
		"skill_boost":fx.vent(combat.view.ship.position,combat.view.ship.global_basis.z*18,int(row.serial));cue="sfx_vessel_boost"
		"skill_barrier":cue="ui_discovery"
		"skill_vent":fx.vent(source,Vector3.UP*10,int(row.serial));cue="sfx_shield_break"
		"skill_deploy":fx.spark(source,Color("b5ffed"),3,.25);cue="ui_discovery"
	if not cue.is_empty():combat.sound(cue,source,true,.8)

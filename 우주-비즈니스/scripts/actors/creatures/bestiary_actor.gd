extends Node3D
## Presentation only: attack events identify visual timing, never deal damage.
signal attack_cue(phase: String)
const GroundMotion=preload("res://scripts/actors/creatures/ground_locomotion.gd")
var ground_motion: RefCounted
var visual_root: Node3D
const Ink = preload("res://scripts/actors/ink_style.gd")
var definition: Dictionary = {}
var appearance: Dictionary = {}
var models: Array[Node3D] = []
var joints: Array[Dictionary] = []
var anatomical_skeletons: Array[Skeleton3D]=[]
var material_slots: Dictionary = {}
var base_scale := 1.0
var movement_rate := 1.0
# Surface flight presentation supplies a continuous takeoff/landing blend.
var flight_blend := -1.0
var flight_clock := -1.0
var state := "idle"
var combat_override:=false
var combat_pattern:="none"
var combat_phase:=""
var combat_clock:=0.0
var combat_info: Dictionary={}
var combat_live: Dictionary={}
var combat_decal: Decal
static var combat_textures: Dictionary={}
var elapsed := 0.0
var paused := false
var attack_phase := ""
var fx: Node3D
var effect_nodes: Array[Node3D] = []
var lod_override := -1
var load_far := true
var defer_far:=false
var deferred_far_scene: PackedScene
var deferred_material_cache: Dictionary={}
var desired_distant:=false
var visible_model:=-1
static var attack_timing: Dictionary={}
var motion_phase := 0.0
var effect_color := Color("e4b065")
var show_effects := true
var attack_duration := 1.6
var windup_seconds := .55
var active_seconds := .30
var recovery_seconds := .75
var mouth_marker: Node3D
var mouth_markers: Array[Node3D]=[]
var visibility_notifier: VisibleOnScreenNotifier3D

func configure(form: Dictionary, look: Dictionary = {},ready_scenes: Array=[]) -> void:
	definition=form;combat_override=false;combat_pattern="none";combat_phase="";combat_clock=0.0
	deferred_far_scene=null;deferred_material_cache.clear();visible_model=-1;desired_distant=false
	if attack_timing.is_empty():attack_timing=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/attack_presentation.json")).timing_seconds
	var timing: Dictionary=attack_timing
	windup_seconds=float(timing.windup)
	active_seconds=float(timing.active)
	recovery_seconds=float(timing.recovery)
	attack_duration=windup_seconds+active_seconds+recovery_seconds
	appearance=look
	state="idle"
	elapsed=0
	attack_phase=""
	for child in get_children(): child.free()
	visual_root=Node3D.new();visual_root.name="LocomotionVisual";add_child(visual_root)
	ground_motion=GroundMotion.new()
	models.clear()
	joints.clear()
	anatomical_skeletons.clear()
	material_slots.clear()
	effect_nodes.clear()
	mouth_markers.clear()
	visibility_notifier=null
	var cache: Dictionary={}
	var lod_names: Array=["near","far"] if load_far and not defer_far else ["near"]
	for lod in lod_names:
		var scene: PackedScene=ready_scenes[0 if lod=="near" else 1] if ready_scenes.size()>=(1 if lod=="near" else 2) else load("res://"+str(form.lods[lod].path).trim_prefix("우주-비즈니스/"))
		_install_model(scene,cache)
	if load_far and defer_far:
		deferred_far_scene=ready_scenes[1] if ready_scenes.size()>1 else load("res://"+str(form.lods.far.path).trim_prefix("우주-비즈니스/"))
		deferred_material_cache=cache
	for mat in cache.values():
		var slot: String=mat.resource_name.trim_prefix("Bio_")
		if not material_slots.has(slot): material_slots[slot]=[]
		material_slots[slot].append(mat)
	apply_appearance(look)
	ground_motion.configure(self,visual_root)
	mouth_marker=mouth_markers[0]
	build_fx()
	set_lod(false)
	pose()

func _install_model(scene: PackedScene,cache: Dictionary) -> void:
	var model: Node3D=scene.instantiate()
	visual_root.add_child(model)
	Ink.apply(model,cache)
	models.append(model)
	mouth_markers.append(model.find_child("FX_Mouth",true,false) as Node3D)
	var row: Dictionary={}
	for n in model.find_children("Anim_*","Node3D",true,false):
		row[str(n.name)]={"node":n,"rest":n.transform}
	joints.append(row)
	var skeletons:=model.find_children("*","Skeleton3D",true,false)
	anatomical_skeletons.append(skeletons[0] as Skeleton3D if not skeletons.is_empty() else null)

func finish_lods() -> bool:
	if deferred_far_scene==null:return false
	_install_model(deferred_far_scene,deferred_material_cache)
	deferred_far_scene=null
	material_slots.clear()
	for mat in deferred_material_cache.values():
		var slot: String=mat.resource_name.trim_prefix("Bio_")
		if not material_slots.has(slot):material_slots[slot]=[]
		material_slots[slot].append(mat)
	deferred_material_cache={}
	apply_appearance(appearance)
	visible_model=-1;set_lod(desired_distant);pose(true)
	return true

func apply_appearance(look: Dictionary) -> void:
	appearance=look
	var colors: Array=look.get("palette",definition.palette)
	for i in range(3):
		var key: String=["main","secondary","accent"][i]
		# Palette numbers are Blender's linear base-color values; source_color expects sRGB.
		for mat in material_slots.get(key,[]): mat.set_shader_parameter("base_color",Color(colors[i]).linear_to_srgb())
	base_scale=float(look.get("scale",1.0))
	for i in range(models.size()):
		var model: Node3D=models[i]
		model.scale=Vector3.ONE*base_scale
		var lod: String="near" if i==0 else "far"
		model.position.y=-float(definition.get("geometry",{}).get(lod,{}).get("floor_y",0))*base_scale

func set_lod(distant: bool) -> void:
	desired_distant=distant
	var index:=1 if distant and models.size()>1 else 0
	if visible_model==index:return
	visible_model=index
	for i in range(models.size()):models[i].visible=i==index
	if not mouth_markers.is_empty():mouth_marker=mouth_markers[index]

func enable_field_culling() -> void:
	visibility_notifier=FrontierFieldVisibility.watch(self,2.0*base_scale)

func set_state(value: String) -> bool:
	if not value in ["idle","move","feed","dormant","stressed","attack"]: return false
	if value=="attack" and definition.get("attack","none")=="none": return false
	state=value
	elapsed=0
	attack_phase=""
	if FrontierFieldVisibility.active(visibility_notifier):pose()
	else:_update_attack_phase()
	return true

func _process(delta: float) -> void:
	if ground_motion!=null:ground_motion.preview(delta)
	if not paused and not combat_override:
		elapsed+=delta*(movement_rate if state=="move" else 1.0)
		_update_attack_phase()
	if not FrontierFieldVisibility.active(visibility_notifier):return
	var camera:=get_viewport().get_camera_3d()
	if lod_override>=0: set_lod(lod_override==1)
	elif camera: set_lod(camera.global_position.distance_to(global_position)>25.)
	if not paused:pose(true)

func pose(visible_lod_only: bool=false) -> void:
	if not combat_override:_update_attack_phase()
	var t:=flight_clock if definition.get("construction","")=="avian" and flight_clock>=0 else elapsed+motion_phase
	if ground_motion!=null and ground_motion.enabled:t=ground_motion.idle_clock+motion_phase
	for lod_index in joints.size():
		if visible_lod_only and not models[lod_index].visible:continue
		var row: Dictionary=joints[lod_index]
		for part in row.values(): part.node.transform=part.rest
		var body: Node3D=row.get("Anim_Body",{}).get("node")
		if body==null:continue
		if definition.get("collection","")=="biota-7000":
			_biota_organ_pose(row,t)
			if combat_override:_combat_pose(row)
			if ground_motion.enabled:ground_motion.pose(row,lod_index)
			_anatomical_pose(lod_index,row,t)
			continue
		var head: Node3D=row.get("Anim_Head",{}).get("node")
		var jaw: Node3D=row.get("Anim_Jaw",{}).get("node")
		var tail: Node3D=row.get("Anim_Tail",{}).get("node")
		var aquatic: bool=definition.family in ["swimmer","ray","lantern_sail"]
		if state=="dormant":
			body.scale.y=.86+.007*sin(t*.7)
			if head:head.rotation.x=-.08
		elif state in ["idle","move","feed","stressed"]:
			if head:head.rotation.y=.055*sin(t*.9)
			if tail:tail.rotation.y=.10*sin(t*1.8)
			if state=="feed":
				if head:head.rotation.x=-.15+.06*sin(t*2.8)
				if jaw:jaw.rotation.x=maxf(0,sin(t*5))*.25
			if state=="stressed":
				if head:head.position.z-=.12;head.rotation.y=.055*sin(t*8)
				body.scale.y=.95
			for key in row:
				var n: Node3D=row[key].node
				if key.begins_with("Anim_Leg") and state=="move" and not ground_motion.enabled:
					var phase: float=t*3.3+float(key.hash()%10)
					n.rotation.y=.17*sin(phase)
					# Newly authored limbs rotate at their attached hip. Translating the
					# entire limb would pull its root away from the body's rigid surface.
					if definition.get("collection","")=="biota-7000":n.rotation.x+=.12*sin(phase)
					else:n.position.y+=maxf(0,sin(phase))*.12
				elif key.begins_with("Anim_Wing"):
					var sign_value: float=-1 if key.ends_with("L") else 1
					n.rotation.z=sign_value*sin(t*(2.2 if aquatic else 4.0))*(.16 if state=="idle" else .33)
					if definition.get("locomotion_medium","")=="atmosphere":n.rotation.z=sign_value*sin(t*.7)*(.055 if state=="idle" else .09)
				elif key.begins_with("Anim_Segment"):
					var index:=int(key.trim_prefix("Anim_Segment_"))
					var wave_clock: float=ground_motion.phase*TAU if ground_motion.enabled else t*2.2
					n.position.x+=sin(wave_clock+index*.55)*(.11 if state=="move" else .025)
					n.rotation.y=sin(wave_clock+index*.55)*.11
				elif key.begins_with("Anim_Petal"):
					n.rotation.z=sin(t*1.3+float(key.hash()%17))*(.09 if state=="feed" else .035)
				elif key.begins_with("Anim_Frond") or key.begins_with("Anim_Appendage"):
					n.rotation.x=sin(t*1.1+float(key.hash()%31))*.025
					n.rotation.z=sin(t*.8+float(key.hash()%17))*.035
			if aquatic:body.position.y+=sin(t*1.6)*.055
		if combat_override:_combat_pose(row)
		elif state=="attack":attack_pose(row,elapsed)
		if definition.get("collection","") in ["xenofauna-300","xenoflora-100","biota-7000"]:_organic_pose(row,t)
		if definition.get("locomotion_medium","")=="atmosphere":body.position.y+=sin(t*.65+motion_phase)*.06;body.rotation.z+=sin(t*.4)*.025
		if ground_motion.enabled:ground_motion.pose(row,lod_index)
		if definition.get("rig",{}).get("skinned",false):_anatomical_pose(lod_index,row,t)
	update_fx()

func drive_ground(at: Vector3,facing: Basis,delta: float,sampler: Callable,stopped: bool) -> void:
	if ground_motion!=null and ground_motion.enabled:
		ground_motion.drive(Transform3D(facing,at),delta,sampler,stopped)
	else:global_transform=Transform3D(facing,at)

func apply_combat(live: Dictionary,profile: Dictionary,stopped: bool) -> void:
	combat_override=true;combat_pattern=profile.pattern;combat_phase=live.phase;combat_clock=float(live.time)
	combat_info=profile;combat_live=live
	paused=stopped;elapsed=combat_clock
	windup_seconds=float(profile.get("windup",.7));active_seconds=float(profile.get("active",.3));recovery_seconds=float(profile.get("recovery",1.1))
	attack_duration=windup_seconds+active_seconds+recovery_seconds
	state="attack" if combat_phase=="attack" else ("dormant" if combat_phase=="down" else ("move" if combat_phase in ["chase","flee","return"] else ("stressed" if combat_phase in ["warning","hurt"] else "idle")))

func _combat_pose(row: Dictionary) -> void:
	var body: Node3D=row.Anim_Body.node
	if combat_phase=="down":
		body.scale.y*=.65;body.rotation.z+=.28
		return
	if combat_phase=="hurt":
		body.position.z+=sin(clampf(combat_clock/.28,0,1)*PI)*.12
		return
	if combat_phase not in ["warning","attack"]:return
	var waiting:=combat_phase=="warning"
	var windup:=.5+.12*sin(combat_clock*6) if waiting else clampf(combat_clock/windup_seconds,0,1)
	var strike:=clampf((combat_clock-windup_seconds)/active_seconds,0,1) if not waiting else 0.0
	var recover:=clampf((combat_clock-windup_seconds-active_seconds)/recovery_seconds,0,1) if not waiting else 0.0
	var hold:=windup if waiting or combat_clock<windup_seconds else 1-recover
	var energy:=sin(strike*PI)
	var mode: String=combat_info.get("behavior","melee")
	if mode=="double_sweep" and not waiting and combat_clock>=windup_seconds:
		var swing:=combat_clock-windup_seconds
		if swing>=float(combat_info.second_strike):swing-=float(combat_info.second_strike)
		energy=sin(clampf(swing/.20,0,1)*PI)
		strike=clampf(swing/.20,0,1)
	# These Blender animals face Godot-local +Z. Preserve each Blender hinge's rest frame and attachment.
	body.position.z+=(-.13*hold if waiting or combat_clock<windup_seconds else 0.0) if mode=="charge" else -.13*hold+.42*energy
	if combat_pattern=="slam":body.position.y+=.22*hold-.12*energy
	if mode=="leap":
		body.position.y-=.20*hold if waiting or combat_clock<windup_seconds else .10*energy
		body.rotation.x+=.12*hold-.22*energy
	if mode=="charge" and not waiting and combat_clock>=windup_seconds and combat_clock<windup_seconds+active_seconds:
		body.rotation.x+=.12;body.position.y+=absf(sin((ground_motion.phase*TAU) if ground_motion.enabled else combat_clock*24))*.06
	if combat_live.get("attack",{}).get("blocked",false):body.rotation.z+=sin(recover*PI*5)*.10*(1-recover)
	for key in row:
		if key=="Anim_Body":continue
		var angle:=Vector3.ZERO
		if key=="Anim_Head":angle.x=(.23 if combat_pattern=="ram" else -.12)*hold+(.22 if combat_pattern=="bite" else -.20)*energy
		elif key=="Anim_Jaw" or key.begins_with("Anim_Flex_Jaw"):angle.x=.42*hold*(1-strike)
		elif key.begins_with("Anim_Flex_Pincer") or key.begins_with("Anim_Arm"):
			angle.y=(.4*hold-.65*energy)*(-1 if key.ends_with("L") else 1)
		elif key.begins_with("Anim_Flex_RaptorialElbow"):angle.x=.65*hold-.9*energy
		elif key.begins_with("Anim_Flex_Raptorial_"):angle.x=-.5*hold+1.0*energy
		elif key.begins_with("Anim_Flex_Finger"):angle.z=.32*hold-.5*energy
		elif key.begins_with("Anim_GaitHip_F") and combat_pattern in ["claw","scythe"]:angle.x=-.4*hold+.9*energy
		elif key.begins_with("Anim_Leg_0") and combat_pattern=="kick":angle.x=-.35*hold+.95*energy
		elif key.begins_with("Anim_Flex_Sting"):angle.x=.10*hold-.16*energy
		if not ground_motion.enabled and mode=="charge" and combat_clock>=windup_seconds and combat_clock<windup_seconds+active_seconds and (key.begins_with("Anim_GaitHip") or key.begins_with("Anim_Leg")):
			angle.x+=sin(combat_clock*24+(0 if key.ends_with("L") else PI))*.55
		if mode=="leap" and key.begins_with("Anim_GaitHip"):
			angle.x+=(-.5 if "_F" in key else .5)*hold*(1-energy)
		if mode=="shockwave" and (key.begins_with("Anim_Arm") or key.begins_with("Anim_Leg_0")):
			angle.x-=.6*hold-.8*energy
		if mode=="double_sweep" and combat_clock>=windup_seconds+float(combat_info.second_strike):angle.y=-angle.y
		row[key].node.transform=row[key].node.transform*Transform3D(Basis.from_euler(angle),Vector3.ZERO)

func _biota_organ_pose(row: Dictionary,t: float) -> void:
	# Every hinge keeps its authored local axes. Replacing a global Euler angle
	# collapses radial legs and branch trunks onto the same direction.
	var resting: bool=state=="dormant"
	var gain: float=.18 if resting else (1.25 if state=="stressed" else 1.0)
	for key in row:
		if key=="Anim_Body":continue
		var angle:=Vector3.ZERO
		var phase: float=float(key.hash()%31)
		if definition.get("construction","")=="avian" and (key.begins_with("Anim_Wing") or key.begins_with("Anim_Avian")):
			angle=_avian_hinge_angle(key,t)
		elif key.begins_with("Anim_Leg") and state=="move" and not ground_motion.enabled:
			angle.x=.12*sin(t*3.3+phase)
			angle.z=.10*cos(t*3.3+phase)
		elif key.begins_with("Anim_Head"):
			angle.y=.04*sin(t*.9)
			if state=="feed":angle.x=-.10+.04*sin(t*2.8)
		elif key.begins_with("Anim_Tail"):
			angle.y=.08*sin(t*1.8)
		elif key.begins_with("Anim_Petal"):
			angle.z=sin(t*1.3+phase)*(.08 if state=="feed" else .025)
		elif key.begins_with("Anim_Frond") or key.begins_with("Anim_Appendage"):
			angle.x=sin(t*1.1+phase)*.025
			angle.z=sin(t*.8+phase)*.025
		elif key.begins_with("Anim_Segment") and definition.construction=="chain":
			angle.y=sin(t*1.1+phase)*.015
		# Branch trunks support terminal organs attached to the tissue scaffold;
		# they follow that scaffold without an independent root displacement.
		var hinge_gain: float=1.0 if definition.get("construction","")=="avian" and (key.begins_with("Anim_Wing") or key.begins_with("Anim_Avian")) else gain
		row[key].node.transform=row[key].rest*Transform3D(Basis.from_euler(angle*hinge_gain),Vector3.ZERO)
	if definition.has("replacement"):_midpoint_pose(row,t,gain)
	var body: Node3D=row.Anim_Body.node
	var wave: float=sin(t*.65+float(definition.anatomy)*.57)
	var strength: float=.008 if resting else .025
	match str(definition.get("motion_profile","pulse")):
		"pulse":body.scale*=Vector3(1+wave*strength*.5,1-wave*strength*.35,1+wave*strength*.5)
		"compress":body.scale.z*=1+wave*strength*.55
		"sway":body.rotation.z+=wave*strength*.35
	if resting:body.scale.y*=.86+.007*sin(t*.7)
	elif state=="stressed":body.scale.y*=.95
	if definition.get("locomotion_medium","")=="atmosphere":
		body.position.y+=sin(t*.65+motion_phase)*.06
		body.rotation.z+=sin(t*.4)*.025

func _midpoint_pose(row: Dictionary,t: float,gain: float) -> void:
	# Each anatomical chain retains its authored rest axes and distal attachments.
	for key in definition.get("anatomical_motion",{}):
		if not row.has(key):continue
		var data: Dictionary=definition.anatomical_motion[key]
		var amount: float=sin(t*float(data.speed)+float(data.phase))*float(data.amplitude)*gain
		if data.get("feeding",false):amount*=2.0 if state=="feed" else .35
		var angle:=Vector3.ZERO
		angle[0 if data.axis=="x" else (1 if data.axis=="y" else 2)]=amount
		row[key].node.transform=row[key].rest*Transform3D(Basis.from_euler(angle),Vector3.ZERO)
	if state!="move" or ground_motion.enabled:return
	var gait: Dictionary=definition.get("gait",{})
	for data in gait.get("limbs",{}).values():
		var upper:=Vector3(data.upper[0],data.upper[1],data.upper[2])
		var lower:=Vector3(data.lower[0],data.lower[1],data.lower[2])
		var phase: float=t*float(gait.rate)+float(data.phase)
		var destination:=upper+lower+Vector3(0,maxf(0,sin(phase))*float(data.lift),cos(phase)*float(data.stride))
		var a:=upper.length();var b:=lower.length()
		var distance:=clampf(destination.length(),absf(a-b)+.001,a+b-.001)
		var direction:=destination.normalized();destination=direction*distance
		var along: float=(a*a-b*b+distance*distance)/(2*distance)
		var bend: Vector3=upper-direction*upper.dot(direction)
		if bend.length_squared()<.00001:bend=direction.cross(Vector3.RIGHT)
		bend=bend.normalized()
		var knee: Vector3=direction*along+bend*sqrt(maxf(0,a*a-along*along))
		var hip_rotation:=Quaternion(upper.normalized(),knee.normalized())
		var lower_rotation:=Quaternion(lower.normalized(),(destination-knee).normalized())
		for part in [[data.hip,hip_rotation],[data.knee,hip_rotation.inverse()*lower_rotation],[data.ankle,lower_rotation.inverse()]]:
			if row.has(part[0]):row[part[0]].node.transform=row[part[0]].rest*Transform3D(Basis(part[1]),Vector3.ZERO)

func _avian_hinge_angle(key: String,t: float) -> Vector3:
	var flying: float=clampf(flight_blend,0,1) if flight_blend>=0 else (1.0 if state=="move" else 0.0)
	var sign_value: float=-1.0 if "_L" in key else 1.0
	var beat: float=t*TAU*float(definition.flight.flap_hz)+(PI*.42 if key.ends_with("1") else 0.0)
	# These unrotated avian hinges import with Godot-local axes.
	# Local Z lifts the wing; local Y folds it behind the shoulder.
	if key.begins_with("Anim_WingShoulder"):
		return Vector3(0,sign_value*lerpf(-1.45,.02,flying),sign_value*lerpf(.08,.48*sin(beat),flying))
	if key.begins_with("Anim_WingElbow"):
		return Vector3(0,sign_value*lerpf(2.5,.10+.12*cos(beat-.55),flying),sign_value*.13*sin(beat-.6)*flying)
	if key.begins_with("Anim_WingWrist"):
		return Vector3(0,sign_value*lerpf(-2.3,-.04+.16*sin(beat-.9),flying),sign_value*.15*sin(beat-.9)*flying)
	if key.begins_with("Anim_AvianHip"):
		return Vector3(-.85*flying,0,0)
	if key.begins_with("Anim_AvianKnee"):
		return Vector3(1.5*flying,0,0)
	return Vector3.ZERO

func _anatomical_pose(lod_index: int,row: Dictionary,t: float) -> void:
	var skeleton: Skeleton3D=anatomical_skeletons[lod_index]
	if skeleton==null:return
	var rig: Dictionary=definition.rig
	for marker in rig.hinges:
		if not row.has(marker):continue
		var bone:=skeleton.find_bone(rig.hinges[marker])
		if bone<0:continue
		var change: Transform3D=row[marker].rest.affine_inverse()*row[marker].node.transform
		var pose: Transform3D=skeleton.get_bone_rest(bone)*change
		skeleton.set_bone_pose_position(bone,pose.origin)
		skeleton.set_bone_pose_rotation(bone,pose.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone,pose.basis.get_scale())
	var gain: float=.18 if state=="dormant" else (1.5 if state=="move" else (1.2 if state=="feed" else 1.0))
	var motion: Dictionary=rig.motion;var layout: String=rig.layout
	for index in rig.scaffold.size():
		var bone:=skeleton.find_bone(rig.scaffold[index])
		if bone<0:continue
		var clock_value: float=ground_motion.phase*TAU/float(motion.speed) if ground_motion.enabled and ground_motion.kind in ["slither","crawl"] else t
		var phase: float=clock_value*float(motion.speed)+float(index)*(.85 if layout in ["metameric","undulating","helical"] else .4)
		var wave: float=sin(phase)*gain if index>0 else 0.0
		if ground_motion.enabled:
			if not ground_motion.limbs.is_empty():wave=0.0
			else:wave*=ground_motion.intensity
		var angle:=wave*float(motion.angle);var offset:=Vector3.ZERO;var rotation:=Vector3.ZERO
		match layout:
			"axial","metameric":rotation.y=angle;offset.y=wave*float(motion.translation)
			"undulating":rotation.z=angle;offset.y=wave*float(motion.translation)
			"radial":rotation.x=angle;offset.y=wave*float(motion.translation)
			"column":rotation.z=angle
			"vault":rotation.x=angle;offset.y=wave*float(motion.translation)*.5
			"laminar":rotation.z=angle;rotation.x=angle*.5
			"helical":rotation.y=angle;rotation.z=angle*.5
			"paired":rotation.z=angle*(-1 if index%2==0 else 1)
			"avian":rotation.x=angle*.5
			"tetrapod","saltatory","arthropod":rotation.x=angle*.5
			"serpentine":rotation.y=angle
			"branching":rotation.x=angle;rotation.z=angle*.6
		var pose: Transform3D=skeleton.get_bone_rest(bone)*Transform3D(Basis.from_euler(rotation),offset)
		skeleton.set_bone_pose_rotation(bone,pose.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_position(bone,pose.origin)
	skeleton.force_update_all_bone_transforms()
	if ground_motion.enabled:ground_motion.skin(skeleton,row,lod_index)

func _organic_pose(row: Dictionary,t: float) -> void:
	var kind: String=definition.get("motion_profile","pulse")
	var strength: float=.025 if state=="dormant" else (.14 if state=="feed" else (.085 if state=="move" else .045))
	var speed: float=1.8 if state=="stressed" else (1.3 if state=="move" else .65)
	var wave: float=sin(t*speed+float(definition.get("anatomy",0))*.57)
	var body: Node3D=row.Anim_Body.node
	if kind=="pulse":body.scale*=Vector3(1+wave*strength*.5,1-wave*strength*.35,1+wave*strength*.5)
	elif kind=="compress":body.scale.z*=1+wave*strength*.55
	elif kind=="sway":body.rotation.z+=wave*strength*.35
	for key in row:
		var node: Node3D=row[key].node
		var phase: float=t*speed+float(key.hash()%17)*.53
		if key.begins_with("Anim_Petal") or key.begins_with("Anim_Frond"):
			node.rotation.z+=sin(phase)*strength*(1.6 if kind=="bloom" else .5)
		elif key.begins_with("Anim_Appendage"):
			if kind=="spiral":node.rotation.y+=sin(phase)*strength*.55
			elif kind=="flex":node.scale.x*=1+sin(phase)*strength*.65
			else:node.rotation.x+=sin(phase)*strength*.5
		elif key.begins_with("Anim_Segment") and kind=="compress":node.position.z+=sin(phase)*strength*.3

func _update_attack_phase() -> void:
	if state=="attack":
		var phase: String="windup" if elapsed<windup_seconds else ("active" if elapsed<windup_seconds+active_seconds else "recovery")
		if elapsed>=attack_duration:
			state="idle"
			elapsed=0
			phase="complete"
		if phase!=attack_phase:
			attack_phase=phase
			attack_cue.emit(phase)

func attack_pose(row: Dictionary,t: float) -> void:
	var body: Node3D=row.Anim_Body.node
	var head: Node3D=row.get("Anim_Head",{}).get("node")
	var jaw: Node3D=row.get("Anim_Jaw",{}).get("node")
	var windup:=clampf(t/windup_seconds,0,1)
	var strike:=clampf((t-windup_seconds)/active_seconds,0,1)
	var recover:=clampf((t-windup_seconds-active_seconds)/recovery_seconds,0,1)
	var energy:=sin(strike*PI) if t>=windup_seconds and t<windup_seconds+active_seconds else 0.
	var hold:=windup if t<windup_seconds else 1.-recover
	var kind: String=definition.attack
	if kind in ["ram","kick","slam","bite","dive"]:
		body.position.z+=(-.20*windup if t<windup_seconds else lerpf(-.20,.52,smoothstep(0.,1.,strike))*(1.0-recover))
		if kind=="dive":body.position.y+=(.65*windup if t<windup_seconds else .65*pow(1.-strike,3))
	if kind=="ram":
		if head:head.rotation.x=.25*hold-.35*energy
	elif kind=="bite":
		if jaw:jaw.rotation.x=.50*hold*(1.-strike if t>windup_seconds else 1.)
		if head:head.rotation.x=-.10*hold+.18*energy
	elif kind=="slam":
		body.position.y+=.25*hold if t<windup_seconds else .18*(1.-strike)*(1.-recover)
		if head:head.rotation.x=.20*hold
	elif kind=="spit":
		if head:head.rotation.x=-.17*hold+.25*energy
		if jaw:jaw.rotation.x=.32*hold
	elif kind=="kick":
		for key in row:
			if key.begins_with("Anim_Leg_0"):
				row[key].node.rotation.x=-.75*energy
				row[key].node.position.y+=.38*energy
	for key in row:
		var n: Node3D=row[key].node
		if key.begins_with("Anim_Arm"):
			var sign_value: float=-1 if key.ends_with("L") else 1
			n.rotation.z=sign_value*(.55*windup if t<windup_seconds else -.85*energy)
			n.rotation.x=-.5*energy
		if definition.get("collection","")=="aberrant":
			if key.begins_with("Anim_Petal") or key.begins_with("Anim_Appendage"):
				n.rotation.z=(.12*hold-.30*energy)*(-1. if key.hash()%2==0 else 1.)
			if key=="Anim_Jaw" and kind=="bite":
				n.scale=Vector3.ONE*(1.+.20*hold-.32*energy)
			if key.begins_with("Anim_Leg") and kind=="slam":
				n.rotation.x=.12*hold-.25*energy
		if key.begins_with("Anim_Wing"):
			var sign_value: float=-1 if key.ends_with("L") else 1
			n.rotation.z=sign_value*(.5*hold+.20*sin(t*11))

func fx_material(color: Color,transparent: bool=false) -> Material:
	var original:=StandardMaterial3D.new()
	original.albedo_color=color
	original.roughness=.8
	if transparent:
		original.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		original.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		original.no_depth_test=false
		return original
	return Ink.material(original,{})

func build_fx() -> void:
	fx=Node3D.new()
	fx.name="AttackPresentation"
	add_child(fx)
	combat_decal=Decal.new();combat_decal.name="GroundAttackPreview";combat_decal.visible=false
	combat_decal.normal_fade=.65;fx.add_child(combat_decal)
	for i in range(20):
		var mi:=MeshInstance3D.new()
		mi.name="PooledEffect_%02d"%i
		if i<12:
			var mesh:=SphereMesh.new()
			mesh.radial_segments=8
			mesh.rings=4
			mi.mesh=mesh
		elif i<16:
			var mesh:=TorusMesh.new()
			mesh.inner_radius=.94
			mesh.outer_radius=1.0
			mesh.rings=40
			mesh.ring_segments=6
			mi.mesh=mesh
		else:
			var mesh:=BoxMesh.new()
			mesh.size=Vector3(.035,.035,.30)
			mi.mesh=mesh
		var color:=Color("b3d773") if definition.get("attack")=="spit" else Color("e8bd77")
		mi.material_override=fx_material(color)
		mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible=false
		fx.add_child(mi)
		effect_nodes.append(mi)

func update_fx() -> void:
	for n in effect_nodes:n.visible=false
	if is_instance_valid(combat_decal):combat_decal.visible=false
	if not show_effects or state!="attack": return
	if combat_override and _combat_fx():return
	# Shape and motion distinguish cues; no per-attack node allocation.
	var k: String=combat_pattern if combat_override else definition.attack
	var mouth:=to_local(mouth_marker.global_position) if mouth_marker else Vector3(0,.85,1.25)*base_scale
	var hit_point:=Vector3(mouth.x,.20*base_scale,mouth.z+(.95 if k=="spit" else .25)*base_scale)
	if elapsed<windup_seconds:
		var cue: Node3D=effect_nodes[12]
		cue.visible=true
		cue.position=Vector3(0,.035,0)
		cue.scale=Vector3.ONE*(.42+.24*elapsed/windup_seconds)
		return
	var t:=elapsed-windup_seconds
	if t>.70:return
	if k=="spit":
		var ball: Node3D=effect_nodes[0]
		ball.visible=t<.32
		ball.scale=Vector3.ONE*.16
		ball.position=mouth.lerp(hit_point,clampf(t/.32,0,1))
		if t<.32:return
		t-=.32
	for i in range(1,12):
		var fragment: Node3D=effect_nodes[i]
		fragment.visible=true
		var a:=float(i)*2.399
		var speed:=1.0+float(i%3)*.4
		fragment.position=hit_point+Vector3(cos(a)*t*speed,maxf(.04,.12+t*(.9+i%3*.2)-t*t*2.2),sin(a)*t*speed*.65)
		fragment.scale=Vector3.ONE*maxf(.01,.105*(1.-t/.70))
	for i in range(13,16):
		var ring: Node3D=effect_nodes[i]
		ring.visible=true
		ring.position=hit_point+Vector3(0,.02*(i-12),0)
		ring.scale=Vector3.ONE*(.12+t*(1.+(i-12)*.5))
	if k in ["claw","scythe","kick","bite","dive"]:
		for i in range(16,20):
			var slash: Node3D=effect_nodes[i]
			slash.visible=t<.22
			var height: float=.35*base_scale if k in ["kick","dive"] else mouth.y*.7
			slash.position=Vector3(hit_point.x+(i-17.5)*.18*base_scale,height+(i%2)*.12*base_scale,mouth.z+.85*base_scale)
			slash.rotation=Vector3(.5,0,.8)
			slash.scale=Vector3(1,1,1.+t*3)

func _combat_fx() -> bool:
	var mode: String=combat_info.get("behavior","melee")
	if mode=="melee":return false
	var elapsed_active:=combat_clock-windup_seconds
	var preparing:=elapsed_active<0
	var progress:=clampf(combat_clock/windup_seconds,0,1)
	var a: Dictionary=combat_live.get("attack",{})
	var center:=Vector3(0,.055-float(combat_live.get("air_height",0)),0)
	var radius:=float(combat_info.get("attack_radius",combat_info.reach))
	if mode=="leap" and a.has("goal"):
		center=to_local(FrontierCrewWorld.vector(a.goal))+Vector3.UP*.06
	if mode in ["leap","shockwave"]:
		_project_ground("circle",center,Vector2.ONE*(radius+.12)*2,preparing or (mode=="shockwave" and elapsed_active<float(combat_info.impact_delay)) or (mode=="leap" and elapsed_active<active_seconds and not a.get("blocked",false)))
		var timer: Node3D=effect_nodes[13]
		timer.visible=preparing;timer.position=center+Vector3.UP*.04
		timer.rotation=Vector3.ZERO;timer.scale=Vector3(radius*maxf(.03,progress),.15,radius*maxf(.03,progress))
		var impact_time:=elapsed_active-(active_seconds if mode=="leap" else float(combat_info.impact_delay))
		if impact_time>=0 and impact_time<.4 and not a.get("blocked",false):
			var wave: Node3D=effect_nodes[14];wave.visible=true;wave.position=center
			wave.rotation=Vector3.ZERO;wave.scale=Vector3.ONE*radius*(.75+impact_time*.6);wave.scale.y=.25
			_combat_dust(center,impact_time,radius)
	elif mode=="charge":
		if preparing:
			var distance:=float(combat_info.charge_distance)+float(combat_info.attack_front)+float(combat_info.contact_radius)
			var width:=float(combat_info.radius)+float(combat_info.contact_radius)
			_project_ground("charge",Vector3(0,.06,distance*.5),Vector2(width*2+.15,distance),true)
		elif elapsed_active<active_seconds or a.get("blocked",false):_combat_dust(Vector3(0,.1,-.4),fmod(elapsed_active,.4),float(combat_info.radius))
	elif mode=="double_sweep":
		if preparing:
			for i in range(12,14):
				var cue: Node3D=effect_nodes[i];cue.visible=true
				cue.position=Vector3((-.45 if i==12 else .45),.12,1.0)
				cue.rotation=Vector3.ZERO;cue.scale=Vector3.ONE*(.28+.12*progress)
		else:
			var second:=elapsed_active>=float(combat_info.second_strike)
			var swing:=elapsed_active-(float(combat_info.second_strike) if second else 0.0)
			if swing<.25:
				for i in range(16,20):
					var slash: Node3D=effect_nodes[i];slash.visible=true
					var angle: float=lerpf(-1.25,1.25,clampf(swing/.25+float(i-18)*.05,0,1))*(-1 if second else 1)
					slash.position=Vector3(sin(angle)*radius,.55,cos(angle)*radius)
					slash.rotation=Vector3(0,angle+PI*.5,.25);slash.scale=Vector3(2,2,2.8)
	return true

func _combat_dust(center: Vector3,time: float,radius: float) -> void:
	for i in range(1,12):
		var part: Node3D=effect_nodes[i];part.visible=true
		var angle:=float(i)*2.399
		part.position=center+Vector3(cos(angle)*radius*time*2,maxf(.05,time*(1.8-time*4)),sin(angle)*radius*time*2)
		part.scale=Vector3.ONE*maxf(.015,.15*(1-time/.4))

func _project_ground(kind: String,center: Vector3,dimensions: Vector2,enabled: bool) -> void:
	# Forward+ decals follow uneven terrain; a long flat ribbon sinks into hills.
	combat_decal.visible=enabled
	if not enabled:return
	if not combat_textures.has(kind):
		var shape:="<circle cx='128' cy='128' r='119'/>" if kind=="circle" else "<path d='M12 12 L12 244 M244 12 L244 244 M78 205 L128 244 L178 205'/>"
		var svg:="<svg xmlns='http://www.w3.org/2000/svg' width='256' height='256'><g fill='none' stroke='#20170e' stroke-width='10'>"+shape+"</g><g fill='none' stroke='#ffd080' stroke-width='5'>"+shape+"</g></svg>"
		var image:=Image.new();image.load_svg_from_string(svg)
		combat_textures[kind]=ImageTexture.create_from_image(image)
	combat_decal.texture_albedo=combat_textures[kind]
	combat_decal.size=Vector3(dimensions.x,5,dimensions.y)
	combat_decal.position=center+Vector3.UP*.6

extends Node3D
## Presentation only: attack events identify visual timing, never deal damage.
signal attack_cue(phase: String)
const Ink = preload("res://scripts/actors/ink_style.gd")
var definition: Dictionary = {}
var appearance: Dictionary = {}
var models: Array[Node3D] = []
var joints: Array[Dictionary] = []
var material_slots: Dictionary = {}
var base_scale := 1.0
var state := "idle"
var elapsed := 0.0
var paused := false
var attack_phase := ""
var fx: Node3D
var effect_nodes: Array[Node3D] = []
var lod_override := -1
var load_far := true
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

func configure(form: Dictionary, look: Dictionary = {}) -> void:
	definition=form
	var timing: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/attack_presentation.json")).timing_seconds
	windup_seconds=float(timing.windup)
	active_seconds=float(timing.active)
	recovery_seconds=float(timing.recovery)
	attack_duration=windup_seconds+active_seconds+recovery_seconds
	appearance=look
	state="idle"
	elapsed=0
	attack_phase=""
	for child in get_children(): child.free()
	models.clear()
	joints.clear()
	material_slots.clear()
	effect_nodes.clear()
	mouth_markers.clear()
	visibility_notifier=null
	var cache: Dictionary={}
	var lod_names: Array=["near","far"] if load_far else ["near"]
	for lod in lod_names:
		var model: Node3D=load("res://"+str(form.lods[lod].path).trim_prefix("우주-비즈니스/")).instantiate()
		add_child(model)
		Ink.apply(model,cache)
		models.append(model)
		mouth_markers.append(model.find_child("FX_Mouth",true,false) as Node3D)
		var row: Dictionary={}
		for n in model.find_children("Anim_*","Node3D",true,false):
			row[str(n.name)]={"node":n,"rest":n.transform}
		joints.append(row)
	for mat in cache.values():
		var slot: String=mat.resource_name.trim_prefix("Bio_")
		if not material_slots.has(slot): material_slots[slot]=[]
		material_slots[slot].append(mat)
	apply_appearance(look)
	mouth_marker=models[0].find_child("FX_Mouth",true,false) as Node3D
	build_fx()
	set_lod(false)
	pose()

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
	for i in range(models.size()): models[i].visible=(i==1 if distant and models.size()>1 else i==0)
	if not mouth_markers.is_empty():mouth_marker=mouth_markers[1 if distant and models.size()>1 else 0]

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
	if not paused:
		elapsed+=delta
		_update_attack_phase()
	if not FrontierFieldVisibility.active(visibility_notifier):return
	var camera:=get_viewport().get_camera_3d()
	if lod_override>=0: set_lod(lod_override==1)
	elif camera: set_lod(camera.global_position.distance_to(global_position)>25.)
	if not paused:pose(true)

func pose(visible_lod_only: bool=false) -> void:
	_update_attack_phase()
	var t:=elapsed+motion_phase
	for lod_index in joints.size():
		if visible_lod_only and not models[lod_index].visible:continue
		var row: Dictionary=joints[lod_index]
		for part in row.values(): part.node.transform=part.rest
		var body: Node3D=row.get("Anim_Body",{}).get("node")
		if body==null:continue
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
				if key.begins_with("Anim_Leg") and state=="move":
					var phase: float=t*3.3+float(key.hash()%10)
					n.rotation.y=.17*sin(phase)
					n.position.y+=maxf(0,sin(phase))*.12
				elif key.begins_with("Anim_Wing"):
					var sign_value: float=-1 if key.ends_with("L") else 1
					n.rotation.z=sign_value*sin(t*(2.2 if aquatic else 4.0))*(.16 if state=="idle" else .33)
				elif key.begins_with("Anim_Segment"):
					var index:=int(key.trim_prefix("Anim_Segment_"))
					n.position.x+=sin(t*2.2+index*.55)*(.11 if state=="move" else .025)
					n.rotation.y=sin(t*2.2+index*.55)*.11
				elif key.begins_with("Anim_Petal"):
					n.rotation.z=sin(t*1.3+float(key.hash()%17))*(.09 if state=="feed" else .035)
				elif key.begins_with("Anim_Frond") or key.begins_with("Anim_Appendage"):
					n.rotation.x=sin(t*1.1+float(key.hash()%31))*.025
					n.rotation.z=sin(t*.8+float(key.hash()%17))*.035
			if aquatic:body.position.y+=sin(t*1.6)*.055
		if state=="attack":attack_pose(row,elapsed)
	update_fx()

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
	if not show_effects or state!="attack": return
	# Shape and motion distinguish cues; no per-attack node allocation.
	var k: String=definition.attack
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

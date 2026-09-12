extends Node3D
## Approved study meshes and authored per-anatomy clips. No species substitution.
const Ink=preload("res://scripts/actors/ink_style.gd")
var form: Dictionary
var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var clip: String=""
var bindings: Dictionary={}
var hit_material: StandardMaterial3D
var hit_flash:=0.0
var surfaces: Array=[]
var locomotion_phase:=0.0
var locomotion_gait:="move_loop"

func load_form(definition: Dictionary) -> void:
	form=definition
	var gltf:=GLTFDocument.new();var state:=GLTFState.new()
	var path: String="res://"+str(form.lods.near.path).trim_prefix("우주-비즈니스/")
	assert(gltf.append_from_file(path,state)==OK)
	model=gltf.generate_scene(state);add_child(model);Ink.apply(model,{})
	model.position.y=-float(form.lods.near.min[1]) if form.kind!="glider" else 0
	for child in model.find_children("*","Skeleton3D",true,false):skeleton=child;break
	for child in model.find_children("*","AnimationPlayer",true,false):player=child;break
	assert(skeleton!=null and player!=null)
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in player.get_animation_list():
		if name.ends_with("_loop"):player.get_animation(name).loop_mode=Animation.LOOP_LINEAR
	bindings=form.get("sockets",{})
	surfaces=model.find_children("*","MeshInstance3D",true,false)
	hit_material=StandardMaterial3D.new();hit_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;hit_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;hit_material.albedo_color=Color(1,.89,.72,.20)
	play("idle_loop",0)

func play(name: String,blend: float=.16) -> void:
	if clip==name:return
	clip=name;player.play(name,blend)

func advance(delta: float) -> void:
	player.advance(delta)
	if hit_flash>0:
		hit_flash=maxf(0,hit_flash-delta)
		if hit_flash<=0:
			for surface in surfaces:surface.material_overlay=null

func flash_hit(blocked: bool) -> void:
	hit_flash=.10;hit_material.albedo_color=Color(.40,.95,1,.25) if blocked else Color(1,.89,.72,.25)
	for surface in surfaces:surface.material_overlay=hit_material
func restart(name: String) -> void:clip="";play(name,0);player.advance(0)
func clock() -> float:return player.current_animation_position

func advance_locomotion(delta: float,speed: float) -> void:
	var walk: Dictionary=form.motion_profile
	var walk_speed: float=float(walk.stride)/float(walk.stance)/float(walk.period)
	# Hysteresis prevents repeated gait switches near the threshold.
	if locomotion_gait=="move_loop" and speed>walk_speed*1.45:locomotion_gait="run_loop"
	elif locomotion_gait=="run_loop" and speed<walk_speed*1.18:locomotion_gait="move_loop"
	var gait: Dictionary=walk.run if locomotion_gait=="run_loop" else walk
	var period: float=gait.period
	var natural_speed: float=float(gait.stride)/float(gait.stance)/period
	if clip!=locomotion_gait:
		play(locomotion_gait,.18)
		player.seek(fposmod(locomotion_phase,2.0)*period,true)
	var rate: float=maxf(0,speed)/natural_speed
	locomotion_phase=fposmod(locomotion_phase+delta*rate/period,2.0)
	advance(delta*rate)

func contact_point(name: String) -> Vector3:
	if bindings.has(name):
		var row: Dictionary=bindings[name];var index:=skeleton.find_bone(row.bone)
		var p: Array=row.point;var rest:=Vector3(p[0],p[1],p[2])
		return skeleton.global_transform*(skeleton.get_bone_global_pose(index)*skeleton.get_bone_global_rest(index).affine_inverse()*rest)
	var node: Node3D=model.find_child(name,true,false)
	assert(node!=null,"Missing contact socket "+name)
	return node.global_position

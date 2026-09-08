class_name FrontierResearchPreview
extends FrontierEquipmentPreview
## Existing Blender bench/specimens plus the articulated, deliberately open T2 probe.
var specimen: Node3D
var specimen_id: String=""
var shown_stage: String=""
var phase: String="ready"
var elapsed:=0.0
var part_origins: Dictionary={}
var separation:=1.0
func present(research_stage: String,resource: String) -> void:
	var path: String="equipment/miner_probe" if research_stage in ["analyzed","prototyped"] else "crew/research_station"
	if model_path!=path:
		specimen=null;specimen_id="";part_origins.clear();show_model(path)
		if path=="crew/research_station":camera.position.z=absf(camera.position.z);camera.look_at(Vector3.ZERO)
		else:camera.size*=.83
		for part in model.find_children("Anim_*","Node3D",true,false):part_origins[part]=part.transform
	shown_stage=research_stage
	if phase!="success":separation=0.0 if shown_stage=="prototyped" else 1.0
	if specimen_id==resource:return
	specimen_id=resource
	if is_instance_valid(specimen):specimen.queue_free();specimen=null
	var socket: Node3D=model.find_child("Socket_Specimen",true,false)
	if resource.is_empty() or socket==null:return
	specimen=load(FrontierMinerals.entry(resource).model).instantiate();socket.add_child(specimen);FrontierInkStyle.apply(specimen,{})
	var bounds:=AABB();var first:=true
	for mesh in specimen.find_children("*","MeshInstance3D",true,false):
		var box: AABB=specimen.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
	var factor:=.30/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z));specimen.scale=Vector3.ONE*factor;specimen.position=Vector3.UP*.10-bounds.get_center()*factor
func _process(delta: float) -> void:
	super._process(delta)
	if not is_visible_in_tree():return
	elapsed+=delta
	separation=move_toward(separation,0.0 if shown_stage=="prototyped" else 1.0,delta*1.7)
	var moving: bool=phase in ["prepared","waiting","success"]
	for part in part_origins:
		part.transform=part_origins[part]
		if part.name=="Anim_SpecimenTurntable":part.rotate_y(elapsed*(1.8 if moving else .18))
		elif part.name=="Anim_OpticalArm" and moving:part.rotate_x(.10*sin(elapsed*5))
		elif part.name=="Anim_Collar_Probe":
			part.position.z-=.30*separation
			if phase=="success":part.rotate_z(.025*sin(elapsed*12))
		elif part.name=="Anim_PrototypeShield":part.position.x+=.22*separation
	if is_instance_valid(specimen):specimen.rotation.y=elapsed*(1.8 if moving else .18)

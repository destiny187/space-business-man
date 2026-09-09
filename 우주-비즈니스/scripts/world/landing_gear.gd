class_name FrontierLandingGear
extends Node
## Drives Blender pivots without changing collision or landing authority.
var nodes: Array[Node3D]=[]
var root_model: Node3D
var deployment:=1.0
var hatch:=1.0
var compression:=0.0
func configure(root: Node3D) -> void:
	root_model=root;refresh()
func refresh() -> void:
	nodes.clear()
	for node in root_model.find_children("Anim_*","Node3D",true,false):
		if str(node.name).begins_with("Anim_LandingLeg_") or str(node.name).begins_with("Anim_Strut_") or str(node.name).begins_with("Anim_Leg_") or node.name in ["Anim_Hatch","Anim_Ramp","Anim_Canopy"]:
			if not node.has_meta("landing_rest"):node.set_meta("landing_rest",node.transform)
			nodes.append(node)
func present(delta: float,flight: bool,override: Dictionary) -> void:
	var blend:=minf(1,delta*7)
	deployment=lerpf(deployment,float(override.get("deployment",0.0 if flight else 1.0)),blend)
	hatch=lerpf(hatch,float(override.get("hatch",0.0 if flight else 1.0)),blend)
	compression=float(override.get("compression",0.0))
	for node in nodes:
		if not is_instance_valid(node):continue
		node.transform=node.get_meta("landing_rest")
		var name: String=str(node.name)
		if name.begins_with("Anim_LandingLeg_"):
			var side: float=-1 if name.contains("_-1_") else 1
			node.rotation.z+=side*(1-deployment)*1.2
		elif name.begins_with("Anim_Strut_"):node.position.y+=compression
		elif name.begins_with("Anim_Leg_"):node.rotation.x+=(1-deployment)*1.1;node.position.y+=compression
		elif name=="Anim_Hatch":node.position.y+=hatch*1.95
		elif name=="Anim_Ramp":node.scale.z=maxf(.01,hatch);node.rotation.x+=asin(1.5/4.0)*hatch;node.visible=hatch>.015
		elif name=="Anim_Canopy":node.rotation.x+=hatch*.9

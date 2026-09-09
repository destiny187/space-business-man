class_name FrontierSuitAppearance
extends RefCounted
## Cosmetic layers are derived from host-confirmed paid ranks. No additional save migration.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/suit_appearance.json"))
	return _config
static func stages(member: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for branch in config().branches:
		var invested:=0
		for key in config().branches[branch]:invested+=FrontierCrewAugmentation.level(member,key)
		var stage:=0
		for threshold in config().thresholds:
			if invested>=int(threshold):stage+=1
		result[branch]=stage
	return result
var model: Node3D
var layers: Dictionary={}
var paints: Dictionary={}
var defaults: Dictionary={}
var overrides: Dictionary={}
var last_state: Array=[]
var current_stages: Dictionary={}
func configure(value: Node3D) -> void:
	model=value;layers.clear();paints.clear();defaults.clear();last_state=[]
	for node in model.find_children("*","MeshInstance3D",true,false):
		var key:=str(node.name)
		if key.begins_with("Aug_"):
			var fields:=key.split("_")
			if fields.size()>=3 and config().branches.has(fields[1]):layers[node]={"branch":fields[1],"stage":int(fields[2])};node.visible=false
		for i in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(i)
			if not material is ShaderMaterial or not material.resource_name.begins_with("DYE::"):continue
			var name_value:=material.resource_name
			if not paints.has(name_value):
				paints[name_value]=material.duplicate();defaults[name_value]=material.get_shader_parameter("base_color")
			node.set_surface_override_material(i,paints[name_value])
func sync(member: Dictionary) -> bool:
	var next:=stages(member)
	var tint:=clampi(int(member.get("profile",{}).get("tint",0)),0,config().legacy_tints.size()-1)
	var saved: Dictionary=member.get("suit_dyes",{})
	var state: Array=[next,tint,saved.duplicate(true),overrides.duplicate(true)]
	if state==last_state:return false
	last_state=state;current_stages=next
	for node in layers:node.visible=next[layers[node].branch]>=layers[node].stage
	for key in paints:
		var fields: PackedStringArray=key.split("::")
		var color: Color=Color(config().legacy_tints[tint]) if fields[2]=="secondary" else defaults[key]
		if saved.get(fields[1],{}).has(fields[2]):color=Color(saved[fields[1]][fields[2]])
		paints[key].set_shader_parameter("base_color",overrides.get(fields[1],{}).get(fields[2],color))
	return true
# Local preview overrides. Confirmed colors come from the host member suit_dyes.
func set_dye(part: String,channel: String,color: Color) -> bool:
	if not config().parts.has(part) or channel not in config().channels or not (is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)):return false
	if not overrides.has(part):overrides[part]={}
	overrides[part][channel]=Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1)
	last_state=[];return true
func clear_dyes() -> void:
	overrides.clear();last_state=[]

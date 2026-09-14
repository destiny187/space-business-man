class_name FrontierAudioMix
extends Node
## One local mixer. User gains and transient warning ducking never overwrite each other.
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/play_presentation.json")).audio
var effects_gain:=1.0
var ambience_gain:=1.0
var hold:=0.0
var duck:=0.0
var applied: Dictionary={}
static func ensure(tree: SceneTree) -> FrontierAudioMix:
	var existing:=tree.root.get_node_or_null("AudioMix") as FrontierAudioMix
	if existing!=null:return existing
	var node:=FrontierAudioMix.new();node.name="AudioMix";tree.root.add_child(node);return node
func _ready() -> void:
	for name_value in ["SFX","Ambience","UI","Voice","Music","Industry"]:
		if AudioServer.get_bus_index(name_value)<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,name_value)
	for child in ["UI","Voice","Industry"]:AudioServer.set_bus_send(AudioServer.get_bus_index(child),"SFX")
	var settings:=FrontierClientSettings.current(get_tree())
	if settings!=null:apply_volumes(settings.values)
func apply_volumes(values: Dictionary) -> void:
	effects_gain=float(values.get("sfx_volume",1));ambience_gain=float(values.get("ambient_volume",1));_apply()
func warning() -> void:
	hold=float(config.warning_hold_seconds);duck=1.0;_apply()
func _process(delta: float) -> void:
	hold=maxf(0,hold-delta)
	if hold<=0 and duck>0:duck=move_toward(duck,0,delta*float(config.warning_release_db_per_second)/absf(float(config.industrial_duck_db)));_apply()
func _apply() -> void:
	var gains: Dictionary={"SFX":linear_to_db(maxf(.0001,effects_gain)),"Ambience":linear_to_db(maxf(.0001,ambience_gain))+float(config.ambience_duck_db)*duck,"Industry":float(config.industrial_duck_db)*duck}
	for bus in gains:
		if applied.get(bus,INF)==gains[bus]:continue
		var index:=AudioServer.get_bus_index(bus)
		if index<0:continue
		AudioServer.set_bus_volume_db(index,gains[bus]);AudioServer.set_bus_mute(index,(bus=="SFX" and effects_gain<=0) or (bus=="Ambience" and ambience_gain<=0));applied[bus]=gains[bus]

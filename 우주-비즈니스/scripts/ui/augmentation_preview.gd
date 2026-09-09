class_name FrontierAugmentationPreview
extends FrontierEquipmentPreview
## Existing Blender suit and scanner; only diagnostic VFX are procedural.
var station: FrontierCrewStation
var character: Node3D
var pose: FrontierCrewPose
var gem: Node3D
var effects: FrontierEffects
var field: String="mobility"
var phase: String="ready"
var elapsed:=0.0
var gem_id: String=""
func _ready() -> void:
	super._ready()
	tooltip_text=""
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	station=FrontierCrewStation.new();stage.add_child(station)
	station.configure("augmentation",JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_stations.json")).stations.augmentation)
	character=load("res://assets/models/crew/surveyor_suit.glb").instantiate();stage.add_child(character);FrontierInkStyle.apply(character,{})
	character.position=Vector3(0,.39,.04);character.rotation.y=PI
	pose=FrontierCrewPose.new();stage.add_child(pose);pose.configure(character)
	effects=FrontierEffects.new();stage.add_child(effects)
	camera.size=3.25;camera.position=Vector3(3.1,2.8,7);camera.look_at(Vector3(.12,1.30,0))
func body_point(key: String) -> Vector2:
	var at: Vector3={"mobility":Vector3(.15,.98,.12),"combat":Vector3(.40,1.67,.08),"vitality":Vector3(0,1.68,.16)}[key]
	return camera.unproject_position(at)*size/Vector2(viewport.size)
func load_gem(id: String) -> void:
	station.load_gem(id);gem_id=id;gem=station.gem
func change_phase(value: String) -> void:
	phase=value;elapsed=0
	if value=="success":effects.burst(Vector3(0,1.5,.5),FrontierInterfaceStyle.ACCENT,18)
	elif value=="error":effects.burst(Vector3(.95,1.16,.35),FrontierInterfaceStyle.WARNING,6)
func _gui_input(_event: InputEvent) -> void:pass
func _process(delta: float) -> void:
	continuous_rendering=true
	super._process(delta)
	if not is_visible_in_tree():return
	elapsed+=delta
	station.present(delta,phase in ["prepared","waiting","success"])
	var motion:=FrontierCrewLocomotion.create();motion.yaw=PI;motion.grounded=true
	if field=="mobility" and phase=="success":motion.state="walk";motion.velocity=[0,0,2];motion.phase=elapsed*7
	pose.animate(motion,delta,false,false)
	if field=="combat" and phase in ["prepared","success"]:pose._rotate("upper_arm_R",Vector3(-.55,0,-.12),.3)
	if phase=="waiting":station.scan.position.y=1.4+.42*sin(elapsed*5)
	if gem!=null:gem.rotation.y+=delta*.7

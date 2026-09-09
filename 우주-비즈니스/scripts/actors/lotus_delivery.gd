class_name FrontierLotusDelivery
extends Node3D
## Only presentation is interpolated. Cargo availability always uses the host's landed flag.
var carrier: Node3D
var crate: Node3D
var collider: StaticBody3D
var lid: Node3D
var label: Label3D
var engine: AudioStreamPlayer3D
var impact: AudioStreamPlayer3D
var audio: FrontierAudio
var rotors: Array[Node3D]=[]
var clamps: Array[Node3D]=[]
var jets: Array[MeshInstance3D]=[]
var row: Dictionary={}
var display_elapsed:=0.0
var received_elapsed:=-1.0
var opened:=false
var land_seen:=false
var initialized:=false
var blocked:=true
func _ready() -> void:
	carrier=load(FrontierLotusSupport.config().ship_model).instantiate();add_child(carrier);FrontierInkStyle.apply(carrier,{})
	crate=load(FrontierLotusSupport.config().crate_model).instantiate();add_child(crate);FrontierInkStyle.apply(crate,{})
	lid=crate.find_child("Anim_Lid",true,false)
	for node in carrier.find_children("Anim_Rotor*","Node3D",true,false):rotors.append(node)
	for node in carrier.find_children("Anim_Clamp*","Node3D",true,false):clamps.append(node)
	for socket in carrier.find_children("Socket_Thrust*","Node3D",true,false):
		var jet:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=.34;cone.bottom_radius=.08;cone.height=1.2;cone.radial_segments=16;jet.mesh=cone;socket.add_child(jet);jet.position.y=-.65
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(.38,.86,.78,.25);jet.material_override=mat;jet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;jets.append(jet)
	collider=make_collision(self);collider.name="LotusCrateCollision"
	label=Label3D.new();label.font=FrontierInterfaceStyle.theme().default_font;label.font_size=42;label.pixel_size=.006;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.outline_size=8;add_child(label)
	audio=FrontierAudio.new();add_child(audio)
	engine=AudioStreamPlayer3D.new();engine.stream=audio.stream("sfx_lotus_carrier",true);engine.bus="SFX";engine.unit_size=18;engine.max_distance=200;engine.volume_db=-17;add_child(engine)
	impact=AudioStreamPlayer3D.new();impact.stream=audio.stream("sfx_lotus_touchdown");impact.bus="SFX";impact.unit_size=8;impact.max_distance=85;impact.volume_db=-9;add_child(impact)
static func make_collision(parent: Node3D) -> StaticBody3D:
	var body:=StaticBody3D.new();parent.add_child(body);body.set_meta("lotus_crate",true)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.9,1.45,1.6);shape.shape=box;shape.position.y=.73;body.add_child(shape)
	return body
func accept(value: Dictionary) -> void:
	if not initialized:opened=int(value.remaining)<int(FrontierLotusSupport.config().package_amount)
	if not is_equal_approx(received_elapsed,float(value.elapsed)):
		display_elapsed=float(value.elapsed);received_elapsed=float(value.elapsed)
	if initialized and not land_seen and value.landed and not blocked:
		impact.position=FrontierCrewWorld.vector(value.position);impact.play()
	if initialized and int(value.remaining)<int(row.get("remaining",value.remaining)):
		opened=true
		if not blocked:audio.play("sfx_lotus_open",FrontierCrewWorld.vector(value.position))
	land_seen=value.landed;initialized=true;row=value.duplicate(true)
func present(delta: float,paused: bool,viewer: Vector3) -> void:
	blocked=paused
	if row.is_empty():return
	if not paused and not row.get("blocked",false):display_elapsed=minf(display_elapsed+delta,received_elapsed+1.0)
	var cfg:=FrontierLotusSupport.config()
	var age:=display_elapsed
	var p:=FrontierCrewWorld.vector(row.position)
	var heading: float=row.heading
	var forward:=Vector3(sin(heading),0,cos(heading))
	var approach:=clampf((age-float(cfg.dispatch_seconds))/float(cfg.approach_seconds),0,1)
	var descent:=clampf((age-float(cfg.dispatch_seconds+cfg.approach_seconds))/float(cfg.drop_seconds),0,1)
	var departure:=clampf((age-FrontierLotusSupport.touchdown())/float(cfg.departure_seconds),0,1)
	var hover:=p+Vector3.UP*6.0
	carrier.position=(hover-forward*95+Vector3.UP*42).lerp(hover,smoothstep(0,1,approach))
	if row.landed:carrier.position=hover.lerp(hover+forward*120+Vector3.UP*65,smoothstep(0,1,departure))
	carrier.rotation.y=heading+PI
	carrier.rotation.z=sin(approach*PI)*.08*(1-departure)
	carrier.visible=age>=float(cfg.dispatch_seconds) and age<FrontierLotusSupport.duration() and not row.get("blocked",false)
	crate.position=p if row.landed else carrier.position+Vector3.UP*.18
	if age>=float(cfg.dispatch_seconds+cfg.approach_seconds) and not row.landed:crate.position=hover.lerp(p,descent*descent)
	crate.rotation.y=heading+PI
	crate.visible=row.landed or carrier.visible
	collider.position=p;collider.rotation.y=crate.rotation.y
	collider.collision_layer=1 if row.landed else 0
	label.position=p+Vector3.UP*2.2
	label.text="LOTUS  "+FrontierCatalog.entry("resources",row.resource).name+"  "+str(int(row.remaining))
	label.visible=bool(row.landed) and viewer.distance_to(p)<30
	if lid!=null:lid.rotation.x=move_toward(lid.rotation.x,-1.0 if opened or int(row.remaining)==0 else 0.0,delta*2.5)
	for i in clamps.size():clamps[i].rotation.z=(.35 if i%2==0 else -.35)*descent
	if carrier.visible and not paused:
		for rotor in rotors:rotor.rotate_y(delta*24)
		for jet in jets:jet.scale.y=.9+.12*sin(float(Time.get_ticks_msec())*.025)
	engine.position=carrier.position;engine.stream_paused=paused
	impact.stream_paused=paused
	if carrier.visible and not paused:
		if not engine.playing:engine.play()
	else:engine.stop()
func _exit_tree() -> void:
	for player in [engine,impact]:
		if is_instance_valid(player):player.stop();player.stream=null

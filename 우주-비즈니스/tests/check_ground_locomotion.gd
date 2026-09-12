extends SceneTree
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var checks:=0
var failures:=0
var stage: Node3D
var camera: Camera3D
var creature: Node3D
class CaveProbe extends FrontierTerrainField:
	func height(_x: float,_z: float) -> float:return 20.0
	func density_at_height(at: Vector3,_height: float) -> float:return absf(at.y+2)-2
	func normal(_at: Vector3,_epsilon: float=.35) -> Vector3:return Vector3.UP

var folder:="/tmp/ground-locomotion"
var render:=false
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
	else:print("PASS ",label)
func sample(at: Vector3,_reach: float) -> Dictionary:
	return {"point":Vector3(at.x,at.x*.12,at.z),"normal":Vector3(-.12,1,0).normalized()}
func setup() -> void:
	stage=Node3D.new();root.add_child(stage);current_scene=stage
	var env:=WorldEnvironment.new();var settings:=Environment.new();env.environment=settings
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("c7d8dd");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("b2c6d2");settings.ambient_light_energy=.5
	stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.shadow_enabled=true;stage.add_child(light)
	var floor:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(200,200);floor.mesh=mesh;floor.rotation.z=atan(.12)
	var material:=StandardMaterial3D.new();material.albedo_color=Color("b5b59e");material.roughness=1;floor.material_override=Actor.Ink.material(material,{});stage.add_child(floor)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.5;stage.add_child(camera);camera.current=true
	Actor.Ink.attach(stage);root.size=Vector2i(1280,800);root.content_scale_size=root.size
func bind_soles() -> Array:
	var result: Array=[]
	var skeleton: Skeleton3D=creature.anatomical_skeletons[0]
	if skeleton==null:return result
	for part in creature.joints[0].values():part.node.transform=part.rest
	skeleton.reset_bone_poses();skeleton.force_update_all_bone_transforms()
	for limb in creature.ground_motion.limbs:
		var marker: String=creature.ground_motion.chains[limb.hip].ankle if creature.ground_motion.chains.has(limb.hip) else limb.hip
		var bone:=skeleton.find_bone(creature.definition.rig.hinges[marker])
		var rest_world: Vector3=creature.models[0].to_global(Actor.GroundMotion.v(limb.rest))
		var local: Vector3=skeleton.get_bone_global_pose(bone).affine_inverse()*skeleton.to_local(rest_world)
		result.append({"bone":bone,"point":local})
	return result
func run_case(id: String,speed_value: float,scale_value: float=1.0) -> Dictionary:
	if creature!=null:creature.free()
	creature=Actor.new();creature.load_far=true;stage.add_child(creature)
	creature.configure(FrontierEcologyCatalog.form(id),{"scale":scale_value});creature.set_process(false);creature.set_state("move")
	var soles:=bind_soles();var motion: RefCounted=creature.ground_motion
	var detail: Dictionary={}
	var maximum_error:=0.0;var drift:=0.0;var body_step:=0.0;var last_phase:=0.0;var contacts: Dictionary={};var footfalls:=0
	var normal: Vector3=sample(Vector3.ZERO,0).normal
	for i in 180:
		var elapsed:=i/60.0
		var at:=Vector3(.25,0,elapsed*speed_value);at.y=.25*.12
		var facing:=Basis(Vector3.UP,0)
		facing=FrontierEcologyPlacement.surface_basis(normal,0)
		creature.drive_ground(at,facing,1.0/60,sample,false);creature.pose()
		for j in motion.contacts.size():
			var c: Dictionary=motion.contacts[j]
			if not c.ready:continue
			var actual: Vector3=c.position
			if not soles.is_empty():
				var skeleton: Skeleton3D=creature.anatomical_skeletons[0]
				actual=skeleton.to_global(skeleton.get_bone_global_pose(soles[j].bone)*soles[j].point)
			else:
				var limb: Dictionary=motion.limbs[j]
				actual=creature.joints[0][limb.hip].node.to_global(Actor.GroundMotion.v(limb.tip))
			if actual.distance_to(c.position)>maximum_error:
				detail={"frame":i,"foot":j,"swing":c.swing,"actual":str(actual),"target":str(c.position),"marker_error":c.get("error",0),"rest":str(motion.Feet.rest_point(motion,j)),"duration":c.get("duration",0)}
			maximum_error=maxf(maximum_error,actual.distance_to(c.position))
			if not c.swing and contacts.has(j) and not contacts[j].swing:
				drift=maxf(drift,Vector2(actual.x-contacts[j].actual.x,actual.z-contacts[j].actual.z).length())
			contacts[j]={"swing":c.swing,"actual":actual}
		if motion.take_footfall().is_finite():footfalls+=1
		last_phase=motion.phase
		if render and i in [30,60,90,120]:
			var bounds: Dictionary=creature.definition.geometry.near
			var height: float=float(bounds.max[1])-float(bounds.floor_y)
			var aim: Vector3=motion.point+Vector3.UP*scale_value*height*.5
			camera.global_position=aim+Vector3(4,1.8,3.6)*scale_value;camera.size=maxf(height*1.5,maxf(3.8,motion.body_length*1.4))*scale_value;camera.look_at(aim)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+id+"-"+str(int(speed_value*10))+"-"+str(i)+".png")
	var ending: Vector3=creature.global_position
	creature.set_state("idle")
	for i in 45:creature.drive_ground(ending,creature.global_basis,1.0/60,sample,false);creature.pose()
	var airborne:=0
	for c in motion.contacts:
		if c.swing:airborne+=1
	if airborne>0 or motion.intensity>=.01:print("STOP_DEBUG ",id," intensity ",motion.intensity," speed ",motion.speed," feet ",motion.contacts)
	if maximum_error>.1*scale_value:print("CONTACT_DEBUG ",id," ",detail)
	check(airborne==0 and motion.intensity<.01,id+" settles lifted feet on stopping")
	var paused_phase: float=motion.phase;var paused_point: Vector3=motion.point
	creature.drive_ground(ending,creature.global_basis,.1,sample,true);creature.paused=true;creature._process(.1)
	check(motion.phase==paused_phase and motion.point==paused_point,id+" pause freezes gait and visual origin")
	check(maximum_error<.22*scale_value,id+" actual skin or rigid sole remains near its contact "+str(snappedf(maximum_error,.001)))
	check(drift<.09*scale_value,id+" planted sole avoids framewise sliding "+str(snappedf(drift,.001)))
	if not motion.limbs.is_empty():check(footfalls>0,id+" footfall follows contact")
	return {"id":id,"kind":motion.kind,"speed":speed_value,"scale":scale_value,"maximum_contact_error":maximum_error,"planted_frame_drift":drift,"phase":last_phase,"footfalls":footfalls,"worst_contact":detail}
func run() -> void:
	render="--render" in OS.get_cmdline_user_args();DirAccess.make_dir_recursive_absolute(folder);setup()
	var report: Array=[]
	for item in [["biota_saddle_sails_26",.65,1.0],["biota_saddle_sails_26",4.0,1.0],["biota_saddle_sails_26",17.4,1.0],["bio_grazer_01",.65,1.0],["bio_runner_01",2.0,1.0],["biota_branch_armor_26",.65,1.0],["biota_radial_armor_01",.65,1.0],["biota_chain_armor_25",1.0,1.0],["biota_ribbon_armor_26",.65,1.0],["biota_chain_armor_01",.65,1.0],["biota_spindle_armor_01",2.6,4.0],["bio_accordion_shell_01",.65,1.0],["bio_knuckle_chain_01",.65,1.0],["bio_petal_mantis_01",.65,1.0],["bio_corkscrew_spine_01",.65,1.0],["bio_window_sac_01",.65,1.0]]:
		report.append(await run_case(item[0],item[1],item[2]))
	check(float(report[1].phase)>float(report[0].phase),"faster travel advances the same creature gait faster")
	check_motion_edges()
	var selected:=0;var missing: Array=[]
	for form in FrontierEcologyCatalog.all_forms():
		if form.category=="animal" and FrontierEcologyCatalog.ground_form(form) and form.get("locomotion_medium","") not in ["surface_air","atmosphere"]:
			selected+=1
			if not Actor.GroundMotion.catalogue.has(form.id):missing.append(form.id)
	check(missing.is_empty() and selected==Actor.GroundMotion.catalogue.size(),"all current ground forms have source-derived locomotion contacts: "+str(selected))
	var output:=FileAccess.open(folder+"/verification.json",FileAccess.WRITE);output.store_string(JSON.stringify({"cases":report,"coverage":selected,"checks":checks,"failures":failures},"\t"));output.close()
	print("GROUND_LOCOMOTION ",checks," FAILURES ",failures)
	quit(1 if failures else 0)

func check_motion_edges() -> void:
	creature.free();creature=Actor.new();stage.add_child(creature)
	creature.configure(FrontierEcologyCatalog.form("biota_saddle_sails_26"));creature.set_process(false);creature.set_state("move")
	var m: RefCounted=creature.ground_motion
	creature.drive_ground(Vector3.ZERO,Basis.IDENTITY,.016,sample,false);creature.pose()
	var old: Basis=m.frame
	creature.drive_ground(Vector3.ZERO,Basis(Vector3.UP,PI),.016,sample,false);creature.pose()
	var turned:=old.get_rotation_quaternion().angle_to(m.frame.get_rotation_quaternion())
	check(turned>0 and turned<=float(m.config().turn_radians_per_second)*.016+.001,"direction reversal respects visual turn speed")
	var maximum_gap:=0.0;var maximum_slip:=0.0
	for i in 90:
		var at:=Vector3(0,0,floorf(i/6.0)*.4)
		creature.drive_ground(at,Basis.IDENTITY,1.0/60,sample,false);creature.pose()
		maximum_gap=maxf(maximum_gap,creature.global_position.distance_to(m.point))
		if i==89:check(creature.global_position==at,"snapshot root stays authoritative")
		for c in m.contacts:
			if c.ready and not c.swing:maximum_slip=maxf(maximum_slip,float(c.get("error",0)))
	check(maximum_gap<=float(m.config().maximum_visual_offset)+.001,"snapshot smoothing keeps a bounded visual offset")
	check(maximum_slip<.25,"host snapshot cadence does not stretch planted feet excessively")
	var a: float=m.phase
	creature.lod_override=1;creature.set_lod(true);creature.pose(true)
	check(m.phase==a and creature.models[1].visible,"LOD switch shares the existing stride phase")
	creature.drive_ground(Vector3(90,10.8,0),Basis.IDENTITY,.016,sample,false);creature.pose()
	check(m.point.distance_to(Vector3(90,10.8,0))<.001 and m.contacts.all(func(c):return c.position.distance_to(Vector3(90,10.8,0))<3),"relocation rebinds feet without stretching across the world")
	var hit: Dictionary=Actor.GroundMotion.sample(CaveProbe.new(),Vector3(2,-4,3),.7)
	check(absf(float(hit.point.y)+4)<.02,"foot probe keeps the nearby cave floor instead of the surface above")

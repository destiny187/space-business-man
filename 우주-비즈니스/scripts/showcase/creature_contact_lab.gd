extends SceneTree
## Actual swept contacts, health/shield outcomes and rig reactions in an isolated arena.
const Body=preload("res://scripts/actors/creatures/study_motion_actor.gd")
const Contacts=preload("res://scripts/domain/creature_study_contact.gd")
const Impacts=preload("res://scripts/actors/creatures/study_impact_effects.gd")
const Ink=preload("res://scripts/actors/ink_style.gd")
var stage: Node3D
var camera: Camera3D
var actor: Node3D
var defender: Node3D
var fx: Node3D
var shield: MeshInstance3D
var current: Dictionary
var profile: Dictionary
var forms: Array=[]
var title: Label
var caption: Label
var health_bar: ColorRect
var shield_bar: ColorRect
var folder: String
var projectiles: Array=[]
var ledger: Dictionary={}
var state: Dictionary={}
var last_points: Dictionary={}
var attack_time:=0.0
var hit_hold:=0.0
var aim:=Vector3.ZERO
var locked:=false
var outcome: String="hit"
var target_base:=Vector3.ZERO
var push:=0.0
var push_speed:=0.0
var hurt_time:=-1.0
var events: Array=[]
var summaries: Array=[]
var camera_base:=Vector3.ZERO
var shake:=0.0
var started:=false
var speed_review:=false
var movement_records: Array=[]

func _initialize() -> void:call_deferred("run")

func make_stage() -> void:
	stage=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env;env.background_mode=Environment.BG_COLOR;env.background_color=Color("ced7d0")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("bdccce");env.ambient_light_energy=.52;stage.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.shadow_enabled=true;sun.shadow_bias=.01;sun.shadow_normal_bias=.03;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;sun.directional_shadow_max_distance=24;stage.add_child(sun)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(100,100);floor.mesh=plane;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("bbc6b7");floor.material_override=Ink.material(mat,{});floor.position.y=-.02;stage.add_child(floor)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05;camera.far=30;camera.current=true;stage.add_child(camera)
	var listener:=AudioListener3D.new();camera.add_child(listener);listener.make_current()
	fx=Impacts.new();fx.camera=camera;stage.add_child(fx);Ink.attach(stage,true)
	shield=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=48;sphere.rings=24;shield.mesh=sphere
	var membrane:=StandardMaterial3D.new();membrane.albedo_color=Color(.22,.77,.81,.11);membrane.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;membrane.roughness=.32;membrane.emission_enabled=true;membrane.emission=Color(.06,.20,.22);shield.material_override=membrane;shield.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;stage.add_child(shield)
	var font:=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf");font.variation_embolden=.5
	title=Label.new();title.position=Vector2(32,22);title.add_theme_font_override("font",font);title.add_theme_font_size_override("font_size",30);title.add_theme_color_override("font_color",Color("203a36"));root.add_child(title)
	caption=Label.new();caption.position=Vector2(34,68);caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",20);caption.add_theme_color_override("font_color",Color("37574d"));root.add_child(caption)
	var backing:=ColorRect.new();backing.color=Color("82968b");backing.position=Vector2(1110,38);backing.size=Vector2(130,12);root.add_child(backing)
	health_bar=ColorRect.new();health_bar.color=Color("476f5a");health_bar.position=backing.position;health_bar.size=backing.size;root.add_child(health_bar)
	shield_bar=ColorRect.new();shield_bar.color=Color("55aaaf");shield_bar.position=Vector2(1110,56);shield_bar.size=Vector2(130,6);root.add_child(shield_bar)

func load_type(form: Dictionary) -> void:
	if is_instance_valid(actor):actor.free();defender.free()
	current=form;profile=form.motion_profile
	actor=Body.new();stage.add_child(actor);actor.load_form(form)
	defender=Body.new();stage.add_child(defender);defender.load_form(forms[0]);defender.scale=Vector3.ONE*.82;defender.rotation.y=PI*.5
	target_base=Vector3(0,0,float(profile.target_z))
	var center:=Vector3(0,1.2,(float(profile.target_z)-1.3)*.5)
	camera.size=6.0 if form.kind!="glider" else 6.3;camera.position=center+Vector3(8,4.4,-3.3);camera.look_at(center);camera_base=camera.position
	title.text=form.name+"  /  움직임과 타격"
	reset_case("hit")

func reset_case(mode: String) -> void:
	outcome=mode;attack_time=0;hit_hold=0;locked=false;ledger.clear();last_points.clear();push=0;push_speed=0;hurt_time=-1;started=false
	for p in projectiles:p.node.free()
	projectiles.clear();fx.clear();state={"health":100.0,"shield":120.0 if mode=="shield" else 0.0}
	actor.position=Vector3.ZERO;actor.rotation.y=0;actor.restart("idle_loop")
	defender.position=target_base;defender.restart("idle_loop");shield.visible=mode=="shield"
	caption.text={"hit":"명중 — 접촉 위치 · 피격 반응 · 반동과 회복","shield":"방어 — 실드 접촉과 튕김","miss":"회피 — 방향 확정 후 피하기 · 빗나간 공격 회복"}[mode]

func targets() -> Array:
	return [{"id":"defender","center":defender.position+Vector3.UP*1.13,"radii":Vector3(.94,.69,.51)+(Vector3.ONE*.13 if state.shield>0 else Vector3.ZERO),"shield":state.shield>0}]

func accept(event: Dictionary,key: String) -> void:
	var result: Dictionary=Contacts.apply_once(event,ledger,state,key,float(profile.damage))
	if result.is_empty():return
	fx.impact(result,str(profile.effect),1.2 if profile.effect in ["ram","slam"] else 1.0)
	events.append({"form":current.id,"case":outcome,"time":attack_time,"stroke":key,"kind":result.kind,"damage":result.damage,"absorbed":result.absorbed,"point":[result.point.x,result.point.y,result.point.z],"contact_distance_from_body":actor.global_position.distance_to(result.point)})
	if result.kind in ["organic","shield"]:
		defender.flash_hit(result.kind=="shield")
		hurt_time=0;defender.restart("blocked" if result.kind=="shield" else "hurt")
		push_speed+=float(profile.knockback)*5.0*(.35 if result.kind=="shield" else 1.0)
		hit_hold=maxf(hit_hold,float(profile.hit_pause));shake=.018 if profile.effect in ["ram","slam","mortar"] else .007

func spawn_projectile(index: int) -> void:
	var origin: Vector3=actor.contact_point("Socket_Muzzle")
	var duration: float=profile.flight_seconds;var gravity: float=8.0*float(profile.arc_height)/(duration*duration)
	var velocity: Vector3=(aim-origin)/duration+Vector3.UP*gravity*duration*.5
	var node:=MeshInstance3D.new()
	if profile.effect=="dart":
		var dart:=CylinderMesh.new();dart.top_radius=0;dart.bottom_radius=.045;dart.height=.30;dart.radial_segments=7;node.mesh=dart
	else:
		var blob:=SphereMesh.new();blob.radius=float(profile.strike_radius);blob.height=blob.radius*2;blob.radial_segments=16;blob.rings=8;node.mesh=blob
	node.material_override=fx.mat(Color("b4ba72") if profile.effect=="acid" else Color("bd955f"));stage.add_child(node);node.position=origin
	projectiles.append({"node":node,"origin":origin,"velocity":velocity,"gravity":gravity,"age":0.0,"previous":origin,"key":"projectile_"+str(index)})
	fx.launch(origin,str(profile.effect))

func step_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p: Dictionary=projectiles[i];p.age+=delta
		var at: Vector3=p.origin+p.velocity*p.age+Vector3.DOWN*.5*p.gravity*p.age*p.age
		var event:=Contacts.sweep(p.previous,at,float(profile.strike_radius),targets())
		if not event.is_empty():accept(event,p.key);p.node.free();projectiles.remove_at(i);continue
		p.node.position=at
		if profile.effect=="dart":p.node.quaternion=Quaternion(Vector3.UP,(at-p.previous).normalized())
		fx.trail(p.previous,at,Color("c7ca90") if profile.effect=="acid" else Color("d5b879"),.014)
		p.previous=at
		if p.age>3:p.node.free();projectiles.remove_at(i)

func update_defender(delta: float) -> void:
	push_speed*=exp(-7*delta);push+=push_speed*delta
	var dodge:=0.0
	if outcome=="miss":dodge=2.1*smoothstep(float(profile.prepare)+.025,float(profile.prepare)+.28,attack_time)
	defender.position=target_base+Vector3(dodge,0,push)
	if outcome=="miss" and dodge>.01 and dodge<2.09 and hurt_time<0:defender.play("move_loop",.12)
	elif hurt_time<0:defender.play("idle_loop",.15)
	if hurt_time>=0:
		hurt_time+=delta
		if hurt_time>.85:hurt_time=-1;defender.play("idle_loop",.18)
	defender.advance(delta)
	shield.position=defender.position+Vector3.UP*1.13;shield.scale=Vector3(1.10,.86,.67)
	health_bar.size.x=130*float(state.health)/100;shield_bar.size.x=130*float(state.shield)/120

func attack_step(delta: float) -> void:
	if not started:actor.play("attack",.15);fx.preparation(actor.position+Vector3.UP,str(profile.effect));started=true
	var previous:=attack_time;var dt:=delta
	if hit_hold>0:hit_hold=maxf(0,hit_hold-delta);dt=0
	attack_time+=dt
	if attack_time<float(profile.duration):actor.advance(dt)
	var finish: float=profile.release[0] if profile.effect!="slash" else float(profile.prepare)+.22
	actor.position.z=float(profile.travel)*smoothstep(float(profile.prepare),finish,attack_time)
	if not locked and attack_time>=float(profile.prepare):aim=target_base+Vector3.UP*float(profile.target_height);locked=true
	update_defender(delta)
	if profile.effect in ["mortar","acid","dart"]:
		for i in profile.release.size():
			if previous<float(profile.release[i]) and attack_time>=float(profile.release[i]):spawn_projectile(i)
	else:
		for i in profile.release.size():
			var release: float=profile.release[i]
			var socket: String="Socket_Strike" if profile.effect=="ram" else ("Socket_leg0_-1" if i==0 else "Socket_leg0_1")
			if profile.effect=="slam":
				if previous<release and attack_time>=release:
					var sockets: Array=profile.get("landing_sockets",["Socket_hind-1","Socket_hind1"])
					var point: Vector3=(actor.contact_point(sockets[0])+actor.contact_point(sockets[1]))*.5+Vector3.BACK*.5;point.y=.03
					var event: Dictionary={"target":"ground","kind":"surface","point":point,"normal":Vector3.UP}
					if Vector2(defender.position.x-point.x,defender.position.z-point.z).length()<float(profile.strike_radius)+.53:event.target="defender";event.kind="shield" if state.shield>0 else "organic"
					accept(event,"landing")
				continue
			var point: Vector3=actor.contact_point(socket)
			if attack_time>=release-float(profile.get("strike_lead",.15)) and attack_time<=release+float(profile.get("strike_tail",.13)):
				var from: Vector3=last_points.get(socket,point)
				if profile.effect=="slash":fx.trail(from,point,Color("f6e4be"),.027)
				accept(Contacts.sweep(from,point,float(profile.strike_radius),targets(),false),"strike_"+str(i))
			if previous<release-.12 and attack_time>=release-.12:fx.launch(point,str(profile.effect))
			last_points[socket]=point
	step_projectiles(delta);fx.step(delta)
	shake*=exp(-16*delta);camera.position=camera_base+Vector3(sin(attack_time*85),cos(attack_time*72),0)*shake

func save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image();img.resize(960,600,Image.INTERPOLATE_LANCZOS);img.save_png(path)

func case_summary() -> void:
	var row: Dictionary={"form":current.id,"case":outcome,"health":state.health,"shield":state.shield,"contacts":ledger.size()}
	summaries.append(row);print("CONTACT_CASE ",row)

func review_speed(t: float,walk: float,fast: float) -> float:
	if t<.6:return walk*smoothstep(0,.6,t)
	if t<1.4:return walk
	if t<2.0:return lerpf(walk,fast,smoothstep(1.4,2.0,t))
	if t<4.4:return fast
	return fast*(1-smoothstep(4.4,5.3,t))

func render_speed(out: String) -> void:
	var walk: float=float(profile.stride)/float(profile.stance)/float(profile.period)
	var fast: float=float(profile.run.stride)/float(profile.run.stance)/float(profile.run.period)
	var total:=0.0
	for frame in 180:total+=review_speed(float(frame)/30,walk,fast)/30
	var progress:=0.0
	var original_camera:=camera_base
	actor.restart("move_loop");actor.locomotion_phase=0;actor.locomotion_gait="move_loop"
	defender.hide();shield.hide();health_bar.hide();shield_bar.hide()
	var markers:=Node3D.new();stage.add_child(markers)
	for i in range(-36,12):
		var mark:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(1.1,.008,.025);mark.mesh=box
		var material:=StandardMaterial3D.new();material.albedo_color=Color("a1b3a1");mark.material_override=Ink.material(material,{})
		mark.position=Vector3(2,-.01,float(i)*.5);markers.add_child(mark)
	for frame in 180:
		var t: float=float(frame)/30
		var speed:=review_speed(t,walk,fast);progress+=speed/30
		actor.position.z=progress-total
		if t<5.3:actor.advance_locomotion(1.0/30,speed)
		else:actor.play("stop",.15);actor.advance(1.0/30)
		camera.position=original_camera+Vector3(0,0,actor.position.z)
		caption.text=("걷기" if t<1.4 else "가속" if t<2 else "빠른 이동" if t<4.4 else "감속 → 정지")+"   %.2f m/s  /  최대 %.1f배"%[speed,fast/walk]
		await process_frame
		if frame%2==0:await save_frame(out+"/move-%03d.png"%(frame/2))
	movement_records.append({"form":current.id,"walk_mps":walk,"fast_mps":fast,"speed_ratio":fast/walk,"distance_m":total,"run_cycle_seconds":profile.run.period,"sequence":"walk / accelerate / fast / decelerate / stop; distance-matched gait"})
	markers.free();defender.show();health_bar.show();shield_bar.show();camera.position=original_camera

func run() -> void:
	var wanted:=OS.get_cmdline_user_args();speed_review=wanted.has("--speed-review")
	if speed_review:wanted.remove_at(wanted.find("--speed-review"))
	var remodel_review:=wanted.has("--r01")
	if remodel_review:wanted.remove_at(wanted.find("--r01"))
	folder=ProjectSettings.globalize_path("res://../output/creature-motion/"+("speed-render" if speed_review else "render"));DirAccess.make_dir_recursive_absolute(folder)
	if remodel_review:folder=ProjectSettings.globalize_path("res://../output/creature-remodel/r01/render");DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	make_stage();forms=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_r01.json" if remodel_review else "res://data/creature_motion_studies.json")).forms
	for form in forms:
		if not wanted.is_empty() and not str(form.id) in wanted:continue
		load_type(form);await process_frame
		if wanted.has("--still"):
			for warmup in 4:await process_frame
			await save_frame(folder+"/shadow-check.png");quit();return
		var out: String=folder+"/"+form.id;DirAccess.make_dir_recursive_absolute(out)
		if speed_review:await render_speed(out)
		for frame in range(0 if speed_review else 60):
			var t: float=frame/30.0
			if t<1.5:
				actor.play("move_loop",.16);actor.position.z=(t-1.5)*float(profile.stride)/float(profile.stance)
			else:actor.play("stop",.15);actor.position.z=0
			caption.text="이동 → 감속 → 지지발 확보";actor.advance(1.0/30);defender.advance(1.0/30);update_defender(1.0/30)
			await process_frame
			if frame%2==0:await save_frame(out+"/move-%03d.png"%(frame/2))
		for mode in ["hit","shield","miss"]:
			reset_case(mode)
			for frame in range(96):
				attack_step(1.0/30);await process_frame
				if frame%2==0:await save_frame(out+"/"+mode+"-%03d.png"%(frame/2))
			case_summary()
		print("MOTION_CONTACT_RENDERED ",form.id)
	var result: Dictionary={"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"cases":summaries,"events":events,"audio_plays":fx.audio_count,"locomotion":movement_records,"yellow_impact_rings":false,"scope":"isolated contact lab; no campaign/save writes"}
	var file:=FileAccess.open(folder+"/evidence.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit()

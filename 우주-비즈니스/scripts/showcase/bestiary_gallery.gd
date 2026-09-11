extends Node3D
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
const Ink=preload("res://scripts/actors/ink_style.gd")
var forms: Array=[]
var appearances: Array=[]
var selected:=0
var variant:=0
var actor: Node3D
var camera: Camera3D
var target:=Vector3.ZERO
var light: DirectionalLight3D
var cache: Dictionary={}
var dragging:=false
var orbit:=false
var headline: Label
var subtitle: Label
var info: Label
var state_info: Label
var status: Label
var attack_button: Button
var regular: FontVariation
var bold: FontVariation
var family_picker: OptionButton
var families: Array[String]=[]
var filtered: Array[int]=[]
var film:=false
var film_frame:=0
var film_choices: Array[int]=[]
var aberrant_only:=false
var eye_revisions:=false
var light_index:=0
var light_button: Button

func _ready() -> void:
	forms=FrontierEcologyCatalog.all_forms()
	appearances=FrontierEcologyCatalog.all_appearances()
	film="--film" in OS.get_cmdline_user_args()
	aberrant_only="--aberrant" in OS.get_cmdline_user_args()
	eye_revisions="--eye-revisions" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1440,900)
	get_window().content_scale_size=Vector2i(1600,1000)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_title("우주 비즈니스맨 · 생물 아트 도감")
	get_viewport().msaa_3d=Viewport.MSAA_4X
	get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	regular=FontVariation.new()
	regular.base_font=load("res://assets/fonts/NotoSansKR.ttf")
	regular.variation_opentype={2003265652:500}
	bold=FontVariation.new()
	bold.base_font=regular.base_font
	bold.variation_opentype={2003265652:750}
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("deded2")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("a5c5d5")
	env.ambient_light_energy=.42
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled=true
	env.ssao_intensity=1.1
	var world:=WorldEnvironment.new()
	world.environment=env
	add_child(world)
	light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-32,0)
	light.light_color=Color("fff0d2")
	light.light_energy=1.3
	light.shadow_enabled=true
	light.directional_shadow_max_distance=50
	add_child(light)
	RenderingServer.directional_shadow_atlas_set_size(4096,true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	var floor_mesh:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(200,200)
	floor_mesh.mesh=plane
	floor_mesh.position.y=-.04
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("b9bba5")
	floor_mesh.material_override=Ink.material(mat,cache)
	add_child(floor_mesh)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.current=true
	camera.far=150
	add_child(camera)
	Ink.attach(self)
	actor=Actor.new()
	actor.lod_override=0
	add_child(actor)
	actor.attack_cue.connect(func(phase: String):
		state_info.text={"windup":"공격 전조","active":"공격 동작 · 효과","recovery":"회복 동작","complete":"대기"}.get(phase,phase))
	build_ui()
	for i in range(forms.size()):
		if not eye_revisions or forms[i].has("eye_design"):filtered.append(i)
		if forms[i].attack!="none" and (eye_revisions or i==0 or forms[i-1].family!=forms[i].family) and (not aberrant_only or forms[i].get("collection","")=="aberrant") and (not eye_revisions or forms[i].has("eye_design")): film_choices.append(i)
	var initial:=15 if eye_revisions else (500 if aberrant_only else 0)
	if "--biota" in OS.get_cmdline_user_args():
		for i in forms.size():
			if forms[i].get("collection","")=="biota-7000":initial=i;break
	select_form(initial)
	print("BESTIARY_GALLERY_READY forms=",forms.size()," appearances=",appearances.size())
	if "--attack-captures" in OS.get_cmdline_user_args():capture_attacks()
	if "--film-captures" in OS.get_cmdline_user_args():capture_film()

func text(parent: Node,value: String,at: Vector2,size: int,color: String="263b3d") -> Label:
	var label:=Label.new()
	label.text=value
	label.position=at
	label.add_theme_font_override("font",bold if size>=24 else regular)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color(color))
	parent.add_child(label)
	return label

func style(color: String) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(color)
	s.set_corner_radius_all(10)
	s.content_margin_left=14
	s.content_margin_right=14
	s.content_margin_top=10
	s.content_margin_bottom=10
	return s

func button(parent: Node,value: String,at: Vector2,size: Vector2,fn: Callable) -> Button:
	var b:=Button.new()
	b.text=value
	b.position=at
	b.size=size
	b.add_theme_font_override("font",regular)
	b.add_theme_font_size_override("font_size",17)
	for slot in ["normal","hover","pressed"]:b.add_theme_stylebox_override(slot,style("c5d2bd" if slot=="pressed" else "e5e7dc"))
	b.add_theme_color_override("font_color",Color("294044"))
	b.pressed.connect(fn)
	parent.add_child(b)
	return b

func build_ui() -> void:
	var ui:=CanvasLayer.new()
	add_child(ui)
	text(ui,"LOCUS / LIFE ATLAS",Vector2(54,32),18)
	headline=text(ui,"",Vector2(50,77),39)
	subtitle=text(ui,"",Vector2(54,144),20,"52665f")
	var panel:=Panel.new()
	panel.position=Vector2(1180,50)
	panel.size=Vector2(366,870)
	panel.add_theme_stylebox_override("panel",style("f1f0e5"))
	ui.add_child(panel)
	text(panel,"생물 아트 도감",Vector2(24,20),26)
	family_picker=OptionButton.new()
	family_picker.position=Vector2(24,76)
	family_picker.size=Vector2(318,46)
	family_picker.add_theme_font_override("font",regular)
	family_picker.add_theme_font_size_override("font_size",18)
	family_picker.add_item("전체 생물")
	families.append("")
	for form in forms:
		if not families.has(str(form.family)):
			families.append(str(form.family))
			family_picker.add_item(form.family_name)
	family_picker.item_selected.connect(filter_family)
	panel.add_child(family_picker)
	button(panel,"← 이전 모델",Vector2(24,139),Vector2(153,46),step_form.bind(-1))
	button(panel,"다음 모델 →",Vector2(189,139),Vector2(153,46),step_form.bind(1))
	button(panel,"← 이전 변형",Vector2(24,200),Vector2(153,46),step_variant.bind(-1))
	button(panel,"다음 변형 →",Vector2(189,200),Vector2(153,46),step_variant.bind(1))
	info=text(panel,"",Vector2(24,271),17,"52665f")
	info.size.x=318
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(panel,"1 · 대기",Vector2(24,405),Vector2(153,46),change_state.bind("idle"))
	button(panel,"2 · 이동",Vector2(189,405),Vector2(153,46),change_state.bind("move"))
	button(panel,"3 · 섭식/활동",Vector2(24,467),Vector2(153,46),change_state.bind("feed"))
	attack_button=button(panel,"4 · 공격 시연",Vector2(189,467),Vector2(153,46),change_state.bind("attack"))
	button(panel,"휴면",Vector2(24,529),Vector2(153,46),change_state.bind("dormant"))
	button(panel,"스트레스",Vector2(189,529),Vector2(153,46),change_state.bind("stressed"))
	state_info=text(panel,"대기",Vector2(24,601),23)
	light_button=button(panel,"조명 · 주광",Vector2(24,650),Vector2(153,46),cycle_light)
	button(panel,"효과 켜기/끄기",Vector2(189,650),Vector2(153,46),func():actor.show_effects=not actor.show_effects;actor.update_fx())
	button(panel,"근거리 / 원거리 모델",Vector2(24,710),Vector2(318,46),func():actor.lod_override=1-actor.lod_override)
	text(panel,"모델·기관 동작과 조명 검수\n실제 서식은 행성 고유 생태를 따름",Vector2(24,780),16,"52665f")
	status=text(ui,"",Vector2(54,883),20)
	text(ui,"← → 모델   ·   ↑ ↓ 변형   ·   1–4 동작   ·   Space 정지   ·   R 회전   ·   드래그/휠   ·   Esc 종료",Vector2(54,950),16)

func select_form(index: int) -> void:
	selected=posmod(index,forms.size())
	variant=0
	actor.configure(forms[selected],appearances[selected*20])
	headline.text=forms[selected].name
	subtitle.text=forms[selected].environment_label+"  /  "+{"animal":"동물","plant":"식생","microbe":"미생물 군락"}[forms[selected].category]
	attack_button.disabled=forms[selected].attack=="none"
	attack_button.text="공격 없음" if attack_button.disabled else "4 · 공격 시연"
	state_info.text="대기"
	frame_subject()
	update_labels()

func frame_subject() -> void:
	var bounds:=AABB()
	var first:=true
	for mi in actor.models[0].find_children("*","MeshInstance3D",true,false):
		var b: AABB=mi.global_transform*mi.get_aabb()
		bounds=b if first else bounds.merge(b)
		first=false
	target=bounds.get_center()
	var direction:=Vector3(1.22,.84,1.70).normalized()
	camera.position=target+direction*maxf(32,bounds.size.length()*4)
	camera.look_at(target)
	var inv:=camera.global_transform.affine_inverse()
	var low:=Vector2(INF,INF)
	var high:=Vector2(-INF,-INF)
	for i in range(8):
		var point:=inv*bounds.get_endpoint(i)
		low=low.min(Vector2(point.x,point.y))
		high=high.max(Vector2(point.x,point.y))
	var extent:=high-low
	camera.size=maxf(extent.y/.65,extent.x/(1.6*.64))*1.20
	target+=camera.global_basis.x*camera.size*.19
	camera.position=target+direction*maxf(32,bounds.size.length()*4)
	camera.look_at(target)

func update_labels() -> void:
	info.add_theme_font_size_override("font_size",17);info.tooltip_text=""
	info.text="%s\n\n모델 %03d / %d · 변형 %02d / 20\n공격 유형: %s"%[forms[selected].habitat_note,selected+1,forms.size(),variant+1,{"none":"없음","ram":"돌진","bite":"물기","kick":"차기","claw":"집게","scythe":"베기","slam":"내려치기","dive":"급강하","spit":"분사"}.get(forms[selected].attack,"")]
	if forms[selected].has("sensory_type"):
		info.text="눈 %d개 · %s\n모델 %03d / %d · 변형 %02d / 20"%[forms[selected].eye_count,forms[selected].sensory_type,selected+1,forms.size(),variant+1]
	if forms[selected].get("collection","")=="biota-7000":
		info.add_theme_font_size_override("font_size",14);info.tooltip_text=forms[selected].anatomy_note
		info.text="%s · 주요 기관 %d개\n%s\n유형 골격 %d개 본\n모델 %04d / %d · 변형 %02d / 20"%[forms[selected].family_name,int(forms[selected].body_plan.radial_count),forms[selected].adaptation_note,int(forms[selected].rig.bone_count),selected+1,forms.size(),variant+1]
	status.text=appearances[selected*20+variant].id+"   /   "+str(appearances.size())+"개 외형 프로필"

func step_variant(direction: int) -> void:
	variant=posmod(variant+direction,20)
	actor.apply_appearance(appearances[selected*20+variant])
	update_labels()

func filter_family(index: int) -> void:
	family_picker.select(index)
	filtered.clear()
	for i in range(forms.size()):
		if index==0 or forms[i].family==families[index]:filtered.append(i)
	if not filtered.is_empty():select_form(filtered[0])

func step_form(direction: int) -> void:
	var index:=filtered.find(selected)
	select_form(filtered[posmod(index+direction,filtered.size())])

func change_state(value: String) -> void:
	actor.paused=false
	if actor.set_state(value):
		state_info.text={"idle":"대기","move":"이동 동작","feed":"섭식 / 활동","dormant":"휴면","stressed":"스트레스","attack":"공격 전조"}.get(value,value)

func cycle_light() -> void:
	light_index=(light_index+1)%3
	light.rotation_degrees=[Vector3(-48,-32,0),Vector3(-25,145,0),Vector3(-65,-110,0)][light_index]
	light.light_energy=[1.3,1.1,.42][light_index]
	light_button.text="조명 · "+["주광","역광","그늘"][light_index]

func _process(delta: float) -> void:
	if orbit:
		camera.position=target+(camera.position-target).rotated(Vector3.UP,delta*.20)
		camera.look_at(target)
	if film and not film_choices.is_empty():
		var segment:=int(film_frame/90)
		if film_frame%90==0:
			select_form(film_choices[segment%film_choices.size()])
			change_state("attack")
		film_frame+=1
		if film_frame>=film_choices.size()*90:get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:get_tree().quit()
		if event.keycode==KEY_LEFT:step_form(-1)
		if event.keycode==KEY_RIGHT:step_form(1)
		if event.keycode==KEY_UP:step_variant(1)
		if event.keycode==KEY_DOWN:step_variant(-1)
		if event.keycode==KEY_SPACE:actor.paused=not actor.paused
		if event.keycode==KEY_R:orbit=not orbit
		if event.keycode>=KEY_1 and event.keycode<=KEY_4:change_state(["idle","move","feed","attack"][event.keycode-KEY_1])
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size=clampf(camera.size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),1,25)
	if event is InputEventMouseMotion and dragging:
		var v: Vector3=(camera.position-target).rotated(Vector3.UP,-event.relative.x*.005)
		var next: Vector3=v.rotated(camera.global_basis.x,-event.relative.y*.004)
		if next.normalized().y>.10 and next.normalized().y<.9:v=next
		camera.position=target+v
		camera.look_at(target)

func capture_attacks() -> void:
	var dest:=ProjectSettings.globalize_path("res://../docs/production/media/bestiary/"+("eye-revision/attacks/" if eye_revisions else ("aberrant/attacks/" if aberrant_only else "attacks/"))+"")
	DirAccess.make_dir_recursive_absolute(dest)
	var records: Array=[]
	for index in film_choices:
		select_form(index)
		for stage in [{"name":"windup","time":.35},{"name":"active","time":.68},{"name":"recovery","time":1.03}]:
			actor.set_state("attack")
			actor.elapsed=stage.time
			actor.paused=true
			actor.pose()
			state_info.text={"windup":"공격 전조","active":"공격 동작 · 효과","recovery":"회복 동작"}[stage.name]
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			var img:=get_viewport().get_texture().get_image()
			assert(img.save_png(dest+forms[index].family+"-"+stage.name+".png")==OK)
		records.append({"form":forms[index].id,"family":forms[index].family,"attack":forms[index].attack,"stages":["windup","active","recovery"]})
	FileAccess.open(dest+"captures.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	print("BESTIARY_ATTACK_CAPTURES ",records.size())
	get_tree().quit()

func capture_film() -> void:
	var dest: String=OS.get_environment("BESTIARY_FILM_FRAMES")
	if dest.is_empty():dest="/tmp/bestiary-film-frames"
	DirAccess.make_dir_recursive_absolute(dest)
	actor.set_process(false)
	var frame:=0
	for index in film_choices:
		select_form(index)
		actor.paused=true
		for step in range(90):
			actor.set_state("attack" if step<48 else "idle")
			actor.elapsed=float(step if step<48 else step-48)/30.
			actor.pose()
			if step>=48:state_info.text="대기"
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			var img:=get_viewport().get_texture().get_image()
			img.resize(1280,800,Image.INTERPOLATE_LANCZOS)
			assert(img.save_png(dest+"/frame-%04d.png"%frame)==OK)
			frame+=1
		print("BESTIARY_FILM_FRAMES ",frame,"/",film_choices.size()*90)
	get_tree().quit()

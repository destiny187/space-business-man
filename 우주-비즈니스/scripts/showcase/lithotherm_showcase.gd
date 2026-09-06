extends Node3D
const Actor = preload("res://scripts/actors/creatures/lithotherm.gd")
const Ink = preload("res://scripts/actors/ink_style.gd")
const STATES := ["dormant","walking","feeding","stressed"]
const TITLES := ["01   휴면","02   보행","03   섭식","04   스트레스"]
const NOTES := ["열을 아끼는 시간\n\n몸을 낮추고 감각 기관을 보호합니다.\n외피 사이의 열빛이 잦아듭니다.","여섯 다리의 느린 탐사\n\n낮은 무게중심과 넓은 발로\n광물 지형을 짚으며 움직입니다.","바위를 먹고 열을 만드는 생물\n\n턱으로 광물 기질을 부수고\n외피 틈으로 대사열을 내보냅니다.","조건 이탈의 시각 신호\n\n머리를 움츠리고 열빛이 맥동합니다.\n생물실의 환경을 확인할 때입니다."]
var specimen: Node3D
var camera: Camera3D
var key: DirectionalLight3D
var group := Node3D.new()
var target := Vector3(.70,.95,0)
var state_label: Label
var note_label: Label
var status_label: Label
var buttons: Array[Button] = []
var food := Node3D.new()
var cache: Dictionary = {}
var dragging := false
var orbit := false
var auto_capture := false
var mode := 1
var light_mode := 0
var capture_dir := "res://../docs/production/media/lithotherm/"
var font_regular: FontVariation
var font_bold: FontVariation
var film_frame := 0
var film := false
var light_label: Button
var crowd_label: Button

func _ready() -> void:
	auto_capture = "--capture" in OS.get_cmdline_user_args()
	film = "--film" in OS.get_cmdline_user_args()
	font_regular=FontVariation.new()
	font_regular.base_font=load("res://assets/fonts/NotoSansKR.ttf")
	font_regular.variation_opentype={2003265652:500}
	font_bold=FontVariation.new()
	font_bold.base_font=font_regular.base_font
	font_bold.variation_opentype={2003265652:750}
	get_window().size = Vector2i(1440,900)
	get_window().content_scale_size = Vector2i(1600,1000)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_title("우주 비즈니스맨 · 리소섬 생물 관찰실")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	RenderingServer.directional_shadow_atlas_set_size(4096,true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("deded2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5c5d5")
	env.ambient_light_energy = .42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = .8
	env.ssao_intensity = 1.1
	var world := WorldEnvironment.new()
	world.environment=env
	add_child(world)
	key = DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-48,-32,0)
	key.light_color=Color("fff0d2")
	key.light_energy=1.3
	key.shadow_enabled=true
	key.directional_shadow_max_distance=35
	add_child(key)
	mesh_plane(Vector3(0,-.15,0),Vector2(200,200),Color("b9b9a5"))
	var plinth := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius=2.8
	cylinder.bottom_radius=2.87
	cylinder.height=.16
	cylinder.radial_segments=96
	plinth.mesh=cylinder
	plinth.position=Vector3(0,-.08,0)
	var pm := StandardMaterial3D.new()
	pm.albedo_color=Color("b4b49c")
	plinth.material_override=Ink.material(pm,cache)
	add_child(plinth)
	specimen=Actor.new()
	add_child(specimen)
	add_child(food)
	for i in range(4):
		rock(food,Vector3(-.28+i*.18,.08,2.2+sin(i)*.10),Vector3(.14,.12,.13),Color("67554a"))
	for i in range(9):
		var a := 2.8+float(i)*.29
		rock(self,Vector3(cos(a)*2.35,.07,sin(a)*2.35),Vector3(.16,.11,.14),Color("7d8884"))
	add_child(group)
	group.visible=false
	for i in range(8):
		var creature:=Actor.new()
		group.add_child(creature)
		creature.position=Vector3((i%4-1.5)*3.5,0,-5.5-float(i/4)*3.5)
		creature.rotation.y=.2*(i%3-1)
		creature.elapsed=i*.67
		creature.lod_override=1
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=6.7
	camera.position=target+Vector3(6,4.1,8).normalized()*32
	camera.far=120
	add_child(camera)
	camera.look_at(target)
	camera.current=true
	Ink.attach(self)
	build_ui()
	select_state(1)
	print("LITHOTHERM_READY")
	if auto_capture: capture_all()

func mesh_plane(at: Vector3,size: Vector2,color: Color) -> void:
	var mesh:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=size
	mesh.mesh=plane
	mesh.position=at
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	mesh.material_override=Ink.material(material,cache)
	add_child(mesh)

func rock(parent: Node3D,at: Vector3,size: Vector3,color: Color) -> void:
	var mesh:=MeshInstance3D.new()
	var sphere:=SphereMesh.new()
	sphere.radial_segments=10
	sphere.rings=5
	mesh.mesh=sphere
	mesh.position=at
	mesh.scale=size*2
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=.8
	mesh.material_override=Ink.material(material,cache)
	parent.add_child(mesh)

func label(parent: Node,content: String,at: Vector2,size: int,color: String="263b3d") -> Label:
	var l:=Label.new()
	l.text=content
	l.position=at
	l.add_theme_font_override("font",font_bold if size>=24 else font_regular)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color(color))
	parent.add_child(l)
	return l

func box_style(color: String,radius: int=10) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(color)
	style.set_corner_radius_all(radius)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=10
	style.content_margin_bottom=10
	return style

func button(parent: Node,text: String,at: Vector2,size: Vector2,callback: Callable) -> Button:
	var b:=Button.new()
	b.text=text
	b.position=at
	b.size=size
	b.add_theme_font_override("font",font_regular)
	b.add_theme_font_size_override("font_size",19)
	b.add_theme_stylebox_override("normal",box_style("e7e7dc"))
	b.add_theme_stylebox_override("hover",box_style("d7dfd2"))
	b.add_theme_stylebox_override("pressed",box_style("a5b9a5"))
	b.add_theme_color_override("font_color",Color("294044"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func build_ui() -> void:
	var ui:=CanvasLayer.new()
	add_child(ui)
	label(ui,"LOCUS   /   FIELD NOTES                                      LIFEFORM 001",Vector2(58,32),17)
	label(ui,"리소섬",Vector2(54,69),56)
	label(ui,"LITHOTHERM   /   열을 품은 바위 생물",Vector2(58,146),22,"55655d")
	label(ui,"광물 외피   ·   여섯 다리   ·   조건부 발열",Vector2(58,190),17,"62736c")
	var panel:=Panel.new()
	panel.position=Vector2(1190,60)
	panel.size=Vector2(354,858)
	panel.add_theme_stylebox_override("panel",box_style("f1f0e5",16))
	ui.add_child(panel)
	label(panel,"표본 관찰",Vector2(24,24),25)
	label(panel,"상태를 선택해 관찰하세요",Vector2(24,69),17,"687771")
	for i in range(4):
		buttons.append(button(panel,TITLES[i],Vector2(24,114+i*61),Vector2(306,49),select_state.bind(i)))
	state_label=label(panel,"",Vector2(24,385),24)
	note_label=label(panel,"",Vector2(24,435),16,"52665f")
	label(panel,"연구의 쓰임",Vector2(24,590),20)
	label(panel,"기질 공급 → 국소 가열 → 얼음 해빙\n\n먹이와 서식 조건을 먼저 맞춥니다.\n높은 체온만으로 냉각하지 않습니다.",Vector2(24,631),16,"52665f")
	light_label=button(panel,"조명 · 주광",Vector2(24,756),Vector2(148,48),cycle_light)
	crowd_label=button(panel,"군집 보기",Vector2(182,756),Vector2(148,48),toggle_group)
	label(ui,"BASALT SHELL / AMBER THERMAL SEAMS",Vector2(58,853),17)
	status_label=label(ui,"",Vector2(58,887),20)
	label(ui,"드래그 회전   ·   휠 확대   ·   1–4 상태   ·   Space 동작 정지   ·   R 자동 회전   ·   Esc 종료",Vector2(58,951),16)
	label(ui,"생물 외형·동작 시연 / 생태·연구·운송은 연결 전",Vector2(1190,943),13,"61736e")

func select_state(index: int) -> void:
	mode=index
	specimen.set_state(STATES[index])
	food.visible=index==2
	state_label.text=TITLES[index].substr(5)
	note_label.text=NOTES[index]
	status_label.text="관찰 상태  /  "+TITLES[index].substr(5)
	for i in range(buttons.size()):
		buttons[i].add_theme_stylebox_override("normal",box_style("bad1ba" if i==index else "e7e7dc"))

func cycle_light() -> void:
	light_mode=(light_mode+1)%3
	key.rotation_degrees=[Vector3(-48,-32,0),Vector3(-25,145,0),Vector3(-65,-110,0)][light_mode]
	key.light_energy=[1.3,1.1,.42][light_mode]
	light_label.text="조명 · "+["주광","역광","그늘"][light_mode]

func toggle_group() -> void:
	group.visible=not group.visible
	camera.size=20.5 if group.visible else 6.7
	target=Vector3(3.2,.8,-3.8) if group.visible else Vector3(.7,.95,0)
	camera.position=target+Vector3(6,5,10).normalized()*32
	camera.look_at(target)
	crowd_label.text="단독 보기" if group.visible else "군집 보기"

func _process(delta: float) -> void:
	if film:
		if film_frame%75==0: select_state(int(film_frame/75)%4)
		film_frame+=1
		if film_frame>=300: get_tree().quit()
	if orbit:
		camera.position=target+(camera.position-target).rotated(Vector3.UP,delta*.23)
		camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4: select_state(event.keycode-KEY_1)
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		if event.keycode == KEY_SPACE:
			specimen.paused=not specimen.paused
			status_label.text="동작 정지" if specimen.paused else "관찰 상태  /  "+TITLES[mode].substr(5)
		if event.keycode == KEY_R: orbit=not orbit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size=clampf(camera.size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),4,25)
	if event is InputEventMouseMotion and dragging:
		var v: Vector3=(camera.position-target).rotated(Vector3.UP,-event.relative.x*.005)
		var next: Vector3=v.rotated(camera.global_basis.x,-event.relative.y*.004)
		if next.normalized().y > .12 and next.normalized().y < .9: v=next
		camera.position=target+v
		camera.look_at(target)

func shot(name: String) -> void:
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	var result:=image.save_png(ProjectSettings.globalize_path(capture_dir+name+".png"))
	assert(result == OK)
	print("LITHOTHERM_CAPTURE ",name)

func capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	for i in range(4):
		select_state(i)
		specimen.elapsed=1.1
		specimen.pose()
		specimen.paused=true
		await shot(STATES[i])
	select_state(1)
	cycle_light()
	await shot("backlight")
	cycle_light()
	await shot("shade")
	cycle_light()
	specimen.lod_override=1
	await shot("far-model-close-inspection")
	specimen.lod_override=-1
	toggle_group()
	await shot("group")
	print("LITHOTHERM_CAPTURE_COMPLETE")
	get_tree().quit()

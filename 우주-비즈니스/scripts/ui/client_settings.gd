class_name FrontierClientSettings
extends CanvasLayer
## Local presentation only: never stored in the host's simulation manifest.
signal changed
const BASE_MOUSE_SENSITIVITY:=0.0025
const DEFAULTS={"tutorial_mode":0,"preset":1,"scale":1.0,"msaa":1,"fxaa":false,"taa":false,"vsync":true,"fps":60,"view_distance":2400.0,"shadow_distance":180.0,"shadow_size":2048,"shadows":true,"local_shadows":true,"ssao":true,"ssil":false,"ssr":false,"glow":true,"fog":1.0,"lod":3.0,"fov":76.0,"sensitivity":1.0,"invert_y":false,"volume":0.8,"music_volume":0.65,"show_fps":false,"window_mode":0,"resolution":0,"upscaler":0,"sharpness":.2,"shadow_filter":3,"local_shadow_size":2048}
const LIMITS={"tutorial_mode":[0,2],"scale":[.5,1.5],"msaa":[0,3],"fps":[0,240],"view_distance":[600,8000],"shadow_distance":[40,500],"shadow_size":[1024,4096],"fog":[0,2],"lod":[1,8],"fov":[60,100],"sensitivity":[.1,10.0],"volume":[0,1],"music_volume":[0,1],"preset":[0,3],"window_mode":[0,2],"resolution":[0,4],"upscaler":[0,1],"sharpness":[0,2],"shadow_filter":[0,5],"local_shadow_size":[1024,4096]}
const RESOLUTIONS=[Vector2i(1280,800),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]
var values: Dictionary=DEFAULTS.duplicate()
var path="user://client_settings.json"
var overlay: Control
var tabs: TabContainer
var notice: Label
var fps_label: Label
var display_previous: Dictionary={}
var display_deadline:=0
var controls: Dictionary={}
var rebuilding:=false
var sensitivity_slider: HSlider

func mouse_sensitivity() -> float:
	return float(values.sensitivity)*BASE_MOUSE_SENSITIVITY

static func ensure(tree: SceneTree) -> FrontierClientSettings:
	var existing:=tree.root.get_node_or_null("ClientSettings") as FrontierClientSettings
	if existing!=null:return existing
	var settings:=FrontierClientSettings.new();settings.name="ClientSettings";tree.root.add_child(settings)
	return settings

static func current(tree: SceneTree) -> FrontierClientSettings:
	return tree.root.get_node_or_null("ClientSettings") as FrontierClientSettings

func _ready() -> void:
	layer=90
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):path=arg.trim_prefix("--crew-folder=")+"/client_settings.json"
	load_settings()
	_build()
	get_tree().node_added.connect(_added)
	apply_all()

func load_settings() -> void:
	values=DEFAULTS.duplicate()
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not data is Dictionary and FileAccess.file_exists(path+".bak"):data=JSON.parse_string(FileAccess.get_file_as_string(path+".bak"))
	if not data is Dictionary:return
	for key in DEFAULTS:
		var value: Variant=data.get(key,DEFAULTS[key])
		if key=="sensitivity" and data.has(key) and data.get("sensitivity_format","")!="multiplier_v1" and (value is float or value is int) and is_finite(float(value)):
			value=clampf(float(value),.0008,.006)/BASE_MOUSE_SENSITIVITY
		if DEFAULTS[key] is bool:
			if value is bool:values[key]=value
		elif (value is float or value is int) and is_finite(float(value)):
			values[key]=clampf(float(value),LIMITS[key][0],LIMITS[key][1])
			if DEFAULTS[key] is int:values[key]=int(values[key])
	for key in ["shadow_size","local_shadow_size"]:
		if int(values[key]) not in [1024,2048,4096]:values[key]=2048

func save_settings() -> bool:
	var stored:=values.duplicate()
	stored.sensitivity_format="multiplier_v1"
	# An unconfirmed display mode must never survive a crash/restart.
	for key in display_previous:stored[key]=display_previous[key]
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(stored,"\t"));file.flush()
	var error:=file.get_error();file.close()
	if error!=OK:return false
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path,path+".bak")!=OK:return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func is_open() -> bool:return overlay!=null and overlay.visible
func open() -> void:
	overlay.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	overlay.grab_focus()
func close() -> void:
	if not display_previous.is_empty():_revert_display()
	overlay.hide();get_viewport().gui_release_focus()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F10:
			if is_open():close()
			else:open()
			get_viewport().set_input_as_handled()
		elif is_open() and event.physical_keycode==KEY_ESCAPE:close();get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
	fps_label.visible=values.show_fps
	if fps_label.visible:fps_label.text="%d FPS · %.1f ms" % [Engine.get_frames_per_second(),1000.0/maxi(1,Engine.get_frames_per_second())]
	if not display_previous.is_empty():
		var remaining:=display_deadline-Time.get_ticks_msec()
		notice.text="화면이 보이면 ‘화면 변경 유지’를 누르세요. %d초 후 복구" % ceili(remaining/1000.0)
		if remaining<=0:_revert_display()
func _added(node: Node) -> void:
	if node is Viewport or node is WorldEnvironment or node is Camera3D or node is Light3D:_apply_node.call_deferred(node)
func _apply_node(node: Node) -> void:
	if not is_instance_valid(node):return
	if node is Viewport:
		node.scaling_3d_mode=values.upscaler;node.fsr_sharpness=values.sharpness;node.positional_shadow_atlas_size=values.local_shadow_size
		node.scaling_3d_scale=values.scale;node.msaa_3d=values.msaa;node.screen_space_aa=1 if values.fxaa else 0;node.use_taa=values.taa;node.mesh_lod_threshold=values.lod
	if node is Camera3D:
		if not node.has_meta("original_far"):node.set_meta("original_far",node.far)
		node.far=maxf(float(node.get_meta("original_far")),float(values.view_distance)*1.6);node.fov=values.fov
	if node is WorldEnvironment and node.environment!=null:
		var env: Environment=node.environment
		env.ssao_enabled=values.ssao;env.ssil_enabled=values.ssil;env.ssr_enabled=values.ssr;env.glow_enabled=values.glow
		if not node.has_meta("original_fog"):node.set_meta("original_fog",env.fog_enabled);node.set_meta("original_density",env.fog_density)
		env.fog_enabled=node.get_meta("original_fog") and values.fog>0;env.fog_density=float(node.get_meta("original_density"))*float(values.fog)
	if node is DirectionalLight3D:
		if not node.has_meta("original_shadow"):node.set_meta("original_shadow",node.shadow_enabled)
		node.shadow_enabled=node.get_meta("original_shadow") and values.shadows;node.directional_shadow_max_distance=values.shadow_distance
	elif node is Light3D:
		if not node.has_meta("original_shadow"):node.set_meta("original_shadow",node.shadow_enabled)
		node.shadow_enabled=node.get_meta("original_shadow") and values.local_shadows
func _walk(node: Node) -> void:
	_apply_node(node)
	for child in node.get_children():_walk(child)
func apply_all() -> void:
	Engine.max_fps=int(values.fps)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,values.volume)))
	AudioServer.set_bus_mute(0,values.volume<=0)
	RenderingServer.directional_shadow_atlas_set_size(int(values.shadow_size),true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(values.shadow_filter))
	RenderingServer.positional_soft_shadow_filter_set_quality(int(values.shadow_filter))
	_walk(get_tree().root)
	changed.emit()
func _apply_display() -> void:
	var modes=[DisplayServer.WINDOW_MODE_WINDOWED,DisplayServer.WINDOW_MODE_MAXIMIZED,DisplayServer.WINDOW_MODE_FULLSCREEN]
	DisplayServer.window_set_mode(modes[int(values.window_mode)])
	if int(values.window_mode)==0:
		DisplayServer.window_set_size(RESOLUTIONS[int(values.resolution)])
		var screen:=DisplayServer.screen_get_usable_rect();DisplayServer.window_set_position(screen.position+(screen.size-DisplayServer.window_get_size())/2)
func _revert_display() -> void:
	for key in display_previous:values[key]=display_previous[key]
	display_previous.clear();_apply_display();_sync();notice.text="이전 화면 설정으로 복구했습니다."
func set_option(key: String,value: Variant) -> void:
	if rebuilding:return
	if key in ["window_mode","resolution"]:
		if display_previous.is_empty():display_previous={"window_mode":values.window_mode,"resolution":values.resolution}
		values[key]=value;display_deadline=Time.get_ticks_msec()+15000;_apply_display()
	else:
		values[key]=value
		if key in ["scale","msaa","fxaa","taa","view_distance","shadow_distance","shadow_size","shadows","local_shadows","ssao","ssil","ssr","glow","fog","lod","upscaler","sharpness","shadow_filter","local_shadow_size"]:values.preset=3
		apply_all()
		if not save_settings():notice.text="설정 저장 실패: 디스크 공간과 쓰기 권한을 확인해 주세요."
		else:notice.text="적용·저장했습니다. 온라인 세계는 설정 중에도 계속 진행됩니다."
	_sync()
func _preset(index: int) -> void:
	if rebuilding or index==3:return
	var presets=[{"scale":.75,"msaa":0,"fxaa":true,"taa":false,"view_distance":1200.0,"shadow_distance":80.0,"shadow_size":1024,"ssao":false,"ssil":false,"ssr":false,"glow":false,"lod":6.0},{"scale":1.0,"msaa":1,"fxaa":false,"taa":false,"view_distance":2400.0,"shadow_distance":180.0,"shadow_size":2048,"ssao":true,"ssil":false,"ssr":false,"glow":true,"lod":3.0},{"scale":1.0,"msaa":2,"fxaa":false,"taa":false,"view_distance":4800.0,"shadow_distance":300.0,"shadow_size":4096,"ssao":true,"ssil":true,"ssr":true,"glow":true,"lod":1.0}]
	values.merge(presets[index],true);values.shadows=true;values.local_shadows=index>0;values.fog=1.0;values.upscaler=0;values.sharpness=.2;values.shadow_filter=1 if index==0 else 3;values.local_shadow_size=1024 if index==0 else (4096 if index==2 else 2048);values.preset=index
	apply_all();notice.text="프리셋을 적용·저장했습니다." if save_settings() else "설정 저장에 실패했습니다.";_sync()
func _sync() -> void:
	rebuilding=true
	for key in controls:
		var control: Control=controls[key]
		if control is OptionButton:
			var options: Array=control.get_meta("values")
			control.select(options.find(values[key]))
		elif control is CheckBox:control.button_pressed=values[key]
		else:control.value=values[key]
	if sensitivity_slider!=null:sensitivity_slider.set_value_no_signal(values.sensitivity)
	rebuilding=false
func _page(title: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.name=title;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",12);scroll.add_child(column)
	return column
func _row(page: VBoxContainer,title: String) -> HBoxContainer:
	var row:=HBoxContainer.new();page.add_child(row)
	var label:=Label.new();label.text=title;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
	return row
func _choice(page: VBoxContainer,title: String,key: String,labels: Array,options: Array) -> void:
	var row:=_row(page,title);var select:=OptionButton.new();select.custom_minimum_size.x=220;row.add_child(select)
	for label in labels:select.add_item(str(label))
	select.set_meta("values",options);controls[key]=select
	select.item_selected.connect(func(index: int):
		if key=="preset":_preset(index)
		else:set_option(key,options[index]))
func _number(page: VBoxContainer,title: String,key: String,step: float,suffix: String="") -> void:
	var row:=_row(page,title);var spin:=SpinBox.new();spin.min_value=LIMITS[key][0];spin.max_value=LIMITS[key][1];spin.step=step;spin.suffix=suffix;spin.custom_minimum_size.x=220;row.add_child(spin);controls[key]=spin
	spin.value_changed.connect(func(value: float):set_option(key,value))
func _sensitivity(page: VBoxContainer) -> void:
	var row:=_row(page,"마우스 감도")
	sensitivity_slider=HSlider.new();sensitivity_slider.min_value=LIMITS.sensitivity[0];sensitivity_slider.max_value=LIMITS.sensitivity[1];sensitivity_slider.step=.01;sensitivity_slider.custom_minimum_size.x=180;sensitivity_slider.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(sensitivity_slider)
	var spin:=SpinBox.new();spin.min_value=LIMITS.sensitivity[0];spin.max_value=LIMITS.sensitivity[1];spin.step=.01;spin.custom_minimum_size.x=110;row.add_child(spin);controls.sensitivity=spin
	spin.tooltip_text="기본 1.00 · 0.50은 절반, 2.00은 두 배 속도 · 숫자를 직접 입력할 수 있습니다."
	sensitivity_slider.tooltip_text=spin.tooltip_text
	sensitivity_slider.value_changed.connect(func(value: float):set_option("sensitivity",value))
	spin.value_changed.connect(func(value: float):set_option("sensitivity",value))
	var reset:=Button.new();reset.text="기본 1.00";reset.pressed.connect(func():set_option("sensitivity",1.0));row.add_child(reset)
func _check(page: VBoxContainer,title: String,key: String) -> void:
	var row:=_row(page,title);var check:=CheckBox.new();check.text="사용";check.custom_minimum_size.x=220;row.add_child(check);controls[key]=check
	check.toggled.connect(func(value: bool):set_option(key,value))
func _build() -> void:
	overlay=ColorRect.new();overlay.focus_mode=Control.FOCUS_ALL;overlay.color=Color(0.02,.035,.055,1);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(overlay)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,28)
	overlay.add_child(margin)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",14);margin.add_child(column)
	var theme:=Theme.new();var font:=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf");font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):550.0};theme.default_font=font;theme.default_font_size=20
	for type in ["Label","Button","CheckBox","OptionButton","LineEdit","TabContainer"]:
		for name_value in ["font_color","font_selected_color","font_hover_color","font_focus_color"]:theme.set_color(name_value,type,Color("e6f0ee"))
		theme.set_color("font_unselected_color",type,Color("afc2c7"))
	for type in ["Button","OptionButton","LineEdit"]:
		for state in ["normal","hover","pressed","focus"]:
			var style:=StyleBoxFlat.new();style.bg_color=Color("263f4d") if state=="hover" else Color("162c39");style.border_color=Color("72ccbd") if state in ["focus","hover"] else Color("44616d");style.set_border_width_all(1);style.set_corner_radius_all(5);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=6;style.content_margin_bottom=6;theme.set_stylebox(state,type,style)
	var background:=StyleBoxFlat.new();background.bg_color=Color("101f2a");background.content_margin_left=14;background.content_margin_right=14;background.content_margin_top=14;background.content_margin_bottom=14;theme.set_stylebox("panel","TabContainer",background)
	overlay.theme=theme
	var heading:=Label.new();heading.text="설정   /   SETTINGS";heading.add_theme_font_size_override("font_size",28);column.add_child(heading)
	var subtitle:=Label.new();subtitle.text="개인 PC 설정 · 즉시 적용 및 자동 저장 · INK 카툰 표현 유지";column.add_child(subtitle)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	var graphics:=_page("그래픽 · 시야거리")
	_choice(graphics,"그래픽 프리셋","preset",["성능 우선","균형","높음","사용자 설정"],[0,1,2,3])
	_number(graphics,"지형 시야거리 · 원경 생성 범위","view_distance",200,"m")
	_number(graphics,"3D 렌더 배율 · UI 선명도 유지","scale",.05,"×")
	_choice(graphics,"해상도 업스케일 · 배율 1 미만에서 유용","upscaler",["Bilinear · 기본","FSR 1.0"],[0,1])
	_number(graphics,"FSR 선명화 감쇠 · 낮을수록 선명","sharpness",.1)
	_choice(graphics,"MSAA · 기하 경계 계단 완화","msaa",["끔","2×","4×","8×"],[0,1,2,3])
	_check(graphics,"FXAA · 빠른 화면 계단 완화","fxaa")
	_check(graphics,"TAA · 잔상 발생 가능","taa")
	_number(graphics,"모델 LOD 허용 오차 · 높을수록 가벼움","lod",1,"px")
	_check(graphics,"태양 그림자","shadows")
	_choice(graphics,"태양 그림자 해상도","shadow_size",["1024 · 성능","2048 · 균형","4096 · 높음"],[1024,2048,4096])
	_choice(graphics,"그림자 필터 · 높을수록 부드럽고 무거움","shadow_filter",["Hard","Soft 매우 낮음","Soft 낮음","Soft 중간","Soft 높음","Soft 최고"],[0,1,2,3,4,5])
	_number(graphics,"태양 그림자 표시 거리","shadow_distance",20,"m")
	_check(graphics,"실내·손전등 그림자","local_shadows")
	_choice(graphics,"실내·손전등 그림자 아틀라스","local_shadow_size",["1024","2048","4096"],[1024,2048,4096])
	for item in [["접지 음영 · SSAO","ssao"],["화면 간접광 · SSIL","ssil"],["화면 반사 · SSR","ssr"],["발광 번짐 · Glow","glow"]]:_check(graphics,item[0],item[1])
	_number(graphics,"대기 안개 강도 · 0이면 끔","fog",.1,"×")
	var display:=_page("화면 · 성능")
	_choice(display,"화면 모드 · 15초 확인 후 유지","window_mode",["창 모드","최대화 창","전체 화면"],[0,1,2])
	_choice(display,"창 해상도 · 창 모드에서 적용","resolution",["1280 × 800","1280 × 720","1600 × 900","1920 × 1080","2560 × 1440"],[0,1,2,3,4])
	_check(display,"수직 동기화 · 화면 찢어짐 방지","vsync")
	_choice(display,"최대 프레임 · VSync가 더 낮게 제한 가능","fps",["무제한","30 FPS","60 FPS","90 FPS","120 FPS","144 FPS","240 FPS"],[0,30,60,90,120,144,240])
	_check(display,"FPS·프레임 시간 표시","show_fps")
	var input:=_page("조작 · 소리")
	_choice(input,"플레이 가이드","tutorial_mode",["처음 플레이어만","항상 표시","끄기"],[0,1,2])
	_number(input,"시야각 · 시야거리와 별도","fov",1,"°")
	_sensitivity(input)
	_check(input,"마우스 세로 반전","invert_y")
	_number(input,"전체 음량","volume",.05)
	_number(input,"배경음악 음량","music_volume",.05)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="시야거리는 원경 범위입니다. 굴착 지형·생물의 활성 범위는 게임 규칙을 따릅니다.";column.add_child(notice)
	var buttons:=HBoxContainer.new();column.add_child(buttons)
	for entry in [["닫기 · Esc / F10",close],["화면 변경 유지",func():display_previous.clear();notice.text="화면 설정을 저장했습니다." if save_settings() else "설정 저장 실패"],["기본값 복원",func():
		if not display_previous.is_empty():_revert_display()
		var mode: Variant=values.window_mode;var resolution: Variant=values.resolution
		values=DEFAULTS.duplicate();values.window_mode=mode;values.resolution=resolution;apply_all();notice.text="화면 모드를 제외한 기본값을 복원했습니다." if save_settings() else "설정 저장 실패";_sync()]]:
		var button:=Button.new();button.text=entry[0];button.pressed.connect(entry[1]);buttons.add_child(button)
	fps_label=Label.new();fps_label.position=Vector2(12,8);fps_label.theme=theme;fps_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(fps_label)
	_sync();overlay.hide()
	_apply_display()

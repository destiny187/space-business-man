class_name FrontierFirstDeparture
extends Control
var app: FrontierCrewExpedition
var letter: ColorRect
var depart: Button
var checked_world: String=""
var seen:=ConfigFile.new()
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seen.load("user://welcome_letters.cfg")
	depart=Button.new();depart.text="출격하기  [G]";depart.custom_minimum_size=Vector2(240,52);depart.add_theme_font_size_override("font_size",21);add_child(depart)
	depart.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);depart.offset_left=-120;depart.offset_right=120;depart.offset_top=-100;depart.offset_bottom=-48
	depart.pressed.connect(func():app.navigation_ui.open_galaxy());depart.hide()
	letter=ColorRect.new();letter.color=Color(.015,.035,.055,.72);letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(letter);letter.hide()
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);letter.add_child(center)
	var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(minf(570,app.get_viewport().get_visible_rect().size.x-40),0);center.add_child(panel)
	var paper:=StyleBoxFlat.new();paper.bg_color=Color("e9e3d3");paper.border_color=Color("689b9d");paper.set_border_width_all(2);paper.set_corner_radius_all(8);paper.set_content_margin_all(30);panel.add_theme_stylebox_override("panel",paper)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",20);panel.add_child(box)
	var stamp:=Label.new();stamp.text="지구 발신  /  첫 항해를 앞둔 당신에게";stamp.add_theme_color_override("font_color",Color("376569"));stamp.add_theme_font_size_override("font_size",16);box.add_child(stamp)
	var title:=Label.new();title.text="당신의 첫 사업을 응원합니다.";title.add_theme_color_override("font_color",Color("203b43"));title.add_theme_font_size_override("font_size",25);box.add_child(title)
	var text:=Label.new();text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size.x=panel.custom_minimum_size.x-60;text.text="안녕하세요, 개척자님.\n이 우주선과 함께 당신만의 사업을 시작해 보세요.\n\n먼저 태양계를 천천히 둘러보세요.\n태양계는 보호 대상이라 착륙·테라포밍할 수 없습니다.\n마우스로 시선을 돌리고 W/S로 비행할 수 있어요.\n행성을 잠시 바라보면 스캔 결과가 나타납니다.\n\n준비가 되면 ‘출격하기’를 눌러 주세요.\n은하 지도에서 항속거리 안의 별을 선택해 출발하세요.\n\n— 당신의 첫 사업을 응원하는 지구 개척 지원팀";text.add_theme_color_override("font_color",Color("30474c"));text.add_theme_font_size_override("font_size",18);box.add_child(text)
	var close:=Button.new();close.text="편지 접기 · 태양계 둘러보기";close.custom_minimum_size.y=46;box.add_child(close)
	close.pressed.connect(func():
		seen.set_value("read",checked_world,true);seen.save("user://welcome_letters.cfg");letter.hide();app.cursor_released=false;app.get_viewport().gui_release_focus())
func update_snapshot(value: Dictionary) -> void:
	var nav: Dictionary=value.crew.navigation
	var solar: bool=int(nav.system)==0 and value.crew.get("landing",{}).is_empty()
	var key: String=value.galaxy_id+":"+value.self_id
	if checked_world!=key:
		checked_world=key
		if solar and not bool(seen.get_value("read",key,false)):letter.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	depart.visible=value.get("local_shuttle","").is_empty() and value.crew.get("landing",{}).is_empty() and nav.mode=="idle" and not letter.visible
	depart.disabled=false
	depart.text=("출격하기  [G]" if solar else "고속 항해  [G]")

func _process(_delta: float) -> void:
	if app!=null and (app.any_menu_open() or FrontierClientSettings.ensure(get_tree()).is_open()):depart.hide()

class_name FrontierFieldHud
extends Control
var scan_card: FrontierSurveyCard
var instruments: FrontierFieldInstruments
var app: FrontierCrewExpedition
var place: Label
var location: Label
var return_label: Label
var ship_direction: TextureRect
var context: PanelContainer
var target_name: Label
var target_action: Label
var target_icon: TextureRect
var target_bar: ProgressBar
var equipment_name: Label
var cooldown: ProgressBar
var navigation: HBoxContainer
var saved: Label
var toast: PanelContainer
var toast_label: Label
var toast_left:=0.0
var save_left:=0.0
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;theme=FrontierInterfaceStyle.theme();mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	instruments=FrontierFieldInstruments.new();add_child(instruments);instruments.configure(app)
	scan_card=FrontierSurveyCard.new();scan_card.configure(app);add_child(scan_card)
	var heading:=VBoxContainer.new();heading.position=Vector2(32,28);heading.add_theme_constant_override("separation",4);heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
	place=FrontierInterfaceStyle.label(heading,"",24);location=FrontierInterfaceStyle.label(heading,"",12,Color("d0d6ce"))
	var compass:=HBoxContainer.new();compass.name="Compass";compass.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(compass);ship_direction=TextureRect.new();ship_direction.texture=load("res://assets/ui/interface/ship.svg");ship_direction.custom_minimum_size=Vector2(22,22);compass.add_child(ship_direction);return_label=FrontierInterfaceStyle.label(compass,"",13)
	saved=FrontierInterfaceStyle.label(self,"✓",16,FrontierInterfaceStyle.ACCENT)
	context=PanelContainer.new();context.mouse_filter=Control.MOUSE_FILTER_IGNORE;context.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(Color("10191fdb"),Color("31434d00"),10));add_child(context)
	var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;context.add_child(row)
	target_icon=TextureRect.new();target_icon.custom_minimum_size=Vector2(36,36);target_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;target_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;target_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(target_icon)
	var labels:=VBoxContainer.new();labels.add_theme_constant_override("separation",4);labels.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(labels)
	target_name=FrontierInterfaceStyle.label(labels,"",15);target_action=FrontierInterfaceStyle.label(labels,"",12,FrontierInterfaceStyle.ACCENT)
	target_bar=ProgressBar.new();target_bar.show_percentage=false;target_bar.custom_minimum_size=Vector2(190,3);labels.add_child(target_bar)
	var weapon:=VBoxContainer.new();weapon.name="Weapon";weapon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(weapon)
	equipment_name=FrontierInterfaceStyle.label(weapon,"",14);cooldown=ProgressBar.new();cooldown.show_percentage=false;cooldown.custom_minimum_size=Vector2(170,3);weapon.add_child(cooldown)
	navigation=HBoxContainer.new();navigation.add_theme_constant_override("separation",5);add_child(navigation)
	var rows: Array=[["inventory","I","아이템 · 장비",app.toggle_inventory],["build","B","건설",app.toggle_business],["scan","J","연구",app.toggle_research],["ship","Tab","지도",app.toggle_navigation]]
	for entry in rows:
		var button:=Button.new();button.custom_minimum_size=Vector2(46,46);button.tooltip_text=entry[2]+" ["+entry[1]+"]";button.pressed.connect(entry[3]);navigation.add_child(button)
		var icon:=TextureRect.new();icon.texture=load("res://assets/ui/interface/"+entry[0]+".svg");icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.position=Vector2(12,5);icon.size=Vector2(22,22);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;button.add_child(icon)
		var key:=FrontierInterfaceStyle.label(button,entry[1],10,FrontierInterfaceStyle.MUTED);key.position=Vector2(0,29);key.size.x=46;key.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	app.session.response_received.connect(func(_seq: int,result: Dictionary):
		if result.get("ok",false):save_left=.7;toast_left=0)
	toast=PanelContainer.new();toast.theme=theme;toast.mouse_filter=Control.MOUSE_FILTER_IGNORE;toast.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.WARNING,12));get_parent().add_child(toast)
	toast_label=FrontierInterfaceStyle.label(toast,"",13,FrontierInterfaceStyle.WARNING);toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;toast_label.custom_minimum_size.x=360;toast.hide()
	app.session.response_received.connect(func(_seq: int,result: Dictionary):
		if result.get("code")=="mining_cooldown":return
		if not result.get("ok",false):toast_label.text=str(result.get("error","실행할 수 없습니다."));toast_left=4)
	for label in [place,location,return_label,equipment_name]:
		label.add_theme_color_override("font_shadow_color",Color("081218e0"));label.add_theme_constant_override("shadow_offset_y",1);label.add_theme_constant_override("shadow_offset_x",1)
	get_viewport().size_changed.connect(_layout);_layout()
func _layout() -> void:
	var size:=get_viewport().get_visible_rect().size
	get_node("Compass").position=Vector2(size.x/2-45,26);saved.position=Vector2(size.x-230,28)
	navigation.position=Vector2(28,size.y-68);get_node("Weapon").position=Vector2(size.x-200,size.y-63)
func _process(delta: float) -> void:
	toast_left=maxf(0,toast_left-delta)
	toast.visible=app.surface_world!=null and toast_left>0
	toast.position=Vector2((get_viewport().get_visible_rect().size.x-toast.size.x)/2,32)
	var on_surface: bool=app.session.active and app.surface_world!=null
	app.status.get_parent().visible=not app.session.active
	app.navigation_toggle.get_parent().visible=false
	visible=on_surface and app.feedback!=null and not app.feedback.blocked()
	if not visible:return
	save_left=maxf(0,save_left-delta);saved.visible=save_left>0
	var position: Vector3=app.actors[app.session.latest.self_id].position
	place.text=app.surface_world.body.name
	location.text="지표 탐사" if position.y>=-5 else "지하  %.0f m"%absf(position.y)
	var ship:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	return_label.text="%.0f m"%position.distance_to(ship)
	var tool:=FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id])
	equipment_name.text=tool.get("name","I  장비 준비")
	cooldown.value=100*(1-clampf(app.dig_timer/maxf(.1,float(tool.get("interval",1))),0,1))
	context.hide();target_bar.hide()
	var target:=app.surface_world.business_view.target(app.camera,app.actors[app.session.latest.self_id])
	if target.get("kind")=="vein":
		var vein:=FrontierExpeditionBusiness.find_vein(app.surface_world.body,target.id)
		target_icon.texture=FrontierResourceIcons.texture(vein.resource);target_name.text=FrontierCatalog.entry("resources",vein.resource).name+" 광맥"
		var usable: bool=tool.get("kind")=="miner" and int(tool.get("tier",0))>=int(vein.required_tier)
		target_action.text="클릭 유지  채집" if usable else "채집기 %s 필요"%["I","II","III"][int(vein.required_tier)-1]
		target_action.modulate=Color.WHITE if usable else FrontierInterfaceStyle.WARNING
		var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(app.surface_world.body.id,{})
		if site.is_empty():target_action.text="광맥 조준 · 클릭 유지로 채집"
		else:target_bar.show();target_bar.max_value=vein.capacity;target_bar.value=site.get("remaining",{}).get(vein.id,vein.capacity)
		target_action.text+=" · E 유지  조사"
		context.show()
	elif not app.surface_target.is_empty():
		var form:=FrontierEcologyCatalog.form(app.surface_target.form_id)
		target_name.text=form.name;target_icon.texture=FrontierResourceIcons.texture(FrontierResourceIcons.specimen_id(form))
		var known: bool=app.session.surface.ecology.observations.has(app.surface_world.body.id+":"+form.id)
		target_action.text="Q  표본 채집 · E  활용 정보" if known else "E 유지  스캔";target_action.modulate=Color.WHITE;context.show()
		if form.category=="animal" and tool.get("kind")=="pulse":
			target_bar.show();target_bar.max_value=FrontierEquipment.config().animal_health;target_bar.value=app.session.latest.crew.get("combat",{}).get(app.surface_world.body.id+"/"+str(app.surface_target.id),target_bar.max_value)
			target_action.text="클릭  발사" if target_bar.value>0 else "무력화"
	elif not target.is_empty():
		var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(app.surface_world.body.id,{})
		var row: Dictionary=site.get("buildings",{}).get(target.id,{})
		target_name.text="현장 창고" if target.get("kind")=="base" else ("M-01 로봇" if target.get("kind")=="robot" else FrontierCatalog.entry("buildings",row.get("type","")).get("name","회수 화물"))
		target_icon.texture=load("res://assets/ui/interface/build.svg");target_action.text="F  로봇 제작소" if row.get("type","")=="factory" else "F  열기";target_action.modulate=Color.WHITE;context.show()
	var size:=get_viewport().get_visible_rect().size
	context.position=Vector2(size.x/2+24,size.y/2+36)

	if scan_card.visible:context.hide()

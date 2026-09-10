class_name FrontierSurveyCard
extends PanelContainer
## Short visual result from the host. Displays no speculative trait as an implemented bonus.
var app: FrontierCrewExpedition
var content: VBoxContainer
var title: Label
var subtitle: Label
var icon: TextureRect
var facts: VBoxContainer
var condition: Label
var action: Label
var timer:=0.0
var previous:=""
var displayed: Dictionary={}
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;mouse_filter=Control.MOUSE_FILTER_IGNORE;theme=FrontierInterfaceStyle.theme()
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(Color("10191fe8"),Color.TRANSPARENT,12))
	content=VBoxContainer.new();content.add_theme_constant_override("separation",7);content.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(content)
	var header:=HBoxContainer.new();header.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(header)
	icon=TextureRect.new();icon.custom_minimum_size=Vector2(40,40);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;header.add_child(icon)
	var names:=VBoxContainer.new();names.mouse_filter=Control.MOUSE_FILTER_IGNORE;header.add_child(names)
	title=FrontierInterfaceStyle.label(names,"",17);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.custom_minimum_size.x=260
	subtitle=FrontierInterfaceStyle.label(names,"",12,FrontierInterfaceStyle.MUTED);subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;subtitle.custom_minimum_size.x=260
	facts=VBoxContainer.new();facts.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(facts)
	condition=FrontierInterfaceStyle.label(content,"",12,FrontierInterfaceStyle.MUTED);condition.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;condition.custom_minimum_size.x=305
	action=FrontierInterfaceStyle.label(content,"",12,FrontierInterfaceStyle.ACCENT)
	hide()
func present(info: Dictionary) -> void:
	displayed=info.duplicate(true)
	z_index=5 if info.kind=="corporation" else 0
	title.text=info.name;subtitle.text=info.subtitle;icon.texture=FrontierResourceIcons.texture(info.icon)
	if info.kind=="corporation":icon.texture=load(FrontierCorporations.icon_path(info.company))
	for child in facts.get_children():facts.remove_child(child);child.queue_free()
	if info.has("asset"):FrontierCorporateIdentity.add_to(facts,info.asset)
	for note in info.notes:
		var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;facts.add_child(row)
		var glyph:=TextureRect.new();glyph.texture=load("res://assets/ui/interface/"+str(note.icon)+".svg");glyph.custom_minimum_size=Vector2(20,20);glyph.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;glyph.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(glyph)
		var label:=FrontierInterfaceStyle.label(row,note.text,13);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=280
	condition.text=info.condition;action.text=info.get("action","")+"  J  조사 기록"
func _process(delta: float) -> void:
	if app.session.latest.is_empty():hide();return
	var scan: Dictionary=app.session.latest.get("scan",{})
	if scan.get("known",false) and scan.has("info"):
		var token:=JSON.stringify(scan.info)
		if token!=previous:
			var new_subject: bool=displayed.get("id","")!=scan.get("id","")
			present(scan.info)
			if new_subject and scan.info.kind=="mineral":app.feedback.audio.play("ui_discovery")
			previous=token
		timer=4
	else:
		if float(scan.get("progress",0))>0:timer=0
		timer=maxf(0,timer-delta)
		if timer<=0:previous=""
	visible=timer>0
	position=Vector2(28,194 if displayed.get("kind")=="corporation" else 110)
	if displayed.get("kind")!="corporation" and size.y>get_viewport().get_visible_rect().size.y-275:position.y=85

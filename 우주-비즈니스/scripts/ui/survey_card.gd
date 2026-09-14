class_name FrontierSurveyCard
extends PanelContainer
## Short visual result from the host. Displays no speculative trait as an implemented bonus.
const RESULT_SECONDS:=4.0
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
var target_point:=Vector3.INF
var anchor:=Vector2.ZERO
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;mouse_filter=Control.MOUSE_FILTER_IGNORE;theme=FrontierInterfaceStyle.theme()
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(Color.TRANSPARENT,Color.TRANSPARENT,12))
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
	z_index=5
	target_point=FrontierCrewWorld.vector(info.point) if info.has("point") else Vector3.INF
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
	if app.session.latest.is_empty():timer=0;previous="";hide();return
	var scan: Dictionary=app.session.latest.get("scan",{})
	var token: String=""
	if scan.get("known",false) and scan.has("info"):
		token=str(app.session.latest.get("session_id",""))+"/"+str(app.session.latest.get("location",""))+"/"+str(scan.info.kind)+"/"+str(scan.get("id",""))
	if app.surface_world==null or app.feedback==null or app.feedback.blocked():
		# Consume a stale snapshot while blocked; reopening a menu is not a scan.
		timer=0;previous=token;hide();return
	timer=maxf(0,timer-delta)
	if not token.is_empty():
		if token!=previous:
			var new_subject: bool=displayed.get("id","")!=scan.get("id","")
			present(scan.info)
			if new_subject and scan.info.kind=="mineral":app.feedback.audio.play("ui_discovery")
			previous=token
			timer=RESULT_SECONDS
	else:
		previous=""
		if float(scan.get("progress",0))>0:timer=0
	visible=timer>0
	if not target_point.is_finite() or app.camera.is_position_behind(target_point):hide();return
	if app.surface_world.ecology.actors.has(displayed.get("id","")):
		target_point=app.surface_world.ecology.actors[displayed.id].global_position+Vector3.UP*.7
	var screen:=get_viewport().get_visible_rect().size
	var projected:=app.camera.unproject_position(target_point)
	if not Rect2(Vector2.ZERO,screen).has_point(projected):hide();return
	position=Vector2(clampf(projected.x+48,16,screen.x-size.x-16),clampf(projected.y-size.y*.5,72,maxf(72,screen.y-size.y-100)))
	anchor=projected-position
	queue_redraw()
func _draw() -> void:
	if visible:FrontierSpaceGuidance.readout(self,Rect2(Vector2.ZERO,size),anchor)

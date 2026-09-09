class_name FrontierEnvironmentHud
extends VBoxContainer
## A read-only view of the host's local environment, never the legacy sale score.
var app: FrontierCrewExpedition
var title: Button
var bar: ProgressBar
var state: Label
var warning: Label
var details: VBoxContainer
var raw: Label
var bars: Dictionary={}
var values: Dictionary={}
var report: Dictionary={}
var refresh_left:=0.0
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;custom_minimum_size.x=280;mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",3)
	title=Button.new();title.flat=true;title.alignment=HORIZONTAL_ALIGNMENT_LEFT;title.add_theme_font_size_override("font_size",14);title.focus_mode=Control.FOCUS_NONE;title.text="환경 적합도  평가 중  [H]";add_child(title);title.pressed.connect(toggle_details)
	bar=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size=Vector2(280,8);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background",FrontierInterfaceStyle.box(Color("18262ee0"),Color.TRANSPARENT,3))
	bar.add_theme_stylebox_override("fill",FrontierInterfaceStyle.box(FrontierInterfaceStyle.ACCENT,Color.TRANSPARENT,3));add_child(bar)
	state=FrontierInterfaceStyle.label(self,"지역 환경  관측 대기",11,FrontierInterfaceStyle.MUTED)
	warning=FrontierInterfaceStyle.label(self,"",12,FrontierInterfaceStyle.WARNING)
	details=VBoxContainer.new();details.add_theme_constant_override("separation",3);details.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(details);details.hide()
	for entry in [["atmosphere","대기","atmosphere"],["temperature","온도","thermal"],["water","물","water"],["ecology","생태","biolab"]]:
		var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_child(row)
		var icon:=TextureRect.new();icon.texture=load("res://assets/ui/previews/"+entry[2]+".png");icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(28,25);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(icon)
		var label:=FrontierInterfaceStyle.label(row,entry[1],12);label.custom_minimum_size.x=35
		var item:=ProgressBar.new();item.show_percentage=false;item.custom_minimum_size=Vector2(150,6);item.size_flags_vertical=Control.SIZE_SHRINK_CENTER;item.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(item);bars[entry[0]]=item
		var value:=FrontierInterfaceStyle.label(row,"—",12);value.custom_minimum_size.x=33;value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;values[entry[0]]=value
	raw=FrontierInterfaceStyle.label(details,"",11,Color("d0d6ce"));raw.custom_minimum_size.x=280;raw.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for label in [state,warning,raw]:
		label.add_theme_color_override("font_shadow_color",Color("081218e0"));label.add_theme_constant_override("shadow_offset_y",1)
func toggle_details() -> void:
	details.visible=not details.visible;refresh_left=0
func _process(delta: float) -> void:
	if not is_visible_in_tree() or app.surface_world==null:return
	refresh_left-=delta
	if refresh_left>0:return
	refresh_left=.25
	var id: String=app.surface_world.body.id
	var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(id,{})
	report=FrontierEvaluator.environment_report(site,id)
	bar.visible=report.observed;warning.visible=false
	if not report.observed:
		title.text="환경 적합도  평가 중  [H]";state.text="지역 환경  관측 대기";raw.text="착륙선에서 지역 개발을 등록하면 관측합니다."
		for key in bars:bars[key].hide();values[key].text="—"
		return
	title.text="환경 적합도 %.0f%%  [H]"%report.overall;bar.value=report.overall
	state.text="지역 환경  "+("✓ 안정" if report.stable else "◷ 관찰 중  %.0f / %.0f초"%[report.stable_seconds,report.stable_required])
	if not report.limiting_factors.is_empty():warning.text="! "+str(report.limiting_factors[0].label);warning.show()
	for key in bars:
		bars[key].show();bars[key].value=report.scores[key];values[key].text="%.0f"%report.scores[key]
	var e: Dictionary=site.environment
	raw.text="%.1f°C  %.2f bar  산소 %.1f%%"%[float(e.temperature),float(e.pressure),float(e.oxygen)*100]
	if site.has("restoration2"):raw.text+="\n염류 %.0f  토양 %.0f"%[float(site.restoration2.salinity),float(site.restoration2.soil)]

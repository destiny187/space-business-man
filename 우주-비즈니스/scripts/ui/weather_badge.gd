class_name FrontierWeatherBadge
extends Control
var state: Dictionary={}
var strength:=0.0
var warning: Label
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning=Label.new();warning.theme=FrontierInterfaceStyle.theme();warning.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;warning.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);warning.offset_top=112;warning.offset_bottom=145;warning.add_theme_color_override("font_color",Color("ffd29b"));FrontierInterfaceStyle.hud_shadow(warning);warning.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(warning)
func accept(value: Dictionary,amount: float) -> void:
	state=value;strength=amount;queue_redraw()
	if warning==null:return
	var e: Dictionary=state.get("event",{});var personal: Dictionary=state.get("personal",{})
	warning.text=""
	if e.is_empty():return
	var clock:=float(state.get("clock",0));var kind:=str(e.kind)
	if kind!="rain" and clock<float(e.start):warning.text="%s  ·  %.0f초 후   %s"%["산성비" if kind=="acid" else "뇌우",float(e.start)-clock,"지붕·동굴을 확인하세요" if kind=="acid" else "낙뢰 표식을 살피세요"]
	elif strength>.1 and kind=="acid" and float(personal.get("exposure",0))>2:warning.text="산성비 노출  ·  지붕 아래로 이동"
func _draw() -> void:
	var e: Dictionary=state.get("event",{})
	if e.is_empty():return
	var p:=Vector2(size.x-44,202);var tint:=Color("8edacb") if e.kind=="rain" else Color("f1bd7f")
	draw_circle(p,20,Color("101b25cc"));draw_arc(p,20,-PI/2,TAU-PI/2,40,Color("718f98"),1.3,true)
	# Open cloud contour and individual drops remain readable on small screens.
	draw_arc(p+Vector2(-6,-3),5,PI*.6,PI*1.5,14,tint,2,true);draw_arc(p+Vector2(1,-6),7,PI,TAU,18,tint,2,true);draw_arc(p+Vector2(8,-2),5,-PI*.6,PI*.5,14,tint,2,true);draw_line(p+Vector2(-8,3),p+Vector2(10,3),tint,2,true)
	if e.kind=="thunder":draw_polyline(PackedVector2Array([p+Vector2(3,4),p+Vector2(-2,10),p+Vector2(3,10),p+Vector2(-1,16)]),tint,2,true)
	else:
		for x in [-7,0,7]:draw_line(p+Vector2(x,7),p+Vector2(x-2,12),tint,2,true)
	var personal: Dictionary=state.get("personal",{})
	var exposure:=clampf(float(personal.get("exposure",0))/float(FrontierPlanetWeather.config().acid_grace),0,1)
	if exposure>0:draw_arc(p,23,-PI/2,-PI/2+TAU*exposure,40,Color("efa873"),2.5,true)
	if (personal.get("lightning_sheltered",false) or personal.get("grounded",false)) if e.kind=="thunder" else personal.get("sheltered",false):draw_polyline(PackedVector2Array([p+Vector2(12,14),p+Vector2(17,18),p+Vector2(23,10)]),Color("a0f0c0"),2,true)

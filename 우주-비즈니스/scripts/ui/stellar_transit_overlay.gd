extends Control
var nav: Dictionary={}
var arrival_name: String=""
var arrival_detail: String=""
var arrival_age: float=100.0
var clock:=0.0
var scan_body: Dictionary={}
var scan_progress:=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(delta: float) -> void:
	clock+=delta;arrival_age+=delta;queue_redraw()
func _draw() -> void:
	if nav.is_empty():return
	var font:=get_theme_default_font()
	var center:=size*.5
	_draw_arrival(font)
	_draw_vitals(font)
	if nav.get("star_warning",false):
		var danger: bool=nav.get("star_danger",false)
		var color:=Color(1,.25,.12) if danger else Color(1,.7,.25)
		var message: String="항성 열기 · 선체 손상! 즉시 이탈하세요" if danger else "항성 접근 경고 · 안전거리를 유지하세요"
		if nav.get("emergency_escape",false):message="비상 추진 · 항성 위험 구간에서 이탈 중"
		var box:=Rect2(Vector2(size.x*.5-260,32),Vector2(520,52))
		draw_rect(box,Color(.12,.025,.01,.85));draw_rect(box,color,false,2)
		draw_string(font,box.position+Vector2(18,33),message,HORIZONTAL_ALIGNMENT_LEFT,484,19,color)
		if danger:draw_rect(Rect2(Vector2.ONE*3,size-Vector2.ONE*6),Color(1,.15,.03,.2+.15*sin(clock*5)),false,6)
	if nav.mode=="jump":
		var p: float=nav.get("transit",{}).get("progress",0.0)
		var strength:=smoothstep(.10,.3,p)*(1.0-smoothstep(.72,1.0,p))
		draw_rect(Rect2(Vector2.ZERO,size),Color(.015,.045,.09,strength*.40))
		for i in 96:
			var angle:=float(i)*2.399963
			var radius:=fmod(float(i)*.173+clock*(.12+strength*.8),1.0)
			var ray:=Vector2(cos(angle),sin(angle))
			var point:=center+ray*radius*size.length()*.55
			draw_line(point,point+ray*(12+strength*170)*radius,Color(.45,.85,1,strength*radius*.8),1.5,true)
		var width:=minf(440,size.x*.6)
		var origin:=Vector2(center.x-width*.5,size.y-95)
		draw_rect(Rect2(origin,Vector2(width,4)),Color(.12,.25,.32))
		draw_rect(Rect2(origin,Vector2(width*p,4)),Color(.4,.94,1))
		draw_string(font,origin+Vector2(0,-15),FrontierCrewNavigation.phase(nav),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color(.8,.95,1))
		draw_string(font,origin+Vector2(0,27),"%.0f%% · %.1f초 · 에너지 자동 공급" % [p*100,float(nav.jump_left)],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(.7,.83,.9))
	else:
		draw_arc(center,5,0,TAU,24,Color(.7,.95,1,.8),1.5,true)
		_draw_scan(font,center)
		if nav.get("boundary",false):draw_string(font,Vector2(24,size.y-72),"항성계 외곽 — 항법도에서 성간 항해를 설정하세요",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(1,.76,.4))

func _draw_scan(font: Font,center: Vector2) -> void:
	if scan_body.is_empty():return
	var cyan:=Color(.45,.94,1,.95)
	draw_arc(center,22,-PI*.5,TAU-PI*.5,64,Color(.2,.5,.6,.35),3,true)
	draw_arc(center,22,-PI*.5,TAU*scan_progress-PI*.5,64,cyan,3,true)
	if scan_progress<1.0:
		draw_string(font,center+Vector2(-38,44),"분석 중",HORIZONTAL_ALIGNMENT_LEFT,-1,15,cyan);return
	var width:=minf(420,size.x*.46)
	var pointer:=center if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else get_local_mouse_position()
	if not Rect2(Vector2.ZERO,size).has_point(pointer):pointer=center
	var box:=Rect2(Vector2(clampf(pointer.x+42,16,size.x-width-16),maxf(16,pointer.y-215)),Vector2(width,183))
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.10,.15,.88);style.border_color=Color(.35,.86,1,.7);style.set_border_width_all(1);style.set_corner_radius_all(9)
	draw_style_box(style,box)
	draw_polyline(PackedVector2Array([pointer+Vector2(18,-18),box.position+Vector2(-12,130),box.position+Vector2(0,130)]),cyan,1.5,true)
	for i in 15:draw_line(box.position+Vector2(1,i*10+5),box.position+Vector2(width-1,i*10+5),Color(.3,.8,1,.035),1)
	var origin:=box.position+Vector2(18,27)
	draw_string(font,origin,"스캔 완료",HORIZONTAL_ALIGNMENT_LEFT,width-36,14,cyan)
	draw_string(font,origin+Vector2(0,33),scan_body.name,HORIZONTAL_ALIGNMENT_LEFT,width-36,27,Color(.88,.98,1))
	var description:=FrontierUniverse.kind_label(scan_body)+" · T%d"%int(scan_body.planet_tier)
	if scan_body.get("origin","")=="solar_reference":description="태양계 · 테라포밍 불가 행성"
	elif not FrontierUniverse.landable(scan_body):description+=" · 착륙 불가"
	else:description+=" · 테라포밍 가능"
	draw_string(font,origin+Vector2(0,68),description,HORIZONTAL_ALIGNMENT_LEFT,width-36,17,Color(.7,.85,.9))
	draw_string(font,origin+Vector2(0,99),FrontierPlanetTraits.describe(scan_body),HORIZONTAL_ALIGNMENT_LEFT,width-36,14,cyan)
	draw_string(font,origin+Vector2(0,132),"E 접근 항해  ·  Tab 항법도",HORIZONTAL_ALIGNMENT_LEFT,width-36,15,cyan)

func _draw_vitals(font: Font) -> void:
	var start:=Vector2(26,size.y-100)
	for index in 2:
		var value: float=float(nav.get("hull" if index==0 else "energy",100.0))
		var point:=start+Vector2(0,index*36)
		var color:=Color(.45,.94,.8) if index==0 else Color(.35,.7,1)
		if value<25:color=Color(1,.4,.2)
		draw_string(font,point,("선체" if index==0 else "추진 에너지")+"  %d"%int(value),HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
		draw_rect(Rect2(point+Vector2(0,8),Vector2(180,5)),Color(.12,.23,.3,.85))
		draw_rect(Rect2(point+Vector2(0,8),Vector2(180*value/100,5)),color)
	if nav.get("boosting",false):draw_string(font,start+Vector2(0,-22),"고속 추진",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(.5,.8,1))
	elif float(nav.get("hull",100))<=0:draw_string(font,start+Vector2(0,-22),"추진 정지 · 응급 수리",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1,.6,.3))

func announce(system_name_value: String,detail: String) -> void:
	arrival_name=system_name_value;arrival_detail=detail;arrival_age=0.0
func _draw_arrival(font: Font) -> void:
	var duration: float=FrontierCelestialNames.rules().arrival_seconds
	if arrival_age>=duration or arrival_name.is_empty():return
	var opacity: float=smoothstep(0.0,1.1,arrival_age)*(1.0-smoothstep(duration-1.8,duration,arrival_age))
	var band: float=minf(110,size.y*.14)*opacity
	draw_rect(Rect2(0,0,size.x,band),Color(.015,.027,.045,.75*opacity))
	draw_rect(Rect2(0,size.y-band,size.x,band),Color(.015,.027,.045,.75*opacity))
	var px:=int(clampf(size.x*.068,32,92))
	while font.get_string_size(arrival_name,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x>size.x*.84 and px>20:px-=1
	var y:=size.y*.36
	draw_string_outline(font,Vector2(size.x*.08,y),arrival_name,HORIZONTAL_ALIGNMENT_CENTER,size.x*.84,px,5,Color(0,.01,.02,opacity*.85))
	draw_string(font,Vector2(size.x*.08,y),arrival_name,HORIZONTAL_ALIGNMENT_CENTER,size.x*.84,px,Color(.91,.97,1,opacity))
	var reach:=size.x*.32*smoothstep(0.1,2.0,arrival_age)
	draw_line(Vector2(size.x*.5-reach,y+26),Vector2(size.x*.5+reach,y+26),Color(.55,.88,.92,opacity*.7),1.5,true)
	draw_string(font,Vector2(size.x*.08,y+61),arrival_detail,HORIZONTAL_ALIGNMENT_CENTER,size.x*.84,int(clampf(size.x*.017,13,22)),Color(.65,.86,.9,opacity))

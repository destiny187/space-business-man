extends Control
var nav: Dictionary={}
var clock:=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(delta: float) -> void:
	clock+=delta;queue_redraw()
func _draw() -> void:
	if nav.is_empty():return
	var font:=get_theme_default_font()
	var center:=size*.5
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
		draw_string(font,Vector2(24,size.y-44),"외부 시점: W/S 전후 · 방향키 선회 · 천체 클릭 선택 · Tab 항법도",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(.75,.9,.94))
		if nav.get("boundary",false):draw_string(font,Vector2(24,size.y-72),"항성계 외곽 — 항법도에서 성간 항해를 설정하세요",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(1,.76,.4))

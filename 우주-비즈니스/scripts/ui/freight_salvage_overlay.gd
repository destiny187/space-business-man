extends Control
var row: Dictionary={}
var carry: Dictionary={}
var markers: Array=[]
var picture: Texture2D
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(FrontierFreightSalvage.ICON):picture=load(FrontierFreightSalvage.ICON)
func _draw() -> void:
	var cyan:=FrontierInterfaceStyle.ACCENT;var muted:=FrontierInterfaceStyle.MUTED;var font:=get_theme_default_font()
	for mark in markers:
		var p: Vector2=mark.point
		if not Rect2(Vector2(16,16),size-Vector2(32,32)).has_point(p):continue
		draw_rect(Rect2(p-Vector2(8,8),Vector2(16,16)),cyan if mark.stage>0 else Color("ffc180"),false,1.5)
		if mark.stage==3:draw_line(p+Vector2(-4,0),p+Vector2(-1,3),cyan,2,true);draw_line(p+Vector2(-1,3),p+Vector2(5,-4),cyan,2,true)
		elif mark.stage==0:draw_string(font,p+Vector2(14,-12),"SOS",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffc180"))
	if not carry.is_empty():
		var at:=Vector2(18,size.y-164);var width:=minf(290,size.x*.36)
		draw_rect(Rect2(at,Vector2(width,86)),Color(.025,.055,.075,.94))
		if picture!=null:draw_texture_rect(picture,Rect2(at+Vector2(4,5),Vector2(78,64)),false)
		draw_string(font,at+Vector2(86,26),"회수 거치대  1 / 1",HORIZONTAL_ALIGNMENT_LEFT,width-92,14,cyan)
		draw_string(font,at+Vector2(86,48),"항만으로 운반 중",HORIZONTAL_ALIGNMENT_LEFT,width-92,12,Color.WHITE)
		draw_string(font,at+Vector2(12,75),carry.port_name,HORIZONTAL_ALIGNMENT_LEFT,width-24,12,muted)
	if row.is_empty():return
	var center:=size*.5;var width:=minf(332,size.x*.42);var at:=Vector2(minf(center.x+48,size.x-width-14),maxf(28,center.y-155))
	draw_rect(Rect2(at,Vector2(width,184)),Color(.025,.055,.075,.96));draw_line(at,at+Vector2(0,184),cyan,2)
	draw_arc(center,32,-PI*.5,-PI*.5+TAU*maxf(.015,float(row.progress)),48,cyan,2,true)
	if picture!=null:draw_texture_rect(picture,Rect2(at+Vector2(3,4),Vector2(70,56)),false)
	draw_string(font,at+Vector2(75,30),row.name if int(row.stage)>0 else "미식별 화물 SOS",HORIZONTAL_ALIGNMENT_LEFT,width-85,16,Color.WHITE)
	for i in 3:draw_circle(at+Vector2(81+i*20,51),4,cyan if int(row.stage)>i else Color("405562"))
	draw_string(font,at+Vector2(14,81),FrontierFreightSalvage.STATES[int(row.stage)],HORIZONTAL_ALIGNMENT_LEFT,width-28,14,cyan)
	draw_string(font,at+Vector2(14,105),FrontierFlightTelemetry.distance_label(float(row.distance)),HORIZONTAL_ALIGNMENT_LEFT,width-28,13,muted)
	draw_string(font,at+Vector2(14,128),row.port_name if int(row.stage)>0 else "송장 식별 후 목적지 확인",HORIZONTAL_ALIGNMENT_LEFT,width-28,12,muted)
	var hint: String=row.reason
	if hint.is_empty():hint="E 유지  "+["송장 식별","윈치로 회수","항만에 인계"][int(row.stage)]
	draw_string(font,at+Vector2(14,162),hint,HORIZONTAL_ALIGNMENT_LEFT,width-28,14,cyan)

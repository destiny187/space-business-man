extends Control
var row: Dictionary={}
var markers: Array=[]
var marks: Dictionary={}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for id in ["lotus","mine","coopertech"]:marks[id]=load(FrontierCorporations.icon_path(id))
func _draw() -> void:
	var cyan:=FrontierInterfaceStyle.ACCENT;var muted:=FrontierInterfaceStyle.MUTED;var font:=get_theme_default_font()
	for mark in markers:
		var p: Vector2=mark.point
		if not Rect2(Vector2(12,12),size-Vector2(24,24)).has_point(p):continue
		draw_arc(p,9,0,TAU,24,cyan if mark.stage>0 else muted,1.5,true)
		if mark.stage==2:draw_line(p+Vector2(-4,0),p+Vector2(-1,3),cyan,2,true);draw_line(p+Vector2(-1,3),p+Vector2(5,-4),cyan,2,true)
		elif mark.stage==0:draw_string(font,p+Vector2(14,-12),"미확인 신호",HORIZONTAL_ALIGNMENT_LEFT,-1,12,muted)
	if row.is_empty():return
	var center:=size*.5;var width:=minf(326,size.x*.4);var at:=Vector2(minf(center.x+52,size.x-width-18),maxf(28,center.y-155))
	draw_rect(Rect2(at,Vector2(width,156)),Color(.025,.055,.075,.94))
	draw_line(at,at+Vector2(0,156),cyan,2)
	draw_arc(center,32,-PI*.5,-PI*.5+TAU*maxf(.015,float(row.progress)),48,cyan,2,true)
	var stage:=int(row.stage)
	if stage>0:draw_texture_rect(marks[row.company],Rect2(at+Vector2(12,12),Vector2(36,36)),false)
	else:draw_arc(at+Vector2(30,30),12,0,TAU,24,muted,2,true)
	draw_string(font,at+Vector2(60,35),row.name if stage>0 else "미확인 활동 신호",HORIZONTAL_ALIGNMENT_LEFT,width-70,16,Color.WHITE)
	for i in 2:
		var p:=at+Vector2(18+i*22,67);draw_circle(p,5,cyan if stage>i else Color("405562"))
	draw_string(font,at+Vector2(60,72),["표식 식별","활동 기록 조사","공동 기록 확보"][stage],HORIZONTAL_ALIGNMENT_LEFT,width-72,14,cyan)
	draw_string(font,at+Vector2(14,101),FrontierFlightTelemetry.distance_label(float(row.distance)),HORIZONTAL_ALIGNMENT_LEFT,width-28,14,muted)
	var hint: String=row.reason
	if hint.is_empty():hint="E 유지  "+("표식 식별" if stage==0 else "활동 기록 읽기")
	draw_string(font,at+Vector2(14,134),hint,HORIZONTAL_ALIGNMENT_LEFT,width-28,14,cyan)

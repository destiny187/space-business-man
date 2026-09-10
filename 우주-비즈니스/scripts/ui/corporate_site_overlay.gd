extends Control
var row: Dictionary={}
var marks: Dictionary={}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for id in ["lotus","space_y","mine","coopertech"]:marks[id]=load("res://assets/ui/corporations/"+id+".svg")
func _draw() -> void:
	if row.is_empty():return
	var font:=get_theme_default_font();var cyan:=Color("9adde0");var center:=size*.5
	draw_arc(center,32,-PI*.5,-PI*.5+TAU*maxf(.02,float(row.progress)),48,cyan,2,true)
	var width:=minf(326,size.x*.36);var origin:=Vector2(minf(center.x+55,size.x-width-18),maxf(30,center.y-168))
	draw_rect(Rect2(origin,Vector2(width,148)),Color(.025,.065,.1,.9));draw_line(origin,origin+Vector2(0,148),cyan,2)
	if float(row.progress)<1:
		draw_string(font,origin+Vector2(16,35),"물류 구조물 식별 중",HORIZONTAL_ALIGNMENT_LEFT,width-32,18,cyan)
		draw_string(font,origin+Vector2(16,67),FrontierFlightTelemetry.distance_label(float(row.distance)),HORIZONTAL_ALIGNMENT_LEFT,width-32,15,Color.WHITE);return
	if marks.has(row.operator):draw_texture_rect(marks[row.operator],Rect2(origin+Vector2(14,13),Vector2(36,36)),false)
	else:draw_line(origin+Vector2(19,19),origin+Vector2(44,44),cyan,3);draw_line(origin+Vector2(44,19),origin+Vector2(19,44),cyan,3)
	draw_string(font,origin+Vector2(60,34),row.short_name,HORIZONTAL_ALIGNMENT_LEFT,width-74,18,Color.WHITE)
	draw_string(font,origin+Vector2(14,72),row.name,HORIZONTAL_ALIGNMENT_LEFT,width-28,16,cyan)
	var state: String={"restored":"복원 완료","operating":"운영 중","developing":"개척 지원","withdrawn":"운항 중단"}[row.state]
	draw_string(font,origin+Vector2(14,101),state+"   "+row.cargo,HORIZONTAL_ALIGNMENT_LEFT,width-28,14,Color(.75,.86,.91))
	draw_string(font,origin+Vector2(14,129),"기업 전용 선석",HORIZONTAL_ALIGNMENT_LEFT,width-28,13,Color(.55,.68,.73))

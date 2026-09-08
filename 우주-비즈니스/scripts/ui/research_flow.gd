class_name FrontierResearchFlow
extends Control
## Visual project relationships; future nodes remain outlined and hollow.
var research_stage: String="unseen"
var amount:=0
var required:=3
var phase: String="ready"
var elapsed:=0.0
func _ready() -> void:
	custom_minimum_size=Vector2(260,104);mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if is_visible_in_tree():elapsed+=delta;queue_redraw()
func _draw() -> void:
	var font:=get_theme_default_font()
	var stages: Array=[research_stage!="unseen",research_stage in ["analyzed","prototyped"],research_stage=="prototyped",false]
	var labels: Array=["표본 · %d/%d"%[amount,required],"분석","시험기 · II","정식 설계 · III"]
	var step: float=size.x/4
	for i in 4:
		var point:=Vector2(step*(i+.5),32)
		var color: Color=FrontierInterfaceStyle.ACCENT if stages[i] else FrontierInterfaceStyle.LINE
		if i<3:draw_line(point+Vector2(25,0),point+Vector2(step-25,0),FrontierInterfaceStyle.ACCENT if stages[i+1] else FrontierInterfaceStyle.LINE,2,true)
		draw_circle(point,23,color,false,2,true)
		if i==0:
			var tex:=FrontierResourceIcons.texture("sapphire");draw_texture_rect(tex,Rect2(point-Vector2(16,16),Vector2(32,32)),false,Color.WHITE if stages[i] else Color(.25,.32,.34))
		elif i==1:
			var points:=PackedVector2Array()
			for x in 33:points.append(point+Vector2(x-16,sin(x*.6+elapsed*(5 if phase in ["waiting","success"] else 0))*((8 if stages[i] or phase in ["prepared","waiting"] else 2))))
			draw_polyline(points,color,2,true)
		else:
			var icon:=FrontierInterfaceStyle.icon("equipment/miner_probe" if i==2 else "manual_tool")
			if icon!=null:draw_texture_rect(icon,Rect2(point-Vector2(18,18),Vector2(36,36)),false,Color.WHITE if stages[i] else Color(.60,.65,.68))
		var label: String=labels[i];var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		draw_string(font,Vector2(point.x-width*.5,78),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,FrontierInterfaceStyle.TEXT if stages[i] else FrontierInterfaceStyle.MUTED)

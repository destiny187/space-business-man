class_name FrontierAugmentationTree
extends Control
signal field_selected(field: String)
var buttons: Dictionary={}
var labels: Dictionary={}
var selected:="mobility"
var own: Dictionary={}
const COLUMNS: Array=[ ["mobility","jump","endurance","stamina_recovery"], ["combat","fire_rate","mining","excavation"], ["vitality","fall_guard","healing","recovery_delay"] ]
func _ready() -> void:
	custom_minimum_size=Vector2(420,340);size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
	for column in COLUMNS:
		for key in column:
			var def: Dictionary=FrontierCrewAugmentation.config().fields[key]
			var button:=Button.new();button.custom_minimum_size=Vector2(126,54);button.toggle_mode=true
			button.icon=load("res://assets/ui/interface/"+"augment_"+key+".svg");button.expand_icon=true;button.add_theme_constant_override("icon_max_width",32)
			button.add_theme_font_size_override("font_size",13);button.alignment=HORIZONTAL_ALIGNMENT_CENTER
			add_child(button);buttons[key]=button;button.pressed.connect(func():field_selected.emit(key))
	resized.connect(arrange);arrange()
func arrange() -> void:
	var column_width: float=size.x/3.0
	var step:=maxf(75,(size.y-36)/4)
	for c in COLUMNS.size():
		for r in COLUMNS[c].size():
			var key: String=COLUMNS[c][r]
			buttons[key].size=Vector2(126,minf(76,step-18))
			buttons[key].position=Vector2(column_width*c+(column_width-126)*.5,36+r*step)
	queue_redraw()
func refresh(member: Dictionary,key: String,pending: bool) -> void:
	own=member;selected=key
	for id in buttons:
		var rank:=FrontierCrewAugmentation.level(member,id)
		var gate:=FrontierCrewAugmentation.unlock_reason(member,id)
		var def: Dictionary=FrontierCrewAugmentation.config().fields[id]
		var button: Button=buttons[id]
		button.text="%s\n%s"%[def.name,("%d / %d"%[rank,int(FrontierCrewAugmentation.config().maximum_level)]) if gate.is_empty() else "선행 %d단계"%int(def.requires)]
		button.tooltip_text=FrontierCrewAugmentation.stat_text(member,id)+("\n"+gate if not gate.is_empty() else "\n선택하여 다음 효과와 보석 확인")
		button.set_pressed_no_signal(id==key);button.disabled=pending
		button.add_theme_color_override("font_color",FrontierInterfaceStyle.MUTED if not gate.is_empty() else FrontierInterfaceStyle.ACCENT if rank>0 else FrontierInterfaceStyle.TEXT)
		button.add_theme_stylebox_override("normal",FrontierInterfaceStyle.box(FrontierInterfaceStyle.PANEL,FrontierInterfaceStyle.ACCENT if rank>0 else FrontierInterfaceStyle.LINE,6))
	queue_redraw()
func _draw() -> void:
	var font:=get_theme_default_font()
	for c in COLUMNS.size():
		var title: String=FrontierCrewAugmentation.config().fields[COLUMNS[c][0]].branch
		draw_string(font,Vector2(size.x*c/3+8,22),title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,FrontierInterfaceStyle.ACCENT)
	for key in buttons:
		var def: Dictionary=FrontierCrewAugmentation.config().fields[key]
		if str(def.parent).is_empty():continue
		var parent: Button=buttons[def.parent];var child: Button=buttons[key]
		var start:=parent.position+Vector2(parent.size.x*.5,parent.size.y)
		var end:=child.position+Vector2(child.size.x*.5,0)
		var color:=FrontierInterfaceStyle.ACCENT if FrontierCrewAugmentation.unlock_reason(own,key).is_empty() else FrontierInterfaceStyle.LINE
		# Second child uses a side branch so links never pass through another node.
		if def.requires==1 and key in ["endurance","mining","healing"]:
			var side:=parent.position.x+parent.size.x+5
			draw_polyline(PackedVector2Array([start,start+Vector2(0,12),Vector2(side,start.y+12),Vector2(side,end.y-12),end-Vector2(0,12),end]),color,2,true)
		else:draw_line(start,end,color,2,true)
		draw_circle(end,3,color,true,-1,true)

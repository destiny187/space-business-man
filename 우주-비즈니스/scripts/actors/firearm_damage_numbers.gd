extends RefCounted
## Only confirmed, per-target HP/shield deltas enter this short-lived display.
var entries: Array[Dictionary]=[]
var settings: Dictionary
var font: FontVariation

func _init() -> void:
	settings=FrontierFirearmEffects.config().damage_numbers
	font=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):750.0}

func clear() -> void:
	entries.clear()

func add(targets: Array) -> void:
	for target in targets:
		var amount:=float(target.get("damage",0))+float(target.get("shield",0))
		if amount<=0 or not target.has("anchor") or str(target.get("id","")).is_empty():continue
		var entry: Dictionary={}
		for existing in entries:
			if existing.id==target.id and float(existing.age)<float(settings.stack_window):entry=existing;break
		if entry.is_empty():
			if entries.size()>=int(settings.limit):entries.pop_front()
			entry={"id":target.id,"amount":0.0,"age":0.0,"broken":false,"shield":false,"killed":false}
			entries.append(entry)
		entry.amount+=amount;entry.age=0.0;entry.anchor=FrontierCrewWorld.vector(target.anchor)
		entry.broken=entry.broken or target.get("broken",false)
		entry.shield=entry.shield or float(target.get("shield",0))>0
		entry.killed=entry.killed or target.get("killed",false)
		entry.color=Color(settings.weak_color if target.get("weak",false) else settings.shield_color if float(target.get("damage",0))<=0 else settings.health_color if target.get("kind")=="animal" else settings.armor_color)

func update(delta: float) -> void:
	for i in range(entries.size()-1,-1,-1):
		entries[i].age+=delta
		if float(entries[i].age)>=float(settings.life):entries.remove_at(i)

func draw(hud: Control,camera: Camera3D,scope: bool) -> void:
	var viewport:=hud.get_viewport_rect().size
	var occupied: Array[Rect2]=[]
	for entry in entries:
		if camera.is_position_behind(entry.anchor):continue
		var point:=camera.unproject_position(entry.anchor)
		if not Rect2(Vector2.ZERO,viewport).has_point(point):continue
		if scope and point.distance_to(viewport*.5)>viewport.y*.35:continue
		var age:=float(entry.age);var progress:=age/float(settings.life)
		var pop:=1.0+.2*pow(1.0-clampf(age/float(settings.pop_time),0,1),2)
		var size:=roundi(float(settings.font_size)*pop)
		var value:=str(maxi(1,roundi(float(entry.amount))))
		var width:=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		point+=Vector2(18,-12-float(settings.rise)*progress)
		point.x=clampf(point.x,24,viewport.x-width-24);point.y=maxf(size+8,point.y)
		var bounds:=Rect2(point-Vector2(22,size),Vector2(width+26,size+6))
		# Nearby splash targets keep independent, readable totals.
		for previous in occupied:
			if bounds.intersects(previous):point.y=previous.position.y-6;bounds.position.y=point.y-size
		occupied.append(bounds)
		var color: Color=entry.color;color.a=clampf((float(settings.life)-age)/.23,0,1)
		var outline:=Color(.025,.035,.055,color.a)
		hud.draw_string_outline(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,5,outline)
		hud.draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
		if entry.shield:
			var icon:=Color(settings.shield_color);icon.a=color.a
			draw_shield(hud,point+Vector2(-13,-size*.4),icon,entry.broken,clampf(age/float(settings.break_time),0,1))
		if entry.killed:
			var x:=point+Vector2(width+9,-size*.4)
			hud.draw_line(x+Vector2(-3,-2),x+Vector2(0,2),color,2,true);hud.draw_line(x+Vector2(0,2),x+Vector2(3,-2),color,2,true)

static func draw_shield(hud: Control,center: Vector2,color: Color,broken: bool,phase: float=0.0) -> void:
	var offset:=Vector2(1.5+phase*2,phase*2) if broken else Vector2.ZERO
	var left:=PackedVector2Array([center+Vector2(0,-7)-offset,center+Vector2(-6,-5)-offset,center+Vector2(-5,2)-offset,center+Vector2(0,7)-offset])
	var right:=PackedVector2Array([center+Vector2(0,-7)+offset,center+Vector2(6,-5)+offset,center+Vector2(5,2)+offset,center+Vector2(0,7)+offset])
	for points in [left,right]:
		hud.draw_polyline(points,Color(.025,.035,.055,color.a),4,true)
		hud.draw_polyline(points,color,1.8,true)
	if broken:
		hud.draw_polyline(PackedVector2Array([center+Vector2(0,-5),center+Vector2(-2,0),center+Vector2(2,1),center+Vector2(0,5)]),color,1.5,true)

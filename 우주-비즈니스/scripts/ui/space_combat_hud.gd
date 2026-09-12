extends Control
var presentation: FrontierSpaceCombatView
var font: Font
var key_style: StyleBox
const MINT=FrontierInterfaceStyle.ACCENT
const WHITE=FrontierInterfaceStyle.TEXT
const WARN=FrontierInterfaceStyle.WARNING
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font=FrontierInterfaceStyle.theme().default_font
	key_style=FrontierInterfaceStyle.box(Color.TRANSPARENT,MINT,0)
func label_at(p: Vector2,text: String,color: Color=WHITE,px: int=15) -> void:
	draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,4,Color(.02,.04,.06,.8*color.a));draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)
func bar(p: Vector2,value: float,maximum: float,width: float,color: Color=MINT) -> void:
	draw_rect(Rect2(p,Vector2(width,3)),Color(.12,.19,.21,.8));draw_rect(Rect2(p,Vector2(width*clampf(value/maxf(maximum,1),0,1),3)),color)
func keycap(p: Vector2,key: String) -> void:
	draw_style_box(key_style,Rect2(p,Vector2(24,24)))
	label_at(p+Vector2(7,18),key,WHITE,14)
func work_icon(p: Vector2,repair: bool) -> void:
	if repair:
		draw_polyline(PackedVector2Array([p+Vector2(18,0),p+Vector2(11,7),p+Vector2(17,13),p+Vector2(24,6)]),MINT,2,true)
		draw_line(p+Vector2(14,10),p+Vector2(3,21),MINT,3,true);draw_circle(p+Vector2(3,21),3,MINT,false,1.5,true)
	else:
		draw_line(p,p+Vector2(22,0),MINT,2,true);draw_line(p+Vector2(13,0),p+Vector2(13,14),MINT,2,true)
		draw_arc(p+Vector2(9,14),4,0,PI,12,MINT,2,true)
func draw_radio() -> void:
	if presentation.radio.is_empty():return
	var total:=float(FrontierSpaceCombat.config().radio.seconds)
	var fade:=minf(clampf((total-presentation.radio_left)/.2,0,1),clampf(presentation.radio_left/.6,0,1))
	var p:=Vector2(28,176)
	for i in 5:
		var height:=3.0+float(2-absi(2-i))*3
		draw_line(p+Vector2(i*4,-height),p+Vector2(i*4,height),Color(WARN,fade),1.5,true)
	label_at(p+Vector2(28,4),str(presentation.radio.sender)+" → "+str(presentation.radio.receiver),Color(WARN,fade),13)
	label_at(p+Vector2(0,33),str(presentation.radio.text),Color(WHITE,fade),16)
func _draw() -> void:
	if presentation==null or presentation.blocked:return
	var v:=presentation.view;var data:=presentation.data();var id:=presentation.id();var center:=size*.5
	var stats: Dictionary=data.get("ships",{}).get(id,{})
	if not stats.is_empty():
		var p:=Vector2(28,size.y-142)
		label_at(p,"실드",MINT,13);label_at(p+Vector2(145,0),str(roundi(stats.shield)),WHITE,14);bar(p+Vector2(0,9),float(stats.shield),float(FrontierSpaceCombat.config().shield if id=="crew" else FrontierSpaceCombat.config().finch_shield),180)
		label_at(p+Vector2(0,38),"선체",MINT,13);label_at(p+Vector2(145,38),str(roundi(v.navigation.get("hull",100))),WARN if float(v.navigation.get("hull",100))<35 else WHITE,14);bar(p+Vector2(0,47),float(v.navigation.get("hull",100)),100,180)
		if id=="crew":label_at(p+Vector2(0,76),"함포",MINT,13);bar(p+Vector2(0,86),float(stats.heat),1,180,WARN if stats.overheated else MINT)
		label_at(p+Vector2(0,110),"추진",MINT,13);label_at(p+Vector2(145,110),str(roundi(v.navigation.get("energy",100))),WHITE,14);bar(p+Vector2(0,120),float(v.navigation.get("energy",100)),100,180)
		var op: Dictionary=stats.get("operation",{})
		if not op.is_empty():
			work_icon(Vector2(260,size.y-146),op.kind=="space_repair")
			bar(Vector2(298,size.y-132),float(op.elapsed),float(FrontierSpaceCombat.config().salvage_seconds),160)
		elif not str(stats.get("operation_error","")).is_empty():label_at(Vector2(260,size.y-140),str(stats.operation_error),WARN,13)
	if presentation.hit_flash>0:draw_arc(center,minf(size.x,size.y)*.39,presentation.hit_bearing-.35,presentation.hit_bearing+.35,18,Color(MINT if presentation.hit_shielded else WARN,presentation.hit_flash*2),3,true)
	if presentation.relevant():
		var e:=presentation.encounter()
		if e.phase=="warning":
			var name: String="해적 접근"
			label_at(Vector2(center.x-font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x*.5,95),name,WARN,18)
		if e.phase=="combat" and e.carrier==id:
			var away: Vector3=(v.ship.position-FrontierSpaceCombat.point(e.origin)).normalized()
			if away.length_squared()<.1:away=-FrontierSpaceCombat.point(e.heading)
			var target: Vector3=v.ship.position+away*1500
			var loc:=v.camera.unproject_position(target) if not v.camera.is_position_behind(target) else center-Vector2(0,260)
			loc=Vector2(clampf(loc.x,50,size.x-190),clampf(loc.y,135,size.y-185));draw_circle(loc,8,MINT,false,2,true)
			bar(Vector2(center.x-70,118),float(e.escape),float(FrontierSpaceCombat.config().escape_seconds),140)
		if presentation.armed():
			draw_arc(center,7,0,TAU,24,MINT,1.5,true)
			for side in [-1,1]:draw_line(center+Vector2(side*12,0),center+Vector2(side*20,0),MINT,1.5,true)
		if presentation.hit_confirm>0:
			for direction in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:draw_line(center+direction*9,center+direction*15,Color(WHITE,presentation.hit_confirm/.16),2,true)
		for enemy in presentation.visible_enemies:
			var p:=FrontierSpaceCombat.point(enemy.position)
			var relative: Vector3=v.camera.global_basis.inverse()*(p-v.camera.global_position)
			var behind:=v.camera.is_position_behind(p)
			var at:=v.camera.unproject_position(p) if not behind else center+Vector2(relative.x,-relative.y).normalized()*size.x
			if behind or not Rect2(Vector2(25,130),size-Vector2(50,270)).has_point(at):
				if float(enemy.windup)>0:
					var ray: Vector2=(at-center).normalized()
					if ray.length()<.1:ray=Vector2.DOWN
					var edge:=center+ray*minf(size.x*.39,size.y*.34)
					draw_colored_polygon(PackedVector2Array([edge+ray*10,edge-ray*6+ray.orthogonal()*5,edge-ray*6-ray.orthogonal()*5]),WARN)
				continue
			var cfg: Dictionary=FrontierSpaceCombat.config().enemy[enemy.kind]
			var radius:=clampf(v.camera.unproject_position(p+v.camera.global_basis.x*float(cfg.radius)).distance_to(at)+8,20,110)
			for side in [-1,1]:
				var x: float=radius*side
				draw_polyline(PackedVector2Array([at+Vector2(x-side*7,-radius*.5),at+Vector2(x,-radius*.5),at+Vector2(x,radius*.5),at+Vector2(x-side*7,radius*.5)]),Color(WARN,.7),1.2,true)
			bar(at+Vector2(-30,-radius*.5-17),float(enemy.shield),float(cfg.shield),60,MINT);bar(at+Vector2(-30,-radius*.5-11),float(enemy.hull),float(cfg.hull),60,WARN)
			if at.distance_to(center)<200:label_at(at+Vector2(radius+8,5),str(cfg.name),WARN,13)
			if float(enemy.windup)>0:draw_arc(at,radius+5,-PI*.5,TAU*(1-float(enemy.windup)/float(cfg.windup))-PI*.5,32,WARN,2,true)

	for wreck in presentation.visible_wrecks:
		var p:=FrontierSpaceCombat.point(wreck.position)
		if v.camera.is_position_behind(p):continue
		var at:=v.camera.unproject_position(p)
		if not Rect2(Vector2(20,130),size-Vector2(40,240)).has_point(at):continue
		draw_polyline(PackedVector2Array([at+Vector2(0,-9),at+Vector2(9,0),at+Vector2(0,9),at+Vector2(-9,0),at+Vector2(0,-9)]),MINT,1.5,true)
		if presentation.selected_wreck==wreck.id:keycap(at+Vector2(16,-13),"F")
		label_at(at+Vector2(47 if presentation.selected_wreck==wreck.id else 16,5),"%dm"%roundi(p.distance_to(v.ship.position)),MINT,13)
	if presentation.repair_available():
		keycap(Vector2(260,size.y-113),"R");work_icon(Vector2(298,size.y-113),true)
		label_at(Vector2(336,size.y-95),"%d Cr"%int(FrontierSpaceCombat.config().repair_cost),WHITE,13)
	draw_radio()

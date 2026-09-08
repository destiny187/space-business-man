class_name FrontierShipModulePreview
extends Control
signal slot_selected(slot: String)
var view: FrontierEquipmentPreview
var buttons: Dictionary={}
var mounts: Dictionary={}
var selected_slot:="propulsion"
var signature:=""
func _ready() -> void:
	view=FrontierEquipmentPreview.new();add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for slot in FrontierVesselRefit.config().slots:
		var button:=Button.new();button.custom_minimum_size=Vector2(128,42);button.text="추진 슬롯" if slot=="propulsion" else "공용 슬롯";button.toggle_mode=true;add_child(button);buttons[slot]=button
		button.pressed.connect(func():selected_slot=slot;slot_selected.emit(slot))
func show_vessel(vessel: Dictionary) -> void:
	var key:=str([vessel.get("hull","kestrel"),vessel.get("loadout",{}),vessel.get("modules",{})])
	if signature==key:return
	signature=key
	var hull:=FrontierSpaceStation.hull(vessel)
	var path:=str(hull.model).trim_prefix("res://assets/models/").trim_suffix(".glb")
	var changed:=view.model_path!=path
	view.show_model(path)
	if changed:view.camera.size*=.6
	for node in mounts.values():
		if is_instance_valid(node):node.get_parent().remove_child(node);node.queue_free()
	mounts.clear()
	for slot in FrontierVesselRefit.config().slots:
		var id: String=vessel.get("loadout",{}).get(slot,"")
		var anchor:=Node3D.new();view.model.add_child(anchor);anchor.position=FrontierCrewWorld.vector(FrontierVesselRefit.config().mounts[slot]);mounts[slot]=anchor
		buttons[slot].text=("추진" if slot=="propulsion" else "공용")+(" · 비어 있음" if id.is_empty() else " · 장착됨")
		if id.is_empty():continue
		var module: Dictionary=vessel.modules[id];var def:=FrontierVesselRefit.definition(module.type)
		var model: Node3D=load("res://assets/models/"+str(def.model)+".glb").instantiate();anchor.add_child(model);FrontierInkStyle.apply(model,{})
		buttons[slot].tooltip_text=def.name
func _process(_delta: float) -> void:
	if not is_visible_in_tree():return
	buttons.propulsion.position=Vector2(6,6);buttons.utility.position=Vector2(maxf(6,size.x-134),maxf(52,size.y-48))
	for slot in buttons:buttons[slot].set_pressed_no_signal(slot==selected_slot)
	queue_redraw()
func _draw() -> void:
	if view==null or view.camera==null:return
	for slot in mounts:
		var point:=view.camera.unproject_position(mounts[slot].global_position)
		var from: Vector2=buttons[slot].position+buttons[slot].size*.5
		var tint:=FrontierInterfaceStyle.ACCENT if slot==selected_slot else FrontierInterfaceStyle.MUTED
		draw_line(from,point,tint,1.5,true);draw_arc(point,6,0,TAU,24,tint,2,true)

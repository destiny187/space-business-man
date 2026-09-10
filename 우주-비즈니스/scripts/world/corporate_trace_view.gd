class_name FrontierCorporateTraceView
extends Node
var flight: FrontierCrewFlightView
var models: Dictionary={}
var selected: Dictionary={}
var stages: Dictionary={}
var mechanisms: Array=[]
var overlay: Control
var scanning:=false
func configure(view: FrontierCrewFlightView) -> void:
	flight=view
	for row in FrontierCorporateTraces.all(flight.state.manifest,flight.current_system,flight.orbit_time):
		var model: Node3D=load("res://assets/models/"+row.model+".glb").instantiate()
		FrontierInkStyle.apply(model,flight.cache);add_child(model);models[row.id]=model
		model.position=FrontierCrewWorld.vector(row.position)
		stages[row.id]=int(flight.trace_records.get(row.id,0))
		for n in model.find_children("Anim_*","Node3D",true,false):mechanisms.append(n)
	var layer:=CanvasLayer.new();add_child(layer);overlay=load("res://scripts/ui/corporate_trace_overlay.gd").new();layer.add_child(overlay)
func update(t: float,blocked: bool) -> void:
	selected={};scanning=false;overlay.markers=[]
	for row in FrontierCorporateTraces.all(flight.state.manifest,flight.current_system,t):
		if not models.has(row.id):continue
		var model: Node3D=models[row.id];model.position=FrontierCrewWorld.vector(row.position)
		var stage:=int(flight.trace_records.get(row.id,0))
		if stage>int(stages.get(row.id,stage)) and not blocked:flight.soundscape.complete()
		stages[row.id]=stage
		var distance:=flight.camera.global_position.distance_to(model.global_position)
		if not blocked and flight.navigation.get("mode","")!="jump" and distance<float(FrontierCorporateTraces.rules(flight.state.manifest).signal_distance) and not flight.camera.is_position_behind(model.global_position) and not flight.corporate_view.hidden(model.global_position):
			overlay.markers.append({"point":flight.camera.unproject_position(model.global_position),"stage":stage})
	for node in mechanisms:
		if str(node.name).begins_with("Anim_Beacon"):node.rotation.y=fposmod(t*.7,TAU)
		elif str(node.name).begins_with("Anim_ServiceArm"):node.rotation.y=sin(t*.18)*.15
		else:node.rotation.y=sin(t*.35)*.7
	if not blocked and flight.scan_enabled and not flight.navigation.is_empty():
		var nav: Dictionary=flight.navigation.duplicate();nav.orbit_time=t
		selected=FrontierCorporateTraces.target(flight.state.manifest,nav,-flight.camera.global_basis.z)
		if not selected.is_empty():
			selected.stage=int(flight.trace_records.get(selected.id,0));selected.progress=0.0
			selected.reason=FrontierCorporateTraces.reason(flight.state.manifest,nav,selected,int(selected.stage))
			if flight.trace_scan.get("kind","")=="corporate_trace" and flight.trace_scan.get("id","")==selected.id and int(flight.trace_scan.get("stage",-1))==int(selected.stage):
				selected.progress=float(flight.trace_scan.get("progress",0));scanning=selected.progress>0 and selected.reason.is_empty()
	overlay.row=selected;overlay.queue_redraw()

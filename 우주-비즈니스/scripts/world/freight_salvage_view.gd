class_name FrontierFreightSalvageView
extends Node3D
var flight: FrontierCrewFlightView
var models: Dictionary={}
var cradles: Dictionary={}
var stages: Dictionary={}
var receiver: Node3D
var selected: Dictionary={}
var overlay: Control
var cable: MeshInstance3D
var scanning:=false
var was_transferring:=false
var winch: AudioStreamPlayer
var beacon_left:=0.0
func model(id: String) -> Node3D:
	var node: Node3D=load("res://assets/models/ships/"+id+".glb").instantiate()
	add_child(node);FrontierInkStyle.apply(node,flight.cache);return node
func configure(view: FrontierCrewFlightView) -> void:
	flight=view
	winch=AudioStreamPlayer.new();winch.stream=flight.soundscape.library.stream("sfx_rover_winch",true);winch.volume_db=-24;winch.bus="SFX";add_child(winch)
	var row:=FrontierFreightSalvage.definition(flight.state.manifest,FrontierFreightSalvage.address(flight.current_system))
	if not row.is_empty():receiver=model("freight_receiver")
	var layer:=CanvasLayer.new();add_child(layer);overlay=load("res://scripts/ui/freight_salvage_overlay.gd").new();layer.add_child(overlay)
	cable=MeshInstance3D.new();add_child(cable);var cylinder:=CylinderMesh.new();cylinder.top_radius=.18;cylinder.bottom_radius=.18;cylinder.height=1;cable.mesh=cylinder
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("90dfeb");cable.material_override=mat;cable.hide()
func socket(vessel: Dictionary) -> Transform3D:
	var transform: Transform3D=flight.ship.global_transform if vessel.id==flight.freight_carrier else Transform3D(flight._flight_basis(FrontierCrewWorld.vector(vessel.direction)),FrontierCrewWorld.vector(vessel.position))
	return transform.translated_local(Vector3(0,-25 if vessel.id=="crew" else -20,5))
func update(delta: float,t: float,blocked: bool) -> void:
	selected={};scanning=false;overlay.row={};overlay.markers=[];overlay.carry={};cable.hide()
	var m: Dictionary=flight.state.manifest;var records: Dictionary=flight.freight_records
	var local_id:=FrontierFreightSalvage.address(flight.current_system);var local:=FrontierFreightSalvage.definition(m,local_id,t)
	if is_instance_valid(receiver):
		receiver.position=FrontierCrewWorld.vector(local.receiver);clamps(receiver,0 if int(records.get(local_id,{}).get("stage",0))==3 else 1)
	var needed: Dictionary={}
	if not local.is_empty():needed[local_id]=local
	var vessels: Dictionary={}
	for vessel in flight.freight_vessels:
		if int(vessel.system)==flight.current_system:vessels[vessel.id]=vessel
	for id in records:
		if int(records[id].stage)==2 and vessels.has(records[id].carrier):needed[id]=FrontierFreightSalvage.definition(m,id,t)
	for node in models.values():node.hide()
	for node in cradles.values():node.hide()
	var transferring:=false
	for id in needed:
		var row: Dictionary=needed[id]
		if row.is_empty():continue
		var record: Dictionary=records.get(id,{"stage":0,"carrier":""});var stage:=int(record.stage)
		var scan: Dictionary={}
		for progress in flight.freight_activity:
			if progress.id==id and int(progress.stage)==stage and float(progress.progress)>float(scan.get("progress",0)):scan=progress
		var vessel_id: String=scan.get("carrier",record.carrier)
		var moving: bool=not scan.is_empty() and stage in [1,2] and vessels.has(vessel_id)
		if stage==2 and not vessels.has(vessel_id):continue
		if not models.has(id):models[id]=model("lost_freight_pod")
		var pod: Node3D=models[id];pod.show()
		var loose:=Transform3D(Basis.from_euler(Vector3(sin(t*.18)*.13,t*.055+float(row.seed%10),cos(t*.16)*.1)),FrontierCrewWorld.vector(row.position))
		var destination:=Transform3D(Basis.IDENTITY,FrontierCrewWorld.vector(row.receiver))
		var held:=Transform3D.IDENTITY
		if vessels.has(vessel_id):
			held=socket(vessels[vessel_id])
			if stage==2 or moving:
				if not cradles.has(vessel_id):cradles[vessel_id]=model("freight_cradle")
				cradles[vessel_id].show();cradles[vessel_id].global_transform=held
				var progress:=float(scan.get("progress",0))
				clamps(cradles[vessel_id],smoothstep(0,.15,progress) if stage==2 and moving else (0.0 if stage==2 else 1.0-smoothstep(.8,1,progress)))
		var transform: Transform3D=loose if stage<2 else (held if stage==2 else destination)
		if moving:
			transferring=true;var p:=smoothstep(.05 if stage==1 else .15,.85,float(scan.progress))
			if stage==2 and is_instance_valid(receiver):clamps(receiver,1.0-smoothstep(.85,1,float(scan.progress)))
			transform=loose.interpolate_with(held,p) if stage==1 else held.interpolate_with(destination,p)
			if vessel_id==flight.freight_carrier and not blocked:
				var from:=held.origin if stage==1 else destination.origin;var length:=from.distance_to(transform.origin)
				if length>1:
					cable.show();cable.position=(from+transform.origin)*.5;cable.basis=Basis(Quaternion(Vector3.UP,(transform.origin-from).normalized()));cable.scale.y=length
		# Follow moving ports immediately; ease only the release of an interrupted transfer.
		if pod.has_meta("moving") and pod.get_meta("moving") and not moving and stage<3:pod.global_transform=pod.global_transform.interpolate_with(transform,minf(1,delta*6))
		else:pod.global_transform=transform
		pod.set_meta("moving",moving or (pod.global_position.distance_to(transform.origin)>1))
		if stages.has(id) and stage>int(stages[id]) and not blocked:
			flight.soundscape.complete()
			if stage>=2:flight.soundscape.library.play("sfx_lotus_touchdown")
		stages[id]=stage
		if id==local_id and not blocked and flight.navigation.get("mode","")!="jump" and not flight.camera.is_position_behind(pod.global_position) and flight.camera.global_position.distance_to(pod.global_position)<float(FrontierFreightSalvage.rules(m).signal_distance) and not flight.corporate_view.hidden(pod.global_position):
			var point: Vector3=destination.origin if stage>=2 else pod.global_position
			if stage!=2 or vessel_id==flight.freight_carrier:overlay.markers.append({"point":flight.camera.unproject_position(point),"stage":stage})
	if not blocked and flight.scan_enabled and not flight.navigation.is_empty():
		var nav: Dictionary=flight.navigation.duplicate();nav.orbit_time=t
		selected=FrontierFreightSalvage.target(m,nav,-flight.camera.global_basis.z,records,flight.freight_carrier)
		if not selected.is_empty():
			selected.reason=FrontierFreightSalvage.reason(m,nav,selected,records,flight.freight_carrier,flight.freight_pilot);selected.progress=0.0
			if flight.trace_scan.get("kind","")=="freight" and flight.trace_scan.get("id","")==selected.id and int(flight.trace_scan.get("stage",-1))==int(selected.stage):selected.progress=float(flight.trace_scan.get("progress",0))
			scanning=selected.progress>0 and selected.reason.is_empty()
			# The closer physical cargo interaction owns the gaze panel.
			flight.trace_view.overlay.row={};flight.trace_view.overlay.queue_redraw();flight.corporate_view.overlay.row={};flight.corporate_view.overlay.queue_redraw()
			if is_instance_valid(flight.traffic):flight.traffic.overlay.row={};flight.traffic.overlay.queue_redraw()
	var carried:=FrontierFreightSalvage.carried(records,flight.freight_carrier)
	if not blocked and not carried.is_empty():overlay.carry=FrontierFreightSalvage.definition(m,carried,t)
	if was_transferring and not transferring and not blocked and not flight.trace_scan.get("reason","").is_empty():flight.soundscape.library.play("sfx_build_invalid")
	var audible: bool=transferring and not blocked and not selected.is_empty() and selected.progress>0
	if audible and not winch.playing:winch.play()
	elif not audible:winch.stop()
	beacon_left=maxf(0,beacon_left-delta)
	if not blocked and not selected.is_empty() and int(selected.stage)==0 and beacon_left<=0:
		flight.soundscape.library.play("sfx_incident_beacon");beacon_left=6
	was_transferring=transferring;overlay.row=selected;overlay.queue_redraw()
func clamps(root: Node3D,opening: float) -> void:
	for node in root.find_children("Anim_Clamp_*","Node3D",true,false):node.rotation.z=-signf(node.position.x)*opening*.7

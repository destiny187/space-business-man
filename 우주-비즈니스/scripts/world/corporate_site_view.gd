class_name FrontierCorporateSiteView
extends Node
var flight: FrontierCrewFlightView
var overlay: Control
var selected: Dictionary={}
var target: String=""
var progress:=0.0
var previous_time:=0.0
var mechanisms: Array=[]
func configure(view: FrontierCrewFlightView) -> void:
	flight=view
	for model in flight.corporate_models.values():
		for n in model.find_children("Anim_Sorter","Node3D",true,false):mechanisms.append({"node":n,"kind":"sorter"})
		for n in model.find_children("Anim_SecuritySensor","Node3D",true,false):mechanisms.append({"node":n,"kind":"sensor"})
	var layer:=CanvasLayer.new();add_child(layer);overlay=load("res://scripts/ui/corporate_site_overlay.gd").new();layer.add_child(overlay)
func update(t: float,blocked: bool) -> void:
	var delta:=clampf(t-previous_time,0,.2);previous_time=t;selected={}
	for mechanism in mechanisms:
		if mechanism.kind=="sorter":mechanism.node.rotation.x=fposmod(t*.6,TAU)
		else:mechanism.node.rotation.y=sin(t*.3)*.8
	if not blocked and flight.scan_enabled and flight.navigation.get("mode","")!="jump" and (not is_instance_valid(flight.traffic) or flight.traffic.selected.is_empty()):
		var best:=.992
		for id in flight.corporate_models:
			var model: Node3D=flight.corporate_models[id];var offset:=model.global_position-flight.camera.global_position
			var dot:=offset.normalized().dot(-flight.camera.global_basis.z)
			if offset.length()>11000 or dot<=best or hidden(model.global_position):continue
			best=dot;selected=FrontierCorporateSites.definition(flight.state.manifest,id,t);selected.distance=offset.length()
	var id: String=selected.get("id","")
	if target!=id:target=id;progress=0
	if not selected.is_empty():
		var body:=FrontierUniverse.body(flight.state.manifest,int(selected.body))
		if flight.scanned.has(body.id):progress=1.0
		else:
			progress=minf(1,progress+delta/float(flight.flight_config.get("scan_seconds",1.8)))
			if progress>=1:
				flight.scanned[body.id]=true;flight.soundscape.complete();flight.planet_scanned.emit(int(body.ordinal))
		selected.progress=progress
	overlay.row=selected;overlay.queue_redraw()
func hidden(point: Vector3) -> bool:
	var origin:=flight.camera.global_position;var ray: Vector3=(point-origin).normalized();var distance:=origin.distance_to(point)
	var spheres: Array=[{"point":Vector3.ZERO,"radius":float(FrontierUniverse.star_settings(flight.state.manifest,flight.current_system).star_radius)}]
	for planet in flight.planets.values():spheres.append({"point":planet.node.global_position,"radius":float(planet.radius)})
	for sphere in spheres:
		var offset: Vector3=sphere.point-origin;var along:=offset.dot(ray)
		if along>0 and along<distance and (offset-ray*along).length()<float(sphere.radius):return true
	return false

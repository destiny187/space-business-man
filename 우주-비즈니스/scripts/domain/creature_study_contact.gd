extends RefCounted
## Deterministic swept contacts for the six-form lab. Returns events; never writes saves.

static func ellipsoid(from: Vector3,to: Vector3,center: Vector3,radii: Vector3,thickness: float) -> Dictionary:
	var scale_value:=radii+Vector3.ONE*thickness
	var p: Vector3=(from-center)/scale_value;var v: Vector3=(to-from)/scale_value
	var a:=v.dot(v);var b:=2*p.dot(v);var c:=p.dot(p)-1
	var fraction:=0.0
	if c>0:
		if a<.00000001:return {}
		var discriminant:=b*b-4*a*c
		if discriminant<0:return {}
		fraction=(-b-sqrt(discriminant))/(2*a)
		if fraction<0 or fraction>1:return {}
	var point:=from.lerp(to,fraction)
	var normal:=((point-center)/(scale_value*scale_value)).normalized()
	return {"fraction":fraction,"point":point,"normal":normal}

static func sweep(from: Vector3,to: Vector3,radius: float,targets: Array,include_ground: bool=true) -> Dictionary:
	var best: Dictionary={};var closest:=2.0
	for target in targets:
		var hit:=ellipsoid(from,to,target.center,target.radii,radius)
		if hit.is_empty() or float(hit.fraction)>=closest:continue
		closest=hit.fraction;best=hit;best.target=target.id;best.kind="shield" if target.get("shield",false) else "organic"
	if include_ground and from.y>=radius and to.y<radius:
		var t: float=(from.y-radius)/maxf(.00001,from.y-to.y)
		if t<closest:best={"fraction":t,"point":from.lerp(to,t),"normal":Vector3.UP,"target":"ground","kind":"surface"}
	return best

static func apply_once(event: Dictionary,ledger: Dictionary,state: Dictionary,key: String,damage: float) -> Dictionary:
	if event.is_empty() or ledger.has(key):return {}
	ledger[key]=true
	var result:=event.duplicate();result.damage=0.0;result.absorbed=0.0
	if event.kind=="shield":
		result.absorbed=minf(float(state.shield),damage);state.shield-=result.absorbed
		result.damage=maxf(0,damage-result.absorbed)
	elif event.kind=="organic":result.damage=damage
	state.health=maxf(0,float(state.health)-float(result.damage))
	return result

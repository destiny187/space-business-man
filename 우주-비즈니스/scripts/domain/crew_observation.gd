class_name FrontierCrewObservation
extends RefCounted
## Small presentation descriptor, published once per snapshot fanout. No authority.
static func neutral_input() -> Array:
	# Menu/focus loss normally requests a safety brake. Watching must not press it.
	return [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]

static func snapshot(world: Dictionary) -> Dictionary:
	var owner: String=world.crew.owner_id
	var member: Dictionary=world.crew.members.get(owner,{})
	if member.is_empty():return {}
	var local:=FrontierShuttles.context(world,owner)
	if not local.crew.get("landing",{}).is_empty() or member.area!="cabin":return {}
	return {"actor":owner,"name":member.profile.name,"navigation":local.crew.navigation.duplicate(true),"shuttle":local.has("local_shuttle")}

static func available(value: Dictionary,hosting: bool) -> bool:
	return not hosting and value.get("active",false) and value.get("phase","")=="playing" and not value.get("host_view",{}).is_empty() and value.get("crew",{}).get("members",{}).get(value.get("host_view",{}).get("actor",""),{}).get("connected",false)

static func valid(value: Variant,crew: Dictionary) -> bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	return value.get("actor")==crew.get("owner_id") and value.get("name") is String and str(value.name).length()<=128 and value.get("shuttle") is bool and FrontierCrewNavigation.validate(value.get("navigation")).is_empty()

extends "res://scripts/actors/creatures/study_impact_effects.gd"
## Consume published host hit masks. A local pose never predicts successful damage.
var serial:=-1
var phase:=""
var hit_masks: Dictionary={}
var shield_before: Dictionary={}
var last_pulses:=0
var was_blocked:=false
var emitted_contacts:=0

func sync(actor: Node3D,draw: bool) -> void:
	terrain_probe=actor.ground_motion.probe
	ground_level=actor.global_position.y-float(actor.combat_live.get("air_height",0))-.06
	var live: Dictionary=actor.combat_live
	var attack: Dictionary=live.get("attack",{})
	var next_serial:=int(live.get("serial",-1));var next_phase: String=live.get("phase","")
	var first:=serial<0
	if next_serial!=serial or next_phase!=phase:
		serial=next_serial;phase=next_phase;hit_masks.clear();last_pulses=0;was_blocked=false
		if first:
			hit_masks=attack.get("hits",{}).duplicate();last_pulses=int(attack.get("pulses",0));was_blocked=attack.get("blocked",false)
	var mouth: Vector3=actor.mouth_marker.global_position if is_instance_valid(actor.mouth_marker) else actor.global_position
	for id in attack.get("hits",{}):
		var mask:=int(attack.hits[id]);var prior:=int(hit_masks.get(id,0));hit_masks[id]=mask
		if not draw or mask==prior or not actor.combat_targets.has(id):continue
		var member: Dictionary=actor.combat_targets[id]
		var at: Vector3=actor.get_parent().to_global(FrontierCrewWorld.vector(member.position))+Vector3.UP*.92
		var normal: Vector3=(mouth-at).normalized()
		if normal.length_squared()<.01:normal=-actor.global_basis.z
		var shield_now:=float(member.get("vitals",{}).get("shield",0))
		var shield_hit: bool=float(shield_before.get(id,shield_now))>shield_now or shield_now>0
		var kind: String="slash" if actor.combat_info.get("pattern","") in ["claw","scythe"] else "ram"
		impact({"kind":"shield" if shield_hit else "organic","point":at+normal*.26,"normal":normal},kind)
		emitted_contacts+=1
	var pulses:=int(attack.get("pulses",0));var blocked: bool=attack.get("blocked",false)
	if draw and phase=="attack" and actor.combat_info.get("behavior","")=="leap" and pulses>=2 and last_pulses<2 and not blocked:
		impact({"kind":"terrain","point":actor.global_position+Vector3.UP*.035,"normal":actor.global_basis.y},"slam",.8)
	if draw and phase=="attack" and actor.combat_info.get("behavior","")=="shockwave" and pulses>=1 and last_pulses<1:
		impact({"kind":"terrain","point":actor.global_position+Vector3.UP*.035,"normal":actor.global_basis.y},"slam",1.)
	if draw and blocked and not was_blocked and attack.get("hits",{}).is_empty():
		impact({"kind":"terrain","point":mouth,"normal":-actor.global_basis.z},"ram",.55)
	last_pulses=pulses;was_blocked=blocked
	for id in actor.combat_targets:
		shield_before[id]=float(actor.combat_targets[id].get("vitals",{}).get("shield",0))
	if not draw:clear()

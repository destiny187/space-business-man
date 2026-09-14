extends RefCounted
## The same FINCH grouping as host peer_group: an independent sortie does not block the common vessel.
static func group(value: Dictionary,id: String) -> bool:
	var members: Dictionary=value.crew.members
	var solo: String=str(value.get("local_shuttle",""))
	if not solo.is_empty():return id==solo
	return str(members[id].get("shuttle_id","")).is_empty()
static func roster(value: Dictionary) -> String:
	var lines: PackedStringArray=[]
	for id in value.crew.members:
		var member: Dictionary=value.crew.members[id]
		var location: String="FINCH 독립 활동" if not str(member.get("shuttle_id","")).is_empty() else ("선내" if member.get("aboard",false) else "지표")
		var state: String="연결 끊김 · 현재 출항 대기에서 제외" if not member.get("connected",false) else ("✓ 준비" if member.ready else "○ 준비 전")
		lines.append(str(member.profile.name)+(" ◈ 조종" if id==value.crew.pilot_id else "")+" · "+location+"\n  "+state)
	return "\n".join(lines)
static func blockers(value: Dictionary,need_ready: bool=true) -> String:
	var pending: PackedStringArray=[]
	for id in value.crew.members:
		var member: Dictionary=value.crew.members[id]
		if not member.get("connected",false) or not group(value,id):continue
		if not member.get("aboard",false):pending.append(str(member.profile.name)+" 탑승")
		elif need_ready and not member.get("ready",false):pending.append(str(member.profile.name)+" 준비")
	return " · ".join(pending)

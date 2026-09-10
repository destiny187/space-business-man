class_name FrontierCorporateTraceSurvey
extends RefCounted
## Uses host vessel position and live held input. Only persisted stages reach the client.
static func step(authority: FrontierCrewAuthority,peer: int,local: Dictionary,delta: float) -> void:
	var nav: Dictionary=local.crew.navigation
	var target:=FrontierCorporateTraces.target(local.manifest,nav,authority.inputs[peer].aim)
	if target.is_empty():authority.scans.erase(peer);return
	var stage:=int(FrontierCorporateTraces.records(authority.world).get(target.id,0))
	var reason:=FrontierCorporateTraces.reason(local.manifest,nav,target,stage)
	if not reason.is_empty():
		authority.scans[peer]={"kind":"corporate_trace","id":target.id,"stage":stage,"progress":0.0,"reason":reason};return
	var previous: Dictionary=authority.scans.get(peer,{})
	var progress: float=float(previous.get("progress",0)) if previous.get("id","")==target.id and int(previous.get("stage",-1))==stage else 0.0
	var cfg:=FrontierCorporateTraces.rules(local.manifest)
	progress+=delta/float(cfg.identify_seconds if stage==0 else cfg.inspect_seconds)
	authority.scans[peer]={"kind":"corporate_trace","id":target.id,"stage":stage,"progress":minf(.99,progress)}
	if progress<1:return
	var draft: Dictionary=authority.world.duplicate(true)
	if not draft.crew.has("corporate_traces"):draft.crew.corporate_traces={}
	# Reinsert so bounded snapshots retain the latest updated record, not only new IDs.
	draft.crew.corporate_traces.erase(target.id);draft.crew.corporate_traces[target.id]=stage+1
	draft.crew.revision+=1
	if not authority.save_world.call(draft):
		authority.scans.erase(peer);authority.stopped=true;authority.error="기업 활동 조사 저장 실패로 공동 세계를 정지했습니다.";return
	authority.world=draft
	authority.scans[peer]={"kind":"corporate_trace","id":target.id,"stage":stage+1,"progress":0.0,"known":stage+1==2}

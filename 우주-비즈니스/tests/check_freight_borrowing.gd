extends SceneTree
func _initialize() -> void:
	var first: String=FrontierPlayerProfile.new_character("이전 운항자",1).character_id
	var next: String=FrontierPlayerProfile.new_character("다음 운항자",2).character_id
	var w: Dictionary={"crew":{"shuttles":{first:{}},"freight_records":{"freight-v1:0":{"stage":3,"carrier":"shuttle:"+first,"at":1},"freight-v1:702":{"stage":2,"carrier":"shuttle:"+first,"at":2}}}}
	FrontierFreightSalvage.reassign(w,first,next);w.crew.shuttles[next]=w.crew.shuttles[first];w.crew.shuttles.erase(first)
	var valid:=FrontierFreightSalvage.valid(w.crew.freight_records,w.crew)
	var kept: bool=w.crew.freight_records["freight-v1:0"].carrier=="shuttle:"+first
	var cargo: bool=FrontierFreightSalvage.carried(w.crew.freight_records,"shuttle:"+next)=="freight-v1:702"
	print("FREIGHT_BORROWING valid=",valid," receipt_retained=",kept," cargo_transferred=",cargo);quit(0 if valid and kept and cargo else 1)

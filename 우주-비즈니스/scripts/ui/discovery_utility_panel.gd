class_name FrontierDiscoveryUtilityPanel
extends VBoxContainer
var panel: FrontierBusinessPanel
var sample: OptionButton
var install: Button
var remove_sample: Button
var mute: Button
var tone: Button
var signature:=""
func configure(owner_panel: FrontierBusinessPanel) -> void:
 panel=owner_panel
 sample=OptionButton.new();sample.add_theme_constant_override("icon_max_width",24);sample.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;add_child(sample)
 install=panel.button(self,"선택한 표본 넣기",func():send("install",str(sample.get_item_metadata(sample.selected)) if sample.selected>=0 else ""))
 remove_sample=panel.button(self,"배양 표본 회수",func():send("remove"))
 mute=panel.button(self,"소리 끄기",func():send("mute"))
 tone=panel.button(self,"공명 음높이 변경",func():send("tone"))
func send(action: String,specimen: String="") -> void:
 panel.command.emit("business_discovery_use",{"building_id":panel.context_id,"action":action,"specimen":specimen})
func refresh(b: Dictionary) -> void:
 var kind:=str(b.get("type",""));visible=FrontierDiscoveryUtilities.building(kind)
 if not visible:return
 var tank: bool=kind=="luminous_vivarium"
 sample.visible=tank;install.visible=tank;remove_sample.visible=tank
 mute.visible=kind in ["resonance_garden","flood_sentinel"];tone.visible=kind=="resonance_garden"
 mute.text="소리 켜기" if b.get("muted",false) else "소리 끄기"
 tone.text="공명 음높이 %d / 3  다음 음높이"%(int(b.get("resonance_tone",1))+1)
 if not tank:return
 var candidates: Dictionary={}
 for key in panel.ledger.get("bags",{}).get(panel.actor_id,{}):
  if int(panel.ledger.bags[panel.actor_id][key])>0 and FrontierDiscoveryUtilities.specimen_allowed(key):candidates[key]=FrontierSpeciesNames.display(panel.knowledge,FrontierSpecimenItems.decode(key).form_id)+"  표본 "+str(FrontierSpecimenItems.decode(key).id).left(6)
 var next:=str(candidates)
 if next!=signature:
  signature=next;sample.clear()
  for key in candidates:
   sample.add_icon_item(FrontierResourceIcons.texture(key),candidates[key]);sample.set_item_metadata(sample.item_count-1,key)
 var occupied: bool=not b.get("specimen_stock",{}).is_empty()
 install.disabled=occupied or candidates.is_empty();remove_sample.disabled=not occupied
 install.text="배낭에 온대 / 습지 / 해양 미생물 표본 필요" if candidates.is_empty() else "선택한 표본 넣기"

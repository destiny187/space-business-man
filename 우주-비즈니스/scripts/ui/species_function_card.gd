extends VBoxContainer
const Functions=preload("res://scripts/domain/species_functions.gd")
var sample_image: TextureRect
var facility_image: TextureRect
var title: Label
var detail: Label
var action: Button
var form_id:=""
var app: FrontierCrewExpedition
func configure(owner_app: FrontierCrewExpedition) -> void:
 app=owner_app
 var strip:=HBoxContainer.new();add_child(strip)
 sample_image=picture(strip)
 FrontierInterfaceStyle.label(strip,"→",24)
 facility_image=picture(strip)
 var text:=VBoxContainer.new();text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;strip.add_child(text)
 title=FrontierInterfaceStyle.label(text,"",14);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 detail=FrontierInterfaceStyle.label(text,"",12);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 action=Button.new();add_child(action);action.pressed.connect(func():app.surface_action("surface_study"))
func picture(parent: Node) -> TextureRect:
 var image:=TextureRect.new();image.custom_minimum_size=Vector2(52,52);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;parent.add_child(image);return image
func refresh(form: Dictionary,ecology: Dictionary,near: bool,at_station: bool) -> void:
 var function:=Functions.definition(form)
 visible=not function.is_empty()
 if not visible:return
 var definition:=FrontierCatalog.entry("buildings",function.building)
 if form_id!=form.id:
  form_id=form.id
  sample_image.texture=FrontierResourceIcons.texture(FrontierResourceIcons.specimen_id(form))
  facility_image.texture=load("res://assets/ui/previews/"+str(definition.model)+".png")
 var done: bool=Functions.studied(ecology,form.id) or app.survey_journal.selected_entry.get("row",{}).get("species_studied",false)
 title.text="%s  %s 처리 +%d%%"%[function.name,definition.name,roundi(float(function.bonus)*100)]
 title.modulate=FrontierInterfaceStyle.ACCENT if done else FrontierInterfaceStyle.MUTED
 var physical:=false
 for sample in FrontierSpecimenItems.carried(app.session.latest.get("inventory",{})).values():
  if sample.form_id==form.id:physical=true;break
 detail.text="분석 후 다른 행성에 이식  지원 구획 안의 설비에 가장 강한 한 종만 적용"
 action.visible=at_station and not done
 action.text="기능 분석  광물 %d"%int(Functions.config().study_rock_cost)
 action.disabled=not near or not physical or not ecology.research.has(form.environment) or int(app.session.latest.crew.rock)<int(Functions.config().study_rock_cost)
 if done:
  var count:=0
  var world: Dictionary={"location":app.session.latest.location,"ecology":ecology}
  var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(world.location,{})
  for b in site.get("buildings",{}).values():
   if Functions.support(world,b).get("form_id")==form.id:count+=1
  detail.text=("복원 설비 %d개에 연결  지원이 끊기면 효과 중단"%count) if count>0 else "분석 완료  다른 행성의 지원 구획에 이식하고 해당 설비를 배치하세요."
 elif not physical:detail.text="이 종의 실물 표본을 아이템창에 가져오세요. 분석 후에도 표본을 보존합니다."
 elif not ecology.research.has(form.environment):detail.text="서식 환경의 기초 분석을 먼저 완료하세요."
 action.tooltip_text=detail.text

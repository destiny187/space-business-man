class_name FrontierSharedPlayGuide
extends RefCounted
## Monotonic expedition milestones. No inventory, research or building ownership is granted.
const KEYS=["solar_move","solar_boost","solar_scan","travel","inventory","field_scan","mined","materials_review","built","terraform_view","complete"]
static func validate(value: Variant) -> String:
 if not value is Dictionary or value.size()>KEYS.size():return "공동 가이드 기록 오류"
 for key in value:
  if key not in KEYS or not value[key] is bool or not value[key]:return "공동 가이드 단계 오류"
 return ""
static func merge(crew: Dictionary,steps: Array) -> void:
 var progress: Dictionary=crew.get("play_guide",{}).duplicate()
 for key in steps:
  if key in KEYS:progress[key]=true
 crew.play_guide=progress
static func report(crew: Dictionary,args: Dictionary) -> String:
 var steps: Variant=args.get("steps")
 if not steps is Array or steps.is_empty() or steps.size()>KEYS.size():return "공동 가이드 보고 오류"
 for key in steps:
  if not key is String or key not in KEYS:return "알 수 없는 공동 가이드 단계"
 merge(crew,steps);return ""

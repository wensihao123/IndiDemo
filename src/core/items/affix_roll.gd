extends RefCounted
class_name AffixRoll
## 一条已 roll 定的词缀实例:从 AffixDef 某 Tier 的区间里摇出的具体值(ARCHITECTURE §3.3)。
## kind 以 StringName(flat/percent)存,可序列化;转 StatModifier 枚举在 to_modifiers 边界做。

var stat: StringName
var kind: StringName = GameKeys.KIND_FLAT
var tier: int = 0
var value: float = 0.0


func _init(p_stat: StringName = &"", p_kind: StringName = GameKeys.KIND_FLAT, p_tier: int = 0, p_value: float = 0.0) -> void:
	stat = p_stat
	kind = p_kind
	tier = p_tier
	value = p_value


func to_dict() -> Dictionary:
	return {"stat": String(stat), "kind": String(kind), "tier": tier, "value": value}


static func from_dict(d: Dictionary) -> AffixRoll:
	return AffixRoll.new(
		StringName(d.get("stat", "")),
		StringName(d.get("kind", GameKeys.KIND_FLAT)),
		int(d.get("tier", 0)),
		float(d.get("value", 0.0)))

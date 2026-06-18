extends RefCounted
class_name StatModifier
## 单条属性增量:装备/buff 注入战斗实体的最小修饰单元(ARCHITECTURE §3.2 属性引擎)。
## kind 决定它进 Σflat 还是 Σpercent;source 是来源标识(如 base_id/技能名),
## 用于无损卸下(invariant #2:remove_modifiers_by_source 必须精确还原)。

enum Kind { FLAT, PERCENT }

var stat: StringName
var kind: Kind = Kind.FLAT
var value: float = 0.0
var source: Variant = null


func _init(p_stat: StringName = &"", p_kind: Kind = Kind.FLAT, p_value: float = 0.0, p_source: Variant = null) -> void:
	stat = p_stat
	kind = p_kind
	value = p_value
	source = p_source


## 数据层用 StringName 存 kind(flat/percent),在此边界转成枚举(PLAN 层3 ItemInstance 调用)。
static func kind_from_name(name: StringName) -> Kind:
	return Kind.PERCENT if name == GameKeys.KIND_PERCENT else Kind.FLAT

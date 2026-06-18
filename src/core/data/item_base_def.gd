extends RefCounted
class_name ItemBaseDef
## 装备基底模板(只读蓝图)。一个槽位一种基底原型(v1)。
## 招牌轴给身份;基底值随 ilvl 走占位曲线 value = base + per_ilvl × ilvl(数值占位,F1 精调)。

var slot: StringName
## 招牌轴模式:SIG_ALL(武器双轴全给)/ SIG_PICK_ONE(饰品掉落时三选一)。
var signature_mode: StringName = GameKeys.SIG_ALL
## 候选招牌轴(SIG_ALL 全生效;SIG_PICK_ONE 由 LootGenerator 选一条)。
var signature_axes: Array[StringName] = []
## 每条招牌轴的占位成长曲线:axis(StringName) -> {"base": float, "per_ilvl": float}。
var base_curves: Dictionary = {}


## 某招牌轴在给定 ilvl 的基底值(占位线性曲线;无曲线返回 0)。
func base_value(axis: StringName, ilvl: int) -> float:
	var c: Variant = base_curves.get(axis)
	if c == null:
		return 0.0
	return float(c.get("base", 0.0)) + float(c.get("per_ilvl", 0.0)) * ilvl

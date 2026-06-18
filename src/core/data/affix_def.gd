extends RefCounted
class_name AffixDef
## 词缀模板(只读蓝图)。一种词缀 = 一个战斗维度 + 平加/百分比 + 可出部位池 + 一串 Tier。
## Tier 机制(04 §3.4):每阶 = 数值区间 + ilvl 解锁门槛;ilvl ≥ 门槛才可 roll 到该阶。

var stat: StringName
## 平加 KIND_FLAT / 百分比 KIND_PERCENT。
var kind: StringName = GameKeys.KIND_FLAT
## 此词缀可出现在哪些部位(slot StringName 列表)。
var slot_pool: Array[StringName] = []
## Tier 列表;每项 = {"tier": int, "min": float, "max": float, "ilvl_req": int, "weight": float}。
var tiers: Array = []


## 取所有 ilvl 门槛 ≤ 给定 ilvl 的合格 Tier(04 §3.4)。
func qualified_tiers(ilvl: int) -> Array:
	var out: Array = []
	for t in tiers:
		if int(t.get("ilvl_req", 1)) <= ilvl:
			out.append(t)
	return out

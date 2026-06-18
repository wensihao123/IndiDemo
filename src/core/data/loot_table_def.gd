extends RefCounted
class_name LootTableDef
## 掉落规则模板(只读蓝图)。稀有度→词缀条数(白0/蓝1-2/金3+,04 §3.2)、
## 自动分解门槛(稀有度 ≤ 门槛 → 分解,04 §3.7)、单件分解产材料数(占位)。

## 稀有度 -> [min, max] 词缀条数(含两端)。
var rarity_affix_count: Dictionary = {}
## 稀有度 ≤ 此门槛(按 GameKeys.rarity_rank)→ 自动分解。默认白。
var decompose_threshold: StringName = GameKeys.RARITY_WHITE
## 单件分解产出的对应部位材料数(占位 1)。
var material_per_decompose: int = 1


## 给定稀有度的词缀条数区间 [min, max];未配置返回 [0, 0]。
func affix_count_range(rarity: StringName) -> Array:
	var r: Variant = rarity_affix_count.get(rarity)
	if r == null:
		return [0, 0]
	return [int(r[0]), int(r[1])]


## 该稀有度是否应自动分解(稀有度序数 ≤ 门槛序数)。
func should_decompose(rarity: StringName) -> bool:
	return GameKeys.rarity_rank(rarity) <= GameKeys.rarity_rank(decompose_threshold)

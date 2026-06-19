extends RefCounted
class_name LootGenerator
## 掉落生成(纯逻辑,承 04 B-4 PoE roll):稀有度定条数、ilvl 定可取 Tier、部位池定可选词缀。
## rng 由调用方注入(可 seed → 可测);本批数值全占位,生成的是"结构正确"的 ItemInstance。

## 按权重数组随机选一个下标(归一化加权)。空数组或权重和≤0 时退回 0。负权重按 0 处理。
static func pick_weighted(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(0.0, float(w))
	if total <= 0.0:
		return 0
	var r := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += maxf(0.0, float(weights[i]))
		if r < acc:
			return i
	return weights.size() - 1


## ilvl/rarity 来源属第二批战斗侧接线(PLAN D8);此处皆为入参,纯函数。
func generate(slot: StringName, ilvl: int, rarity: StringName, registry: DataRegistry, rng: RandomNumberGenerator) -> ItemInstance:
	var inst := ItemInstance.new(slot, ilvl, rarity)
	var base := registry.get_item_base(slot)
	if base != null:
		inst.signature_axes = _roll_signature_axes(base, rng)
	var table := registry.get_loot_table()
	var count := 0
	if table != null:
		var rng_range := table.affix_count_range(rarity)   # [min,max]
		count = rng.randi_range(int(rng_range[0]), int(rng_range[1]))
	inst.affixes = _roll_affixes(slot, ilvl, count, registry, rng)
	return inst


## ALL→全招牌轴;PICK_ONE→随机一轴(饰品三选一)。
func _roll_signature_axes(base: ItemBaseDef, rng: RandomNumberGenerator) -> Array[StringName]:
	if base.signature_mode == GameKeys.SIG_PICK_ONE and not base.signature_axes.is_empty():
		return [base.signature_axes[rng.randi() % base.signature_axes.size()]]
	return base.signature_axes.duplicate()


## 从部位池选 count 条不重复 stat 的词缀;每条在 ilvl 合格 Tier 里挑一阶并区间 roll 值。
func _roll_affixes(slot: StringName, ilvl: int, count: int, registry: DataRegistry, rng: RandomNumberGenerator) -> Array[AffixRoll]:
	var candidates: Array[AffixDef] = []
	for a in registry.get_affixes_for_slot(slot):
		if not a.qualified_tiers(ilvl).is_empty():
			candidates.append(a)
	count = min(count, candidates.size())
	var rolls: Array[AffixRoll] = []
	for _i in count:
		var pick := rng.randi() % candidates.size()
		var a: AffixDef = candidates[pick]
		candidates.remove_at(pick)              # 不重复 stat(每个 AffixDef 一个独占 stat)
		var tiers := a.qualified_tiers(ilvl)
		var t: Dictionary = tiers[rng.randi() % tiers.size()]
		var value := rng.randf_range(float(t.get("min", 0.0)), float(t.get("max", 0.0)))
		rolls.append(AffixRoll.new(a.stat, a.kind, int(t.get("tier", 0)), value))
	return rolls

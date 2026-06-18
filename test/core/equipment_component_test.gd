extends GdUnitTestSuite
## PLAN 步7 验证:EquipmentComponent 穿/脱/换装 ↔ StatsComponent 注入/无损回收(层3)。

func _registry() -> DataRegistry:
	# 只需基底招牌轴可回查;affixes 由 ItemInstance 自带,故 ingest 空词缀池。
	var bases := {
		"weapon": {"slot": "weapon", "signature_mode": "all", "signature_axes": ["attack"],
			"base_curves": {"attack": {"base": 3.0, "per_ilvl": 0.5}}},
	}
	var table := {"rarity_affix_count": {"white": [0, 0], "blue": [1, 2], "gold": [3, 4]},
		"decompose_threshold": "white"}
	var r := DataRegistry.new()
	r.ingest(bases, [], table)
	return r

func _weapon(affixes: Array[AffixRoll], ilvl: int = 10) -> ItemInstance:
	var inst := ItemInstance.new(GameKeys.SLOT_WEAPON, ilvl, GameKeys.RARITY_BLUE)
	inst.signature_axes = [GameKeys.STAT_ATTACK]   # ilvl10 招牌攻击 = 3 + 0.5×10 = 8
	inst.affixes = affixes
	return inst

func test_equip_raises_final_by_modifier_sum() -> void:
	var r := _registry()
	var stats := StatsComponent.new()
	var eq := EquipmentComponent.new(stats, r)
	var item := _weapon([AffixRoll.new(GameKeys.STAT_ATTACK, GameKeys.KIND_FLAT, 1, 5.0)])
	eq.equip(GameKeys.SLOT_WEAPON, item)
	assert_float(stats.get_final(GameKeys.STAT_ATTACK)).is_equal(13.0)  # 招牌8 + flat5
	assert_bool(eq.is_slot_empty(GameKeys.SLOT_WEAPON)).is_false()

func test_equip_percent_affix_scales() -> void:
	var r := _registry()
	var stats := StatsComponent.new()
	var eq := EquipmentComponent.new(stats, r)
	eq.equip(GameKeys.SLOT_WEAPON, _weapon([AffixRoll.new(GameKeys.STAT_ATTACK, GameKeys.KIND_PERCENT, 1, 0.5)]))
	assert_float(stats.get_final(GameKeys.STAT_ATTACK)).is_equal(12.0)  # 招牌8 ×1.5

func test_unequip_is_lossless() -> void:
	var r := _registry()
	var stats := StatsComponent.new()
	stats.set_base(GameKeys.STAT_ATTACK, 2.0)
	var eq := EquipmentComponent.new(stats, r)
	eq.equip(GameKeys.SLOT_WEAPON, _weapon([AffixRoll.new(GameKeys.STAT_ATTACK, GameKeys.KIND_FLAT, 1, 5.0)]))
	assert_float(stats.get_final(GameKeys.STAT_ATTACK)).is_equal(15.0)  # base2 + 招牌8 + flat5
	var off := eq.unequip(GameKeys.SLOT_WEAPON)
	assert_object(off).is_not_null()
	assert_float(stats.get_final(GameKeys.STAT_ATTACK)).is_equal(2.0)   # 精确回 base
	assert_bool(eq.is_slot_empty(GameKeys.SLOT_WEAPON)).is_true()

func test_swap_leaves_no_residual() -> void:
	var r := _registry()
	var stats := StatsComponent.new()
	var eq := EquipmentComponent.new(stats, r)
	eq.equip(GameKeys.SLOT_WEAPON, _weapon([AffixRoll.new(GameKeys.STAT_ATTACK, GameKeys.KIND_FLAT, 1, 100.0)]))
	var prev := eq.equip(GameKeys.SLOT_WEAPON, _weapon([AffixRoll.new(GameKeys.STAT_ATTACK, GameKeys.KIND_FLAT, 1, 5.0)]))
	assert_object(prev).is_not_null()  # 换装返回旧件
	assert_float(stats.get_final(GameKeys.STAT_ATTACK)).is_equal(13.0)  # 仅新件:招牌8 + flat5,旧 +100 不残留

func test_empty_slots_reports_all_three_initially() -> void:
	var r := _registry()
	var eq := EquipmentComponent.new(StatsComponent.new(), r)
	assert_int(eq.empty_slots().size()).is_equal(3)

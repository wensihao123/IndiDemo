extends GdUnitTestSuite
## PLAN 步10 验证:LootIntake 填空优先于分解的路由(04 §3.8)。
## ① 空槽→穿(含白);② 已穿+白→出材料、不进包;③ 已穿+蓝/金→进包、材料不变。

func _registry() -> DataRegistry:
	var r := DataRegistry.new()
	r.load_all()
	return r

func _item(rarity: StringName) -> ItemInstance:
	var inst := ItemInstance.new(GameKeys.SLOT_WEAPON, 10, rarity)
	inst.signature_axes = [GameKeys.STAT_ATTACK, GameKeys.STAT_ATTACK_SPEED]
	return inst

func test_empty_slot_equips_even_white() -> void:
	var r := _registry()
	var eq := EquipmentComponent.new(StatsComponent.new(), r)
	var ps: PlayerState = auto_free(PlayerState.new())
	var outcome := LootIntake.handle_drop(_item(GameKeys.RARITY_WHITE), eq, ps, r.get_loot_table())
	assert_str(outcome).is_equal("equipped")
	assert_bool(eq.is_slot_empty(GameKeys.SLOT_WEAPON)).is_false()
	assert_int(ps.bag.size()).is_equal(0)

func test_white_on_full_slot_decomposes_to_material() -> void:
	var r := _registry()
	var eq := EquipmentComponent.new(StatsComponent.new(), r)
	var ps: PlayerState = auto_free(PlayerState.new())
	eq.equip(GameKeys.SLOT_WEAPON, _item(GameKeys.RARITY_BLUE))  # 占槽
	var outcome := LootIntake.handle_drop(_item(GameKeys.RARITY_WHITE), eq, ps, r.get_loot_table())
	assert_str(outcome).is_equal("decomposed")
	assert_int(ps.get_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE)).is_equal(1)
	assert_int(ps.bag.size()).is_equal(0)

func test_blue_on_full_slot_goes_to_bag() -> void:
	var r := _registry()
	var eq := EquipmentComponent.new(StatsComponent.new(), r)
	var ps: PlayerState = auto_free(PlayerState.new())
	eq.equip(GameKeys.SLOT_WEAPON, _item(GameKeys.RARITY_BLUE))  # 占槽
	var outcome := LootIntake.handle_drop(_item(GameKeys.RARITY_GOLD), eq, ps, r.get_loot_table())
	assert_str(outcome).is_equal("bagged")
	assert_int(ps.bag.size()).is_equal(1)
	assert_int(ps.get_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE)).is_equal(0)

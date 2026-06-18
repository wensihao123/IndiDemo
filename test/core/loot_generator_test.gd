extends GdUnitTestSuite
## PLAN 步9 验证:LootGenerator 承 PoE roll —— 条数随稀有度、stat 不重复且在池内、门槛守约、招牌轴正确。
## 用实发配置 + seed 化 rng,断言结构与约束(非平衡值,守 R4 占位)。

func _registry() -> DataRegistry:
	var r := DataRegistry.new()
	r.load_all()
	return r

func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng

func test_white_yields_zero_affixes() -> void:
	var inst := LootGenerator.new().generate(GameKeys.SLOT_WEAPON, 50, GameKeys.RARITY_WHITE, _registry(), _rng(1))
	assert_int(inst.affixes.size()).is_equal(0)

func test_blue_yields_one_or_two() -> void:
	var inst := LootGenerator.new().generate(GameKeys.SLOT_WEAPON, 50, GameKeys.RARITY_BLUE, _registry(), _rng(7))
	assert_int(inst.affixes.size()).is_between(1, 2)

func test_gold_yields_three_or_four() -> void:
	var inst := LootGenerator.new().generate(GameKeys.SLOT_WEAPON, 50, GameKeys.RARITY_GOLD, _registry(), _rng(3))
	assert_int(inst.affixes.size()).is_between(3, 4)

func test_affix_stats_are_distinct_and_in_pool() -> void:
	var r := _registry()
	var inst := LootGenerator.new().generate(GameKeys.SLOT_WEAPON, 50, GameKeys.RARITY_GOLD, r, _rng(11))
	var pool_stats: Array = []
	for a in r.get_affixes_for_slot(GameKeys.SLOT_WEAPON):
		pool_stats.append(a.stat)
	var seen: Array = []
	for roll in inst.affixes:
		assert_bool(seen.has(roll.stat)).is_false()      # stat 不重复
		assert_bool(pool_stats.has(roll.stat)).is_true()  # 在该部位池内
		seen.append(roll.stat)

func test_no_affix_exceeds_ilvl_gate() -> void:
	# 门槛守约:每条 affix 的所选 Tier 的 ilvl_req 必 ≤ 物品 ilvl。低 ilvl 自然取不到高 Tier。
	var r := _registry()
	var ilvl := 1
	var inst := LootGenerator.new().generate(GameKeys.SLOT_ACCESSORY, ilvl, GameKeys.RARITY_GOLD, r, _rng(5))
	for roll in inst.affixes:
		assert_int(_tier_ilvl_req(r, GameKeys.SLOT_ACCESSORY, roll.stat, roll.tier)).is_less_equal(ilvl)

func test_signature_all_gives_all_axes() -> void:
	var inst := LootGenerator.new().generate(GameKeys.SLOT_WEAPON, 20, GameKeys.RARITY_BLUE, _registry(), _rng(2))
	assert_int(inst.signature_axes.size()).is_equal(2)  # 武器 ALL:攻击+攻速

func test_signature_pick_one_gives_single_axis() -> void:
	var inst := LootGenerator.new().generate(GameKeys.SLOT_ACCESSORY, 20, GameKeys.RARITY_BLUE, _registry(), _rng(2))
	assert_int(inst.signature_axes.size()).is_equal(1)  # 饰品 PICK_ONE

func _tier_ilvl_req(r: DataRegistry, slot: StringName, stat: StringName, tier: int) -> int:
	for a in r.get_affixes_for_slot(slot):
		if a.stat == stat:
			for t in a.tiers:
				if int(t.get("tier", -1)) == tier:
					return int(t.get("ilvl_req", 0))
	return -1

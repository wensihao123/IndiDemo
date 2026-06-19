extends GdUnitTestSuite
## PLAN 步8 验证:PlayerState 材料累加 + material_gained signal;Character/PlayerState round-trip 等值(层3 D6)。

func test_material_accumulates() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	ps.add_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE, 1)
	ps.add_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE, 2)
	assert_int(ps.get_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE)).is_equal(3)
	# 不同 (部位×稀有度) 互不串
	assert_int(ps.get_material(GameKeys.SLOT_ARMOR, GameKeys.RARITY_WHITE)).is_equal(0)

func test_material_gained_signal_fires() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	monitor_signals(ps)
	ps.add_material(GameKeys.SLOT_ARMOR, GameKeys.RARITY_WHITE, 4)
	await assert_signal(ps).is_emitted("material_gained", [GameKeys.SLOT_ARMOR, GameKeys.RARITY_WHITE, 4])

func _sample_item() -> ItemInstance:
	var inst := ItemInstance.new(GameKeys.SLOT_WEAPON, 12, GameKeys.RARITY_GOLD)
	inst.signature_axes = [GameKeys.STAT_ATTACK, GameKeys.STAT_ATTACK_SPEED]
	inst.affixes = [
		AffixRoll.new(GameKeys.STAT_CRIT_CHANCE, GameKeys.KIND_FLAT, 3, 0.04),
		AffixRoll.new(GameKeys.STAT_ATTACK, GameKeys.KIND_PERCENT, 1, 0.2),
	]
	return inst

func test_character_build_stats_seeds_base() -> void:
	# 接缝(第二批层5消费):Character.base_stats → StatsComponent 基底等值。
	var c := Character.new(&"hero_1", &"warrior")
	c.base_stats = {GameKeys.STAT_ATTACK: 5.0, GameKeys.STAT_MAX_HP: 100.0}
	var s := c.build_stats()
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(5.0)
	assert_float(s.get_final(GameKeys.STAT_MAX_HP)).is_equal(100.0)

func test_character_round_trip() -> void:
	var c := Character.new(&"hero_1", &"warrior")
	c.base_stats = {GameKeys.STAT_ATTACK: 5.0, GameKeys.STAT_MAX_HP: 100.0}
	c.equipped[GameKeys.SLOT_WEAPON] = _sample_item()
	var d := c.to_dict()
	var c2 := Character.from_dict(d)
	assert_dict(c2.to_dict()).is_equal(d)

func test_reset_clears_all_persistent_state() -> void:
	# reset-on-boot 的内部方法:roster/bag/materials 三者全清(REFACTOR-02 §3,守测试隔离)。
	var ps: PlayerState = auto_free(PlayerState.new())
	var c := Character.new(&"hero_1", &"warrior")
	ps.roster.append(c)
	ps.add_to_bag(_sample_item())
	ps.add_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE, 1)
	ps.reset()
	assert_int(ps.roster.size()).is_equal(0)
	assert_int(ps.bag.size()).is_equal(0)
	assert_int(ps.materials.size()).is_equal(0)


func test_player_state_round_trip() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var c := Character.new(&"hero_1", &"warrior")
	c.base_stats = {GameKeys.STAT_ATTACK: 5.0}
	c.equipped[GameKeys.SLOT_WEAPON] = _sample_item()
	ps.roster.append(c)
	ps.add_to_bag(_sample_item())
	ps.add_material(GameKeys.SLOT_ARMOR, GameKeys.RARITY_WHITE, 2)
	var d := ps.to_dict()
	var ps2: PlayerState = auto_free(PlayerState.new())
	ps2.from_dict(d)
	assert_dict(ps2.to_dict()).is_equal(d)

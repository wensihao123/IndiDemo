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


# ── PLAN 步4:手动换装 / 强化元操作(城镇主动路径) ──────────────────────────

func _enh_cfg() -> EnhanceConfigDef:
	return EnhanceConfigDef.new()  # 默认 per_level=0.1 cap=10 cost_base=1 cost_step=1

func test_equip_from_bag_swaps_and_returns_prev() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var c := Character.new(&"hero_1", &"warrior")
	var old_w := _sample_item()
	c.equipped[GameKeys.SLOT_WEAPON] = old_w
	var new_w := _sample_item()
	ps.add_to_bag(new_w)
	ps.equip_from_bag(c, GameKeys.SLOT_WEAPON, new_w)
	assert_object(c.equipped[GameKeys.SLOT_WEAPON]).is_same(new_w)
	assert_bool(ps.bag.has(old_w)).is_true()   # 旧件退回背包(无损)
	assert_bool(ps.bag.has(new_w)).is_false()  # 新件已出包

func test_equip_into_empty_slot_leaves_bag_without_prev() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var c := Character.new(&"hero_1", &"warrior")
	var w := _sample_item()
	ps.add_to_bag(w)
	ps.equip_from_bag(c, GameKeys.SLOT_WEAPON, w)
	assert_object(c.equipped[GameKeys.SLOT_WEAPON]).is_same(w)
	assert_int(ps.bag.size()).is_equal(0)

func test_unequip_to_bag_clears_slot() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var c := Character.new(&"hero_1", &"warrior")
	var w := _sample_item()
	c.equipped[GameKeys.SLOT_WEAPON] = w
	ps.unequip_to_bag(c, GameKeys.SLOT_WEAPON)
	assert_bool(c.equipped.has(GameKeys.SLOT_WEAPON)).is_false()
	assert_bool(ps.bag.has(w)).is_true()

func test_enhance_succeeds_and_deducts_material() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var w := _sample_item()  # base_id = weapon, enhance_level 0
	ps.add_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE, 5)
	var ok := ps.enhance_item(w, _enh_cfg())
	assert_bool(ok).is_true()
	assert_int(w.enhance_level).is_equal(1)
	assert_int(ps.get_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE)).is_equal(4)  # 扣 cost(0)=1

func test_enhance_cost_curve_is_one_plus_level() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var w := _sample_item()
	ps.add_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE, 10)
	ps.enhance_item(w, _enh_cfg())  # 0→1 花 1,剩 9
	ps.enhance_item(w, _enh_cfg())  # 1→2 花 2,剩 7
	assert_int(w.enhance_level).is_equal(2)
	assert_int(ps.get_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE)).is_equal(7)

func test_enhance_rejects_when_material_insufficient_no_partial_deduct() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var w := _sample_item()
	# level 2 → cost 3,只给 2 → 拒绝,不扣半截。
	w.enhance_level = 2
	ps.add_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE, 2)
	var ok := ps.enhance_item(w, _enh_cfg())
	assert_bool(ok).is_false()
	assert_int(w.enhance_level).is_equal(2)  # 不变
	assert_int(ps.get_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE)).is_equal(2)  # 不扣

func test_enhance_rejects_at_max_level() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var w := _sample_item()
	w.enhance_level = 10  # cap
	ps.add_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE, 99)
	var ok := ps.enhance_item(w, _enh_cfg())
	assert_bool(ok).is_false()
	assert_int(w.enhance_level).is_equal(10)
	assert_int(ps.get_material(GameKeys.SLOT_WEAPON, GameKeys.RARITY_WHITE)).is_equal(99)

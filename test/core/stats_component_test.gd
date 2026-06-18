extends GdUnitTestSuite
## PLAN 步5 验证:StatsComponent 终值公式 + 脏缓存 + 无损卸下(层2 属性引擎)。
## ① 公式 Final=(base+Σflat)×(1+Σpercent);② 缓存按需重算;③ invariant #2 无损还原。

func _stats() -> StatsComponent:
	return StatsComponent.new()

# ── ① 终值公式 ────────────────────────────────────────────────────────────────

func test_base_only() -> void:
	var s := _stats()
	s.set_base(GameKeys.STAT_ATTACK, 10.0)
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(10.0)

func test_flat_adds_to_base() -> void:
	var s := _stats()
	s.set_base(GameKeys.STAT_ATTACK, 10.0)
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.FLAT, 5.0, "gear"))
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(15.0)

func test_percent_scales_base() -> void:
	var s := _stats()
	s.set_base(GameKeys.STAT_ATTACK, 10.0)
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.PERCENT, 0.5, "buff"))
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(15.0)  # 10 × 1.5

func test_flat_then_percent_order() -> void:
	# (base + Σflat) × (1 + Σpercent) = (10 + 5) × (1 + 0.5) = 22.5
	var s := _stats()
	s.set_base(GameKeys.STAT_ATTACK, 10.0)
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.FLAT, 5.0, "gear"))
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.PERCENT, 0.5, "buff"))
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(22.5)

func test_multiple_same_kind_sum() -> void:
	var s := _stats()
	s.set_base(GameKeys.STAT_ATTACK, 0.0)
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.FLAT, 3.0, "a"))
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.FLAT, 4.0, "b"))
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.PERCENT, 0.1, "c"))
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.PERCENT, 0.2, "d"))
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(7.0 * 1.3)  # 9.1

func test_modifier_only_no_base() -> void:
	# 纯修饰符(base 缺省 0):flat 5 → 5;再叠 percent
	var s := _stats()
	s.add_modifier(StatModifier.new(GameKeys.STAT_MAX_HP, StatModifier.Kind.FLAT, 5.0, "gear"))
	assert_float(s.get_final(GameKeys.STAT_MAX_HP)).is_equal(5.0)

# ── ② 缓存按需重算 ────────────────────────────────────────────────────────────

func test_cache_recomputes_after_write() -> void:
	var s := _stats()
	s.set_base(GameKeys.STAT_ATTACK, 10.0)
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(10.0)  # 填缓存
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.FLAT, 5.0, "gear"))
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(15.0)  # 写后置脏→重算

# ── ③ invariant #2:按来源无损卸下 ────────────────────────────────────────────

func test_remove_by_source_is_lossless() -> void:
	var s := _stats()
	s.set_base(GameKeys.STAT_ATTACK, 10.0)
	var before := s.get_final(GameKeys.STAT_ATTACK)
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.FLAT, 5.0, "sword"))
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.PERCENT, 0.25, "sword"))
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_not_equal(before)
	var removed := s.remove_modifiers_by_source("sword")
	assert_int(removed).is_equal(2)
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(before)  # 精确还原

func test_remove_by_source_keeps_others() -> void:
	var s := _stats()
	s.set_base(GameKeys.STAT_ATTACK, 10.0)
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.FLAT, 5.0, "sword"))
	s.add_modifier(StatModifier.new(GameKeys.STAT_ATTACK, StatModifier.Kind.FLAT, 3.0, "ring"))
	s.remove_modifiers_by_source("sword")
	assert_float(s.get_final(GameKeys.STAT_ATTACK)).is_equal(13.0)  # 只剩 ring

func test_kind_from_name_boundary() -> void:
	assert_int(StatModifier.kind_from_name(GameKeys.KIND_PERCENT)).is_equal(StatModifier.Kind.PERCENT)
	assert_int(StatModifier.kind_from_name(GameKeys.KIND_FLAT)).is_equal(StatModifier.Kind.FLAT)
	assert_int(StatModifier.kind_from_name(&"garbage")).is_equal(StatModifier.Kind.FLAT)  # 缺省落 FLAT

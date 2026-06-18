extends GdUnitTestSuite
## PLAN 步 5b 验证:SkillComponent 出手节奏 + 6 维伤害解算。
## 值逐条对齐 formula_test.gd:26-101(暴击/闪避/护甲)。极值去随机或注入 rng.seed。

func _entity(overrides: Dictionary) -> Entity:
	# 直接构造带指定属性的实体(绕开工厂,隔离单维度)。
	var e: Entity = auto_free(Entity.new())
	var s := StatsComponent.new()
	for stat in overrides.keys():
		s.set_base(stat, float(overrides[stat]))
	e.stats = s
	e.current_hp = 1.0e9
	return e

func _tuning() -> CombatTuning:
	var t := CombatTuning.new()
	t.armor_k = 50.0
	return t

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	return r

# ── 出手节奏 ──────────────────────────────────────────────────────────────────

func test_accumulate_yields_one_swing_per_unit() -> void:
	var sk := SkillComponent.new()
	sk.accumulate(1.0, 1.0)            # 攻速1 × dt1 = 1.0
	assert_int(sk.pending_swings()).is_equal(1)
	assert_int(sk.pending_swings()).is_equal(0)   # 已扣减

func test_accumulate_yields_multiple_swings() -> void:
	var sk := SkillComponent.new()
	sk.accumulate(3.0, 1.0)            # 3.0 → 3 次
	assert_int(sk.pending_swings()).is_equal(3)

func test_accumulate_carries_remainder() -> void:
	var sk := SkillComponent.new()
	sk.accumulate(0.7, 1.0)
	sk.accumulate(0.7, 1.0)           # 累计 1.4 → 1 次,余 0.4
	assert_int(sk.pending_swings()).is_equal(1)
	sk.accumulate(0.7, 1.0)           # 0.4 + 0.7 = 1.1 → 1 次
	assert_int(sk.pending_swings()).is_equal(1)

# ── 暴击(formula_test:26-52)────────────────────────────────────────────────

func test_crit_doubles_when_chance_is_one() -> void:
	var atk := _entity({GameKeys.STAT_ATTACK: 10.0, GameKeys.STAT_CRIT_CHANCE: 1.0, GameKeys.STAT_CRIT_MULT: 2.0})
	var tgt := _entity({})
	var res := atk.skill.resolve_hit(atk, tgt, _tuning(), _rng())
	assert_float(res["amount"]).is_equal(20.0)   # 10 × 2
	assert_bool(res["is_crit"]).is_true()

func test_no_crit_when_chance_is_zero() -> void:
	var atk := _entity({GameKeys.STAT_ATTACK: 10.0, GameKeys.STAT_CRIT_CHANCE: 0.0})
	var tgt := _entity({})
	var res := atk.skill.resolve_hit(atk, tgt, _tuning(), _rng())
	assert_float(res["amount"]).is_equal(10.0)
	assert_bool(res["is_crit"]).is_false()

# ── 闪避(formula_test:56-77)────────────────────────────────────────────────

func test_dodge_negates_hit_when_chance_is_one() -> void:
	var atk := _entity({GameKeys.STAT_ATTACK: 50.0})
	var tgt := _entity({GameKeys.STAT_DODGE_CHANCE: 1.0})
	var res := atk.skill.resolve_hit(atk, tgt, _tuning(), _rng())
	assert_bool(res["dodged"]).is_true()
	assert_float(res["amount"]).is_equal(0.0)

func test_no_dodge_takes_full_when_chance_is_zero() -> void:
	var atk := _entity({GameKeys.STAT_ATTACK: 50.0})
	var tgt := _entity({GameKeys.STAT_DODGE_CHANCE: 0.0})
	var res := atk.skill.resolve_hit(atk, tgt, _tuning(), _rng())
	assert_bool(res["dodged"]).is_false()
	assert_float(res["amount"]).is_equal(50.0)

# ── 护甲(formula_test:81-101)──────────────────────────────────────────────

func test_armor_equal_to_k_halves_damage() -> void:
	var atk := _entity({GameKeys.STAT_ATTACK: 100.0})
	var tgt := _entity({GameKeys.STAT_ARMOR: 50.0})   # = armor_k → 减伤恰 50%
	var res := atk.skill.resolve_hit(atk, tgt, _tuning(), _rng())
	assert_float(res["amount"]).is_equal(50.0)         # 100 × 0.5

func test_zero_armor_takes_full_damage() -> void:
	var atk := _entity({GameKeys.STAT_ATTACK: 100.0})
	var tgt := _entity({GameKeys.STAT_ARMOR: 0.0})
	var res := atk.skill.resolve_hit(atk, tgt, _tuning(), _rng())
	assert_float(res["amount"]).is_equal(100.0)

func test_enrage_damage_mult_scales_raw() -> void:
	# 狂暴倍率经 damage_mult 入(Arena 算好传入):atk10 × 1.5 = 15。
	var atk := _entity({GameKeys.STAT_ATTACK: 10.0})
	var tgt := _entity({})
	var res := atk.skill.resolve_hit(atk, tgt, _tuning(), _rng(), 1.5)
	assert_float(res["amount"]).is_equal(15.0)

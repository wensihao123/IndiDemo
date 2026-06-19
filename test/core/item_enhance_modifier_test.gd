extends GdUnitTestSuite
## PLAN 步3 验证:to_modifiers 接强化加成(层1)。
## ① 强化件主轴多出一条正确 FLAT;② weapon 副轴 attack_speed 不被强化(守 i4);
## ③ 全部 source=self → 脱下精确回收(i1);④ enhance_level=0 不加任何强化条。

func _registry() -> DataRegistry:
	var r := DataRegistry.new()
	r.load_all()
	return r

func _weapon(ilvl: int, level: int) -> ItemInstance:
	var inst := ItemInstance.new(GameKeys.SLOT_WEAPON, ilvl, GameKeys.RARITY_WHITE)
	var axes: Array[StringName] = [GameKeys.STAT_ATTACK, GameKeys.STAT_ATTACK_SPEED]
	inst.signature_axes = axes
	inst.enhance_level = level
	return inst

func _flat_sum(mods: Array, stat: StringName) -> float:
	var total := 0.0
	for m in mods:
		if m.stat == stat and m.kind == StatModifier.Kind.FLAT:
			total += m.value
	return total

func _count(mods: Array, stat: StringName) -> int:
	var n := 0
	for m in mods:
		if m.stat == stat and m.kind == StatModifier.Kind.FLAT:
			n += 1
	return n

func test_enhanced_main_axis_gets_extra_flat() -> void:
	var r := _registry()
	# weapon ilvl 5:base attack = 3.0 + 0.5×5 = 5.5;enhance 3 → bonus = 5.5×0.10×3 = 1.65。
	var mods := _weapon(5, 3).to_modifiers(r)
	assert_int(_count(mods, GameKeys.STAT_ATTACK)).is_equal(2)  # 基底 + 强化
	assert_float(_flat_sum(mods, GameKeys.STAT_ATTACK)).is_equal_approx(5.5 + 1.65, 0.001)

func test_attack_speed_not_enhanced() -> void:
	var r := _registry()
	var mods := _weapon(5, 3).to_modifiers(r)
	# 副轴只有基底一条,无强化条(守 i4,DPS 对强化等级线性)。
	assert_int(_count(mods, GameKeys.STAT_ATTACK_SPEED)).is_equal(1)

func test_zero_level_adds_no_enhance_modifier() -> void:
	var r := _registry()
	var mods := _weapon(5, 0).to_modifiers(r)
	assert_int(_count(mods, GameKeys.STAT_ATTACK)).is_equal(1)  # 仅基底

func test_all_modifiers_source_is_self() -> void:
	var r := _registry()
	var inst := _weapon(5, 3)
	for m in inst.to_modifiers(r):
		assert_object(m.source).is_same(inst)  # 脱下按 source 精确回收(i1)

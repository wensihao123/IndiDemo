extends GdUnitTestSuite
## PLAN 步1 验证:ItemInstance.enhance_level 字段 + 序列化(层1 数据层)。
## ① to_dict/from_dict round-trip 保值;② 旧档(无该键)→ from_dict 缺省 0(向后兼容)。

func _item() -> ItemInstance:
	var inst := ItemInstance.new(GameKeys.SLOT_WEAPON, 5, GameKeys.RARITY_WHITE)
	var axes: Array[StringName] = [GameKeys.STAT_ATTACK]
	inst.signature_axes = axes
	return inst

func test_default_enhance_level_is_zero() -> void:
	assert_int(_item().enhance_level).is_equal(0)

func test_round_trip_preserves_enhance_level() -> void:
	var inst := _item()
	inst.enhance_level = 7
	var back := ItemInstance.from_dict(inst.to_dict())
	assert_int(back.enhance_level).is_equal(7)

func test_old_dict_without_key_defaults_zero() -> void:
	# 旧档没有 enhance_level 键 → from_dict 得 0,无缝兼容。
	var old := {"base_id": "weapon", "ilvl": 3, "rarity": "white",
		"signature_axes": ["attack"], "affixes": []}
	var inst := ItemInstance.from_dict(old)
	assert_int(inst.enhance_level).is_equal(0)

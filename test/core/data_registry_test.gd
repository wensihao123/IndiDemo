extends GdUnitTestSuite
## PLAN 步3 验证:DataRegistry 解析 + 校验 + 访问器(层1 数据层)。
## ① 实发 JSON 配置能干净加载;② 合法内存数据 ingest 后访问器正确;③ 畸形数据各报对应错且不崩。

func _registry() -> DataRegistry:
	return DataRegistry.new()

# ── ① 实发配置干净加载 ────────────────────────────────────────────────────────

func test_shipped_config_loads_clean() -> void:
	var r := _registry()
	var ok := r.load_all()  # res://data/config
	assert_array(r.get_load_errors()).is_empty()
	assert_bool(ok).is_true()
	# 三槽基底齐全
	assert_object(r.get_item_base(GameKeys.SLOT_WEAPON)).is_not_null()
	assert_object(r.get_item_base(GameKeys.SLOT_ARMOR)).is_not_null()
	assert_object(r.get_item_base(GameKeys.SLOT_ACCESSORY)).is_not_null()
	# 掉落表在
	assert_object(r.get_loot_table()).is_not_null()

func test_shipped_full_tier_tables_present() -> void:
	# 04 §3.4:生命 10 阶、暴击率 5 阶按占位表填全。
	var r := _registry()
	r.load_all()
	var max_hp := _find_affix(r, GameKeys.STAT_MAX_HP)
	var crit := _find_affix(r, GameKeys.STAT_CRIT_CHANCE)
	assert_object(max_hp).is_not_null()
	assert_object(crit).is_not_null()
	assert_int((max_hp as AffixDef).tiers.size()).is_equal(10)
	assert_int((crit as AffixDef).tiers.size()).is_equal(5)

func _find_affix(r: DataRegistry, stat: StringName) -> AffixDef:
	for a in r.get_affixes_for_slot(GameKeys.SLOT_ACCESSORY):
		if a.stat == stat:
			return a
	return null

# ── ② 合法内存数据 → 访问器正确 ───────────────────────────────────────────────

func _good_bases() -> Dictionary:
	return {
		"weapon": {"slot": "weapon", "signature_mode": "all", "signature_axes": ["attack"],
			"base_curves": {"attack": {"base": 3.0, "per_ilvl": 0.5}}},
	}

func _good_affixes() -> Array:
	return [
		{"stat": "attack", "kind": "flat", "slot_pool": ["weapon"],
			"tiers": [{"tier": 1, "min": 1.0, "max": 3.0, "ilvl_req": 1, "weight": 1.0}]},
	]

func _good_table() -> Dictionary:
	return {"rarity_affix_count": {"white": [0, 0], "blue": [1, 2], "gold": [3, 4]},
		"decompose_threshold": "white", "material_per_decompose": 1}

func test_ingest_good_data_is_valid_and_queryable() -> void:
	var r := _registry()
	var ok := r.ingest(_good_bases(), _good_affixes(), _good_table())
	assert_bool(ok).is_true()
	assert_array(r.get_load_errors()).is_empty()
	var base := r.get_item_base(GameKeys.SLOT_WEAPON)
	assert_object(base).is_not_null()
	assert_float(base.base_value(GameKeys.STAT_ATTACK, 10)).is_equal(8.0)  # 3 + 0.5×10
	# 部位池过滤:weapon 命中,armor 空
	assert_int(r.get_affixes_for_slot(GameKeys.SLOT_WEAPON).size()).is_equal(1)
	assert_int(r.get_affixes_for_slot(GameKeys.SLOT_ARMOR).size()).is_equal(0)
	var lt := r.get_loot_table()
	assert_array(lt.affix_count_range(GameKeys.RARITY_BLUE)).is_equal([1, 2])
	assert_bool(lt.should_decompose(GameKeys.RARITY_WHITE)).is_true()
	assert_bool(lt.should_decompose(GameKeys.RARITY_BLUE)).is_false()

# ── ③ 畸形数据各报错且不崩 ────────────────────────────────────────────────────

func test_unknown_stat_reports_error() -> void:
	var r := _registry()
	var affixes := [{"stat": "bogus", "kind": "flat", "slot_pool": ["weapon"],
		"tiers": [{"tier": 1, "min": 1.0, "max": 2.0, "ilvl_req": 1, "weight": 1.0}]}]
	var ok := r.ingest(_good_bases(), affixes, _good_table())
	assert_bool(ok).is_false()
	assert_str(_join(r.get_load_errors())).contains("bogus")

func test_zero_ilvl_req_reports_error() -> void:
	var r := _registry()
	var affixes := [{"stat": "attack", "kind": "flat", "slot_pool": ["weapon"],
		"tiers": [{"tier": 1, "min": 1.0, "max": 2.0, "ilvl_req": 0, "weight": 1.0}]}]
	var ok := r.ingest(_good_bases(), affixes, _good_table())
	assert_bool(ok).is_false()
	assert_str(_join(r.get_load_errors())).contains("ilvl_req")

func test_min_gt_max_reports_error() -> void:
	var r := _registry()
	var affixes := [{"stat": "attack", "kind": "flat", "slot_pool": ["weapon"],
		"tiers": [{"tier": 1, "min": 9.0, "max": 2.0, "ilvl_req": 1, "weight": 1.0}]}]
	var ok := r.ingest(_good_bases(), affixes, _good_table())
	assert_bool(ok).is_false()

func test_unknown_slot_in_pool_reports_error() -> void:
	var r := _registry()
	var affixes := [{"stat": "attack", "kind": "flat", "slot_pool": ["wand"],
		"tiers": [{"tier": 1, "min": 1.0, "max": 2.0, "ilvl_req": 1, "weight": 1.0}]}]
	var ok := r.ingest(_good_bases(), affixes, _good_table())
	assert_bool(ok).is_false()
	assert_str(_join(r.get_load_errors())).contains("wand")

func test_unknown_rarity_in_table_reports_error() -> void:
	var r := _registry()
	var table := {"rarity_affix_count": {"purple": [1, 2]}, "decompose_threshold": "white"}
	var ok := r.ingest(_good_bases(), _good_affixes(), table)
	assert_bool(ok).is_false()
	assert_str(_join(r.get_load_errors())).contains("purple")

func test_incomplete_rarity_table_reports_error() -> void:
	# 漏配金档 → 报缺档错(否则金装静默掉成 0 词缀)。
	var r := _registry()
	var table := {"rarity_affix_count": {"white": [0, 0], "blue": [1, 2]},
		"decompose_threshold": "white", "material_per_decompose": 1}
	var ok := r.ingest(_good_bases(), _good_affixes(), table)
	assert_bool(ok).is_false()
	assert_str(_join(r.get_load_errors())).contains("gold")

func _join(errs: Array) -> String:
	return "\n".join(errs)

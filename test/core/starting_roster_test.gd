extends GdUnitTestSuite
## PLAN 步1 验证:DataRegistry 加载/校验默认起始 roster + Character.display_name 序列化(层1 数据层 D3/D7)。
## ① 实发 starting_roster.json 干净加载得战士;② 合法内存 ingest → Character 8 维齐、build_stats 等值;
## ③ 非法(stat 拼错 / id 空)→ is_valid()==false 且报对应错。

func _registry() -> DataRegistry:
	return DataRegistry.new()

func _join(errs: Array) -> String:
	return "\n".join(errs)

# ── ① 实发配置:starting_roster.json 干净加载 ──────────────────────────────────

func test_shipped_roster_loads_warrior() -> void:
	var r := _registry()
	var ok := r.load_all()  # res://data/config
	assert_array(r.get_load_errors()).is_empty()
	assert_bool(ok).is_true()
	var roster := r.get_starting_roster()
	assert_int(roster.size()).is_equal(1)
	var warrior := roster[0]
	assert_str(warrior.display_name).is_equal("战士")
	assert_int(warrior.base_stats.size()).is_equal(8)  # 8 维齐
	assert_float(warrior.build_stats().get_final(GameKeys.STAT_ATTACK)).is_equal(6.0)
	assert_float(warrior.build_stats().get_final(GameKeys.STAT_MAX_HP)).is_equal(120.0)

# ── ② 合法内存数据 → Character 正确 ───────────────────────────────────────────

func _good_roster() -> Array:
	return [{
		"id": "warrior", "class_id": "warrior", "display_name": "战士",
		"base_stats": {"attack": 6, "max_hp": 120, "attack_speed": 1, "armor": 0,
			"dodge_chance": 0, "crit_chance": 0, "crit_mult": 2, "hp_regen": 0},
	}]

func test_ingest_good_roster_is_valid() -> void:
	var r := _registry()
	var ok := r.ingest_starting_roster(_good_roster())
	assert_bool(ok).is_true()
	assert_array(r.get_load_errors()).is_empty()
	var roster := r.get_starting_roster()
	assert_int(roster.size()).is_equal(1)
	assert_str(roster[0].display_name).is_equal("战士")
	assert_float(roster[0].build_stats().get_final(GameKeys.STAT_CRIT_MULT)).is_equal(2.0)

func test_get_starting_roster_returns_fresh_copies() -> void:
	# 深拷贝:改一份不污染下一次取出的。
	var r := _registry()
	r.ingest_starting_roster(_good_roster())
	var a := r.get_starting_roster()[0]
	a.base_stats[GameKeys.STAT_ATTACK] = 999.0
	var b := r.get_starting_roster()[0]
	assert_float(b.build_stats().get_final(GameKeys.STAT_ATTACK)).is_equal(6.0)

# ── ③ 畸形数据各报错且不崩 ────────────────────────────────────────────────────

func test_unknown_stat_key_reports_error() -> void:
	var r := _registry()
	var bad := [{"id": "warrior", "display_name": "战士",
		"base_stats": {"attck": 6, "max_hp": 120}}]  # attck 拼错
	var ok := r.ingest_starting_roster(bad)
	assert_bool(ok).is_false()
	assert_str(_join(r.get_load_errors())).contains("attck")

func test_empty_id_reports_error() -> void:
	var r := _registry()
	var bad := [{"id": "", "display_name": "无名", "base_stats": {"attack": 6}}]
	var ok := r.ingest_starting_roster(bad)
	assert_bool(ok).is_false()
	assert_str(_join(r.get_load_errors())).contains("id")

func test_non_numeric_stat_value_reports_error() -> void:
	var r := _registry()
	var bad := [{"id": "warrior", "display_name": "战士",
		"base_stats": {"attack": "六"}}]  # 值非数字
	var ok := r.ingest_starting_roster(bad)
	assert_bool(ok).is_false()
	assert_str(_join(r.get_load_errors())).contains("attack")

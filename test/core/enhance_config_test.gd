extends GdUnitTestSuite
## PLAN 步2 验证:enhance.json 加载 + EnhanceConfigDef 公式(层1 数据层)。
## ① 实发配置干净加载且访问器有值;② 成本曲线 1+L / 满级判定正确;③ 畸形配置各报错。

func _registry() -> DataRegistry:
	return DataRegistry.new()

# ── ① 实发配置干净加载 ────────────────────────────────────────────────────────

func test_shipped_enhance_config_loads_clean() -> void:
	var r := _registry()
	var ok := r.load_all()
	assert_array(r.get_load_errors()).is_empty()
	assert_bool(ok).is_true()
	var cfg := r.get_enhance_config()
	assert_object(cfg).is_not_null()
	assert_float(cfg.per_level).is_equal_approx(0.10, 0.0001)
	assert_int(cfg.cap).is_equal(10)

# ── ② 公式:成本曲线 1+L + 满级判定 ───────────────────────────────────────────

func test_cost_curve_is_one_plus_level() -> void:
	var cfg := EnhanceConfigDef.new()  # 默认 cost_base=1 cost_step=1
	assert_int(cfg.cost_for_level(0)).is_equal(1)
	assert_int(cfg.cost_for_level(1)).is_equal(2)
	assert_int(cfg.cost_for_level(9)).is_equal(10)

func test_is_max_at_cap() -> void:
	var cfg := EnhanceConfigDef.new()  # 默认 cap=10
	assert_bool(cfg.is_max(9)).is_false()
	assert_bool(cfg.is_max(10)).is_true()
	assert_bool(cfg.is_max(11)).is_true()

# ── ③ 畸形配置报错 ────────────────────────────────────────────────────────────

func test_nonpositive_per_level_reports_error() -> void:
	var r := _registry()
	var ok := r.ingest_enhance({"per_level": 0.0, "cap": 10, "cost_base": 1, "cost_step": 1})
	assert_bool(ok).is_false()
	assert_str("\n".join(r.get_load_errors())).contains("per_level")

func test_zero_cap_reports_error() -> void:
	var r := _registry()
	var ok := r.ingest_enhance({"per_level": 0.1, "cap": 0, "cost_base": 1, "cost_step": 1})
	assert_bool(ok).is_false()
	assert_str("\n".join(r.get_load_errors())).contains("cap")

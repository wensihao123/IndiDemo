extends GdUnitTestSuite
## PLAN step 7 验证:固定步长累加器帧率无关 —— 同样模拟时长 → 同样 tick 数(PLAN D8)。
## (后台持续推进 / 收起态 15fps 一致性是手动 Play 验收,见 PLAN step 7。)

func _trivial_stage() -> Array[StageConfig]:
	# 单场景、超大 kill_count(永不清场)、1血/atk0 怪 → 每 tick 恰 1 次击杀,原地刷。
	var st := StageConfig.new()
	st.stage_name = "刷怪场"
	var e := EnemyDef.new()
	e.max_hp = 1.0
	e.attack = 0.0
	e.drop_chance = 0.0
	var sc := SceneConfig.new()
	sc.enemy = e
	sc.kill_count = 100000
	st.scenes = [sc] as Array[SceneConfig]
	st.boss = e
	var stages: Array[StageConfig] = [st]
	return stages

func _director() -> CombatDirector:
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.party = [PartyMember.new("战士", 1000.0, 100.0), null, null, null]
	d.tick_seconds = 0.1
	return d

func test_same_sim_time_yields_same_tick_count_regardless_of_frame_size() -> void:
	var big := _director()
	var big_kills := [0]
	big.enemy_defeated.connect(func(_e): big_kills[0] += 1)
	big.begin_run(_trivial_stage())
	big._process(1.0)  # 一大帧 = 10 步

	var small := _director()
	var small_kills := [0]
	small.enemy_defeated.connect(func(_e): small_kills[0] += 1)
	small.begin_run(_trivial_stage())
	for i in 10:
		small._process(0.1)  # 十小帧 = 10 步

	assert_int(big_kills[0]).is_equal(10)
	assert_int(small_kills[0]).is_equal(10)
	assert_int(big_kills[0]).is_equal(small_kills[0])

func test_accumulator_carries_remainder_across_frames() -> void:
	var d := _director()
	var kills := [0]
	d.enemy_defeated.connect(func(_e): kills[0] += 1)
	d.begin_run(_trivial_stage())
	d._process(0.05)            # < 0.1 → 不足一步
	assert_int(kills[0]).is_equal(0)
	d._process(0.05)            # 累计 0.1 → 恰一步
	assert_int(kills[0]).is_equal(1)

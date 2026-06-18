extends GdUnitTestSuite
## PLAN step 5 验证:团灭回退四条规则 + 回退后 GRINDING 原地刷不推进(PLAN D5)。

func _hard_enemy() -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = 1000.0   # 脆皮 1 atk 打不动 → 不会先杀敌
	e.attack = 100.0    # 一击秒掉脆皮
	e.drop_chance = 0.0
	return e

func _hard_stage(p_name: String) -> StageConfig:
	var st := StageConfig.new()
	st.stage_name = p_name
	var arr: Array[SceneConfig] = []
	for k in 3:
		var sc := SceneConfig.new()
		sc.enemy = _hard_enemy()
		sc.kill_count = 5
		arr.append(sc)
	st.scenes = arr
	st.boss = _hard_enemy()
	return st

func _weak_director() -> CombatDirector:
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.party = [PartyMember.new("脆皮", 5.0, 1.0), null, null, null]
	return d

func _two_hard_stages() -> Array[StageConfig]:
	var stages: Array[StageConfig] = [_hard_stage("第一关"), _hard_stage("第二关")]
	return stages

func test_wipe_in_mid_scene_retreats_one_scene_back() -> void:
	var d := _weak_director()
	d.begin_run(_two_hard_stages(), 0, 1)  # 卡在 (0,1)
	d.tick_combat()                         # 团灭
	assert_int(d.mode).is_equal(CombatDirector.Mode.GRINDING)
	assert_int(d.cur_stage).is_equal(0)
	assert_int(d.cur_scene).is_equal(0)     # 退一场景
	assert_int(d.advance_target_stage).is_equal(0)
	assert_int(d.advance_target_scene).is_equal(1)  # 推进回原点

func test_wipe_at_first_scene_of_non_first_stage_retreats_to_prev_stage_last_scene() -> void:
	var d := _weak_director()
	d.begin_run(_two_hard_stages(), 1, 0)  # 卡在 (1,0)
	d.tick_combat()
	assert_int(d.cur_stage).is_equal(0)     # 退到上一关
	assert_int(d.cur_scene).is_equal(2)     # 上一关末普通场景(跳过其 Boss)
	assert_int(d.advance_target_stage).is_equal(1)
	assert_int(d.advance_target_scene).is_equal(0)  # 推进 → 本关第一场景,不重打上关 Boss

func test_wipe_at_first_scene_of_first_stage_grinds_in_place() -> void:
	var d := _weak_director()
	d.begin_run(_two_hard_stages(), 0, 0)  # 首关首场景
	d.tick_combat()
	assert_int(d.cur_stage).is_equal(0)
	assert_int(d.cur_scene).is_equal(0)     # 原地
	assert_int(d.advance_target_stage).is_equal(0)
	assert_int(d.advance_target_scene).is_equal(0)

func test_wipe_at_boss_retreats_to_last_scene_and_targets_boss() -> void:
	var d := _weak_director()
	d.begin_run(_two_hard_stages(), 0, CombatDirector.BOSS_SCENE)  # Boss 未通团灭
	d.tick_combat()
	assert_int(d.cur_stage).is_equal(0)
	assert_int(d.cur_scene).is_equal(2)     # 退到末普通场景
	assert_int(d.advance_target_stage).is_equal(0)
	assert_int(d.advance_target_scene).is_equal(CombatDirector.BOSS_SCENE)  # 推进 → 重打 Boss

func test_grinding_does_not_advance_cursor() -> void:
	# scene0 无害(atk0,1血),scene1 致命 → 卡 (0,1) 团灭退到 (0,0) 刷;
	# 此后击杀 scene0 怪不推进游标(GRINDING)。
	var d := _weak_director()
	var st := StageConfig.new()
	st.stage_name = "混合关"
	var trivial := EnemyDef.new()
	trivial.max_hp = 1.0
	trivial.attack = 0.0
	trivial.drop_chance = 0.0
	var lethal := _hard_enemy()
	var arr: Array[SceneConfig] = []
	for e in [trivial, lethal, trivial]:
		var sc := SceneConfig.new()
		sc.enemy = e
		sc.kill_count = 5
		arr.append(sc)
	st.scenes = arr
	st.boss = _hard_enemy()
	var stages: Array[StageConfig] = [st]
	d.begin_run(stages, 0, 1)  # 卡致命 scene1
	d.tick_combat()            # 团灭 → 退到 (0,0)
	assert_int(d.mode).is_equal(CombatDirector.Mode.GRINDING)
	assert_int(d.cur_scene).is_equal(0)
	for i in 10:               # 反复杀 scene0 无害怪
		d.tick_combat()
	assert_int(d.cur_scene).is_equal(0)  # 仍原地,未推进
	assert_int(d.mode).is_equal(CombatDirector.Mode.GRINDING)

func test_grind_round_heals_party_so_hp_does_not_erode() -> void:
	# 战士 hp100/atk100;grind 怪 hp150/atk10、kill_count=2;scene1 致命 → 卡 (0,1) 团灭退 (0,0) 刷。
	# 刷一轮(2 杀)中持续受伤,刷满 kill_count → 全队回满,血不会越刷越低(用户报的 bug)。
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.party = [PartyMember.new("战士", 100.0, 100.0), null, null, null]
	var st := StageConfig.new()
	st.stage_name = "卡关回血"
	var grind_enemy := EnemyDef.new()
	grind_enemy.max_hp = 150.0
	grind_enemy.attack = 10.0
	grind_enemy.drop_chance = 0.0
	var lethal := _hard_enemy()
	var sc0 := SceneConfig.new()
	sc0.enemy = grind_enemy
	sc0.kill_count = 2
	var sc1 := SceneConfig.new()
	sc1.enemy = lethal
	sc1.kill_count = 1
	st.scenes = [sc0, sc1] as Array[SceneConfig]
	st.boss = lethal
	d.begin_run([st] as Array[StageConfig], 0, 1)  # 卡致命 scene1
	d.tick_combat()                                 # 团灭 → 退 (0,0) 刷,复活满血
	assert_int(d.mode).is_equal(CombatDirector.Mode.GRINDING)
	assert_int(d.cur_scene).is_equal(0)
	assert_float(d.party[0].current_hp).is_equal(100.0)
	d.tick_combat()                                 # 怪 150→50,受击 100→90
	assert_float(d.party[0].current_hp).is_equal(90.0)
	d.tick_combat()                                 # 怪死(本轮 1/2),未满 kill_count → 不回血
	assert_float(d.party[0].current_hp).is_equal(90.0)
	d.tick_combat()                                 # 新怪 150→50,受击 90→80
	assert_float(d.party[0].current_hp).is_equal(80.0)
	d.tick_combat()                                 # 怪死(本轮 2/2)→ 一轮完成,全队回满
	assert_float(d.party[0].current_hp).is_equal(100.0)
	assert_int(d.cur_scene).is_equal(0)             # 仍在同场景继续刷

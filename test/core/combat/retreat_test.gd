extends GdUnitTestSuite
## PLAN 步 5f 验证(承 test/combat/retreat_test 逐条等值):团灭回退四条规则 +
## 回退后 GRINDING 原地刷不推进 + 卡关回血(REFACTOR-01 层5;Arena+Progression 接线驱动)。

const MAX_HP := GameKeys.STAT_MAX_HP
const ATTACK := GameKeys.STAT_ATTACK
const ASPD := GameKeys.STAT_ATTACK_SPEED

func _hard_enemy() -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = 1000.0   # 脆皮 1 atk 打不动 → 不会先杀敌
	e.attack = 100.0    # 一击秒掉脆皮
	e.attack_speed = 1.0
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

func _two_hard_stages() -> Array[StageConfig]:
	var stages: Array[StageConfig] = [_hard_stage("第一关"), _hard_stage("第二关")]
	return stages

func _member(hp: float, atk: float) -> Entity:
	var e: Entity = auto_free(Entity.new(Entity.Team.PLAYER))
	var s := StatsComponent.new()
	s.set_base(MAX_HP, hp)
	s.set_base(ATTACK, atk)
	s.set_base(ASPD, 1.0)
	e.stats = s
	e.current_hp = hp
	return e

# 每 actor 每 tick 一击(攻速 1.0 × tick_seconds 1.0,无浮点漂移):敌人一击秒脆皮 → 团灭确定(承 Flag-C / Step 4)。
func _arena(hero: Entity) -> CombatArena:
	var a: CombatArena = auto_free(CombatArena.new())
	a.tuning = CombatTuning.new()
	a.tuning.tick_seconds = 1.0
	var party: Array[Entity] = [hero]
	a.players = party
	return a

func _prog(a: CombatArena) -> ProgressionController:
	var p := ProgressionController.new()
	p.arena = a
	return p

func test_wipe_in_mid_scene_retreats_one_scene_back() -> void:
	var a := _arena(_member(5.0, 1.0))
	var p := _prog(a)
	p.begin_run(_two_hard_stages(), 0, 1)  # 卡在 (0,1)
	a.tick_combat()                         # 团灭
	assert_int(p.mode).is_equal(ProgressionController.Mode.GRINDING)
	assert_int(p.cur_stage).is_equal(0)
	assert_int(p.cur_scene).is_equal(0)     # 退一场景
	assert_int(p.advance_target_stage).is_equal(0)
	assert_int(p.advance_target_scene).is_equal(1)  # 推进回原点

func test_wipe_at_first_scene_of_non_first_stage_retreats_to_prev_stage_last_scene() -> void:
	var a := _arena(_member(5.0, 1.0))
	var p := _prog(a)
	p.begin_run(_two_hard_stages(), 1, 0)  # 卡在 (1,0)
	a.tick_combat()
	assert_int(p.cur_stage).is_equal(0)     # 退到上一关
	assert_int(p.cur_scene).is_equal(2)     # 上一关末普通场景(跳过其 Boss)
	assert_int(p.advance_target_stage).is_equal(1)
	assert_int(p.advance_target_scene).is_equal(0)  # 推进 → 本关第一场景,不重打上关 Boss

func test_wipe_at_first_scene_of_first_stage_grinds_in_place() -> void:
	var a := _arena(_member(5.0, 1.0))
	var p := _prog(a)
	p.begin_run(_two_hard_stages(), 0, 0)  # 首关首场景
	a.tick_combat()
	assert_int(p.cur_stage).is_equal(0)
	assert_int(p.cur_scene).is_equal(0)     # 原地
	assert_int(p.advance_target_stage).is_equal(0)
	assert_int(p.advance_target_scene).is_equal(0)

func test_wipe_at_boss_retreats_to_last_scene_and_targets_boss() -> void:
	var a := _arena(_member(5.0, 1.0))
	var p := _prog(a)
	p.begin_run(_two_hard_stages(), 0, ProgressionController.BOSS_SCENE)  # Boss 未通团灭
	a.tick_combat()
	assert_int(p.cur_stage).is_equal(0)
	assert_int(p.cur_scene).is_equal(2)     # 退到末普通场景
	assert_int(p.advance_target_stage).is_equal(0)
	assert_int(p.advance_target_scene).is_equal(ProgressionController.BOSS_SCENE)  # 推进 → 重打 Boss

func test_grinding_does_not_advance_cursor() -> void:
	# scene0 无害(atk0,1血),scene1 致命 → 卡 (0,1) 团灭退到 (0,0) 刷;
	# 此后击杀 scene0 怪不推进游标(GRINDING)。
	var a := _arena(_member(5.0, 1.0))
	var p := _prog(a)
	var st := StageConfig.new()
	st.stage_name = "混合关"
	var trivial := EnemyDef.new()
	trivial.max_hp = 1.0
	trivial.attack = 0.0
	trivial.attack_speed = 1.0
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
	p.begin_run(stages, 0, 1)  # 卡致命 scene1
	a.tick_combat()            # 团灭 → 退到 (0,0)
	assert_int(p.mode).is_equal(ProgressionController.Mode.GRINDING)
	assert_int(p.cur_scene).is_equal(0)
	for i in 10:               # 反复杀 scene0 无害怪
		a.tick_combat()
	assert_int(p.cur_scene).is_equal(0)  # 仍原地,未推进
	assert_int(p.mode).is_equal(ProgressionController.Mode.GRINDING)

func test_grind_round_heals_party_so_hp_does_not_erode() -> void:
	# 战士 hp100/atk100;grind 怪 hp150/atk10、kill_count=2;scene1 致命 → 卡 (0,1) 团灭退 (0,0) 刷。
	# 刷一轮(2 杀)中持续受伤,刷满 kill_count → 全队回满,血不会越刷越低(用户报的 bug)。
	var a := _arena(_member(100.0, 100.0))
	var p := _prog(a)
	var st := StageConfig.new()
	st.stage_name = "卡关回血"
	var grind_enemy := EnemyDef.new()
	grind_enemy.max_hp = 150.0
	grind_enemy.attack = 10.0
	grind_enemy.attack_speed = 1.0
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
	p.begin_run([st] as Array[StageConfig], 0, 1)  # 卡致命 scene1
	a.tick_combat()                                 # 团灭 → 退 (0,0) 刷,复活满血
	assert_int(p.mode).is_equal(ProgressionController.Mode.GRINDING)
	assert_int(p.cur_scene).is_equal(0)
	assert_float(a.players[0].current_hp).is_equal(100.0)
	a.tick_combat()                                 # 怪 150→50,受击 100→90
	assert_float(a.players[0].current_hp).is_equal(90.0)
	a.tick_combat()                                 # 怪死(本轮 1/2),未满 kill_count → 不回血
	assert_float(a.players[0].current_hp).is_equal(90.0)
	a.tick_combat()                                 # 新怪 150→50,受击 90→80
	assert_float(a.players[0].current_hp).is_equal(80.0)
	a.tick_combat()                                 # 怪死(本轮 2/2)→ 一轮完成,全队回满
	assert_float(a.players[0].current_hp).is_equal(100.0)
	assert_int(p.cur_scene).is_equal(0)             # 仍在同场景继续刷

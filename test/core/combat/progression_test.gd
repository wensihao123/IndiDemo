extends GdUnitTestSuite
## PLAN 步 5f 验证(承 test/combat/progression_test 逐条等值):场景游标 0→1→2→Boss、
## Boss 击杀永久解锁 + 不再回到该 Boss(REFACTOR-01 层5;Arena+Progression 接线驱动)。

const MAX_HP := GameKeys.STAT_MAX_HP
const ATTACK := GameKeys.STAT_ATTACK
const ASPD := GameKeys.STAT_ATTACK_SPEED

func _enemy(hp: float) -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = hp
	e.attack = 0.0          # 敌人不还手 → 战士不死,推进可控
	e.attack_speed = 1.0
	e.drop_chance = 0.0     # 不掺掉落随机
	return e

func _scene(hp: float, kills: int) -> SceneConfig:
	var s := SceneConfig.new()
	s.enemy = _enemy(hp)
	s.kill_count = kills
	return s

func _stage(p_name: String, kills: Array, boss_hp: float) -> StageConfig:
	var st := StageConfig.new()
	st.stage_name = p_name
	var arr: Array[SceneConfig] = []
	for k in kills:
		arr.append(_scene(1.0, k))
	st.scenes = arr
	st.boss = _enemy(boss_hp)
	return st

func _warrior(hp: float, atk: float) -> Entity:
	var e: Entity = auto_free(Entity.new(Entity.Team.PLAYER))
	var s := StatsComponent.new()
	s.set_base(MAX_HP, hp)
	s.set_base(ATTACK, atk)
	s.set_base(ASPD, 1.0)
	e.stats = s
	e.current_hp = hp
	return e

# 攻速 1.0 × tick_seconds 1.0 = 每次 tick_combat() 每 actor 恰一击(无浮点漂移),
# 还原 02"1 击必杀 1 血怪、推进完全确定"的语义(承 Flag-C / Step 4)。
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

func test_cursor_advances_through_scenes_to_boss() -> void:
	var a := _arena(_warrior(1000.0, 100.0))
	var p := _prog(a)
	var stages: Array[StageConfig] = [_stage("第一关", [1, 1, 1], 500.0)]
	p.begin_run(stages)
	assert_int(p.cur_scene).is_equal(0)
	a.tick_combat()  # 杀场景0 → 场景1
	assert_int(p.cur_scene).is_equal(1)
	a.tick_combat()  # 杀场景1 → 场景2
	assert_int(p.cur_scene).is_equal(2)
	a.tick_combat()  # 杀场景2 → Boss
	assert_int(p.cur_scene).is_equal(ProgressionController.BOSS_SCENE)
	assert_int(p.cur_stage).is_equal(0)

func test_kill_count_gates_scene_advance() -> void:
	var a := _arena(_warrior(1000.0, 100.0))
	var p := _prog(a)
	var stages: Array[StageConfig] = [_stage("第一关", [3, 1, 1], 500.0)]
	p.begin_run(stages)
	a.tick_combat()
	assert_int(p.cur_scene).is_equal(0)  # 仅 1/3 杀,未达标
	a.tick_combat()
	assert_int(p.cur_scene).is_equal(0)  # 2/3
	a.tick_combat()
	assert_int(p.cur_scene).is_equal(1)  # 3/3 达标 → 进场景1

func test_boss_kill_unlocks_next_stage_permanently() -> void:
	var a := _arena(_warrior(1000.0, 100.0))
	var p := _prog(a)
	var stages: Array[StageConfig] = [
		_stage("第一关", [1], 1.0),   # 1 场景 + 1血 Boss
		_stage("第二关", [99], 500.0),
	]
	var cleared := [-1]
	p.boss_cleared.connect(func(s): cleared[0] = s)
	p.begin_run(stages)
	a.tick_combat()  # 杀场景0 → Boss
	assert_int(p.cur_scene).is_equal(ProgressionController.BOSS_SCENE)
	a.tick_combat()  # 杀 Boss → 解锁 + 进通关倒计时(不立刻推进)
	assert_int(cleared[0]).is_equal(0)
	assert_int(p.max_unlocked_stage).is_equal(1)
	assert_int(p.mode).is_equal(ProgressionController.Mode.STAGE_CLEAR_COUNTDOWN)
	assert_int(p.cur_stage).is_equal(0)  # 倒计时内仍未推进
	p.process_countdown(a.tuning.stage_clear_countdown_sec + 0.1)  # 倒计时到点 → 自动推进
	assert_int(p.cur_stage).is_equal(1)
	assert_int(p.cur_scene).is_equal(0)
	assert_int(p.mode).is_equal(ProgressionController.Mode.PROGRESSING)

func test_never_refights_cleared_boss() -> void:
	var a := _arena(_warrior(1000.0, 100.0))
	var p := _prog(a)
	var stages: Array[StageConfig] = [
		_stage("第一关", [1], 1.0),
		_stage("第二关", [99], 500.0),
	]
	p.begin_run(stages)
	a.tick_combat()  # 杀场景0 → Boss
	a.tick_combat()  # 杀 Boss → 倒计时
	p.process_countdown(a.tuning.stage_clear_countdown_sec + 0.1)  # 自动推进到第二关
	for i in 20:
		a.tick_combat()
	# 进了第二关后就停在第二关场景0(99 血打不完),绝不回到第一关 Boss。
	assert_int(p.cur_stage).is_greater_equal(1)

func test_party_heals_full_after_clearing_a_scene() -> void:
	# 战士 hp100/atk100;场景0 怪 hp150/atk10 → tick1 怪 150→50 还手(战士 100→90),
	# tick2 怪 50→0 死、清场进场景1 → 全队回满(过场景回血)。
	var a := _arena(_warrior(100.0, 100.0))
	var p := _prog(a)
	var st := StageConfig.new()
	st.stage_name = "回血关"
	var hurter := EnemyDef.new()
	hurter.max_hp = 150.0
	hurter.attack = 10.0
	hurter.attack_speed = 1.0
	hurter.drop_chance = 0.0
	var sc := SceneConfig.new()
	sc.enemy = hurter
	sc.kill_count = 1
	st.scenes = [sc, _scene(1.0, 1)] as Array[SceneConfig]
	st.boss = _enemy(1.0)
	p.begin_run([st] as Array[StageConfig])
	a.tick_combat()                                   # 怪 150→50,战士受 1 击
	assert_float(a.players[0].current_hp).is_equal(90.0)
	a.tick_combat()                                   # 怪 50→0 死,清场 → 回满
	assert_int(p.cur_scene).is_equal(1)
	assert_float(a.players[0].current_hp).is_equal(100.0)

## 〔08 团战 #12 回归〕一波多敌逐个被清,杀掉前排不会触发整波重刷(后排仍在),波清空才推进。
func test_multi_enemy_wave_clears_one_by_one_without_respawn() -> void:
	var a := _arena(_warrior(1000.0, 100.0))   # aspd1×tick1 → 每 tick 恰 1 击 → 每 tick 杀 1 只
	var p := _prog(a)
	var st := StageConfig.new()
	st.stage_name = "团战关"
	var sc := SceneConfig.new()
	sc.enemy_group = [_enemy(1.0), _enemy(1.0)] as Array[EnemyDef]  # 2 敌一波(各1血/atk0)
	sc.kill_count = 5                          # 一波(2杀)不够清场 → 同场景重刷
	st.scenes = [sc] as Array[SceneConfig]
	st.boss = _enemy(500.0)
	p.begin_run([st] as Array[StageConfig])
	assert_int(a.enemies.size()).is_equal(2)   # 整波同屏并存
	a.tick_combat()                            # 杀前排 1 只
	assert_int(p.cur_scene).is_equal(0)        # 波未清空 → 未推进
	assert_bool(a.has_living_enemy()).is_true()# 后排仍活(未被整波重刷冲掉)
	assert_int(a.enemies.size()).is_equal(2)   # 同一波数组,前死后活(#12:杀一只不重刷)
	a.tick_combat()                            # 杀后排 → 波清空
	assert_int(p.cur_scene).is_equal(0)        # 累计2杀 < kill_count5 → 仍本场景
	assert_int(a.enemies.size()).is_equal(2)   # 波清空才重刷新一波 2 敌
	assert_bool(a.has_living_enemy()).is_true()

func test_current_enemy_def_returns_boss_at_boss_scene() -> void:
	var a := _arena(_warrior(1000.0, 100.0))
	var p := _prog(a)
	var boss_hp := 777.0
	var stages: Array[StageConfig] = [_stage("第一关", [1, 1, 1], boss_hp)]
	p.begin_run(stages, 0, ProgressionController.BOSS_SCENE)
	var def := p.current_enemy_def()
	assert_object(def).is_not_null()
	assert_float(def.max_hp).is_equal(boss_hp)

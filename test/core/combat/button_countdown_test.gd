extends GdUnitTestSuite
## PLAN 步 5f 验证(承 test/combat/button_countdown_test 逐条等值):通关倒计时自动推进 /
## 修整取消推进、卡关推进+修整在本轮结束执行(REFACTOR-01 层5;Arena+Progression 接线驱动)。

const MAX_HP := GameKeys.STAT_MAX_HP
const ATTACK := GameKeys.STAT_ATTACK
const ASPD := GameKeys.STAT_ATTACK_SPEED

func _enemy(hp: float, atk: float) -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = hp
	e.attack = atk
	e.attack_speed = 1.0
	e.drop_chance = 0.0
	return e

func _scene(enemy: EnemyDef, kills: int) -> SceneConfig:
	var s := SceneConfig.new()
	s.enemy = enemy
	s.kill_count = kills
	return s

func _member(hp: float, atk: float) -> Entity:
	var e: Entity = auto_free(Entity.new(Entity.Team.PLAYER))
	var s := StatsComponent.new()
	s.set_base(MAX_HP, hp)
	s.set_base(ATTACK, atk)
	s.set_base(ASPD, 1.0)
	e.stats = s
	e.current_hp = hp
	return e

# 每 actor 每 tick 一击(攻速 1.0 × tick_seconds 1.0,无浮点漂移),还原 02 逐 tick 确定推进(承 Flag-C / Step 4)。
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

# 一关:1 个无害场景(1血/atk0)+ 1血 Boss → 强战士两 tick 通关到倒计时。
func _quick_clear_stages() -> Array[StageConfig]:
	var st := StageConfig.new()
	st.stage_name = "速通关"
	var arr: Array[SceneConfig] = [_scene(_enemy(1.0, 0.0), 1)]
	st.scenes = arr
	st.boss = _enemy(1.0, 0.0)
	var st2 := StageConfig.new()
	st2.stage_name = "第二关"
	st2.scenes = [_scene(_enemy(1.0, 0.0), 1)] as Array[SceneConfig]
	st2.boss = _enemy(1.0, 0.0)
	var stages: Array[StageConfig] = [st, st2]
	return stages

# 混合关:scene0 无害可杀、scene1 致命 → 用于制造 GRINDING 态。
func _mixed_stages() -> Array[StageConfig]:
	var st := StageConfig.new()
	st.stage_name = "混合关"
	var arr: Array[SceneConfig] = [
		_scene(_enemy(1.0, 0.0), 5),      # scene0 无害,1 击可杀
		_scene(_enemy(1000.0, 100.0), 5), # scene1 致命
		_scene(_enemy(1.0, 0.0), 5),
	]
	st.scenes = arr
	st.boss = _enemy(1000.0, 100.0)
	var stages: Array[StageConfig] = [st]
	return stages

func test_countdown_auto_advances_when_no_action() -> void:
	var a := _arena(_member(1000.0, 100.0))
	var p := _prog(a)
	p.begin_run(_quick_clear_stages())
	a.tick_combat()  # 杀场景0 → Boss
	a.tick_combat()  # 杀 Boss → 倒计时
	assert_int(p.mode).is_equal(ProgressionController.Mode.STAGE_CLEAR_COUNTDOWN)
	p.process_countdown(a.tuning.stage_clear_countdown_sec * 0.5)
	assert_int(p.mode).is_equal(ProgressionController.Mode.STAGE_CLEAR_COUNTDOWN)  # 未到点
	assert_int(p.cur_stage).is_equal(0)
	p.process_countdown(a.tuning.stage_clear_countdown_sec)  # 越过 0
	assert_int(p.mode).is_equal(ProgressionController.Mode.PROGRESSING)
	assert_int(p.cur_stage).is_equal(1)
	assert_int(p.cur_scene).is_equal(0)

func test_rest_during_countdown_cancels_auto_advance() -> void:
	var a := _arena(_member(1000.0, 100.0))
	var p := _prog(a)
	var rested := [0]
	p.rest_requested.connect(func(): rested[0] += 1)
	p.begin_run(_quick_clear_stages())
	a.tick_combat()
	a.tick_combat()  # → 倒计时
	p.request_rest()
	assert_int(rested[0]).is_equal(1)
	assert_int(p.mode).is_equal(ProgressionController.Mode.RESTING)
	assert_int(p.cur_stage).is_equal(0)  # 未推进
	p.process_countdown(a.tuning.stage_clear_countdown_sec + 5.0)  # 不应再自动推进
	assert_int(p.cur_stage).is_equal(0)
	assert_int(p.mode).is_equal(ProgressionController.Mode.RESTING)

func test_push_executes_at_round_end_while_grinding() -> void:
	var a := _arena(_member(5.0, 1.0))
	var p := _prog(a)
	p.begin_run(_mixed_stages(), 0, 1)  # 卡致命 scene1
	a.tick_combat()                      # 团灭 → 退到 (0,0) GRINDING
	assert_int(p.mode).is_equal(ProgressionController.Mode.GRINDING)
	p.request_push()
	assert_int(p.cur_scene).is_equal(0)  # 入队但本轮未结束 → 还没推进
	a.tick_combat()                      # 杀掉 scene0 怪 = 本轮结束 → 执行推进
	assert_int(p.mode).is_equal(ProgressionController.Mode.PROGRESSING)
	assert_int(p.cur_stage).is_equal(0)
	assert_int(p.cur_scene).is_equal(1)  # 推进回原卡关点

func test_rest_executes_at_round_end_while_grinding() -> void:
	var a := _arena(_member(5.0, 1.0))
	var p := _prog(a)
	var rested := [0]
	p.rest_requested.connect(func(): rested[0] += 1)
	p.begin_run(_mixed_stages(), 0, 1)
	a.tick_combat()  # 团灭 → GRINDING (0,0)
	p.request_rest()
	assert_int(rested[0]).is_equal(0)    # 本轮未结束,尚未触发
	a.tick_combat()  # 杀 scene0 怪 = 本轮结束 → 修整
	assert_int(rested[0]).is_equal(1)
	assert_int(p.mode).is_equal(ProgressionController.Mode.RESTING)
	assert_bool(a.has_living_enemy()).is_false()  # 停刷怪
